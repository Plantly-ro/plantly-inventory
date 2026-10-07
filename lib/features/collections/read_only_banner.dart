import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/navigation.dart' show openMeSection;
import '../../cloud/collections.dart';
import '../../data/providers.dart' show currentTenantIdProvider;
import '../home/home_providers.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';

/// Copy for a read-only collection, by reason (MULTI-USER-V2 §0/§8).
String readOnlyCopy(AppLocalizations t, ReadOnlyReason reason) => switch (reason) {
      ReadOnlyReason.cloudRequired => t.shareReadOnlyCloudBanner,
      _ => t.shareReadOnlyBanner,
    };

/// "View only" strip shown at the top of the main screens when the active
/// collection is one the account can only read (MULTI-USER-V2 §3: a
/// `viewer` of a shared collection; §8: any shared collection while the
/// caller's own Inventory Cloud plan is not active). Renders nothing — and
/// takes no space — whenever [canEditActiveCollectionProvider] is true, so
/// local-only and single-collection screens stay pixel-identical.
class ReadOnlyBanner extends ConsumerWidget {
  const ReadOnlyBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The linked home was lost (removed / deleted after a transfer) while
    // its local rows are on screen: editable, but nothing syncs — say so,
    // tap → Me → Cloud for the way out.
    final loss = ref.watch(homeLossProvider);
    if (loss != null && ref.watch(currentTenantIdProvider) == loss.collectionId) {
      return const _HomeLostStrip();
    }
    // Visibility follows the edit right; the reason only picks the copy
    // (so a plain `canEdit` override — tests, call sites — still works).
    if (ref.watch(canEditActiveCollectionProvider)) return const SizedBox.shrink();
    final reason = ref.watch(activeCollectionReadOnlyReasonProvider);
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final cloud = reason == ReadOnlyReason.cloudRequired;
    return Material(
      key: const Key('read-only-banner'),
      color: surface.surfaceAlt,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: surface.border))),
        child: Row(
          children: [
            Icon(
              cloud ? Icons.workspace_premium_outlined : Icons.lock_outline,
              size: 16,
              color: cloud ? surface.terra : surface.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                readOnlyCopy(AppLocalizations.of(context), reason),
                key: Key(cloud ? 'read-only-banner-cloud' : 'read-only-banner-viewer'),
                style: TextStyle(fontSize: 12, color: surface.muted, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeLostStrip extends ConsumerWidget {
  const _HomeLostStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    return Material(
      key: const Key('home-lost-banner'),
      color: surface.surfaceAlt,
      child: InkWell(
        onTap: () => openMeSection(context, 'cloud'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: surface.border))),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, size: 16, color: surface.terra),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).cloudHomeLostBanner,
                  style: TextStyle(fontSize: 12, color: surface.muted, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: surface.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// One-shot read of the edit right (for callbacks; builds should `watch`).
bool canEditNow(WidgetRef ref) => ref.read(canEditActiveCollectionProvider);

/// Guard for mutating callbacks that cannot simply be hidden: returns true
/// when the active collection is editable, otherwise shows the read-only
/// snackbar (copy by reason) and returns false so the caller can early-return.
bool ensureCanEdit(BuildContext context, WidgetRef ref) {
  if (canEditNow(ref)) return true;
  final reason = ref.read(activeCollectionReadOnlyReasonProvider);
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const Key('read-only-snack'),
      content: Text(reason == ReadOnlyReason.cloudRequired ? t.shareErrMemberLapsed : t.shareErrReadOnly),
    ));
  return false;
}
