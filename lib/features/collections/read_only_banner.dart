import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/collections.dart';
import '../home/home_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';

/// "View only" strip shown at the top of the main screens when the active
/// collection is one the account can only read (MULTI-USER-V2 §3: a
/// `viewer` of a shared collection). Renders nothing — and takes no space —
/// whenever [canEditActiveCollectionProvider] is true, so local-only and
/// single-collection screens stay pixel-identical.
class ReadOnlyBanner extends ConsumerWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(canEditActiveCollectionProvider)) return const SizedBox.shrink();
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    return Material(
      key: const Key('read-only-banner'),
      color: surface.surfaceAlt,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: surface.border))),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 16, color: surface.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context).shareReadOnlyBanner,
                style: TextStyle(fontSize: 12, color: surface.muted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One-shot read of the edit right (for callbacks; builds should `watch`).
bool canEditNow(WidgetRef ref) => ref.read(canEditActiveCollectionProvider);

/// Guard for mutating callbacks that cannot simply be hidden: returns true
/// when the active collection is editable, otherwise shows the read-only
/// snackbar and returns false so the caller can early-return.
bool ensureCanEdit(BuildContext context, WidgetRef ref) {
  if (canEditNow(ref)) return true;
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const Key('read-only-snack'),
      content: Text(AppLocalizations.of(context).shareErrReadOnly),
    ));
  return false;
}
