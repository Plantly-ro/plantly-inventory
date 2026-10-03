// MULTI-USER-V2 §0/§3 — `canEditActiveCollectionProvider` is the single
// switch every mutating affordance watches. False for a viewer of a shared
// collection — and, belt and braces, for a signed-out device still parked
// on a tenant that is not its linked home (somebody else's collection);
// every other state (signed out at home, own collection, editor, a tenant
// the list does not know) stays editable.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';

const _mine = CloudCollection(id: 'col-1', name: 'My plants', role: 'owner', ownerUserId: 'u-1');
const _editor = CloudCollection(id: 'col-2', name: 'Family greenhouse', role: 'editor', ownerUserId: 'u-2');
const _viewer = CloudCollection(id: 'col-3', name: 'Office jungle', role: 'viewer', ownerUserId: 'u-3');

const _ready = CloudState(phase: CloudPhase.ready, account: 'alice', collectionId: 'col-1', collectionName: 'My plants');
const _signedOut = CloudState(phase: CloudPhase.signedOut);

ProviderContainer _container({
  required CloudState cloud,
  required String tenant,
  List<CloudCollection> collections = const [_mine, _editor, _viewer],
  String? home,
}) {
  final container = ProviderContainer(overrides: [
    cloudStateProvider.overrideWithValue(cloud),
    homeCollectionIdProvider.overrideWithValue(home),
    currentTenantIdProvider.overrideWith((ref) => tenant),
    collectionsProvider.overrideWith((ref) => CollectionsNotifier(ref, autoStart: false, initial: collections)),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('signed out → editable (read-only is a role, not a connectivity state)', () {
    final c = _container(cloud: _signedOut, tenant: 'col-1', collections: const []);
    expect(c.read(canEditActiveCollectionProvider), isTrue);
  });

  test('signed out, link known, tenant is home → editable', () {
    final c = _container(cloud: _signedOut, tenant: 'col-1', collections: const [], home: 'col-1');
    expect(c.read(canEditActiveCollectionProvider), isTrue);
  });

  test('signed out but still parked on a shared tenant → read-only (belt and braces)', () {
    // The session-loss fallback should have flipped the tenant home; if it
    // has not (yet), the rows on screen are somebody else's collection.
    final c = _container(cloud: _signedOut, tenant: 'col-3', collections: const [], home: 'col-1');
    expect(c.read(canEditActiveCollectionProvider), isFalse);
    c.read(currentTenantIdProvider.notifier).state = 'col-1';
    expect(c.read(canEditActiveCollectionProvider), isTrue, reason: 'back home → editable again');
  });

  test('signed out, never linked (local-only device) → editable whatever the tenant', () {
    final c = _container(cloud: _signedOut, tenant: 'local-abc', collections: const []);
    expect(c.read(canEditActiveCollectionProvider), isTrue);
  });

  test('cloud feature off → editable', () {
    final c = _container(cloud: CloudState.off, tenant: 'col-1', collections: const []);
    expect(c.read(canEditActiveCollectionProvider), isTrue);
  });

  test('own (linked default) collection → editable', () {
    final c = _container(cloud: _ready, tenant: 'col-1');
    expect(c.read(canEditActiveCollectionProvider), isTrue);
  });

  test('shared collection as editor → editable', () {
    final c = _container(cloud: _ready, tenant: 'col-2');
    expect(c.read(canEditActiveCollectionProvider), isTrue);
  });

  test('shared collection as viewer → read-only', () {
    final c = _container(cloud: _ready, tenant: 'col-3');
    expect(c.read(canEditActiveCollectionProvider), isFalse);
  });

  test('tenant unknown to the list → editable (never lock the user out on a stale list)', () {
    final c = _container(cloud: _ready, tenant: 'col-404');
    expect(c.read(canEditActiveCollectionProvider), isTrue);
  });

  test('tracks the tenant switch viewer → own → viewer', () {
    final c = _container(cloud: _ready, tenant: 'col-3');
    expect(c.read(canEditActiveCollectionProvider), isFalse);
    c.read(currentTenantIdProvider.notifier).state = 'col-1';
    expect(c.read(canEditActiveCollectionProvider), isTrue);
    c.read(currentTenantIdProvider.notifier).state = 'col-3';
    expect(c.read(canEditActiveCollectionProvider), isFalse);
  });
}
