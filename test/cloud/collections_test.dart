// Shared collections (CLOUD-SYNC-CONTRACT §3) — provider-level tests over
// the real chain (feature flag → auth → entitlement → link → collections →
// active collection → runner), an in-memory DB, a fake op-log transport per
// collection and a fake HTTP layer for the account + §3 routes.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/sign_in_events.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/features/me/cloud_section.dart' show describeSyncError;
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/plantly_session.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/sync/http_sync_runner.dart';
import 'package:plantly_inventory/sync/sync_engine.dart';
import 'package:plantly_inventory/sync/sync_providers.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;
import '../sync/http_sync_runner_test.dart' show ScriptedTransport;
import 'cloud_flow_test.dart' show waitFor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final aliceToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400);

  const config = SyncRunnerConfig(
    debounce: Duration(milliseconds: 50),
    periodic: Duration.zero,
    minBackoff: Duration(milliseconds: 30),
    maxBackoff: Duration(milliseconds: 120),
    linkDebounce: Duration(milliseconds: 20),
  );

  late AppDatabase db;
  late bool entitled;
  late List<Map<String, dynamic>> serverCollections; // what GET /inventory/collections returns
  late List<http.Request> requests;
  late Map<String, ScriptedTransport> fakes;
  late ProviderContainer container;

  Map<String, dynamic> col(String id, String name, {String role = 'owner', String owner = 'u-1', int members = 1}) =>
      {'id': id, 'name': name, 'role': role, 'owner_user_id': owner, 'member_count': members};

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    entitled = true;
    requests = [];
    fakes = {};
    serverCollections = [
      col('col-1', 'My plants'),
      col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3),
    ];
    container = ProviderContainer(overrides: [
      cloudEnabledProvider.overrideWithValue(true),
      databaseProvider.overrideWithValue(db),
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore()),
      notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
      photoBlobStoreProvider.overrideWithValue(InMemoryPhotoBlobStore()),
      syncRunnerConfigProvider.overrideWithValue(config),
      collectionsRefreshIntervalProvider.overrideWithValue(Duration.zero),
      syncTransportProvider.overrideWith((ref) {
        final id = ref.watch(syncCollectionIdProvider);
        return id == null ? null : fakes.putIfAbsent(id, ScriptedTransport.new);
      }),
      collectionUsageSourceProvider.overrideWith((ref) {
        final id = ref.watch(syncCollectionIdProvider);
        return id == null ? null : fakes.putIfAbsent(id, ScriptedTransport.new);
      }),
      photoTransportProvider.overrideWithValue(null),
      httpClientProvider.overrideWith((_) => MockClient((req) async {
            requests.add(req);
            final path = req.url.path;
            final uid = PlantlySession.fromToken((req.headers['Authorization'] ?? '').replaceFirst('Bearer ', '')).userId;
            if (req.method == 'GET' && path.endsWith('/subscriptions/me')) {
              return jsonRes({
                'is_pro': entitled,
                'entitlements': {
                  'inventory_cloud': {'active': entitled, 'source': entitled ? 'pro' : null},
                },
              });
            }
            if (req.method == 'POST' && path.endsWith('/inventory/collections/default')) {
              return jsonRes({
                'collection': {'id': 'col-1', 'name': 'My plants', 'role': 'owner'},
              });
            }
            if (req.method == 'GET' && path.endsWith('/inventory/collections')) {
              return jsonRes({'collections': serverCollections});
            }
            if (req.method == 'POST' && path.endsWith('/inventory/collections/join')) {
              final code = (json.decode(req.body) as Map)['code'];
              if (code != 'ABCDEFGH') return jsonRes({'error': 'not found', 'code': 'invite_not_found'}, 404);
              final joined = col('col-3', 'Office jungle', role: 'editor', owner: 'u-3', members: 2);
              serverCollections = [...serverCollections, joined];
              return jsonRes({'collection': joined});
            }
            if (req.method == 'DELETE' && path.contains('/inventory/collections/col-2/members/')) {
              expect(path.endsWith('/members/$uid'), isTrue, reason: 'leave = delete self');
              serverCollections = [for (final c in serverCollections) if (c['id'] != 'col-2') c];
              return http.Response('', 204);
            }
            return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
          })),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.close();
  });

  Future<int> plantsIn(String tenant) async {
    final row = await db.customSelect('SELECT COUNT(*) AS n FROM plants WHERE tenant_id = ?',
        variables: [Variable<String>(tenant)]).getSingle();
    return row.read<int>('n');
  }

  /// Boot + sign in as alice (entitled) → auto-linked to col-1, list fetched.
  Future<void> signInAlice() async {
    container.read(cloudSyncCoordinatorProvider);
    await container.read(appContextProvider.future);
    await container.read(collectionLinkProvider.notifier).ready;
    final alice = await container.read(plantlyAuthProvider.notifier).adoptToken(aliceToken);
    container.read(signInEventsProvider).emit(alice);
    await waitFor(() => container.read(cloudStateProvider).canSync, reason: 'linked + ready');
    await waitFor(() => container.read(collectionsProvider).items.length == serverCollections.length,
        reason: 'collections fetched');
  }

  test('signed out: no list; signed in: list fetched, linked default first, cached per account', () async {
    container.read(collectionsProvider);
    await container.read(appContextProvider.future);
    expect(container.read(collectionsProvider).items, isEmpty);
    expect(container.read(collectionSwitcherVisibleProvider), isFalse);
    expect(container.read(activeCollectionIdProvider), isNull);

    await signInAlice();
    final state = container.read(collectionsProvider);
    expect(state.items.map((c) => c.id), ['col-1', 'col-2']);
    expect(state.items.first.isOwner, isTrue);
    expect(state.items.last.role, 'editor');
    expect(state.items.last.memberCount, 3);
    expect(state.sharedWithMe.map((c) => c.id), ['col-2']);
    expect(container.read(collectionSwitcherVisibleProvider), isTrue);
    expect(container.read(activeCollectionIdProvider), 'col-1');
    expect(container.read(activeCollectionProvider)!.name, 'My plants');
    expect(requests.where((r) => r.method == 'GET' && r.url.path.endsWith('/inventory/collections')).first.headers['X-Plantly-Client'],
        startsWith('inventory/'));

    final prefs = await SharedPreferences.getInstance();
    final cache = json.decode(prefs.getString(kCollectionsCachePrefKey)!) as Map<String, dynamic>;
    expect(cache['user_id'], 'u-1');
    expect((cache['items'] as List).length, 2);
  });

  test('switching keeps tenants separate: rows of A invisible under B, cursors per tenant, runner rebinds, no seed', () async {
    await signInAlice();
    final fern = await container.read(plantRepositoryProvider).create(nickname: 'Fern');
    final seeded = await plantsIn('col-1');
    expect(seeded, greaterThan(1), reason: 'demo seed + Fern migrated into the default');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner);
    final runner1 = container.read(syncRunnerProvider) as HttpSyncRunner;
    expect(runner1.collectionId, 'col-1');
    await runner1.syncNow();
    final prefs = await SharedPreferences.getInstance();
    await PrefsSyncCursor(prefs: prefs, tenantId: 'col-1').set('41');

    await container.read(collectionsProvider.notifier).switchCollection('col-2');

    expect(container.read(currentTenantIdProvider), 'col-2');
    expect(prefs.getString(kTenantIdPrefKey), 'col-2');
    expect(prefs.getBool(kSkipSeedPrefKey), isTrue, reason: 'a fresh shared tenant must fill from pull, not the demo seed');
    expect(container.read(activeCollectionIdProvider), 'col-2');
    expect(container.read(syncCollectionIdProvider), 'col-2');
    expect(container.read(activeCollectionProvider)!.name, 'Family greenhouse');

    // Repositories rebound to the new tenant: nothing of A is visible.
    await container.read(appContextProvider.future);
    await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-2');
    final visible = await container.read(plantRepositoryProvider).watchAll().first;
    expect(visible, isEmpty);
    expect(await plantsIn('col-2'), 0, reason: 'no seed, no migration');
    expect(await plantsIn('col-1'), seeded, reason: 'A untouched on disk');

    // Cursors are per tenant.
    expect(await PrefsSyncCursor(prefs: prefs, tenantId: 'col-2').get(), '');
    expect(await PrefsSyncCursor(prefs: prefs, tenantId: 'col-1').get(), '41');

    // Runner rebinds to B and pushes only B's ops.
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-2');
    final runner2 = container.read(syncRunnerProvider) as HttpSyncRunner;
    await runner2.syncNow();
    final serverB = fakes['col-2']!;
    for (final push in serverB.pushes) {
      expect(push.ops.map((o) => o.entityId), isNot(contains(fern.id)));
    }
    final monstera = await container.read(plantRepositoryProvider).create(nickname: 'Monstera');
    expect(monstera.tenantId, 'col-2');
    await waitFor(() => serverB.pushes.any((p) => p.ops.any((o) => o.entityId == monstera.id)),
        timeout: config.debounce * 20, reason: 'B write pushed to B');
    expect(fakes['col-1']!.pushes.every((p) => p.ops.every((o) => o.entityId != monstera.id)), isTrue);

    // Back to A: A's rows are there again, B's are hidden.
    await container.read(collectionsProvider.notifier).switchCollection('col-1');
    await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-1');
    expect((await container.read(plantRepositoryProvider).watchAll().first).map((p) => p.id), contains(fern.id));
    expect((await container.read(plantRepositoryProvider).watchAll().first).map((p) => p.id), isNot(contains(monstera.id)));
  });

  test('guard: unknown ids rejected; entitlement is the OWNER\'s — editor collections stay switchable/syncable without a plan', () async {
    await signInAlice();
    final notifier = container.read(collectionsProvider.notifier);
    await expectLater(notifier.switchCollection('col-9'), throwsA(isA<CollectionSwitchError>()));

    // The caller's plan lapses: own default → no runner; shared → still syncs.
    entitled = false;
    await container.read(cloudEntitlementProvider.notifier).refresh();
    await waitFor(() => !container.read(cloudStateProvider).canSync);
    expect(container.read(currentTenantIdProvider), 'col-1');
    expect(container.read(activeCollectionIdProvider), isNull, reason: 'own collection needs the caller\'s plan');
    expect(container.read(syncRunnerProvider), isA<NoopSyncRunner>());
    expect(container.read(activeCollectionProvider)?.id, 'col-1', reason: 'still shown as the collection on screen');

    expect(notifier.canSwitchTo('col-2'), isTrue);
    await notifier.switchCollection('col-2');
    expect(container.read(activeCollectionIdProvider), 'col-2');
    expect(container.read(syncCollectionIdProvider), 'col-2');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-2');
    expect((container.read(syncRunnerProvider) as HttpSyncRunner).entitlementIsOwners, isTrue);

    // Home is always reachable — the runner just goes quiet there.
    expect(notifier.canSwitchTo('col-1'), isTrue);
    await notifier.switchCollection('col-1');
    await waitFor(() => container.read(syncRunnerProvider) is NoopSyncRunner);
    expect(container.read(activeCollectionIdProvider), isNull);
    // Let the disposed col-2 runner's in-flight futures settle before tearDown.
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  test('editor with NO entitlement of their own: signs in, links, syncs the shared collection and pushes', () async {
    entitled = false;
    container.read(cloudSyncCoordinatorProvider);
    await container.read(appContextProvider.future);
    await container.read(collectionLinkProvider.notifier).ready;
    final alice = await container.read(plantlyAuthProvider.notifier).adoptToken(aliceToken);
    container.read(signInEventsProvider).emit(alice);
    await waitFor(() => container.read(cloudStateProvider).linked, reason: 'linked without a plan');
    expect(container.read(cloudStateProvider).phase, CloudPhase.notEntitled);
    expect(container.read(cloudStateProvider).canSync, isFalse);
    await waitFor(() => container.read(collectionsProvider).items.length == 2);
    expect(container.read(syncRunnerProvider), isA<NoopSyncRunner>(), reason: 'own default: paywall applies');

    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-2');
    final runner = container.read(syncRunnerProvider) as HttpSyncRunner;
    await runner.syncNow();
    expect(runner.current.lastError, isNull);
    await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-2');
    final cactus = await container.read(plantRepositoryProvider).create(nickname: 'Shared cactus');
    await waitFor(() => fakes['col-2']!.pushes.any((p) => p.ops.any((o) => o.entityId == cactus.id)),
        timeout: config.debounce * 20, reason: 'editor write pushed on the owner\'s plan');
    expect(fakes.containsKey('col-1'), isFalse, reason: 'own collection never synced');
  });

  test('402 on a shared collection = the OWNER\'s plan lapsed: cloud_required + owner_plan_lapsed detail, no paywall refresh', () async {
    entitled = false;
    await signInAlice().catchError((_) {}); // canSync never turns true without a plan
    await waitFor(() => container.read(cloudStateProvider).linked);
    await waitFor(() => container.read(collectionsProvider).items.length == 2);
    final subscriptionHitsBefore = requests.where((r) => r.url.path.endsWith('/subscriptions/me')).length;
    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner);
    final runner = container.read(syncRunnerProvider) as HttpSyncRunner;
    fakes['col-2']!.failures.add(const SyncEntitlementError());
    await runner.syncNow();
    expect(runner.current.lastError, 'cloud_required');
    expect(runner.current.lastErrorDetail, kOwnerPlanLapsedDetail);
    final t = lookupAppLocalizations(const Locale('en'));
    expect(describeSyncError(t, runner.current.lastError!, detail: runner.current.lastErrorDetail),
        contains('owner’s plan lapsed'));
    expect(describeSyncError(lookupAppLocalizations(const Locale('ro')), 'cloud_required', detail: kOwnerPlanLapsedDetail),
        contains('proprietarului'));
    expect(describeSyncError(t, 'cloud_required'), t.cloudNotIncludedValue, reason: 'own collection keeps the paywall copy');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(requests.where((r) => r.url.path.endsWith('/subscriptions/me')).length, subscriptionHitsBefore,
        reason: 'no entitlement refresh — it is not our plan');
  });

  test('join: POST {code} → collection added, switched to, synced against; bad code → stable error', () async {
    await signInAlice();
    final notifier = container.read(collectionsProvider.notifier);
    await expectLater(
      notifier.join('ZZZZZZZZ'),
      throwsA(isA<PlantlyApiException>().having((e) => e.code, 'code', 'invite_not_found')),
    );
    expect(() => notifier.join('short'), throwsArgumentError);

    final joined = await notifier.join(' abcd-efgh ');
    expect(joined.id, 'col-3');
    expect(joined.role, 'editor');
    final joinReq = requests.lastWhere((r) => r.url.path.endsWith('/inventory/collections/join'));
    expect(json.decode(joinReq.body), {'code': 'ABCDEFGH'});
    expect(joinReq.headers['Content-Type'], startsWith('application/json'));
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1', 'col-2', 'col-3']);
    expect(container.read(currentTenantIdProvider), 'col-3');
    expect(container.read(syncCollectionIdProvider), 'col-3');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-3');
  });

  test('leave: DELETE members/{me}, list shrinks, active falls back to the linked default', () async {
    await signInAlice();
    final notifier = container.read(collectionsProvider.notifier);
    await notifier.switchCollection('col-2');
    expect(container.read(activeCollectionIdProvider), 'col-2');
    await notifier.leave('col-2');
    expect(requests.any((r) => r.method == 'DELETE' && r.url.path.endsWith('/inventory/collections/col-2/members/u-1')), isTrue);
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1']);
    expect(container.read(currentTenantIdProvider), 'col-1');
    expect(container.read(activeCollectionIdProvider), 'col-1');
    expect(container.read(collectionSwitcherVisibleProvider), isFalse);
  });

  test('removed on the server while active → refresh reconciles back to the default', () async {
    await signInAlice();
    final notifier = container.read(collectionsProvider.notifier);
    await notifier.switchCollection('col-2');
    serverCollections = [col('col-1', 'My plants')];
    await notifier.refresh();
    await waitFor(() => container.read(currentTenantIdProvider) == 'col-1', reason: 'reconciled to default');
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1']);
  });

  test('unlink while switched restores the default tenant; re-link never migrates the shared tenant', () async {
    await signInAlice();
    await container.read(plantRepositoryProvider).create(nickname: 'Fern');
    final inA = await plantsIn('col-1');
    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-2');
    await container.read(plantRepositoryProvider).create(nickname: 'Shared cactus');
    expect(await plantsIn('col-2'), 1);

    final links = container.read(collectionLinkProvider.notifier);
    await links.unlink();
    expect(container.read(currentTenantIdProvider), 'col-1', reason: 'back home on unlink');
    expect(container.read(cloudStateProvider).linked, isFalse);

    await links.link();
    expect(container.read(currentTenantIdProvider), 'col-1');
    expect(await plantsIn('col-1'), inA, reason: 'nothing migrated in');
    expect(await plantsIn('col-2'), 1, reason: 'shared rows stay under their collection');
  });

  test('membersProvider: fetched, cached in prefs, served from cache on error', () async {
    var fail = false;
    container = ProviderContainer(overrides: [
      cloudEnabledProvider.overrideWithValue(true),
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore(aliceToken)),
      httpClientProvider.overrideWith((_) => MockClient((req) async {
            if (fail) return jsonRes({'error': 'down'}, 503);
            expect(req.url.path, endsWith('/inventory/collections/col-2/members'));
            return jsonRes({
              'members': [
                {'user_id': 'u-2', 'username': 'bob', 'role': 'owner', 'joined_at': '2026-09-01T10:00:00Z'},
                {'user_id': 'u-1', 'username': 'alice', 'role': 'editor', 'joined_at': '2026-09-20T10:00:00Z'},
              ]
            });
          })),
    ]);
    final members = await container.read(membersProvider('col-2').future);
    expect(members.map((m) => m.username), ['bob', 'alice']);
    expect(members.first.isOwner, isTrue);
    expect(memberUsername(members, 'u-2'), 'bob');
    expect(memberUsername(members, 'u-9'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('${kMembersCachePrefPrefix}col-2'), contains('"bob"'));

    fail = true;
    container.invalidate(membersProvider('col-2'));
    final cached = await container.read(membersProvider('col-2').future);
    expect(cached.map((m) => m.username), ['bob', 'alice'], reason: 'cache survives a failed refresh');
    container.dispose();
  });
}
