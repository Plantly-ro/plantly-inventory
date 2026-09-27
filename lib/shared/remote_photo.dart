import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repositories/photo_repository.dart';
import '../sync/photo_sync.dart';
import '../sync/sync_providers.dart';

/// Resolves a photo by sha for display. Rows that arrived through cloud
/// sync (`photos.remote_state == 'remote'`, CLOUD-SYNC-CONTRACT §2.4) have
/// no bytes on this device yet: the blob is downloaded lazily on first
/// display via `PhotoFetcher.ensureLocal` (single-flight per sha), showing
/// [placeholder] meanwhile. Local rows resolve straight from the store.
///
/// [placeholder] is also what renders when the row or blob is missing, when
/// cloud is off for a remote row, or when the download fails — the next
/// build retries. Galleries keep their own layout; this only supplies the
/// [ImageProvider] to [builder].
class RemotePhoto extends ConsumerStatefulWidget {
  const RemotePhoto({
    super.key,
    required this.sha,
    required this.placeholder,
    required this.builder,
  });

  final String sha;
  final Widget placeholder;
  final Widget Function(BuildContext context, ImageProvider image) builder;

  @override
  ConsumerState<RemotePhoto> createState() => _RemotePhotoState();
}

class _RemotePhotoState extends ConsumerState<RemotePhoto> {
  Future<ImageProvider?>? _future;
  String? _sha;
  PhotoRepository? _repo;
  PhotoFetcher? _fetcher;

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(photoRepositoryProvider);
    final fetcher = ref.watch(photoFetcherProvider);
    // One resolution per (sha, repo, fetcher); a null outcome is not cached
    // so a failed download or a blob that shows up later is retried on the
    // next build (same behaviour the plain store lookup always had).
    if (_future == null || _sha != widget.sha || !identical(_repo, repo) || !identical(_fetcher, fetcher)) {
      _sha = widget.sha;
      _repo = repo;
      _fetcher = fetcher;
      final future = resolvePhotoImage(repo: repo, fetcher: fetcher, sha: widget.sha);
      _future = future;
      future.then((image) {
        if (image == null && identical(_future, future)) _future = null;
      });
    }
    return FutureBuilder<ImageProvider?>(
      future: _future,
      builder: (context, snap) {
        final image = snap.data;
        if (image == null) return widget.placeholder;
        return widget.builder(context, image);
      },
    );
  }
}

/// The resolution step behind [RemotePhoto]: missing row → null; a `remote`
/// row is downloaded first ([fetcher] null = cloud off → null, transport
/// failure → null); everything else is the store lookup.
Future<ImageProvider?> resolvePhotoImage({
  required PhotoRepository repo,
  required PhotoFetcher? fetcher,
  required String sha,
}) async {
  final row = await repo.byHash(sha);
  if (row == null) return null;
  if (row.remoteState == 'remote') {
    if (fetcher == null) return null;
    try {
      if (!await fetcher.ensureLocal(sha)) return null;
    } catch (_) {
      return null;
    }
  }
  return repo.imageFor(sha);
}
