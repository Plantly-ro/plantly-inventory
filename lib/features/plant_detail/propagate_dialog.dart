import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';

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

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: '${widget.parentName} · propagation');
  }

  @override
  void dispose() {
    _nickname.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Propagate ${widget.parentName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nickname,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Child nickname'),
            maxLength: 64,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. cut from node 3; rooting in water',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: Text(_saving ? 'Saving…' : 'Propagate'),
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
