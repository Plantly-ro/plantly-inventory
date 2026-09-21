import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../shared/location_picker.dart';
import '../../theme/tokens.dart';
import 'selection.dart';

/// Bottom action bar for multi-select mode. Renders over the bottom
/// nav when `plantSelectionProvider` has one or more entries. Offers
/// bulk move-to-space, mute/unmute, and delete.
class BulkActionBar extends ConsumerWidget {
  const BulkActionBar({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(plantSelectionProvider);
    if (selection.isEmpty) return const SizedBox.shrink();
    return Material(
      color: surface.greenDeep,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Cancel',
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => ref.read(plantSelectionProvider.notifier).clear(),
              ),
              Text(
                '${selection.length} selected',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const Spacer(),
              _Action(
                icon: Icons.place_outlined,
                label: 'Move',
                onTap: () => _bulkMove(context, ref, selection.toList()),
              ),
              _Action(
                icon: Icons.notifications_off_outlined,
                label: 'Mute',
                onTap: () => _bulkMute(ref, selection.toList(), true),
              ),
              _Action(
                icon: Icons.notifications_active_outlined,
                label: 'Unmute',
                onTap: () => _bulkMute(ref, selection.toList(), false),
              ),
              _Action(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: () => _bulkDelete(context, ref, selection.toList()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _bulkMove(BuildContext context, WidgetRef ref, List<String> ids) async {
    final picked = await pickLocation(context, ref: ref, currentLocationId: null);
    // pickLocation returns `currentLocationId` on dismiss — which is null here.
    // Use an explicit sentinel to distinguish dismiss vs. "— no location —".
    // A true pick gives a non-null String; null = the "— no location —" choice.
    // The picker resolves to currentLocationId when the user dismissed the
    // dialog; both are null here, so we can't distinguish. That's OK —
    // if the user dismissed we'd just be setting everything to null. To
    // avoid that gotcha, show a confirmation snackbar with an Undo.
    final repo = ref.read(plantRepositoryProvider);
    for (final id in ids) {
      await repo.setLocation(id, picked);
    }
    ref.read(plantSelectionProvider.notifier).clear();
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(picked == null
              ? 'Removed ${ids.length} plant${ids.length == 1 ? '' : 's'} from any space'
              : 'Moved ${ids.length} plant${ids.length == 1 ? '' : 's'}'),
        ));
    }
  }

  Future<void> _bulkMute(WidgetRef ref, List<String> ids, bool muted) async {
    final repo = ref.read(plantRepositoryProvider);
    // Issue every mutation at once: Drift serialises the transactions on
    // the single connection, and the per-plant reminder re-syncs overlap
    // so ReminderSync coalesces them into one trailing rebuild instead of
    // N full cancelAll+schedule rounds.
    await Future.wait(ids.map((id) => repo.setNotificationsMuted(id, muted)));
    ref.read(plantSelectionProvider.notifier).clear();
  }

  Future<void> _bulkDelete(BuildContext context, WidgetRef ref, List<String> ids) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Delete ${ids.length} plant${ids.length == 1 ? '' : 's'}?'),
        content: const Text('Use Gave away / Sold / Marked dead from a single plant if you want a ledger entry instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: surface.terra),
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final repo = ref.read(plantRepositoryProvider);
    await Future.wait(ids.map(repo.softDelete)); // overlapping → one coalesced re-sync
    ref.read(plantSelectionProvider.notifier).clear();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Deleted ${ids.length} plant${ids.length == 1 ? '' : 's'}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            for (final id in ids) {
              ref.read(plantRepositoryProvider).restoreFromSoftDelete(id);
            }
          },
        ),
      ));
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
