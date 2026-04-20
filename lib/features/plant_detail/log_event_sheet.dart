import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/care_types.dart';
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
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
  String _selectedType = 'water';
  final _customTypeController = TextEditingController();
  final _productController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _when = DateTime.now();
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

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      // Allow backdating up to 10 years and forward-dating up to 2
      // years — broad enough for "I forgot to log last April" and
      // "I'll do this next weekend" without showing a crazy range.
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null || !mounted) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    final type = _isCustom ? _customTypeController.text.trim().toLowerCase() : _selectedType;
    if (_isCustom && type.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).logEventEnterName);
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
            doneAt: _when.toUtc().millisecondsSinceEpoch,
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
              t.logEventTitle,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
            ),
            const SizedBox(height: 14),
            Text(t.logEventWhat, style: _labelStyle(surface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ct in types)
                  _TypeChip(
                    label: ct.pastTenseLabel,
                    icon: ct.icon,
                    selected: _selectedType == ct.key,
                    surface: surface,
                    onTap: () => setState(() => _selectedType = ct.key),
                  ),
                _TypeChip(
                  label: t.logEventOther,
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
                decoration: _inputDecoration(surface, hint: t.logEventOtherHint),
              ),
            ],
            const SizedBox(height: 14),
            Text(t.logEventWhen, style: _labelStyle(surface)),
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
                    Expanded(
                      child: Text(_fmtDate(_when), style: TextStyle(fontSize: 14, color: surface.text)),
                    ),
                    Icon(Icons.chevron_right, color: surface.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(t.logEventProduct, style: _labelStyle(surface)),
            const SizedBox(height: 8),
            TextField(
              controller: _productController,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(surface, hint: t.logEventProductHint),
            ),
            Consumer(builder: (ctx, cref, _) {
              final recent = cref.watch(recentProductsProvider).maybeWhen(
                    data: (list) => list,
                    orElse: () => const <String>[],
                  );
              if (recent.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in recent)
                      ActionChip(
                        label: Text(p, style: const TextStyle(fontSize: 11)),
                        onPressed: () => setState(() => _productController.text = p),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),
            Text(t.logEventNotes, style: _labelStyle(surface)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: _inputDecoration(surface, hint: t.logEventNotesHint),
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
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $h:$m';
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
