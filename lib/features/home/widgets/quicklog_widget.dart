import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/mock_plants.dart';
import '../../../data/providers.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/plant_thumb.dart';
import '../../../theme/tokens.dart';
import 'widget_shell.dart';
import '../../../app/side_sheet.dart';

/// "Quick log" — shortcut to record Water / Fertilize / Mist across any
/// plant in the collection in two taps. Each tile opens a plant picker;
/// picking a plant writes a `care_events` row of the chosen type.
class QuickLogWidget extends ConsumerWidget {
  const QuickLogWidget({
    super.key,
    required this.surface,
    this.onLog,
    this.editing = false,
    this.onMoveUp,
    this.onMoveDown,
    this.onRemove,
  });

  final PlantlySurface surface;
  final void Function(String message)? onLog;
  final bool editing;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final actions = <_Action>[
      _Action(t.quickLogWater, 'water', Icons.water_drop_outlined, surface.green, surface.greenSoft),
      _Action(t.quickLogFertilize, 'fertilize', Icons.eco_outlined, surface.green, surface.greenSoft),
      _Action(t.quickLogMist, 'mist', Icons.bubble_chart_outlined, surface.terra, surface.terraSoft),
      _Action(t.quickLogRotate, 'rotate', Icons.light_mode_outlined, surface.terra, surface.terraSoft),
    ];
    return WidgetShell(
      surface: surface,
      editing: editing,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      onRemove: onRemove,
      title: t.quickLogTitle,
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.85,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: actions.map((a) {
          return _Btn(
            action: a,
            surface: surface,
            onTap: () => _pickPlant(context, ref, a),
          );
        }).toList(growable: false),
      ),
    );
  }

  Future<void> _pickPlant(BuildContext context, WidgetRef ref, _Action action) async {
    final t = AppLocalizations.of(context);
    final plant = await showAdaptiveSheet<PlantRow>(
      context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlantPickerSheet(surface: surface, action: action),
    );
    if (plant == null) return;
    await ref.read(careEventRepositoryProvider).record(
          plantId: plant.id,
          type: action.type,
        );
    onLog?.call(t.homeToastActionLogged(action.label, plant.nickname));
  }
}

class _Action {
  const _Action(this.label, this.type, this.icon, this.color, this.soft);
  final String label;
  final String type;
  final IconData icon;
  final Color color;
  final Color soft;
}

class _Btn extends StatelessWidget {
  const _Btn({required this.action, required this.surface, required this.onTap});
  final _Action action;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radiusXl),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: action.soft,
                  borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                ),
                child: Icon(action.icon, size: 16, color: action.color),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: surface.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlantPickerSheet extends ConsumerWidget {
  const _PlantPickerSheet({required this.surface, required this.action});
  final PlantlySurface surface;
  final _Action action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(plantsStreamProvider).maybeWhen(
          data: (r) => r,
          orElse: () => const <PlantRow>[],
        );
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: surface.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(action.icon, color: action.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context).homeQuickLogWhich(action.label), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: surface.text)),
                          Text(AppLocalizations.of(context).homeQuickLogRecordsNow, style: TextStyle(fontSize: 12, color: surface.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: plants.isEmpty
                    ? Center(
                        child: Text(AppLocalizations.of(context).homeQuickLogEmpty, style: TextStyle(color: surface.muted)),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                        itemCount: plants.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (_, i) {
                          final p = plants[i];
                          return Material(
                            color: surface.surface,
                            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                              onTap: () => Navigator.of(context).pop(p),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: surface.border),
                                  borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                child: Row(
                                  children: [
                                    PlantPhotoThumb(
                                      plantId: p.id,
                                      fallback: MockPlants.byId(p.id),
                                      size: 40,
                                      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        p.nickname,
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: surface.muted),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
