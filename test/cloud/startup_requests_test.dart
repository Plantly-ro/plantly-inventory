// App start with a stored session and a persisted link (a reload, a cold
// start): exactly one `GET /inventory/collections` and one sync cycle —
// the account / link resolving after the providers were built must not
// read as a "change" that refetches or re-syncs (QA finding l).
import 'dart:async' show Completer;
import 'dart:convert';

import 'package:drift/drift.dart' show LazyDatabase;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/sync/http_sync_runner.dart';
import 'package:plantly_inventory/sync/sync_providers.dart';
import 'package:plantly_inventory/sync/sync_tabs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;
import '../sync/http_sync_runner_test.dart' show ScriptedTransport;
import 'collections_test.dart' show FakeSyncTabs;
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
  late List<http.Request> requests;
  late Map<String, ScriptedTransport> fakes;
  late ProviderContainer container;

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  ProviderContainer boot({String? token, SyncRunnerConfig cfg = config, SyncTabs tabs = SyncTabs.single}) =>
      ProviderContainer(overrides: [
        cloudEnabledProvider.overrideWithValue(true),
        databaseProvider.overrideWithValue(db),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
        notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
        photoBlobStoreProvider.overrideWithValue(InMemoryPhotoBlobStore()),
        syncRunnerConfigProvider.overrideWithValue(cfg),
        syncTabsProvider.overrideWith((_) => tabs),
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
              if (req.method == 'GET' && path.endsWith('/subscriptions/me')) {
                return jsonRes({
                  'is_pro': true,
                  'entitlements': {
                    'inventory_cloud': {'active': true, 'source': 'pro'},
                  },
                });
              }
              if (req.method == 'POST' && path.endsWith('/inventory/collections/default')) {
                return jsonRes({
                  'collection': {'id': 'col-1', 'name': 'My plants', 'role': 'owner'},
                });
              }
              if (req.method == 'GET' && path.endsWith('/inventory/collections')) {
                return jsonRes({
                  'collections': [
                    {'id': 'col-1', 'name': 'My plants', 'role': 'owner', 'owner_user_id': 'u-1', 'member_count': 1},
                  ],
                });
              }
              return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
            })),
      ]);

  setUp(() {
    // What a previous session left behind: linked to col-1 for alice.
    SharedPreferences.setMockInitialValues({
      kSkipSeedPrefKey: true,
      kTenantIdPrefKey: 'col-1',
      kCollectionIdPrefKey: 'col-1',
      kCollectionNamePrefKey: 'My plants',
      kCollectionUserIdPrefKey: 'u-1',
      kCollectionUsernamePrefKey: 'alice',
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    requests = [];
    fakes = {};
  });

  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.close();
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  int listFetches() =>
      requests.where((r) => r.method == 'GET' && r.url.path.endsWith('/inventory/collections')).length;

  test('boot with a stored session + link: one collections fetch, one sync cycle', () async {
    container = boot(token: aliceToken);
    // What `PlantlyApp` keeps alive for the session.
    container.read(cloudSyncCoordinatorProvider);
    final notifier = container.read(collectionsProvider.notifier);
    await waitFor(() => container.read(cloudStateProvider).canSync, reason: 'linked + entitled');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner, reason: 'runner started');
    await waitFor(() => fakes['col-1']?.pulls.isNotEmpty ?? false, reason: 'first cycle pulled');
    // Well past every debounce / follow-up window.
    await Future<void>.delayed(config.linkDebounce * 10 + config.debounce * 4);

    expect(listFetches(), 1, reason: 'account + link resolving at boot is not a change');
    expect(notifier.fetches, 1);
    expect(fakes['col-1']!.pulls, hasLength(1), reason: 'one startup cycle, not start + link-change sync');
  });

  test('the link resolving after the session (slow database at boot) is not a second fetch', () async {
    // The link store checks the data-owner marker against the database
    // before it reports the link: hold the database so the session (and
    // with it the account) is known well before the link.
    final gate = Completer<void>();
    db = AppDatabase.forTesting(LazyDatabase(() async {
      await gate.future;
      return NativeDatabase.memory();
    }));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kDataOwnerUserIdPrefKey, 'u-1');
    await prefs.setString(kDataOwnerUsernamePrefKey, 'alice');
    container = boot(token: aliceToken);
    container.read(cloudSyncCoordinatorProvider);
    final notifier = container.read(collectionsProvider.notifier);
    await waitFor(() => container.read(cloudStateProvider).account == 'alice', reason: 'session resolved');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(container.read(cloudStateProvider).linked, isFalse, reason: 'link still loading');
    expect(listFetches(), 0, reason: 'the first fetch waits for the link instead of refetching when it lands');

    gate.complete();
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner, reason: 'runner started');
    await waitFor(() => fakes['col-1']?.pulls.isNotEmpty ?? false);
    await Future<void>.delayed(config.linkDebounce * 10 + config.debounce * 4);
    expect(listFetches(), 1);
    expect(notifier.fetches, 1);
    expect(fakes['col-1']!.pulls, hasLength(1));
  });

  test('a real link change after boot still refetches the list and syncs', () async {
    container = boot(token: aliceToken);
    container.read(cloudSyncCoordinatorProvider);
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner, reason: 'runner started');
    await waitFor(() => listFetches() == 1);
    await Future<void>.delayed(config.linkDebounce * 10);

    // Unlink → the list stays for the account; re-link → refetched (the
    // server just created / returned the default).
    await container.read(collectionLinkProvider.notifier).unlink();
    await waitFor(() => !container.read(cloudStateProvider).linked);
    await container.read(collectionLinkProvider.notifier).link();
    await waitFor(() => container.read(cloudStateProvider).linked);
    await waitFor(() => listFetches() >= 2, reason: 'new link → list refetched');
    await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner);
    final pullsBefore = fakes['col-1']!.pulls.length;
    await (container.read(syncRunnerProvider) as HttpSyncRunner).syncNow();
    expect(fakes['col-1']!.pulls.length, greaterThan(pullsBefore));
  });
  group('tab hidden / app backgrounded: pending writes pushed without waiting for the debounce', () {
    // Long enough that only the flush can explain a push inside the test.
    const slow = SyncRunnerConfig(
      debounce: Duration(seconds: 30),
      periodic: Duration.zero,
      minBackoff: Duration(milliseconds: 30),
      maxBackoff: Duration(milliseconds: 120),
      linkDebounce: Duration(milliseconds: 20),
    );

    void hide() {
      final binding = TestWidgetsFlutterBinding.instance;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    }

    test('leading tab: a fresh write is pushed as soon as the page is hidden', () async {
      container = boot(token: aliceToken, cfg: slow);
      container.read(cloudSyncCoordinatorProvider);
      await waitFor(() => container.read(syncRunnerProvider) is HttpSyncRunner, reason: 'runner started');
      await waitFor(() => fakes['col-1']?.pulls.isNotEmpty ?? false, reason: 'startup cycle');
      await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-1');
      final fern = await container.read(plantRepositoryProvider).create(nickname: 'Fern');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(fakes['col-1']!.pushes, isEmpty, reason: 'still inside the debounce');

      hide();
      await waitFor(() => fakes['col-1']!.pushes.isNotEmpty, timeout: const Duration(seconds: 2), reason: 'flushed on hide');
      expect(fakes['col-1']!.pushes.expand((p) => p.ops).any((o) => o.entityId == fern.id), isTrue);
    });

    test('a following tab never pushes, hidden or not (its writes go to the leader)', () async {
      final tabs = FakeSyncTabs(); // another tab holds the lock
      container = boot(token: aliceToken, cfg: slow, tabs: tabs);
      container.read(cloudSyncCoordinatorProvider);
      await waitFor(() => container.read(syncRunnerProvider) is FollowerSyncRunner, reason: 'follower');
      await waitFor(() => container.read(appContextProvider).requireValue.tenantId == 'col-1');
      await container.read(plantRepositoryProvider).create(nickname: 'Fern');
      await waitFor(() => tabs.posted.any((m) => m.kind == SyncTabMessageKind.changed), reason: 'forwarded');

      hide();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(fakes['col-1']?.pushes ?? const [], isEmpty);
      expect(fakes['col-1']?.pulls ?? const [], isEmpty);
    });
  });
}
