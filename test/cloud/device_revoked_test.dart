// MULTI-USER-V2 §2.12 / §3 — runner halts that the collections layer turns
// into account-level actions: 403 `device_revoked` signs the cloud session
// out (+ one-shot notice); 410 `collection_deleted` / 404
// `collection_not_found` on any collection but the linked home drop it
// like a removal; 403 `read_only` refetches the list so the role flip
// rebuilds the runner pull-only; session loss (sign-out / revoke) while
// parked on a shared tenant goes back home first.
// Container setup mirrors `collections_test.dart`.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/sign_in_events.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
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
  late List<Map<String, dynamic>> serverCollections;
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
    requests = [];
    fakes = {};
    serverCollections = [
      col('col-1', 'My plants'),
      col('col-2', 'Family greenhouse', role: 'editor', owner: 'u-2', members: 3),
      col('col-3', 'Office jungle', role: 'viewer', owner: 'u-3', members: 4),
      // An owned collection that is NOT the linked default (created on
      // the web / another device).
      col('col-4', 'Balcony', members: 1),
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
                'is_pro': true,
                'entitlements': {
                  'inventory_cloud': {'active': true, 'source': 'pro'},
                },
              });
            }
            if (req.method == 'POST' && path.endsWith('/inventory/collections/default')) {
              return jsonRes({
                'collection': uid == 'u-2'
                    ? {'id': 'col-5', 'name': "Bob's plants", 'role': 'owner'}
                    : {'id': 'col-1', 'name': 'My plants', 'role': 'owner'},
              });
            }
            if (req.method == 'GET' && path.endsWith('/inventory/collections')) {
              return jsonRes({'collections': serverCollections});
            }
            if (req.method == 'POST' && path.endsWith('/auth/logout')) {
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

  Future<HttpSyncRunner> runnerFor(String collectionId) async {
    await waitFor(
      () =>
          container.read(syncRunnerProvider) is HttpSyncRunner &&
          (container.read(syncRunnerProvider) as HttpSyncRunner).collectionId == collectionId,
      reason: 'runner bound to $collectionId',
    );
    return container.read(syncRunnerProvider) as HttpSyncRunner;
  }

  test('403 device_revoked on push → cloud session signed out + one-shot notice raised', () async {
    await signInAlice();
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNotNull);
    expect(container.read(deviceRevokedNoticeProvider), isFalse);

    final runner = await runnerFor('col-1');
    fakes['col-1']!.failures.add(const SyncCollectionError('device_revoked', status: 403));
    await runner.syncNow();

    await waitFor(() => container.read(deviceRevokedNoticeProvider), reason: 'device-revoked notice');
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNull, reason: 'session dropped');
    expect(container.read(plantlyAuthProvider).valueOrNull, isNull);
    await waitFor(() => container.read(cloudStateProvider).phase == CloudPhase.signedOut, reason: 'cloud state follows');
    // Not a collection removal: the shared list is untouched and no
    // "removed from" notice fires.
    expect(container.read(collectionRemovedNoticeProvider), isNull);
  });

  test('403 device_revoked while on a SHARED collection also signs out (not treated as removal)', () async {
    await signInAlice();
    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    final runner = await runnerFor('col-2');
    fakes['col-2']!.failures.add(const SyncCollectionError('device_revoked', status: 403));
    await runner.syncNow();

    await waitFor(() => container.read(deviceRevokedNoticeProvider), reason: 'device-revoked notice');
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNull);
    expect(container.read(collectionRemovedNoticeProvider), isNull, reason: 'not a removal');
    await waitFor(() => container.read(cloudStateProvider).phase == CloudPhase.signedOut);
  });

  test('410 collection_deleted on a SHARED collection → dropped from the list, notice carries its name', () async {
    await signInAlice();
    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    expect(container.read(currentTenantIdProvider), 'col-2');
    final runner = await runnerFor('col-2');
    fakes['col-2']!.failures.add(const SyncCollectionError('collection_deleted', status: 410));
    await runner.syncNow();

    await waitFor(() => container.read(collectionRemovedNoticeProvider) != null, reason: 'removed notice');
    expect(container.read(collectionRemovedNoticeProvider), 'Family greenhouse');
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1', 'col-4', 'col-3']);
    await waitFor(() => container.read(currentTenantIdProvider) == 'col-1', reason: 'fell back to the linked default');
    // The account itself is untouched.
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNotNull);
    expect(container.read(deviceRevokedNoticeProvider), isFalse);
  });

  test('404 collection_not_found on a SHARED collection → same removal path', () async {
    await signInAlice();
    await container.read(collectionsProvider.notifier).switchCollection('col-2');
    final runner = await runnerFor('col-2');
    fakes['col-2']!.failures.add(const SyncCollectionError(kCollectionNotFoundDetail, status: 404));
    await runner.syncNow();

    await waitFor(() => container.read(collectionRemovedNoticeProvider) != null, reason: 'removed notice');
    expect(container.read(collectionRemovedNoticeProvider), 'Family greenhouse');
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1', 'col-4', 'col-3']);
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNotNull);
  });

  test('410 on the OWN default collection is not a removal (list + session untouched)', () async {
    await signInAlice();
    final runner = await runnerFor('col-1');
    fakes['col-1']!.failures.add(const SyncCollectionError('collection_deleted', status: 410));
    await runner.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(container.read(collectionRemovedNoticeProvider), isNull);
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1', 'col-4', 'col-2', 'col-3']);
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNotNull);
  });

  test('410 on an OWNED non-default collection → removed + fallback home (only the linked home is exempt)', () async {
    await signInAlice();
    await container.read(collectionsProvider.notifier).switchCollection('col-4');
    expect(container.read(currentTenantIdProvider), 'col-4');
    final runner = await runnerFor('col-4');
    fakes['col-4']!.failures.add(const SyncCollectionError('collection_deleted', status: 410));
    await runner.syncNow();

    await waitFor(() => container.read(collectionRemovedNoticeProvider) != null, reason: 'removed notice');
    expect(container.read(collectionRemovedNoticeProvider), 'Balcony');
    expect(container.read(collectionsProvider).items.map((c) => c.id), ['col-1', 'col-2', 'col-3']);
    await waitFor(() => container.read(currentTenantIdProvider) == 'col-1', reason: 'fell back to the linked default');
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNotNull);
    expect(container.read(deviceRevokedNoticeProvider), isFalse);
  });

  group('session loss while parked on a shared tenant', () {
    test('viewer on col-3 → sign out → tenant is home (col-1) and editable again', () async {
      await signInAlice();
      await container.read(collectionsProvider.notifier).switchCollection('col-3');
      expect(container.read(currentTenantIdProvider), 'col-3');
      expect(container.read(canEditActiveCollectionProvider), isFalse, reason: 'viewer');

      await container.read(plantlyAuthProvider.notifier).signOut();

      await waitFor(() => container.read(currentTenantIdProvider) == 'col-1', reason: 'went home on sign-out');
      await waitFor(() => container.read(cloudStateProvider).phase == CloudPhase.signedOut);
      expect(container.read(collectionsProvider).items, isEmpty, reason: 'list cleared after the fallback');
      expect(container.read(canEditActiveCollectionProvider), isTrue, reason: 'home is always editable');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kTenantIdPrefKey), 'col-1', reason: 'persisted — survives a restart');
    });

    test('editor on col-2 → sign out → same fallback (any non-owned tenant)', () async {
      await signInAlice();
      await container.read(collectionsProvider.notifier).switchCollection('col-2');
      await container.read(plantlyAuthProvider.notifier).signOut();
      await waitFor(() => container.read(currentTenantIdProvider) == 'col-1', reason: 'went home');
    });

    test('owned non-default (col-4) → sign out → stays (it is the account\'s own data)', () async {
      await signInAlice();
      await container.read(collectionsProvider.notifier).switchCollection('col-4');
      await container.read(plantlyAuthProvider.notifier).signOut();
      await waitFor(() => container.read(cloudStateProvider).phase == CloudPhase.signedOut);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(container.read(currentTenantIdProvider), 'col-4');
    });

    test('403 device_revoked while viewer on col-3 → tenant is home before the session drops', () async {
      await signInAlice();
      await container.read(collectionsProvider.notifier).switchCollection('col-3');
      final runner = await runnerFor('col-3');
      expect(runner.readOnly, isTrue, reason: 'viewer runner is pull-only');
      fakes['col-3']!.failures.add(const SyncCollectionError('device_revoked', status: 403));
      await runner.syncNow();

      await waitFor(() => container.read(deviceRevokedNoticeProvider), reason: 'device-revoked notice');
      expect(container.read(currentTenantIdProvider), 'col-1', reason: 'flipped home before sign-out');
      expect(await container.read(plantlyAuthProvider.notifier).current(), isNull);
      expect(container.read(canEditActiveCollectionProvider), isTrue);
      expect(container.read(collectionRemovedNoticeProvider), isNull, reason: 'not a removal');
    });
  });

  group('403 read_only (role downgraded under a push)', () {
    test('list refetched → role flips to viewer → canEdit false → runner rebuilt read-only', () async {
      await signInAlice();
      await container.read(collectionsProvider.notifier).switchCollection('col-2');
      final runner = await runnerFor('col-2');
      expect(runner.readOnly, isFalse, reason: 'editor pushes');
      expect(container.read(canEditActiveCollectionProvider), isTrue);
      final fetchesBefore = container.read(collectionsProvider.notifier).fetches;

      // The owner downgraded us meanwhile: the server now says viewer.
      serverCollections[1] = col('col-2', 'Family greenhouse', role: 'viewer', owner: 'u-2', members: 3);
      fakes['col-2']!.failures.add(const SyncCollectionError(kReadOnlyDetail, status: 403));
      await runner.syncNow();
      expect(runner.current.lastError, 'collection_unavailable');
      expect(runner.current.lastErrorDetail, kReadOnlyDetail);

      await waitFor(() => container.read(collectionsProvider.notifier).fetches > fetchesBefore, reason: 'list refetched');
      await waitFor(() => container.read(collectionsProvider).byId('col-2')?.role == 'viewer', reason: 'role flipped');
      expect(container.read(canEditActiveCollectionProvider), isFalse, reason: 'banner + gates follow');
      await waitFor(
        () => container.read(syncRunnerProvider) is HttpSyncRunner && (container.read(syncRunnerProvider) as HttpSyncRunner).readOnly,
        reason: 'runner rebuilt pull-only',
      );
      expect(identical(container.read(syncRunnerProvider), runner), isFalse);
      expect(container.read(currentTenantIdProvider), 'col-2', reason: 'still on the collection, just read-only');
      expect(container.read(collectionRemovedNoticeProvider), isNull);
    });
  });

  test('503 device_lookup_failed → retrying, with the server code as the detail', () async {
    await signInAlice();
    final runner = await runnerFor('col-1');
    fakes['col-1']!.failures.add(const SyncRetryableError(kDeviceLookupFailedDetail, status: 503));
    await runner.syncNow();
    expect(runner.current.lastError, 'retrying');
    expect(runner.current.lastErrorDetail, kDeviceLookupFailedDetail);
  });
}
