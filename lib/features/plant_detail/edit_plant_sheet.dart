import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../shared/location_picker.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Edit the nickname / notes / location for an existing plant. Species
/// input is free-text for now — we store it as the literal species name
/// (the seed taxonomy lands in a later PR). Location dropdown is populated
/// from `locationsStreamProvider`.
class EditPlantSheet extends ConsumerStatefulWidget {
  const EditPlantSheet({super.key, required this.plantRow});
  final PlantRow plantRow;

  @override
  ConsumerState<EditPlantSheet> createState() => _EditPlantSheetState();
}

class _EditPlantSheetState extends ConsumerState<EditPlantSheet> {
  late final TextEditingController _nickname;
  late final TextEditingController _notes;
  late final TextEditingController _species;
  late String? _locationId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.plantRow.nickname);
    _notes = TextEditingController(text: widget.plantRow.notes ?? '');
    _species = TextEditingController(text: widget.plantRow.speciesId ?? '');
    _resolveSpeciesName();
    _locationId = widget.plantRow.locationId;
  }

  /// `species_id` may point at a real `species` row (imports) — show its
  /// scientific name instead of the ULID, and keep the id if the user
  /// leaves the text untouched.
  String? _resolvedSpeciesName;

  Future<void> _resolveSpeciesName() async {
    final id = widget.plantRow.speciesId;
    if (id == null || id.isEmpty) return;
    final name = await ref.read(speciesRepositoryProvider).displayName(id);
    if (!mounted || name == null || name == id) return;
    setState(() {
      _resolvedSpeciesName = name;
      if (_species.text == id) _species.text = name;
    });
  }

  String? _speciesValue() {
    final text = _species.text.trim();
    if (text.isEmpty) return null;
    if (_resolvedSpeciesName != null && text == _resolvedSpeciesName) return widget.plantRow.speciesId;
    return text;
  }

  @override
  void dispose() {
    _nickname.dispose();
    _notes.dispose();
    _species.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nickname.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nickname is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(plantRepositoryProvider).edit(
            widget.plantRow.id,
            nickname: name,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            locationId: _locationId,
            speciesId: _speciesValue(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final locations = ref.watch(locationsStreamProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <LocationRow>[],
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: surface.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text('Edit plant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text)),
            const SizedBox(height: 14),
            _label('NICKNAME', surface),
            const SizedBox(height: 6),
            TextField(
              controller: _nickname,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(surface),
            ),
            const SizedBox(height: 12),
            _label('SPACE', surface),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await pickLocation(
                  context,
                  ref: ref,
                  currentLocationId: _locationId,
                );
                if (picked != _locationId) setState(() => _locationId = picked);
              },
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: surface.surface,
                  border: Border.all(color: surface.border),
                  borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                ),
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: surface.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locSummary(_locationId, locations),
                        style: TextStyle(fontSize: 14, color: surface.text),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: surface.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _label('SPECIES', surface),
            const SizedBox(height: 6),
            TextField(
              controller: _species,
              decoration: _dec(surface, hint: 'e.g. Monstera deliciosa'),
            ),
            const SizedBox(height: 12),
            _label('NOTES', surface),
            const SizedBox(height: 6),
            TextField(
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: _dec(surface, hint: 'optional'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: surface.terra, fontSize: 12)),
            ],
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: surface.surfaceAlt,
                      foregroundColor: surface.muted,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                      ),
                    ),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: surface.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Text _label(String text, PlantlySurface s) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.muted,
          letterSpacing: 0.08 * 11,
        ),
      );

  String _locSummary(String? id, List<LocationRow> rows) {
    if (id == null) return '— no location —';
    for (final r in rows) {
      if (r.id == id) return '${r.name} · ${r.kind}';
    }
    return 'Loading…';
  }

  InputDecoration _dec(PlantlySurface s, {String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: s.muted),
        filled: true,
        fillColor: s.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          borderSide: BorderSide(color: s.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          borderSide: BorderSide(color: s.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          borderSide: BorderSide(color: s.green, width: 1.5),
        ),
      );
}
