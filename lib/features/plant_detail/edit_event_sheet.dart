import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/care_types.dart';
import '../../data/database/app_database.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/care_type_labels.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Edit an existing `care_events` row — type, when, product, dose, notes.
class EditEventSheet extends ConsumerStatefulWidget {
  const EditEventSheet({super.key, required this.event});
  final CareEventRow event;

  @override
  ConsumerState<EditEventSheet> createState() => _EditEventSheetState();
}

class _EditEventSheetState extends ConsumerState<EditEventSheet> {
  late String _selectedType;
  late final TextEditingController _product;
  late final TextEditingController _dose;
  late final TextEditingController _notes;
  late DateTime _doneAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.event.type;
    _product = TextEditingController(text: widget.event.product ?? '');
    _dose = TextEditingController(text: widget.event.dose ?? '');
    _notes = TextEditingController(text: widget.event.notes ?? '');
    _doneAt = DateTime.fromMillisecondsSinceEpoch(widget.event.doneAt, isUtc: true).toLocal();
  }

  @override
  void dispose() {
    _product.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(careEventRepositoryProvider).edit(
            widget.event.id,
            type: _selectedType,
            doneAt: _doneAt.toUtc().millisecondsSinceEpoch,
            product: _product.text.trim().isEmpty ? null : _product.text.trim(),
            dose: _dose.text.trim().isEmpty ? null : _dose.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
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

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _doneAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_doneAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _doneAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
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
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text(t.editEventTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text)),
              const SizedBox(height: 14),
              Text(t.logEventWhat, style: _label(surface)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final ct in types)
                    _Chip(
                      label: careTypePastLabel(t, ct),
                      icon: ct.icon,
                      selected: _selectedType == ct.key,
                      surface: surface,
                      onTap: () => setState(() => _selectedType = ct.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(t.logEventWhen, style: _label(surface)),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickWhen,
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
                      Expanded(child: Text(_fmtDate(_doneAt), style: TextStyle(fontSize: 14, color: surface.text))),
                      Icon(Icons.chevron_right, color: surface.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(t.logEventProduct, style: _label(surface)),
              const SizedBox(height: 8),
              TextField(controller: _product, decoration: _dec(surface, hint: t.logEventProductHint)),
              const SizedBox(height: 12),
              Text(t.editEventDose, style: _label(surface)),
              const SizedBox(height: 8),
              TextField(controller: _dose, decoration: _dec(surface, hint: t.editEventDoseHint)),
              const SizedBox(height: 12),
              Text(t.logEventNotes, style: _label(surface)),
              const SizedBox(height: 8),
              TextField(controller: _notes, maxLines: 2, decoration: _dec(surface)),
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
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m';
  }

  TextStyle _label(PlantlySurface s) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: s.muted,
        letterSpacing: 1.1,
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

class _Chip extends StatelessWidget {
  const _Chip({
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
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : surface.text,
                )),
          ],
        ),
      ),
    );
  }
}
