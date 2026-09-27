import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'cloud_section.dart';

/// Me → Cloud, full page (`/me/cloud`): the same rows as the section plus
/// plan, collection and last-error detail.
class CloudScreen extends ConsumerWidget {
  const CloudScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
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
          t.cloudScreenTitle,
          style: TextStyle(
            fontFamily: PlantlyFonts.plusJakartaSans,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: surface.text,
            letterSpacing: -0.02 * 22,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            t.cloudScreenIntro,
            key: const Key('cloud-screen-intro'),
            style: TextStyle(fontSize: 13, height: 1.4, color: surface.muted),
          ),
          const SizedBox(height: 16),
          CloudRows(surface: surface, detailed: true),
        ],
      ),
    );
  }
}
