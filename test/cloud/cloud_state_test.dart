import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;
import 'collection_link_test.dart' show insertDummy;

/// Fixed-verdict entitlement notifier for tests (no network, no timers).
class FixedEntitlement extends CloudEntitlementNotifier {
  FixedEntitlement(this.value, {this.hang = false});
  final CloudEntitlement? value;
  final bool hang;

  @override
  Future<CloudEntitlement?> build() async {
    ref.watch(plantlyAuthProvider);
    if (hang) return Completer<CloudEntitlement?>().future;
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PLANTLY_CLOUD_ENABLED defaults to off', () {
    expect(PlantlyFeatures.cloudEnabled, isFalse);
  });

  final token = fakeJwt(
    iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
  );

  ProviderContainer make({
    bool enabled = true,
    bool signedIn = true,
    CloudEntitlement? entitlement,
    bool hang = false,
    bool linked = false,
    String linkUser = 'u-1',
    bool unlinked = false,
    String? dataOwner,
    AppDatabase? db,
  }) {
    SharedPreferences.setMockInitialValues({
      if (linked) kCollectionIdPrefKey: 'col-1',
      if (linked) kCollectionNamePrefKey: 'My plants',
      if (linked) kCollectionUserIdPrefKey: linkUser,
      if (linked) kCollectionUsernamePrefKey: linkUser == 'u-1' ? 'alice' : 'bob',
      if (unlinked) kCloudUnlinkedPrefKey: true,
      if (dataOwner != null) kTenantIdPrefKey: 'col-1',
      kDataOwnerUserIdPrefKey: ?dataOwner,
      if (dataOwner != null) kDataOwnerUsernamePrefKey: dataOwner == 'u-1' ? 'alice' : 'bob',
    });
    final c = ProviderContainer(overrides: [
      if (db != null) databaseProvider.overrideWithValue(db),
      cloudEnabledProvider.overrideWithValue(enabled),
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore(signedIn ? token : null)),
      cloudEntitlementProvider.overrideWith(() => FixedEntitlement(entitlement, hang: hang)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<CloudState> settle(ProviderContainer c) async {
    await c.read(plantlyAuthProvider.notifier).current();
    await c.read(collectionLinkProvider.notifier).ready;
    try {
      await c.read(cloudEntitlementProvider.future).timeout(const Duration(milliseconds: 20));
    } catch (_) {}
    return c.read(cloudStateProvider);
  }

  group('cloudStateProvider matrix', () {
    test('flag off → off, regardless of everything else', () async {
      final s = await settle(make(enabled: false, entitlement: const CloudEntitlement(active: true, source: 'pro'), linked: true));
      expect(s, CloudState.off);
      expect(s.canSync, isFalse);
    });

    test('no session → signedOut (checking while the store is being read)', () async {
      final c = make(signedIn: false);
      expect(c.read(cloudStateProvider).phase, CloudPhase.signedOut);
      expect(c.read(cloudStateProvider).checking, isTrue);
      final s = await settle(c);
      expect(s.phase, CloudPhase.signedOut);
      expect(s.checking, isFalse);
      expect(s.account, isNull);
    });

    test('session + entitlement lookup in flight → notEntitled with checking=true', () async {
      final s = await settle(make(hang: true));
      expect(s.phase, CloudPhase.notEntitled);
      expect(s.checking, isTrue);
      expect(s.account, 'alice');
    });

    test('session + inactive entitlement → notEntitled', () async {
      final s = await settle(make(entitlement: CloudEntitlement.none));
      expect(s.phase, CloudPhase.notEntitled);
      expect(s.checking, isFalse);
      expect(s.entitlement, CloudEntitlement.none);
      expect(s.canSync, isFalse);
    });

    test('session + active entitlement, not linked yet → ready but not syncable', () async {
      final s = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'inventory_cloud')));
      expect(s.phase, CloudPhase.ready);
      expect(s.linked, isFalse);
      expect(s.canSync, isFalse);
      expect(s.collectionId, isNull);
    });

    test('session + active entitlement + link → ready and syncable', () async {
      final s = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), linked: true));
      expect(s.phase, CloudPhase.ready);
      expect(s.account, 'alice');
      expect(s.collectionId, 'col-1');
      expect(s.collectionName, 'My plants');
      expect(s.canSync, isTrue);
    });

    test('a stale link with no entitlement is still notEntitled (server rules)', () async {
      final s = await settle(make(entitlement: CloudEntitlement.none, linked: true));
      expect(s.phase, CloudPhase.notEntitled);
      expect(s.collectionId, 'col-1');
      expect(s.canSync, isFalse);
    });

    test('a link made by another account on this device does not count', () async {
      final s = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), linked: true, linkUser: 'u-other'));
      expect(s.phase, CloudPhase.ready);
      expect(s.linked, isFalse);
      expect(s.canSync, isFalse);
      expect(s.heldByOther, 'bob');
      final own = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), linked: true));
      expect(own.heldByOther, isNull);
    });

    test('QA2 BUG-4: a foreign link is never home — linked=false, no collection id, heldByOther set, in BOTH phases', () async {
      for (final e in [CloudEntitlement.none, const CloudEntitlement(active: true, source: 'pro')]) {
        final s = await settle(make(entitlement: e, linked: true, linkUser: 'u-other'));
        expect(s.phase, e.active ? CloudPhase.ready : CloudPhase.notEntitled);
        expect(s.linked, isFalse, reason: 'phase ${s.phase}');
        expect(s.collectionId, isNull);
        expect(s.collectionName, isNull);
        expect(s.canSync, isFalse);
        expect(s.heldByOther, 'bob');
        expect(s.account, 'alice');
      }
    });

    test('data-owner marker alone (A unlinked, B signed in) → heldByOther, nothing syncs', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await insertDummy(db, db.plants, 'col-1'); // A's parked rows
      final s = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), dataOwner: 'u-other', db: db));
      expect(s.phase, CloudPhase.ready);
      expect(s.linked, isFalse);
      expect(s.canSync, isFalse);
      expect(s.heldByOther, 'bob');
      expect(s.unlinkedByUser, isFalse);
      // Own marker → no decision.
      final own = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), dataOwner: 'u-1', db: db));
      expect(own.heldByOther, isNull);
      expect(own.phase, CloudPhase.ready);
    });

    test('marker on an empty tenant is ignored; a fresh device never shows the decision', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final wiped = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), dataOwner: 'u-other', db: db));
      expect(wiped.heldByOther, isNull);
      expect(wiped.phase, CloudPhase.ready);
      final fresh = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), db: db));
      expect(fresh.heldByOther, isNull);
      expect(fresh.linked, isFalse);
    });

    test('unlinked by the user → ready, not linked, flag surfaced for the UI', () async {
      final s = await settle(make(entitlement: const CloudEntitlement(active: true, source: 'pro'), unlinked: true));
      expect(s.phase, CloudPhase.ready);
      expect(s.linked, isFalse);
      expect(s.unlinkedByUser, isTrue);
    });

    test('signing out drops straight to signedOut', () async {
      final c = make(entitlement: const CloudEntitlement(active: true, source: 'pro'), linked: true);
      expect((await settle(c)).phase, CloudPhase.ready);
      await c.read(plantlyAuthProvider.notifier).signOut();
      expect(c.read(cloudStateProvider).phase, CloudPhase.signedOut);
    });
  });
}
