import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/care_types.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/care_type_labels.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../../app/breakpoints.dart';
import '../../shared/sheet_chrome.dart';
import 'assignee_picker.dart';

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
        return count * 30;
    }
  }
}

({_Unit unit, double count}) _fromDays(double days) {
  if (days >= 30) return (unit: _Unit.months, count: days / 30);
  if (days >= 1) return (unit: _Unit.days, count: days);
  if (days * 24 >= 1) return (unit: _Unit.hours, count: days * 24);
  return (unit: _Unit.minutes, count: days * 24 * 60);
}

/// In-place edit for an existing reminder. Shown via long-press on a
/// Plant Detail Upcoming Care row. Mirrors AddReminderSheet's layout
/// but omits the "type" field — changing a schedule's type is a
/// destructive rename so we ask users to delete + re-add instead.
class EditReminderSheet extends ConsumerStatefulWidget {
  const EditReminderSheet({super.key, required this.schedule});
  final CareScheduleRow schedule;

  @override
  ConsumerState<EditReminderSheet> createState() => _EditReminderSheetState();
}

class _EditReminderSheetState extends ConsumerState<EditReminderSheet> {
  late final TextEditingController _interval;
  late _Unit _unit;
  late String _recurrenceMode;
  late DateTime _firstDue;
  String? _assigneeUserId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final conv = _fromDays(widget.schedule.baseIntervalDays);
    _unit = conv.unit;
    _interval = TextEditingController(text: _format(conv.count));
    _recurrenceMode = widget.schedule.recurrenceMode;
    _assigneeUserId = widget.schedule.assigneeUserId;
    _firstDue = widget.schedule.nextDueAt != null
        ? DateTime.fromMillisecondsSinceEpoch(widget.schedule.nextDueAt!, isUtc: true).toLocal()
        : DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  Future<void> _save() async {
    final count = double.tryParse(_interval.text.trim().replaceAll(',', '.'));
    if (count == null || count <= 0) {
      setState(() => _error = AppLocalizations.of(context).addReminderEnterPositive);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(careScheduleRepositoryProvider).edit(
            widget.schedule.id,
            baseIntervalDays: _unit.toDays(count),
            recurrenceMode: _recurrenceMode,
            nextDueAt: _firstDue.toUtc(),
            assigneeUserId: Value(_assigneeUserId),
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

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(t.editReminderDeleteTitle),
        content: Text(t.editReminderDeleteBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(t.cancel)),
          TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(t.commonDelete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(careScheduleRepositoryProvider).softDelete(widget.schedule.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _pickFirstDue() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
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

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);
    final ct = resolveCareType(types, widget.schedule.type);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SheetChrome(
        surface: surface,
        title: t.editReminderTitle(careTypeLabel(t, ct).toLowerCase()),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        handleGap: 14,
        crossAxisAlignment: CrossAxisAlignment.start,
        scrollable: true,
        children: [
              if (!context.isDesktop) ...[
              Row(
                children: [
                  Icon(ct.icon, color: surface.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.editReminderTitle(careTypeLabel(t, ct).toLowerCase()),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ],
              _label(t.addReminderEvery, surface),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _interval,
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
                  _mode(t.addReminderRepeatOnDone, Icons.refresh, 'after_completion', surface),
                  _mode(t.addReminderRepeatFixed, Icons.event_repeat_outlined, 'fixed', surface),
                  _mode(t.addReminderRepeatOnce, Icons.event_available_outlined, 'once', surface),
                ],
              ),
              const SizedBox(height: 14),
              _label(t.editReminderNextDue, surface),
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
                      Expanded(child: Text(_formatWhen(_firstDue), style: TextStyle(fontSize: 14, color: surface.text))),
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
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: surface.terra, fontSize: 12)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: surface.terra),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(t.commonDelete),
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: surface.surfaceAlt,
                      foregroundColor: surface.muted,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                    ),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: Text(t.cancel),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: surface.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? t.saving : t.commonSave),
                  ),
                ],
              ),
            ],
      ),
    );
  }

  Widget _mode(String label, IconData icon, String value, PlantlySurface s) {
    final selected = _recurrenceMode == value;
    return InkWell(
      onTap: () => setState(() => _recurrenceMode = value),
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? s.greenSoft : s.surface,
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          border: Border.all(color: selected ? s.green : s.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? s.green : s.muted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? s.green : s.text,
                )),
          ],
        ),
      ),
    );
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

  InputDecoration _dec(PlantlySurface s) => InputDecoration(
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
