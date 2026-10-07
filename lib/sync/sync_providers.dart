import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_state.dart';
import '../cloud/collections.dart';
import '../cloud/entitlement.dart';
import '../cloud/sync_runner.dart';
import '../data/database/app_database.dart';
import '../data/photo_blob_store.dart';
import '../data/providers.dart';
import '../marketplace/plantly_auth.dart';
import 'device_meta.dart';
import 'http_sync_runner.dart';
import 'http_sync_transport.dart';
import 'op_log.dart';
import 'photo_sync.dart';
import 'sync_engine.dart';
import 'sync_rejections.dart';
import 'sync_transport.dart';

/// Server collection id to sync against; null = cloud off. Derived from the
/// account layer: only while `cloudStateProvider.canSync` (feature on,
/// signed in, entitled, linked for *this* account) — never `'local'`, never
/// a tenant id while unlinked. With shared collections (§3) this is the
/// *active* collection (`activeCollectionIdProvider`): the current tenant
/// when it is a collection the account can see, else the linked default.
final syncCollectionIdProvider = Provider<String?>((ref) {
  return ref.watch(activeCollectionIdProvider);
});

/// Timings of the sync loop; overridden by tests to shorten the waits.
class SyncRunnerConfig {
  const SyncRunnerConfig({
    this.debounce = const Duration(seconds: 3),
    this.periodic = const Duration(minutes: 15),
    this.minBackoff = const Duration(seconds: 1),
    this.maxBackoff = const Duration(minutes: 15),
    this.usageInterval = const Duration(minutes: 10),
    this.linkDebounce = const Duration(milliseconds: 500),
  });

  /// Quiet period after a local write before a push (§2.4: 3 s).
  final Duration debounce;

  /// Foreground periodic sync; `Duration.zero` disables it.
  final Duration periodic;
  final Duration minBackoff;
  final Duration maxBackoff;
  final Duration usageInterval;

  /// Coalescing window for the "sync right after sign-in / link" requests
  /// (`CloudSyncCoordinator`), not a network timing.
  final Duration linkDebounce;
}

final syncRunnerConfigProvider = Provider<SyncRunnerConfig>((_) => const SyncRunnerConfig());

/// HTTP transport bound to the current collection, or null when cloud is
/// off. Sends `X-Plantly-Client` from `PlantlyHosts.clientHeader`, the same
/// value the account layer's `PlantlyApi` uses on the cloud routes.
final httpSyncTransportProvider = Provider<HttpSyncTransport?>((ref) {
  final collectionId = ref.watch(syncCollectionIdProvider);
  if (collectionId == null || collectionId.isEmpty) return null;
  final auth = ref.watch(plantlyAuthProvider.notifier);
  return HttpSyncTransport(
    client: ref.watch(httpClientProvider),
    collectionId: collectionId,
    token: () async => (await auth.current())?.token,
    deviceMeta: ref.watch(syncDeviceMetaProvider),
  );
});

/// Device descriptor for the §2.12 push/pull headers; tests override.
final syncDeviceMetaProvider = Provider<SyncDeviceMeta?>((ref) {
  final ctx = ref.watch(appContextProvider).asData?.value;
  return currentDeviceMeta(deviceId: ctx?.deviceId ?? '');
});

/// The three faces of the transport the runner consumes, split so tests can
/// swap the op-log wire for a fake without touching HTTP. All default to
/// [httpSyncTransportProvider]; null = cloud off.
final syncTransportProvider = Provider<SyncTransport?>((ref) => ref.watch(httpSyncTransportProvider));
final photoTransportProvider = Provider<PhotoTransport?>((ref) => ref.watch(httpSyncTransportProvider));
final collectionUsageSourceProvider =
    Provider<CollectionUsageSource?>((ref) => ref.watch(httpSyncTransportProvider));

/// Lazy downloader for `remote_state='remote'` photos; null when cloud is
/// off. UI: `shared/remote_photo.dart` calls `ensureLocal(sha)` before
/// resolving the blob.
final photoFetcherProvider = Provider<PhotoFetcher?>((ref) {
  final collectionId = ref.watch(syncCollectionIdProvider);
  final transport = ref.watch(photoTransportProvider);
  final ctx = ref.watch(appContextProvider).asData?.value;
  if (collectionId == null || transport == null || ctx == null) return null;
  return PhotoFetcher(
    db: ctx.db,
    tenantId: collectionId,
    blobs: ref.watch(photoBlobStoreProvider),
    transport: transport,
  );
});

/// Rejection ledger for the current collection (null when cloud is off).
/// Shared between the runner (writes) and Me → Cloud → Details (reads,
/// retry/dismiss).
final syncRejectionStoreProvider = Provider<SyncRejectionStore?>((ref) {
  final collectionId = ref.watch(syncCollectionIdProvider);
  final ctx = ref.watch(appContextProvider).asData?.value;
  if (collectionId == null || ctx == null) return null;
  return SyncRejectionStore(db: ctx.db, tenantId: collectionId);
});

/// Live rows of the rejection ledger; empty when cloud is off.
final syncRejectionsProvider = StreamProvider<List<SyncRejectionRow>>((ref) {
  final store = ref.watch(syncRejectionStoreProvider);
  if (store == null) return Stream.value(const <SyncRejectionRow>[]);
  return store.watchAll();
});

/// The real runner for the current collection (started on creation,
/// disposed when the collection / app context changes or on container
/// dispose). Returns [NoopSyncRunner] until the app context, prefs and a
/// collection id are available — so it doubles as the "cloud off" runner
/// and `syncRunnerProvider` (`cloud/cloud_sync.dart`) can watch it
/// unconditionally.
///
/// A 402 halt (`cloud_required`) triggers one cache-bypassing entitlement
/// refresh so the Me section flips to "not included" instead of showing a
/// stale green light — except for `cloud_required_owner` on a shared
/// collection (the owner's plan, MULTI-USER-V2 §8), where only the list is
/// refetched for the "paused" marker. A 403 `not_a_member` / 410 / 404 halt on any
/// collection that is not the linked home hands over to
/// `CollectionsNotifier.removedByServer`; a 403 `read_only` halt refetches
/// the list so the role flip rebuilds this runner pull-only.
final httpSyncRunnerProvider = Provider<SyncRunner>((ref) {
  final collectionId = ref.watch(syncCollectionIdProvider);
  final transport = ref.watch(syncTransportProvider);
  final ctx = ref.watch(appContextProvider).asData?.value;
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  if (collectionId == null || transport == null || ctx == null || prefs == null) {
    return const NoopSyncRunner();
  }
  final config = ref.watch(syncRunnerConfigProvider);
  final photoTransport = ref.watch(photoTransportProvider);
  final auth = ref.read(plantlyAuthProvider.notifier);
  final shared = ref.watch(activeCollectionIsSharedProvider);
  // The linked default ("home") is the one collection a 410/404 never
  // removes locally — it is re-created by the link flow, not by the list.
  final homeId = ref.watch(cloudStateProvider.select((s) => s.collectionId));
  // Viewer (MULTI-USER-V2 §0) or a shared collection without our own plan
  // (§8, `caller_entitled == false`): pull only. Watched so a role change
  // (editor ↔ viewer) or a plan change rebuilds the runner.
  final readOnly = !ref.watch(canEditActiveCollectionProvider);
  // Watched: an account change rebuilds the runner so it only ever pushes
  // (and counts) the signed-in account's pending ops.
  final userId = ref.watch(currentUserIdProvider);
  final opLog = ctx.opLog.tenantId == collectionId
      ? ctx.opLog
      : OpLogWriter(
          db: ctx.db,
          clock: ctx.clock,
          tenantId: collectionId,
          currentUserId: () => ref.read(plantlyAuthProvider).valueOrNull?.userId,
        );
  final runner = HttpSyncRunner(
    db: ctx.db,
    opLog: opLog,
    transport: transport,
    cursor: PrefsSyncCursor(prefs: prefs, tenantId: collectionId),
    deviceId: ctx.deviceId,
    collectionId: collectionId,
    userId: userId,
    localChanges: ctx.opLog.changes,
    rejections: ref.watch(syncRejectionStoreProvider),
    photos: photoTransport == null
        ? null
        : PhotoUploader(
            db: ctx.db,
            tenantId: collectionId,
            blobs: ref.watch(photoBlobStoreProvider),
            transport: photoTransport,
            deviceId: ctx.deviceId,
          ),
    usage: ref.watch(collectionUsageSourceProvider),
    refreshAuth: () async => (await auth.current()) != null,
    debounce: config.debounce,
    periodic: config.periodic,
    minBackoff: config.minBackoff,
    maxBackoff: config.maxBackoff,
    usageInterval: config.usageInterval,
    entitlementIsOwners: shared,
    readOnly: readOnly,
  );

  var refreshedForHalt = false;
  var removalHandled = false;
  var roleRefreshed = false;
  final sub = runner.status.listen((s) {
    // 403 `not_a_member` / 410 `collection_deleted` / 404
    // `collection_not_found` (deleted, and we were already removed) on any
    // collection but the linked home — shared, or an owned non-default the
    // account deleted elsewhere: drop it, go home, tell the user (once per
    // runner — the tenant flip rebuilds this provider anyway).
    if (collectionId != homeId &&
        !removalHandled &&
        s.lastError == 'collection_unavailable' &&
        (s.lastErrorDetail == kNotAMemberDetail ||
            s.lastErrorDetail == kCollectionDeletedDetail ||
            s.lastErrorDetail == kCollectionNotFoundDetail)) {
      removalHandled = true;
      unawaited(ref.read(collectionsProvider.notifier).removedByServer(collectionId));
    }
    // 403 `device_revoked` (§2.12): this install was revoked from another
    // device. Any collection, own or shared: sign the cloud session out.
    if (!removalHandled && s.lastError == 'collection_unavailable' && s.lastErrorDetail == kDeviceRevokedDetail) {
      removalHandled = true;
      unawaited(ref.read(collectionsProvider.notifier).deviceRevoked());
    }
    // 403 `read_only` (§2.10): our role was downgraded under a push. The
    // list refetch flips `canEdit`, which rebuilds this runner read-only
    // and raises the banner; until then the halt shows in Me → Cloud.
    if (!roleRefreshed && s.lastError == 'collection_unavailable' && s.lastErrorDetail == kReadOnlyDetail) {
      roleRefreshed = true;
      unawaited(ref.read(collectionsProvider.notifier).refresh());
    }
    if (s.lastError != 'cloud_required') {
      refreshedForHalt = false;
      return;
    }
    if (refreshedForHalt) return;
    refreshedForHalt = true;
    if (shared) {
      // §8: the list carries the verdicts (`caller_entitled`,
      // `owner_entitled`) that flip the switcher markers and — for our own
      // lapse — rebuild this runner read-only.
      unawaited(ref.read(collectionsProvider.notifier).refresh());
      // The OWNER's plan is not ours to re-check.
      if (s.lastErrorDetail == kOwnerPlanLapsedDetail) return;
    }
    unawaited(ref.read(cloudEntitlementProvider.notifier).refresh().catchError((_) {}));
  });
  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(runner.dispose());
  });
  runner.start();
  return runner;
});
