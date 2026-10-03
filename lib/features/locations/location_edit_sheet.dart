import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'space_kind_label.dart';
import '../../app/breakpoints.dart';
import '../../shared/sheet_chrome.dart';

/// Edit every user-visible field on a location in one sheet — kind,
/// parent, outdoor flag, light level, humidity/temp ranges, notes.
/// Creates a new location when [existing] is null.
class LocationEditSheet extends ConsumerStatefulWidget {
  const LocationEditSheet({super.key, this.existing});
  final LocationRow? existing;

  @override
  ConsumerState<LocationEditSheet> createState() => _LocationEditSheetState();
}

class _LocationEditSheetState extends ConsumerState<LocationEditSheet> {
  static const _kinds = ['home', 'room', 'zone', 'shelf', 'outdoor_bed'];
  static const _lights = <String>['bright direct', 'bright indirect', 'medium', 'low'];

  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _humMin = TextEditingController();
  final _humMax = TextEditingController();
  final _tempMin = TextEditingController();
  final _tempMax = TextEditingController();

  String _kind = 'room';
  String? _parentId;
  String? _light;
  bool _isOutdoor = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _name.text = e.name;
      _notes.text = e.notes ?? '';
      _kind = e.kind;
      _parentId = e.parentId;
      _light = e.light;
      _isOutdoor = e.isOutdoor;
      _humMin.text = e.humidityMin?.toString() ?? '';
      _humMax.text = e.humidityMax?.toString() ?? '';
      _tempMin.text = e.tempMinC?.toString() ?? '';
      _tempMax.text = e.tempMaxC?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _humMin.dispose();
    _humMax.dispose();
    _tempMin.dispose();
    _tempMax.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).spaceNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(locationRepositoryProvider);
      final humMin = int.tryParse(_humMin.text.trim());
      final humMax = int.tryParse(_humMax.text.trim());
      final tempMin = double.tryParse(_tempMin.text.trim().replaceAll(',', '.'));
      final tempMax = double.tryParse(_tempMax.text.trim().replaceAll(',', '.'));
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      if (widget.existing == null) {
        final created = await repo.create(
          name: name,
          kind: _kind,
          parentId: _parentId,
          isOutdoor: _isOutdoor,
          light: _light,
        );
        // Second pass to persist all the other fields (LocationRepository
        // only had a minimal create signature — we don't want to bloat it).
        await repo.edit(
          created.id,
          name: name,
          kind: _kind,
          parentId: _parentId,
          isOutdoor: _isOutdoor,
          light: _light,
          humidityMin: humMin,
          humidityMax: humMax,
          tempMinC: tempMin,
          tempMaxC: tempMax,
          notes: notes,
        );
      } else {
        await repo.edit(
          widget.existing!.id,
          name: name,
          kind: _kind,
          parentId: _parentId,
          isOutdoor: _isOutdoor,
          light: _light,
          humidityMin: humMin,
          humidityMax: humMax,
          tempMinC: tempMin,
          tempMaxC: tempMax,
          notes: notes,
        );
      }
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
    final t = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final locations = ref.watch(locationsStreamProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <LocationRow>[],
        );
    // Disallow cycles: a location can't be its own parent.
    final parentCandidates = widget.existing == null
        ? locations
        : locations.where((l) => l.id != widget.existing!.id).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SheetChrome(
        surface: surface,
        title: widget.existing == null ? t.addSpace : t.spaceEditTitle(widget.existing!.name),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        handleGap: 14,
        crossAxisAlignment: CrossAxisAlignment.start,
        scrollable: true,
        children: [
              if (!context.isDesktop) ...[
              Text(
                widget.existing == null ? t.addSpace : t.spaceEditTitle(widget.existing!.name),
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
              ),
              const SizedBox(height: 14),
              ],
              _label(t.spaceNameLabel, surface),
              const SizedBox(height: 6),
              TextField(
                controller: _name,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec(surface, hint: t.spaceNameHint),
              ),
              const SizedBox(height: 12),
              _label(t.spaceKindUpper, surface),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                isExpanded: true,
                decoration: _dec(surface),
                items: [for (final k in _kinds) DropdownMenuItem(value: k, child: Text(spaceKindLabel(t, k)))],
                onChanged: (v) => setState(() => _kind = v ?? 'room'),
              ),
              const SizedBox(height: 12),
              _label(t.spaceInsideLabel, surface),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _parentId,
                isExpanded: true,
                decoration: _dec(surface, hint: t.spaceTopLevelHint),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(t.topLevel)),
                  for (final p in parentCandidates)
                    DropdownMenuItem<String?>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _parentId = v),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.spaceOutdoor, style: TextStyle(color: surface.text)),
                subtitle: Text(t.spaceOutdoorSub, style: TextStyle(color: surface.muted, fontSize: 12)),
                value: _isOutdoor,
                activeThumbColor: surface.green,
                onChanged: (v) => setState(() => _isOutdoor = v),
              ),
              const SizedBox(height: 8),
              _label(t.spaceLightLabel, surface),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _light,
                isExpanded: true,
                decoration: _dec(surface, hint: t.spaceUnspecifiedHint),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(t.spaceUnspecified)),
                  for (final l in _lights)
                    DropdownMenuItem<String?>(value: l, child: Text(spaceLightLabel(t, l))),
                ],
                onChanged: (v) => setState(() => _light = v),
              ),
              const SizedBox(height: 12),
              _label(t.spaceHumidityLabel, surface),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextField(controller: _humMin, keyboardType: TextInputType.number, decoration: _dec(surface, hint: t.spaceMin))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _humMax, keyboardType: TextInputType.number, decoration: _dec(surface, hint: t.spaceMax))),
                ],
              ),
              const SizedBox(height: 12),
              _label(t.spaceTempLabel, surface),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: TextField(controller: _tempMin, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: _dec(surface, hint: t.spaceMin))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _tempMax, keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), decoration: _dec(surface, hint: t.spaceMax))),
                ],
              ),
              const SizedBox(height: 12),
              _label(t.spaceNotesLabel, surface),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec(surface, hint: t.notesHint),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                      ),
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: Text(t.cancel),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: surface.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? t.saving : t.commonSave),
                    ),
                  ),
                ],
              ),
            ],
      ),
    );
  }

  Text _label(String text, PlantlySurface s) => Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: s.muted,
          letterSpacing: 1.1,
        ),
      );

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
