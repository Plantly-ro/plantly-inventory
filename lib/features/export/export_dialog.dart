import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/database/app_database.dart' as db;
import '../../data/mock_plants.dart';
import '../../data/providers.dart';
import '../../plugins/export_plugin.dart';
import '../../plugins/plugin_registry.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Draft a plantly.ro listing. Reads live data from the DB:
///   - Title/description seeded from the plant row (nickname + notes).
///   - Photos come from the plant's attached OR-set (max 6).
///
/// Phase 1 is still "draft" only — "Post now" writes to the draft store
/// and surfaces a confirmation; the actual network plugin lands in Phase 2.
class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key, required this.plantRow});
  final db.PlantRow plantRow;

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  final _selected = <String>{};
  bool _selectionInitialised = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.plantRow.nickname);
    _desc = TextEditingController(text: widget.plantRow.notes ?? '');
    _price = TextEditingController();
    // Fire-and-forget: if a draft exists for this plant, prefill — lets
    // the user resume a half-filled listing instead of re-typing.
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final draft =
        await ref.read(localDraftStoreProvider).loadDraft(widget.plantRow.id);
    if (draft == null || !mounted) return;
    setState(() {
      if (draft.title.isNotEmpty) _title.text = draft.title;
      if (draft.description.isNotEmpty) _desc.text = draft.description;
      if (draft.priceLei != null) _price.text = draft.priceLei.toString();
      if (draft.photoRefs.isNotEmpty) {
        _selected
          ..clear()
          ..addAll(draft.photoRefs);
        _selectionInitialised = true;
      }
      _posted = draft.postedAt?.toUtc().toIso8601String();
    });
  }

  /// Snapshot the current form as an [ExportDraft]. Category / county / city
  /// are still placeholder UI (not yet editable), so they're intentionally
  /// left unset here rather than persisting the fake displayed values.
  ExportDraft _buildDraft({DateTime? postedAt}) {
    return ExportDraft(
      sourcePlantId: widget.plantRow.id,
      title: _title.text,
      description: _desc.text,
      priceLei: int.tryParse(_price.text.trim()),
      photoRefs: _selected.toList(),
      postedAt: postedAt ??
          (_posted != null ? DateTime.tryParse(_posted!) : null),
    );
  }

  Future<void> _persistDraft() async {
    await ref.read(localDraftStoreProvider).saveDraft(_buildDraft());
  }

  String? _posted;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final plant = widget.plantRow;
    final swatch = MockPlants.byId(plant.id);
    final shas = ref.watch(attachedPhotosProvider(plant.id)).maybeWhen(
          data: (list) => list,
          orElse: () => const <String>[],
        );
    // First time we see photos, preselect up to 6 so the user isn't greeted
    // with a zero-selected export.
    if (!_selectionInitialised && shas.isNotEmpty) {
      _selectionInitialised = true;
      _selected.addAll(shas.take(6));
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: surface.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                height: 4,
                width: 40,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🌿 PLANTLY.RO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: surface.terra,
                              letterSpacing: 0.1 * 11,
                            ),
                          ),
                          Text(
                            'Post "${plant.nickname}"',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: surface.text,
                              letterSpacing: -0.02 * 19,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close, color: surface.text),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [
                    _Label(text: 'TITLE', surface: surface),
                    _Field(controller: _title, maxLength: 64, surface: surface, onChanged: (_) => setState(() {})),
                    _CharCount(value: _title.text.length, max: 64, surface: surface),
                    const SizedBox(height: 10),
                    _Label(text: 'DESCRIPTION', surface: surface),
                    _Field(controller: _desc, maxLength: 2000, surface: surface, maxLines: 3, onChanged: (_) => setState(() {})),
                    _CharCount(value: _desc.text.length, max: 2000, surface: surface),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label(text: 'PRICE', surface: surface),
                              Stack(
                                alignment: Alignment.centerRight,
                                children: [
                                  _Field(
                                    controller: _price,
                                    surface: surface,
                                    keyboardType: TextInputType.number,
                                    suffixPadding: 40,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Text(
                                      'lei',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.muted),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label(text: 'CATEGORY', surface: surface),
                              _FakeInput(text: 'Indoor plant', surface: surface, trailingIcon: Icons.expand_more),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Label(text: 'LOCATION', surface: surface),
                    _FakeInput(text: 'Timiș County · Timișoara', surface: surface, leadingIcon: Icons.place_outlined),
                    const SizedBox(height: 14),
                    _Label(text: 'PHOTOS (${_selected.length}/6)', surface: surface),
                    const SizedBox(height: 8),
                    _PhotoGrid(
                      shas: shas,
                      selected: _selected,
                      swatch: swatch,
                      surface: surface,
                      onToggle: (sha) {
                        setState(() {
                          if (_selected.contains(sha)) {
                            _selected.remove(sha);
                          } else if (_selected.length < 6) {
                            _selected.add(sha);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: surface.surface,
                  border: Border(top: BorderSide(color: surface.border)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: surface.surfaceAlt,
                            foregroundColor: surface.text,
                            side: BorderSide(color: surface.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            await _persistDraft();
                            if (context.mounted) _finish('Draft saved');
                          },
                          child: const Text('Save draft'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 14,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: surface.terra,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          onPressed: () async {
                            final plugin = ref.read(defaultExportPluginProvider);
                            ExportProgress? last;
                            await for (final p in plugin.submit(_buildDraft())) {
                              last = p;
                            }
                            if (!context.mounted) return;
                            if (last?.error != null) {
                              _finish('Could not post: ${last!.error}');
                            } else {
                              _finish(last?.message ?? 'Posted');
                            }
                          },
                          child: const Text('Post now'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _finish(String msg) {
    Navigator.of(context).maybePop();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text, required this.surface});
  final String text;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: surface.muted,
          letterSpacing: 0.08 * 11,
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.surface,
    this.maxLength,
    this.maxLines = 1,
    this.keyboardType,
    this.suffixPadding = 12,
    this.onChanged,
  });
  final TextEditingController controller;
  final PlantlySurface surface;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final double suffixPadding;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: surface.text),
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: surface.surface,
        contentPadding: EdgeInsets.fromLTRB(12, 10, suffixPadding, 10),
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
    );
  }
}

class _CharCount extends StatelessWidget {
  const _CharCount({required this.value, required this.max, required this.surface});
  final int value;
  final int max;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text('$value/$max', style: TextStyle(fontSize: 10.5, color: surface.muted)),
      ),
    );
  }
}

class _FakeInput extends StatelessWidget {
  const _FakeInput({
    required this.text,
    required this.surface,
    this.leadingIcon,
    this.trailingIcon,
  });
  final String text;
  final PlantlySurface surface;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface.surface,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        border: Border.all(color: surface.border),
      ),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 13, color: surface.muted),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: surface.text))),
          if (trailingIcon != null) Icon(trailingIcon, size: 14, color: surface.muted),
        ],
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid({
    required this.shas,
    required this.selected,
    required this.swatch,
    required this.surface,
    required this.onToggle,
  });
  final List<String> shas;
  final Set<String> selected;
  final MockPlant swatch;
  final PlantlySurface surface;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface.surface,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        ),
        alignment: Alignment.center,
        child: Text(
          'No photos attached. Add some on the plant detail screen first.',
          style: TextStyle(fontSize: 12, color: surface.muted),
          textAlign: TextAlign.center,
        ),
      );
    }
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (final sha in shas)
          GestureDetector(
            onTap: () => onToggle(sha),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                    border: Border.all(
                      color: selected.contains(sha) ? surface.green : surface.border,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Opacity(
                    opacity: selected.contains(sha) ? 1 : 0.45,
                    child: _GridPhoto(sha: sha, fallback: swatch),
                  ),
                ),
                if (selected.contains(sha))
                  Positioned(
                    top: 3,
                    right: 3,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(color: surface.green, shape: BoxShape.circle),
                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _GridPhoto extends ConsumerWidget {
  const _GridPhoto({required this.sha, required this.fallback});
  final String sha;
  final MockPlant fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(photoRepositoryProvider);
    return FutureBuilder(
      future: repo.byHash(sha),
      builder: (_, snap) {
        final path = snap.data?.localPath;
        if (path != null && File(path).existsSync()) {
          return Image.file(File(path), fit: BoxFit.cover, width: 80, height: 80);
        }
        return PlantThumb(plant: fallback, size: 80);
      },
    );
  }
}
