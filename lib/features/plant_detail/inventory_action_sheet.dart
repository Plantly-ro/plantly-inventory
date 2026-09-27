import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart' as db;
import '../../data/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../../app/breakpoints.dart';
import '../../shared/sheet_chrome.dart';

/// Bottom sheet that closes out a plant — gift, sale, or death. Writes
/// an `inventory_transactions` row and soft-deletes the plant in the
/// same DB transaction, so the plant disappears from the grid but the
/// ledger keeps its history.
class InventoryActionSheet extends ConsumerStatefulWidget {
  const InventoryActionSheet({
    super.key,
    required this.plantRow,
    required this.type, // 'gift' | 'sale' | 'death'
  });

  final db.PlantRow plantRow;
  final String type;

  @override
  ConsumerState<InventoryActionSheet> createState() => _InventoryActionSheetState();
}

class _InventoryActionSheetState extends ConsumerState<InventoryActionSheet> {
  final _counterparty = TextEditingController();
  final _notes = TextEditingController();
  final _amount = TextEditingController();
  String _currency = 'RON';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _counterparty.dispose();
    _notes.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _isSale => widget.type == 'sale';
  bool get _isGift => widget.type == 'gift';
  bool get _isDeath => widget.type == 'death';

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(inventoryTransactionRepositoryProvider);
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final counterparty = _counterparty.text.trim().isEmpty ? null : _counterparty.text.trim();
      if (_isGift) {
        await repo.gift(plantId: widget.plantRow.id, counterparty: counterparty, notes: notes);
      } else if (_isSale) {
        final amount = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
        final minor = amount == null ? null : (amount * 100).round();
        await repo.sell(
          plantId: widget.plantRow.id,
          amountMinor: minor,
          currency: minor == null ? null : _currency,
          counterparty: counterparty,
          notes: notes,
        );
      } else if (_isDeath) {
        await repo.markDead(plantId: widget.plantRow.id, notes: notes);
      }
      if (mounted) Navigator.of(context).pop(true);
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
    final (title, hint, accent) = switch (widget.type) {
      'gift' => (t.sheetGaveAwayTitle, t.sheetGaveAwayHint, surface.green),
      'sale' => (t.sheetSoldTitle, t.sheetSoldHint, surface.terra),
      'death' => (t.sheetMarkedDeadTitle, null, surface.terra),
      _ => (widget.type, null, surface.muted),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SheetChrome(
        surface: surface,
        title: title,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        handleGap: 14,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            if (!context.isDesktop) ...[
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: surface.text)),
            const SizedBox(height: 4),
            ],
            Text(
              t.sheetInventoryRemoveBody(widget.plantRow.nickname),
              style: TextStyle(fontSize: 12, color: surface.muted),
            ),
            if (hint != null) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _counterparty,
                textCapitalization: TextCapitalization.sentences,
                decoration: _inputDecoration(surface, hint: hint),
              ),
            ],
            if (_isSale) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDecoration(surface, hint: t.sheetPriceHint),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: DropdownButtonFormField<String>(
                      initialValue: _currency,
                      decoration: _inputDecoration(surface),
                      items: const [
                        DropdownMenuItem(value: 'RON', child: Text('RON')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                      ],
                      onChanged: (v) => setState(() => _currency = v ?? 'RON'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDecoration(surface, hint: t.sheetNotesOptionalHint),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                    ),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                    child: Text(t.cancel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? t.saving : t.commonConfirm),
                  ),
                ),
              ],
            ),
          ],
      ),
    );
  }

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
