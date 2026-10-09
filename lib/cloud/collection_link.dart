import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulid/ulid.dart';

import '../config/plantly_features.dart';
import '../data/database/app_database.dart';
import '../data/providers.dart';
import '../data/seed_manifest.dart';
import '../marketplace/plantly_auth.dart';
import '../sync/device_id.dart';
import '../sync/sync_markers.dart';

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
///
/// [dataOwnerUserId] is the account whose data lives in the local tenant.
/// It is written by every successful [CollectionLinkService.link] (so also
/// by "Move" and "Start empty") and — unlike the link — survives
/// [CollectionLinkService.unlink]: after A unlinks, B signing in must still
/// get the Move / Start empty decision instead of an automatic migration of
/// A's rows into B's collection. Cleared when the local tenant holds no
/// rows at all (fresh device, data wiped) so it never blocks needlessly.
class CollectionLinkState {
  const CollectionLinkState({
    this.link,
    this.unlinkedByUser = false,
    this.loaded = false,
    this.dataOwnerUserId,
    this.dataOwnerUsername = '',
  });
  final CollectionLink? link;
  final bool unlinkedByUser;

  /// True once prefs have been read.
  final bool loaded;

  /// Account the local rows belong to; null = nobody has claimed them yet.
  final String? dataOwnerUserId;
  final String dataOwnerUsername;

  /// What to call the data owner in copy.
  String? get dataOwnerLabel {
    final id = dataOwnerUserId;
    if (id == null || id.isEmpty) return null;
    return dataOwnerUsername.isNotEmpty ? dataOwnerUsername : id;
  }

  /// True when the local rows belong to someone other than [userId].
  bool dataHeldByOther(String userId) {
    final id = dataOwnerUserId;
    return id != null && id.isNotEmpty && id != userId;
  }

  /// Who to name when this device holds data of an account other than
  /// [userId] — the data owner, else the account behind a foreign link —
  /// or null when everything here is [userId]'s (`CloudState.heldByOther`).
  String? heldByOtherLabel(String userId) {
    if (dataHeldByOther(userId)) return dataOwnerLabel;
    final stored = link;
    if (stored != null && stored.userId != userId) return stored.accountLabel;
    return null;
  }

  CollectionLinkState copyWith({
    Object? link = _unset,
    bool? unlinkedByUser,
    bool? loaded,
    Object? dataOwnerUserId = _unset,
    String? dataOwnerUsername,
  }) =>
      CollectionLinkState(
        link: identical(link, _unset) ? this.link : link as CollectionLink?,
        unlinkedByUser: unlinkedByUser ?? this.unlinkedByUser,
        loaded: loaded ?? this.loaded,
        dataOwnerUserId: identical(dataOwnerUserId, _unset) ? this.dataOwnerUserId : dataOwnerUserId as String?,
        dataOwnerUsername: dataOwnerUsername ?? this.dataOwnerUsername,
      );

  static const _unset = Object();

  @override
  bool operator ==(Object other) =>
      other is CollectionLinkState &&
      other.link == link &&
      other.unlinkedByUser == unlinkedByUser &&
      other.loaded == loaded &&
      other.dataOwnerUserId == dataOwnerUserId &&
      other.dataOwnerUsername == dataOwnerUsername;

  @override
  int get hashCode => Object.hash(link, unlinkedByUser, loaded, dataOwnerUserId, dataOwnerUsername);

  @override
  String toString() =>
      'CollectionLinkState($link, unlinkedByUser=$unlinkedByUser, loaded=$loaded, owner=$dataOwnerUserId)';
}

const String kCollectionIdPrefKey = 'plantly_collection_id';
const String kCollectionNamePrefKey = 'plantly_collection_name';
const String kCollectionUserIdPrefKey = 'plantly_collection_user_id';
const String kCollectionUsernamePrefKey = 'plantly_collection_username';
const String kCloudUnlinkedPrefKey = 'plantly_cloud_unlinked';

/// Who owns the rows in the local tenant (see [CollectionLinkState]).
const String kDataOwnerUserIdPrefKey = 'plantly_data_owner_user_id';
const String kDataOwnerUsernamePrefKey = 'plantly_data_owner_username';

/// A tenant id that names a server collection, as opposed to the pre-cloud
/// [kDefaultTenantId] or a `local-<ulid>` "start empty" tenant.
bool isCollectionTenant(String tenant) => tenant != kDefaultTenantId && !tenant.startsWith('local-');

/// True when no table holds a single row for [tenant] (`sync_ops`
/// included) — nothing on this device that anyone could own.
Future<bool> tenantIsEmpty(AppDatabase db, String tenant) async {
  for (final table in db.allTables) {
    if (!table.columnsByName.containsKey('tenant_id')) continue;
    final row = await db.customSelect(
      'SELECT EXISTS(SELECT 1 FROM ${table.actualTableName} WHERE tenant_id = ?) AS present',
      variables: [Variable<String>(tenant)],
    ).getSingle();
    if (row.read<bool>('present')) return false;
  }
  return true;
}

/// Move every row (and every pending op) from tenant [from] to tenant [to]
/// in ONE transaction. Generic over the schema: any table with a
/// `tenant_id` column is rewritten, so a new entity table can't be missed.
/// `sync_ops` rides along on purpose — the un-pushed ops must be pushed
/// under the collection later. Idempotent: a second run finds no [from]
/// rows and changes nothing. Returns the number of rows rewritten.
///
/// [resetSyncState]: the rows are moving into a collection that has never
/// seen [from]'s op log (another account's collection, a re-created home
/// after a delete / purge, or a never-linked local tenant). [from]'s
/// `sync_ops` (pushed history AND pending ops, which may be stamped with
/// another account and would never be pushed) and its rejection ledger are
/// discarded, and `photos.remote_state='synced'` drops back to `'local'`
/// so the blobs upload again; `'remote'` photos (blob never downloaded,
/// unreachable from another collection) are dropped with their links. The runner's initial-upload pass then
/// synthesizes one `*` op per live row (row HLC, current account) — the
/// whole collection is re-uploaded, tombstones are not needed.
Future<int> migrateTenant(
  AppDatabase db, {
  required String from,
  required String to,
  bool resetSyncState = false,
}) async {
  if (from == to) return 0;
  return db.transaction(() async {
    // One-shot sync passes re-run for both: [from]'s log is discarded or
    // merged into [to]'s, so neither marker describes the result any more.
    await clearSyncMarkers(db, tenantId: from);
    await clearSyncMarkers(db, tenantId: to);
    if (resetSyncState) {
      for (final TableInfo table in [db.syncOps, db.syncRejections]) {
        await db.customUpdate(
          'DELETE FROM ${table.actualTableName} WHERE tenant_id = ?',
          variables: [Variable<String>(from)],
          updates: {table},
          updateKind: UpdateKind.delete,
        );
      }
      await db.customUpdate(
        "UPDATE photos SET remote_state = 'local' WHERE tenant_id = ? AND remote_state = 'synced'",
        variables: [Variable<String>(from)],
        updates: {db.photos},
        updateKind: UpdateKind.update,
      );
      // `remote` photos never reached this device and blobs are stored per
      // collection: the new collection could never serve them. Drop them
      // (and every link to them) rather than upload broken images.
      const remote = "SELECT sha256 FROM photos WHERE tenant_id = ? AND remote_state = 'remote'";
      final f = Variable<String>(from);
      Future<void> run(String sql, TableInfo table, UpdateKind kind) => db.customUpdate(
            sql,
            variables: [f, f],
            updates: {table},
            updateKind: kind,
          );
      await run('DELETE FROM plant_photos WHERE tenant_id = ? AND photo_sha IN ($remote)', db.plantPhotos, UpdateKind.delete);
      await run('DELETE FROM location_photos WHERE tenant_id = ? AND photo_sha IN ($remote)', db.locationPhotos,
          UpdateKind.delete);
      await run('UPDATE care_events SET photo_sha = NULL WHERE tenant_id = ? AND photo_sha IN ($remote)', db.careEvents,
          UpdateKind.update);
      await run('UPDATE locations SET map_photo_sha = NULL WHERE tenant_id = ? AND map_photo_sha IN ($remote)',
          db.locations, UpdateKind.update);
      await db.customUpdate(
        "DELETE FROM photos WHERE tenant_id = ? AND remote_state = 'remote'",
        variables: [f],
        updates: {db.photos},
        updateKind: UpdateKind.delete,
      );
    }
    var rewritten = 0;
    for (final table in db.allTables) {
      if (!table.columnsByName.containsKey('tenant_id')) continue;
      // Tables keyed per tenant (`photos`: (tenant_id, sha256)) can already
      // hold the same key under [to]; that row wins and the [from] duplicate
      // is dropped (the blob on disk is shared by sha, nothing is lost).
      final perTenantKey = table.$primaryKey.any((c) => c.name == 'tenant_id');
      rewritten += await db.customUpdate(
        'UPDATE${perTenantKey ? ' OR IGNORE' : ''} ${table.actualTableName} SET tenant_id = ? WHERE tenant_id = ?',
        variables: [Variable<String>(to), Variable<String>(from)],
        updates: {table},
        updateKind: UpdateKind.update,
      );
      if (perTenantKey) {
        await db.customUpdate(
          'DELETE FROM ${table.actualTableName} WHERE tenant_id = ?',
          variables: [Variable<String>(from)],
          updates: {table},
          updateKind: UpdateKind.delete,
        );
      }
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
    var owner = p.getString(kDataOwnerUserIdPrefKey);
    if (owner != null && owner.isNotEmpty) {
      // A marker with nothing behind it (data wiped, or a tenant that never
      // received a row) must not block the next account.
      final tenant = p.getString(kTenantIdPrefKey) ?? kDefaultTenantId;
      if (await tenantIsEmpty(_ref.read(databaseProvider), tenant)) {
        await p.remove(kDataOwnerUserIdPrefKey);
        await p.remove(kDataOwnerUsernamePrefKey);
        owner = null;
      }
    }
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
      dataOwnerUserId: owner == null || owner.isEmpty ? null : owner,
      dataOwnerUsername: owner == null ? '' : (p.getString(kDataOwnerUsernamePrefKey) ?? ''),
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
    var from = _ref.read(currentTenantIdProvider);
    // Shared collections (§3): while switched to a collection somebody else
    // owns, the tenant is that collection's id. "This device's plants" are
    // the ones under the previously linked default — never migrate the
    // shared collection's rows into another account's default.
    final stored = state.link;
    if (stored != null && from != stored.id && isCollectionTenant(from)) from = stored.id;
    final p = await _prefs;
    if (from != col.id && !isCollectionTenant(from)) {
      // Demo plants the user never touched are not theirs to upload: drop
      // them (local rows only — never pushed, so no tombstones needed).
      await dropUntouchedSeed(
        db: db,
        tenant: from,
        prefs: p,
        deviceId: await DeviceId.load(p),
        web: _ref.read(webPlatformProvider),
      );
    }
    // A different collection (account switch "Move", a re-created home, a
    // first link) never saw [from]'s op log: re-upload everything from the
    // rows. Re-linking the same collection keeps the log (from == to).
    await migrateTenant(db, from: from, to: col.id, resetSyncState: true);

    // Persist only after the transaction committed: a crash in between
    // leaves rows under the new id with prefs still pointing at the old
    // one, which the next link() heals (migrateTenant is idempotent and
    // the old tenant simply has no rows left).
    await p.setString(kTenantIdPrefKey, col.id);
    // Linked once = never seed demo data again on this install (an unlink
    // keeps the collection tenant; a later empty tenant stays empty).
    await p.setBool(kSkipSeedPrefKey, true);
    await clearSeedManifest(p);
    await p.setString(kCollectionIdPrefKey, col.id);
    await p.setString(kCollectionNamePrefKey, col.name);
    await p.setString(kCollectionUserIdPrefKey, session.userId);
    await p.setString(kCollectionUsernamePrefKey, session.username);
    await p.remove(kCloudUnlinkedPrefKey);
    // The rows in the local tenant now belong to this account — whether
    // they were migrated in ("Move") or the tenant is fresh ("Start empty").
    await p.setString(kDataOwnerUserIdPrefKey, session.userId);
    await p.setString(kDataOwnerUsernamePrefKey, session.username);

    _ref.read(currentTenantIdProvider.notifier).state = col.id;
    final link = CollectionLink(id: col.id, name: col.name, userId: session.userId, username: session.username);
    if (mounted) {
      state = state.copyWith(
        link: link,
        unlinkedByUser: false,
        loaded: true,
        dataOwnerUserId: session.userId,
        dataOwnerUsername: session.username,
      );
    }
    return link;
  }

  /// Link unless this device is already linked *for the signed-in user*.
  /// Returns null — and links NOTHING — when the local data belongs to
  /// another account (data-owner marker, or a persisted link made by
  /// someone else): that is a decision for the user ("Move this device's
  /// plants" = [link], "Start empty" = [startEmpty]), never an automatic
  /// migration of someone else's data.
  Future<CollectionLink?> ensureLinked() async {
    await _loaded;
    final session = await _ref.read(plantlyAuthProvider.notifier).current();
    if (session == null) throw StateError('not signed in');
    if (state.dataHeldByOther(session.userId)) return null;
    final current = state.link;
    if (current == null) return link();
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

  /// Forget the link and remember that the user asked for it. Local data,
  /// the tenant id and the data-owner marker are untouched; nothing is
  /// deleted on the server. A device switched to a shared collection (§3)
  /// goes back to its own default tenant first — the shared rows stay on
  /// disk under their collection id, invisible until the next switch.
  Future<void> unlink() async {
    await _loaded;
    final p = await _prefs;
    final link = state.link;
    if (link != null && _ref.read(currentTenantIdProvider) != link.id) {
      await p.setString(kTenantIdPrefKey, link.id);
      _ref.read(currentTenantIdProvider.notifier).state = link.id;
    }
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
