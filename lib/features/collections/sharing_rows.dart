import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/side_sheet.dart';
import '../../cloud/cloud_state.dart';
import '../../cloud/collections.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../shared/sheet_chrome.dart';
import '../../theme/tokens.dart';
import '../home/home_providers.dart';
import '../me/me_rows.dart';
import 'collection_ui.dart';
import 'join_collection_sheet.dart';

/// Seam for the OS share sheet so widget tests can capture the text.
typedef ShareText = Future<void> Function(String text, {String? subject});

final shareTextProvider = Provider<ShareText>((_) {
  return (text, {subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  };
});

/// Me → Cloud → "Sharing" (CLOUD-SYNC-CONTRACT §3): the active collection
/// with the caller's role, then the owner tools ("Invite someone",
/// "Members") or, on a collection shared with the account, "Leave
/// collection"; "Join with code…" always. Renders nothing while the device
/// cannot sync (the Cloud rows above already explain why).
class SharingRows extends ConsumerWidget {
  const SharingRows({super.key, required this.surface});
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Signed in + linked (own plan or not — editors sync on the owner's).
    if (!cloudAccountReady(ref.watch(cloudStateProvider))) return const SizedBox.shrink();
    final active = ref.watch(activeCollectionProvider);
    if (active == null) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final rows = <Widget>[
      MeActionRow(
        key: const Key('share-active'),
        label: t.shareActiveLabel,
        value: t.shareActiveValue(active.displayName, roleLabel(t, active.role)),
        icon: active.isOwner ? Icons.folder_outlined : Icons.group_outlined,
        surface: surface,
      ),
      if (active.isOwner)
        MeActionRow(
          key: const Key('share-invite'),
          label: t.shareInviteLabel,
          value: t.shareInviteValue,
          icon: Icons.person_add_alt_1_outlined,
          surface: surface,
          onTap: () => showInviteSheet(context, active),
        ),
      MeActionRow(
        key: const Key('share-members'),
        label: t.shareMembersLabel,
        value: t.shareMembersValue,
        icon: Icons.people_outline,
        surface: surface,
        onTap: () => showMembersSheet(context, active),
      ),
      if (!active.isOwner)
        MeActionRow(
          key: const Key('share-leave'),
          label: t.shareLeaveLabel,
          value: t.shareLeaveValue(active.displayName),
          icon: Icons.logout,
          surface: surface,
          valueColor: surface.terra,
          onTap: () => confirmLeaveCollection(context, ref, active),
        ),
      MeActionRow(
        key: const Key('share-join'),
        label: t.shareJoinWithCode,
        value: t.shareJoinBody,
        icon: Icons.vpn_key_outlined,
        surface: surface,
        onTap: () => showJoinCollectionSheet(context),
      ),
    ];
    return Column(
      key: const Key('share-rows'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        MeSectionLabel(text: t.shareSectionTitle, surface: surface),
        const SizedBox(height: 4),
        Text(t.shareSectionIntro, style: TextStyle(fontSize: 12, height: 1.4, color: surface.muted)),
        const SizedBox(height: 8),
        for (var i = 0; i < rows.length; i++) ...[if (i > 0) const SizedBox(height: 6), rows[i]],
      ],
    );
  }
}

/// Compact row for the Me list (non-detailed Cloud section): "Sharing ·
/// n collections" → `/me/cloud`. Hidden with a single collection so the
/// Me screen stays as it was.
class SharingSummaryRow extends ConsumerWidget {
  const SharingSummaryRow({super.key, required this.surface, required this.onTap});
  final PlantlySurface surface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(collectionSwitcherVisibleProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final n = ref.watch(collectionsProvider.select((s) => s.items.length));
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: MeActionRow(
        key: const Key('share-summary'),
        label: t.shareSectionTitle,
        value: t.shareMeRowValue(n),
        icon: Icons.group_outlined,
        surface: surface,
        onTap: onTap,
      ),
    );
  }
}

/// `Leave <name>?` → `DELETE …/members/{me}`; the active collection falls
/// back to the linked default.
Future<void> confirmLeaveCollection(BuildContext context, WidgetRef ref, CloudCollection col) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final collections = ref.read(collectionsProvider.notifier); // before the await (#14)
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(t.shareLeaveTitle(col.displayName)),
      content: Text(t.shareLeaveBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
        FilledButton(
          key: const Key('share-leave-confirm'),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(t.shareLeave),
        ),
      ],
    ),
  );
  if (ok != true) return;
  try {
    await collections.leave(col.id);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t.shareLeft(col.displayName))));
  } catch (e) {
    messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(describeShareError(t, e, action: ShareAction.member))));
  }
}

// --- invite -----------------------------------------------------------------

Future<void> showInviteSheet(BuildContext context, CloudCollection col) {
  return showAdaptiveSheet<void>(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => InviteSheet(collection: col),
  );
}

/// Mints an invite on open and shows the code + link with Copy / Share.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.collection});
  final CloudCollection collection;

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  CollectionInvite? _invite;
  String? _error;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  Future<void> _create() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _error = null;
      _invite = null;
    });
    try {
      final invite = await ref.read(collectionsProvider.notifier).createInvite(widget.collection.id);
      if (mounted) setState(() => _invite = invite);
    } catch (e) {
      if (mounted) setState(() => _error = describeShareError(t, e, action: ShareAction.invite));
    }
  }

  String _message(AppLocalizations t, CollectionInvite i) =>
      t.shareInviteMessage(widget.collection.displayName, i.url, i.code);

  Future<void> _copy(AppLocalizations t, CollectionInvite i) async {
    await Clipboard.setData(ClipboardData(text: _message(t, i)));
    if (mounted) setState(() => _copied = true);
  }

  Future<void> _share(AppLocalizations t, CollectionInvite i) async {
    await ref.read(shareTextProvider)(_message(t, i), subject: t.shareInviteTitle(widget.collection.displayName));
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final invite = _invite;
    final title = t.shareInviteTitle(widget.collection.displayName);
    return SheetChrome(
      surface: surface,
      title: title,
      subtitle: t.shareInviteCodeHint,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                key: const Key('invite-title'),
                style: TextStyle(
                  fontFamily: PlantlyFonts.plusJakartaSans,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(t.shareInviteCodeHint, style: TextStyle(fontSize: 12.5, color: surface.muted)),
              const SizedBox(height: 16),
              if (invite == null && _error == null)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: surface.green),
                    ),
                    const SizedBox(width: 10),
                    Text(t.shareInviteCreating, style: TextStyle(fontSize: 12.5, color: surface.muted)),
                  ],
                ),
              if (_error != null) ...[
                Text(
                  _error!,
                  key: const Key('invite-error'),
                  style: TextStyle(fontSize: 12.5, color: surface.terra),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _create,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(t.cloudRefreshStatusLabel),
                ),
              ],
              if (invite != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: surface.greenSoft,
                    borderRadius: BorderRadius.circular(PlantlyTokens.radius),
                  ),
                  child: Center(
                    child: SelectableText(
                      _pretty(invite.code),
                      key: const Key('invite-code'),
                      style: TextStyle(
                        fontFamily: PlantlyFonts.plusJakartaSans,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: surface.green,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  invite.url,
                  key: const Key('invite-url'),
                  style: TextStyle(fontSize: 12, color: surface.muted),
                ),
                if (invite.expiresAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd(t.localeName).add_Hm().format(invite.expiresAt!.toLocal()),
                    style: TextStyle(fontSize: 11.5, color: surface.muted),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('invite-copy'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: surface.text,
                          side: BorderSide(color: surface.border),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                        ),
                        onPressed: () => _copy(t, invite),
                        icon: Icon(_copied ? Icons.check : Icons.copy, size: 18),
                        label: Text(_copied ? t.shareInviteCopied : t.shareInviteCopy),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('invite-share'),
                        style: FilledButton.styleFrom(
                          backgroundColor: surface.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
                        ),
                        onPressed: () => _share(t, invite),
                        icon: const Icon(Icons.ios_share, size: 18),
                        label: Text(t.shareInviteShare),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  /// `ABCDEFGH` → `ABCD-EFGH` for reading aloud; `InviteCode.normalize`
  /// strips the dash on the way back in.
  static String _pretty(String code) => code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
}

// --- members ----------------------------------------------------------------

Future<void> showMembersSheet(BuildContext context, CloudCollection col) {
  return showAdaptiveSheet<void>(
    context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MembersSheet(collection: col),
  );
}

/// Username / role / joined per member. The owner can remove anyone but
/// themself; an editor sees "Leave" on their own row.
class MembersSheet extends ConsumerWidget {
  const MembersSheet({super.key, required this.collection});
  final CloudCollection collection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final surface = mode == ThemeMode.dark ? PlantlySurface.dark : PlantlySurface.light;
    final t = AppLocalizations.of(context);
    final me = ref.watch(currentUserIdProvider);
    final members = ref.watch(membersProvider(collection.id));
    final title = t.shareMembersTitle(collection.displayName);
    return SheetChrome(
      surface: surface,
      title: title,
      children: [
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                key: const Key('members-title'),
                style: TextStyle(
                  fontFamily: PlantlyFonts.plusJakartaSans,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: surface.text,
                ),
              ),
              const SizedBox(height: 10),
              members.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: surface.green)),
                ),
                error: (e, _) => Text(t.shareMembersError, style: TextStyle(fontSize: 12.5, color: surface.terra)),
                data: (list) => list.isEmpty
                    ? Text(t.shareNoMembers, style: TextStyle(fontSize: 12.5, color: surface.muted))
                    : Column(children: [for (final m in list) _memberTile(context, ref, t, surface, m, me)]),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _memberTile(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    PlantlySurface surface,
    CollectionMember m,
    String? me,
  ) {
    final isMe = m.userId == me;
    final iAmOwner = collection.isOwner;
    final joined = m.joinedAt == null
        ? null
        : t.shareMemberJoined(DateFormat.yMMMd(t.localeName).format(m.joinedAt!.toLocal()));
    final subtitle = [roleLabel(t, m.role), ?joined].join(' · ');
    Widget? trailing;
    if (iAmOwner && !isMe) {
      trailing = TextButton(
        key: Key('member-remove-${m.userId}'),
        style: TextButton.styleFrom(foregroundColor: surface.terra),
        onPressed: () => _remove(context, ref, t, m),
        child: Text(t.shareRemoveMember),
      );
    } else if (!iAmOwner && isMe) {
      trailing = TextButton(
        key: const Key('member-leave'),
        style: TextButton.styleFrom(foregroundColor: surface.terra),
        onPressed: () async {
          final nav = Navigator.of(context);
          await confirmLeaveCollection(context, ref, collection);
          if (nav.mounted) nav.pop();
        },
        child: Text(t.shareLeave),
      );
    }
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        key: Key('member-${m.userId}'),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: surface.greenSoft, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            m.username.isEmpty ? '?' : m.username.substring(0, 1).toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w800, color: surface.green),
          ),
        ),
        title: Text(
          isMe ? '${m.username} (${t.shareMemberYou})' : m.username,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: surface.text),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11.5, color: surface.muted)),
        trailing: trailing,
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, AppLocalizations t, CollectionMember m) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final collections = ref.read(collectionsProvider.notifier); // before the await (#14)
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.shareRemoveMemberTitle(m.username)),
        content: Text(t.shareRemoveMemberBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(t.cancel)),
          FilledButton(
            key: const Key('member-remove-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.shareRemoveMember),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await collections.removeMember(collection.id, m.userId);
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.shareRemoved(m.username))));
    } catch (e) {
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(describeShareError(t, e, action: ShareAction.member))));
    }
  }
}
