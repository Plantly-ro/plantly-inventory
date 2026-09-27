import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_state.dart';
import '../cloud/entitlement.dart';
import '../cloud/sync_runner.dart';
import '../data/database/app_database.dart';
import '../data/photo_blob_store.dart';
import '../data/providers.dart';
import '../marketplace/plantly_auth.dart';
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
/// a tenant id while unlinked.
final syncCollectionIdProvider = Provider<String?>((ref) {
  return ref.watch(cloudStateProvider.select((s) => s.canSync ? s.collectionId : null));
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
  );
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
/// stale green light.
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
  final opLog = ctx.opLog.tenantId == collectionId
      ? ctx.opLog
      : OpLogWriter(db: ctx.db, clock: ctx.clock, tenantId: collectionId);
  final runner = HttpSyncRunner(
    db: ctx.db,
    opLog: opLog,
    transport: transport,
    cursor: PrefsSyncCursor(prefs: prefs, tenantId: collectionId),
    deviceId: ctx.deviceId,
    collectionId: collectionId,
    localChanges: ctx.opLog.changes,
    rejections: ref.watch(syncRejectionStoreProvider),
    photos: photoTransport == null
        ? null
        : PhotoUploader(
            db: ctx.db,
            tenantId: collectionId,
            blobs: ref.watch(photoBlobStoreProvider),
            transport: photoTransport,
          ),
    usage: ref.watch(collectionUsageSourceProvider),
    refreshAuth: () async => (await auth.current()) != null,
    debounce: config.debounce,
    periodic: config.periodic,
    minBackoff: config.minBackoff,
    maxBackoff: config.maxBackoff,
    usageInterval: config.usageInterval,
  );

  var refreshedForHalt = false;
  final sub = runner.status.listen((s) {
    if (s.lastError != 'cloud_required') {
      refreshedForHalt = false;
      return;
    }
    if (refreshedForHalt) return;
    refreshedForHalt = true;
    unawaited(ref.read(cloudEntitlementProvider.notifier).refresh().catchError((_) {}));
  });
  ref.onDispose(() {
    unawaited(sub.cancel());
    unawaited(runner.dispose());
  });
  runner.start();
  return runner;
});
