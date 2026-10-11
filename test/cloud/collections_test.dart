// Shared collections (CLOUD-SYNC-CONTRACT §3) — provider-level tests over
// the real chain (feature flag → auth → entitlement → link → collections →
// active collection → runner), an in-memory DB, a fake op-log transport per
// collection and a fake HTTP layer for the account + §3 routes.
import 'dart:async';
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
import 'package:plantly_inventory/features/me/cloud_section.dart' show describeHomeLoss, describeSyncError;
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
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/http_sync_runner.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_engine.dart';
import 'package:plantly_inventory/sync/sync_providers.dart';
import 'package:plantly_inventory/sync/sync_tabs.dart';
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
  bool? callerEntitled; // top-level `caller_entitled` of GET /inventory/collections (null = omitted, older server)
  late List<http.Request> requests;
  late Map<String, ScriptedTransport> fakes;
  late ProviderContainer container;
  Completer<void>? holdCollections; // when set, GET /inventory/collections waits on it
  late Map<String, dynamic> aliceDefault; // what POST /collections/default returns for u-1
  late SyncTabs tabs; // cross-tab coordinator (single tab unless a test swaps it)
  var failCollections = false; // GET /inventory/collections answers 503

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
    holdCollections = null;
    callerEntitled = null;
    aliceDefault = {'id': 'col-1', 'name': 'My plants', 'role': 'owner'};
    tabs = SyncTabs.single;
    failCollections = false;
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
      syncTabsProvider.overrideWith((_) => tabs),
      collectionsRefreshIntervalProvider.overrideWithValue(Duration.zero),
      homeRecheckDelayProvider.overrideWithValue(const Duration(milliseconds: 100)),
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
                'collection': uid == 'u-2'
                    ? {'id': 'col-5', 'name': "Bob's plants", 'role': 'owner'}
                    : aliceDefault,
              });
            }
            if (req.method == 'GET' && path.endsWith('/inventory/collections')) {
              if (holdCollections != null) await holdCollections!.future;
              if (failCollections) return jsonRes({'error': 'unavailable'}, 503);
              return jsonRes({'collections': serverCollections, 'caller_entitled': ?callerEntitled});
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

  Future<int> opsIn(String tenant, {bool pendingOnly = false}) async {
    final row = await db.customSelect(
        'SELECT COUNT(*) AS n FROM sync_ops WHERE tenant_id = ?${pendingOnly ? ' AND pushed_at IS NULL' : ''}',
        variables: [Variable<String>(tenant)]).getSingle();
    return row.read<int>('n');
  }

  Future<HttpSyncRunner> runnerOn(String id) async {
    await waitFor(() {
      final r = container.read(syncRunnerProvider);
      return r is HttpSyncRunner && r.collectionId == id;
    }, reason: 'runner bound to $id');
    return container.read(syncRunnerProvider) as HttpSyncRunner;
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
    expect(seeded, 1, reason: 'Fern migrated into the default; the untouched demo seed was dropped at link');
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

  test('editor with NO entitlement of their own (§8, client verdict, older server without the flag): links, pulls the shared collection read-only, never pushes; pushes once the plan is active',
      () async {
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
    expect(container.read(collectionsProvider).callerEntitled, isTrue, reason: 'no flag from this server');
    expect(container.read(sharedNeedsCloudProvider), isTrue, reason: 'the client\'s own verdict is enough');

    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-2');
    expect(container.read(activeCollectionReadOnlyReasonProvider), ReadOnlyReason.cloudRequired);
    final runner = container.read(syncRunnerProvider) as HttpSyncRunner;
    expect(runner.readOnly, isTrue);
    await runner.syncNow();
    expect(runner.current.lastError, isNull);
    expect(fakes['col-2']!.pulls, isNotEmpty, reason: 'read grace: pulls');
    await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-2');
    final cactus = await container.read(plantRepositoryProvider).create(nickname: 'Shared cactus');
    await Future<void>.delayed(config.debounce * 4);
    expect(fakes['col-2']!.pushes, isEmpty, reason: 'no push without our own plan');
    expect(fakes.containsKey('col-1'), isFalse, reason: 'own collection never synced');

    entitled = true;
    await container.read(cloudEntitlementProvider.notifier).refresh();
    await waitFor(() => container.read(activeCollectionReadOnlyReasonProvider) == ReadOnlyReason.none);
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        !(container.read(syncRunnerProvider) as HttpSyncRunner).readOnly);
    await (container.read(syncRunnerProvider) as HttpSyncRunner).syncNow();
    expect(fakes['col-2']!.pushes.any((p) => p.ops.any((o) => o.entityId == cactus.id)), isTrue,
        reason: 'kept rows push once the plan is active');
  });

  Future<HttpSyncRunner> sharedRunnerWithoutPlan() async {
    entitled = false;
    await signInAlice().catchError((_) {}); // canSync never turns true without a plan
    await waitFor(() => container.read(cloudStateProvider).linked);
    await waitFor(() => container.read(collectionsProvider).items.length == 2);
    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner);
    return container.read(syncRunnerProvider) as HttpSyncRunner;
  }

  int hits(String suffix) => requests.where((r) => r.url.path.endsWith(suffix)).length;

  test('402 cloud_required_owner on a shared collection = the OWNER\'s plan: owner detail, list refreshed, NO entitlement refresh (§8)',
      () async {
    final runner = await sharedRunnerWithoutPlan();
    final subsBefore = hits('/subscriptions/me');
    final listBefore = hits('/inventory/collections');
    fakes['col-2']!.failures.add(const SyncEntitlementError(kCloudRequiredOwnerCode));
    await runner.syncNow();
    expect(runner.current.lastError, 'cloud_required');
    expect(runner.current.lastErrorDetail, kOwnerPlanLapsedDetail);
    final t = lookupAppLocalizations(const Locale('en'));
    expect(describeSyncError(t, runner.current.lastError!, detail: runner.current.lastErrorDetail),
        contains('owner’s plan lapsed'));
    expect(describeSyncError(lookupAppLocalizations(const Locale('ro')), 'cloud_required', detail: kOwnerPlanLapsedDetail),
        contains('proprietarului'));
    await waitFor(() => hits('/inventory/collections') > listBefore, reason: 'list refetched for the paused marker');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(hits('/subscriptions/me'), subsBefore, reason: 'no entitlement refresh — it is not our plan');
  });

  test('402 cloud_required on a shared collection = OUR plan lapsed: member detail + copy, entitlement AND list refreshed (§8)',
      () async {
    final runner = await sharedRunnerWithoutPlan();
    final subsBefore = hits('/subscriptions/me');
    final listBefore = hits('/inventory/collections');
    fakes['col-2']!.failures.add(const SyncEntitlementError());
    await runner.syncNow();
    expect(runner.current.lastError, 'cloud_required');
    expect(runner.current.lastErrorDetail, kMemberPlanLapsedDetail);
    final t = lookupAppLocalizations(const Locale('en'));
    expect(describeSyncError(t, 'cloud_required', detail: kMemberPlanLapsedDetail),
        'Your Inventory Cloud subscription expired — reactivate it to sync shared collections.');
    expect(describeSyncError(lookupAppLocalizations(const Locale('ro')), 'cloud_required', detail: kMemberPlanLapsedDetail),
        'Abonamentul tău Inventory Cloud a expirat — reactivează-l ca să sincronizezi colecțiile partajate.');
    expect(describeSyncError(t, 'cloud_required'), t.cloudNotIncludedValue, reason: 'own collection keeps the paywall copy');
    await waitFor(() => hits('/subscriptions/me') > subsBefore, reason: 'our plan: re-checked');
    await waitFor(() => hits('/inventory/collections') > listBefore, reason: 'list refetched for caller_entitled');
  });

  test('caller_entitled=false (§8): shared collections read-only (cloudRequired), runner pull-only, local rows kept; flag absent → entitled',
      () async {
    callerEntitled = false;
    final runner = await sharedRunnerWithoutPlan();
    final state = container.read(collectionsProvider);
    expect(state.callerEntitled, isFalse);
    expect(container.read(activeCollectionReadOnlyReasonProvider), ReadOnlyReason.cloudRequired);
    expect(container.read(canEditActiveCollectionProvider), isFalse);
    expect(container.read(sharedCollectionsNeedCloudProvider), isTrue);
    expect(runner.readOnly, isTrue);
    expect(runner.entitlementIsOwners, isTrue);
    // Cached with the flag, so the next boot starts read-only too.
    final prefs = await SharedPreferences.getInstance();
    expect(json.decode(prefs.getString(kCollectionsCachePrefKey)!)['caller_entitled'], isFalse);

    await runner.syncNow();
    expect(fakes['col-2']!.pulls, isNotEmpty, reason: 'read grace: still pulls');
    expect(fakes['col-2']!.pushes, isEmpty);
    await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-2');
    // A row that slips in locally (the UI gates writes) is kept, never pushed.
    final cactus = await container.read(plantRepositoryProvider).create(nickname: 'Kept locally');
    await Future<void>.delayed(config.debounce * 4);
    expect(fakes['col-2']!.pushes, isEmpty, reason: 'no push without our own plan');
    expect(await plantsIn('col-2'), greaterThanOrEqualTo(1));
    expect(cactus.id, isNotEmpty);

    // The plan comes back (server flag flips; our own entitlement too).
    callerEntitled = true;
    entitled = true;
    await container.read(cloudEntitlementProvider.notifier).refresh();
    await container.read(collectionsProvider.notifier).refresh();
    await waitFor(() => container.read(activeCollectionReadOnlyReasonProvider) == ReadOnlyReason.none);
    expect(container.read(canEditActiveCollectionProvider), isTrue);
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        !(container.read(syncRunnerProvider) as HttpSyncRunner).readOnly);
    await (container.read(syncRunnerProvider) as HttpSyncRunner).syncNow();
    expect(fakes['col-2']!.pushes.any((p) => p.ops.any((o) => o.entityId == cactus.id)), isTrue,
        reason: 'kept rows push once the plan is active again');
    expect(await plantsIn('col-2'), greaterThanOrEqualTo(1), reason: 'local data never deleted');

    // Older server: no flag at all → treated as entitled (no false markers).
    callerEntitled = null;
    await container.read(collectionsProvider.notifier).refresh();
    expect(container.read(collectionsProvider).callerEntitled, isTrue);
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

  test('tenant unknown to the list (shared id before the first fetch) → no runner, never the default; listed → that id', () async {
    // A device that switched to a shared collection, booting linked with
    // the collections cache not there yet: until the list says what col-3
    // is, nothing may sync — least of all the home collection driven by
    // col-3's op log.
    SharedPreferences.setMockInitialValues({
      kTenantIdPrefKey: 'col-3',
      kSkipSeedPrefKey: true,
      kCollectionIdPrefKey: 'col-1',
      kCollectionNamePrefKey: 'My plants',
      kCollectionUserIdPrefKey: 'u-1',
      kCollectionUsernamePrefKey: 'alice',
    });
    serverCollections = [...serverCollections, col('col-3', 'Office jungle', role: 'editor', owner: 'u-3', members: 2)];
    holdCollections = Completer<void>();

    container.read(cloudSyncCoordinatorProvider);
    await container.read(appContextProvider.future);
    await container.read(collectionLinkProvider.notifier).ready;
    final alice = await container.read(plantlyAuthProvider.notifier).adoptToken(aliceToken);
    container.read(signInEventsProvider).emit(alice);
    await waitFor(() => container.read(cloudStateProvider).canSync, reason: 'linked + entitled');
    await container.read(collectionsProvider.notifier).ready;
    await waitFor(() => container.read(collectionsProvider).loading, reason: 'a fetch is under way');

    expect(container.read(currentTenantIdProvider), 'col-3');
    expect(container.read(collectionsProvider).byId('col-3'), isNull);
    expect(container.read(activeCollectionIdProvider), isNull, reason: 'unknown tenant: no guess');
    expect(container.read(syncCollectionIdProvider), isNull);
    expect(container.read(syncRunnerProvider), isA<NoopSyncRunner>());
    expect(container.read(activeCollectionProvider)?.id, 'col-1', reason: 'display still has a home to show');

    holdCollections!.complete();
    await waitFor(() => container.read(collectionsProvider).byId('col-3') != null, reason: 'list fetched');
    expect(container.read(activeCollectionIdProvider), 'col-3');
    expect(container.read(currentTenantIdProvider), 'col-3', reason: 'not reconciled away');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-3');
    expect(fakes.containsKey('col-1'), isFalse, reason: 'the default was never synced against');
  });

  test('403 not_a_member on the active shared collection → dropped, back home, notice raised (once)', () async {
    await signInAlice();
    final notifier = container.read(collectionsProvider.notifier);
    await notifier.switchCollection('col-2');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-2');
    final runner = container.read(syncRunnerProvider) as HttpSyncRunner;
    expect(container.read(collectionRemovedNoticeProvider), isNull);

    fakes['col-2']!.failures.add(const SyncCollectionError('not_a_member', status: 403));
    await runner.syncNow();
    expect(runner.current.lastError, 'collection_unavailable');
    expect(runner.current.lastErrorDetail, kNotAMemberDetail);
    final t = lookupAppLocalizations(const Locale('en'));
    expect(describeSyncError(t, 'collection_unavailable', detail: runner.current.lastErrorDetail, collectionName: 'Family greenhouse'),
        'You were removed from Family greenhouse');

    await waitFor(() => container.read(currentTenantIdProvider) == 'col-1', reason: 'back home');
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1']);
    expect(container.read(collectionRemovedNoticeProvider), 'Family greenhouse');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kTenantIdPrefKey), 'col-1');
    final cache = json.decode(prefs.getString(kCollectionsCachePrefKey)!) as Map<String, dynamic>;
    expect((cache['items'] as List).map((e) => (e as Map)['id']), ['col-1'], reason: 'cache dropped it too');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-1');
    // A second notice is not raised for the same event.
    container.read(collectionRemovedNoticeProvider.notifier).state = null;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(container.read(collectionRemovedNoticeProvider), isNull);
  });

  test('404 collection_not_found / 403 on an OWN collection does not trigger the removal path', () async {
    await signInAlice();
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner);
    final runner = container.read(syncRunnerProvider) as HttpSyncRunner;
    fakes['col-1']!.failures.add(const SyncCollectionError('not_a_member', status: 403));
    await runner.syncNow();
    expect(runner.current.lastError, 'collection_unavailable');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(collectionRemovedNoticeProvider), isNull);
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1', 'col-2']);
    // The server still lists the home as ours: a stray 403 is not a loss.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(homeLossProvider), isNull);
    expect(container.read(homeLostNoticeProvider), isNull);
  });

  test('QA2 BUG-4: b signs in on a\'s device via a join link — decision first, a\'s pending ops never pushed as b (nor b\'s as a)', () async {
    // Device linked by alice (u-1) to col-1 with two of her ops still pending.
    SharedPreferences.setMockInitialValues({
      kTenantIdPrefKey: 'col-1',
      kSkipSeedPrefKey: true,
      kCollectionIdPrefKey: 'col-1',
      kCollectionNamePrefKey: 'My plants',
      kCollectionUserIdPrefKey: 'u-1',
      kCollectionUsernamePrefKey: 'alice',
      kDataOwnerUserIdPrefKey: 'u-1',
      kDataOwnerUsernamePrefKey: 'alice',
    });
    final aliceLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'dev-a'), tenantId: 'col-1', currentUserId: () => 'u-1');
    final h = await aliceLog.recordCreate(entity: 'plants', entityId: 'alice-fern', value: {'id': 'alice-fern', 'nickname': 'Fern', 'status': 'active'});
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'alice-fern', tenantId: 'col-1', nickname: 'Fern', status: 'active', updatedHlc: h.encode(), deviceId: 'dev-a'));
    await aliceLog.recordFieldUpdate(entity: 'plants', entityId: 'alice-fern', field: 'notes', value: 'water weekly');
    const aliceIds = {'alice-fern'};
    Future<List<SyncOpRow>> pendingOps() async => (await db.select(db.syncOps).get()).where((o) => o.pushedAt == null).toList();
    expect(await pendingOps(), hasLength(2));

    // The join deep link: bob (u-2) signs in.
    final bobToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400, username: 'bob', userId: 'u-2');
    serverCollections = [col('col-5', "Bob's plants", owner: 'u-2')];
    final coordinator = container.read(cloudSyncCoordinatorProvider);
    await container.read(appContextProvider.future);
    await container.read(collectionLinkProvider.notifier).ready;
    final bob = await container.read(plantlyAuthProvider.notifier).adoptToken(bobToken);
    container.read(signInEventsProvider).emit(bob);
    await coordinator.idle;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    var cloud = container.read(cloudStateProvider);
    expect(cloud.account, 'bob');
    expect(cloud.heldByOther, 'alice');
    expect(cloud.linked, isFalse, reason: 'alice\'s link is not bob\'s');
    expect(container.read(activeCollectionIdProvider), isNull, reason: 'nothing syncs while undecided');
    expect(container.read(syncRunnerProvider), isA<NoopSyncRunner>());
    expect(requests.where((r) => r.url.path.endsWith('/collections/default')), isEmpty, reason: 'no automatic link');

    // Bob adds a plant while still undecided (tenant is alice's col-1): the
    // op is HIS, stamped so, and must never go up under alice's token.
    final stray = await container.read(plantRepositoryProvider).create(nickname: 'Bob stray');
    expect(stray.tenantId, 'col-1');
    final strayOps = (await pendingOps()).where((o) => o.entityId == stray.id).toList();
    expect(strayOps, isNotEmpty);
    expect(strayOps.map((o) => o.userId), everyElement('u-2'));

    // The dialog's "Start empty for bob" (provider-level equivalent), then the join.
    await container.read(collectionLinkProvider.notifier).startEmpty();
    cloud = container.read(cloudStateProvider);
    expect(cloud.linked, isTrue);
    expect(cloud.collectionId, 'col-5', reason: 'bob\'s own default, from POST /default under his token');
    expect(cloud.heldByOther, isNull);
    final joined = await container.read(collectionsProvider.notifier).join('ABCDEFGH');
    expect(joined.id, 'col-3');
    expect(container.read(currentTenantIdProvider), 'col-3');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-3');
    final bobRunner = container.read(syncRunnerProvider) as HttpSyncRunner;
    expect(bobRunner.userId, 'u-2');
    await bobRunner.syncNow();
    final cactus = await container.read(plantRepositoryProvider).create(nickname: 'Shared cactus');
    await waitFor(() => fakes['col-3']!.pushes.any((p) => p.ops.any((o) => o.entityId == cactus.id)),
        timeout: config.debounce * 20, reason: 'bob\'s write in the joined collection pushed');

    // Nothing of alice's went anywhere; her ops are still hers, still pending.
    for (final fake in fakes.values) {
      for (final push in fake.pushes) {
        expect(push.ops.where((o) => aliceIds.contains(o.entityId)), isEmpty, reason: 'alice\'s ops pushed as bob');
      }
    }
    expect(fakes.containsKey('col-1'), isFalse, reason: 'alice\'s collection never synced against');
    final aliceLeft = (await pendingOps()).where((o) => aliceIds.contains(o.entityId)).toList();
    expect(aliceLeft, hasLength(2));
    expect(aliceLeft.map((o) => o.userId), everyElement('u-1'));
    expect(aliceLeft.map((o) => o.tenantId), everyElement('col-1'));

    // Alice comes back: decides "Start empty" too → her rows reappear under
    // col-1; her runner pushes HER two ops and leaves bob's stray alone.
    await container.read(plantlyAuthProvider.notifier).signOut();
    final alice = await container.read(plantlyAuthProvider.notifier).adoptToken(aliceToken);
    container.read(signInEventsProvider).emit(alice);
    await coordinator.idle;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(container.read(cloudStateProvider).heldByOther, 'bob');
    serverCollections = [col('col-1', 'My plants')];
    await container.read(collectionLinkProvider.notifier).startEmpty();
    expect(container.read(cloudStateProvider).collectionId, 'col-1');
    expect(container.read(currentTenantIdProvider), 'col-1');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == 'col-1' &&
        (container.read(syncRunnerProvider) as HttpSyncRunner).userId == 'u-1');
    final aliceRunner = container.read(syncRunnerProvider) as HttpSyncRunner;
    await aliceRunner.syncNow();
    final serverA = fakes['col-1']!;
    final pushedIds = [for (final p in serverA.pushes) for (final o in p.ops) o.entityId];
    expect(pushedIds.where((id) => id == 'alice-fern'), hasLength(2), reason: 'alice\'s two ops went up under alice');
    expect(pushedIds, isNot(contains(stray.id)), reason: 'bob\'s op is not alice\'s to push (QA2 BUG-4 wrong actor)');
    expect(aliceRunner.current.pendingOps, 0);
    final strayLeft = (await pendingOps()).where((o) => o.entityId == stray.id).toList();
    expect(strayLeft, isNotEmpty);
    expect(strayLeft.map((o) => o.userId), everyElement('u-2'));
    await Future<void>.delayed(const Duration(milliseconds: 100));
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

  test('the active shared collection vanishing from the list is announced (not a silent move); a plain refresh is quiet', () async {
    await signInAlice();
    final notifier = container.read(collectionsProvider.notifier);
    final notices = <String?>[];
    container.listen<String?>(collectionGoneNoticeProvider, (_, next) => notices.add(next));
    await notifier.refresh();
    expect(notices, isEmpty, reason: 'nothing vanished');
    await notifier.switchCollection('col-2');
    final name = container.read(collectionsProvider).items.firstWhere((c) => c.id == 'col-2').displayName;
    serverCollections = [col('col-1', 'My plants')];
    await notifier.refresh();
    await waitFor(() => container.read(currentTenantIdProvider) == 'col-1', reason: 'reconciled to default');
    expect(notices, [name]);
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

  group('home collection no longer owned (MULTI-USER-V2 §2.8 transfer)', () {
    test('old owner = editor of the home: role/canEdit come from the server list; demoted to viewer under a push (403 read_only) → read-only, runner pull-only',
        () async {
      serverCollections = [
        col('col-1', 'My plants', role: 'editor', owner: 'u-2', members: 2),
        col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3),
      ];
      await signInAlice();
      var runner = await runnerOn('col-1');
      expect(container.read(activeCollectionIsSharedProvider), isTrue, reason: 'runs on the new owner\'s plan');
      expect(container.read(canEditActiveCollectionProvider), isTrue);
      expect(runner.readOnly, isFalse);
      expect(runner.entitlementIsOwners, isTrue);
      await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-1');

      // The new owner demotes alice; her next push races the change.
      serverCollections = [
        col('col-1', 'My plants', role: 'viewer', owner: 'u-2', members: 2),
        col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3),
      ];
      fakes['col-1']!.failures.add(const SyncCollectionError('read_only', status: 403));
      await container.read(plantRepositoryProvider).create(nickname: 'Edited before the demotion');
      await runner.syncNow();
      expect(runner.current.lastErrorDetail, kReadOnlyDetail);
      await waitFor(() => container.read(activeCollectionReadOnlyReasonProvider) == ReadOnlyReason.viewer,
          reason: 'home follows the server role like any collection');
      expect(container.read(canEditActiveCollectionProvider), isFalse);
      await waitFor(() {
        final r = container.read(syncRunnerProvider);
        return r is HttpSyncRunner && r.collectionId == 'col-1' && r.readOnly;
      }, reason: 'runner rebuilt pull-only');
      runner = container.read(syncRunnerProvider) as HttpSyncRunner;
      final pushesBefore = fakes['col-1']!.pushes.length;
      await runner.syncNow();
      expect(fakes['col-1']!.pushes.length, pushesBefore, reason: 'viewer never pushes');
      expect(fakes['col-1']!.pulls, isNotEmpty);
      expect(container.read(homeLossProvider), isNull, reason: 'still a member: not lost');
    });

    test('old owner without a plan of their own: the former home still pulls on the new owner\'s plan (read-only, §8)', () async {
      entitled = false;
      serverCollections = [col('col-1', 'My plants', role: 'editor', owner: 'u-2', members: 2)];
      container.read(cloudSyncCoordinatorProvider);
      await container.read(appContextProvider.future);
      await container.read(collectionLinkProvider.notifier).ready;
      final alice = await container.read(plantlyAuthProvider.notifier).adoptToken(aliceToken);
      container.read(signInEventsProvider).emit(alice);
      await waitFor(() => container.read(cloudStateProvider).linked, reason: 'linked without a plan');
      await waitFor(() => container.read(collectionsProvider).items.any((c) => c.id == 'col-1' && !c.isOwner));
      final runner = await runnerOn('col-1');
      expect(runner.readOnly, isTrue);
      expect(container.read(activeCollectionReadOnlyReasonProvider), ReadOnlyReason.cloudRequired);
    });

    test('403 not_a_member on the home (removed after a transfer): flagged lost, runner stops, local rows kept and editable; rehome → a new collection owns them, one whole-row op per live row for this account',
        () async {
      final fake = FakeSyncTabs()..autoGrant = true;
      tabs = fake;
      await signInAlice();
      var runner = await runnerOn('col-1');
      await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-1');
      final fern = await container.read(plantRepositoryProvider).create(nickname: 'Fern');
      await runner.syncNow();
      expect(fakes['col-1']!.pushes.expand((p) => p.ops).any((o) => o.entityId == fern.id), isTrue);
      expect(await opsIn('col-1', pendingOnly: true), 0);
      final rowsBefore = await plantsIn('col-1');
      final opsBefore = await opsIn('col-1');
      expect(rowsBefore, greaterThan(0));

      // The new owner removes alice from her former home.
      serverCollections = [col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3)];
      fakes['col-1']!.failures.add(const SyncCollectionError('not_a_member', status: 403));
      await runner.syncNow();
      await waitFor(() => container.read(homeLossProvider) != null, reason: 'home flagged lost');
      final loss = container.read(homeLossProvider)!;
      expect(loss.collectionId, 'col-1');
      expect(loss.reason, HomeLossReason.removed);
      expect(loss.name, 'My plants');
      expect(container.read(homeLostNoticeProvider)?.collectionId, 'col-1', reason: 'one-shot notice');
      expect(container.read(collectionRemovedNoticeProvider), isNull, reason: 'not the shared-collection path');
      expect(container.read(currentTenantIdProvider), 'col-1', reason: 'stays on the local data');
      await waitFor(() => container.read(syncRunnerProvider) is NoopSyncRunner,
          reason: 'no runner looping against a collection we lost');
      expect(container.read(canEditActiveCollectionProvider), isTrue, reason: 'local data stays editable');
      expect(await plantsIn('col-1'), rowsBefore, reason: 'nothing deleted');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kHomeLossPrefKey), isNotNull, reason: 'survives a restart');
      final t = lookupAppLocalizations(const Locale('en'));
      expect(describeHomeLoss(t, loss), contains('My plants'));

      // Edits made while lost are kept and travel with the rows.
      final ivy = await container.read(plantRepositoryProvider).create(nickname: 'Ivy (offline)');

      // A historical op another member pushed (pulled: user NULL, foreign device).
      await db.customStatement(
          "INSERT INTO sync_ops (tenant_id, entity, entity_id, field, hlc, device_id, value_json, pushed_at) "
          "VALUES ('col-1', 'plants', '${fern.id}', 'nickname', '00000000000001-00000-bobdev', 'bobdev', '\"Bob\"', 1)");

      // "Move your plants into …": the account owns no other collection →
      // the server creates one; the dialog has no target to name.
      expect(container.read(collectionsProvider.notifier).rehomeTarget, isNull);
      aliceDefault = {'id': 'col-9', 'name': 'My plants', 'role': 'owner'};
      serverCollections = [col('col-9', 'My plants'), ...serverCollections];
      final link = await container.read(collectionsProvider.notifier).rehome();
      expect(link.id, 'col-9');
      expect(container.read(cloudStateProvider).collectionId, 'col-9');
      expect(container.read(currentTenantIdProvider), 'col-9');
      expect(await plantsIn('col-9'), rowsBefore + 1);
      expect(await plantsIn('col-1'), 0);
      expect(container.read(homeLossProvider), isNull);
      expect(prefs.getString(kHomeLossPrefKey), isNull);
      expect(fake.posted.map((m) => m.kind), contains(SyncTabMessageKind.reload), reason: 'other tabs reload');
      runner = await runnerOn('col-9');
      await runner.syncNow();
      final pushed = fakes['col-9']!.pushes.expand((p) => p.ops).toList();
      expect(pushed.map((o) => o.entityId), containsAll([fern.id, ivy.id]), reason: 'every live row uploaded');
      expect(pushed.every((o) => o.field == '*'), isTrue,
          reason: 'a snapshot per row, not the old op history (other members\' ops are not replayed as ours)');
      final keys = pushed.map((o) => '${o.entity}/${o.entityId}').toList();
      expect(keys.toSet().length, keys.length, reason: 'one op per row');
      expect(pushed.where((o) => o.entityId == fern.id).single.value, isA<Map>());
      final foreign = await db.customSelect(
          "SELECT COUNT(*) AS n FROM sync_ops WHERE tenant_id = 'col-9' AND (user_id IS NULL OR user_id <> 'u-1')").getSingle();
      expect(foreign.read<int>('n'), 0, reason: 'everything in the new collection is stamped with this account');
      expect(await opsIn('col-9', pendingOnly: true), 0);
      expect(opsBefore, greaterThan(0));
      expect(fakes['col-1']!.pushes.expand((p) => p.ops).where((o) => o.entityId == ivy.id), isEmpty,
          reason: 'never pushed into the lost collection');
    });

    test('rehome target = the OLDEST owned live collection (may be shared): named before anything moves', () async {
      await signInAlice();
      final runner = await runnerOn('col-1');
      serverCollections = [
        {...col('col-7', 'Shared jungle', members: 3), 'created_at': '2026-03-01T00:00:00Z'},
        {...col('col-8', 'Newer', members: 1), 'created_at': '2026-05-01T00:00:00Z'},
        col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3),
      ];
      fakes['col-1']!.failures.add(const SyncCollectionError('not_a_member', status: 403));
      await runner.syncNow();
      await waitFor(() => container.read(homeLossProvider) != null);
      final target = container.read(collectionsProvider.notifier).rehomeTarget!;
      expect(target.id, 'col-7');
      expect(target.memberCount, 3);
      aliceDefault = {'id': 'col-7', 'name': 'Shared jungle', 'role': 'owner'};
      final link = await container.read(collectionsProvider.notifier).rehome();
      expect(link.id, 'col-7');
      expect(container.read(currentTenantIdProvider), 'col-7');
    });

    test('offline re-check: a failed list fetch never flags the home; retried, settled by the next successful fetch', () async {
      await signInAlice();
      final runner = await runnerOn('col-1');
      serverCollections = [col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3)];
      failCollections = true;
      fakes['col-1']!.failures.add(const SyncCollectionError('not_a_member', status: 403));
      await runner.syncNow();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(container.read(homeLossProvider), isNull, reason: 'not concluded from a failed fetch');
      expect(container.read(homeLostNoticeProvider), isNull);
      failCollections = false;
      await waitFor(() => container.read(homeLossProvider) != null, reason: 'retried with backoff, then confirmed');
      expect(container.read(homeLossProvider)!.reason, HomeLossReason.removed);
    });

    test('410 collection_deleted on the home (deleted / purged): lost (deleted); a list that names it again clears the flag', () async {
      await signInAlice();
      final runner = await runnerOn('col-1');
      serverCollections = [col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3)];
      fakes['col-1']!.failures.add(const SyncCollectionError('collection_deleted', status: 410));
      await runner.syncNow();
      await waitFor(() => container.read(homeLossProvider) != null);
      expect(container.read(homeLossProvider)!.reason, HomeLossReason.deleted);
      expect(container.read(collectionsProvider).items.map((c) => c.id), contains('col-1'),
          reason: 'home stays reachable in the switcher (local data)');

      // Switching away and back home works; nothing syncs against the lost home.
      await container.read(collectionsProvider.notifier).switchCollection('col-2');
      await runnerOn('col-2');
      await container.read(collectionsProvider.notifier).switchCollection('col-1');
      await waitFor(() => container.read(syncRunnerProvider) is NoopSyncRunner);

      // Restored server-side (reactivation within the purge window): the list names it again.
      serverCollections = [col('col-1', 'My plants'), ...serverCollections];
      await container.read(collectionsProvider.notifier).refresh();
      expect(container.read(homeLossProvider), isNull);
      await runnerOn('col-1');
    });

    test('a persisted loss is restored on the next boot (before any sync)', () async {
      await signInAlice();
      final runner = await runnerOn('col-1');
      serverCollections = [col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3)];
      fakes['col-1']!.failures.add(const SyncCollectionError('not_a_member', status: 403));
      await runner.syncNow();
      await waitFor(() => container.read(homeLossProvider) != null);
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kHomeLossPrefKey)!;
      final decoded = HomeLoss.fromJson(json.decode(raw) as Map<String, dynamic>);
      expect(decoded.collectionId, 'col-1');
      expect(decoded.reason, HomeLossReason.removed);
    });
  });

  group('browser tabs (one runner per collection across tabs)', () {
    test('another tab holds the lock: this tab follows (forwards writes + sync now, mirrors status, never talks to the server); lock granted → real runner, peer writes trigger its push',
        () async {
      final fake = FakeSyncTabs();
      tabs = fake;
      await signInAlice();
      await waitFor(() => container.read(syncRunnerProvider) is FollowerSyncRunner, reason: 'not the leader yet');
      final follower = container.read(syncRunnerProvider) as FollowerSyncRunner;
      expect(fake.posted.map((m) => m.kind), contains(SyncTabMessageKind.hello));
      await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-1');

      await container.read(plantRepositoryProvider).create(nickname: 'Written in a follower tab');
      await waitFor(() => fake.posted.any((m) => m.kind == SyncTabMessageKind.changed && m.collectionId == 'col-1'));
      await follower.syncNow();
      expect(fake.posted.last.kind, SyncTabMessageKind.syncNow);
      fake.deliver(const SyncTabMessage(SyncTabMessageKind.status, 'col-1', status: SyncStatus(pendingOps: 4)));
      await waitFor(() => follower.current.pendingOps == 4, reason: 'leader status mirrored');
      expect(fakes['col-1']?.pushes ?? const [], isEmpty, reason: 'only the leading tab syncs');

      // The leading tab closes: the lock passes here.
      fake.grant('col-1');
      final runner = await runnerOn('col-1');
      await waitFor(() => fakes['col-1']!.pushes.isNotEmpty, reason: 'pending ops of this tab pushed');
      final before = fakes['col-1']!.pushes.length;
      // Another tab (now a follower) writes into the shared database.
      await db.customStatement("UPDATE sync_ops SET pushed_at = NULL WHERE seq = (SELECT MAX(seq) FROM sync_ops)");
      fake.deliver(const SyncTabMessage(SyncTabMessageKind.changed, 'col-1'));
      await waitFor(() => fakes['col-1']!.pushes.length > before, reason: 'peer change debounced into a push');
      expect(fake.posted.any((m) => m.kind == SyncTabMessageKind.status && m.collectionId == 'col-1'), isTrue,
          reason: 'leader publishes its status');
      fake.deliver(const SyncTabMessage(SyncTabMessageKind.hello, 'col-1'));
      await waitFor(() => fake.posted.last.kind == SyncTabMessageKind.status);
      expect(runner.collectionId, 'col-1');
    });

    test('clocks across tabs: every message carries the sender\'s latest HLC and every tab merges it', () async {
      final fake = FakeSyncTabs();
      tabs = fake;
      await signInAlice();
      await waitFor(() => container.read(syncRunnerProvider) is FollowerSyncRunner);
      final ctx = await container.read(appContextProvider.future);
      await waitFor(() => ctx.tenantId == 'col-1' || container.read(appContextProvider).requireValue.tenantId == 'col-1');
      final clock = container.read(appContextProvider).requireValue.clock;
      // The leader is ahead (it just pulled): its status stamp is merged here.
      final ahead = Hlc(DateTime.now().toUtc().millisecondsSinceEpoch + 60000, 7, 'dev-x');
      fake.deliver(SyncTabMessage(SyncTabMessageKind.status, 'col-1', status: SyncStatus.empty, hlc: ahead.encode()));
      await waitFor(() => (clock.latest?.compareTo(ahead) ?? -1) >= 0, reason: 'follower merged the leader\'s HLC');
      final p = await container.read(plantRepositoryProvider).create(nickname: 'After the merge');
      final row = await db.customSelect("SELECT updated_hlc FROM plants WHERE id = ?", variables: [Variable<String>(p.id)]).getSingle();
      expect(Hlc.parse(row.read<String>('updated_hlc')) > ahead, isTrue, reason: 'the next local edit sorts after it');
      await waitFor(() => fake.posted.any((m) => m.kind == SyncTabMessageKind.changed && m.hlc != null));
      final sent = fake.posted.lastWhere((m) => m.kind == SyncTabMessageKind.changed);
      expect(Hlc.parse(sent.hlc!) > ahead, isTrue, reason: 'the follower shares its own latest stamp');
      // Malformed stamps are ignored.
      fake.deliver(const SyncTabMessage(SyncTabMessageKind.changed, 'col-1', hlc: 'garbage'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });

    test('leader shares its HLC right after each applied batch (followers merge before showing pulled rows)', () async {
      final fake = FakeSyncTabs()..autoGrant = true;
      tabs = fake;
      await signInAlice();
      await runnerOn('col-1');
      final clock = container.read(appContextProvider).requireValue.clock;
      final ahead = Hlc(DateTime.now().toUtc().millisecondsSinceEpoch + 30000, 2, 'peer');
      clock.merge(ahead); // what the applier does for a pulled op …
      fake.posted.clear();
      // … then records it in sync_ops.
      await db.customStatement(
          "INSERT INTO sync_ops (tenant_id, entity, entity_id, field, hlc, device_id, value_json, pushed_at) "
          "VALUES ('col-1', 'plants', 'p-x', 'nickname', '${ahead.encode()}', 'peer', '\"x\"', 1)");
      await waitFor(() => fake.posted.any((m) => m.kind == SyncTabMessageKind.status && m.hlc != null));
      final m = fake.posted.firstWhere((m) => m.kind == SyncTabMessageKind.status && m.hlc != null);
      expect(Hlc.parse(m.hlc!) > ahead, isTrue);
    });

    test('switching collection releases the lock of the old one', () async {
      final fake = FakeSyncTabs()..autoGrant = true;
      tabs = fake;
      await signInAlice();
      await runnerOn('col-1');
      await container.read(collectionsProvider.notifier).switchCollection('col-2');
      await runnerOn('col-2');
      await waitFor(() => fake.released.contains('col-1'));
      expect(fake.released, isNot(contains('col-2')));
    });
  });
}

class FakeSyncTabs implements SyncTabs {
  final Map<String, Completer<void>> _grants = {};
  final List<SyncTabMessage> posted = [];
  final List<String> released = [];
  final _messages = StreamController<SyncTabMessage>.broadcast();
  bool autoGrant = false;

  void grant(String id) {
    final c = _grants[id];
    if (c != null && !c.isCompleted) c.complete();
  }

  void deliver(SyncTabMessage m) => _messages.add(m);

  @override
  SyncLease acquire(String collectionId) {
    final c = _grants[collectionId] = Completer<void>();
    if (autoGrant) c.complete();
    return SyncLease(granted: c.future, onRelease: () => released.add(collectionId), grantedNow: autoGrant);
  }

  @override
  Stream<SyncTabMessage> get messages => _messages.stream;

  @override
  void post(SyncTabMessage message) => posted.add(message);
}
