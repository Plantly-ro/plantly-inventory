import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Bottom sheet to record a past care event (CareEventRepository.record).
/// Users pick a type — or type a free-form one — and optionally attach a
/// product (e.g. "neem oil") or a free-form note. Example row this fills in:
/// "Misted — Fern spray" → type=mist, product="Fern spray".
class LogEventSheet extends ConsumerStatefulWidget {
  const LogEventSheet({super.key, required this.plantId});
  final String plantId;

  @override
  ConsumerState<LogEventSheet> createState() => _LogEventSheetState();
}

class _LogEventSheetState extends ConsumerState<LogEventSheet> {
  static const _presets = <({String type, String label, IconData icon})>[
    (type: 'water', label: 'Watered', icon: Icons.water_drop_outlined),
    (type: 'fertilize', label: 'Fertilized', icon: Icons.eco_outlined),
    (type: 'mist', label: 'Misted', icon: Icons.bubble_chart_outlined),
    (type: 'repot', label: 'Repotted', icon: Icons.local_florist_outlined),
    (type: 'prune', label: 'Pruned', icon: Icons.content_cut_outlined),
    (type: 'rotate', label: 'Rotated', icon: Icons.light_mode_outlined),
  ];

  String _selectedType = 'water';
  final _customTypeController = TextEditingController();
  final _productController = TextEditingController();
  final _notesController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _customTypeController.dispose();
    _productController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isCustom => _selectedType == '__custom__';

  Future<void> _save() async {
    final type = _isCustom ? _customTypeController.text.trim().toLowerCase() : _selectedType;
    if (_isCustom && type.isEmpty) {
      setState(() => _error = 'Enter a name for the event');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final product = _productController.text.trim();
      final notes = _notesController.text.trim();
      await ref.read(careEventRepositoryProvider).record(
            plantId: widget.plantId,
            type: type,
            product: product.isEmpty ? null : product,
            notes: notes.isEmpty ? null : notes,
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
                decoration: BoxDecoration(
                  color: surface.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Log event',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
            ),
            const SizedBox(height: 14),
            Text('WHAT', style: _labelStyle(surface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _presets)
                  _TypeChip(
                    label: p.label,
                    icon: p.icon,
                    selected: _selectedType == p.type,
                    surface: surface,
                    onTap: () => setState(() => _selectedType = p.type),
                  ),
                _TypeChip(
                  label: 'Other',
                  icon: Icons.edit_outlined,
                  selected: _isCustom,
                  surface: surface,
                  onTap: () => setState(() => _selectedType = '__custom__'),
                ),
              ],
            ),
            if (_isCustom) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customTypeController,
                textCapitalization: TextCapitalization.none,
                decoration: _inputDecoration(surface, hint: 'e.g. spider-mite treatment'),
              ),
            ],
            const SizedBox(height: 14),
            Text('PRODUCT (OPTIONAL)', style: _labelStyle(surface)),
            const SizedBox(height: 8),
            TextField(
              controller: _productController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(surface, hint: 'e.g. Fern spray'),
            ),
            const SizedBox(height: 14),
            Text('NOTES (OPTIONAL)', style: _labelStyle(surface)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: _inputDecoration(surface, hint: 'e.g. new leaf unfurling'),
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

  TextStyle _labelStyle(PlantlySurface s) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: s.muted,
        letterSpacing: 1.1,
      );

  InputDecoration _inputDecoration(PlantlySurface s, {String? hint}) => InputDecoration(
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.surface,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? surface.green : surface.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? surface.green : surface.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : surface.green),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : surface.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
