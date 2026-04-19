import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/care_types.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../plant_detail/plant_detail_screen.dart';
import '../locations/location_detail_screen.dart';

/// Streams every row that has `notifications_muted = true` across
/// plants, schedules, and locations. Same provider scope
/// (appContextProvider) so it's cheap to tail alongside the rest.
final _mutedPlantsProvider = StreamProvider<List<PlantRow>>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return (ctx.db.select(ctx.db.plants)
        ..where((p) =>
            p.tenantId.equals(ctx.opLog.tenantId) &
            p.deletedAt.isNull() &
            p.notificationsMuted.equals(true))
        ..orderBy([(p) => drift.OrderingTerm(expression: p.nickname)]))
      .watch();
});

final _mutedSchedulesProvider = StreamProvider<List<CareScheduleRow>>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return (ctx.db.select(ctx.db.careSchedules)
        ..where((s) =>
            s.tenantId.equals(ctx.opLog.tenantId) &
            s.deletedAt.isNull() &
            s.notificationsMuted.equals(true)))
      .watch();
});

final _mutedLocationsProvider = StreamProvider<List<LocationRow>>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return (ctx.db.select(ctx.db.locations)
        ..where((l) =>
            l.tenantId.equals(ctx.opLog.tenantId) &
            l.deletedAt.isNull() &
            l.notificationsMuted.equals(true))
        ..orderBy([(l) => drift.OrderingTerm(expression: l.name)]))
      .watch();
});

/// "Me → Notifications" — surfaces everything that's been silenced so
/// users remember what they muted and can unmute in one place.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final granted = ref.watch(notificationPermissionProvider);
    final plants = ref.watch(_mutedPlantsProvider).maybeWhen(data: (r) => r, orElse: () => const <PlantRow>[]);
    final schedules = ref.watch(_mutedSchedulesProvider).maybeWhen(data: (r) => r, orElse: () => const <CareScheduleRow>[]);
    final locations = ref.watch(_mutedLocationsProvider).maybeWhen(data: (r) => r, orElse: () => const <LocationRow>[]);
    final plantsById = ref.watch(plantsStreamProvider).maybeWhen(
          data: (rows) => {for (final p in rows) p.id: p},
          orElse: () => const <String, PlantRow>{},
        );
    final types = ref.watch(careTypesProvider);

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          _PermissionCard(surface: surface, granted: granted),
          const SizedBox(height: 20),
          if (plants.isEmpty && schedules.isEmpty && locations.isEmpty)
            _EmptyState(surface: surface)
          else ...[
            if (plants.isNotEmpty) ...[
              _SectionLabel(text: 'MUTED PLANTS (${plants.length})', surface: surface),
              const SizedBox(height: 8),
              for (final p in plants)
                _MutedRow(
                  title: p.nickname,
                  subtitle: 'Every reminder for this plant is silenced.',
                  icon: Icons.eco_outlined,
                  surface: surface,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: p.id)),
                    );
                  },
                  onUnmute: () =>
                      ref.read(plantRepositoryProvider).setNotificationsMuted(p.id, false),
                ),
              const SizedBox(height: 20),
            ],
            if (schedules.isNotEmpty) ...[
              _SectionLabel(text: 'MUTED REMINDERS (${schedules.length})', surface: surface),
              const SizedBox(height: 8),
              for (final s in schedules)
                _MutedRow(
                  title: '${resolveCareType(types, s.type).label} · ${plantsById[s.plantId]?.nickname ?? s.plantId}',
                  subtitle: 'Single schedule muted — other reminders for this plant still fire.',
                  icon: resolveCareType(types, s.type).icon,
                  surface: surface,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: s.plantId)),
                    );
                  },
                  onUnmute: () => ref
                      .read(careScheduleRepositoryProvider)
                      .setNotificationsMuted(s.id, false),
                ),
              const SizedBox(height: 20),
            ],
            if (locations.isNotEmpty) ...[
              _SectionLabel(text: 'MUTED SPACES (${locations.length})', surface: surface),
              const SizedBox(height: 8),
              for (final l in locations)
                _MutedRow(
                  title: l.name,
                  subtitle: 'Every plant in this space is silenced.',
                  icon: Icons.place_outlined,
                  surface: surface,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => LocationDetailScreen(locationId: l.id)),
                    );
                  },
                  onUnmute: () =>
                      ref.read(locationRepositoryProvider).setNotificationsMuted(l.id, false),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PermissionCard extends ConsumerWidget {
  const _PermissionCard({required this.surface, required this.granted});
  final PlantlySurface surface;
  final bool? granted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (status, color, icon) = switch (granted) {
      null => ('Checking system permission…', surface.muted, Icons.hourglass_empty),
      true => ('OS notifications are allowed for PlantlyInventory.', surface.green, Icons.notifications_active_outlined),
      false => ('OS notifications are OFF. Reminders won\'t fire.', surface.terra, Icons.notifications_off_outlined),
    };
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: InkWell(
        onTap: granted == true
            ? null
            : () async {
                final ok = await ref.read(notificationServiceProvider).requestPermissions();
                ref.read(notificationPermissionProvider.notifier).state = ok;
              },
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(status, style: TextStyle(fontSize: 13, color: surface.text)),
              ),
              if (granted != true) Icon(Icons.chevron_right, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface.surface,
        border: Border.all(color: surface.border),
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_none_outlined, size: 32, color: surface.muted),
          const SizedBox(height: 10),
          Text('Nothing muted',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
          const SizedBox(height: 4),
          Text(
            'Silence reminders per plant, schedule, or space from the relevant detail screen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: surface.muted),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: surface.green,
        letterSpacing: 0.1 * 11,
      ),
    );
  }
}

class _MutedRow extends StatelessWidget {
  const _MutedRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.surface,
    required this.onTap,
    required this.onUnmute,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final PlantlySurface surface;
  final VoidCallback onTap;
  final VoidCallback onUnmute;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: surface.surface,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: surface.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                      Text(subtitle, style: TextStyle(fontSize: 11.5, color: surface.muted)),
                    ],
                  ),
                ),
                TextButton.icon(
                  icon: Icon(Icons.notifications_active_outlined, size: 14, color: surface.green),
                  label: Text('Unmute', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surface.green)),
                  onPressed: onUnmute,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
