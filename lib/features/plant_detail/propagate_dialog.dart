import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';

/// Propagate dialog — asks for a child nickname + optional notes, writes
/// a propagation transaction, returns the newly-created PlantRow so
/// PlantDetail can navigate to it.
class PropagateDialog extends ConsumerStatefulWidget {
  const PropagateDialog({super.key, required this.parentId, required this.parentName});
  final String parentId;
  final String parentName;

  @override
  ConsumerState<PropagateDialog> createState() => _PropagateDialogState();

  static Future<PlantRow?> show(BuildContext context,
      {required String parentId, required String parentName}) {
    return showDialog<PlantRow>(
      context: context,
      builder: (_) => PropagateDialog(parentId: parentId, parentName: parentName),
    );
  }
}

class _PropagateDialogState extends ConsumerState<PropagateDialog> {
  late final TextEditingController _nickname;
  final _notes = TextEditingController();
  bool _saving = false;
  bool _nicknameReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The localized default needs an inherited lookup, which initState
    // can't do; seed the controller once the first time we have context.
    if (!_nicknameReady) {
      _nickname = TextEditingController(
        text: AppLocalizations.of(context).sheetPropagateDefaultName(widget.parentName),
      );
      _nicknameReady = true;
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.sheetPropagateTitle(widget.parentName)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nickname,
            autofocus: true,
            decoration: InputDecoration(labelText: t.sheetChildNickname),
            maxLength: 64,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: t.sheetNotesOptionalHint,
              hintText: t.sheetPropagateNotesHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? t.saving : t.sheetPropagateAction),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final name = _nickname.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    try {
      final result = await ref.read(inventoryTransactionRepositoryProvider).propagate(
            parentId: widget.parentId,
            childNickname: name,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
      nav.pop(result.child);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
