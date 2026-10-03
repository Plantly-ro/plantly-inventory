import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/config/plantly_hosts.dart';
import 'package:plantly_inventory/sync/http_sync_transport.dart';
import 'package:plantly_inventory/sync/photo_sync.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

void main() {
  const host = 'https://dev.example';
  const base = '$host/api/v1/inventory/collections/col-1';

  HttpSyncTransport transport(
    Future<http.Response> Function(http.Request) handler, {
    List<http.Request>? log,
    String? token = 'tok',
    SyncDeviceMeta? deviceMeta,
  }) {
    return HttpSyncTransport(
      client: MockClient((req) {
        log?.add(req);
        return handler(req);
      }),
      collectionId: 'col-1',
      token: () async => token,
      host: host,
      sendUserAgent: true,
      deviceMeta: deviceMeta,
    );
  }

  http.Response jsonRes(Object body, [int status = 200, Map<String, String>? headers]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json', ...?headers});

  group('push', () {
    test('POSTs the contract body with auth + client headers and parses the reply', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (req) async {
        return jsonRes({
          'accepted': 1,
          'rejected': [
            {'op_index': 1, 'reason': 'hlc_future'}
          ],
          'cursor': '17',
          'fresh_ops': [
            {'entity': 'plants', 'entity_id': 'p9', 'field': 'notes', 'value': 'x', 'hlc': '00000000000000009-00000-dev-b', 'device_id': 'dev-b', 'seq': 17}
          ],
          'has_more': true,
        });
      });
      final res = await t.push(PushRequest(deviceId: 'dev-a', since: '', ops: const [
        SyncOpDto(entity: 'plants', entityId: 'p1', field: '*', value: {'nickname': 'Bob'}, hlc: '00000000000000001-00000-dev-a'),
        SyncOpDto(entity: 'plants', entityId: 'p1', field: '__tombstone__', value: null, hlc: '00000000000000002-00000-dev-a'),
      ]));

      final req = log.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), '$base/sync/push');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.headers['X-Plantly-Client'], PlantlyHosts.clientHeader);
      expect(req.headers['Accept'], 'application/json');
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(req.headers['User-Agent'], startsWith('PlantlyInventory/'));
      expect(json.decode(req.body), {
        'device_id': 'dev-a',
        'since': '0',
        'ops': [
          {'entity': 'plants', 'entity_id': 'p1', 'field': '*', 'value': {'nickname': 'Bob'}, 'hlc': '00000000000000001-00000-dev-a'},
          {'entity': 'plants', 'entity_id': 'p1', 'field': '__tombstone__', 'value': null, 'hlc': '00000000000000002-00000-dev-a'},
        ],
      });

      expect(res.accepted, 1);
      expect(res.rejected.single.opIndex, 1);
      expect(res.rejected.single.reason, 'hlc_future');
      expect(res.cursor, '17');
      expect(res.hasMore, isTrue);
      expect(res.freshOps.single.entityId, 'p9');
      expect(res.freshOps.single.deviceId, 'dev-b');
      expect(res.freshOps.single.seq, '17');
    });

    test('sends the persisted cursor as since', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (_) async => jsonRes({'accepted': 0, 'cursor': '42'}));
      await t.push(const PushRequest(deviceId: 'dev-a', since: '42', ops: []));
      expect(json.decode(log.single.body)['since'], '42');
    });
  });

  group('pull', () {
    test('GETs with since/limit and parses ops + cursor (numeric tolerated)', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (_) async {
        return jsonRes({
          'ops': [
            {'entity': 'tags', 'entity_id': 't1', 'field': '*', 'value': {'name': 'sun'}, 'hlc': '00000000000000003-00000-dev-b', 'device_id': 'dev-b', 'seq': '3'}
          ],
          'cursor': 3,
          'has_more': false,
        });
      });
      final res = await t.pull(const PullRequest(since: '2', limit: 100));
      final req = log.single;
      expect(req.method, 'GET');
      expect(req.url.toString(), '$base/sync/pull?since=2&limit=100');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(res.ops.single.entity, 'tags');
      expect(res.ops.single.value, {'name': 'sun'});
      expect(res.cursor, '3');
      expect(res.hasMore, isFalse);
    });

    test('empty since goes out as 0', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (_) async => jsonRes({'ops': [], 'cursor': '0', 'has_more': false}));
      await t.pull(const PullRequest(since: ''));
      expect(log.single.url.queryParameters['since'], '0');
    });
  });

  group('device meta (MULTI-USER-V2 §2.12)', () {
    const meta = SyncDeviceMeta(deviceId: 'dev-a', deviceName: 'Pixel 8', appVersion: '1.2.3', platform: 'android');
    const metaHeaders = ['X-Plantly-Device-Name', 'X-Plantly-App-Version', 'X-Plantly-Platform'];
    final emptyPush = jsonRes({'accepted': 0, 'rejected': [], 'cursor': '0', 'fresh_ops': [], 'has_more': false});
    final emptyPull = jsonRes({'ops': [], 'cursor': '0', 'has_more': false});

    test('push sends the three headers', () async {
      final log = <http.Request>[];
      final t = transport(log: log, deviceMeta: meta, (_) async => emptyPush);
      await t.push(const PushRequest(deviceId: 'dev-a', since: '0', ops: []));
      final h = log.single.headers;
      expect(h['X-Plantly-Device-Name'], 'Pixel 8');
      expect(h['X-Plantly-App-Version'], '1.2.3');
      expect(h['X-Plantly-Platform'], 'android');
    });

    test('pull sends the three headers + ?device_id= when meta.deviceId is set', () async {
      final log = <http.Request>[];
      final t = transport(log: log, deviceMeta: meta, (_) async => emptyPull);
      await t.pull(const PullRequest(since: '0'));
      final req = log.single;
      expect(req.headers['X-Plantly-Device-Name'], 'Pixel 8');
      expect(req.headers['X-Plantly-App-Version'], '1.2.3');
      expect(req.headers['X-Plantly-Platform'], 'android');
      expect(req.url.queryParameters['device_id'], 'dev-a');
      expect(req.url.queryParameters['since'], '0');
    });

    test('pull without meta.deviceId carries no device_id query', () async {
      final log = <http.Request>[];
      const noId = SyncDeviceMeta(deviceName: 'Pixel 8', appVersion: '1.2.3', platform: 'android');
      final t = transport(log: log, deviceMeta: noId, (_) async => emptyPull);
      await t.pull(const PullRequest(since: '0'));
      expect(log.single.url.queryParameters.containsKey('device_id'), isFalse);
      expect(log.single.headers['X-Plantly-Platform'], 'android');
    });

    test('/usage and photo routes do NOT carry the device headers', () async {
      final log = <http.Request>[];
      final t = transport(log: log, deviceMeta: meta, (req) async {
        if (req.url.path.endsWith('/usage')) return jsonRes({'bytes_stored': 1, 'bytes_quota': 2});
        if (req.url.path.endsWith('/photos/upload-url')) {
          return jsonRes({'url': '$host/put', 'headers': {}, 'already_stored': false});
        }
        return jsonRes({}, 200);
      });
      await t.usage();
      await t.requestUpload(sha256: 'a', bytes: 1, mime: 'image/jpeg');
      await t.completeUpload('a');
      expect(log, hasLength(3));
      for (final req in log) {
        for (final name in metaHeaders) {
          expect(req.headers.containsKey(name), isFalse, reason: '$name on ${req.url.path}');
        }
        expect(req.url.queryParameters.containsKey('device_id'), isFalse);
      }
    });

    test('without deviceMeta none of the headers go out', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (req) async => req.method == 'POST' ? emptyPush : emptyPull);
      await t.push(const PushRequest(deviceId: 'dev-a', since: '0', ops: []));
      await t.pull(const PullRequest(since: '0'));
      for (final req in log) {
        for (final name in metaHeaders) {
          expect(req.headers.containsKey(name), isFalse, reason: '$name on ${req.url.path}');
        }
        expect(req.url.queryParameters.containsKey('device_id'), isFalse);
      }
    });

    test('headerSafe: diacritics fold, other non-ASCII → ?, whitespace collapsed, capped at 80', () {
      expect(SyncDeviceMeta.headerSafe('Pixel — Mária'), 'Pixel ? Maria');
      expect(SyncDeviceMeta.headerSafe('Șerban Țicu ăâî ÄÖÜ ß'), 'Serban Ticu aai AOU ss');
      expect(SyncDeviceMeta.headerSafe('Galaxy 日本'), 'Galaxy ??');
      expect(SyncDeviceMeta.headerSafe('  a \t\n b   c '), 'a b c');
      expect(SyncDeviceMeta.headerSafe('x' * 200), hasLength(80));
      expect(SyncDeviceMeta.headerSafe('x' * 200), 'x' * 80);
      // Headers skip empty values.
      expect(const SyncDeviceMeta(deviceName: '', appVersion: '1', platform: 'web').headers.keys,
          ['X-Plantly-App-Version', 'X-Plantly-Platform']);
    });
  });

  group('error mapping', () {
    Future<void> expectError(int status, Matcher matcher, {Map<String, String>? headers, Object body = const {'error': 'x'}}) async {
      final t = transport((_) async => jsonRes(body, status, headers));
      await expectLater(t.pull(const PullRequest(since: '0')), throwsA(matcher));
    }

    test('401 → SyncAuthError', () => expectError(401, isA<SyncAuthError>()));
    test('402 → SyncEntitlementError with the server code', () => expectError(
        402, isA<SyncEntitlementError>().having((e) => e.message, 'message', 'cloud_required'),
        body: {'error': 'cloud_required'}));
    test('403 → SyncCollectionError(403)', () =>
        expectError(403, isA<SyncCollectionError>().having((e) => e.status, 'status', 403).having((e) => e.message, 'message', 'not_a_member'), body: {'error': 'not_a_member'}));
    test('404 → SyncCollectionError(404)', () => expectError(404, isA<SyncCollectionError>().having((e) => e.status, 'status', 404)));
    test('403 device_revoked → SyncCollectionError with that message', () => expectError(
        403, isA<SyncCollectionError>().having((e) => e.status, 'status', 403).having((e) => e.message, 'message', 'device_revoked'),
        body: {'error': 'device_revoked'}));
    test('410 collection_deleted → SyncCollectionError(410)', () => expectError(
        410, isA<SyncCollectionError>().having((e) => e.status, 'status', 410).having((e) => e.message, 'message', 'collection_deleted'),
        body: {'error': 'collection_deleted'}));
    test('429 → SyncRetryableError with Retry-After', () => expectError(
        429, isA<SyncRetryableError>().having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 7)).having((e) => e.status, 'status', 429),
        headers: {'retry-after': '7'}));
    test('503 → SyncRetryableError', () => expectError(503, isA<SyncRetryableError>().having((e) => e.status, 'status', 503)));
    test('400 → SyncProtocolError', () => expectError(400, isA<SyncProtocolError>()));
    test('400 too_many_devices → SyncCollectionError(400) (halt, not a retry)', () => expectError(
        400, isA<SyncCollectionError>().having((e) => e.status, 'status', 400).having((e) => e.message, 'message', 'too_many_devices'),
        body: {'error': 'too_many_devices'}));
    test('400 with another code stays a SyncProtocolError', () =>
        expectError(400, isA<SyncProtocolError>(), body: {'error': 'bad_request'}));
    test('503 device_lookup_failed → SyncRetryableError carrying the code', () => expectError(
        503, isA<SyncRetryableError>().having((e) => e.status, 'status', 503).having((e) => e.message, 'message', 'device_lookup_failed'),
        body: {'error': 'device_lookup_failed'}));
    test('413 on /sync/push → SyncBatchTooLargeError (not quota)', () async {
      final t = transport((_) async => jsonRes({'error': 'too_large'}, 413));
      await expectLater(
        t.push(const PushRequest(deviceId: 'd', since: '0', ops: [])),
        throwsA(isA<SyncBatchTooLargeError>()),
      );
    });
    test('413 on photos/upload-url → SyncQuotaError', () async {
      final t = transport((_) async => jsonRes({'error': 'quota_exceeded', 'bytes_quota': 5}, 413));
      await expectLater(
        t.requestUpload(sha256: 'a', bytes: 1, mime: 'image/jpeg'),
        throwsA(isA<SyncQuotaError>().having((e) => e.bytesQuota, 'quota', 5)),
      );
    });
    test('413 elsewhere → SyncQuotaError with bytes', () => expectError(
        413, isA<SyncQuotaError>().having((e) => e.bytesQuota, 'quota', 2048).having((e) => e.bytesStored, 'stored', 2000),
        body: {'error': 'quota_exceeded', 'bytes_quota': 2048, 'bytes_stored': 2000}));

    test('network failure → SyncRetryableError without status', () async {
      final t = transport((_) async => throw http.ClientException('boom'));
      await expectLater(
        t.pull(const PullRequest(since: '0')),
        throwsA(isA<SyncRetryableError>().having((e) => e.status, 'status', isNull)),
      );
    });

    test('no session token → SyncAuthError before any request', () async {
      var called = false;
      final t = transport(token: null, (_) async {
        called = true;
        return jsonRes({});
      });
      await expectLater(t.pull(const PullRequest(since: '0')), throwsA(isA<SyncAuthError>()));
      expect(called, isFalse);
    });
  });

  test('usage parses bytes + quota', () async {
    final log = <http.Request>[];
    final t = transport(log: log, (_) async => jsonRes({'bytes_stored': 123, 'bytes_quota': 456, 'ops_count': 7}));
    final u = await t.usage();
    expect(log.single.url.toString(), '$base/usage');
    expect(u.bytesStored, 123);
    expect(u.bytesQuota, 456);
    expect(u.opsCount, 7);
  });

  group('photos', () {
    test('requestUpload posts sha/bytes/mime and parses the ticket', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (_) async {
        return jsonRes({
          'upload': {'url': 'https://r2.example/put?sig=1', 'method': 'PUT', 'headers': {'Content-Type': 'image/jpeg'}, 'expires_at': 'x'},
          'already_stored': false,
        });
      });
      final ticket = await t.requestUpload(sha256: 'abc', bytes: 3, mime: 'image/jpeg');
      expect(log.single.url.toString(), '$base/photos/upload-url');
      expect(json.decode(log.single.body), {'sha256': 'abc', 'bytes': 3, 'mime': 'image/jpeg'});
      expect(ticket.alreadyStored, isFalse);
      expect(ticket.url, 'https://r2.example/put?sig=1');
      expect(ticket.headers, {'Content-Type': 'image/jpeg'});
    });

    test('already_stored:true comes through', () async {
      final t = transport((_) async => jsonRes({'already_stored': true}));
      final ticket = await t.requestUpload(sha256: 'abc', bytes: 3, mime: 'image/jpeg');
      expect(ticket.alreadyStored, isTrue);
      expect(ticket.url, isNull);
    });

    test('putBlob PUTs raw bytes to the presigned URL with only the ticket headers (no bearer)', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (_) async => http.Response('', 200));
      final bytes = Uint8List.fromList([1, 2, 3]);
      await t.putBlob(
        const PhotoUploadTicket(alreadyStored: false, url: 'https://r2.example/put?sig=1', headers: {'x-amz-meta-a': 'b'}),
        bytes,
        mime: 'image/png',
      );
      final req = log.single;
      expect(req.method, 'PUT');
      expect(req.url.toString(), 'https://r2.example/put?sig=1');
      expect(req.bodyBytes, [1, 2, 3]);
      expect(req.headers.containsKey('Authorization'), isFalse);
      expect(req.headers['x-amz-meta-a'], 'b');
      expect(req.headers['Content-Type'], 'image/png');
    });

    test('completeUpload posts to /photos/{sha}/complete', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (_) async => jsonRes({'state': 'stored', 'bytes': 3}));
      await t.completeUpload('abc');
      expect(log.single.method, 'POST');
      expect(log.single.url.toString(), '$base/photos/abc/complete');
    });

    test('download asks for JSON (Accept) and fetches {url} with a bare client (no bearer)', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (req) async {
        if (req.url.path.endsWith('/photos/abc')) {
          return jsonRes({'url': 'https://r2.example/get?sig=1', 'expires_at': '2026-09-27T12:00:00Z'});
        }
        return http.Response.bytes([1, 2, 3], 200, headers: {'content-type': 'image/jpeg'});
      });
      final bytes = await t.download('abc');
      expect(bytes, [1, 2, 3]);
      expect(log, hasLength(2));
      expect(log[0].url.toString(), '$base/photos/abc');
      expect(log[0].headers['Accept'], 'application/json');
      expect(log[0].headers['Authorization'], 'Bearer tok');
      expect(log[0].followRedirects, isFalse, reason: 'io: a 302 fallback must expose Location so the blob is fetched without the bearer');
      expect(log[1].url.toString(), 'https://r2.example/get?sig=1');
      expect(log[1].headers.containsKey('Authorization'), isFalse);
      expect(log[1].headers.containsKey('X-Plantly-Client'), isFalse);
    });

    test('download falls back to the 302 Location (older server) without the bearer token', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (req) async {
        if (req.url.path.endsWith('/photos/abc')) {
          return http.Response('', 302, headers: {'location': 'https://r2.example/get?sig=2'});
        }
        return http.Response.bytes([9, 8], 200);
      });
      final bytes = await t.download('abc');
      expect(bytes, [9, 8]);
      expect(log, hasLength(2));
      expect(log[0].url.toString(), '$base/photos/abc');
      expect(log[1].url.toString(), 'https://r2.example/get?sig=2');
      expect(log[1].headers.containsKey('Authorization'), isFalse);
    });

    test('download: a transparently followed redirect (browser) yields the bytes directly', () async {
      final log = <http.Request>[];
      final t = transport(log: log, (_) async => http.Response.bytes([7, 7], 200, headers: {'content-type': 'image/png'}));
      expect(await t.download('abc'), [7, 7]);
      expect(log, hasLength(1));
    });

    test('download: JSON reply without url → SyncProtocolError; relative url resolves against the API', () async {
      final t = transport((_) async => jsonRes({'expires_at': 'x'}));
      await expectLater(t.download('abc'), throwsA(isA<SyncProtocolError>()));

      final log = <http.Request>[];
      final t2 = transport(log: log, (req) async {
        if (req.url.path.endsWith('/photos/abc')) return jsonRes({'url': '/blobs/abc?sig=3'});
        return http.Response.bytes([4], 200);
      });
      expect(await t2.download('abc'), [4]);
      expect(log[1].url.toString(), '$host/blobs/abc?sig=3');
    });

    test('download 404 → SyncCollectionError(404)', () async {
      final t = transport((_) async => jsonRes({'error': 'not_found'}, 404));
      await expectLater(t.download('abc'), throwsA(isA<SyncCollectionError>()));
    });
  });
}
