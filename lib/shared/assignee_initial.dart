import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/collections.dart';
import '../l10n/generated/app_localizations.dart';
import '../marketplace/plantly_api.dart';
import '../theme/tokens.dart';

/// Initial of a member's username, for avatar circles. Uppercase first
/// letter; "?" when the name is empty / unknown.
String assigneeInitialFor(String? username) {
  final n = (username ?? '').trim();
  return n.isEmpty ? '?' : n.substring(0, 1).toUpperCase();
}

/// Small avatar for a schedule's assignee (MULTI-USER-V2 §0): a 20px
/// circle with the first letter of the member's username, tooltip = the
/// username. Renders nothing at all when [userId] is null (unassigned =
/// everyone), so rows keep their layout unless an assignee exists. An id
/// the members list does not know (former member, list not fetched yet)
/// shows "?" with the "Former member" tooltip.
class AssigneeInitial extends StatelessWidget {
  const AssigneeInitial({
    super.key,
    required this.userId,
    required this.members,
    this.size = 20,
    this.padLeft = 6,
    this.background,
    this.foreground,
  });

  final String? userId;
  final List<CollectionMember>? members;
  final double size;

  /// Gap inserted before the circle (so callers can drop it into an
  /// existing `Row` without touching sibling spacing).
  final double padLeft;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final id = userId;
    if (id == null || id.isEmpty) return const SizedBox.shrink();
    final name = memberUsername(members, id);
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final bg = background ?? scheme.primary;
    final fg = foreground ?? scheme.onPrimary;
    return Padding(
      padding: EdgeInsets.only(left: padLeft),
      child: Tooltip(
        message: name == null ? t.assigneeUnknown : t.assigneeTooltip(name),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: name == null ? scheme.surfaceContainerHighest : bg,
            shape: BoxShape.circle,
          ),
          child: Text(
            assigneeInitialFor(name),
            style: TextStyle(
              fontSize: size * 0.55,
              fontWeight: FontWeight.w700,
              color: name == null ? scheme.onSurfaceVariant : fg,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// [AssigneeInitial] bound to the active tenant's members cache. Drop-in
/// for schedule rows: `AssigneeChip(schedule: s, surface: surface)`.
class AssigneeChip extends ConsumerWidget {
  const AssigneeChip({super.key, required this.userId, required this.tenantId, this.surface, this.size = 20, this.padLeft = 6});

  final String? userId;
  final String tenantId;
  final PlantlySurface? surface;
  final double size;
  final double padLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId == null || userId!.isEmpty) return const SizedBox.shrink();
    final members = ref.watch(membersProvider(tenantId)).valueOrNull;
    return AssigneeInitial(
      userId: userId,
      members: members,
      size: size,
      padLeft: padLeft,
      background: surface?.green,
      foreground: Colors.white,
    );
  }
}
