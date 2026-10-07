import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

enum BackupPassphrasePurpose { export, import }

/// Asks for the backup passphrase. Returns null on Cancel.
///
/// The passphrase only signs the backup (HMAC-SHA256, see `BackupService`):
/// it detects tampering, the contents stay plaintext. The copy must never
/// suggest encryption.
Future<String?> showBackupPassphraseDialog(BuildContext context, {required BackupPassphrasePurpose purpose}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _BackupPassphraseDialog(purpose: purpose),
  );
}

/// Owns its [TextEditingController] so it is disposed with the route, not
/// the moment `showDialog` returns — the dialog is still animating out then
/// and its TextField would rebuild against a disposed controller.
class _BackupPassphraseDialog extends StatefulWidget {
  const _BackupPassphraseDialog({required this.purpose});
  final BackupPassphrasePurpose purpose;

  @override
  State<_BackupPassphraseDialog> createState() => _BackupPassphraseDialogState();
}

class _BackupPassphraseDialogState extends State<_BackupPassphraseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final export = widget.purpose == BackupPassphrasePurpose.export;
    final field = TextField(
      controller: _controller,
      autofocus: true,
      obscureText: true,
      decoration: InputDecoration(
        hintText: export ? t.meBackupPassphraseExportHint : t.meBackupPassphraseImportHint,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    );
    return AlertDialog(
      title: Text(t.meBackupPassphrase),
      content: export
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.meBackupPassphraseExportNote, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                field,
              ],
            )
          : field,
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(null), child: Text(t.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(t.commonOk)),
      ],
    );
  }
}
