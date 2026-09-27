import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../locations/space_kind_label.dart';
import '../../app/breakpoints.dart';
import '../../shared/location_picker.dart';
import '../../shared/sheet_chrome.dart';
import '../../theme/tokens.dart';
import 'home_providers.dart';

/// Minimal "add a plant" sheet — nickname is the only required field.
/// Further fields (species, location, source, notes, pot size) get added
/// as those features ship in subsequent Phase 1 PRs.
class AddPlantSheet extends ConsumerStatefulWidget {
  const AddPlantSheet({super.key});

  @override
  ConsumerState<AddPlantSheet> createState() => _AddPlantSheetState();
}

String _locationLabel(AppLocalizations t, String? id, List<LocationRow> rows) {
  if (id == null) return t.addPlantNoLocation;
  for (final r in rows) {
    if (r.id == id) return '${r.name} · ${spaceKindLabel(t, r.kind)}';
  }
  return t.addPlantLoading;
}

class _AddPlantSheetState extends ConsumerState<AddPlantSheet> {
  final _nickname = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _locationId;

  @override
  void dispose() {
    _nickname.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final repo = ref.watch(plantRepositoryProvider);
    final locations = ref.watch(locationsStreamProvider).maybeWhen(
          data: (rows) => rows,
          orElse: () => const <LocationRow>[],
        );

    Future<void> submit() async {
      final name = _nickname.text.trim();
      if (name.isEmpty) return;
      // Capture the Navigator before the await so the analyzer's
      // use_build_context_synchronously lint is satisfied.
      final navigator = Navigator.of(context);
      setState(() => _saving = true);
      try {
        await repo.create(
          nickname: name,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          locationId: _locationId,
        );
        if (!mounted) return;
        navigator.maybePop();
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SheetChrome(
          surface: surface,
          title: t.addPlant,
          topRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          handleGap: 14,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          footer: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: surface.green,
              padding: context.isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 20, vertical: 10)
                  : const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2),
              ),
            ),
            onPressed: _saving ? null : submit,
            child: Text(_saving ? t.saving : t.addPlantSubmit),
          ),
          children: [
            if (!context.isDesktop) ...[
              Text(
                t.addPlant,
                style: TextStyle(fontFamily: PlantlyFonts.plusJakartaSans, 
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                  letterSpacing: -0.02 * 22,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              t.addPlantNicknameLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: surface.muted,
                letterSpacing: 0.08 * 11,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _nickname,
              autofocus: true,
              maxLength: 64,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saving ? null : submit(),
              decoration: InputDecoration(
                hintText: t.nicknameHint,
                counterText: '',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              t.addPlantSpaceLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: surface.muted,
                letterSpacing: 0.08 * 11,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: locations.isEmpty
                  ? null
                  : () async {
                      final picked = await pickLocation(
                        context,
                        ref: ref,
                        currentLocationId: _locationId,
                        title: AppLocalizations.of(context).spacePickerChooseTitle,
                      );
                      if (picked != _locationId) setState(() => _locationId = picked);
                    },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: surface.border),
                  borderRadius: BorderRadius.circular(4),
                  color: surface.surface,
                ),
                child: Row(
                  children: [
                    Icon(Icons.place_outlined, size: 16, color: surface.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _locationLabel(t, _locationId, locations),
                        style: TextStyle(fontSize: 14, color: surface.text),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: surface.muted),
                  ],
                ),
              ),
            ),
            if (locations.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  t.addPlantAddSpaceFirst,
                  style: TextStyle(fontSize: 11, color: surface.muted),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              t.addPlantNotesLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: surface.muted,
                letterSpacing: 0.08 * 11,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: t.notesHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
