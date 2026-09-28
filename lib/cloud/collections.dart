import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/plantly_features.dart';
import '../data/providers.dart';
import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_auth.dart';
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
  });

  /// Own default first (when known), then the shared ones by name.
  final List<CloudCollection> items;

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
  }) =>
      CollectionsState(
        items: items ?? this.items,
        loaded: loaded ?? this.loaded,
        loading: loading ?? this.loading,
        error: identical(error, _unset) ? this.error : error,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  static const _unset = Object();

  @override
  String toString() => 'CollectionsState(${items.length} items, loaded=$loaded, loading=$loading, error=$error)';
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
  }) : super(CollectionsState(items: initial, loaded: !autoStart)) {
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
          if (mounted) state = state.copyWith(items: const [], loading: false, error: null);
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
    if (raw != null && session != null) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map<String, dynamic> && decoded['user_id'] == session.userId) {
          items = _decodeList(decoded['items']);
        }
      } catch (_) {
        // Corrupt cache — ignore, the next fetch rewrites it.
      }
    }
    if (mounted) state = state.copyWith(items: items, loaded: true);
  }

  static List<CloudCollection> _decodeList(Object? list) => [
        if (list is List)
          for (final e in list)
            if (e is Map<String, dynamic>) CloudCollection.fromJson(e),
      ];

  Future<void> _saveCache(String userId, List<CloudCollection> items) async {
    final p = await _prefs;
    await p.setString(
      kCollectionsCachePrefKey,
      json.encode({'user_id': userId, 'items': [for (final c in items) c.toJson()]}),
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
      if (mounted) state = state.copyWith(items: const [], loading: false, error: null);
      return;
    }
    if (mounted) state = state.copyWith(loading: true);
    try {
      fetches++;
      final fetched = await _ref.read(plantlyApiProvider).listCollections(session.token);
      final items = _sorted(_withLinkedDefault(fetched));
      await _saveCache(session.userId, items);
      if (!mounted) return;
      state = state.copyWith(items: items, loading: false, error: null, fetchedAt: DateTime.now().toUtc());
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

  /// `POST /inventory/collections/join`. Adds the collection to the list
  /// and switches to it (editors sync on the owner's plan, so a caller
  /// without a plan of their own still gets there — the device only needs
  /// its link, which is attempted here when missing). Throws `StateError`
  /// when signed out; API / network errors pass through. Returns the
  /// joined collection.
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

  /// Owner: mint a 7-day invite for [collectionId].
  Future<CollectionInvite> createInvite(String collectionId) async {
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    return _ref.read(plantlyApiProvider).createInvite(session.token, collectionId);
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
    return members;
  } catch (_) {
    return cached();
  }
});

/// Username for [userId] in a members list (`membersProvider(...).valueOrNull`),
/// or null when unknown (not fetched yet / no longer a member).
String? memberUsername(List<CollectionMember>? members, String userId) {
  if (members == null) return null;
  for (final m in members) {
    if (m.userId == userId && m.username.isNotEmpty) return m.username;
  }
  return null;
}
