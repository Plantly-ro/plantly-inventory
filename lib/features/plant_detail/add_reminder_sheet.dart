import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/care_types.dart';
import '../../data/providers.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Bottom sheet to create a new CareSchedule for a plant. Reads the
/// available types from the user-editable registry in `careTypesProvider`
/// (defaults + any custom ones the user added under Me → Care types).
///
/// Picks:
///   - Type (chip row + free-form "Custom" that auto-creates a type)
///   - Interval count + unit (min / hr / day / mo)
///   - Recurrence mode (after completion / fixed date / once)
///   - First due date + time
class AddReminderSheet extends ConsumerStatefulWidget {
  const AddReminderSheet({super.key, required this.plantId});
  final String plantId;

  @override
  ConsumerState<AddReminderSheet> createState() => _AddReminderSheetState();
}

enum _Unit { minutes, hours, days, months }

extension on _Unit {
  double toDays(double count) {
    switch (this) {
      case _Unit.minutes:
        return count / (24 * 60);
      case _Unit.hours:
        return count / 24;
      case _Unit.days:
        return count;
      case _Unit.months:
        return count * 30; // approximate — fine for care reminders
    }
  }
}

/// Best-effort reverse conversion — used to prefill the unit when we
/// prime the form from a care type's `defaultIntervalDays`.
({_Unit unit, double count}) _fromDays(double days) {
  if (days >= 30) return (unit: _Unit.months, count: days / 30);
  if (days >= 1) return (unit: _Unit.days, count: days);
  if (days * 24 >= 1) return (unit: _Unit.hours, count: days * 24);
  return (unit: _Unit.minutes, count: days * 24 * 60);
}

class _AddReminderSheetState extends ConsumerState<AddReminderSheet> {
  String _selectedKey = '';
  final _customTypeController = TextEditingController();
  final _intervalController = TextEditingController();
  _Unit _unit = _Unit.days;
  String _recurrenceMode = 'after_completion';
  DateTime _firstDue = DateTime.now().add(const Duration(days: 1));
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Start the form on the first built-in type ("water").
    _selectedKey = kBuiltInCareTypes.first.key;
    final (:unit, :count) = _fromDays(kBuiltInCareTypes.first.defaultIntervalDays);
    _unit = unit;
    _intervalController.text = _format(count);
  }

  @override
  void dispose() {
    _customTypeController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  bool get _isCustom => _selectedKey == '__custom__';

  String _format(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Future<void> _save() async {
    final count = double.tryParse(_intervalController.text.trim().replaceAll(',', '.'));
    if (count == null || count <= 0) {
      setState(() => _error = 'Enter a positive number');
      return;
    }
    String typeKey;
    if (_isCustom) {
      final raw = _customTypeController.text.trim();
      if (raw.isEmpty) {
        setState(() => _error = 'Name the custom reminder');
        return;
      }
      typeKey = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      // Register it so it shows up in future pickers too.
      await ref.read(careTypesProvider.notifier).add(
            CareType(
              key: typeKey,
              label: raw,
              iconCode: Icons.notifications_active_outlined.codePoint,
              defaultIntervalDays: _unit.toDays(count),
            ),
          );
    } else {
      typeKey = _selectedKey;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(careScheduleRepositoryProvider).upsert(
            plantId: widget.plantId,
            type: typeKey,
            baseIntervalDays: _unit.toDays(count),
            firstDueAt: _firstDue.toUtc(),
            recurrenceMode: _recurrenceMode,
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
    final types = ref.watch(careTypesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: surface.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(PlantlyTokens.radius2xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: SingleChildScrollView(
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
              Text('Add reminder',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text)),
              const SizedBox(height: 14),
              _label('TYPE', surface),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in types)
                    _TypeChip(
                      label: t.label,
                      icon: t.icon,
                      selected: _selectedKey == t.key,
                      surface: surface,
                      onTap: () {
                        setState(() {
                          _selectedKey = t.key;
                          final conv = _fromDays(t.defaultIntervalDays);
                          _unit = conv.unit;
                          _intervalController.text = _format(conv.count);
                        });
                      },
                    ),
                  _TypeChip(
                    label: 'Custom',
                    icon: Icons.edit_outlined,
                    selected: _isCustom,
                    surface: surface,
                    onTap: () => setState(() => _selectedKey = '__custom__'),
                  ),
                ],
              ),
              if (_isCustom) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _customTypeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _dec(surface, hint: 'e.g. neem spray'),
                ),
              ],
              const SizedBox(height: 14),
              _label('EVERY', surface),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _intervalController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _dec(surface),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SegmentedButton<_Unit>(
                      segments: const [
                        ButtonSegment(value: _Unit.minutes, label: Text('min')),
                        ButtonSegment(value: _Unit.hours, label: Text('hr')),
                        ButtonSegment(value: _Unit.days, label: Text('day')),
                        ButtonSegment(value: _Unit.months, label: Text('mo')),
                      ],
                      selected: {_unit},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _unit = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label('REPEAT', surface),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ModeChip(
                    label: 'After I mark it done',
                    icon: Icons.refresh,
                    selected: _recurrenceMode == 'after_completion',
                    surface: surface,
                    onTap: () => setState(() => _recurrenceMode = 'after_completion'),
                  ),
                  _ModeChip(
                    label: 'On a fixed schedule',
                    icon: Icons.event_repeat_outlined,
                    selected: _recurrenceMode == 'fixed',
                    surface: surface,
                    onTap: () => setState(() => _recurrenceMode = 'fixed'),
                  ),
                  _ModeChip(
                    label: 'Just once',
                    icon: Icons.event_available_outlined,
                    selected: _recurrenceMode == 'once',
                    surface: surface,
                    onTap: () => setState(() => _recurrenceMode = 'once'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label('FIRST DUE', surface),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickFirstDue,
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
                      Icon(Icons.event_outlined, size: 16, color: surface.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatWhen(_firstDue),
                          style: TextStyle(fontSize: 14, color: surface.text),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: surface.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _Preview(
                unit: _unit,
                intervalText: _intervalController.text,
                mode: _recurrenceMode,
                firstDue: _firstDue,
                surface: surface,
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
      ),
    );
  }

  Future<void> _pickFirstDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_firstDue),
    );
    if (time == null || !mounted) return;
    setState(() {
      _firstDue = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatWhen(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m';
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

class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? surface.greenSoft : surface.surface,
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          border: Border.all(color: selected ? surface.green : surface.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? surface.green : surface.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? surface.green : surface.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.unit,
    required this.intervalText,
    required this.mode,
    required this.firstDue,
    required this.surface,
  });

  final _Unit unit;
  final String intervalText;
  final String mode;
  final DateTime firstDue;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final count = double.tryParse(intervalText.replaceAll(',', '.'));
    if (count == null || count <= 0) return const SizedBox.shrink();
    final intervalMs = (unit.toDays(count) * 86400 * 1000).round();
    final firings = <DateTime>[];
    var at = firstDue;
    final limit = mode == 'once' ? 1 : 3;
    for (var i = 0; i < limit; i++) {
      firings.add(at);
      if (mode == 'once') break;
      at = at.add(Duration(milliseconds: intervalMs));
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surface.greenSoft,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        border: Border.all(color: surface.green.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            mode == 'once' ? 'FIRES ONCE' : 'NEXT ${firings.length} REMINDERS',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: surface.green, letterSpacing: 1.1),
          ),
          const SizedBox(height: 4),
          for (final d in firings)
            Text(
              _formatFull(d),
              style: TextStyle(fontSize: 12, color: surface.text),
            ),
        ],
      ),
    );
  }

  String _formatFull(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final wd = weekdays[d.weekday - DateTime.monday];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$wd, ${months[d.month - 1]} ${d.day} · $h:$m';
  }
}
