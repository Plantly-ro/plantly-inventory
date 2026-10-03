import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/plantly_features.dart';
import '../data/providers.dart';
import '../marketplace/plantly_api.dart';
import '../marketplace/plantly_auth.dart';

/// Per-collection activity feed (MULTI-USER-V2 §0 "Activity", §2.11).
///
/// The feed is server-fed from the op log — the client keeps no op history
/// of its own. Each collection's newest [kActivityCacheMax] events are
/// cached in prefs (`<prefix><collection id>`) so the screen and the
/// "last edited by" line on plant detail work offline and before the
/// first fetch. No Drift schema involved.

const String kActivityCachePrefPrefix = 'plantly_collection_activity/';
const int kActivityCacheMax = 200;
const int kActivityPageSize = 50;

/// A collection other people can see: more than one member, or one the
/// account does not own. Only these get the Activity surfaces.
bool isSharedCollection(CloudCollection? c) => c != null && (c.memberCount > 1 || !c.isOwner);

/// Cache + fetch, pure of Riverpod so it can be unit-tested with a
/// `MockClient` and mock prefs.
class CollectionActivityRepository {
  CollectionActivityRepository({required this.api, required this.prefs});

  final PlantlyApi api;
  final SharedPreferences prefs;

  static String cacheKey(String collectionId) => '$kActivityCachePrefPrefix$collectionId';

  /// Cached events, newest first; empty when nothing / corrupt.
  List<ActivityEvent> readCache(String collectionId) {
    final raw = prefs.getString(cacheKey(collectionId));
    if (raw == null) return const [];
    try {
      final decoded = json.decode(raw);
      final list = decoded is Map<String, dynamic> ? decoded['events'] : decoded;
      if (list is! List) return const [];
      final events = list.map(ActivityEvent.tryParse).nonNulls.toList();
      events.sort((a, b) => b.seq.compareTo(a.seq));
      return events;
    } catch (_) {
      return const [];
    }
  }

  /// Persists the newest [kActivityCacheMax] of [events] (newest first).
  Future<void> writeCache(String collectionId, List<ActivityEvent> events) async {
    final kept = events.length > kActivityCacheMax ? events.sublist(0, kActivityCacheMax) : events;
    await prefs.setString(
      cacheKey(collectionId),
      json.encode({'events': [for (final e in kept) e.toJson()]}),
    );
  }

  Future<void> clearCache(String collectionId) => prefs.remove(cacheKey(collectionId));

  /// Newest page (`GET …/activity?limit=`).
  Future<ActivityPage> fetchLatest(String token, String collectionId, {int limit = kActivityPageSize}) =>
      api.listActivity(token, collectionId, limit: limit);

  /// Older page (`GET …/activity?before=<seq>&limit=`).
  Future<ActivityPage> fetchBefore(String token, String collectionId, int before, {int limit = kActivityPageSize}) =>
      api.listActivity(token, collectionId, before: before, limit: limit);

  /// Union by `seq`, newest first. Incoming rows win over cached ones with
  /// the same seq (the server is the source of truth).
  static List<ActivityEvent> merge(Iterable<ActivityEvent> existing, Iterable<ActivityEvent> incoming) {
    final bySeq = <int, ActivityEvent>{for (final e in existing) e.seq: e};
    for (final e in incoming) {
      bySeq[e.seq] = e;
    }
    final out = bySeq.values.toList()..sort((a, b) => b.seq.compareTo(a.seq));
    return out;
  }
}

/// What the Activity screen / plant-detail line render.
class ActivityFeedState {
  const ActivityFeedState({
    this.events = const [],
    this.loaded = false,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.fromCache = false,
    this.error,
  });

  /// Newest first. In memory this may exceed [kActivityCacheMax] after
  /// paging; only the newest 200 are persisted.
  final List<ActivityEvent> events;

  /// The prefs cache has been read (events may still be empty).
  final bool loaded;

  /// The newest page is being fetched.
  final bool loading;

  /// An older page is being fetched.
  final bool loadingMore;

  /// The server reported older events beyond what is in memory.
  final bool hasMore;

  /// The last server fetch failed; [events] are the cache (or the previous
  /// successful fetch).
  final bool fromCache;

  /// Last fetch failure (`PlantlyNetworkException` / `PlantlyApiException`).
  final Object? error;

  bool get isEmpty => events.isEmpty;

  /// Oldest seq in memory — the `before` cursor for the next page.
  int? get oldestSeq => events.isEmpty ? null : events.last.seq;
  int? get newestSeq => events.isEmpty ? null : events.first.seq;

  ActivityFeedState copyWith({
    List<ActivityEvent>? events,
    bool? loaded,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    bool? fromCache,
    Object? error = _unset,
  }) =>
      ActivityFeedState(
        events: events ?? this.events,
        loaded: loaded ?? this.loaded,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        fromCache: fromCache ?? this.fromCache,
        error: identical(error, _unset) ? this.error : error,
      );

  static const _unset = Object();

  @override
  String toString() =>
      'ActivityFeedState(${events.length} events, loaded=$loaded, loading=$loading, more=$hasMore, cache=$fromCache, error=$error)';
}

/// Owns one collection's feed: cache first, then the newest page from the
/// server; [refresh] (pull-to-refresh) and [loadMore] ("Load more").
/// Signed out / feature off → cache only, never a network call.
class CollectionActivityNotifier extends StateNotifier<ActivityFeedState> {
  CollectionActivityNotifier(this._ref, this.collectionId, {bool autoStart = true}) : super(const ActivityFeedState()) {
    if (autoStart) {
      _ready = _init();
    } else {
      _ready = Future.value();
    }
  }

  final Ref _ref;
  final String collectionId;
  late final Future<void> _ready;
  CollectionActivityRepository? _repo;
  Future<void>? _inflight;
  Future<void>? _inflightMore;

  /// The server confirmed (next_before null) that we hold its oldest row.
  /// A refresh that merely abuts the cached range must not reopen paging.
  bool _exhausted = false;

  /// Number of server fetches performed (tests).
  int fetches = 0;

  /// Resolves once the cache has been read and the first refresh finished.
  Future<void> get ready => _ready;

  Future<CollectionActivityRepository> _repository() async {
    if (_repo != null) return _repo!;
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    return _repo = CollectionActivityRepository(api: _ref.read(plantlyApiProvider), prefs: prefs);
  }

  Future<void> _init() async {
    final repo = await _repository();
    if (!mounted) return;
    final cached = repo.readCache(collectionId);
    state = state.copyWith(events: cached, loaded: true, fromCache: cached.isNotEmpty);
    await refresh();
  }

  Future<String?> _token() async {
    if (!_ref.read(cloudEnabledProvider)) return null;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    return session?.token;
  }

  /// Fetch the newest page and merge it over what is in memory. Concurrent
  /// calls coalesce.
  Future<void> refresh() {
    final running = _inflight;
    if (running != null) return running;
    final f = _refresh();
    _inflight = f;
    return f.whenComplete(() {
      if (identical(_inflight, f)) _inflight = null;
    });
  }

  Future<void> _refresh() async {
    final repo = await _repository();
    if (!mounted) return;
    final token = await _token();
    if (token == null) {
      if (mounted) state = state.copyWith(loading: false, fromCache: state.events.isNotEmpty, loaded: true);
      return;
    }
    state = state.copyWith(loading: true, error: null);
    try {
      fetches++;
      final page = await repo.fetchLatest(token, collectionId);
      if (!mounted) return;
      final prevNewest = state.newestSeq;
      final pageOldest = page.events.isEmpty ? null : page.events.last.seq;
      // More than a page of new ops since the last fetch: the newest page
      // no longer touches what we hold. Restart from the page so paging
      // (`before = oldest in memory`) stays contiguous instead of jumping
      // below the hole.
      final gap = page.hasMore && prevNewest != null && pageOldest != null && pageOldest > prevNewest + 1;
      final events = gap ? page.events : CollectionActivityRepository.merge(state.events, page.events);
      if (gap) _exhausted = false;
      if (!page.hasMore) _exhausted = true;
      await repo.writeCache(collectionId, events);
      if (!mounted) return;
      state = state.copyWith(
        events: events,
        loading: false,
        loaded: true,
        fromCache: false,
        error: null,
        // The server knows rows older than this page, unless it already
        // told us we hold its oldest row and this page just abuts/overlaps
        // that range (a fully paged feed that then grew).
        hasMore: page.hasMore && !_exhausted,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loading: false, loaded: true, fromCache: true, error: e);
    }
  }

  /// Fetch the page older than the oldest event in memory. Concurrent
  /// calls coalesce.
  Future<void> loadMore() {
    final running = _inflightMore;
    if (running != null) return running;
    final f = _loadMore();
    _inflightMore = f;
    return f.whenComplete(() {
      if (identical(_inflightMore, f)) _inflightMore = null;
    });
  }

  Future<void> _loadMore() async {
    final before = state.oldestSeq;
    if (before == null || state.loadingMore || !state.hasMore) return;
    final repo = await _repository();
    if (!mounted) return;
    final token = await _token();
    if (token == null) return;
    state = state.copyWith(loadingMore: true, error: null);
    try {
      fetches++;
      final page = await repo.fetchBefore(token, collectionId, before);
      if (!mounted) return;
      final merged = CollectionActivityRepository.merge(state.events, page.events);
      await repo.writeCache(collectionId, merged);
      if (!mounted) return;
      if (!page.hasMore) _exhausted = true;
      state = state.copyWith(events: merged, loadingMore: false, hasMore: page.hasMore, error: null);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(loadingMore: false, error: e);
    }
  }
}

/// One feed per collection id. Not auto-disposed: plant detail and the
/// Activity screen share the in-memory feed; the cache makes it cheap.
final collectionActivityProvider =
    StateNotifierProvider.family<CollectionActivityNotifier, ActivityFeedState, String>(
  (ref, collectionId) => CollectionActivityNotifier(ref, collectionId),
);

/// Newest event touching [entityId] made by someone other than
/// [excludeUserId] (the signed-in user), or null when the feed holds none
/// — the plant-detail "last edited by" source. [events] newest first.
ActivityEvent? latestEditBy(Iterable<ActivityEvent> events, {required String entityId, String? excludeUserId}) {
  for (final e in events) {
    if (e.entityId != entityId) continue;
    if (e.user.id.isEmpty) continue;
    if (excludeUserId != null && e.user.id == excludeUserId) continue;
    return e;
  }
  return null;
}
