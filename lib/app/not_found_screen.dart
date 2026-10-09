import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/home_providers.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'navigation.dart';

/// The router's `errorBuilder`: an address that matches no route (typo,
/// stale bookmark) — a styled, localized page with a way Home instead of
/// go_router's raw `GoException` text.
class NotFoundScreen extends ConsumerWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final surface = ref.watch(themeModeProvider) == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    return Scaffold(
      key: const Key('not-found'),
      backgroundColor: surface.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(PlantlyTokens.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
                    child: Icon(Icons.eco_outlined, size: 30, color: surface.green),
                  ),
                  const SizedBox(height: PlantlyTokens.space4),
                  Semantics(
                    header: true,
                    child: Text(
                      t.notFoundTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PlantlyFonts.plusJakartaSans,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: surface.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: PlantlyTokens.space2),
                  Text(
                    t.notFoundBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: surface.muted, height: 1.4),
                  ),
                  const SizedBox(height: PlantlyTokens.space5),
                  FilledButton.icon(
                    key: const Key('not-found-home'),
                    style: FilledButton.styleFrom(backgroundColor: surface.green, foregroundColor: Colors.white),
                    onPressed: () => context.go(AppRoutes.home),
                    icon: const Icon(Icons.home_outlined, size: 18),
                    label: Text(t.notFoundHome),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
