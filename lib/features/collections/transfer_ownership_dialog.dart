import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/collections.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../theme/tokens.dart';
import 'collection_ui.dart';

/// "Transfer `<name>` to `<username>`?" (MULTI-USER-V2 §2.8): explains that the
/// target becomes owner, THEIR plan + quota apply from now on and the
/// caller stays as editor. Runs `POST …/transfer` itself so a `402
/// cloud_required_new_owner` (or any other failure) shows inline and the
/// dialog stays open. Resolves `true` after a successful transfer.
Future<bool> showTransferOwnershipDialog(
  BuildContext context, {
  required CloudCollection collection,
  required CollectionMember target,
  required PlantlySurface surface,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => TransferOwnershipDialog(collection: collection, target: target, surface: surface),
  );
  return ok == true;
}

class TransferOwnershipDialog extends ConsumerStatefulWidget {
  const TransferOwnershipDialog({super.key, required this.collection, required this.target, required this.surface});
  final CloudCollection collection;
  final CollectionMember target;
  final PlantlySurface surface;

  @override
  ConsumerState<TransferOwnershipDialog> createState() => _TransferOwnershipDialogState();
}

class _TransferOwnershipDialogState extends ConsumerState<TransferOwnershipDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _transfer() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(collectionsProvider.notifier).transferOwnership(widget.collection.id, widget.target.userId);
      if (nav.mounted) nav.pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeShareError(t, e, action: ShareAction.transfer);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final surface = widget.surface;
    return AlertDialog(
      title: Text(t.shareTransferTitle(widget.collection.displayName, widget.target.username)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.shareTransferBody(widget.target.username)),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, key: const Key('transfer-error'), style: TextStyle(fontSize: 12.5, color: surface.terra)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text(t.cancel)),
        FilledButton(
          key: const Key('transfer-confirm'),
          onPressed: _busy ? null : _transfer,
          child: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(t.shareTransferConfirm),
        ),
      ],
    );
  }
}
