import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/repositories/location_repository.dart';
import '../features/locations/space_kind_label.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import '../features/home/home_providers.dart';

/// Hierarchical location picker. Renders the location tree indented by
/// depth with a parent → child icon trail so users can see context. Used
/// from Add-Plant, Edit-Plant, and the Plant Detail "Move to space"
/// overflow action.
///
/// Returns the picked location id (or `null` for "— no location —"), or
/// undefined if the user dismissed the dialog.
///
/// [title] overrides the dialog title; defaults to "Move to space", which
/// suits Edit / Move flows — pass a neutral one (e.g. `spacePickerChooseTitle`)
/// when the plant doesn't exist yet.
Future<String?> pickLocation(
  BuildContext context, {
  required WidgetRef ref,
  String? currentLocationId,
  String? title,
}) async {
  final pickedWrapped = await showDialog<_PickResult>(
    context: context,
    builder: (_) => _PickerDialog(currentLocationId: currentLocationId, title: title),
  );
  if (pickedWrapped == null) return currentLocationId; // dismissed
  return pickedWrapped.locationId;
}

class _PickResult {
  const _PickResult(this.locationId);
  final String? locationId;
}

class _PickerDialog extends ConsumerWidget {
  const _PickerDialog({required this.currentLocationId, this.title});
  final String? currentLocationId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final async = ref.watch(locationsStreamProvider);

    return AlertDialog(
      title: Text(title ?? AppLocalizations.of(context).spacePickerTitle),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 320,
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e', style: TextStyle(color: surface.terra)),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context).spacePickerEmpty,
                  style: TextStyle(color: surface.muted),
                ),
              );
            }
            final tree = buildTree(rows);
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    dense: true,
                    selected: currentLocationId == null,
                    leading: const Icon(Icons.clear),
                    title: Text(AppLocalizations.of(context).addPlantNoLocation),
                    onTap: () => Navigator.of(context).pop(const _PickResult(null)),
                  ),
                  const Divider(height: 8),
                  for (final node in tree) ..._render(context, node, 0, surface),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(AppLocalizations.of(context).cancel),
        ),
      ],
    );
  }

  List<Widget> _render(BuildContext context, LocationNode node, int depth, PlantlySurface surface) {
    return [
      InkWell(
        onTap: () => Navigator.of(context).pop(_PickResult(node.row.id)),
        child: Container(
          color: node.row.id == currentLocationId ? surface.greenSoft : null,
          padding: EdgeInsets.only(left: 16.0 + depth * 20, right: 12, top: 8, bottom: 8),
          child: Row(
            children: [
              Icon(_iconFor(node.row.kind), size: 18, color: surface.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node.row.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    Text(spaceKindLabel(AppLocalizations.of(context), node.row.kind), style: TextStyle(fontSize: 11, color: surface.muted)),
                  ],
                ),
              ),
              if (node.row.id == currentLocationId)
                Icon(Icons.check, size: 16, color: surface.green),
            ],
          ),
        ),
      ),
      for (final child in node.children) ..._render(context, child, depth + 1, surface),
    ];
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'home':
        return Icons.home_outlined;
      case 'room':
        return Icons.meeting_room_outlined;
      case 'shelf':
        return Icons.shelves;
      case 'outdoor_bed':
        return Icons.outdoor_grill_outlined;
      case 'zone':
        return Icons.crop_square;
      default:
        return Icons.place_outlined;
    }
  }
}
