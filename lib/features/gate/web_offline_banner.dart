import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/web_access.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';

/// Web only (WEB-ACCESS-POLICY §0 offline rule): while the app runs on a
/// cached entitlement because plantly.ro is unreachable, a slim strip above
/// the shell says so. Local edits keep working and sync once the server is
/// back; nothing else changes. Renders nothing in every other state.
class WebOfflineBanner extends ConsumerWidget {
  const WebOfflineBanner({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(webAccessProvider);
    if (access is! WebAccessOpen || !access.offline) return child;
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    return Column(
      children: [
        // Announced by assistive tech when it appears: connectivity changed
        // under the user, nothing they did triggered it.
        Semantics(
          liveRegion: true,
          child: Material(
            key: const Key('web-offline-banner'),
            color: surface.terraSoft,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_outlined, size: 16, color: surface.terra),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.gateOfflineBanner,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: surface.text),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
