import '../../l10n/generated/app_localizations.dart';
import '../../marketplace/plantly_api.dart';

/// Copy helpers shared by the switcher, the join sheet and the Sharing rows
/// (CLOUD-SYNC-CONTRACT §3).

String roleLabel(AppLocalizations t, String role) => role == 'owner' ? t.shareRoleOwner : t.shareRoleEditor;

/// Which §3 call failed — picks the status-code fallbacks.
enum ShareAction { join, invite, member }

/// §3 API failures → copy. Stable server codes first (`invite_invalid`,
/// `already_member`, `too_many_invites {max_active}`, `owner_only`,
/// `owner_cannot_leave`, `member_not_found`), then tolerant status-code
/// fallbacks per [action], then generic network / rate-limit copy, else
/// the server message.
String describeShareError(AppLocalizations t, Object e, {ShareAction action = ShareAction.join}) {
  if (e is PlantlyNetworkException) return t.plantlyErrorNetwork;
  if (e is PlantlyApiException) {
    switch (e.code) {
      case 'invite_invalid':
        return t.shareJoinErrInvalid;
      case 'already_member':
        return t.shareJoinErrAlreadyMember;
      case 'too_many_invites':
        return t.shareErrTooManyInvites((e.details['max_active'] as num?)?.toInt() ?? 5);
      case 'owner_only':
        return t.shareErrOwnerOnly;
      case 'owner_cannot_leave':
        return t.shareErrOwnerCannotLeave;
      case 'member_not_found':
        return t.shareErrMemberNotFound;
    }
    switch (action) {
      case ShareAction.join:
        if (e.status == 404 || e.status == 410 || e.status == 400) return t.shareJoinErrInvalid;
        if (e.status == 409) return t.shareJoinErrAlreadyMember;
      case ShareAction.invite:
        if (e.status == 403) return t.shareErrOwnerOnly;
      case ShareAction.member:
        if (e.status == 404) return t.shareErrMemberNotFound;
        if (e.status == 409) return t.shareErrOwnerCannotLeave;
    }
    if (e.isRateLimited) return t.plantlyErrorRateLimited;
    if (e.status == 402) return t.cloudNotIncludedValue;
    return e.message;
  }
  return '$e';
}
