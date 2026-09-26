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
  });

  final int status;
  final String message;
  final String? code;

  /// Seconds from the `Retry-After` header on 429s, when present.
  final int? retryAfter;

  bool get isUnauthorized => status == 401;
  bool get isRateLimited => status == 429;

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

/// One server-side inventory collection (CLOUD-SYNC-CONTRACT §2.2).
class CloudCollection {
  const CloudCollection({required this.id, required this.name, required this.role, this.createdAt});
  final String id;
  final String name;
  final String role;
  final DateTime? createdAt;

  factory CloudCollection.fromJson(Map<String, dynamic> m) => CloudCollection(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        role: m['role'] as String? ?? 'owner',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? ''),
      );
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
    try {
      final body = json.decode(utf8.decode(res.bodyBytes));
      if (body is Map<String, dynamic>) {
        message = body['error'] as String? ?? body['message'] as String? ?? message;
        code = body['code'] as String?;
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
