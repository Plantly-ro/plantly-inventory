import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';

/// Tag chip row on Plant Detail. Shows the currently-attached tags as
/// removable green chips, and an "+ Add tag" action that opens a dialog
/// with autocomplete against `allTagsProvider`. New tags are created on
/// the fly via `TagRepository.ensure`, so the user never needs to visit
/// a separate "manage tags" screen.
class TagChipInput extends ConsumerWidget {
  const TagChipInput({super.key, required this.plantId, required this.surface});
  final String plantId;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachedAsync = ref.watch(tagsForPlantProvider(plantId));
    final allTagsAsync = ref.watch(allTagsProvider);
    final allTags = allTagsAsync.maybeWhen(data: (rows) => rows, orElse: () => const []);
    final byId = {for (final t in allTags) t.id: t.name};

    final attached = attachedAsync.maybeWhen(data: (ids) => ids, orElse: () => const <String>[]);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tagId in attached)
          _Chip(
            label: byId[tagId] ?? '…',
            surface: surface,
            onRemove: () => ref.read(plantTagRepositoryProvider).detach(plantId, tagId),
          ),
        _AddChip(
          surface: surface,
          onTap: () => _openDialog(context, ref, attached),
        ),
      ],
    );
  }

  Future<void> _openDialog(BuildContext context, WidgetRef ref, List<String> attached) async {
    final t = AppLocalizations.of(context);
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Consumer(builder: (ctx, dialogRef, _) {
              final allTags = dialogRef.watch(allTagsProvider).maybeWhen(
                    data: (rows) => rows,
                    orElse: () => const [],
                  );
              final attachedIds = attached.toSet();
              final query = controller.text.trim().toLowerCase();
              final suggestions = allTags
                  .where((t) => !attachedIds.contains(t.id))
                  .where((t) => query.isEmpty || t.name.contains(query))
                  .toList();
              return AlertDialog(
                title: Text(t.tagAdd),
                content: SizedBox(
                  width: 320,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.none,
                        decoration: InputDecoration(
                          hintText: t.tagHint,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setLocal(() {}),
                        onSubmitted: (_) => _commit(ctx, dialogRef, controller.text),
                      ),
                      const SizedBox(height: 10),
                      if (suggestions.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(t.tagPickExisting,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: SingleChildScrollView(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final tag in suggestions)
                                  ActionChip(
                                    label: Text('#${tag.name}'),
                                    onPressed: () async {
                                      final navigator = Navigator.of(ctx);
                                      await dialogRef.read(plantTagRepositoryProvider).attach(plantId, tag.id);
                                      navigator.maybePop();
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).maybePop(), child: Text(t.cancel)),
                  FilledButton(
                    onPressed: controller.text.trim().isEmpty
                        ? null
                        : () => _commit(ctx, dialogRef, controller.text),
                    child: Text(t.addBtn),
                  ),
                ],
              );
            });
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _commit(BuildContext ctx, WidgetRef ref, String raw) async {
    final name = raw.trim();
    if (name.isEmpty) return;
    final navigator = Navigator.of(ctx);
    final tags = ref.read(tagRepositoryProvider);
    final joins = ref.read(plantTagRepositoryProvider);
    final tag = await tags.ensure(name);
    await joins.attach(plantId, tag.id);
    navigator.maybePop();
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.surface, required this.onRemove});
  final String label;
  final PlantlySurface surface;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.greenSoft,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#$label',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surface.green),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Icon(Icons.close, size: 12, color: surface.green),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  const _AddChip({required this.surface, required this.onTap});
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: surface.border, style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 12, color: surface.muted),
              const SizedBox(width: 3),
              Text(
                t.tagAddTitle,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surface.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
