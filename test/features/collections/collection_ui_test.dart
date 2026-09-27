import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/features/collections/collection_ui.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';

/// Server error shapes (§3, as merged) → copy.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ro = lookupAppLocalizations(const Locale('ro'));

  PlantlyApiException api(int status, String? code, {Map<String, dynamic> details = const {}}) =>
      PlantlyApiException(status: status, message: 'server says', code: code, details: details);

  test('join: 404 invite_invalid, 409 already_member (+ status fallbacks)', () {
    expect(describeShareError(en, api(404, 'invite_invalid')), en.shareJoinErrInvalid);
    expect(describeShareError(en, api(409, 'already_member')), en.shareJoinErrAlreadyMember);
    expect(describeShareError(en, api(404, null)), en.shareJoinErrInvalid);
    expect(describeShareError(en, api(410, null)), en.shareJoinErrInvalid);
    expect(describeShareError(en, api(409, null)), en.shareJoinErrAlreadyMember);
    expect(describeShareError(ro, api(404, 'invite_invalid')), ro.shareJoinErrInvalid);
    expect(ro.shareJoinErrInvalid, contains('ț'));
  });

  test('invite: 429 too_many_invites {max_active}, 403 owner_only', () {
    expect(describeShareError(en, api(429, 'too_many_invites', details: {'max_active': 5}), action: ShareAction.invite),
        en.shareErrTooManyInvites(5));
    expect(describeShareError(en, api(429, 'too_many_invites'), action: ShareAction.invite), en.shareErrTooManyInvites(5));
    expect(describeShareError(en, api(403, 'owner_only'), action: ShareAction.invite), en.shareErrOwnerOnly);
    expect(describeShareError(en, api(403, null), action: ShareAction.invite), en.shareErrOwnerOnly);
    expect(describeShareError(en, api(429, null), action: ShareAction.invite), en.plantlyErrorRateLimited);
  });

  test('members: 409 owner_cannot_leave, 404 member_not_found', () {
    expect(describeShareError(en, api(409, 'owner_cannot_leave'), action: ShareAction.member), en.shareErrOwnerCannotLeave);
    expect(describeShareError(en, api(404, 'member_not_found'), action: ShareAction.member), en.shareErrMemberNotFound);
    expect(describeShareError(en, api(409, null), action: ShareAction.member), en.shareErrOwnerCannotLeave);
    expect(describeShareError(en, api(404, null), action: ShareAction.member), en.shareErrMemberNotFound);
  });

  test('generic: network, 402, unknown → server message', () {
    expect(describeShareError(en, const PlantlyNetworkException('x')), en.plantlyErrorNetwork);
    expect(describeShareError(en, api(402, 'cloud_required')), en.cloudNotIncludedValue);
    expect(describeShareError(en, api(500, 'boom')), 'server says');
    expect(describeShareError(en, StateError('x')), contains('Bad state'));
  });
}
