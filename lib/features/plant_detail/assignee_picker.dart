import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cloud/collections.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../shared/assignee_initial.dart';
import '../../theme/tokens.dart';

/// Whether the schedule editors show the "Assignee" row (MULTI-USER-V2
/// §0): only when the collection on screen is shared with at least two
/// members — a shared collection joined by this account, or an own one
/// whose `member_count` > 1. Single-member / local-only stays untouched.
final assigneePickerVisibleProvider = Provider<bool>((ref) {
  if (ref.watch(activeCollectionIsSharedProvider)) return true;
  return (ref.watch(activeCollectionProvider)?.memberCount ?? 1) > 1;
});

/// "Assignee" field of the add / edit reminder sheets: a tappable row
/// showing the current choice ("Everyone" or a member with initial avatar)
/// that opens a bottom sheet with "Everyone" + the collection's members
/// (from the members cache; the signed-in user is marked "(you)").
/// Renders nothing when [assigneePickerVisibleProvider] is false.
class AssigneePicker extends ConsumerWidget {
  const AssigneePicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.surface,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(assigneePickerVisibleProvider)) return const SizedBox.shrink();
    final t = AppLocalizations.of(context);
    final collection = ref.watch(activeCollectionProvider);
    final members = collection == null ? null : ref.watch(membersProvider(collection.id)).valueOrNull;
    final me = ref.watch(currentUserIdProvider);
    final name = value == null ? null : memberUsername(members, value!);
    final label = value == null
        ? t.assigneeEveryone
        : name == null
            ? t.assigneeUnknown
            : (value == me ? '$name ${t.assigneeYouSuffix}' : name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.assigneeLabel,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: surface.muted, letterSpacing: 1.1),
        ),
        const SizedBox(height: 8),
        InkWell(
          key: const Key('assignee-picker'),
          onTap: () => _pick(context, ref, t, members ?? const [], me),
          borderRadius: BorderRadius.circular(PlantlyTokens.radius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: surface.surface,
              border: Border.all(color: surface.border),
              borderRadius: BorderRadius.circular(PlantlyTokens.radius),
            ),
            child: Row(
              children: [
                if (value == null)
                  Icon(Icons.group_outlined, size: 16, color: surface.muted)
                else
                  AssigneeInitial(
                    userId: value,
                    members: members,
                    padLeft: 0,
                    background: surface.green,
                    foreground: Colors.white,
                  ),
                const SizedBox(width: 10),
                Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: surface.text))),
                Icon(Icons.chevron_right, color: surface.muted),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(t.assigneeHint, style: TextStyle(fontSize: 11, color: surface.muted)),
      ],
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations t,
    List<CollectionMember> members,
    String? me,
  ) async {
    final chosen = await showModalBottomSheet<_Choice>(
      context: context,
      backgroundColor: surface.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            ListTile(
              key: const Key('assignee-option-everyone'),
              leading: Icon(Icons.group_outlined, color: surface.muted),
              title: Text(t.assigneeEveryone, style: TextStyle(color: surface.text)),
              trailing: value == null ? Icon(Icons.check, color: surface.green) : null,
              onTap: () => Navigator.of(ctx).pop(const _Choice(null)),
            ),
            for (final m in members)
              if (m.userId.isNotEmpty)
                ListTile(
                  key: Key('assignee-option-${m.userId}'),
                  leading: AssigneeInitial(
                    userId: m.userId,
                    members: members,
                    size: 28,
                    padLeft: 0,
                    background: surface.green,
                    foreground: Colors.white,
                  ),
                  title: Text(
                    m.userId == me ? '${m.username} ${t.assigneeYouSuffix}' : m.username,
                    style: TextStyle(color: surface.text),
                  ),
                  trailing: value == m.userId ? Icon(Icons.check, color: surface.green) : null,
                  onTap: () => Navigator.of(ctx).pop(_Choice(m.userId)),
                ),
          ],
        ),
      ),
    );
    if (chosen != null) onChanged(chosen.userId);
  }
}

/// Wrapper so "Everyone" (null) is distinguishable from "dismissed".
class _Choice {
  const _Choice(this.userId);
  final String? userId;
}
