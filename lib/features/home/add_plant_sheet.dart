import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/providers.dart';
import '../../theme/tokens.dart';
import 'home_providers.dart';

/// Minimal "add a plant" sheet — nickname is the only required field.
/// Further fields (species, location, source, notes, pot size) get added
/// as those features ship in subsequent Phase 1 PRs.
class AddPlantSheet extends ConsumerStatefulWidget {
  const AddPlantSheet({super.key});

  @override
  ConsumerState<AddPlantSheet> createState() => _AddPlantSheetState();
}

class _AddPlantSheetState extends ConsumerState<AddPlantSheet> {
  final _nickname = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nickname.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final repo = ref.watch(plantRepositoryProvider);

    Future<void> submit() async {
      final name = _nickname.text.trim();
      if (name.isEmpty) return;
      // Capture the Navigator before the await so the analyzer's
      // use_build_context_synchronously lint is satisfied.
      final navigator = Navigator.of(context);
      setState(() => _saving = true);
      try {
        await repo.create(
          nickname: name,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
        if (!mounted) return;
        navigator.maybePop();
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: surface.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: surface.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Add a plant',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                  letterSpacing: -0.02 * 22,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'NICKNAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: surface.muted,
                  letterSpacing: 0.08 * 11,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nickname,
                autofocus: true,
                maxLength: 64,
                decoration: const InputDecoration(
                  hintText: 'e.g. Monstera Bob',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'NOTES',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: surface.muted,
                  letterSpacing: 0.08 * 11,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'optional',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: surface.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2),
                  ),
                ),
                onPressed: _saving ? null : submit,
                child: Text(_saving ? 'Saving…' : 'Add plant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
