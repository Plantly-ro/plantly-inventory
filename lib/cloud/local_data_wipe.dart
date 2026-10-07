import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/plantly_features.dart';
import '../data/database/app_database.dart';
import '../data/photo_blob_store.dart';
import '../data/providers.dart';
import '../marketplace/plantly_auth.dart';
import '../shared/page_reload.dart';
import '../shared/session_tab_events.dart';
import 'cloud_sync.dart';
import 'collections.dart' show deviceRevokedNoticeProvider;

/// Prefs that survive [wipeLocalData]: this browser's UI choices, not
/// account data. Everything else under the `plantly` prefix goes — tenant,
/// link, data owner, sync cursors, collection / member / activity caches,
/// entitlement cache, greeting name, parked routes and invites, seed state.
/// The device id stays: it names this browser install (the server keys
/// devices per account; a new id per sign-in would churn the device cap).
const Set<String> kWipeKeptPrefKeys = {
  'plantly_theme',
  'plantly_layout',
  'plantly_plant_sort',
  'plantly_onboarded',
  'plantly_dnd_enabled',
  'plantly_dnd_start',
  'plantly_dnd_end',
  'plantly_crash_consent',
  'plantly_analytics_consent',
  'plantly_care_types',
  'plantly_muted_type_keys',
  'plantly_quick_fab_type',
  'plantly_device_id',
};

/// Deletes every row of every table (all tenants, op log, rejection ledger,
/// search index) with `secure_delete` on and VACUUMs, so the rows are not
/// left readable in free pages of the database file. Throws on failure.
Future<void> wipeDatabase(AppDatabase db) async {
  await db.customStatement('PRAGMA secure_delete = ON');
  await db.transaction(() async {
    for (final table in db.allTables) {
      await db.customUpdate(
        'DELETE FROM ${table.actualTableName}',
        updates: {table},
        updateKind: UpdateKind.delete,
      );
    }
    await db.customStatement('DELETE FROM plants_fts');
  });
  await db.customStatement('VACUUM');
}

/// Empties this install's local copy: the database ([wipeDatabase]), then
/// — only once that succeeded — every photo blob and the account-scoped
/// prefs ([kWipeKeptPrefKeys]). A failed database wipe leaves blobs and
/// prefs alone (the data-owner marker keeps protecting the rows) and
/// rethrows. The plantly.ro session itself is not touched here.
Future<void> wipeLocalData({
  required AppDatabase db,
  required PhotoBlobStore blobs,
  required SharedPreferences prefs,
}) async {
  await wipeDatabase(db);
  if (blobs is ClearablePhotoBlobStore) {
    await (blobs as ClearablePhotoBlobStore).clear();
  }
  for (final key in prefs.getKeys().toList()) {
    if (key.startsWith('plantly') && !kWipeKeptPrefKeys.contains(key)) await prefs.remove(key);
  }
}

/// Web only (WEB-ACCESS-POLICY §0: the browser is a cloud surface, the
/// local database a cache of the collection). Wipes ONLY on an explicit
/// user decision — sign-out from Me → Cloud / the gate / Me → plantly.ro,
/// the gate's "clear this browser" — or a confirmed `device_revoked`. Any
/// other loss of the session (refresh 401, max token age, a plugin 401)
/// keeps the data; the gate stays closed until the same account signs in
/// again, and another account meets the held-by-other gate.
class LocalDataWiper {
  LocalDataWiper(this._ref);
  final Ref _ref;
  Future<void>? _inflight;

  /// Ops still waiting for the cloud that the signed-in account owns
  /// (unattributed ones included), across every tenant on this device.
  Future<int> pendingCount() async {
    final db = _ref.read(databaseProvider);
    final me = _ref.read(plantlyAuthProvider).valueOrNull?.userId;
    final row = await db
        .customSelect(
          'SELECT COUNT(*) AS n FROM sync_ops WHERE pushed_at IS NULL AND (user_id IS NULL OR user_id = ?)',
          variables: [Variable<String>(me ?? '')],
          readsFrom: {db.syncOps},
        )
        .getSingle();
    return row.read<int>('n');
  }

  /// Push what is pending: `syncNow` until nothing is left or [timeout]
  /// runs out (a cycle already in flight may predate the last edit, so one
  /// call is not enough). Returns what is still pending.
  Future<int> flush({Duration timeout = const Duration(seconds: 15), Duration pause = const Duration(milliseconds: 300)}) async {
    final deadline = DateTime.now().add(timeout);
    var pending = await pendingCount();
    while (pending > 0) {
      final left = deadline.difference(DateTime.now());
      if (left <= Duration.zero) break;
      try {
        await _ref.read(syncRunnerProvider).syncNow().timeout(left);
      } catch (_) {
        // Offline / timed out: report what is left.
      }
      pending = await pendingCount();
      if (pending == 0 || DateTime.now().isAfter(deadline)) break;
      await Future<void>.delayed(pause);
    }
    return pending;
  }

  Future<void> _wipe() async => wipeLocalData(
        db: _ref.read(databaseProvider),
        blobs: _ref.read(photoBlobStoreProvider),
        prefs: await _ref.read(sharedPreferencesProvider.future),
      );

  /// The explicit sign-out, after the caller's confirmations (and flush):
  /// drop the session first — the `storage` event sends every other tab
  /// of this browser into a reload, so none keeps writing — then wipe and
  /// reload at the root. A failed database wipe rethrows WITHOUT reloading:
  /// the caller surfaces it; the rows stay behind the closed gate.
  Future<void> signOutAndWipe() async {
    await _ref.read(plantlyAuthProvider.notifier).signOut();
    await _wipeThenReload();
  }

  /// Wipe and reload, keeping the session (the gate's "clear this browser",
  /// a confirmed `device_revoked`). Single-flight; rethrows a failure.
  Future<void> wipeAndReload() => _wipeThenReload();

  Future<void> _wipeThenReload() => _inflight ??= () async {
        try {
          // Let the sign-out's own listeners (runner disposal, tenant
          // fallback) settle first so none of them writes after the wipe.
          await Future<void>.delayed(Duration.zero);
          await _wipe();
        } catch (e, st) {
          debugPrint('local_data_wipe: failed, nothing reloaded: $e\n$st');
          rethrow;
        } finally {
          _inflight = null;
        }
        _ref.read(pageReloaderProvider)();
      }();
}

final localDataWiperProvider = Provider<LocalDataWiper>((ref) => LocalDataWiper(ref));

/// Web session guard, read once from the app root (inert off web):
///  * another tab dropped the session → reload this one at once, so it
///    stops accepting writes and shows the gate (the tab that signed out
///    owns the wipe);
///  * the server confirmed `device_revoked` → wipe this browser + reload.
final webSessionGuardProvider = Provider<void>((ref) {
  if (!ref.watch(webPlatformProvider)) return;
  final sub = ref.watch(sessionRemovedInOtherTabProvider).listen((_) => ref.read(pageReloaderProvider)());
  ref.onDispose(sub.cancel);
  ref.listen<bool>(deviceRevokedNoticeProvider, (prev, next) {
    if (next && prev != true) {
      unawaited(ref.read(localDataWiperProvider).wipeAndReload().catchError((_) {}));
    }
  });
});
