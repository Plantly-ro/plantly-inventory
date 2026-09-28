import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/plantly_hosts.dart';
import 'photo_sync.dart';
import 'sync_transport.dart';

/// Compile-time platform check (no Flutter import needed here): in a browser
/// `followRedirects=false` is not supported by `BrowserClient`.
const bool _isWeb = bool.fromEnvironment('dart.library.js_interop');

/// Supplies the current plantly.ro JWT (typically
/// `() => auth.current().then((s) => s?.token)`); null = signed out.
typedef SyncTokenProvider = Future<String?> Function();

/// HTTP implementation of the sync, usage and photo endpoints under
/// `/api/v1/inventory/collections/{id}` (CLOUD-SYNC-CONTRACT §2.2).
///
/// Error mapping (all methods):
///   401 → [SyncAuthError], 402 → [SyncEntitlementError],
///   403/404 → [SyncCollectionError],
///   413 → [SyncBatchTooLargeError] on `/sync/push`, [SyncQuotaError] on photo routes,
///   429/5xx/network → [SyncRetryableError] (with `Retry-After`),
///   anything else non-2xx → [SyncProtocolError].
class HttpSyncTransport implements SyncTransport, CollectionUsageSource, PhotoTransport {
  HttpSyncTransport({
    required http.Client client,
    required this.collectionId,
    required SyncTokenProvider token,
    String? host,
    this.timeout = const Duration(seconds: 30),
    this.blobTimeout = const Duration(seconds: 120),
    bool? sendUserAgent,
  })  : _client = client,
        _token = token,
        host = host ?? PlantlyHosts.host,
        _sendUserAgent = sendUserAgent ?? PlantlyHosts.canSendUserAgent;

  final http.Client _client;
  final SyncTokenProvider _token;
  final String collectionId;
  final String host;
  final Duration timeout;
  final Duration blobTimeout;
  final bool _sendUserAgent;

  Uri _uri(String path, [Map<String, String>? query]) => Uri.parse(
        '${PlantlyHosts.apiBase(host)}/inventory/collections/$collectionId$path',
      ).replace(queryParameters: query);

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await _token();
    if (token == null || token.isEmpty) throw const SyncAuthError('no session');
    return {
      if (_sendUserAgent) 'User-Agent': PlantlyHosts.userAgent,
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      // Same value as PlantlyApi's cloud routes (§2.2).
      'X-Plantly-Client': PlantlyHosts.clientHeader,
    };
  }

  // --- sync -----------------------------------------------------------------

  @override
  Future<PushResponse> push(PushRequest request) async {
    final res = await _send(
      () async => _client.post(
        _uri('/sync/push'),
        headers: await _headers(json: true),
        body: json.encode(request.toJson()),
      ),
      tooLargeIsBatch: true,
    );
    return PushResponse.fromJson(_object(res));
  }

  @override
  Future<PullResponse> pull(PullRequest request) async {
    final res = await _send(() async => _client.get(
          _uri('/sync/pull', {
            'since': request.since.isEmpty ? '0' : request.since,
            'limit': '${request.limit}',
          }),
          headers: await _headers(),
        ));
    return PullResponse.fromJson(_object(res));
  }

  @override
  Future<CollectionUsage> usage() async {
    final res = await _send(() async => _client.get(_uri('/usage'), headers: await _headers()));
    return CollectionUsage.fromJson(_object(res));
  }

  // --- photos ---------------------------------------------------------------

  @override
  Future<PhotoUploadTicket> requestUpload({
    required String sha256,
    required int bytes,
    required String mime,
  }) async {
    final res = await _send(() async => _client.post(
          _uri('/photos/upload-url'),
          headers: await _headers(json: true),
          body: json.encode({'sha256': sha256, 'bytes': bytes, 'mime': mime}),
        ));
    final body = _object(res);
    final upload = body['upload'];
    final u = upload is Map<String, dynamic> ? upload : const <String, dynamic>{};
    final rawHeaders = u['headers'];
    return PhotoUploadTicket(
      alreadyStored: body['already_stored'] == true,
      url: u['url'] as String?,
      method: (u['method'] as String?) ?? 'PUT',
      headers: rawHeaders is Map ? {for (final e in rawHeaders.entries) '${e.key}': '${e.value}'} : const {},
    );
  }

  @override
  Future<void> putBlob(PhotoUploadTicket ticket, Uint8List bytes, {required String mime}) async {
    final url = ticket.url;
    if (url == null || url.isEmpty) throw const SyncProtocolError('upload ticket has no url');
    // Presigned URL: NO bearer token (S3 rejects mixed auth), only what the
    // server told us to send. Content-Type must match the signature when it
    // was included; otherwise a bare PUT is fine.
    final headers = {
      if (!ticket.headers.keys.any((k) => k.toLowerCase() == 'content-type')) 'Content-Type': mime,
      ...ticket.headers,
    };
    final req = http.Request(ticket.method, Uri.parse(url))
      ..headers.addAll(headers)
      ..bodyBytes = bytes;
    await _send(
      () async => http.Response.fromStream(await _client.send(req)),
      timeout: blobTimeout,
    );
  }

  @override
  Future<void> completeUpload(String sha256) async {
    await _send(() async => _client.post(_uri('/photos/$sha256/complete'), headers: await _headers()));
  }

  @override
  Future<Uint8List> download(String sha256) async {
    // One code path for io and web: ask the API for the object location as
    // JSON (`Accept: application/json` → `200 {"url","expires_at"}`) and
    // fetch the bytes from that URL with NO bearer token (S3 rejects mixed
    // auth). The old redirect trick — `followRedirects=false` + manual GET —
    // is gone: `BrowserClient` maps it to fetch `redirect:'error'`, which
    // made every photo fail on web. Fallbacks for an older server that
    // still answers 302: on io we can block the redirect and use its
    // Location; in a browser the redirect is followed transparently (the
    // browser strips Authorization cross-origin) and the bytes arrive here.
    final res = await _send(() async {
      final req = http.Request('GET', _uri('/photos/$sha256'))
        ..headers.addAll(await _headers())
        ..followRedirects = _isWeb;
      return http.Response.fromStream(await _client.send(req));
    }, allowRedirect: true);
    if (res.statusCode >= 300 && res.statusCode < 400) {
      return _fetchBlob(_locationOf(res, sha256, res.headers['location'], what: 'photo redirect'));
    }
    final url = _jsonUrl(res);
    if (url != null) return _fetchBlob(_locationOf(res, sha256, url, what: 'photo location'));
    // Not JSON: the redirect was followed for us — these are the bytes.
    return res.bodyBytes;
  }

  /// `url` from a JSON `{"url": …}` reply, null when the body is not that.
  String? _jsonUrl(http.Response res) {
    final type = res.headers['content-type'] ?? '';
    final looksJson = type.contains('json') ||
        (res.bodyBytes.isNotEmpty && res.bodyBytes.first == 0x7B /* '{' */);
    if (!looksJson) return null;
    try {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final url = decoded['url'];
        if (url is String && url.isNotEmpty) return url;
        throw const SyncProtocolError('photo location without url');
      }
    } on FormatException {
      // binary that happened to start with '{' — treat as bytes
    }
    return null;
  }

  Uri _locationOf(http.Response res, String sha256, String? raw, {required String what}) {
    if (raw == null || raw.isEmpty) throw SyncProtocolError('$what without location');
    final target = Uri.parse(raw);
    return target.hasScheme ? target : _uri('/photos/$sha256').resolveUri(target);
  }

  /// Bare GET (no bearer, no client headers) of a presigned object URL.
  Future<Uint8List> _fetchBlob(Uri target) async {
    final blob = await _send(() => _client.get(target), timeout: blobTimeout);
    return blob.bodyBytes;
  }

  // --- plumbing -------------------------------------------------------------

  Future<http.Response> _send(
    Future<http.Response> Function() run, {
    Duration? timeout,
    bool allowRedirect = false,
    bool tooLargeIsBatch = false,
  }) async {
    final http.Response res;
    try {
      res = await run().timeout(timeout ?? this.timeout);
    } on SyncError {
      rethrow;
    } catch (e) {
      throw SyncRetryableError('network: $e');
    }
    _check(res, allowRedirect: allowRedirect, tooLargeIsBatch: tooLargeIsBatch);
    return res;
  }

  void _check(http.Response res, {bool allowRedirect = false, bool tooLargeIsBatch = false}) {
    final s = res.statusCode;
    if (s >= 200 && s < 300) return;
    if (allowRedirect && s >= 300 && s < 400) return;
    String code = 'HTTP $s';
    Map<String, dynamic> body = const {};
    try {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        body = decoded;
        code = decoded['error'] as String? ?? decoded['code'] as String? ?? code;
      }
    } catch (_) {
      // non-JSON error body — keep the HTTP status as the message
    }
    switch (s) {
      case 401:
        throw SyncAuthError(code);
      case 402:
        throw SyncEntitlementError(code);
      case 403:
      case 404:
        throw SyncCollectionError(code, status: s);
      case 413:
        if (tooLargeIsBatch) throw SyncBatchTooLargeError(code);
        throw SyncQuotaError(
          bytesQuota: (body['bytes_quota'] as num?)?.toInt(),
          bytesStored: (body['bytes_stored'] as num?)?.toInt(),
        );
      case 429:
        throw SyncRetryableError(code, status: s, retryAfter: _retryAfter(res));
    }
    if (s >= 500) throw SyncRetryableError(code, status: s, retryAfter: _retryAfter(res));
    throw SyncProtocolError(code, status: s);
  }

  Duration? _retryAfter(http.Response res) {
    final raw = res.headers['retry-after'];
    if (raw == null) return null;
    final secs = int.tryParse(raw.trim());
    if (secs != null) return Duration(seconds: secs);
    final date = _tryParseHttpDate(raw);
    if (date == null) return null;
    final d = date.difference(DateTime.now().toUtc());
    return d.isNegative ? Duration.zero : d;
  }

  DateTime? _tryParseHttpDate(String raw) {
    try {
      return DateTime.parse(raw).toUtc();
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _object(http.Response res) {
    if (res.bodyBytes.isEmpty) return const {};
    final decoded = json.decode(utf8.decode(res.bodyBytes));
    if (decoded is Map<String, dynamic>) return decoded;
    throw SyncProtocolError('unexpected body', status: res.statusCode);
  }
}
