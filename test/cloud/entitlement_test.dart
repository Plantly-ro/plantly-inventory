import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/sign_in_events.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CloudEntitlement.fromSubscriptionJson (§1.2)', () {
    test('shared_access (MULTI-USER-V2 §0, additive): parsed, cached, compared; absent → false/0', () {
      final shared = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {
            'active': false,
            'source': null,
            'shared_access': {'active': true, 'collections': 2},
          },
        },
      });
      expect(shared.active, isFalse, reason: 'shared access does not change the own verdict (yet)');
      expect(shared.sharedAccess.active, isTrue);
      expect(shared.sharedAccess.collections, 2);
      expect(CloudEntitlement.fromJson(json.decode(json.encode(shared.toJson())) as Map<String, dynamic>), shared);
      expect(shared, isNot(CloudEntitlement.fromJson({'active': false})));

      final plain = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {'active': true, 'source': 'pro'},
        },
      });
      expect(plain.sharedAccess.active, isFalse);
      expect(plain.sharedAccess.collections, 0);
      // Older cache rows (no shared keys) still decode.
      final legacyCache = CloudEntitlement.fromJson({'active': true, 'source': 'pro', 'provider': null});
      expect(legacyCache.sharedAccess.active, isFalse);
      expect(legacyCache.sharedAccess.collections, 0);
      // Malformed shapes degrade to the defaults instead of throwing.
      final odd = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {'active': true, 'shared_access': 'yes'},
        },
      });
      expect(odd.sharedAccess.active, isFalse);
      expect(odd.sharedAccess.collections, 0);
    });

    test('reads entitlements.inventory_cloud when present', () {
      final e = CloudEntitlement.fromSubscriptionJson({
        'is_pro': false,
        'entitlements': {
          'inventory_cloud': {'active': true, 'source': 'inventory_cloud', 'current_period_end': '2026-10-27T10:00:00Z'},
        },
      });
      expect(e.active, isTrue);
      expect(e.source, 'inventory_cloud');
      expect(e.currentPeriodEnd, DateTime.utc(2026, 10, 27, 10));
    });

    test('reads provider (PLAY-BILLING-CONTRACT §2, additive); absent → not managed by Play', () {
      final play = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {'active': true, 'source': 'inventory_cloud', 'provider': 'play', 'current_period_end': '2026-10-27T10:00:00Z'},
        },
      });
      expect(play.provider, 'play');
      expect(play.managedByPlay, isTrue);
      final roundTrip = CloudEntitlement.fromJson(json.decode(json.encode(play.toJson())) as Map<String, dynamic>);
      expect(roundTrip, play);
      expect(roundTrip.managedByPlay, isTrue);

      final legacy = CloudEntitlement.fromSubscriptionJson({
        'entitlements': {
          'inventory_cloud': {'active': true, 'source': 'inventory_cloud'},
        },
      });
      expect(legacy.provider, isNull);
      expect(legacy.managedByPlay, isFalse);
      expect(legacy, isNot(equals(play)));

      // An inactive row never counts as Play-managed, whatever it says.
      expect(const CloudEntitlement(active: false, provider: 'play').managedByPlay, isFalse);
    });

    test('entitlements block wins over is_pro (server is authoritative)', () {
      final e = CloudEntitlement.fromSubscriptionJson({
        'is_pro': true,
        'entitlements': {
          'inventory_cloud': {'active': false, 'source': null, 'current_period_end': null},
        },
      });
      expect(e.active, isFalse);
      expect(e.source, isNull);
      expect(e.currentPeriodEnd, isNull);
    });

    test('entitlements block without the inventory_cloud key = not entitled', () {
      final e = CloudEntitlement.fromSubscriptionJson({'is_pro': true, 'entitlements': <String, dynamic>{}});
      expect(e.active, isFalse);
    });

    test('falls back to is_pro when the entitlements block is absent (older monolith)', () {
      final pro = CloudEntitlement.fromSubscriptionJson({
        'is_pro': true,
        'tier': 'pro',
        'status': 'active',
        'current_period_end': '2026-10-01T00:00:00Z',
      });
      expect(pro.active, isTrue);
      expect(pro.source, 'pro');
      expect(pro.currentPeriodEnd, DateTime.utc(2026, 10));

      final free = CloudEntitlement.fromSubscriptionJson({'is_pro': false});
      expect(free, CloudEntitlement.none);
      expect(CloudEntitlement.fromSubscriptionJson(const {}), CloudEntitlement.none);
    });

    test('round-trips through the prefs cache shape', () {
      const e = CloudEntitlement(active: true, source: 'pro');
      expect(CloudEntitlement.fromJson(json.decode(json.encode(e.toJson())) as Map<String, dynamic>), e);
      const cancelling = CloudEntitlement(active: true, source: 'inventory_cloud', cancelAtPeriodEnd: true);
      expect(CloudEntitlement.fromJson(json.decode(json.encode(cancelling.toJson())) as Map<String, dynamic>), cancelling);
      expect(cancelling == const CloudEntitlement(active: true, source: 'inventory_cloud'), isFalse);
    });

    test('cancel_at_period_end comes from the subscriptions[] row behind the grant', () {
      Map<String, dynamic> body({required String source, String provider = 'stripe', required List<Map<String, dynamic>> subs}) => {
            'is_pro': source == 'pro',
            'subscriptions': subs,
            'entitlements': {
              'inventory_cloud': {
                'active': true,
                'source': source,
                'provider': provider,
                'current_period_end': '2026-11-07T00:00:00Z',
              },
            },
          };
      // The granting Pro row is cancelled; an unrelated inventory_cloud row is not.
      expect(
        CloudEntitlement.fromSubscriptionJson(body(source: 'pro', subs: [
          {'product': 'pro', 'provider': 'stripe', 'cancel_at_period_end': true},
          {'product': 'inventory_cloud', 'provider': 'stripe', 'cancel_at_period_end': false},
        ])).cancelAtPeriodEnd,
        isTrue,
      );
      // Matching is per product + provider: a cancelled Stripe row does not
      // describe the Play grant.
      expect(
        CloudEntitlement.fromSubscriptionJson(body(source: 'inventory_cloud', provider: 'play', subs: [
          {'product': 'inventory_cloud', 'provider': 'stripe', 'cancel_at_period_end': true},
          {'product': 'inventory_cloud', 'provider': 'play', 'cancel_at_period_end': false},
        ])).cancelAtPeriodEnd,
        isFalse,
      );
      expect(
        CloudEntitlement.fromSubscriptionJson(body(source: 'inventory_cloud', subs: const [])).cancelAtPeriodEnd,
        isFalse,
        reason: 'no matching row → renews (unknown)',
      );
      // Legacy body: top-level Pro fields.
      expect(
        CloudEntitlement.fromSubscriptionJson({'is_pro': true, 'cancel_at_period_end': true}).cancelAtPeriodEnd,
        isTrue,
      );
    });
  });

  group('cloudEntitlementProvider', () {
    final now = DateTime.utc(2026, 9, 27, 12);
    int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
    final token = fakeJwt(iat: secs(DateTime.now().toUtc()), exp: secs(DateTime.now().toUtc().add(const Duration(hours: 24))));

    late int fetches;
    late Map<String, dynamic> body;
    late bool offline;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      fetches = 0;
      offline = false;
      body = {
        'is_pro': false,
        'entitlements': {
          'inventory_cloud': {'active': true, 'source': 'inventory_cloud', 'current_period_end': '2026-10-27T10:00:00Z'},
        },
      };
    });

    ProviderContainer make({String? storedToken = ''}) {
      final c = ProviderContainer(overrides: [
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(storedToken == '' ? token : storedToken)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              if (req.url.path.endsWith('/subscriptions/me')) {
                expect(req.headers['Authorization'], 'Bearer $token');
                expect(req.headers['X-Plantly-Client'], startsWith('inventory/'));
                fetches++;
                if (offline) throw http.ClientException('offline');
                return http.Response(json.encode(body), 200);
              }
              return http.Response('{"error":"nope"}', 404);
            })),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('signed out → null, no request', () async {
      final c = make(storedToken: null);
      await c.read(plantlyAuthProvider.notifier).current();
      expect(await c.read(cloudEntitlementProvider.future), isNull);
      expect(fetches, 0);
    });

    test('fetches once, serves the cache within 15 min, refresh() bypasses it', () async {
      final c = make();
      await c.read(plantlyAuthProvider.notifier).current();
      final notifier = c.read(cloudEntitlementProvider.notifier)..now = () => now;
      final first = await c.read(cloudEntitlementProvider.future);
      expect(first?.active, isTrue);
      expect(first?.source, 'inventory_cloud');
      expect(fetches, 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(CloudEntitlementNotifier.cacheUserKey), 'u-1');
      expect(prefs.getInt(CloudEntitlementNotifier.cacheAtKey), now.millisecondsSinceEpoch);

      c.invalidate(cloudEntitlementProvider);
      expect((await c.read(cloudEntitlementProvider.future))?.active, isTrue);
      expect(fetches, 1, reason: 'fresh cache → no request');

      await notifier.refreshIfStale();
      await c.read(cloudEntitlementProvider.future);
      expect(fetches, 1, reason: 'not stale yet');

      notifier.now = () => now.add(const Duration(minutes: 16));
      await notifier.refreshIfStale();
      await c.read(cloudEntitlementProvider.future);
      expect(fetches, 2, reason: 'stale → refetch');

      body['entitlements']['inventory_cloud']['active'] = false;
      await notifier.refresh();
      expect((await c.read(cloudEntitlementProvider.future))?.active, isFalse);
      expect(fetches, 3);
    });

    test('a sign-in event forces a refresh', () async {
      final c = make();
      await c.read(plantlyAuthProvider.notifier).current();
      await c.read(cloudEntitlementProvider.future);
      expect(fetches, 1);
      c.read(signInEventsProvider).emit(c.read(plantlyAuthProvider).value!);
      await Future<void>.delayed(Duration.zero);
      await c.read(cloudEntitlementProvider.future);
      expect(fetches, 2);
    });

    test('offline with a stale cache keeps the cached verdict; offline without one errors', () async {
      final c = make();
      await c.read(plantlyAuthProvider.notifier).current();
      final notifier = c.read(cloudEntitlementProvider.notifier)..now = () => now;
      await c.read(cloudEntitlementProvider.future);
      offline = true;
      notifier.now = () => now.add(const Duration(hours: 1));
      await notifier.refresh();
      expect((await c.read(cloudEntitlementProvider.future))?.active, isTrue);

      SharedPreferences.setMockInitialValues({});
      final c2 = make();
      await c2.read(plantlyAuthProvider.notifier).current();
      await expectLater(c2.read(cloudEntitlementProvider.future), throwsA(isA<Exception>()));
    });
  });
}
