import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/plantly_features.dart';
import '../data/providers.dart';
import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_auth.dart';
import '../marketplace/plantly_session.dart';
import 'cloud_state.dart';
import 'collection_link.dart';
import 'sign_in_events.dart';

/// Shared collections (CLOUD-SYNC-CONTRACT §3) — the client-side model.
///
/// Every collection the signed-in account can see (its own default plus the
/// ones shared with it) lives in [collectionsProvider]. Each collection's
/// rows live under its own local tenant (`tenant_id` = collection id), so
/// switching is nothing more than flipping [currentTenantIdProvider]: no
/// migration, no copy. A collection never synced on this device starts
/// empty locally and fills from the first pull; sync cursors are already
/// per tenant (`PrefsSyncCursor`); the runner rebinds through
/// `syncCollectionIdProvider`, which follows [activeCollectionIdProvider].
///
/// Only the account's *own default* collection ever goes through the
/// migrate-on-link path (`CollectionLinkService.link`) — that one adopts the
/// pre-cloud local rows. Shared collections never migrate anything.

/// JSON cache of the last successful `GET /inventory/collections`, so the
/// switcher and the active-collection lookup work offline / before the
/// first fetch. Stored per account (`{"user_id":…, "items":[…]}`).
const String kCollectionsCachePrefKey = 'plantly_collections_cache';

/// Prefix of the per-collection members cache (`<prefix><collection id>`).
const String kMembersCachePrefPrefix = 'plantly_collection_members/';

/// Server code (and `SyncStatus.lastErrorDetail` of a `collection_unavailable`
/// halt) for a 403 on a collection the account is no longer a member of.
const String kNotAMemberDetail = 'not_a_member';

/// `410 collection_deleted` (MULTI-USER-V2 §2.3): the owner deleted the
/// collection. Handled like a removal (drop + go home + notice).
const String kCollectionDeletedDetail = 'collection_deleted';

/// `404 collection_not_found`: a soft-deleted collection answers 410 to
/// former members and 404 to non-members; both mean "gone" for a shared
/// collection in the list.
const String kCollectionNotFoundDetail = 'collection_not_found';

/// `403 device_revoked` (§2.12): the account revoked this device. The
/// client signs out the cloud session and shows "Dispozitiv deconectat".
const String kDeviceRevokedDetail = 'device_revoked';

/// `403 read_only` (§2.10): a viewer tried to push. The runner never pushes
/// for viewers, so this only shows up after a role downgrade raced a push.
const String kReadOnlyDetail = 'read_only';

/// `400 too_many_devices` (§2.12): the account hit its device cap. Not
/// retryable — the user frees a slot in Me → Cloud → Devices. The transport
/// raises it as a `SyncCollectionError` so the runner halts (rather than
/// backing off forever) and the Me section shows the pointer.
const String kTooManyDevicesDetail = 'too_many_devices';

/// `503 device_lookup_failed` (§2.12): the server could not check the
/// device registry; retryable, surfaced as the `retrying` detail.
const String kDeviceLookupFailedDetail = 'device_lookup_failed';

/// Set once after the server answered `device_revoked` and the cloud
/// session was cleared; the UI shows "Dispozitiv deconectat" once
/// (`CloudNotices`) and resets it to false.
final deviceRevokedNoticeProvider = StateProvider<bool>((_) => false);

/// Display name of a shared collection the server just told us we were
/// removed from ([CollectionsNotifier.removedByServer]); the UI shows it
/// once (`CloudNotices` SnackBar) and resets it to null.
final collectionRemovedNoticeProvider = StateProvider<String?>((_) => null);

class CollectionsState {
  const CollectionsState({
    this.items = const [],
    this.loaded = false,
    this.loading = false,
    this.error,
    this.fetchedAt,
    this.callerEntitled = true,
  });

  /// Own default first (when known), then the shared ones by name.
  final List<CloudCollection> items;

  /// Top-level `caller_entitled` of the last `GET /inventory/collections`
  /// (MULTI-USER-V2 §8): the server's verdict on the caller's OWN plan.
  /// False → every shared collection is read-only locally, never pushed,
  /// and carries the "needs Inventory Cloud" marker. Absent on older
  /// servers (and before the first fetch) → true, so no false markers.
  final bool callerEntitled;

  /// The prefs cache has been read (the list may still be empty).
  final bool loaded;

  /// A `GET /inventory/collections` is in flight.
  final bool loading;

  /// Last fetch failure (network / API); the cached [items] stay.
  final Object? error;
  final DateTime? fetchedAt;

  CloudCollection? byId(String? id) {
    if (id == null) return null;
    for (final c in items) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Collections shared with the account (where it is not the owner).
  List<CloudCollection> get sharedWithMe => [
        for (final c in items)
          if (!c.isOwner) c,
      ];

  List<CloudCollection> get mine => [
        for (final c in items)
          if (c.isOwner) c,
      ];

  CollectionsState copyWith({
    List<CloudCollection>? items,
    bool? loaded,
    bool? loading,
    Object? error = _unset,
    DateTime? fetchedAt,
    bool? callerEntitled,
  }) =>
      CollectionsState(
        items: items ?? this.items,
        loaded: loaded ?? this.loaded,
        loading: loading ?? this.loading,
        error: identical(error, _unset) ? this.error : error,
        fetchedAt: fetchedAt ?? this.fetchedAt,
        callerEntitled: callerEntitled ?? this.callerEntitled,
      );

  static const _unset = Object();

  @override
  String toString() =>
      'CollectionsState(${items.length} items, loaded=$loaded, loading=$loading, callerEntitled=$callerEntitled, error=$error)';
}

/// Why the collection on screen cannot be edited (MULTI-USER-V2 §0/§8).
enum ReadOnlyReason {
  /// Editable.
  none,

  /// The account is a `viewer` of this shared collection.
  viewer,

  /// A shared collection while the caller's own Inventory Cloud plan is
  /// missing / lapsed (`caller_entitled == false`, §8): local rows stay
  /// visible, nothing is edited or pushed until the plan is active again.
  cloudRequired,
}

/// Thrown by [CollectionsNotifier.switchCollection] when the device is not
/// in a state where switching is allowed (see [collectionSyncAllowed]) or
/// the id is not a collection the account can see.
class CollectionSwitchError extends StateError {
  CollectionSwitchError(super.message);
}

/// Signed in, linked, account decided (no foreign data pending) — the
/// precondition for touching any collection at all.
bool cloudAccountReady(CloudState cloud) =>
    cloud.phase != CloudPhase.off && cloud.phase != CloudPhase.signedOut && cloud.linked;

/// §3 entitlement rule: the plan is the OWNER's. The device may sync
/// [collection] when [cloudAccountReady] and either the caller is entitled
/// (their own collections) or the collection is one shared with them
/// (`role == editor`) — a lapsed owner plan surfaces as a 402 from the
/// server, not as a paywall for the editor.
bool collectionSyncAllowed(CloudState cloud, CloudCollection? collection) {
  if (!cloudAccountReady(cloud)) return false;
  if (cloud.phase == CloudPhase.ready) return true;
  return collection != null && !collection.isOwner;
}

/// Owns the collection list + the active-collection switch (§3).
///
/// Refreshes: on construction (cache first, then the server), on every
/// sign-in event, whenever the device link changes, every [refreshInterval]
/// while the app is alive, and on [refresh]. Signed out → empty list, cache
/// kept on disk for the account that wrote it.
class CollectionsNotifier extends StateNotifier<CollectionsState> {
  CollectionsNotifier(
    this._ref, {
    this.refreshInterval = const Duration(minutes: 15),
    bool autoStart = true,
    List<CloudCollection> initial = const [],
    bool callerEntitled = true,
  }) : super(CollectionsState(items: initial, loaded: !autoStart, callerEntitled: callerEntitled)) {
    if (!autoStart) {
      // Widget tests: a fixed list, no subscriptions, no network.
      _ready = Future.value();
      return;
    }
    // Subscriptions are set up synchronously (inside the provider body);
    // the cache read + first fetch follow asynchronously.
    _signIns = _ref.read(signInEventsProvider).stream.listen((_) => unawaited(refresh()));
    // Link changes (first link, move, start-empty) and account changes both
    // surface as a new collection id / account on the cloud state.
    _ref.listen<(String?, String?)>(
      cloudStateProvider.select((s) => (s.collectionId, s.account)),
      (prev, next) {
        if (next.$2 == null) {
          // Signed out: nothing to list, but keep the cache for the account.
          _onSessionLost();
          return;
        }
        if (prev != next) unawaited(refresh());
      },
    );
    if (refreshInterval > Duration.zero) {
      _timer = Timer.periodic(refreshInterval, (_) => unawaited(refresh()));
    }
    _ready = _loadCache();
    unawaited(_ready.then((_) => refresh()));
  }

  final Ref _ref;
  final Duration refreshInterval;
  late final Future<void> _ready;
  Timer? _timer;
  StreamSubscription<Object?>? _signIns;
  Future<void>? _inflight;

  /// Number of server fetches performed (tests).
  int fetches = 0;

  Future<SharedPreferences> get _prefs => _ref.read(sharedPreferencesProvider.future);

  /// Resolves once the prefs cache has been read.
  Future<void> get ready => _ready;

  Future<void> _loadCache() async {
    final p = await _prefs;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    final raw = p.getString(kCollectionsCachePrefKey);
    var items = const <CloudCollection>[];
    var callerEntitled = true;
    if (raw != null && session != null) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic> && decoded['user_id'] == session.userId) {
          items = _decodeList(decoded['items']);
          callerEntitled = decoded['caller_entitled'] != false;
        }
      } catch (_) {
        // Corrupt cache — ignore, the next fetch rewrites it.
      }
    }
    if (mounted) state = state.copyWith(items: items, loaded: true, callerEntitled: callerEntitled);
  }

  static List<CloudCollection> _decodeList(Object? list) => [
        if (list is List)
          for (final e in list)
            if (e is Map<String, dynamic>) CloudCollection.fromJson(e),
      ];

  Future<void> _saveCache(String userId, List<CloudCollection> items, {bool? callerEntitled}) async {
    final p = await _prefs;
    await p.setString(
      kCollectionsCachePrefKey,
      json.encode({
        'user_id': userId,
        'items': [for (final c in items) c.toJson()],
        'caller_entitled': callerEntitled ?? state.callerEntitled,
      }),
    );
  }

  /// `GET /inventory/collections`; concurrent calls share one fetch. Errors
  /// land in [CollectionsState.error] (the cached list stays), never throw.
  Future<void> refresh() {
    return _inflight ??= _refresh().whenComplete(() => _inflight = null);
  }

  Future<void> _refresh() async {
    await _ready;
    if (!_ref.read(cloudEnabledProvider)) return;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) {
      _onSessionLost();
      return;
    }
    if (mounted) state = state.copyWith(loading: true);
    try {
      fetches++;
      final listing = await _ref.read(plantlyApiProvider).fetchCollections(session.token);
      final items = _sorted(_withLinkedDefault(listing.items));
      await _saveCache(session.userId, items, callerEntitled: listing.callerEntitled);
      if (!mounted) return;
      state = state.copyWith(
        items: items,
        loading: false,
        error: null,
        fetchedAt: DateTime.now().toUtc(),
        callerEntitled: listing.callerEntitled,
      );
      _reconcileActive();
    } catch (e) {
      if (mounted) state = state.copyWith(loading: false, error: e);
    }
  }

  /// The linked default is authoritative locally: if the server list omits
  /// it (older server, eventual consistency right after `POST /default`)
  /// keep a synthetic owner entry so the switcher never loses "home".
  List<CloudCollection> _withLinkedDefault(List<CloudCollection> fetched) {
    final link = _ref.read(collectionLinkProvider).link;
    if (link == null || fetched.any((c) => c.id == link.id)) return fetched;
    return [
      CloudCollection(id: link.id, name: link.name, role: 'owner', ownerUserId: link.userId),
      ...fetched,
    ];
  }

  List<CloudCollection> _sorted(List<CloudCollection> items) {
    final link = _ref.read(collectionLinkProvider).link;
    final out = [...items];
    out.sort((a, b) {
      if (link != null) {
        if (a.id == link.id) return -1;
        if (b.id == link.id) return 1;
      }
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
    return out;
  }

  /// After a fetch: a tenant that is no longer in the list (removed as a
  /// member, collection deleted) goes back to the linked default so the
  /// user is never left looking at a collection nobody syncs.
  void _reconcileActive() {
    final cloud = _ref.read(cloudStateProvider);
    if (!cloudAccountReady(cloud)) return;
    final tenant = _ref.read(currentTenantIdProvider);
    if (tenant == cloud.collectionId || state.byId(tenant) != null) return;
    unawaited(_setTenant(cloud.collectionId!));
  }

  /// Whether [switchCollection] would accept [collectionId] right now: the
  /// linked default is always reachable (it is "home", synced or not);
  /// anything else must be a known collection the device may sync
  /// ([collectionSyncAllowed]).
  bool canSwitchTo(String collectionId) {
    final cloud = _ref.read(cloudStateProvider);
    if (!cloudAccountReady(cloud)) return false;
    if (collectionId == cloud.collectionId) return true;
    final col = state.byId(collectionId);
    return col != null && collectionSyncAllowed(cloud, col);
  }

  /// Make [collectionId] the active collection: flip the tenant (+ pref).
  /// No rows move. See [canSwitchTo] for the guard.
  Future<void> switchCollection(String collectionId) async {
    await _ready;
    if (!canSwitchTo(collectionId)) {
      throw CollectionSwitchError(
        state.byId(collectionId) == null && collectionId != _ref.read(cloudStateProvider).collectionId
            ? 'unknown collection $collectionId'
            : 'cloud sync is not available',
      );
    }
    if (_ref.read(currentTenantIdProvider) == collectionId) return;
    await _setTenant(collectionId);
  }

  Future<void> _setTenant(String collectionId) async {
    final p = await _prefs;
    // A collection that has never synced here is an empty tenant — it must
    // fill from the pull, never from the demo seed (which would then be
    // pushed into somebody else's collection).
    await p.setBool(kSkipSeedPrefKey, true);
    await p.setString(kTenantIdPrefKey, collectionId);
    _ref.read(currentTenantIdProvider.notifier).state = collectionId;
  }

  /// The linked default ("home"): the link store first — `CloudState`
  /// drops `collectionId` the moment the session is gone, which is exactly
  /// when the fallback below needs it.
  String? _homeId() => _ref.read(homeCollectionIdProvider) ?? _ref.read(cloudStateProvider).collectionId;

  /// Same rule `CollectionLinkService.unlink` applies: a device parked on a
  /// tenant that is not its own collection must not stay there once the
  /// session is gone — signed out, nothing syncs, and a viewer's tenant
  /// would otherwise turn editable (local-only = editable). Returns the
  /// home id to switch to, or null when the current tenant may stay
  /// (home itself, an owned collection, or no link at all). Decided
  /// against the list as it is NOW — call it before clearing the items.
  String? _sharedTenantFallback() {
    final home = _homeId();
    if (home == null) return null;
    final tenant = _ref.read(currentTenantIdProvider);
    if (tenant == home) return null;
    return state.byId(tenant)?.isOwner == true ? null : home;
  }

  /// Sign-out / expired session (401 that did not refresh): go home first
  /// when parked on a shared tenant, then forget the list (the on-disk
  /// cache stays for the account that wrote it).
  void _onSessionLost() {
    final home = _sharedTenantFallback();
    if (mounted) state = state.copyWith(items: const [], loading: false, error: null);
    if (home != null) unawaited(_setTenant(home));
  }

  /// `POST /inventory/collections/join`. Adds the collection to the list
  /// and switches to it (the device only needs its link, which is attempted
  /// here when missing). Throws `StateError` when signed out; API / network
  /// errors pass through — including `402 cloud_required` (MULTI-USER-V2
  /// §8: the caller has no active plan; the invite is NOT consumed, the
  /// join sheet parks it). Returns the joined collection.
  Future<CloudCollection> join(String code) async {
    await _ready;
    final normalized = InviteCode.normalize(code);
    if (normalized == null) throw ArgumentError.value(code, 'code', 'not an invite code');
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    final col = await _ref.read(plantlyApiProvider).joinCollection(session.token, normalized);
    final items = _sorted([
      for (final c in state.items)
        if (c.id != col.id) c,
      col,
    ]);
    await _saveCache(session.userId, items);
    if (mounted) state = state.copyWith(items: items, error: null);
    if (!_ref.read(cloudStateProvider).linked) {
      try {
        await _ref.read(collectionLinkProvider.notifier).ensureLinked();
      } catch (_) {
        // Offline / server error: the collection is in the list; the user
        // switches once the link lands (Me → Cloud shows the reason).
      }
    }
    if (canSwitchTo(col.id)) await switchCollection(col.id);
    return col;
  }

  /// Leave a collection shared with this account (`DELETE …/members/{me}`).
  /// The local tenant is left on disk (invisible, never pushed); the active
  /// collection falls back to the linked default when it was this one.
  Future<void> leave(String collectionId) async {
    await _ready;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    await _ref.read(plantlyApiProvider).removeMember(session.token, collectionId, session.userId);
    await _drop(collectionId, session.userId);
  }

  /// Owner: remove [userId] from [collectionId]. Refreshes the members
  /// list on success.
  Future<void> removeMember(String collectionId, String userId) async {
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    await _ref.read(plantlyApiProvider).removeMember(session.token, collectionId, userId);
    _ref.invalidate(membersProvider(collectionId));
    unawaited(refresh());
  }

  /// Owner: mint an invite for [collectionId] (default 1 use / 7 days /
  /// editor; see [InviteOptions]).
  Future<CollectionInvite> createInvite(String collectionId, {InviteOptions options = const InviteOptions()}) async {
    final session = await _requireSession();
    return _ref.read(plantlyApiProvider).createInvite(session.token, collectionId, options: options);
  }

  /// Owner: active invites of [collectionId] (`GET …/invites`).
  Future<List<CollectionInvite>> listInvites(String collectionId) async {
    final session = await _requireSession();
    return _ref.read(plantlyApiProvider).listInvites(session.token, collectionId);
  }

  /// Owner: revoke an invite (`DELETE …/invites/{id}`).
  Future<void> revokeInvite(String collectionId, String inviteId) async {
    final session = await _requireSession();
    await _ref.read(plantlyApiProvider).revokeInvite(session.token, collectionId, inviteId);
  }

  /// Owner: change a member's role (`PATCH …/members/{uid} {role}`,
  /// editor ↔ viewer). Refreshes the members list on success.
  Future<void> setMemberRole(String collectionId, String userId, String role) async {
    final session = await _requireSession();
    await _ref.read(plantlyApiProvider).setMemberRole(session.token, collectionId, userId, role);
    _ref.invalidate(membersProvider(collectionId));
  }

  /// Owner: hand [collectionId] to [userId] (`POST …/transfer`). On
  /// success the caller becomes an editor: the local list is patched
  /// right away (role + owner) and refreshed from the server. `402
  /// cloud_required_new_owner` passes through.
  Future<void> transferOwnership(String collectionId, String userId) async {
    final session = await _requireSession();
    final newOwner = await _ref.read(plantlyApiProvider).transferOwnership(session.token, collectionId, userId);
    final members = _ref.read(membersProvider(collectionId)).valueOrNull;
    final items = [
      for (final c in state.items)
        if (c.id == collectionId)
          c.copyWith(
            role: CollectionRole.editor,
            ownerUserId: newOwner,
            ownerUsername: memberUsername(members, newOwner),
          )
        else
          c,
    ];
    await _saveCache(session.userId, _sorted(items));
    if (mounted) state = state.copyWith(items: _sorted(items));
    _ref.invalidate(membersProvider(collectionId));
    unawaited(refresh());
  }

  /// Owner: rename (`PATCH /collections/{id} {name}`). Patches the local
  /// list with the server's stored name and refreshes.
  Future<void> rename(String collectionId, String name) async {
    final session = await _requireSession();
    final stored = await _ref.read(plantlyApiProvider).renameCollection(session.token, collectionId, name);
    final items = _sorted([
      for (final c in state.items) c.id == collectionId ? c.copyWith(name: stored) : c,
    ]);
    await _saveCache(session.userId, items);
    if (mounted) state = state.copyWith(items: items);
    unawaited(refresh());
  }

  /// Owner: delete (`DELETE /collections/{id}`). The local tenant stays on
  /// disk, invisible, like after [leave]; the active collection falls back
  /// to the linked default when it was this one.
  Future<void> delete(String collectionId) async {
    final session = await _requireSession();
    await _ref.read(plantlyApiProvider).deleteCollection(session.token, collectionId);
    await _drop(collectionId, session.userId);
  }

  /// The server answered `403 device_revoked` (§2.12) on a sync call: this
  /// install was revoked from Me → Cloud → Devices on another device. Drop
  /// the cloud session (the user signs in again to re-register) and raise
  /// [deviceRevokedNoticeProvider] for the one-shot notice.
  Future<void> deviceRevoked() async {
    // Leave a shared tenant BEFORE the session goes (the sign-out listener
    // would do it too, but the list is still intact here — deterministic).
    final home = _sharedTenantFallback();
    if (home != null) await _setTenant(home);
    await _ref.read(plantlyAuthProvider.notifier).signOut();
    _ref.read(deviceRevokedNoticeProvider.notifier).state = true;
  }

  Future<PlantlySession> _requireSession() async {
    await _ready;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    return session;
  }

  /// The server answered 403 `not_a_member` for [collectionId] while it was
  /// the active one (the owner removed this account): forget it locally,
  /// fall back to the linked default when it was the current tenant, and
  /// raise [collectionRemovedNoticeProvider] with its name for the UI. The
  /// tenant's rows stay on disk, invisible, like after [leave]. No-op when
  /// the list no longer knows the collection.
  Future<void> removedByServer(String collectionId) async {
    await _ready;
    final name = state.byId(collectionId)?.displayName;
    if (name == null) return;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    await _drop(collectionId, session?.userId);
    _ref.read(collectionRemovedNoticeProvider.notifier).state = name;
  }

  Future<void> _drop(String collectionId, String? userId) async {
    final items = [
      for (final c in state.items)
        if (c.id != collectionId) c,
    ];
    if (userId != null) await _saveCache(userId, items);
    if (mounted) state = state.copyWith(items: items);
    final home = _ref.read(cloudStateProvider).collectionId;
    if (_ref.read(currentTenantIdProvider) == collectionId && home != null) {
      await _setTenant(home);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _signIns?.cancel();
    super.dispose();
  }
}

/// Timing knob for tests (the 15-minute auto refresh).
final collectionsRefreshIntervalProvider = Provider<Duration>((_) => const Duration(minutes: 15));

final collectionsProvider = StateNotifierProvider<CollectionsNotifier, CollectionsState>((ref) {
  return CollectionsNotifier(ref, refreshInterval: ref.watch(collectionsRefreshIntervalProvider));
});

/// Id of the linked default collection ("home") straight from the link
/// store. Unlike `CloudState.collectionId` it survives sign-out, so the
/// session-loss fallback and the signed-out read-only guard can tell a
/// shared tenant from home. Null = never linked / unlinked.
final homeCollectionIdProvider = Provider<String?>((ref) {
  return ref.watch(collectionLinkProvider.select((s) => s.link?.id));
});

/// The collection the runner syncs against: the current tenant when it is
/// a collection the device may sync ([collectionSyncAllowed] — own
/// collections need the caller's plan, editor collections run on the
/// owner's). Null = no runner (signed out, unlinked, flag off, own
/// collection without a plan, or a tenant the list does not know yet).
///
/// Never the linked default as a stand-in: the runner pushes the *current
/// tenant's* op log, so guessing another collection while the list is
/// still loading would sync rows into the wrong collection.
final activeCollectionIdProvider = Provider<String?>((ref) {
  final cloud = ref.watch(cloudStateProvider);
  if (!cloudAccountReady(cloud)) return null;
  final entitled = cloud.phase == CloudPhase.ready;
  final tenant = ref.watch(currentTenantIdProvider);
  if (tenant == cloud.collectionId) return entitled ? tenant : null;
  final col = ref.watch(collectionsProvider.select((s) => s.byId(tenant)));
  if (col == null) {
    // A shared collection before this boot's first fetch (cache still
    // loading / cleared), or one the account was removed from. Stay quiet
    // and make sure a fetch is under way (concurrent calls coalesce); a
    // vanished id goes back home through `_reconcileActive`. Deferred: a
    // provider must not mutate another one during its own build.
    final notifier = ref.read(collectionsProvider.notifier);
    scheduleMicrotask(() {
      if (notifier.mounted) unawaited(notifier.refresh());
    });
    return null;
  }
  return collectionSyncAllowed(cloud, col) ? tenant : null;
});

/// The collection on screen for display purposes (switcher chip, Sharing
/// rows): the current tenant when it is a known collection, else the
/// linked default — regardless of whether it syncs right now.
final shownCollectionProvider = Provider<CloudCollection?>((ref) {
  final cloud = ref.watch(cloudStateProvider);
  if (!cloudAccountReady(cloud)) return null;
  final tenant = ref.watch(currentTenantIdProvider);
  final fromList = ref.watch(collectionsProvider.select((s) => s.byId(tenant) ?? s.byId(cloud.collectionId)));
  if (fromList != null) return fromList;
  return CloudCollection(id: cloud.collectionId!, name: cloud.collectionName ?? '', role: 'owner');
});

/// True when the shown collection is one shared with the account: its
/// sync runs on the owner's plan (a 402 there = the owner's plan lapsed).
final activeCollectionIsSharedProvider = Provider<bool>((ref) {
  final id = ref.watch(activeCollectionIdProvider);
  if (id == null) return false;
  return ref.watch(collectionsProvider.select((s) => s.byId(id)?.isOwner == false));
});

/// Why the collection on screen is read-only, if it is (MULTI-USER-V2
/// §0/§3/§8): [ReadOnlyReason.viewer] for a *viewer* of a shared
/// collection, [ReadOnlyReason.cloudRequired] for any shared collection
/// while the server says the caller's own plan is not active
/// (`caller_entitled == false`). Local-only / own collections are always
/// editable — read-only is a role or a plan, never a connectivity state.
///
/// Belt and braces for the signed-out case: `CollectionsNotifier` sends a
/// device parked on a shared tenant home on session loss; should it still
/// be sitting on a tenant that is not home (not yet flipped, or a link
/// that resolves later), that tenant is somebody else's collection and
/// stays read-only rather than silently turning into local edits.
final activeCollectionReadOnlyReasonProvider = Provider<ReadOnlyReason>((ref) {
  final cloud = ref.watch(cloudStateProvider);
  final tenant = ref.watch(currentTenantIdProvider);
  if (!cloudAccountReady(cloud)) {
    if (cloud.phase != CloudPhase.signedOut) return ReadOnlyReason.none;
    final home = ref.watch(homeCollectionIdProvider);
    return home == null || tenant == home ? ReadOnlyReason.none : ReadOnlyReason.viewer;
  }
  if (tenant == cloud.collectionId) return ReadOnlyReason.none;
  final col = ref.watch(collectionsProvider.select((s) => s.byId(tenant)));
  if (col == null || col.isOwner) return ReadOnlyReason.none;
  if (ref.watch(sharedNeedsCloudProvider)) return ReadOnlyReason.cloudRequired;
  return col.canEdit ? ReadOnlyReason.none : ReadOnlyReason.viewer;
});

/// §8 verdict for the account's SHARED collections: the server says the
/// caller is not entitled (`caller_entitled == false`) OR the client's own
/// check says so (`CloudPhase.notEntitled`, once checked). Either locks
/// every shared collection down locally (read-only, no push, marker).
final sharedNeedsCloudProvider = Provider<bool>((ref) {
  if (!ref.watch(collectionsProvider.select((s) => s.callerEntitled))) return true;
  final cloud = ref.watch(cloudStateProvider);
  return cloud.phase == CloudPhase.notEntitled && !cloud.checking;
});

/// Whether the signed-in account may mutate rows of the collection on
/// screen — [activeCollectionReadOnlyReasonProvider] is `none`. Every
/// mutating affordance in the active tenant (FABs, swipe actions, editors,
/// photo add/delete, import, care actions) watches this and shows the
/// `ReadOnlyBanner` instead.
final canEditActiveCollectionProvider = Provider<bool>((ref) {
  return ref.watch(activeCollectionReadOnlyReasonProvider) == ReadOnlyReason.none;
});

/// True when the account takes part in shared collections that its own
/// plan does not cover (§8, [sharedNeedsCloudProvider]): the Cloud screen
/// shows "Inventory Cloud is required for shared collections".
final sharedCollectionsNeedCloudProvider = Provider<bool>((ref) {
  final cloud = ref.watch(cloudStateProvider);
  if (cloud.phase == CloudPhase.off || cloud.phase == CloudPhase.signedOut) return false;
  if (ref.watch(collectionsProvider.select((s) => s.sharedWithMe.isEmpty))) return false;
  return ref.watch(sharedNeedsCloudProvider);
});

/// Display record for the collection on screen ([shownCollectionProvider]);
/// kept as the name every UI surface reads.
final activeCollectionProvider = Provider<CloudCollection?>((ref) => ref.watch(shownCollectionProvider));

/// Whether the collection switcher renders at all: feature on and more than
/// one collection to choose from. With 0/1 collections every switcher
/// surface is hidden, so single-collection screens stay pixel-identical.
final collectionSwitcherVisibleProvider = Provider<bool>((ref) {
  if (!ref.watch(cloudEnabledProvider)) return false;
  return ref.watch(collectionsProvider.select((s) => s.items.length > 1));
});

/// plantly.ro user id of the signed-in account, null when signed out.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(plantlyAuthProvider).valueOrNull?.userId;
});

/// Members of a collection (`GET …/members`), cached in prefs so names can
/// be resolved offline (timeline `by <username>`). Falls back to the cache
/// on any error; signed out → cache only.
final membersProvider = FutureProvider.family<List<CollectionMember>, String>((ref, collectionId) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  final key = '$kMembersCachePrefPrefix$collectionId';
  List<CollectionMember> cached() {
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    try {
      final decoded = json.decode(raw);
      return [
        if (decoded is List)
          for (final e in decoded)
            if (e is Map<String, dynamic>) CollectionMember.fromJson(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  if (!ref.watch(cloudEnabledProvider)) return cached();
  final session = await ref.read(plantlyAuthProvider.notifier).current();
  if (session == null) return cached();
  try {
    final members = await ref.read(plantlyApiProvider).listMembers(session.token, collectionId);
    await prefs.setString(key, json.encode([for (final m in members) m.toJson()]));
    _clearStaleAssignees(ref, collectionId, members, me: session.userId);
    return members;
  } catch (_) {
    return cached();
  }
});

/// MULTI-USER-V2 §0: after a SUCCESSFUL members fetch of the repository's
/// own tenant, schedules assigned to someone who is no longer a member go
/// back to "everyone" (a local op, so it syncs). Never fails the fetch.
///
/// Guards, each one a reason the list cannot be trusted as "the members":
/// the app context must be open and bound to [collectionId] (the
/// repository writes under `opLog.tenantId`, not whatever the tenant pref
/// says mid-switch); the list must be non-empty and name the signed-in
/// account [me] (an empty / foreign answer is not authoritative); and that
/// account must hold an editing role — a viewer never writes ops, the
/// server would reject them as `read_only`.
void _clearStaleAssignees(Ref ref, String collectionId, List<CollectionMember> members, {required String me}) {
  try {
    // Cheap pre-check before touching the app context (which opens the
    // database): a tenant pref that is not this collection means the
    // repository cannot be bound to it either — skip without side effects.
    if (ref.read(currentTenantIdProvider) != collectionId) return;
    final ctx = ref.read(appContextProvider).asData?.value;
    if (ctx == null || ctx.opLog.tenantId != collectionId) return;
    if (members.isEmpty) return;
    CollectionMember? mine;
    for (final m in members) {
      if (m.userId == me) {
        mine = m;
        break;
      }
    }
    if (mine == null || !mine.canEdit) return;
    final ids = <String>{
      for (final m in members)
        if (m.userId.isNotEmpty) m.userId,
      // Belt and braces: the owner is always a member, even on a server
      // that lists only the invited accounts.
      ...?_ownerOf(ref, collectionId),
    };
    unawaited(ref.read(careScheduleRepositoryProvider).clearAssigneesNotIn(ids).catchError((Object _) => 0));
  } catch (_) {
    // Provider not ready / disposed: nothing to clear this time round.
  }
}

Set<String>? _ownerOf(Ref ref, String collectionId) {
  final owner = ref.read(collectionsProvider).byId(collectionId)?.ownerUserId;
  return owner == null || owner.isEmpty ? null : {owner};
}

/// Username for [userId] in a members list (`membersProvider(...).valueOrNull`),
/// or null when unknown (not fetched yet / no longer a member).
String? memberUsername(List<CollectionMember>? members, String userId) {
  if (members == null) return null;
  for (final m in members) {
    if (m.userId == userId && m.username.isNotEmpty) return m.username;
  }
  return null;
}
