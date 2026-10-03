import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import 'collections.dart';

/// One-shot cloud notices that no screen owns, surfaced as SnackBars from
/// the app root (mounted in `main.dart`'s `builder:` chain, i.e. under the
/// root `ScaffoldMessenger`). Today: "You were removed from `<collection>`"
/// ([collectionRemovedNoticeProvider], raised when a shared collection
/// answers 403 `not_a_member`). Each notice is reset to null once shown.
class CloudNotices extends ConsumerStatefulWidget {
  const CloudNotices({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CloudNotices> createState() => _CloudNoticesState();
}

class _CloudNoticesState extends ConsumerState<CloudNotices> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(collectionRemovedNoticeProvider, (_, name) {
      if (name == null || !mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(key: const Key('cloud-notice-removed'), content: Text(t.shareRemovedFromCollection(name))));
      ref.read(collectionRemovedNoticeProvider.notifier).state = null;
    });
    ref.listenManual<bool>(deviceRevokedNoticeProvider, (_, revoked) {
      if (!revoked || !mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(key: const Key('cloud-notice-device-revoked'), content: Text(t.shareErrDeviceRevoked)));
      ref.read(deviceRevokedNoticeProvider.notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
