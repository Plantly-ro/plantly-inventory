import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/location_repository.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Hierarchical locations list + add dialog. Matches the prototype's
/// "Spaces" tab-bar entry.
class LocationsScreen extends ConsumerWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final async = ref.watch(locationsStreamProvider);

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
          'Spaces',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: surface.green,
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const _AddLocationDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => Center(child: CircularProgressIndicator(color: surface.green)),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Could not load locations.\n$e', style: TextStyle(color: surface.terra)),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No spaces yet. Tap + to add a room, shelf, or balcony.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: surface.muted, fontSize: 14),
                ),
              ),
            );
          }
          final tree = buildTree(rows);
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              for (final node in tree) _LocationTile(node: node, depth: 0, surface: surface),
            ],
          );
        },
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({required this.node, required this.depth, required this.surface});
  final LocationNode node;
  final int depth;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 20.0, bottom: 4, top: depth == 0 ? 12 : 4),
          child: Container(
            decoration: BoxDecoration(
              color: surface.surface,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_iconFor(node.row.kind), size: 18, color: surface.green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.row.name,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                      ),
                      Text(
                        node.row.kind,
                        style: TextStyle(fontSize: 11, color: surface.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final child in node.children) _LocationTile(node: child, depth: depth + 1, surface: surface),
      ],
    );
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
      default:
        return Icons.place_outlined;
    }
  }
}

class _AddLocationDialog extends ConsumerStatefulWidget {
  const _AddLocationDialog();

  @override
  ConsumerState<_AddLocationDialog> createState() => _AddLocationDialogState();
}

class _AddLocationDialogState extends ConsumerState<_AddLocationDialog> {
  final _name = TextEditingController();
  String _kind = 'room';
  String? _parentId;

  static const _kinds = ['home', 'room', 'zone', 'shelf', 'outdoor_bed'];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(locationsStreamProvider);
    final parents = async.maybeWhen(data: (r) => r, orElse: () => const <LocationRow>[]);
    return AlertDialog(
      title: const Text('Add a space'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Living room'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Kind'),
              items: [for (final k in _kinds) DropdownMenuItem(value: k, child: Text(k))],
              onChanged: (v) => setState(() => _kind = v ?? 'room'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              decoration: const InputDecoration(labelText: 'Inside (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— top level —')),
                for (final p in parents)
                  DropdownMenuItem<String?>(value: p.id, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _parentId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            final nav = Navigator.of(context);
            await ref.read(locationRepositoryProvider).create(
                  name: name,
                  kind: _kind,
                  parentId: _parentId,
                  isOutdoor: _kind == 'outdoor_bed',
                );
            if (!mounted) return;
            nav.maybePop();
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
