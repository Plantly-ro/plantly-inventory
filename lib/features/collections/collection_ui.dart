import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';
import '../../theme/tokens.dart';

/// Copy helpers shared by the switcher, the join sheet and the Sharing rows
/// (CLOUD-SYNC-CONTRACT §3).

String roleLabel(AppLocalizations t, String role) => switch (role) {
      CollectionRole.owner => t.shareRoleOwner,
      CollectionRole.viewer => t.shareRoleViewer,
      _ => t.shareRoleEditor,
    };

/// Which §3 call failed — picks the status-code fallbacks. `transfer` and
/// `collection` (rename/delete) are the MULTI-USER-V2 owner calls.
enum ShareAction { join, invite, member, transfer, collection }

/// §3 / MULTI-USER-V2 API failures → copy. Stable server codes first
/// (`invite_invalid`, `already_member`, `too_many_invites {max_active}`,
/// `owner_only`, `owner_cannot_leave`, `member_not_found`, `read_only`,
/// `device_revoked`, `too_many_devices`, `device_lookup_failed`,
/// `collection_deleted`, `cloud_required_new_owner`, `cloud_required_owner`,
/// `cloud_required` — MULTI-USER-V2 §8),
/// then tolerant status-code fallbacks per [action], then generic network /
/// rate-limit copy, else the server message. Codes are read from `code`
/// or, failing that, `error` ([PlantlyApiException.errorCode]) — the
/// inventory routes send `{"error":"<code>"}`.
String describeShareError(AppLocalizations t, Object e, {ShareAction action = ShareAction.join}) {
  if (e is PlantlyNetworkException) return t.plantlyErrorNetwork;
  if (e is PlantlyApiException) {
    switch (e.errorCode) {
      case 'invite_invalid':
        return t.shareJoinErrInvalid;
      case 'already_member':
        return t.shareJoinErrAlreadyMember;
      case 'too_many_invites':
        return t.shareErrTooManyInvites((e.details['max_active'] as num?)?.toInt() ?? 10);
      case 'owner_only':
        return t.shareErrOwnerOnly;
      case 'owner_cannot_leave':
        return t.shareErrOwnerCannotLeave;
      case 'member_not_found':
        return t.shareErrMemberNotFound;
      case 'read_only':
        return t.shareErrReadOnly;
      case 'device_revoked':
        return t.shareErrDeviceRevoked;
      case 'too_many_devices':
        return t.shareErrTooManyDevices;
      case 'device_lookup_failed':
        return t.shareErrDeviceLookupFailed;
      case 'collection_deleted':
        return t.shareErrCollectionDeleted;
      case 'cloud_required_new_owner':
        return t.shareErrCloudRequiredNewOwner;
      case 'cloud_required_owner':
        return t.shareErrOwnerLapsed;
      case 'cloud_required':
        // §8: the caller's own plan — on a join the sheet shows the
        // requirement step instead; everywhere else this line.
        return action == ShareAction.join ? t.shareJoinCloudRequiredTitle : t.shareErrMemberLapsed;
      case 'not_a_member':
        return t.shareErrNotAMember;
    }
    if (e.status == 410) return t.shareErrCollectionDeleted;
    switch (action) {
      case ShareAction.join:
        if (e.status == 404 || e.status == 400) return t.shareJoinErrInvalid;
        if (e.status == 409) return t.shareJoinErrAlreadyMember;
      case ShareAction.invite:
        if (e.status == 403) return t.shareErrOwnerOnly;
        if (e.status == 409) return t.shareErrTooManyInvites(10);
      case ShareAction.member:
        if (e.status == 404) return t.shareErrMemberNotFound;
        if (e.status == 409) return t.shareErrOwnerCannotLeave;
        if (e.status == 403) return t.shareErrOwnerOnly;
      case ShareAction.transfer:
        if (e.status == 402) return t.shareErrCloudRequiredNewOwner;
        if (e.status == 404) return t.shareErrMemberNotFound;
        if (e.status == 403) return t.shareErrOwnerOnly;
      case ShareAction.collection:
        if (e.status == 403) return t.shareErrOwnerOnly;
    }
    if (e.isRateLimited) return t.plantlyErrorRateLimited;
    if (e.status == 402) return t.cloudNotIncludedValue;
    return e.message;
  }
  return '$e';
}


/// `owner` → soft green pill, `editor` → outlined, `viewer` → outlined and
/// muted (dimmer text, dashed-looking border colour) so a read-only member
/// reads as such at a glance. Shared by the switcher, the members sheet
/// and the invites list.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, required this.surface});
  final String role;
  final PlantlySurface surface;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final owner = role == CollectionRole.owner;
    final viewer = role == CollectionRole.viewer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: owner ? surface.greenSoft : (viewer ? surface.surfaceAlt : surface.bg),
        border: Border.all(color: owner ? Colors.transparent : surface.border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewer) ...[
            Icon(Icons.visibility_outlined, size: 11, color: surface.muted.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
          ],
          Text(
            roleLabel(t, role),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: viewer ? FontWeight.w600 : FontWeight.w700,
              color: owner ? surface.green : (viewer ? surface.muted.withValues(alpha: 0.8) : surface.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// "expires in N days" / "expires in N hours" / "expires soon" / "expired"
/// for an invite's `expires_at`; null when the server sent no expiry.
/// Hand-rolled day/hour diff (ceil) — no need for a full relative-time
/// formatter here.
String? inviteExpiryLabel(AppLocalizations t, DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return null;
  final left = expiresAt.difference(now ?? DateTime.now());
  if (left.isNegative) return t.shareInviteExpired;
  if (left.inMinutes < 60) return t.shareInviteExpiresSoon;
  if (left.inHours < 24) return t.shareInviteExpiresHours(left.inHours);
  final days = (left.inHours / 24).ceil();
  return t.shareInviteExpiresDays(days);
}
