// Web access gate (WEB-ACCESS-POLICY §0/§1): the verdict derived from the
// real session + entitlement providers against a fake HTTP layer, the
// offline / 401 / 403 rules, the lapse-keeps-data guarantee, the forced
// flag on web, the parking lot and the focus re-check.
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/web_access.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 3, 12);
  int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
  final token = fakeJwt(
    iat: secs(DateTime.now().toUtc()),
    exp: secs(DateTime.now().toUtc().add(const Duration(hours: 24))),
  );
  final tokenB = fakeJwt(
    iat: secs(DateTime.now().toUtc()),
    exp: secs(DateTime.now().toUtc().add(const Duration(hours: 24))),
    username: 'bob',
    userId: 'u-2',
  );

  late int fetches;
  late bool active;
  late bool shared; // entitlements.inventory_cloud.shared_access.active
  late bool offline;
  late int status; // non-200 → PlantlyApiException with this status

  setUp(() {
    SharedPreferences.setMockInitialValues({kSkipSeedPrefKey: true});
    fetches = 0;
    active = true;
    shared = false;
    offline = false;
    status = 200;
  });

  ProviderContainer make({
    String? storedToken = '',
    bool web = true,
    AppDatabase? db,
  }) {
    final c = ProviderContainer(
      overrides: [
        webPlatformProvider.overrideWithValue(web),
        webAccessClockProvider.overrideWithValue(() => now),
        if (db != null) databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWith(
          (_) => FakeNotificationService(),
        ),
        sessionStoreProvider.overrideWith(
          (_) => InMemorySessionStore(storedToken == '' ? token : storedToken),
        ),
        httpClientProvider.overrideWith(
          (_) => MockClient((req) async {
            if (req.url.path.endsWith('/subscriptions/me')) {
              fetches++;
              if (offline) throw http.ClientException('offline');
              if (status != 200) {
                return http.Response('{"error":"nope"}', status);
              }
              return http.Response(
                json.encode({
                  'entitlements': {
                    'inventory_cloud': {
                      'active': active,
                      'source': active ? 'inventory_cloud' : null,
                      if (shared)
                        'shared_access': {'active': true, 'collections': 1},
                    },
                  },
                }),
                200,
              );
            }
            return http.Response('{"error":"nope"}', 404);
          }),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Settle the session, then the entitlement; return the verdict.
  Future<WebAccess> verdict(ProviderContainer c) async {
    c.listen(webAccessProvider, (_, _) {}); // keep the derivation alive
    await c.read(plantlyAuthProvider.notifier).current();
    c.read(cloudEntitlementProvider.notifier).now = () => now;
    try {
      await c.read(cloudEntitlementProvider.future);
    } catch (_) {
      // Error verdicts are part of what we assert.
    }
    await Future<void>.delayed(Duration.zero);
    return c.read(webAccessProvider);
  }

  Future<void> seedCache({
    required bool entitled,
    required Duration age,
    String userId = 'u-1',
    bool sharedOnly = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(CloudEntitlementNotifier.cacheUserKey, userId);
    await prefs.setString(
      CloudEntitlementNotifier.cacheKey,
      json.encode(
        CloudEntitlement(
          active: entitled,
          source: entitled ? 'pro' : null,
          sharedAccess: sharedOnly
              ? const SharedAccess(active: true, collections: 1)
              : SharedAccess.none,
        ).toJson(),
      ),
    );
    await prefs.setInt(
      CloudEntitlementNotifier.cacheAtKey,
      now.subtract(age).millisecondsSinceEpoch,
    );
  }

  group('flags', () {
    test('cloud is forced on for web builds, follows the define elsewhere', () {
      expect(
        PlantlyFeatures.cloudEnabledFor(isWeb: true, define: false),
        isTrue,
      );
      expect(
        PlantlyFeatures.cloudEnabledFor(isWeb: true, define: true),
        isTrue,
      );
      expect(
        PlantlyFeatures.cloudEnabledFor(isWeb: false, define: false),
        isFalse,
      );
      expect(
        PlantlyFeatures.cloudEnabledFor(isWeb: false, define: true),
        isTrue,
      );
    });
  });

  group('webAccessProvider', () {
    test('off web the gate never engages (even signed out)', () async {
      final c = make(storedToken: null, web: false);
      expect(await verdict(c), WebAccess.open);
      expect(fetches, 0);
    });

    test('state 1: signed out', () async {
      final c = make(storedToken: null);
      expect(await verdict(c), WebAccess.closedSignedOut);
      expect(fetches, 0);
    });

    test('state 2: signed in, not entitled', () async {
      active = false;
      final c = make();
      final v = await verdict(c);
      expect(v, WebAccess.closedNotEntitled('alice'));
      expect(v.isClosed, isTrue);
    });

    test('state 3: entitled → open, no offline flag', () async {
      final c = make();
      final v = await verdict(c);
      expect(v, WebAccess.open);
      expect((v as WebAccessOpen).offline, isFalse);
    });

    test('a lapse returns to state 2 without touching local data', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final c = make(db: db);
      expect(await verdict(c), WebAccess.open);
      await c.read(appContextProvider.future); // DB bootstrap (seed) done
      final plant = await c
          .read(plantRepositoryProvider)
          .create(nickname: 'Fern');

      active = false;
      await c.read(cloudEntitlementProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(webAccessProvider), WebAccess.closedNotEntitled('alice'));

      final rows = await db.select(db.plants).get();
      expect(
        rows.map((r) => r.id),
        contains(plant.id),
        reason: 'local rows survive the lapse',
      );
      expect(rows.single.deletedAt, isNull);
      // The session is kept too — only the gate closed.
      expect(c.read(plantlyAuthProvider).valueOrNull?.username, 'alice');
    });

    test(
      'offline with an entitled check ≤ 24 h old → open (read-only banner)',
      () async {
        await seedCache(entitled: true, age: const Duration(hours: 23));
        offline = true;
        final c = make();
        final v = await verdict(c);
        expect(v, const WebAccessOpen(offline: true));
        expect(
          fetches,
          1,
          reason: 'the stale (>15 min) cache is re-validated first',
        );
      },
    );

    test('offline with an entitled check > 24 h old → closed, retry', () async {
      await seedCache(entitled: true, age: const Duration(hours: 25));
      offline = true;
      final c = make();
      expect(await verdict(c), WebAccess.closedUnreachable('alice'));
    });

    test(
      'offline with a fresh (< 15 min) cache → open without the banner',
      () async {
        await seedCache(entitled: true, age: const Duration(minutes: 5));
        offline = true;
        final c = make();
        expect(await verdict(c), WebAccess.open);
        expect(fetches, 0);
      },
    );

    test('offline with nothing cached → closed, retry', () async {
      offline = true;
      final c = make();
      expect(await verdict(c), WebAccess.closedUnreachable('alice'));
    });

    test(
      'offline with a cached NOT-entitled verdict → state 2, never open',
      () async {
        await seedCache(entitled: false, age: const Duration(hours: 1));
        offline = true;
        final c = make();
        expect(await verdict(c), WebAccess.closedNotEntitled('alice'));
      },
    );

    test('403 never opens, even with a recent entitled cache', () async {
      await seedCache(entitled: true, age: const Duration(hours: 1));
      status = 403;
      final c = make();
      expect(await verdict(c), WebAccess.closedNotEntitled('alice'));
    });

    test('401 never opens: the session is dropped → state 1', () async {
      await seedCache(entitled: true, age: const Duration(hours: 1));
      status = 401;
      final c = make();
      final v = await verdict(c);
      expect(v.isOpen, isFalse);
      expect(v, WebAccess.closedSignedOut);
    });

    test(
      '5xx with a recent entitled cache → open offline; without → unreachable',
      () async {
        await seedCache(entitled: true, age: const Duration(hours: 2));
        status = 503;
        final c = make();
        expect(await verdict(c), const WebAccessOpen(offline: true));

        SharedPreferences.setMockInitialValues({kSkipSeedPrefKey: true});
        final c2 = make();
        expect(await verdict(c2), WebAccess.closedUnreachable('alice'));
      },
    );

    test(
      'account switch: user A open → B adopts the token offline → never open at any tick',
      () async {
        final c = make();
        expect(await verdict(c), WebAccess.open);
        final seen = <WebAccess>[];
        c.listen(webAccessProvider, (_, next) => seen.add(next));

        offline = true;
        await c.read(plantlyAuthProvider.notifier).adoptToken(tokenB);
        // Synchronously after the session flipped: B's first fetch is in
        // flight and A's `server` provenance must already be gone.
        expect(c.read(webAccessProvider), WebAccess.checking);
        try {
          await c.read(cloudEntitlementProvider.future);
        } catch (_) {}
        await Future<void>.delayed(Duration.zero);

        expect(
          seen.where((v) => v.isOpen),
          isEmpty,
          reason: 'A\'s verdict never leaks to B: $seen',
        );
        expect(seen.first, WebAccess.checking);
        // A's cache is keyed to u-1 → nothing usable for B while offline.
        expect(c.read(webAccessProvider), WebAccess.closedUnreachable('bob'));
        final notifier = c.read(cloudEntitlementProvider.notifier);
        expect(notifier.lastVerifiedAt, isNull);
      },
    );

    test(
      'account switch with B\'s own NOT-entitled cache → state 2 for B, never open',
      () async {
        final c = make();
        expect(await verdict(c), WebAccess.open);
        // B used this browser earlier and was not entitled. (One cache slot:
        // seeding it for u-2 is what the switch leaves behind.)
        await seedCache(
          entitled: false,
          age: const Duration(hours: 1),
          userId: 'u-2',
        );
        final seen = <WebAccess>[];
        c.listen(webAccessProvider, (_, next) => seen.add(next));
        offline = true;
        await c.read(plantlyAuthProvider.notifier).adoptToken(tokenB);
        expect(c.read(webAccessProvider), WebAccess.checking);
        try {
          await c.read(cloudEntitlementProvider.future);
        } catch (_) {}
        await Future<void>.delayed(Duration.zero);
        expect(seen.where((v) => v.isOpen), isEmpty, reason: '$seen');
        expect(c.read(webAccessProvider), WebAccess.closedNotEntitled('bob'));
      },
    );

    test(
      'signed out → sign in: "checking" (not signed-out) until the first fetch resolves',
      () async {
        final c = make(storedToken: null);
        expect(await verdict(c), WebAccess.closedSignedOut);
        final seen = <WebAccess>[];
        c.listen(webAccessProvider, (_, next) => seen.add(next));

        await c.read(plantlyAuthProvider.notifier).adoptToken(token);
        expect(c.read(webAccessProvider), WebAccess.checking);
        await c.read(cloudEntitlementProvider.future);
        await Future<void>.delayed(Duration.zero);
        expect(c.read(webAccessProvider), WebAccess.open);
        expect(seen, [WebAccess.checking, WebAccess.open]);
      },
    );

    test(
      '403 forgets the cache timestamp: the fast path can never serve it as confirmed',
      () async {
        await seedCache(entitled: true, age: const Duration(hours: 1));
        status = 403;
        final c = make();
        expect(await verdict(c), WebAccess.closedNotEntitled('alice'));
        expect(fetches, 1);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt(CloudEntitlementNotifier.cacheAtKey), isNull);
        expect(
          c.read(cloudEntitlementProvider.notifier).lastVerifiedAt,
          isNull,
        );

        // A fresh session in the same browser (prefs survive) must ask the
        // server again instead of trusting the old entitled row for 15 min.
        final c2 = make();
        expect(await verdict(c2), WebAccess.closedNotEntitled('alice'));
        expect(fetches, 2, reason: 'no ≤ maxAge fast path after a 403');

        // And if the server now relents, the next check reflects it.
        status = 200;
        final c3 = make();
        expect(await verdict(c3), WebAccess.open);
        expect(fetches, 3);
      },
    );

    test(
      'a refresh in flight keeps the previous verdict (no gate flash)',
      () async {
        final c = make();
        expect(await verdict(c), WebAccess.open);
        final seen = <WebAccess>[];
        c.listen(webAccessProvider, (_, next) => seen.add(next));
        await c.read(cloudEntitlementProvider.notifier).refresh();
        await Future<void>.delayed(Duration.zero);
        expect(seen.whereType<WebAccessChecking>(), isEmpty);
        expect(c.read(webAccessProvider), WebAccess.open);
      },
    );
  });

  group('shared access is informational (MULTI-USER-V2 §8: own plan only)', () {
    test('own inactive + shared_access.active → state 2 (not entitled)', () async {
      active = false;
      shared = true;
      final c = make();
      final v = await verdict(c);
      expect(v, WebAccess.closedNotEntitled('alice'));
      expect(v.isClosed, isTrue);
      final e = c.read(cloudEntitlementProvider).valueOrNull!;
      expect(e.active, isFalse);
      expect(e.sharedAccess.active, isTrue, reason: 'still parsed, for display only');
      expect(e.sharedAccess.collections, 1);
    });

    test('own plan arrives → open; it lapses again → state 2 (shared access changes nothing)', () async {
      active = false;
      shared = true;
      final c = make();
      expect(await verdict(c), WebAccess.closedNotEntitled('alice'));
      active = true;
      await c.read(cloudEntitlementProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(webAccessProvider), WebAccess.open);
      active = false;
      await c.read(cloudEntitlementProvider.notifier).refresh();
      await Future<void>.delayed(Duration.zero);
      expect(c.read(webAccessProvider), WebAccess.closedNotEntitled('alice'));
    });

    test('offline with a cached shared-only verdict ≤ 24 h old → still state 2 (never opens)', () async {
      await seedCache(
        entitled: false,
        sharedOnly: true,
        age: const Duration(hours: 1),
      );
      offline = true;
      final c = make();
      expect(await verdict(c), WebAccess.closedNotEntitled('alice'));
      expect(
        c.read(cloudEntitlementProvider).valueOrNull?.sharedAccess,
        const SharedAccess(active: true, collections: 1),
      );
    });

    test('403 never opens, even with a recent shared-only cache', () async {
      await seedCache(
        entitled: false,
        sharedOnly: true,
        age: const Duration(hours: 1),
      );
      status = 403;
      final c = make();
      expect(await verdict(c), WebAccess.closedNotEntitled('alice'));
    });
  });

  group('another account\'s data on this browser (heldByOther)', () {
    Future<AppDatabase> dbWithRowsUnder(String tenant) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.into(db.plants).insert(PlantsCompanion.insert(
            id: 'their-plant',
            tenantId: tenant,
            nickname: 'Theirs',
            status: 'alive',
            updatedHlc: '00000000000001-00000-dev',
            deviceId: 'dev',
          ));
      return db;
    }

    test('data-owner marker of another account: entitled but closed, with the account named', () async {
      SharedPreferences.setMockInitialValues({
        kSkipSeedPrefKey: true,
        kTenantIdPrefKey: 'col-9',
        kDataOwnerUserIdPrefKey: 'u-other',
        kDataOwnerUsernamePrefKey: 'bob',
      });
      final c = make(db: await dbWithRowsUnder('col-9'));
      await c.read(collectionLinkProvider.notifier).ready;
      final v = await verdict(c);
      expect(v, WebAccess.closedHeldByOther('alice', 'bob'));
      expect(v.isClosed, isTrue);
    });

    test('a persisted link made by another account closes it too', () async {
      SharedPreferences.setMockInitialValues({
        kSkipSeedPrefKey: true,
        kTenantIdPrefKey: 'col-9',
        kCollectionIdPrefKey: 'col-9',
        kCollectionUserIdPrefKey: 'u-other',
        kCollectionUsernamePrefKey: 'bob',
      });
      final c = make(db: await dbWithRowsUnder('col-9'));
      await c.read(collectionLinkProvider.notifier).ready;
      expect(await verdict(c), WebAccess.closedHeldByOther('alice', 'bob'));
    });

    test('own data (marker = me) opens as before; off web the gate never engages', () async {
      SharedPreferences.setMockInitialValues({
        kSkipSeedPrefKey: true,
        kTenantIdPrefKey: 'col-9',
        kDataOwnerUserIdPrefKey: 'u-1',
        kDataOwnerUsernamePrefKey: 'alice',
      });
      final c = make(db: await dbWithRowsUnder('col-9'));
      await c.read(collectionLinkProvider.notifier).ready;
      expect(await verdict(c), WebAccess.open);

      SharedPreferences.setMockInitialValues({
        kSkipSeedPrefKey: true,
        kTenantIdPrefKey: 'col-9',
        kDataOwnerUserIdPrefKey: 'u-other',
      });
      final android = make(web: false, db: await dbWithRowsUnder('col-9'));
      expect(await verdict(android), WebAccess.open);
    });
  });

  group('WebGateParking', () {
    test(
      'parks a route and a link; take clears; persists across instances',
      () async {
        final prefs = SharedPreferences.getInstance();
        final a = WebGateParking(prefs, now: () => now);
        await a.ready;
        expect(a.route, isNull);
        a.parkRoute('/plants/p1?x=1');
        a.parkLink(Uri.parse('https://inventory.plantly.ro/join?c=ABCD-EFGH'));
        await Future<void>.delayed(Duration.zero);

        final b = WebGateParking(
          prefs,
          now: () => now.add(const Duration(minutes: 30)),
        );
        await b.ready;
        expect(b.route, '/plants/p1?x=1');
        expect(b.takeRoute(), '/plants/p1?x=1');
        expect(b.takeRoute(), isNull);
        expect(
          b.takeLink(),
          Uri.parse('https://inventory.plantly.ro/join?c=ABCD-EFGH'),
        );
        expect(b.takeLink(), isNull);
        await Future<void>.delayed(Duration.zero);

        final c = WebGateParking(
          prefs,
          now: () => now.add(const Duration(minutes: 31)),
        );
        await c.ready;
        expect(
          c.route,
          isNull,
          reason: 'taken entries are gone from prefs too',
        );
      },
    );

    test('entries older than the ttl are dropped', () async {
      final prefs = SharedPreferences.getInstance();
      final a = WebGateParking(prefs, now: () => now)..parkRoute('/calendar');
      await a.ready;
      await Future<void>.delayed(Duration.zero);
      final b = WebGateParking(
        prefs,
        now: () => now.add(WebGateParking.ttl + const Duration(seconds: 1)),
      );
      await b.ready;
      expect(b.route, isNull);
    });

    test('a route parked before prefs resolve is kept', () async {
      final a = WebGateParking(SharedPreferences.getInstance(), now: () => now)
        ..parkRoute('/spaces');
      await a.ready;
      expect(a.route, '/spaces');
    });

    test(
      'kept across sign-in; cleared on sign-out and on account switch',
      () async {
        final c = make();
        final parking = c.read(webGateParkingProvider);
        await parking.ready;
        parking.parkRoute('/calendar');
        // Session restore (none → alice) is the OAuth-reload case: keep it.
        expect(await verdict(c), WebAccess.open);
        expect(parking.route, '/calendar');

        await c.read(plantlyAuthProvider.notifier).signOut();
        await Future<void>.delayed(Duration.zero);
        expect(
          parking.route,
          isNull,
          reason: 'sign-out drops the previous session\'s destination',
        );

        // Sign in again (none → alice): still kept.
        parking.parkRoute('/spaces');
        await c.read(plantlyAuthProvider.notifier).adoptToken(token);
        await Future<void>.delayed(Duration.zero);
        expect(parking.route, '/spaces');

        // Another account takes over (alice → bob): dropped.
        await c.read(plantlyAuthProvider.notifier).adoptToken(tokenB);
        await Future<void>.delayed(Duration.zero);
        expect(parking.route, isNull);
        await Future<void>.delayed(Duration.zero);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(WebGateParking.routeKey),
          isNull,
          reason: 'the prefs copy is gone too',
        );
      },
    );
  });

  group('WebAccessWatcher', () {
    test(
      'tab focus re-checks when the last check is older than a minute',
      () async {
        final c = make();
        expect(await verdict(c), WebAccess.open);
        expect(fetches, 1);
        final watcher = c.read(webAccessWatcherProvider);
        final notifier = c.read(cloudEntitlementProvider.notifier);

        watcher.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await c.read(cloudEntitlementProvider.future);
        expect(fetches, 1, reason: 'checked seconds ago → no request');

        notifier.now = () => now.add(const Duration(minutes: 2));
        watcher.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        await c.read(cloudEntitlementProvider.future);
        expect(fetches, 2);
        expect(watcher.resumes, 2);

        watcher.didChangeAppLifecycleState(AppLifecycleState.hidden);
        expect(watcher.resumes, 2);
      },
    );

    test('inert off web', () async {
      final c = make(web: false);
      final watcher = c.read(webAccessWatcherProvider);
      expect(watcher.resumes, 0);
      // start() was skipped: the binding does not call back. Calling the
      // hook by hand is harmless either way.
      watcher.dispose();
    });
  });
}
