import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/breakpoints.dart';
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
import 'invites_section.dart';
import 'join_collection_sheet.dart';
import 'transfer_ownership_dialog.dart';

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

/// Invite presets (MULTI-USER-V2 §2.4): single use · 7 days (the server
/// default), "Family" (10 uses · 30 days), or custom steppers.
enum InvitePreset { single, family, custom }

/// Invite v2: a small form first (role, preset / custom uses + days,
/// optional label) → `POST …/invites` → the code + link with Copy / Share
/// (the code is shown once, so the result view keeps `shareInviteMessage`
/// for both buttons) plus a role · uses · expiry summary line.
class InviteSheet extends ConsumerStatefulWidget {
  const InviteSheet({super.key, required this.collection});
  final CloudCollection collection;

  @override
  ConsumerState<InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<InviteSheet> {
  CollectionInvite? _invite;
  InviteOptions? _sent;
  String? _error;
  bool _busy = false;
  bool _copied = false;

  String _role = CollectionRole.editor;
  InvitePreset _preset = InvitePreset.single;
  int _maxUses = 1;
  int _ttlDays = 7;
  final _label = TextEditingController();

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  InviteOptions get _options => InviteOptions(
        role: _role,
        maxUses: switch (_preset) {
          InvitePreset.single => 1,
          InvitePreset.family => InviteOptions.family.maxUses,
          InvitePreset.custom => _maxUses,
        },
        ttlDays: switch (_preset) {
          InvitePreset.single => 7,
          InvitePreset.family => InviteOptions.family.ttlDays,
          InvitePreset.custom => _ttlDays,
        },
        label: _label.text.trim().isEmpty ? null : _label.text.trim(),
      );

  Future<void> _create() async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    final options = _options;
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final invite = await ref.read(collectionsProvider.notifier).createInvite(widget.collection.id, options: options);
      if (mounted) {
        setState(() {
          _invite = invite;
          _sent = options;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeShareError(t, e, action: ShareAction.invite));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    final hint = invite == null ? t.shareInviteFormHint : t.shareInviteCodeShownOnce;
    return SheetChrome(
      surface: surface,
      title: title,
      subtitle: hint,
      scrollable: true,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Desktop: title + hint live in the SheetChrome header (#29).
              if (!context.isDesktop) ...[
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
                Text(hint, style: TextStyle(fontSize: 12.5, color: surface.muted)),
                const SizedBox(height: 16),
              ],
              if (invite == null) ..._form(t, surface),
              if (invite != null) ..._result(t, surface, invite),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _form(AppLocalizations t, PlantlySurface surface) {
    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            text,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: surface.muted),
          ),
        );
    Widget chip({required Key key, required String label, required bool selected, required VoidCallback onTap}) {
      return ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        onSelected: _busy ? null : (_) => onTap(),
        showCheckmark: false,
        selectedColor: surface.greenSoft,
        backgroundColor: surface.bg,
        side: BorderSide(color: selected ? surface.green : surface.border),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: selected ? surface.green : surface.text,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
    }

    return [
      sectionLabel(t.shareInviteRoleLabel),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final role in CollectionRole.assignable)
            chip(
              key: Key('invite-role-$role'),
              label: roleLabel(t, role),
              selected: _role == role,
              onTap: () => setState(() => _role = role),
            ),
        ],
      ),
      const SizedBox(height: 4),
      Text(t.shareInviteRoleHint, style: TextStyle(fontSize: 11.5, color: surface.muted)),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip(
            key: const Key('invite-preset-single'),
            label: t.shareInvitePresetSingle,
            selected: _preset == InvitePreset.single,
            onTap: () => setState(() => _preset = InvitePreset.single),
          ),
          chip(
            key: const Key('invite-preset-family'),
            label: t.shareInvitePresetFamily,
            selected: _preset == InvitePreset.family,
            onTap: () => setState(() => _preset = InvitePreset.family),
          ),
          chip(
            key: const Key('invite-preset-custom'),
            label: t.shareInvitePresetCustom,
            selected: _preset == InvitePreset.custom,
            onTap: () => setState(() => _preset = InvitePreset.custom),
          ),
        ],
      ),
      if (_preset == InvitePreset.custom) ...[
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _Stepper(
                key: const Key('invite-max-uses'),
                label: t.shareInviteMaxUses,
                value: _maxUses,
                min: 1,
                max: InviteOptions.maxUsesLimit,
                surface: surface,
                onChanged: (v) => setState(() => _maxUses = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Stepper(
                key: const Key('invite-ttl-days'),
                label: t.shareInviteTtlDays,
                value: _ttlDays,
                min: 1,
                max: InviteOptions.ttlDaysLimit,
                surface: surface,
                onChanged: (v) => setState(() => _ttlDays = v),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 14),
      TextField(
        key: const Key('invite-label'),
        controller: _label,
        enabled: !_busy,
        maxLength: InviteOptions.labelLimit,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(fontSize: 14, color: surface.text),
        decoration: InputDecoration(
          labelText: t.shareInviteLabelField,
          hintText: t.shareInviteLabelHint,
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius)),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 6),
      Text(
        t.shareInviteSummary(roleLabel(t, _options.role), _options.maxUses, _options.ttlDays),
        key: const Key('invite-form-summary'),
        style: TextStyle(fontSize: 11.5, color: surface.muted),
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, key: const Key('invite-error'), style: TextStyle(fontSize: 12.5, color: surface.terra)),
      ],
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          key: const Key('invite-create'),
          style: FilledButton.styleFrom(
            backgroundColor: surface.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PlantlyTokens.radius + 2)),
          ),
          onPressed: _busy ? null : _create,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.person_add_alt_1_outlined, size: 18),
          label: Text(_busy ? t.shareInviteCreating : t.shareInviteCreate),
        ),
      ),
    ];
  }

  List<Widget> _result(AppLocalizations t, PlantlySurface surface, CollectionInvite invite) {
    final sent = _sent ?? const InviteOptions();
    return [
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
      const SizedBox(height: 6),
      Row(
        children: [
          RoleBadge(role: invite.role.isEmpty ? sent.role : invite.role, surface: surface),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // Role · uses; the expiry date below says when it ends,
              // the requested TTL would only restate it.
              [
                if (invite.label != null) invite.label!,
                roleLabel(t, invite.role.isEmpty ? sent.role : invite.role),
                t.shareInviteMaxUsesLabel(invite.maxUses > 0 ? invite.maxUses : sent.maxUses),
              ].join(' · '),
              key: const Key('invite-summary'),
              style: TextStyle(fontSize: 11.5, color: surface.muted),
            ),
          ),
        ],
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
    ];
  }

  /// `ABCDEFGH` → `ABCD-EFGH` for reading aloud; `InviteCode.normalize`
  /// strips the dash on the way back in.
  static String _pretty(String code) => code.length == 8 ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
}

/// `−  n  +` with a label; clamps to [min]..[max]. Keys: `<key>-minus`,
/// `<key>-plus`, `<key>-value` derive from the widget key's value.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required Key super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.surface,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final PlantlySurface surface;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final base = (key! as ValueKey<String>).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: surface.muted)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: surface.border),
            borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          ),
          child: Row(
            children: [
              IconButton(
                key: Key('$base-minus'),
                tooltip: t.stepperDecrease(label),
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.remove, size: 18, color: surface.text),
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              Expanded(
                child: Text(
                  '$value',
                  key: Key('$base-value'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: surface.text),
                ),
              ),
              IconButton(
                key: Key('$base-plus'),
                tooltip: t.stepperIncrease(label),
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add, size: 18, color: surface.text),
                onPressed: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
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

/// Members v2 (MULTI-USER-V2 §2.6–2.8): every row carries a [RoleBadge]
/// and the joined date; the caller's own row says "(you)". The owner gets
/// a per-row menu on everyone else — Make editor / Make viewer, Transfer
/// ownership, Remove — and the [InvitesSection] below the list. Editors
/// and viewers see badges only plus "Leave" on their own row.
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
    // The role may change under us (transfer): read the live record.
    final live = ref.watch(collectionsProvider.select((s) => s.byId(collection.id))) ?? collection;
    final title = t.shareMembersTitle(live.displayName);
    return SheetChrome(
      surface: surface,
      title: title,
      scrollable: true,
      children: [
        SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Desktop: the SheetChrome header carries the title (#29).
              if (!context.isDesktop) ...[
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
              ],
              members.when(
                loading: () => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator(color: surface.green)),
                ),
                error: (e, _) => Text(t.shareMembersError, style: TextStyle(fontSize: 12.5, color: surface.terra)),
                data: (list) => list.isEmpty
                    ? Text(t.shareNoMembers, style: TextStyle(fontSize: 12.5, color: surface.muted))
                    : Column(children: [for (final m in list) _memberTile(context, ref, t, surface, live, m, me)]),
              ),
              if (live.isOwner) ...[
                const SizedBox(height: 10),
                Divider(height: 1, color: surface.border),
                InvitesSection(collection: live, surface: surface),
              ],
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
    CloudCollection col,
    CollectionMember m,
    String? me,
  ) {
    final isMe = m.userId == me;
    final iAmOwner = col.isOwner;
    final joined = m.joinedAt == null
        ? null
        : t.shareMemberJoined(DateFormat.yMMMd(t.localeName).format(m.joinedAt!.toLocal()));
    Widget? trailing;
    if (iAmOwner && !isMe && !m.isOwner) {
      final nextRole = m.isViewer ? CollectionRole.editor : CollectionRole.viewer;
      trailing = PopupMenuButton<String>(
        key: Key('member-menu-${m.userId}'),
        tooltip: t.shareMembersActions,
        icon: Icon(Icons.more_vert, size: 20, color: surface.muted),
        onSelected: (v) {
          switch (v) {
            case 'role':
              _setRole(context, ref, t, col, m, nextRole);
            case 'transfer':
              _transfer(context, ref, t, surface, col, m);
            case 'remove':
              _remove(context, ref, t, col, m);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            key: Key('member-make-$nextRole-${m.userId}'),
            value: 'role',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(nextRole == CollectionRole.viewer ? Icons.visibility_outlined : Icons.edit_outlined, size: 18),
              title: Text(nextRole == CollectionRole.viewer ? t.shareMembersMakeViewer : t.shareMembersMakeEditor),
            ),
          ),
          PopupMenuItem(
            key: Key('member-transfer-${m.userId}'),
            value: 'transfer',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.swap_horiz, size: 18),
              title: Text(t.shareTransferAction),
            ),
          ),
          PopupMenuItem(
            key: Key('member-remove-${m.userId}'),
            value: 'remove',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.person_remove_outlined, size: 18, color: surface.terra),
              title: Text(t.shareRemoveMember, style: TextStyle(color: surface.terra)),
            ),
          ),
        ],
      );
    } else if (!iAmOwner && isMe) {
      trailing = TextButton(
        key: const Key('member-leave'),
        style: TextButton.styleFrom(foregroundColor: surface.terra),
        onPressed: () async {
          final nav = Navigator.of(context);
          await confirmLeaveCollection(context, ref, col);
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
        title: Row(
          children: [
            Flexible(
              child: Text(
                isMe ? '${m.username} (${t.shareMemberYou})' : m.username,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: surface.text),
              ),
            ),
            const SizedBox(width: 8),
            RoleBadge(key: Key('member-role-${m.userId}'), role: m.role, surface: surface),
          ],
        ),
        subtitle: joined == null ? null : Text(joined, style: TextStyle(fontSize: 11.5, color: surface.muted)),
        trailing: trailing,
      ),
    );
  }

  Future<void> _setRole(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    CloudCollection col,
    CollectionMember m,
    String role,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(collectionsProvider.notifier).setMemberRole(col.id, m.userId, role);
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(t.shareMembersRoleChanged(m.username, roleLabel(t, role)))));
    } catch (e) {
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(describeShareError(t, e, action: ShareAction.member))));
    }
  }

  Future<void> _transfer(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    PlantlySurface surface,
    CloudCollection col,
    CollectionMember m,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await showTransferOwnershipDialog(context, collection: col, target: m, surface: surface);
    if (!ok) return;
    messenger
      ?..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(t.shareTransferDone(m.username, col.displayName))));
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, AppLocalizations t, CloudCollection col, CollectionMember m) async {
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
      await collections.removeMember(col.id, m.userId);
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
