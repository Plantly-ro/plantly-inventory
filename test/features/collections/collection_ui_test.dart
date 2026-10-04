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
    expect(describeShareError(en, api(410, null)), en.shareErrCollectionDeleted, reason: 'v2: bare 410 = deleted');
    expect(describeShareError(en, api(409, null)), en.shareJoinErrAlreadyMember);
    expect(describeShareError(ro, api(404, 'invite_invalid')), ro.shareJoinErrInvalid);
    expect(ro.shareJoinErrInvalid, contains('ț'));
  });

  test('invite: 429 too_many_invites {max_active}, 403 owner_only', () {
    expect(describeShareError(en, api(429, 'too_many_invites', details: {'max_active': 5}), action: ShareAction.invite),
        en.shareErrTooManyInvites(5));
    expect(describeShareError(en, api(429, 'too_many_invites'), action: ShareAction.invite), en.shareErrTooManyInvites(10));
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
    // §8: `cloud_required` = the caller's own plan — the join sheet's
    // requirement title on a join, the lapsed-member line elsewhere; a
    // bare 402 keeps the generic "not included" copy.
    expect(describeShareError(en, api(402, 'cloud_required')), en.shareJoinCloudRequiredTitle);
    expect(describeShareError(en, api(402, 'cloud_required'), action: ShareAction.member), en.shareErrMemberLapsed);
    expect(describeShareError(en, api(402, 'cloud_required_owner')), en.shareErrOwnerLapsed);
    expect(describeShareError(en, api(402, null), action: ShareAction.member), en.cloudNotIncludedValue);
    expect(describeShareError(en, api(500, 'boom')), 'server says');
    expect(describeShareError(en, StateError('x')), contains('Bad state'));
  });

  test('MULTI-USER-V2 codes: read_only, device_revoked, collection_deleted (code + bare 410)', () {
    expect(describeShareError(en, api(403, 'read_only'), action: ShareAction.member), en.shareErrReadOnly);
    expect(describeShareError(en, PlantlyApiException(status: 403, message: 'read_only')), en.shareErrReadOnly,
        reason: 'inventory routes send {"error":"<code>"} → errorCode falls back to message');
    expect(describeShareError(en, api(403, 'device_revoked')), en.shareErrDeviceRevoked);
    expect(describeShareError(en, api(410, 'collection_deleted')), en.shareErrCollectionDeleted);
    for (final action in ShareAction.values) {
      expect(describeShareError(en, api(410, null), action: action), en.shareErrCollectionDeleted, reason: '$action');
    }
    expect(describeShareError(ro, api(410, null), action: ShareAction.member), ro.shareErrCollectionDeleted);
  });

  test('MULTI-USER-V2 §2.12 device codes: too_many_devices points at Me → Cloud → Devices; device_lookup_failed = retry', () {
    expect(describeShareError(en, api(400, 'too_many_devices')), en.shareErrTooManyDevices);
    expect(en.shareErrTooManyDevices, contains('Devices'));
    expect(describeShareError(ro, api(400, 'too_many_devices')), ro.shareErrTooManyDevices);
    expect(ro.shareErrTooManyDevices, contains('Dispozitive'));
    expect(describeShareError(en, api(503, 'device_lookup_failed')), en.shareErrDeviceLookupFailed);
    expect(describeShareError(ro, api(503, 'device_lookup_failed')), ro.shareErrDeviceLookupFailed);
    expect(describeShareError(en, api(400, 'bad_request'), action: ShareAction.member), 'server says',
        reason: 'other 400s keep the server message (join alone maps a bare 400 to invite-invalid)');
  });

  test('transfer: 402 cloud_required_new_owner by code and by bare 402; 404 member_not_found', () {
    expect(describeShareError(en, api(402, 'cloud_required_new_owner'), action: ShareAction.transfer),
        en.shareErrCloudRequiredNewOwner);
    expect(describeShareError(en, api(402, 'cloud_required_new_owner')), en.shareErrCloudRequiredNewOwner,
        reason: 'code wins regardless of action');
    expect(describeShareError(en, api(402, null), action: ShareAction.transfer), en.shareErrCloudRequiredNewOwner);
    expect(describeShareError(en, api(402, null), action: ShareAction.member), en.cloudNotIncludedValue,
        reason: 'bare 402 is only the new-owner copy on the transfer call');
    expect(describeShareError(en, api(404, 'member_not_found'), action: ShareAction.transfer), en.shareErrMemberNotFound);
    expect(describeShareError(en, api(404, null), action: ShareAction.transfer), en.shareErrMemberNotFound);
    expect(describeShareError(en, api(403, null), action: ShareAction.transfer), en.shareErrOwnerOnly);
  });

  test('invite: 409 too_many_invites (v2) by code and by bare 409 on the invite call', () {
    expect(describeShareError(en, api(409, 'too_many_invites', details: {'max_active': 10}), action: ShareAction.invite),
        en.shareErrTooManyInvites(10));
    expect(describeShareError(en, api(409, null), action: ShareAction.invite), en.shareErrTooManyInvites(10));
    expect(describeShareError(en, api(403, null), action: ShareAction.collection), en.shareErrOwnerOnly);
  });

  test('roleLabel: owner / editor / viewer (+ unknown → editor), both locales', () {
    expect(roleLabel(en, 'owner'), 'Owner');
    expect(roleLabel(en, 'editor'), 'Editor');
    expect(roleLabel(en, 'viewer'), 'Viewer');
    expect(roleLabel(en, 'whatever'), 'Editor');
    expect(roleLabel(ro, 'viewer'), ro.shareRoleViewer);
    expect(ro.shareRoleViewer, isNot(ro.shareRoleEditor));
  });

  test('inviteExpiryLabel: days (ceil) / hours / soon / expired / null', () {
    final now = DateTime.utc(2026, 10, 3, 12);
    expect(inviteExpiryLabel(en, null, now: now), isNull);
    expect(inviteExpiryLabel(en, now.add(const Duration(days: 7)), now: now), 'expires in 7 days');
    expect(inviteExpiryLabel(en, now.add(const Duration(days: 6, hours: 1)), now: now), 'expires in 7 days');
    expect(inviteExpiryLabel(en, now.add(const Duration(hours: 25)), now: now), 'expires in 2 days');
    expect(inviteExpiryLabel(en, now.add(const Duration(hours: 5)), now: now), 'expires in 5 hours');
    expect(inviteExpiryLabel(en, now.add(const Duration(hours: 1)), now: now), 'expires in 1 hour');
    expect(inviteExpiryLabel(en, now.add(const Duration(minutes: 20)), now: now), 'expires soon');
    expect(inviteExpiryLabel(en, now.subtract(const Duration(minutes: 1)), now: now), 'expired');
    expect(inviteExpiryLabel(ro, now.add(const Duration(days: 30)), now: now), 'expiră în 30 de zile');
    expect(inviteExpiryLabel(ro, now.add(const Duration(days: 3)), now: now), 'expiră în 3 zile');
  });
}
