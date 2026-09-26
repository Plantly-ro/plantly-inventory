import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulid/ulid.dart';

import '../data/database/app_database.dart';
import '../data/providers.dart';
import '../marketplace/plantly_auth.dart';

/// The cloud collection this device is linked to (CLOUD-SYNC-CONTRACT §2.4),
/// remembered together with the account that linked it: a different user
/// signing in on this device must never sync into it.
class CollectionLink {
  const CollectionLink({required this.id, required this.name, required this.userId, this.username = ''});
  final String id;
  final String name;
  final String userId;

  /// Display name of the linking account (for the account-switch prompt).
  final String username;

  /// What to call the linking account in copy.
  String get accountLabel => username.isNotEmpty ? username : userId;

  @override
  bool operator ==(Object other) =>
      other is CollectionLink &&
      other.id == id &&
      other.name == name &&
      other.userId == userId &&
      other.username == username;

  @override
  int get hashCode => Object.hash(id, name, userId, username);

  @override
  String toString() => 'CollectionLink($id, $name, user=$userId)';
}

/// Persisted link state. [unlinkedByUser] makes "Unlink this device" stick:
/// the UI shows "sync is off here" and nothing auto-relinks until the user
/// asks (or a new sign-in happens).
class CollectionLinkState {
  const CollectionLinkState({this.link, this.unlinkedByUser = false, this.loaded = false});
  final CollectionLink? link;
  final bool unlinkedByUser;

  /// True once prefs have been read.
  final bool loaded;

  CollectionLinkState copyWith({Object? link = _unset, bool? unlinkedByUser, bool? loaded}) => CollectionLinkState(
        link: identical(link, _unset) ? this.link : link as CollectionLink?,
        unlinkedByUser: unlinkedByUser ?? this.unlinkedByUser,
        loaded: loaded ?? this.loaded,
      );

  static const _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is CollectionLinkState &&
      other.link == link &&
      other.unlinkedByUser == unlinkedByUser &&
      other.loaded == loaded;

  @override
  int get hashCode => Object.hash(link, unlinkedByUser, loaded);

  @override
  String toString() => 'CollectionLinkState($link, unlinkedByUser=$unlinkedByUser, loaded=$loaded)';
}

const String kCollectionIdPrefKey = 'plantly_collection_id';
const String kCollectionNamePrefKey = 'plantly_collection_name';
const String kCollectionUserIdPrefKey = 'plantly_collection_user_id';
const String kCollectionUsernamePrefKey = 'plantly_collection_username';
const String kCloudUnlinkedPrefKey = 'plantly_cloud_unlinked';

/// Move every row (and every pending op) from tenant [from] to tenant [to]
/// in ONE transaction. Generic over the schema: any table with a
/// `tenant_id` column is rewritten, so a new entity table can't be missed.
/// `sync_ops` rides along on purpose — the un-pushed ops must be pushed
/// under the collection later. Idempotent: a second run finds no [from]
/// rows and changes nothing. Returns the number of rows rewritten.
Future<int> migrateTenant(AppDatabase db, {required String from, required String to}) async {
  if (from == to) return 0;
  return db.transaction(() async {
    var rewritten = 0;
    for (final table in db.allTables) {
      if (!table.columnsByName.containsKey('tenant_id')) continue;
      rewritten += await db.customUpdate(
        'UPDATE ${table.actualTableName} SET tenant_id = ? WHERE tenant_id = ?',
        variables: [Variable<String>(to), Variable<String>(from)],
        updates: {table},
        updateKind: UpdateKind.update,
      );
    }
    return rewritten;
  });
}

/// Links this device to the signed-in user's default collection and owns
/// the persisted link. Linking = `POST /collections/default` → tenant
/// migration → prefs → flip [currentTenantIdProvider]. Unlinking forgets
/// the link only: data and tenant id stay as they are (the engine watches
/// `cloudStateProvider` and simply stops).
class CollectionLinkService extends StateNotifier<CollectionLinkState> {
  CollectionLinkService(this._ref) : super(const CollectionLinkState()) {
    _loaded = _load();
  }

  final Ref _ref;
  late final Future<void> _loaded;
  Future<CollectionLink>? _inflight;

  Future<SharedPreferences> get _prefs => _ref.read(sharedPreferencesProvider.future);

  Future<void> _load() async {
    final p = await _prefs;
    final id = p.getString(kCollectionIdPrefKey);
    if (!mounted) return;
    state = CollectionLinkState(
      link: id == null || id.isEmpty
          ? null
          : CollectionLink(
              id: id,
              name: p.getString(kCollectionNamePrefKey) ?? '',
              userId: p.getString(kCollectionUserIdPrefKey) ?? '',
              username: p.getString(kCollectionUsernamePrefKey) ?? '',
            ),
      unlinkedByUser: p.getBool(kCloudUnlinkedPrefKey) ?? false,
      loaded: true,
    );
  }

  /// Resolves once the persisted link has been read.
  Future<void> get ready => _loaded;

  /// Link (or re-link) to the signed-in user's default collection.
  /// Concurrent calls share one run. Throws `StateError` when signed out;
  /// `PlantlyApiException` / `PlantlyNetworkException` pass through.
  Future<CollectionLink> link() {
    return _inflight ??= _link().whenComplete(() => _inflight = null);
  }

  Future<CollectionLink> _link() async {
    await _loaded;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    final col = await _ref.read(plantlyApiProvider).ensureDefaultCollection(session.token);

    final db = _ref.read(databaseProvider);
    final from = _ref.read(currentTenantIdProvider);
    await migrateTenant(db, from: from, to: col.id);

    // Persist only after the transaction committed: a crash in between
    // leaves rows under the new id with prefs still pointing at the old
    // one, which the next link() heals (migrateTenant is idempotent and
    // the old tenant simply has no rows left).
    final p = await _prefs;
    await p.setString(kTenantIdPrefKey, col.id);
    await p.setString(kCollectionIdPrefKey, col.id);
    await p.setString(kCollectionNamePrefKey, col.name);
    await p.setString(kCollectionUserIdPrefKey, session.userId);
    await p.setString(kCollectionUsernamePrefKey, session.username);
    await p.remove(kCloudUnlinkedPrefKey);

    _ref.read(currentTenantIdProvider.notifier).state = col.id;
    final link = CollectionLink(id: col.id, name: col.name, userId: session.userId, username: session.username);
    if (mounted) state = state.copyWith(link: link, unlinkedByUser: false, loaded: true);
    return link;
  }

  /// Link unless this device is already linked *for the signed-in user*.
  /// Returns null — and links NOTHING — when the persisted link belongs to
  /// another account: that is a decision for the user ("Move this device's
  /// plants" = [link], "Start empty" = [startEmpty]), never an automatic
  /// migration of someone else's data.
  Future<CollectionLink?> ensureLinked() async {
    await _loaded;
    final current = state.link;
    if (current == null) return link();
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    return session.userId == current.userId ? current : null;
  }

  /// Account switch, "Start empty for <B>": park the previous account's
  /// rows where they are (under their collection id as tenant — invisible,
  /// never pushed, untouched on disk) and give B a fresh, empty local
  /// tenant that then links to B's default collection. No rows migrate.
  /// The demo seed is suppressed for good on this device ([kSkipSeedPrefKey]).
  ///
  /// Recovery: when A signs in again and chooses "Start empty" too, the
  /// fresh tenant is renamed to A's collection id by [link] — the very id
  /// A's rows still carry — so they reappear without any copy.
  Future<CollectionLink> startEmpty() async {
    await _loaded;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    final fresh = 'local-${Ulid()}';
    final p = await _prefs;
    await p.setBool(kSkipSeedPrefKey, true);
    await p.setString(kTenantIdPrefKey, fresh);
    _ref.read(currentTenantIdProvider.notifier).state = fresh;
    // link() migrates `fresh` (no rows) → B's collection id.
    return link();
  }

  /// Forget the link and remember that the user asked for it. Local data
  /// and the tenant id are untouched; nothing is deleted on the server.
  Future<void> unlink() async {
    await _loaded;
    final p = await _prefs;
    await p.remove(kCollectionIdPrefKey);
    await p.remove(kCollectionNamePrefKey);
    await p.remove(kCollectionUserIdPrefKey);
    await p.remove(kCollectionUsernamePrefKey);
    await p.setBool(kCloudUnlinkedPrefKey, true);
    if (mounted) state = state.copyWith(link: null, unlinkedByUser: true, loaded: true);
  }
}

final collectionLinkProvider = StateNotifierProvider<CollectionLinkService, CollectionLinkState>((ref) {
  return CollectionLinkService(ref);
});
