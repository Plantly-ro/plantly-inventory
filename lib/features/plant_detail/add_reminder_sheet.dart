import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/care_types.dart';
import '../../data/providers.dart';
import '../../domain/services/local_calendar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/care_type_labels.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../../app/breakpoints.dart';
import '../../shared/sheet_chrome.dart';
import 'assignee_picker.dart';

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
  String? _assigneeUserId;
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
    final t = AppLocalizations.of(context);
    final count = double.tryParse(_intervalController.text.trim().replaceAll(',', '.'));
    if (count == null || count <= 0) {
      setState(() => _error = t.addReminderEnterPositive);
      return;
    }
    String typeKey;
    if (_isCustom) {
      final raw = _customTypeController.text.trim();
      if (raw.isEmpty) {
        setState(() => _error = t.addReminderNameCustom);
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
            assigneeUserId: _assigneeUserId,
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
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SheetChrome(
        surface: surface,
        title: t.addReminderTitle,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        handleGap: 14,
        crossAxisAlignment: CrossAxisAlignment.start,
        scrollable: true,
        children: [
              if (!context.isDesktop) ...[
              Text(t.addReminderTitle,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text)),
              const SizedBox(height: 14),
              ],
              _label(t.addReminderType, surface),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ct in types)
                    _TypeChip(
                      label: careTypeLabel(t, ct),
                      icon: ct.icon,
                      selected: _selectedKey == ct.key,
                      surface: surface,
                      onTap: () {
                        setState(() {
                          _selectedKey = ct.key;
                          final conv = _fromDays(ct.defaultIntervalDays);
                          _unit = conv.unit;
                          _intervalController.text = _format(conv.count);
                        });
                      },
                    ),
                  _TypeChip(
                    label: t.addReminderCustom,
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
                  decoration: _dec(surface, hint: t.addReminderCustomHint),
                ),
              ],
              const SizedBox(height: 14),
              _label(t.addReminderPresets, surface),
              const SizedBox(height: 8),
              _Presets(
                surface: surface,
                onApply: (count, unit, mode, anchor) {
                  setState(() {
                    _intervalController.text = _format(count);
                    _unit = unit;
                    _recurrenceMode = mode;
                    if (anchor != null) _firstDue = anchor;
                  });
                },
              ),
              const SizedBox(height: 14),
              _label(t.addReminderEvery, surface),
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
                      segments: [
                        ButtonSegment(value: _Unit.minutes, label: Text(t.addReminderUnitMin)),
                        ButtonSegment(value: _Unit.hours, label: Text(t.addReminderUnitHr)),
                        ButtonSegment(value: _Unit.days, label: Text(t.addReminderUnitDay)),
                        ButtonSegment(value: _Unit.months, label: Text(t.addReminderUnitMo)),
                      ],
                      selected: {_unit},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => setState(() => _unit = s.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label(t.addReminderRepeat, surface),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ModeChip(
                    label: t.addReminderRepeatOnDone,
                    icon: Icons.refresh,
                    selected: _recurrenceMode == 'after_completion',
                    surface: surface,
                    onTap: () => setState(() => _recurrenceMode = 'after_completion'),
                  ),
                  _ModeChip(
                    label: t.addReminderRepeatFixed,
                    icon: Icons.event_repeat_outlined,
                    selected: _recurrenceMode == 'fixed',
                    surface: surface,
                    onTap: () => setState(() => _recurrenceMode = 'fixed'),
                  ),
                  _ModeChip(
                    label: t.addReminderRepeatOnce,
                    icon: Icons.event_available_outlined,
                    selected: _recurrenceMode == 'once',
                    surface: surface,
                    onTap: () => setState(() => _recurrenceMode = 'once'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label(t.addReminderFirstDue, surface),
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
              if (ref.watch(assigneePickerVisibleProvider)) ...[
                const SizedBox(height: 14),
                AssigneePicker(
                  value: _assigneeUserId,
                  surface: surface,
                  onChanged: (v) => setState(() => _assigneeUserId = v),
                ),
              ],
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                        ),
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

  /// "Sep 26, 2026 · 12:22" / "26 sept. 2026 · 12:22".
  String _formatWhen(DateTime d) {
    final locale = Localizations.localeOf(context).toString();
    return '${DateFormat.yMMMd(locale).format(d)} · ${DateFormat.Hm(locale).format(d)}';
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
    final t = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final intervalDays = unit.toDays(count);
    const calendar = LocalCalendar();
    final firings = <DateTime>[];
    var at = firstDue;
    final limit = mode == 'once' ? 1 : 3;
    for (var i = 0; i < limit; i++) {
      firings.add(at);
      if (mode == 'once') break;
      // Same stepping as the real schedule (wall-clock time across DST).
      at = DateTime.fromMillisecondsSinceEpoch(
        calendar.addDays(at.millisecondsSinceEpoch, intervalDays),
        isUtc: at.isUtc,
      );
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
            mode == 'once' ? t.addReminderFiresOnce : t.addReminderNextReminders(firings.length),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: surface.green, letterSpacing: 1.1),
          ),
          const SizedBox(height: 4),
          for (final d in firings)
            Text(
              _formatFull(d, locale),
              style: TextStyle(fontSize: 12, color: surface.text),
            ),
        ],
      ),
    );
  }

  /// "Sat, Sep 26 · 12:22" / "sâm., 26 sept. · 12:22".
  String _formatFull(DateTime d, String locale) =>
      '${DateFormat.MMMEd(locale).format(d)} · ${DateFormat.Hm(locale).format(d)}';
}

class _Presets extends StatelessWidget {
  const _Presets({required this.surface, required this.onApply});

  final PlantlySurface surface;
  final void Function(double count, _Unit unit, String mode, DateTime? anchor) onApply;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    DateTime nextWeekday(int targetWeekday, {int hour = 9}) {
      final now = DateTime.now();
      var d = DateTime(now.year, now.month, now.day, hour);
      while (d.weekday != targetWeekday || !d.isAfter(now)) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }

    final presets = <({String label, IconData icon, void Function() apply})>[
      (
        label: t.addReminderPresetDaily,
        icon: Icons.sunny,
        apply: () => onApply(1, _Unit.days, 'after_completion', null),
      ),
      (
        label: t.addReminderPresetEveryOtherDay,
        icon: Icons.today,
        apply: () => onApply(2, _Unit.days, 'after_completion', null),
      ),
      (
        label: t.addReminderPresetWeekly,
        icon: Icons.view_week_outlined,
        apply: () => onApply(7, _Unit.days, 'after_completion', null),
      ),
      (
        label: t.addReminderPresetMondays,
        icon: Icons.calendar_month,
        apply: () => onApply(7, _Unit.days, 'fixed', nextWeekday(DateTime.monday)),
      ),
      (
        label: t.addReminderPresetBiweekly,
        icon: Icons.date_range_outlined,
        apply: () => onApply(14, _Unit.days, 'after_completion', null),
      ),
      (
        label: t.addReminderPresetMonthly,
        icon: Icons.calendar_view_month,
        apply: () => onApply(1, _Unit.months, 'after_completion', null),
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in presets)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _PresetChip(
                label: p.label,
                icon: p.icon,
                surface: surface,
                onTap: p.apply,
              ),
            ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.icon,
    required this.surface,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: surface.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: surface.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: surface.muted),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(fontSize: 11, color: surface.text, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
