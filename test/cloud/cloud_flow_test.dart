// End-to-end provider test for the cloud wiring (CLOUD-SYNC-CONTRACT §2.4):
// real providers from the feature flag down to the HTTP runner, an
// in-memory database, a fake op-log transport and a fake HTTP layer for the
// two account routes (`/subscriptions/me`, `/inventory/collections/default`).
//
// One sequential scenario, because every step builds on the device state
// the previous one left behind — exactly like a real device would:
//   (a) signed out           → phase signedOut, Noop runner
//   (b) sign-in + entitled   → auto-link, tenant migrated, phase ready,
//                              local write → push within the debounce,
//                              fresh_ops applied, lastSyncAt set
//   (c) transport 402        → cloud_required, entitlement refreshed,
//                              phase notEntitled, runner back to Noop
//   (d) other account + "Start empty" → runner bound to the new collection
//   (e) unlink               → Noop, no further pushes
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/sign_in_events.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/config/plantly_hosts.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/plantly_session.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/sync/http_sync_runner.dart';
import 'package:plantly_inventory/sync/sync_providers.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;
import '../sync/http_sync_runner_test.dart' show ScriptedTransport, remotePlant;

/// Poll until [check] passes (real timers — the runner's own debounce and
/// backoff are shortened via [SyncRunnerConfig], not faked).
Future<void> waitFor(
  bool Function() check, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!check()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out waiting for ${reason ?? 'condition'}');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final aliceToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400);
  final bobToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400, username: 'bob', userId: 'u-2');

  const config = SyncRunnerConfig(
    debounce: Duration(milliseconds: 50),
    periodic: Duration.zero,
    minBackoff: Duration(milliseconds: 30),
    maxBackoff: Duration(milliseconds: 120),
    linkDebounce: Duration(milliseconds: 20),
  );

  late AppDatabase db;
  late Map<String, bool> entitled; // userId → inventory_cloud active
  late int subscriptionHits;
  late int collectionCreates;
  late Map<String, ScriptedTransport> fakes; // collection id → transport
  late ProviderContainer container;

  String userIdOf(http.BaseRequest req) {
    final auth = req.headers['Authorization'] ?? '';
    return PlantlySession.fromToken(auth.replaceFirst('Bearer ', '')).userId;
  }

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  setUp(() {
    SharedPreferences.setMockInitialValues({kSkipSeedPrefKey: true});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entitled = {'u-1': true, 'u-2': true};
    subscriptionHits = 0;
    collectionCreates = 0;
    fakes = {};
    container = ProviderContainer(overrides: [
      cloudEnabledProvider.overrideWithValue(true),
      databaseProvider.overrideWithValue(db),
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore()),
      notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
      photoBlobStoreProvider.overrideWithValue(InMemoryPhotoBlobStore()),
      syncRunnerConfigProvider.overrideWithValue(config),
      // Op-log wire: one scripted server per collection id, created on
      // demand — so "no further pushes" can be asserted per collection.
      syncTransportProvider.overrideWith((ref) {
        final id = ref.watch(syncCollectionIdProvider);
        return id == null ? null : fakes.putIfAbsent(id, ScriptedTransport.new);
      }),
      collectionUsageSourceProvider.overrideWith((ref) {
        final id = ref.watch(syncCollectionIdProvider);
        return id == null ? null : fakes.putIfAbsent(id, ScriptedTransport.new);
      }),
      photoTransportProvider.overrideWithValue(null),
      // Account routes.
      httpClientProvider.overrideWith((_) => MockClient((req) async {
            expect(req.headers['X-Plantly-Client'], PlantlyHosts.clientHeader,
                reason: 'cloud routes send the client header');
            final path = req.url.path;
            if (req.method == 'GET' && path.endsWith('/subscriptions/me')) {
              subscriptionHits++;
              final active = entitled[userIdOf(req)] ?? false;
              return jsonRes({
                'is_pro': active,
                'entitlements': {
                  'inventory_cloud': {'active': active, 'source': active ? 'pro' : null},
                },
              });
            }
            if (req.method == 'POST' && path.endsWith('/inventory/collections/default')) {
              collectionCreates++;
              final uid = userIdOf(req);
              final id = uid == 'u-1' ? 'col-1' : 'col-2';
              return jsonRes({
                'collection': {'id': id, 'name': '$uid plants', 'role': 'owner'},
              });
            }
            return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
          })),
    ]);
  });

  tearDown(() async {
    container.dispose();
    // Let the disposed runner's pending futures settle before the DB goes.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.close();
  });

  Future<int> tenantCount(String tenant) async {
    final row = await db.customSelect('SELECT COUNT(*) AS n FROM plants WHERE tenant_id = ?',
        variables: [Variable<String>(tenant)]).getSingle();
    return row.read<int>('n');
  }

  test('signed out → sign-in/auto-link/sync → 402 → start empty → unlink', () async {
    // Boot: the coordinator is what the app root watches for the whole session.
    final coordinator = container.read(cloudSyncCoordinatorProvider);
    await container.read(appContextProvider.future);
    await container.read(plantlyAuthProvider.notifier).current();
    await container.read(collectionLinkProvider.notifier).ready;

    // A row born before any account exists — the migration + initial upload
    // must carry it into the collection.
    final early = await container.read(plantRepositoryProvider).create(nickname: 'Fern');
    expect(await tenantCount('local'), 1);

    // --- (a) signed out -----------------------------------------------------
    var state = container.read(cloudStateProvider);
    expect(state.phase, CloudPhase.signedOut);
    expect(container.read(syncCollectionIdProvider), isNull);
    expect(container.read(syncRunnerProvider), isA<NoopSyncRunner>());
    expect(fakes, isEmpty);

    // --- (b) sign in (entitled) → auto-link → ready → sync --------------------
    final alice = await container.read(plantlyAuthProvider.notifier).adoptToken(aliceToken);
    container.read(signInEventsProvider).emit(alice);
    await coordinator.idle;
    await waitFor(() => container.read(cloudStateProvider).canSync, reason: 'phase ready + linked');

    state = container.read(cloudStateProvider);
    expect(state.phase, CloudPhase.ready);
    expect(state.collectionId, 'col-1');
    expect(state.account, 'alice');
    expect(collectionCreates, 1, reason: 'exactly one POST /collections/default');
    expect(container.read(currentTenantIdProvider), 'col-1');
    expect(await tenantCount('local'), 0, reason: 'tenant migrated');
    expect(await tenantCount('col-1'), 1);
    expect(container.read(syncCollectionIdProvider), 'col-1');

    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner, reason: 'HTTP runner bound');
    final runner1 = container.read(syncRunnerProvider) as HttpSyncRunner;
    expect(runner1.collectionId, 'col-1');

    // First cycle: the pre-link row's ops go up, the other device's op comes down.
    final server1 = fakes['col-1']!;
    server1.serverOps.add(remotePlant('p-remote', 1000));
    await runner1.syncNow();
    expect(server1.pushes, isNotEmpty);
    expect(server1.pushes.first.ops.map((o) => o.entityId), contains(early.id));
    expect(runner1.current.lastSyncAt, isNotNull);
    expect(runner1.current.lastError, isNull);
    final remoteRow = await (db.select(db.plants)..where((p) => p.id.equals('p-remote'))).getSingleOrNull();
    expect(remoteRow, isNotNull, reason: 'fresh_ops applied');
    expect(remoteRow!.tenantId, 'col-1');
    expect(remoteRow.nickname, 'R-p-remote');

    // A local write → push within the debounce, no manual trigger.
    final pushesBefore = server1.pushes.length;
    final late = await container.read(plantRepositoryProvider).create(nickname: 'Monstera');
    await waitFor(() => server1.pushes.length > pushesBefore,
        timeout: config.debounce * 20, reason: 'debounced push after a local write');
    expect(server1.pushes.last.ops.map((o) => o.entityId), contains(late.id));
    await waitFor(() => !runner1.current.inFlight && runner1.current.pendingOps == 0, reason: 'queue drained');
    expect(server1.pushes.last.deviceId, container.read(appContextProvider).requireValue.deviceId);

    // --- (c) 402 → cloud_required → entitlement re-checked → notEntitled ------
    entitled['u-1'] = false;
    final hitsBefore = subscriptionHits;
    server1.failures.add(const SyncEntitlementError());
    await runner1.syncNow();
    expect(runner1.current.lastError, 'cloud_required');
    await waitFor(() => subscriptionHits > hitsBefore, reason: 'entitlement refresh after 402');
    await waitFor(() => container.read(cloudStateProvider).phase == CloudPhase.notEntitled, reason: 'notEntitled');
    expect(container.read(syncCollectionIdProvider), isNull);
    expect(container.read(syncRunnerProvider), isA<NoopSyncRunner>());
    expect(container.read(collectionLinkProvider).link?.id, 'col-1', reason: 'link survives a lapsed plan');

    // Plan comes back → a fresh runner for the same collection.
    entitled['u-1'] = true;
    await container.read(cloudEntitlementProvider.notifier).refresh();
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner, reason: 'runner recreated');
    final runner1b = container.read(syncRunnerProvider) as HttpSyncRunner;
    expect(identical(runner1b, runner1), isFalse, reason: 'old runner disposed, new one built');
    expect(runner1b.collectionId, 'col-1');
    await waitFor(() => !runner1b.current.inFlight && runner1b.current.lastSyncAt != null);

    // --- (d) another account: no auto-link; "Start empty" binds col-2 --------
    await container.read(plantlyAuthProvider.notifier).signOut();
    await waitFor(() => container.read(syncRunnerProvider) is NoopSyncRunner, reason: 'sign-out stops sync');
    expect(container.read(cloudStateProvider).phase, CloudPhase.signedOut);

    final bob = await container.read(plantlyAuthProvider.notifier).adoptToken(bobToken);
    container.read(signInEventsProvider).emit(bob);
    await coordinator.idle;
    await waitFor(() => container.read(cloudStateProvider).phase == CloudPhase.ready);
    state = container.read(cloudStateProvider);
    expect(state.heldByOther, 'alice');
    expect(state.linked, isFalse);
    expect(state.canSync, isFalse);
    expect(collectionCreates, 1, reason: "someone else's link is never migrated automatically");
    expect(container.read(syncRunnerProvider), isA<NoopSyncRunner>());

    final col2 = await container.read(collectionLinkProvider.notifier).startEmpty();
    expect(col2.id, 'col-2');
    expect(collectionCreates, 2);
    expect(container.read(currentTenantIdProvider), 'col-2');
    expect(await tenantCount('col-1'), 3, reason: "alice's rows stay parked under her collection id");
    expect(await tenantCount('col-2'), 0);
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner, reason: 'runner for col-2');
    final runner2 = container.read(syncRunnerProvider) as HttpSyncRunner;
    expect(runner2.collectionId, 'col-2');
    expect(container.read(syncCollectionIdProvider), 'col-2');
    await waitFor(() => fakes['col-2']?.pulls.isNotEmpty ?? false, reason: 'first cycle against col-2');
    expect(server1.pushes.every((p) => p.ops.every((o) => o.entityId != 'p-bob')), isTrue);

    final bobPlant = await container.read(plantRepositoryProvider).create(nickname: 'Cactus');
    await waitFor(() => fakes['col-2']!.pushes.any((p) => p.ops.any((o) => o.entityId == bobPlant.id)),
        timeout: config.debounce * 20, reason: "bob's write pushed to col-2");

    // --- (e) unlink → Noop, nothing else leaves the device --------------------
    await container.read(collectionLinkProvider.notifier).unlink();
    await waitFor(() => container.read(syncRunnerProvider) is NoopSyncRunner, reason: 'unlink stops sync');
    expect(container.read(cloudStateProvider).unlinkedByUser, isTrue);
    expect(container.read(syncCollectionIdProvider), isNull);
    expect(container.read(currentTenantIdProvider), 'col-2', reason: 'data keeps its tenant');

    final pushes1 = server1.pushes.length;
    final pushes2 = fakes['col-2']!.pushes.length;
    await container.read(plantRepositoryProvider).create(nickname: 'Never leaves');
    await Future<void>.delayed(config.debounce * 4);
    expect(server1.pushes.length, pushes1);
    expect(fakes['col-2']!.pushes.length, pushes2);
    expect(await container.read(appContextProvider).requireValue.opLog.pendingCount(), greaterThan(0),
        reason: 'the op waits locally for a future link');
  });

  test('flag off → phase off, Noop runner, coordinator inert', () async {
    final off = ProviderContainer(
      parent: null,
      overrides: [
        cloudEnabledProvider.overrideWithValue(false),
        databaseProvider.overrideWithValue(db),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(aliceToken)),
        notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
        httpClientProvider.overrideWith((_) => MockClient((_) async => fail('no network when cloud is off'))),
      ],
    );
    addTearDown(off.dispose);
    off.read(cloudSyncCoordinatorProvider);
    await off.read(appContextProvider.future);
    await off.read(plantlyAuthProvider.notifier).current();
    expect(off.read(cloudStateProvider), CloudState.off);
    expect(off.read(syncRunnerProvider), isA<NoopSyncRunner>());
    expect(off.read(syncCollectionIdProvider), isNull);
    off.read(signInEventsProvider).emit(PlantlySession.fromToken(aliceToken));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(off.read(collectionLinkProvider).link, isNull);
  });
}
