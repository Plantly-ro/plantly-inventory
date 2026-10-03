import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/plantly_hosts.dart';

/// A non-2xx reply from the marketplace, with the JSON error envelope
/// decoded (`{"error":"msg"}` or `{"error":"msg","code":"stable_code"}`).
class PlantlyApiException implements Exception {
  const PlantlyApiException({
    required this.status,
    required this.message,
    this.code,
    this.retryAfter,
    this.details = const {},
  });

  final int status;
  final String message;
  final String? code;

  /// Seconds from the `Retry-After` header on 429s, when present.
  final int? retryAfter;

  /// Extra fields of the JSON error envelope beyond `error`/`code`
  /// (e.g. `max_active` on `429 too_many_invites`, §3).
  final Map<String, dynamic> details;

  bool get isUnauthorized => status == 401;
  bool get isRateLimited => status == 429;

  /// Stable server code: the `code` field when present, else the `error`
  /// field (the inventory routes send `{"error":"<code>"}`, MULTI-USER-V2 §2).
  String get errorCode => code ?? message;

  @override
  String toString() => 'PlantlyApiException($status${code == null ? '' : ' $code'}: $message)';
}

/// The request never produced a reply: DNS, TLS, timeout, connection reset.
class PlantlyNetworkException implements Exception {
  const PlantlyNetworkException(this.cause);
  final Object cause;

  @override
  String toString() => 'PlantlyNetworkException($cause)';
}

/// A 2xx reply of `POST /subscriptions/play/verify`.
class PlayVerifyReply {
  const PlayVerifyReply({required this.status, required this.body});

  /// 200 (active, acknowledged) or 202 (Play still PENDING).
  final int status;
  final Map<String, dynamic> body;

  bool get pending => status == 202 || body['status'] == 'pending';
}

class LoginResult {
  const LoginResult({required this.token, required this.userId, required this.username, required this.email});
  final String token;
  final String userId;
  final String username;
  final String email;
}

/// One ranked row of `GET /categories/search`.
class CategoryHit {
  const CategoryHit({
    required this.id,
    required this.slug,
    required this.name,
    required this.path,
    required this.score,
  });

  final String id;
  final String slug;
  final String name;

  /// Localized breadcrumb, ` › ` joined.
  final String path;
  final double score;

  factory CategoryHit.fromJson(Map<String, dynamic> m) => CategoryHit(
        id: m['id'] as String? ?? '',
        slug: m['slug'] as String? ?? '',
        name: m['name'] as String? ?? '',
        path: m['path'] as String? ?? (m['name'] as String? ?? ''),
        score: (m['score'] as num?)?.toDouble() ?? 0,
      );
}

/// One photo ready for upload — already downscaled/encoded.
class UploadImage {
  const UploadImage({required this.bytes, this.mime = 'image/jpeg', this.fileName});
  final Uint8List bytes;
  final String mime;
  final String? fileName;
}

class CreatePostResult {
  const CreatePostResult({required this.id, this.uploadWarnings = const []});
  final String id;

  /// Non-fatal per-image upload failures reported by the server.
  final List<String> uploadWarnings;
}

/// Roles a member can hold in a collection (MULTI-USER-V2 §0).
abstract final class CollectionRole {
  static const String owner = 'owner';
  static const String editor = 'editor';
  static const String viewer = 'viewer';

  /// Roles the owner may assign to another member (`PATCH …/members/{uid}`,
  /// invite `role`).
  static const List<String> assignable = [editor, viewer];

  /// Whether [role] may push ops / upload photos / edit anything.
  static bool canEdit(String role) => role == owner || role == editor;
}

/// One server-side inventory collection (CLOUD-SYNC-CONTRACT §2.2 / §3,
/// MULTI-USER-V2 §2.1). `role` is the caller's role in it: `owner`,
/// `editor` or `viewer`.
class CloudCollection {
  const CloudCollection({
    required this.id,
    required this.name,
    required this.role,
    this.createdAt,
    this.ownerUserId,
    this.ownerUsername,
    this.ownerEntitled = true,
    this.memberCount = 1,
  });
  final String id;
  final String name;
  final String role;
  final DateTime? createdAt;

  /// Account that owns the collection (§3 `GET /inventory/collections`).
  final String? ownerUserId;

  /// Owner's plantly.ro username (v2 `owner_username`); null on older
  /// servers / the synthetic linked-default entry.
  final String? ownerUsername;

  /// Whether the owner's plan is currently active (v2 `owner_entitled`).
  /// Sharing runs on the owner's plan, so false = this collection is
  /// paused for everyone. Defaults to true when the server omits it.
  final bool ownerEntitled;

  /// Members including the owner (§3); 1 for a plain default collection.
  final int memberCount;

  bool get isOwner => role == CollectionRole.owner;
  bool get isViewer => role == CollectionRole.viewer;

  /// Whether the caller may mutate rows in this collection (owner/editor).
  bool get canEdit => CollectionRole.canEdit(role);

  /// Sensible display name: the server name, else the id.
  String get displayName => name.isEmpty ? id : name;

  factory CloudCollection.fromJson(Map<String, dynamic> m) => CloudCollection(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        role: m['role'] as String? ?? 'owner',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? ''),
        ownerUserId: m['owner_user_id'] as String?,
        ownerUsername: m['owner_username'] as String?,
        ownerEntitled: m['owner_entitled'] as bool? ?? true,
        memberCount: (m['member_count'] as num?)?.toInt() ?? 1,
      );

  CloudCollection copyWith({String? name, String? role, String? ownerUserId, String? ownerUsername}) =>
      CloudCollection(
        id: id,
        name: name ?? this.name,
        role: role ?? this.role,
        createdAt: createdAt,
        ownerUserId: ownerUserId ?? this.ownerUserId,
        ownerUsername: ownerUsername ?? this.ownerUsername,
        ownerEntitled: ownerEntitled,
        memberCount: memberCount,
      );

  /// Round-trips through the prefs cache (`collectionsProvider`).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
        if (ownerUserId != null) 'owner_user_id': ownerUserId,
        if (ownerUsername != null) 'owner_username': ownerUsername,
        'owner_entitled': ownerEntitled,
        'member_count': memberCount,
      };

  @override
  bool operator ==(Object other) =>
      other is CloudCollection &&
      other.id == id &&
      other.name == name &&
      other.role == role &&
      other.ownerUserId == ownerUserId &&
      other.ownerUsername == ownerUsername &&
      other.ownerEntitled == ownerEntitled &&
      other.memberCount == memberCount;

  @override
  int get hashCode => Object.hash(id, name, role, ownerUserId, ownerUsername, ownerEntitled, memberCount);

  @override
  String toString() => 'CloudCollection($id, $name, role=$role, members=$memberCount)';
}

/// Options for `POST /inventory/collections/{id}/invites` (MULTI-USER-V2
/// §0/§2.4). Server defaults: role editor, 1 use, 7 days, no label.
class InviteOptions {
  const InviteOptions({
    this.role = CollectionRole.editor,
    this.maxUses = 1,
    this.ttlDays = 7,
    this.label,
  });

  /// `editor` | `viewer`.
  final String role;

  /// 1..50.
  final int maxUses;

  /// 1..30.
  final int ttlDays;

  /// ≤ 40 chars, optional.
  final String? label;

  static const int maxUsesLimit = 50;
  static const int ttlDaysLimit = 30;
  static const int labelLimit = 40;

  /// "Familie" preset: 10 uses, 30 days.
  static const InviteOptions family = InviteOptions(maxUses: 10, ttlDays: 30);

  Map<String, dynamic> toJson() => {
        'role': role,
        'max_uses': maxUses.clamp(1, maxUsesLimit),
        'ttl_days': ttlDays.clamp(1, ttlDaysLimit),
        if (label != null && label!.trim().isNotEmpty) 'label': label!.trim(),
      };
}

/// An invite: the `POST …/invites` reply (with `code`/`url`, shown once) or
/// one row of `GET …/invites` (no code; `use_count`, `created_by_username`).
/// (§3, MULTI-USER-V2 §2.4/2.5).
class CollectionInvite {
  const CollectionInvite({
    this.id = '',
    this.code = '',
    this.url = '',
    this.role = CollectionRole.editor,
    this.maxUses = 1,
    this.useCount = 0,
    this.expiresAt,
    this.createdAt,
    this.label,
    this.createdByUsername,
  });

  /// Server id (uuid) — the handle for `DELETE …/invites/{id}`.
  final String id;

  /// 8-char code; empty on list rows (the server never re-shows it).
  final String code;

  /// `https://plantly.ro/app/inventory/join#c=<code>` — deep link / landing
  /// page. Empty on list rows.
  final String url;
  final String role;
  final int maxUses;
  final int useCount;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final String? label;
  final String? createdByUsername;

  int get usesLeft => (maxUses - useCount).clamp(0, maxUses);

  factory CollectionInvite.fromJson(Map<String, dynamic> m) => CollectionInvite(
        id: m['id'] as String? ?? '',
        code: m['code'] as String? ?? '',
        url: m['url'] as String? ?? '',
        role: m['role'] as String? ?? CollectionRole.editor,
        maxUses: (m['max_uses'] as num?)?.toInt() ?? 1,
        useCount: (m['use_count'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.tryParse(m['expires_at'] as String? ?? ''),
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? ''),
        label: (m['label'] as String?)?.trim().isEmpty ?? true ? null : (m['label'] as String).trim(),
        createdByUsername: m['created_by_username'] as String?,
      );
}

/// One row of `GET /inventory/devices` (MULTI-USER-V2 §2.12).
class CloudDevice {
  const CloudDevice({
    required this.deviceId,
    this.platform,
    this.appVersion,
    this.deviceName,
    this.firstSeenAt,
    this.lastSeenAt,
    this.current = false,
  });
  final String deviceId;
  final String? platform;
  final String? appVersion;
  final String? deviceName;
  final DateTime? firstSeenAt;
  final DateTime? lastSeenAt;

  /// The server says this row is the calling device.
  final bool current;

  factory CloudDevice.fromJson(Map<String, dynamic> m) => CloudDevice(
        deviceId: m['device_id'] as String? ?? '',
        platform: m['platform'] as String?,
        appVersion: m['app_version'] as String?,
        deviceName: m['device_name'] as String?,
        firstSeenAt: DateTime.tryParse(m['first_seen_at'] as String? ?? ''),
        lastSeenAt: DateTime.tryParse(m['last_seen_at'] as String? ?? ''),
        current: m['current'] as bool? ?? false,
      );
}

/// One row of `GET /inventory/collections/{id}/members` (§3).
class CollectionMember {
  const CollectionMember({required this.userId, required this.username, required this.role, this.joinedAt});
  final String userId;
  final String username;
  final String role;
  final DateTime? joinedAt;

  bool get isOwner => role == CollectionRole.owner;
  bool get isViewer => role == CollectionRole.viewer;
  bool get canEdit => CollectionRole.canEdit(role);

  factory CollectionMember.fromJson(Map<String, dynamic> m) => CollectionMember(
        userId: m['user_id'] as String? ?? '',
        username: m['username'] as String? ?? '',
        role: m['role'] as String? ?? 'editor',
        joinedAt: DateTime.tryParse(m['joined_at'] as String? ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'role': role,
        if (joinedAt != null) 'joined_at': joinedAt!.toUtc().toIso8601String(),
      };

  @override
  bool operator ==(Object other) =>
      other is CollectionMember && other.userId == userId && other.username == username && other.role == role;

  @override
  int get hashCode => Object.hash(userId, username, role);
}

/// Invite codes (§3): 8 chars from `A-HJ-NP-Z2-9` (no I/O/0/1). Lower case
/// and surrounding whitespace / dashes are tolerated on input.
abstract final class InviteCode {
  static const int length = 8;
  static final RegExp _shape = RegExp(r'^[A-HJ-NP-Z2-9]{8}$');

  /// Canonical form (`ABCD-EFGH`, ` abcdefgh ` → `ABCDEFGH`), or null when
  /// the input is not a valid code.
  static String? normalize(String raw) {
    final c = raw.trim().replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
    return _shape.hasMatch(c) ? c : null;
  }

  static bool isValid(String raw) => normalize(raw) != null;
}

/// Thin client over the marketplace REST API (CONTRACT §0/§1/§5). One
/// method per endpoint we use; no caching, no retries — callers decide.
class PlantlyApi {
  PlantlyApi({
    required http.Client client,
    String? host,
    this.timeout = const Duration(seconds: 15),
    this.uploadTimeout = const Duration(seconds: 90),
    bool? sendUserAgent,
  })  : _client = client,
        host = host ?? PlantlyHosts.host,
        _sendUserAgent = sendUserAgent ?? PlantlyHosts.canSendUserAgent;

  final http.Client _client;
  final String host;
  final Duration timeout;
  final Duration uploadTimeout;
  final bool _sendUserAgent;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${PlantlyHosts.apiBase(host)}$path').replace(queryParameters: query);

  Map<String, String> _headers({String? token, bool json = false, bool inventoryClient = false}) => {
        if (_sendUserAgent) 'User-Agent': PlantlyHosts.userAgent,
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        // Only on the cloud routes (§2.2) — a custom header forces a CORS
        // preflight on web, so the marketplace-only calls keep the old set.
        if (inventoryClient) 'X-Plantly-Client': PlantlyHosts.clientHeader,
      };

  /// `POST /auth/login` → token + user. 401 invalid credentials; 403 with
  /// `code` `email_not_verified` | `account_suspended`.
  Future<LoginResult> login(String email, String password) async {
    final res = await _send(() => _client.post(
          _uri('/auth/login'),
          headers: _headers(json: true),
          body: json.encode({'email': email, 'password': password}),
        ));
    final body = _decodeObject(res);
    final user = body['user'];
    final u = user is Map<String, dynamic> ? user : const <String, dynamic>{};
    return LoginResult(
      token: body['token'] as String? ?? '',
      userId: u['id'] as String? ?? '',
      username: u['username'] as String? ?? '',
      email: u['email'] as String? ?? '',
    );
  }

  /// `POST /auth/refresh` with the (possibly expired) old token → new token.
  Future<String> refresh(String oldToken) async {
    final res = await _send(() => _client.post(_uri('/auth/refresh'), headers: _headers(token: oldToken)));
    return _decodeObject(res)['token'] as String? ?? (throw const PlantlyApiException(status: 200, message: 'refresh reply has no token'));
  }

  /// `GET /users/me`.
  Future<Map<String, dynamic>> me(String token) async {
    final res = await _send(() => _client.get(_uri('/users/me'), headers: _headers(token: token)));
    return _decodeObject(res);
  }

  /// `GET /categories/search?q=&lang=&limit=&approved_only=1` → ranked hits
  /// (never null; empty when `q` is shorter than 2 chars after normalisation).
  Future<List<CategoryHit>> searchCategories(String q, {required String lang, int limit = 10}) async {
    final res = await _send(() => _client.get(
          _uri('/categories/search', {
            'q': q,
            'lang': lang,
            'limit': '$limit',
            'approved_only': '1',
          }),
          headers: _headers(),
        ));
    final decoded = _decode(res);
    if (decoded is! List) return const [];
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic>) CategoryHit.fromJson(e),
    ];
  }

  /// `POST /posts` multipart (§5). Field names are the server's; booleans go
  /// as the strings `"true"`/`"false"`.
  Future<CreatePostResult> createPost({
    required String token,
    required String title,
    required String description,
    required String price,
    required String categoryId,
    String state = 'Romania',
    String? county,
    String? city,
    bool deliveryPickup = true,
    bool deliverySeller = false,
    bool deliveryCourier = false,
    required List<UploadImage> images,
  }) async {
    final req = http.MultipartRequest('POST', _uri('/posts'))
      ..headers.addAll(_headers(token: token))
      ..fields['title'] = title
      ..fields['description'] = description
      ..fields['price'] = price
      ..fields['category_id'] = categoryId
      ..fields['state'] = state
      ..fields['county'] = county ?? ''
      ..fields['city'] = city ?? ''
      ..fields['delivery_pickup'] = '$deliveryPickup'
      ..fields['delivery_seller'] = '$deliverySeller'
      ..fields['delivery_courier'] = '$deliveryCourier';
    for (var i = 0; i < images.length; i++) {
      final img = images[i];
      req.files.add(http.MultipartFile.fromBytes(
        'images',
        img.bytes,
        filename: img.fileName ?? 'photo-${i + 1}.${_extFor(img.mime)}',
        contentType: MediaType.parse(img.mime),
      ));
    }
    final res = await _send(() async => http.Response.fromStream(await _client.send(req)), timeout: uploadTimeout);
    final body = _decodeObject(res);
    final id = body['id'];
    if (id is! String || id.isEmpty) {
      // A 2xx without an id is a broken reply, not a listing.
      throw PlantlyApiException(status: res.statusCode, message: 'create reply has no post id');
    }
    final warnings = body['upload_warnings'];
    return CreatePostResult(
      id: id,
      uploadWarnings: warnings is List ? warnings.map((w) => '$w').toList() : const [],
    );
  }

  /// `GET /subscriptions/me` (CLOUD-SYNC-CONTRACT §1.2) — raw envelope; the
  /// `entitlements.inventory_cloud` parsing lives in `cloud/entitlement.dart`.
  Future<Map<String, dynamic>> getMySubscription(String token) async {
    final res = await _send(() => _client.get(
          _uri('/subscriptions/me'),
          headers: _headers(token: token, inventoryClient: true),
        ));
    return _decodeObject(res);
  }

  /// `POST /subscriptions/play/verify` (PLAY-BILLING-CONTRACT §2): hand a
  /// Google Play purchase token to the server, which re-fetches it from
  /// Google, upserts the subscription row and acknowledges it. Idempotent.
  /// 200 = active (`status`, `interval`, `entitlements`), 202 = Play still
  /// reports PENDING (retry later). Non-2xx surface as [PlantlyApiException]
  /// with [PlantlyApiException.message] = the stable error code:
  /// `already_entitled` (409, `details.source` / `details.provider`),
  /// `token_owned_by_other_user` (409), `invalid_purchase` (400),
  /// `play_unavailable` (502), `play_billing_unavailable` (503).
  Future<PlayVerifyReply> verifyPlayPurchase(
    String token, {
    required String purchaseToken,
    required String productId,
  }) async {
    final res = await _send(() => _client.post(
          _uri('/subscriptions/play/verify'),
          headers: _headers(token: token, json: true, inventoryClient: true),
          body: json.encode({'purchase_token': purchaseToken, 'product_id': productId}),
        ));
    return PlayVerifyReply(status: res.statusCode, body: _decodeObject(res));
  }

  /// `POST /inventory/collections/default` (§2.2) — the caller's default
  /// collection, created on first call. Idempotent.
  Future<CloudCollection> ensureDefaultCollection(String token) async {
    final res = await _send(() => _client.post(
          _uri('/inventory/collections/default'),
          headers: _headers(token: token, inventoryClient: true),
        ));
    final body = _decodeObject(res);
    final col = body['collection'];
    if (col is! Map<String, dynamic> || (col['id'] as String? ?? '').isEmpty) {
      throw PlantlyApiException(status: res.statusCode, message: 'collection reply has no id');
    }
    return CloudCollection.fromJson(col);
  }

  /// `GET /inventory/collections` (§3) — every collection the caller can
  /// see: their own default plus the ones shared with them.
  Future<List<CloudCollection>> listCollections(String token) async {
    final res = await _send(() => _client.get(
          _uri('/inventory/collections'),
          headers: _headers(token: token, inventoryClient: true),
        ));
    final decoded = _decode(res);
    final list = decoded is Map<String, dynamic> ? decoded['collections'] : decoded;
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic> && (e['id'] as String? ?? '').isNotEmpty) CloudCollection.fromJson(e),
    ];
  }

  /// `POST /inventory/collections/{id}/invites` (§3, MULTI-USER-V2 §2.4,
  /// owner) → code + landing URL (code shown once). `403 owner_only`; `409
  /// too_many_invites` (older servers: 429 with `max_active` in
  /// [PlantlyApiException.details]).
  Future<CollectionInvite> createInvite(
    String token,
    String collectionId, {
    InviteOptions options = const InviteOptions(),
  }) async {
    final res = await _send(() => _client.post(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}/invites'),
          headers: _headers(token: token, json: true, inventoryClient: true),
          body: json.encode(options.toJson()),
        ));
    final body = _decodeObject(res);
    final invite = CollectionInvite.fromJson(body['invite'] is Map<String, dynamic> ? body['invite'] : body);
    if (invite.code.isEmpty) {
      throw PlantlyApiException(status: res.statusCode, message: 'invite reply has no code');
    }
    return invite;
  }

  /// `GET /inventory/collections/{id}/invites` (§2.5, owner) — active
  /// invites only (not revoked / expired / used up). Tolerates both a bare
  /// list and `{"invites":[…]}`.
  Future<List<CollectionInvite>> listInvites(String token, String collectionId) async {
    final res = await _send(() => _client.get(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}/invites'),
          headers: _headers(token: token, inventoryClient: true),
        ));
    final decoded = _decode(res);
    final list = decoded is Map<String, dynamic> ? decoded['invites'] : decoded;
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic> && (e['id'] as String? ?? '').isNotEmpty) CollectionInvite.fromJson(e),
    ];
  }

  /// `DELETE /inventory/collections/{id}/invites/{invite_id}` (§2.5, owner).
  Future<void> revokeInvite(String token, String collectionId, String inviteId) async {
    await _send(() => _client.delete(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}/invites/${Uri.encodeComponent(inviteId)}'),
          headers: _headers(token: token, inventoryClient: true),
        ));
  }

  /// `PATCH /inventory/collections/{id}` `{name}` (§2.2, owner) → the new
  /// name as the server stored it (1..60 chars).
  Future<String> renameCollection(String token, String collectionId, String name) async {
    final res = await _send(() => _client.patch(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}'),
          headers: _headers(token: token, json: true, inventoryClient: true),
          body: json.encode({'name': name}),
        ));
    final body = _decodeObject(res);
    return body['name'] as String? ?? name;
  }

  /// `DELETE /inventory/collections/{id}` (§2.3, owner) → 204; soft-deletes
  /// the collection server-side. Further access → `410 collection_deleted`.
  Future<void> deleteCollection(String token, String collectionId) async {
    await _send(() => _client.delete(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}'),
          headers: _headers(token: token, inventoryClient: true),
        ));
  }

  /// `PATCH /inventory/collections/{id}/members/{user_id}` `{role}` (§2.7,
  /// owner): `editor` ↔ `viewer`. 400 for the owner / self.
  Future<void> setMemberRole(String token, String collectionId, String userId, String role) async {
    await _send(() => _client.patch(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}/members/${Uri.encodeComponent(userId)}'),
          headers: _headers(token: token, json: true, inventoryClient: true),
          body: json.encode({'role': role}),
        ));
  }

  /// `POST /inventory/collections/{id}/transfer` `{user_id}` (§2.8, owner)
  /// → the new `owner_user_id`. `402 cloud_required_new_owner` when the
  /// target has no active plan; `404 member_not_found`.
  Future<String> transferOwnership(String token, String collectionId, String userId) async {
    final res = await _send(() => _client.post(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}/transfer'),
          headers: _headers(token: token, json: true, inventoryClient: true),
          body: json.encode({'user_id': userId}),
        ));
    return _decodeObject(res)['owner_user_id'] as String? ?? userId;
  }

  /// `GET /inventory/devices?device_id=<own>` (§2.12) — every non-revoked
  /// device that synced under this account; `current` is computed by the
  /// server from `device_id` (always pass this install's id). Reply is
  /// wrapped `{"devices":[…]}` (a bare list is tolerated).
  Future<List<CloudDevice>> listDevices(String token, {String? deviceId}) async {
    final res = await _send(() => _client.get(
          _uri('/inventory/devices', {
            // The server computes `current` from this; revoked devices are
            // omitted from the list.
            if (deviceId != null && deviceId.isNotEmpty) 'device_id': deviceId,
          }),
          headers: _headers(token: token, inventoryClient: true),
        ));
    final decoded = _decode(res);
    final list = decoded is Map<String, dynamic> ? decoded['devices'] : decoded;
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic> && (e['device_id'] as String? ?? '').isNotEmpty) CloudDevice.fromJson(e),
    ];
  }

  /// `DELETE /inventory/devices/{device_id}` (§2.12) — revoke: that
  /// device's next push/pull gets `403 device_revoked`.
  Future<void> revokeDevice(String token, String deviceId) async {
    await _send(() => _client.delete(
          _uri('/inventory/devices/${Uri.encodeComponent(deviceId)}'),
          headers: _headers(token: token, inventoryClient: true),
        ));
  }

  /// `POST /inventory/collections/join { code }` (§3) → the joined
  /// collection (role `editor`, with `owner_user_id`/`member_count`).
  /// `404 invite_invalid` (unknown / expired / used / malformed) and
  /// `409 already_member` pass through as [PlantlyApiException].
  Future<CloudCollection> joinCollection(String token, String code) async {
    final res = await _send(() => _client.post(
          _uri('/inventory/collections/join'),
          headers: _headers(token: token, json: true, inventoryClient: true),
          body: json.encode({'code': code}),
        ));
    final body = _decodeObject(res);
    final col = body['collection'];
    if (col is! Map<String, dynamic> || (col['id'] as String? ?? '').isEmpty) {
      throw PlantlyApiException(status: res.statusCode, message: 'join reply has no collection');
    }
    return CloudCollection.fromJson(col);
  }

  /// `GET /inventory/collections/{id}/members` (§3).
  Future<List<CollectionMember>> listMembers(String token, String collectionId) async {
    final res = await _send(() => _client.get(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}/members'),
          headers: _headers(token: token, inventoryClient: true),
        ));
    final list = _decodeObject(res)['members'];
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map<String, dynamic>) CollectionMember.fromJson(e),
    ];
  }

  /// `DELETE /inventory/collections/{id}/members/{user_id}` (§3) — the
  /// owner removes a member, or a member removes themself ("Leave").
  /// `409 owner_cannot_leave`, `404 member_not_found`.
  Future<void> removeMember(String token, String collectionId, String userId) async {
    await _send(() => _client.delete(
          _uri('/inventory/collections/${Uri.encodeComponent(collectionId)}/members/${Uri.encodeComponent(userId)}'),
          headers: _headers(token: token, inventoryClient: true),
        ));
  }

  /// `POST /posts/{id}/sold` — owner-only, idempotent.
  Future<void> markSold(String token, String postId) async {
    final res = await _send(() => _client.post(_uri('/posts/$postId/sold'), headers: _headers(token: token)));
    _check(res);
  }

  // --- plumbing ------------------------------------------------------------

  Future<http.Response> _send(Future<http.Response> Function() run, {Duration? timeout}) async {
    final http.Response res;
    try {
      res = await run().timeout(timeout ?? this.timeout);
    } on PlantlyApiException {
      rethrow;
    } catch (e) {
      throw PlantlyNetworkException(e);
    }
    _check(res);
    return res;
  }

  void _check(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    String message = 'HTTP ${res.statusCode}';
    String? code;
    var details = const <String, dynamic>{};
    try {
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) {
        message = body['error'] as String? ?? body['message'] as String? ?? message;
        code = body['code'] as String?;
        details = {
          for (final e in body.entries)
            if (e.key != 'error' && e.key != 'message' && e.key != 'code') e.key: e.value,
        };
      }
    } catch (_) {
      final text = res.body.trim();
      if (text.isNotEmpty && text.length < 200) message = text;
    }
    throw PlantlyApiException(
      status: res.statusCode,
      message: message,
      code: code,
      retryAfter: int.tryParse(res.headers['retry-after'] ?? ''),
      details: details,
    );
  }

  Object? _decode(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    return json.decode(utf8.decode(res.bodyBytes));
  }

  Map<String, dynamic> _decodeObject(http.Response res) {
    final decoded = _decode(res);
    return decoded is Map<String, dynamic> ? decoded : const <String, dynamic>{};
  }

  static String _extFor(String mime) => switch (mime) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
}
