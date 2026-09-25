import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/care_types.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// User-editable list of care-event / reminder types. Built-ins can be
/// renamed but not deleted (their `key` is referenced by existing
/// schedules + events). Users can also add custom types that show up
/// everywhere — AddReminderSheet, LogEventSheet, QuickLog.
class CareTypesScreen extends ConsumerWidget {
  const CareTypesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final types = ref.watch(careTypesProvider);

    return Scaffold(
      backgroundColor: surface.bg,
      appBar: AppBar(
        backgroundColor: surface.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: surface.text),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          t.careTypesTitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
        actions: [
          IconButton(
            tooltip: t.careTypesReset,
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: Text(t.careTypesResetTitle),
                  content: Text(t.careTypesResetBody),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: Text(t.cancel)),
                    FilledButton(onPressed: () => Navigator.of(dctx).pop(true), child: Text(t.careTypesReset)),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(careTypesProvider.notifier).resetToBuiltIn();
              }
            },
            icon: Icon(Icons.restart_alt, color: surface.text),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: surface.green,
        foregroundColor: Colors.white,
        onPressed: () => _edit(context, ref, surface, null),
        child: const Icon(Icons.add),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
        itemCount: types.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final t = types[i];
          final muted = ref.watch(mutedCareTypesProvider).contains(t.key);
          return _Row(
            type: t,
            surface: surface,
            muted: muted,
            onToggleMute: () =>
                ref.read(mutedCareTypesProvider.notifier).setMuted(t.key, !muted),
            onEdit: () => _edit(context, ref, surface, t),
            onDelete: t.builtin ? null : () => ref.read(careTypesProvider.notifier).remove(t.key),
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    PlantlySurface surface,
    CareType? existing,
  ) async {
    final t = AppLocalizations.of(context);
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    var days = existing?.defaultIntervalDays ?? 7.0;
    var iconCode = existing?.iconCode ?? Icons.notifications_active_outlined.codePoint;
    int? colorValue = existing?.colorValue;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(color: surface.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    existing == null ? t.meCareTypeNew : t.meCareTypeEdit(existing.label),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text),
                  ),
                  const SizedBox(height: 14),
                  _label(t.meCareTypeLabelField, surface),
                  const SizedBox(height: 6),
                  TextField(
                    controller: labelCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _dec(surface, hint: t.meCareTypeLabelHint),
                  ),
                  const SizedBox(height: 12),
                  _label(t.meCareTypeIntervalField, surface),
                  const SizedBox(height: 6),
                  TextField(
                    controller: TextEditingController(text: _fmt(days))
                      ..selection = TextSelection.collapsed(offset: _fmt(days).length),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: _dec(surface),
                    onChanged: (v) {
                      final parsed = double.tryParse(v.replaceAll(',', '.'));
                      if (parsed != null && parsed > 0) days = parsed;
                    },
                  ),
                  const SizedBox(height: 12),
                  _label(t.meCareTypeIconField, surface),
                  const SizedBox(height: 6),
                  _IconPicker(
                    value: iconCode,
                    surface: surface,
                    onChanged: (code) => setLocal(() => iconCode = code),
                  ),
                  const SizedBox(height: 12),
                  _label(t.meCareTypeColourField, surface),
                  const SizedBox(height: 6),
                  _ColorPicker(
                    value: colorValue,
                    surface: surface,
                    onChanged: (v) => setLocal(() => colorValue = v),
                  ),
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
                          onPressed: () => Navigator.of(ctx).pop(),
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
                          onPressed: () async {
                            final label = labelCtrl.text.trim();
                            if (label.isEmpty) return;
                            final notifier = ref.read(careTypesProvider.notifier);
                            if (existing == null) {
                              final key = label.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
                              await notifier.add(CareType(
                                key: key,
                                label: label,
                                iconCode: iconCode,
                                defaultIntervalDays: days,
                                colorValue: colorValue,
                              ));
                            } else {
                              await notifier.update(
                                existing.key,
                                existing.copyWith(
                                  label: label,
                                  iconCode: iconCode,
                                  defaultIntervalDays: days,
                                  colorValue: colorValue,
                                  clearColor: colorValue == null,
                                ),
                              );
                            }
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          },
                          child: Text(t.commonSave),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
    labelCtrl.dispose();
  }

  String _fmt(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  Widget _label(String text, PlantlySurface s) => Text(
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

class _Row extends StatelessWidget {
  const _Row({
    required this.type,
    required this.surface,
    required this.muted,
    required this.onToggleMute,
    required this.onEdit,
    required this.onDelete,
  });
  final CareType type;
  final PlantlySurface surface;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Material(
      color: surface.surface,
      borderRadius: BorderRadius.circular(PlantlyTokens.radius),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: type.color ?? surface.greenSoft,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  type.icon,
                  size: 18,
                  color: type.color == null ? surface.green : Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(type.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text)),
                    Text(t.meCareTypeDefaultEvery(_format(type.defaultIntervalDays), type.defaultIntervalDays.round()),
                        style: TextStyle(fontSize: 11.5, color: surface.muted)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  muted ? Icons.notifications_off_outlined : Icons.notifications_outlined,
                  color: muted ? surface.terra : surface.muted,
                ),
                tooltip: muted ? t.meCareTypeUnmuteTooltip : t.meCareTypeMuteTooltip,
                onPressed: onToggleMute,
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: surface.terra),
                  onPressed: onDelete,
                  tooltip: t.commonDelete,
                ),
              Icon(Icons.chevron_right, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }

  String _format(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.value, required this.surface, required this.onChanged});
  final int value;
  final PlantlySurface surface;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final icon in kCareIconPalette)
          InkWell(
            onTap: () => onChanged(icon.codePoint),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: icon.codePoint == value ? surface.green : surface.surface,
                borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                border: Border.all(color: icon.codePoint == value ? surface.green : surface.border),
              ),
              child: Icon(
                icon,
                color: icon.codePoint == value ? Colors.white : surface.green,
                size: 18,
              ),
            ),
          ),
      ],
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.surface, required this.onChanged});
  final int? value;
  final PlantlySurface surface;
  final ValueChanged<int?> onChanged;

  static const _palette = <int>[
    0xFF3D7A5F, // botanical green
    0xFFC26A3A, // terra
    0xFF2E86AB, // deep blue
    0xFF9B5DE5, // violet
    0xFFE56B6F, // rose
    0xFFF2C14E, // mustard
    0xFF6C757D, // slate
    0xFF4F772D, // forest
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _swatch(null, t.meCareTypeColourDefault),
        for (final c in _palette) _swatch(c, null),
      ],
    );
  }

  Widget _swatch(int? v, String? label) {
    final selected = value == v;
    final color = v == null ? null : Color(v);
    return InkWell(
      onTap: () => onChanged(v),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 32,
        width: label == null ? 32 : null,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
        decoration: BoxDecoration(
          color: color ?? surface.surface,
          shape: label == null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: label == null ? null : BorderRadius.circular(999),
          border: Border.all(color: selected ? surface.green : surface.border, width: selected ? 2 : 1),
        ),
        alignment: Alignment.center,
        child: label == null
            ? (selected ? const Icon(Icons.check, color: Colors.white, size: 16) : null)
            : Text(label, style: TextStyle(fontSize: 11, color: surface.muted, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
