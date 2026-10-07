import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../data/database/cross_tab_lock.dart' show crossTabDbBusy;
import '../features/me/cloud_section.dart' show describeHomeLoss;
import 'collections.dart';

/// One-shot cloud notices that no screen owns, surfaced as SnackBars from
/// the app root (mounted in `main.dart`'s `builder:` chain, i.e. under the
/// root `ScaffoldMessenger`). Today: "You were removed from `<collection>`"
/// ([collectionRemovedNoticeProvider], raised when a shared collection
/// answers 403 `not_a_member`) and "your collection is no longer available"
/// ([homeLostNoticeProvider]). Each notice is reset to null once shown.
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
    crossTabDbBusy.addListener(_onDbBusy);
    ref.listenManual<String?>(collectionRemovedNoticeProvider, (_, name) {
      if (name == null || !mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(key: const Key('cloud-notice-removed'), content: Text(t.shareRemovedFromCollection(name))));
      ref.read(collectionRemovedNoticeProvider.notifier).state = null;
    });
    ref.listenManual<HomeLoss?>(homeLostNoticeProvider, (_, loss) {
      if (loss == null || !mounted) return;
      final t = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(
          key: const Key('cloud-notice-home-lost'),
          duration: const Duration(seconds: 8),
          content: Text(describeHomeLoss(t, loss)),
        ));
      ref.read(homeLostNoticeProvider.notifier).state = null;
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

  /// Web: another tab held the database past the lock timeout. Shown once
  /// per episode, never blocking — the statement retries on its own.
  void _onDbBusy() {
    if (!crossTabDbBusy.value || !mounted) return;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(key: const Key('db-busy-other-tab'), content: Text(t.dbBusyOtherTab)),
    );
  }

  @override
  void dispose() {
    crossTabDbBusy.removeListener(_onDbBusy);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
