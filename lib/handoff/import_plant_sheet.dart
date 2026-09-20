import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/providers.dart';
import '../features/home/home_providers.dart';
import '../features/plant_detail/plant_detail_screen.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'import_plant_service.dart';
import 'plantly_export.dart';

final importPlantServiceProvider = Provider<ImportPlantService>((ref) {
  final ctx = ref.watch(appContextProvider).requireValue;
  return ImportPlantService(
    db: ctx.db,
    plants: ref.watch(plantRepositoryProvider),
    species: ref.watch(speciesRepositoryProvider),
    photos: ref.watch(photoRepositoryProvider),
    plantPhotos: ref.watch(plantPhotoRepositoryProvider),
    tenantId: ctx.opLog.tenantId,
  );
});

/// Preview-then-confirm sheet for an incoming PlantlyExport (CONTRACT §4b).
/// On confirm it writes the plant and pushes its detail screen.
Future<void> showImportPlantSheet(BuildContext context, PlantlyExportPayload payload) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ImportPlantSheet(payload: payload),
  );
}

/// Friendly error for a malformed / oversized link.
Future<void> showImportErrorSheet(BuildContext context, PlantlyExportFormatError error) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ImportErrorSheet(error: error),
  );
}

class ImportPlantSheet extends ConsumerStatefulWidget {
  const ImportPlantSheet({super.key, required this.payload});
  final PlantlyExportPayload payload;

  @override
  ConsumerState<ImportPlantSheet> createState() => _ImportPlantSheetState();
}

class _ImportPlantSheetState extends ConsumerState<ImportPlantSheet> {
  late final TextEditingController _nickname;
  bool _saving = false;
  bool _recent = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.payload.defaultNickname);
    unawaited(_checkRecent());
  }

  Future<void> _checkRecent() async {
    try {
      final dup = await ref.read(importPlantServiceProvider).recentDuplicate(widget.payload);
      if (mounted && dup != null) setState(() => _recent = true);
    } catch (_) {
      // Hint only — never block the import on it.
    }
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      final plant = await ref.read(importPlantServiceProvider).import(
            widget.payload,
            nickname: _nickname.text,
            t: t,
          );
      if (!mounted) return;
      navigator.pop();
      navigator.push(MaterialPageRoute(builder: (_) => PlantDetailScreen(plantId: plant.id)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final p = widget.payload;
    final thumb = p.thumbBytes;
    final inset = MediaQuery.of(context).viewInsets.bottom;
    final health = p.healthStatus;
    final obs = p.observations ?? const [];

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: Container(
        decoration: BoxDecoration(
          color: surface.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  p.isFromMarketplace ? t.importSourceMarketplace : t.importSourceAssistant,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.terra, letterSpacing: 1.1),
                ),
                Text(
                  t.importTitle,
                  style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800, color: surface.text),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                      child: thumb != null
                          ? Image.memory(thumb, key: const Key('import-thumb'), width: 72, height: 72, fit: BoxFit.cover)
                          : Container(
                              width: 72,
                              height: 72,
                              color: surface.surfaceAlt,
                              child: Icon(Icons.local_florist_outlined, color: surface.green),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.scientificName,
                            style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: surface.text),
                          ),
                          if (p.commonName != null)
                            Text(p.commonName!, style: TextStyle(fontSize: 12.5, color: surface.muted)),
                          if (health != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              t.importHealthLine(ImportPlantService.healthLabel(health, t)),
                              style: TextStyle(fontSize: 12, color: surface.text),
                            ),
                          ],
                          if (obs.isNotEmpty)
                            Text(
                              obs.map((o) => ImportPlantService.observationLabel(o.kind, t)).join(' · '),
                              style: TextStyle(fontSize: 11.5, color: surface.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  t.importNicknameLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.muted, letterSpacing: 0.9),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('import-nickname'),
                  controller: _nickname,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 14, color: surface.text),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: surface.surface,
                    contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                      borderSide: BorderSide(color: surface.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                      borderSide: BorderSide(color: surface.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                      borderSide: BorderSide(color: surface.green, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(t.importNoSchedulesHint, style: TextStyle(fontSize: 11.5, color: surface.muted)),
                if (_recent) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const Key('import-recent-hint'),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: surface.surfaceAlt,
                      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                      border: Border.all(color: surface.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, size: 16, color: surface.terra),
                        const SizedBox(width: 8),
                        Expanded(child: Text(t.importRecentDuplicate, style: TextStyle(fontSize: 12, color: surface.text))),
                      ],
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(fontSize: 12, color: surface.terra)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: surface.surfaceAlt,
                          foregroundColor: surface.text,
                          side: BorderSide(color: surface.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                        ),
                        onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                        child: Text(t.importCancel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const Key('import-confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: surface.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                        ),
                        onPressed: _saving ? null : _confirm,
                        child: _saving
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_recent ? t.importConfirmAgain : t.importConfirm,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportErrorSheet extends ConsumerWidget {
  const _ImportErrorSheet({required this.error});
  final PlantlyExportFormatError error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final detail = switch (error) {
      PlantlyExportFormatError.tooLarge => t.importErrorTooLarge,
      PlantlyExportFormatError.unsupportedVersion => t.importErrorVersion,
      _ => t.importErrorMalformed,
    };
    return Container(
      decoration: BoxDecoration(
        color: surface.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: surface.terra),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t.importErrorTitle,
                      style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: surface.text)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(detail, key: const Key('import-error'), style: TextStyle(fontSize: 13, color: surface.muted)),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(t.importErrorDismiss, style: TextStyle(color: surface.green)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
