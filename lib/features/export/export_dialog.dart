import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/mock_plants.dart';
import '../../shared/plant_thumb.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Port of `ExportDialog` in `web/prototype/components/screens.jsx`.
/// The dialog mirrors plantly.ro's post fields exactly:
/// title ≤64, description ≤2000, price in lei, category, location, ≤6 photos.
class ExportDialog extends ConsumerStatefulWidget {
  const ExportDialog({super.key, required this.plant});
  final MockPlant plant;

  @override
  ConsumerState<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends ConsumerState<ExportDialog> {
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _price;
  final _photos = <bool>[true, true, true, false, false];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: 'Monstera deliciosa variegata');
    _desc = TextEditingController(
      text:
          'Mature Monstera, 5 leaves, propagated from my mother plant in 2024. Healthy and ready to re-home.',
    );
    _price = TextEditingController(text: '250');
  }

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
    final selectedCount = _photos.where((x) => x).length;

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
                decoration: BoxDecoration(
                  color: surface.border,
                  borderRadius: BorderRadius.circular(2),
                ),
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
                            'Post "${widget.plant.name}"',
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
                    _Field(controller: _title, maxLength: 64, surface: surface),
                    _CharCount(value: _title.text.length, max: 64, surface: surface),
                    const SizedBox(height: 10),
                    _Label(text: 'DESCRIPTION', surface: surface),
                    _Field(controller: _desc, maxLength: 2000, surface: surface, maxLines: 3),
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
                              _FakeInput(text: 'Indoor › Monsteras', surface: surface, trailingIcon: Icons.expand_more),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Label(text: 'LOCATION', surface: surface),
                    _FakeInput(text: 'Timiș County · Timișoara', surface: surface, leadingIcon: Icons.place_outlined),
                    const SizedBox(height: 14),
                    _Label(text: 'PHOTOS ($selectedCount/6)', surface: surface),
                    const SizedBox(height: 8),
                    _PhotoGrid(
                      photos: _photos,
                      plant: widget.plant,
                      surface: surface,
                      onToggle: (i) => setState(() => _photos[i] = !_photos[i]),
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
                          onPressed: () => _finish('Draft saved'),
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
                          onPressed: () => _finish('Posted to plantly.ro ✓'),
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
  });
  final TextEditingController controller;
  final PlantlySurface surface;
  final int? maxLength;
  final int maxLines;
  final TextInputType? keyboardType;
  final double suffixPadding;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      keyboardType: keyboardType,
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
        child: Text(
          '$value/$max',
          style: TextStyle(fontSize: 10.5, color: surface.muted),
        ),
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
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: surface.text)),
          ),
          if (trailingIcon != null)
            Icon(trailingIcon, size: 14, color: surface.muted),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.plant,
    required this.surface,
    required this.onToggle,
  });
  final List<bool> photos;
  final MockPlant plant;
  final PlantlySurface surface;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      children: [
        for (var i = 0; i < photos.length; i++)
          GestureDetector(
            onTap: () => onToggle(i),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                    border: Border.all(
                      color: photos[i] ? surface.green : surface.border,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Opacity(
                    opacity: photos[i] ? 1 : 0.45,
                    child: PlantThumb(plant: plant, size: 80),
                  ),
                ),
                if (photos[i])
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
