import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../marketplace/plantly_api.dart';
import 'collection_link.dart';

/// The account-switch decision (CLOUD-SYNC-CONTRACT §2.4 "Linking"): this
/// device still holds plants that belong to another plantly.ro account —
/// a link that account made, or the data-owner marker it left behind. The
/// signed-in user chooses between "Move this device's plants to `<me>`"
/// (`CollectionLinkService.link`, after a confirm) and "Start empty for
/// `<me>`" (`CollectionLinkService.startEmpty`). Nothing happens
/// automatically; Cancel keeps everything as is.
///
/// Two surfaces present it with the same copy and keys:
///   * Me → Cloud rows (`CloudRows._heldByOther`, inline rows);
///   * the join sheet ([resolveHeldByOther], a dialog) — a join link is
///     the one path where a user without a plan of their own can end up
///     here (a shared collection runs on the owner's plan), and the join
///     must not land on a device whose link belongs to somebody else.

/// The "Move plants to your cloud?" confirmation; true = confirmed.
Future<bool> confirmMoveToMe(BuildContext context, {required String other, required String me}) async {
  final t = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.cloudMoveConfirmTitle),
      content: Text(t.cloudMoveConfirmBody(other, me)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
        FilledButton(
          key: const Key('cloud-move-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(t.cloudMove),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Copy for a failed link / start-empty (network, API, anything else).
String describeLinkError(AppLocalizations t, Object e) {
  if (e is PlantlyNetworkException) return t.plantlyErrorNetwork;
  if (e is PlantlyApiException) return e.isRateLimited ? t.plantlyErrorRateLimited : e.message;
  return '$e';
}

/// Ask the data-owner question as a dialog (key `join-held-by-other`) and
/// carry the chosen action out. Resolves true only once a choice completed
/// successfully — the device is then linked for [me]; false when the user
/// cancelled (nothing changed). Errors stay inside the dialog with the
/// choices still available.
Future<bool> resolveHeldByOther(
  BuildContext context,
  WidgetRef ref, {
  required String other,
  required String me,
}) async {
  final links = ref.read(collectionLinkProvider.notifier); // before the await (#14)
  final decided = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _HeldByOtherDialog(other: other, me: me, links: links),
  );
  return decided == true;
}

class _HeldByOtherDialog extends StatefulWidget {
  const _HeldByOtherDialog({required this.other, required this.me, required this.links});
  final String other;
  final String me;
  final CollectionLinkService links;

  @override
  State<_HeldByOtherDialog> createState() => _HeldByOtherDialogState();
}

class _HeldByOtherDialogState extends State<_HeldByOtherDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeLinkError(AppLocalizations.of(context), e);
        });
      }
    }
  }

  Future<void> _moveToMe() async {
    final ok = await confirmMoveToMe(context, other: widget.other, me: widget.me);
    if (!ok || !mounted) return; // cancel = stay as is (sticky)
    await _run(() => widget.links.link());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      key: const Key('join-held-by-other'),
      title: Text(t.cloudHeldByOther(widget.other)),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const Key('cloud-move-to-me'),
            enabled: !_busy,
            leading: const Icon(Icons.drive_file_move_outline),
            title: Text(t.cloudMoveToMeLabel(widget.me)),
            subtitle: Text(t.cloudMoveToMeValue(widget.other)),
            onTap: _busy ? null : _moveToMe,
          ),
          ListTile(
            key: const Key('cloud-start-empty'),
            enabled: !_busy,
            leading: const Icon(Icons.fiber_new_outlined),
            title: Text(t.cloudStartEmptyLabel(widget.me)),
            subtitle: Text(t.cloudStartEmptyValue(widget.other)),
            onTap: _busy ? null : () => _run(() => widget.links.startEmpty()),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                _error!,
                key: const Key('join-held-by-other-error'),
                style: TextStyle(fontSize: 12.5, color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('join-held-by-other-cancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: Text(t.cancel),
        ),
      ],
    );
  }
}
