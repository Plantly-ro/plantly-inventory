import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Bottom sheet to create a new CareSchedule for a plant. Covers the fixed
/// care types (water / fertilize / mist / repot / prune / rotate) plus a
/// free-form "custom" label so users can track anything else (humidity
/// check, spider-mite treatment, rotating stakes, …).
class AddReminderSheet extends ConsumerStatefulWidget {
  const AddReminderSheet({super.key, required this.plantId});
  final String plantId;

  @override
  ConsumerState<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<AddReminderSheet> {
  static const _presets = <({String type, String label, IconData icon, double defaultDays})>[
    (type: 'water', label: 'Water', icon: Icons.water_drop_outlined, defaultDays: 7),
    (type: 'fertilize', label: 'Fertilize', icon: Icons.eco_outlined, defaultDays: 30),
    (type: 'mist', label: 'Mist', icon: Icons.bubble_chart_outlined, defaultDays: 3),
    (type: 'repot', label: 'Repot', icon: Icons.local_florist_outlined, defaultDays: 365),
    (type: 'prune', label: 'Prune', icon: Icons.content_cut_outlined, defaultDays: 90),
    (type: 'rotate', label: 'Rotate', icon: Icons.light_mode_outlined, defaultDays: 14),
  ];

  String _selectedType = 'water';
  final _customTypeController = TextEditingController();
  final _intervalController = TextEditingController(text: '7');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _customTypeController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  bool get _isCustom => _selectedType == '__custom__';

  Future<void> _save() async {
    final interval = double.tryParse(_intervalController.text.trim());
    if (interval == null || interval <= 0) {
      setState(() => _error = 'Enter a positive number of days');
      return;
    }
    final type = _isCustom ? _customTypeController.text.trim().toLowerCase() : _selectedType;
    if (_isCustom && type.isEmpty) {
      setState(() => _error = 'Enter a name for the custom reminder');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(careScheduleRepositoryProvider).upsert(
            plantId: widget.plantId,
            type: type,
            baseIntervalDays: interval,
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
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
              'Add reminder',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
            ),
            const SizedBox(height: 14),
            Text('TYPE', style: _labelStyle(surface)),
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
                    onTap: () {
                      setState(() {
                        _selectedType = p.type;
                        _intervalController.text = p.defaultDays.toStringAsFixed(0);
                      });
                    },
                  ),
                _TypeChip(
                  label: 'Custom',
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
                decoration: _inputDecoration(surface, hint: 'e.g. neem spray'),
              ),
            ],
            const SizedBox(height: 14),
            Text('EVERY', style: _labelStyle(surface)),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _intervalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _inputDecoration(surface),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                Text('day(s)', style: TextStyle(color: surface.muted)),
              ],
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
