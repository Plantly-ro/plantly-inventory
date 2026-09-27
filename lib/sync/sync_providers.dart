import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/sync_runner.dart';
import '../config/plantly_hosts.dart';
import '../data/photo_blob_store.dart';
import '../data/providers.dart';
import '../marketplace/plantly_auth.dart';
import 'http_sync_runner.dart';
import 'http_sync_transport.dart';
import 'op_log.dart';
import 'photo_sync.dart';
import 'sync_engine.dart';

/// Server collection id to sync against; null = cloud off. The account layer
/// overrides this (or rebinds it to its `currentTenantIdProvider` once the
/// local tenant has been migrated to the collection id).
final syncCollectionIdProvider = Provider<String?>((_) => null);

/// Version reported in `X-Plantly-Client: inventory/<version>`. Defaults to
/// the build-time `PLANTLY_APP_VERSION` define (same source as the UA);
/// override with `package_info_plus` at integration if preferred.
final syncClientVersionProvider = Provider<String>((_) => PlantlyHosts.appVersion);

/// Transport bound to the current collection, or null when cloud is off.
final httpSyncTransportProvider = Provider<HttpSyncTransport?>((ref) {
  final collectionId = ref.watch(syncCollectionIdProvider);
  if (collectionId == null || collectionId.isEmpty) return null;
  final auth = ref.watch(plantlyAuthProvider.notifier);
  return HttpSyncTransport(
    client: ref.watch(httpClientProvider),
    collectionId: collectionId,
    token: () async => (await auth.current())?.token,
    clientVersion: ref.watch(syncClientVersionProvider),
  );
});

/// Lazy downloader for `remote_state='remote'` photos; null when cloud is
/// off. UI: `ref.read(photoFetcherProvider)?.ensureLocal(sha)` before
/// resolving the blob.
final photoFetcherProvider = Provider<PhotoFetcher?>((ref) {
  final transport = ref.watch(httpSyncTransportProvider);
  final ctx = ref.watch(appContextProvider).asData?.value;
  if (transport == null || ctx == null) return null;
  return PhotoFetcher(
    db: ctx.db,
    tenantId: transport.collectionId,
    blobs: ref.watch(photoBlobStoreProvider),
    transport: transport,
  );
});

/// The real runner for the current collection (started on first read,
/// disposed with the provider). Returns [NoopSyncRunner] until the app
/// context, prefs and a collection id are available. The account layer
/// points `syncRunnerProvider` at this once its cloud phase is `ready`.
final httpSyncRunnerProvider = Provider<SyncRunner>((ref) {
  final transport = ref.watch(httpSyncTransportProvider);
  final ctx = ref.watch(appContextProvider).asData?.value;
  final prefs = ref.watch(sharedPreferencesProvider).asData?.value;
  if (transport == null || ctx == null || prefs == null) return const NoopSyncRunner();
  final collectionId = transport.collectionId;
  final auth = ref.read(plantlyAuthProvider.notifier);
  final opLog = ctx.opLog.tenantId == collectionId
      ? ctx.opLog
      : OpLogWriter(db: ctx.db, clock: ctx.clock, tenantId: collectionId);
  final runner = HttpSyncRunner(
    db: ctx.db,
    opLog: opLog,
    clock: ctx.clock,
    transport: transport,
    cursor: PrefsSyncCursor(prefs: prefs, tenantId: collectionId),
    deviceId: ctx.deviceId,
    collectionId: collectionId,
    localChanges: ctx.opLog.changes,
    photos: PhotoUploader(
      db: ctx.db,
      tenantId: collectionId,
      blobs: ref.watch(photoBlobStoreProvider),
      transport: transport,
    ),
    usage: transport,
    refreshAuth: () async => (await auth.current()) != null,
  );
  ref.onDispose(runner.dispose);
  runner.start();
  return runner;
});
