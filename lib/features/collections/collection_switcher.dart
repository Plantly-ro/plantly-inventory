import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/side_sheet.dart';
import '../../cloud/cloud_sync.dart';
import '../../cloud/collections.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../shared/sheet_chrome.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import 'collection_ui.dart';
import 'join_collection_sheet.dart';

/// Collection switcher surfaces (CLOUD-SYNC-CONTRACT §3). Every widget here
/// renders `SizedBox.shrink()` unless `collectionSwitcherVisibleProvider`
/// (feature on + more than one collection), so single-collection screens —
/// and their goldens — are untouched.

/// Switch + confirm; surfaces the guard as a snackbar.
Future<void> switchCollectionFromUi(BuildContext context, WidgetRef ref, CloudCollection target) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final collections = ref.read(collectionsProvider.notifier);
  final runner = ref.read(syncRunnerProvider);
  try {
    await collections.switchCollection(target.id);
  } on CollectionSwitchError {
    messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t.shareSwitchUnavailable)));
    return;
  }
  messenger
    ?..clearSnackBars()
    ..showSnackBar(
      SnackBar(content: Text(t.shareSwitched(target.displayName)), duration: const Duration(milliseconds: 1800)),
    );
  // The rebuilt runner's first cycle usually wins; this just joins it.
  await runner.syncNow();
}

/// Phone: a compact chip in the Home top bar showing the active collection
/// name; tap → [showCollectionSwitcherSheet].
class CollectionSwitcherChip extends ConsumerWidget {
  const CollectionSwitcherChip({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(collectionSwitcherVisibleProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final active = ref.watch(activeCollectionProvider);
    final name = active?.displayName ?? t.shareSwitcherTitle;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: t.shareSwitcherTooltip,
        child: Material(
          key: const Key('collection-switcher-chip'),
          color: surface.greenSoft,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showCollectionSwitcherSheet(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    active != null && !active.isOwner ? Icons.group_outlined : Icons.folder_outlined,
                    size: 14,
                    color: surface.green,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: surface.green),
                    ),
                  ),
                  Icon(Icons.expand_more, size: 16, color: surface.green),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop: the active collection's name as an inline label (Home title
/// area) — shown only with more than one collection.
class ActiveCollectionLabel extends ConsumerWidget {
  const ActiveCollectionLabel({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(collectionSwitcherVisibleProvider)) return const SizedBox.shrink();
    final active = ref.watch(activeCollectionProvider);
    if (active == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: PlantlyTokens.space3),
      child: Row(
        key: const Key('active-collection-label'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active.isOwner ? Icons.folder_outlined : Icons.group_outlined, size: 16, color: surface.muted),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              active.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: surface.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop side nav: a dropdown under the logo listing every collection
/// (role in the subtitle) plus "Join with code…".
class CollectionSwitcherDropdown extends ConsumerWidget {
  const CollectionSwitcherDropdown({super.key, required this.surface});
  final PlantlySurface surface;

  static const String _joinValue = '__join__';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(collectionSwitcherVisibleProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final items = ref.watch(collectionsProvider.select((s) => s.items));
    final active = ref.watch(activeCollectionProvider);
    final value = items.any((c) => c.id == active?.id) ? active!.id : null;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        key: const Key('collection-switcher-dropdown'),
        decoration: BoxDecoration(
          color: surface.bg,
          border: Border.all(color: surface.border),
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: value,
            hint: Text(t.shareSwitcherTitle, style: TextStyle(fontSize: 13, color: surface.muted)),
            icon: Icon(Icons.unfold_more, size: 18, color: surface.muted),
            dropdownColor: surface.surface,
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: surface.text),
            selectedItemBuilder: (context) => [
              for (final c in items)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(c.isOwner ? Icons.folder_outlined : Icons.group_outlined, size: 16, color: surface.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c.displayName, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              const SizedBox.shrink(),
            ],
            items: [
              for (final c in items)
                DropdownMenuItem<String>(
                  value: c.id,
                  child: Row(
                    children: [
                      Icon(c.isOwner ? Icons.folder_outlined : Icons.group_outlined, size: 16, color: surface.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c.displayName, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      _RoleBadge(role: c.role, surface: surface),
                    ],
                  ),
                ),
              DropdownMenuItem<String>(
                value: _joinValue,
                child: Row(
                  children: [
                    Icon(Icons.vpn_key_outlined, size: 16, color: surface.muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(t.shareJoinWithCode, style: TextStyle(color: surface.muted)),
                    ),
                  ],
                ),
              ),
            ],
            onChanged: (v) {
              if (v == null) return;
              if (v == _joinValue) {
                showJoinCollectionSheet(context);
                return;
              }
              if (v == active?.id) return;
              final target = items.firstWhere((c) => c.id == v);
              switchCollectionFromUi(context, ref, target);
            },
          ),
        ),
      ),
    );
  }
}

/// Phone/tablet bottom sheet: "My collections" / "Shared with me" with role
/// badges, a check on the active one, and "Join with code…".
Future<void> showCollectionSwitcherSheet(BuildContext context) {
  return showAdaptiveSheet<void>(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CollectionSwitcherSheet(),
  );
}

class CollectionSwitcherSheet extends ConsumerWidget {
  const CollectionSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final state = ref.watch(collectionsProvider);
    final active = ref.watch(activeCollectionProvider);
    final mine = state.mine;
    final shared = state.sharedWithMe;

    // ListTile paints ink on the nearest Material; the sheet chrome's
    // decorated box would hide it, so every tile gets a transparent one.
    Widget tile(CloudCollection c) {
      final isActive = c.id == active?.id;
      return Material(
        type: MaterialType.transparency,
        child: ListTile(
          key: Key('collection-tile-${c.id}'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
            child: Icon(c.isOwner ? Icons.folder_outlined : Icons.group_outlined, size: 16, color: surface.green),
          ),
          title: Text(
            c.displayName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: surface.text),
          ),
          subtitle: Text(t.shareMembersCount(c.memberCount), style: TextStyle(fontSize: 11.5, color: surface.muted)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RoleBadge(role: c.role, surface: surface),
              if (isActive) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, size: 18, color: surface.green, key: Key('collection-active-${c.id}')),
              ],
            ],
          ),
          onTap: () async {
            final nav = Navigator.of(context);
            if (!isActive) await switchCollectionFromUi(context, ref, c);
            if (nav.mounted) nav.pop();
          },
        ),
      );
    }

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: surface.muted),
      ),
    );

    return SheetChrome(
      surface: surface,
      title: t.shareSwitcherTitle,
      children: [
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.shareSwitcherTitle,
                key: const Key('collection-switcher-sheet-title'),
                style: TextStyle(
                  fontFamily: PlantlyFonts.plusJakartaSans,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                ),
              ),
              if (mine.isNotEmpty) header(t.shareMineSection),
              for (final c in mine) tile(c),
              header(t.shareSharedWithMe),
              if (shared.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                  child: Text(t.shareNoMembers, style: TextStyle(fontSize: 12, color: surface.muted)),
                ),
              for (final c in shared) tile(c),
              const SizedBox(height: 6),
              Material(
                type: MaterialType.transparency,
                child: ListTile(
                  key: const Key('collection-join-with-code'),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      border: Border.all(color: surface.border),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.vpn_key_outlined, size: 16, color: surface.muted),
                  ),
                  title: Text(
                    t.shareJoinWithCode,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: surface.text),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    showJoinCollectionSheet(context);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.surface});
  final String role;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final owner = role == 'owner';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: owner ? surface.greenSoft : surface.bg,
        border: Border.all(color: owner ? Colors.transparent : surface.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        roleLabel(t, role),
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: owner ? surface.green : surface.muted),
      ),
    );
  }
}
