// Activity feed (MULTI-USER-V2 §0/§2.11) — wire parsing, the per-collection
// cache, paging through the notifier against a scripted HTTP layer, and
// the `shared_access` entitlement block (§2.13).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/collection_activity.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;
import 'cloud_flow_test.dart' show waitFor;
import 'cloud_state_test.dart' show FixedEntitlement;

Map<String, dynamic> wireEvent(
  int seq, {
  String userId = 'u-2',
  String username = 'maria',
  String entity = 'plants',
  String entityId = 'p-1',
  String kind = 'created',
  String? name = 'Monstera',
  DateTime? at,
}) =>
    {
      'seq': seq,
      'at': (at ?? DateTime.utc(2026, 10, 3, 12).add(Duration(seconds: seq))).toIso8601String(),
      'user': {'id': userId, 'username': username},
      'device_id': 'd-2',
      'entity': entity,
      'entity_id': entityId,
      'kind': kind,
      'fields': ['name'],
      if (name != null) 'summary': {'name': name},
    };

ActivityEvent ev(
  int seq, {
  String userId = 'u-2',
  String username = 'maria',
  String entity = 'plants',
  String entityId = 'p-1',
  ActivityKind kind = ActivityKind.created,
  String? name = 'Monstera',
  DateTime? at,
}) =>
    ActivityEvent(
      seq: seq,
      at: at ?? DateTime.utc(2026, 10, 3, 12).add(Duration(seconds: seq)),
      user: ActivityUser(id: userId, username: username),
      entity: entity,
      entityId: entityId,
      kind: kind,
      summaryName: name,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final token = fakeJwt(iat: nowSecs, exp: nowSecs + 86400);

  group('wire model (§2.11)', () {
    test('ActivityPage.fromJson: sorts newest first, drops rows without seq, reads next_before', () {
      final page = ActivityPage.fromJson({
        'events': [
          wireEvent(3),
          {'seq': 'nope'},
          'garbage',
          wireEvent(7, kind: 'deleted', name: null),
          wireEvent(5, kind: 'updated', entity: 'locations', entityId: 'l-1', name: 'Living room'),
        ],
        'next_before': 3,
      });
      expect(page.events.map((e) => e.seq), [7, 5, 3]);
      expect(page.hasMore, isTrue);
      expect(page.nextBefore, 3);
      expect(page.events.first.kind, ActivityKind.deleted);
      expect(page.events.first.summaryName, isNull);
      expect(page.events[1].entity, 'locations');
      expect(page.events[1].summaryName, 'Living room');
      expect(page.events.last.user.username, 'maria');
      expect(page.events.last.fields, ['name']);
      expect(page.events.last.deviceId, 'd-2');
    });

    test('next_before null / 0 / absent → no more; non-object body → empty page', () {
      expect(ActivityPage.fromJson({'events': [], 'next_before': null}).hasMore, isFalse);
      expect(ActivityPage.fromJson({'events': [], 'next_before': 0}).hasMore, isFalse);
      expect(ActivityPage.fromJson({'events': []}).hasMore, isFalse);
      expect(ActivityPage.fromJson(['x']).events, isEmpty);
      expect(ActivityPage.fromJson(null).events, isEmpty);
    });

    test('missing / garbage `at` → null (never 1970); username and id are trimmed', () {
      final raw = wireEvent(4)..remove('at');
      expect(ActivityEvent.tryParse(raw)!.at, isNull);
      expect(ActivityEvent.tryParse({...wireEvent(4), 'at': 'yesterday-ish'})!.at, isNull);
      expect(ActivityEvent.tryParse({...wireEvent(4), 'at': 12345})!.at, isNull);
      final back = ActivityEvent.tryParse(json.decode(json.encode(ActivityEvent.tryParse(raw)!.toJson())))!;
      expect(back.at, isNull, reason: 'cache round-trip keeps it unknown');
      final padded = ActivityEvent.tryParse({...wireEvent(4), 'user': {'id': ' u-2 ', 'username': '  maria '}})!;
      expect(padded.user, const ActivityUser(id: 'u-2', username: 'maria'));
    });

    test('unknown kind → updated; round-trips through toJson', () {
      final e = ActivityEvent.tryParse(wireEvent(9, kind: 'weird'))!;
      expect(e.kind, ActivityKind.updated);
      final back = ActivityEvent.tryParse(json.decode(json.encode(e.toJson())))!;
      expect(back.seq, 9);
      expect(back.at, e.at);
      expect(back.user, e.user);
      expect(back.entity, e.entity);
      expect(back.entityId, e.entityId);
      expect(back.kind, ActivityKind.updated);
      expect(back.summaryName, 'Monstera');
      expect(back.deviceId, 'd-2');
    });
  });

  group('shared_access entitlement (§2.13, informational since §8)', () {
    test('absent → inactive; it never adds up to access of its own', () {
      final none = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {'active': false, 'source': null},
        },
      });
      expect(none.sharedAccess, SharedAccess.none);
      expect(none.sharedAccess.active, isFalse);
      expect(none.active, isFalse);

      final own = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {'active': true, 'source': 'pro'},
        },
      });
      expect(own.active, isTrue);
      expect(own.sharedAccess.active, isFalse);

      // Legacy server (no entitlements block) → none either.
      expect(CloudEntitlement.fromSubscriptionJson({'is_pro': false}).sharedAccess, SharedAccess.none);
      expect(CloudEntitlement.none.active, isFalse);
    });

    test('present → parsed for display; `active` stays the caller\'s own verdict; prefs round-trip', () {
      final e = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {
            'active': false,
            'source': null,
            'shared_access': {'active': true, 'collections': 2},
          },
        },
      });
      expect(e.active, isFalse, reason: '§8: shared access grants nothing');
      expect(e.sharedAccess, const SharedAccess(active: true, collections: 2));
      expect(e.sharedAccess.active, isTrue);
      expect(e.sharedAccess.collections, 2);

      final back = CloudEntitlement.fromJson(json.decode(json.encode(e.toJson())) as Map<String, dynamic>);
      expect(back, e);
      expect(back.sharedAccess.collections, 2);
      expect(back, isNot(equals(CloudEntitlement.none)));

      // Garbage shapes degrade to none.
      expect(SharedAccess.fromJson('x'), SharedAccess.none);
      expect(SharedAccess.fromJson({'active': 'yes'}).active, isFalse);
    });

    test('cloud phase: shared_access.active alone is still notEntitled', () async {
      SharedPreferences.setMockInitialValues({});
      Future<CloudPhase> phase(CloudEntitlement? e) async {
        final c = ProviderContainer(overrides: [
          cloudEnabledProvider.overrideWithValue(true),
          sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
          cloudEntitlementProvider.overrideWith(() => FixedEntitlement(e)),
        ]);
        addTearDown(c.dispose);
        await c.read(plantlyAuthProvider.notifier).current();
        try {
          await c.read(cloudEntitlementProvider.future).timeout(const Duration(milliseconds: 100));
        } catch (_) {}
        return c.read(cloudStateProvider).phase;
      }

      expect(await phase(CloudEntitlement.none), CloudPhase.notEntitled);
      expect(await phase(const CloudEntitlement(active: true, source: 'pro')), CloudPhase.ready);
      expect(await phase(const CloudEntitlement(active: false, sharedAccess: SharedAccess(active: true, collections: 1))),
          CloudPhase.notEntitled);
    });
  });

  group('CollectionActivityRepository cache', () {
    late SharedPreferences prefs;
    late CollectionActivityRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = CollectionActivityRepository(
        api: PlantlyApi(client: MockClient((_) async => http.Response('{}', 500))),
        prefs: prefs,
      );
    });

    test('empty / corrupt cache → []', () async {
      expect(repo.readCache('col-2'), isEmpty);
      await prefs.setString(CollectionActivityRepository.cacheKey('col-2'), '{not json');
      expect(repo.readCache('col-2'), isEmpty);
      await prefs.setString(CollectionActivityRepository.cacheKey('col-2'), '{"events": "nope"}');
      expect(repo.readCache('col-2'), isEmpty);
    });

    test('write → read round-trip, newest first, per collection', () async {
      await repo.writeCache('col-2', [ev(5), ev(9), ev(1)]);
      expect(repo.readCache('col-2').map((e) => e.seq), [9, 5, 1]);
      expect(repo.readCache('col-3'), isEmpty);
      expect(prefs.getString('plantly_collection_activity/col-2'), isNotNull);
    });

    test('writeCache keeps only the newest 200', () async {
      await repo.writeCache('col-2', [for (var s = 300; s >= 1; s--) ev(s)]);
      final back = repo.readCache('col-2');
      expect(back.length, kActivityCacheMax);
      expect(back.first.seq, 300);
      expect(back.last.seq, 101);
    });

    test('merge: union by seq, incoming wins, newest first', () {
      final merged = CollectionActivityRepository.merge(
        [ev(10), ev(8, name: 'old'), ev(6)],
        [ev(12), ev(8, name: 'new'), ev(7)],
      );
      expect(merged.map((e) => e.seq), [12, 10, 8, 7, 6]);
      expect(merged[2].summaryName, 'new');
    });
  });

  group('CollectionActivityNotifier paging + caching', () {
    late int total; // server has events seq total..1
    late List<http.Request> requests;
    late bool offline;
    late ProviderContainer container;

    http.Response jsonRes(Object body, [int status = 200]) =>
        http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

    ProviderContainer build({bool signedIn = true}) => ProviderContainer(overrides: [
          cloudEnabledProvider.overrideWithValue(true),
          sessionStoreProvider.overrideWith((_) => InMemorySessionStore(signedIn ? token : null)),
          httpClientProvider.overrideWith((_) => MockClient((req) async {
                requests.add(req);
                if (offline) throw const SocketException('down');
                final path = req.url.path;
                if (req.method == 'GET' && path.endsWith('/inventory/collections/col-2/activity')) {
                  final before = int.tryParse(req.url.queryParameters['before'] ?? '');
                  final limit = int.parse(req.url.queryParameters['limit']!);
                  final start = before == null ? total : before - 1;
                  final events = [for (var s = start; s >= 1 && start - s < limit; s--) wireEvent(s)];
                  final oldest = events.isEmpty ? 0 : (events.last['seq'] as int);
                  return jsonRes({'events': events, 'next_before': oldest > 1 ? oldest : null});
                }
                return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
              })),
        ]);

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      total = 100;
      requests = [];
      offline = false;
    });

    tearDown(() => container.dispose());

    test('first load: cache (empty) → newest page of 50; load more pages with before=<oldest>', () async {
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      var state = container.read(collectionActivityProvider('col-2'));
      expect(state.loaded, isTrue);
      expect(state.loading, isFalse);
      expect(state.events.length, 50);
      expect(state.events.first.seq, 100);
      expect(state.events.last.seq, 51);
      expect(state.hasMore, isTrue);
      expect(state.fromCache, isFalse);
      expect(state.error, isNull);
      expect(notifier.fetches, 1);
      expect(requests.single.url.queryParameters, {'limit': '50'});
      expect(requests.single.headers['Authorization'], 'Bearer $token');
      expect(requests.single.headers['X-Plantly-Client'], isNotNull);

      await notifier.loadMore();
      state = container.read(collectionActivityProvider('col-2'));
      expect(requests.last.url.queryParameters, {'before': '51', 'limit': '50'});
      expect(state.events.length, 100);
      expect(state.events.last.seq, 1);
      expect(state.hasMore, isFalse, reason: 'server returned next_before null');
      expect(state.loadingMore, isFalse);

      // No-op when exhausted.
      await notifier.loadMore();
      expect(notifier.fetches, 2);

      // Persisted: the whole 100 (≤ 200).
      final prefs = await SharedPreferences.getInstance();
      final cached = CollectionActivityRepository(api: container.read(plantlyApiProvider), prefs: prefs).readCache('col-2');
      expect(cached.length, 100);
      expect(cached.first.seq, 100);
    });

    test('memory grows past 200 while the cache keeps the newest 200', () async {
      total = 260;
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      while (container.read(collectionActivityProvider('col-2')).hasMore) {
        await notifier.loadMore();
      }
      final state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.length, 260);
      expect(notifier.fetches, 6);
      final prefs = await SharedPreferences.getInstance();
      final cached = CollectionActivityRepository(api: container.read(plantlyApiProvider), prefs: prefs).readCache('col-2');
      expect(cached.length, 200);
      expect(cached.first.seq, 260);
      expect(cached.last.seq, 61);
    });

    test('refresh merges new rows over the cache and dedupes', () async {
      total = 60;
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      expect(container.read(collectionActivityProvider('col-2')).events.length, 50);
      total = 65; // five new ops on the server
      await notifier.refresh();
      final state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.length, 55, reason: '50 cached ∪ newest 50 = 65..11');
      expect(state.events.first.seq, 65);
      expect(state.events.last.seq, 11);
      expect(state.events.map((e) => e.seq).toSet().length, 55, reason: 'no duplicates');
    });

    test('fully paged, refresh after growth → no spurious load-more', () async {
      total = 60;
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      await notifier.loadMore();
      var state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.length, 60);
      expect(state.hasMore, isFalse);
      expect(notifier.fetches, 2);

      total = 65; // five new ops: the newest page (65..16) overlaps what we hold
      await notifier.refresh();
      state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.length, 65);
      expect(state.events.first.seq, 65);
      expect(state.events.last.seq, 1);
      expect(state.hasMore, isFalse, reason: 'server end already reached; the page abuts the cache');
      await notifier.loadMore();
      expect(notifier.fetches, 3, reason: 'load-more is a no-op');

      total = 110; // exactly abutting: page = 110..61, cache newest = 65 → overlap, still no gap
      await notifier.refresh();
      state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.length, 110);
      expect(state.hasMore, isFalse);
    });

    test('fully paged, then more than a page of growth → restart from the top and page contiguously', () async {
      total = 60;
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      await notifier.loadMore();
      expect(container.read(collectionActivityProvider('col-2')).hasMore, isFalse);

      total = 200; // newest page = 200..151; hole 150..61 above the cached 60..1
      await notifier.refresh();
      var state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.map((e) => e.seq).toList(), [for (var s = 200; s >= 151; s--) s],
          reason: 'stale rows below the hole are dropped so paging stays contiguous');
      expect(state.hasMore, isTrue);
      await notifier.loadMore();
      state = container.read(collectionActivityProvider('col-2'));
      expect(requests.last.url.queryParameters['before'], '151');
      expect(state.events.last.seq, 101);
      expect(state.hasMore, isTrue);
      while (container.read(collectionActivityProvider('col-2')).hasMore) {
        await notifier.loadMore();
      }
      state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.length, 200);
      expect(state.events.map((e) => e.seq).toSet().length, 200);
    });

    test('concurrent loadMore calls coalesce into one request', () async {
      total = 150;
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      expect(notifier.fetches, 1);
      await Future.wait([notifier.loadMore(), notifier.loadMore(), notifier.loadMore()]);
      expect(notifier.fetches, 2);
      expect(container.read(collectionActivityProvider('col-2')).events.length, 100);
    });

    test('offline: cache shown, error = network, fromCache; recovers on the next refresh', () async {
      final prefs = await SharedPreferences.getInstance();
      await CollectionActivityRepository(
        api: PlantlyApi(client: MockClient((_) async => http.Response('', 500))),
        prefs: prefs,
      ).writeCache('col-2', [ev(3), ev(2), ev(1)]);
      offline = true;
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      var state = container.read(collectionActivityProvider('col-2'));
      expect(state.loaded, isTrue);
      expect(state.events.map((e) => e.seq), [3, 2, 1]);
      expect(state.fromCache, isTrue);
      expect(state.error, isA<PlantlyNetworkException>());
      expect(state.loading, isFalse);

      offline = false;
      total = 4;
      await notifier.refresh();
      state = container.read(collectionActivityProvider('col-2'));
      expect(state.error, isNull);
      expect(state.fromCache, isFalse);
      expect(state.events.map((e) => e.seq), [4, 3, 2, 1]);
    });

    test('server error (403 not a member): cache kept, error surfaced as PlantlyApiException', () async {
      container = ProviderContainer(overrides: [
        cloudEnabledProvider.overrideWithValue(true),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
        httpClientProvider.overrideWith((_) => MockClient((req) async => jsonRes({'error': 'not_a_member'}, 403))),
      ]);
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      final state = container.read(collectionActivityProvider('col-2'));
      expect(state.error, isA<PlantlyApiException>().having((e) => e.status, 'status', 403));
      expect(state.events, isEmpty);
      expect(state.loaded, isTrue);
    });

    test('signed out: cache only, no network call', () async {
      final prefs = await SharedPreferences.getInstance();
      await CollectionActivityRepository(
        api: PlantlyApi(client: MockClient((_) async => http.Response('', 500))),
        prefs: prefs,
      ).writeCache('col-2', [ev(2), ev(1)]);
      container = build(signedIn: false);
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      final state = container.read(collectionActivityProvider('col-2'));
      expect(state.events.length, 2);
      expect(state.loaded, isTrue);
      expect(state.fromCache, isTrue);
      expect(requests, isEmpty);
      expect(notifier.fetches, 0);
      await notifier.loadMore();
      expect(requests, isEmpty);
    });

    test('concurrent refresh calls coalesce into one request', () async {
      container = build();
      final notifier = container.read(collectionActivityProvider('col-2').notifier);
      await notifier.ready;
      expect(notifier.fetches, 1);
      await Future.wait([notifier.refresh(), notifier.refresh(), notifier.refresh()]);
      expect(notifier.fetches, 2);
      await waitFor(() => !container.read(collectionActivityProvider('col-2')).loading);
    });
  });

  group('latestEditBy (plant detail "last edited by")', () {
    test('newest event for the entity by someone other than me; null when none', () {
      final events = [
        ev(10, userId: 'u-1', username: 'alice', entityId: 'p-1', kind: ActivityKind.updated), // me
        ev(9, userId: 'u-2', username: 'maria', entityId: 'p-2'),
        ev(8, userId: 'u-3', username: 'ion', entityId: 'p-1', kind: ActivityKind.updated),
        ev(7, userId: 'u-2', username: 'maria', entityId: 'p-1'),
        ev(6, userId: '', username: '', entityId: 'p-3'),
      ];
      expect(latestEditBy(events, entityId: 'p-1', excludeUserId: 'u-1')?.seq, 8);
      expect(latestEditBy(events, entityId: 'p-1')?.seq, 10, reason: 'nobody excluded');
      expect(latestEditBy(events, entityId: 'p-2', excludeUserId: 'u-1')?.user.username, 'maria');
      expect(latestEditBy(events, entityId: 'p-2', excludeUserId: 'u-2'), isNull);
      expect(latestEditBy(events, entityId: 'p-3'), isNull, reason: 'empty user id = unknown actor');
      expect(latestEditBy(events, entityId: 'p-9'), isNull);
      expect(latestEditBy(const [], entityId: 'p-1'), isNull);
    });
  });
}
