import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/navigation.dart';
import '../../cloud/cloud_sync.dart';
import '../../data/database/app_database.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../sync/sync_providers.dart';
import '../../sync/sync_rejections.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'me_rows.dart';

/// Me → Cloud → Details: the ops the server refused (`sync_rejections`),
/// newest first, with "Retry all" (re-queue + sync) and "Dismiss all".
class SyncRejectionsScreen extends ConsumerWidget {
  const SyncRejectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final rows = ref.watch(syncRejectionsProvider).valueOrNull ?? const <SyncRejectionRow>[];
    final store = ref.watch(syncRejectionStoreProvider);
    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: adaptiveBackButton(context, surface, fallback: AppRoutes.meSection('cloud')),
        title: Text(
          t.cloudRejScreenTitle,
          style: TextStyle(
            fontFamily: PlantlyFonts.plusJakartaSans,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      body: ListView(
        key: const Key('cloud-rejections-list'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            t.cloudRejScreenIntro,
            style: TextStyle(fontSize: 13, height: 1.4, color: surface.muted),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(t.cloudRejEmpty, key: const Key('cloud-rejections-empty'), style: TextStyle(fontSize: 13, color: surface.muted))
          else ...[
            MeActionRow(
              key: const Key('cloud-rejections-retry'),
              label: t.cloudRejRetry,
              value: t.cloudRejRetryValue,
              icon: Icons.replay,
              surface: surface,
              onTap: store == null ? null : () => _retryAll(context, ref, store),
            ),
            const SizedBox(height: 6),
            MeActionRow(
              key: const Key('cloud-rejections-dismiss'),
              label: t.cloudRejDismiss,
              value: t.cloudRejDismissValue,
              icon: Icons.delete_sweep_outlined,
              surface: surface,
              onTap: store == null ? null : () => _dismissAll(ref, store),
            ),
            const SizedBox(height: 16),
            for (final r in rows) ...[
              _RejectionTile(row: r, surface: surface),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _retryAll(BuildContext context, WidgetRef ref, SyncRejectionStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final t = AppLocalizations.of(context);
    final runner = ref.read(syncRunnerProvider);
    final n = await store.retryAll();
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t.cloudRejRequeued(n))));
    await runner.syncNow();
  }

  Future<void> _dismissAll(WidgetRef ref, SyncRejectionStore store) async {
    final runner = ref.read(syncRunnerProvider);
    await store.clear();
    // The status only re-evaluates at the end of a cycle; a pull-only cycle
    // is cheap and clears the sticky `rejected` right away.
    await runner.syncNow();
  }
}

class _RejectionTile extends StatelessWidget {
  const _RejectionTile({required this.row, required this.surface});
  final SyncRejectionRow row;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final when = DateFormat.yMMMd(t.localeName).add_Hm().format(DateTime.fromMillisecondsSinceEpoch(row.at, isUtc: true).toLocal());
    final kind = row.parked ? t.cloudRejKindParked : t.cloudRejKindRetrying;
    return Container(
      key: Key('cloud-rejection-${row.opSeq}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${row.entity} · ${row.field}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
          ),
          const SizedBox(height: 2),
          Text(
            '${row.reason} · $kind · $when',
            style: TextStyle(fontSize: 12, color: surface.terra),
          ),
          Text(
            row.entityId,
            style: TextStyle(fontSize: 11, color: surface.muted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
