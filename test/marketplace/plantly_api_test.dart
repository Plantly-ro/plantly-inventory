import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';

import 'multipart_parser.dart';

void main() {
  const host = 'https://dev.example';

  PlantlyApi api(Future<http.Response> Function(http.Request) handler, {List<http.Request>? log}) {
    return PlantlyApi(
      client: MockClient((req) {
        log?.add(req);
        return handler(req);
      }),
      host: host,
      sendUserAgent: true,
    );
  }

  group('login', () {
    test('POSTs JSON to /api/v1/auth/login with UA + Accept and parses token/user', () async {
      final log = <http.Request>[];
      final a = api(log: log, (req) async {
        return http.Response(
          json.encode({
            'token': 't.o.k',
            'user': {'id': 'u1', 'username': 'alice', 'email': 'alice@plantly.local'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final r = await a.login('alice@plantly.local', 'plantly123');
      expect(r.token, 't.o.k');
      expect(r.username, 'alice');
      expect(r.userId, 'u1');
      final req = log.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), '$host/api/v1/auth/login');
      expect(req.headers['Content-Type'], startsWith('application/json'));
      expect(req.headers['User-Agent'], 'PlantlyInventory/dev (+https://plantly.ro/app/inventory)');
      expect(json.decode(req.body), {'email': 'alice@plantly.local', 'password': 'plantly123'});
    });

    test('401 → PlantlyApiException(401) with server message', () async {
      final a = api((_) async => http.Response('{"error":"invalid credentials"}', 401));
      await expectLater(
        a.login('x', 'y'),
        throwsA(isA<PlantlyApiException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.message, 'message', 'invalid credentials')
            .having((e) => e.code, 'code', isNull)),
      );
    });

    test('403 carries the stable code (email_not_verified / account_suspended)', () async {
      for (final code in ['email_not_verified', 'account_suspended']) {
        final a = api((_) async => http.Response('{"error":"nope","code":"$code"}', 403));
        await expectLater(
          a.login('x', 'y'),
          throwsA(isA<PlantlyApiException>().having((e) => e.status, 'status', 403).having((e) => e.code, 'code', code)),
        );
      }
    });

    test('429 exposes Retry-After', () async {
      final a = api((_) async => http.Response('{"error":"slow down"}', 429, headers: {'retry-after': '42'}));
      await expectLater(
        a.login('x', 'y'),
        throwsA(isA<PlantlyApiException>()
            .having((e) => e.isRateLimited, 'rateLimited', isTrue)
            .having((e) => e.retryAfter, 'retryAfter', 42)),
      );
    });

    test('transport failure → PlantlyNetworkException', () async {
      final a = api((_) async => throw http.ClientException('boom'));
      await expectLater(a.login('x', 'y'), throwsA(isA<PlantlyNetworkException>()));
    });
  });

  test('refresh sends the old token as Bearer and returns the new one', () async {
    final log = <http.Request>[];
    final a = api(log: log, (_) async => http.Response('{"token":"new.t.k"}', 200));
    expect(await a.refresh('old.t.k'), 'new.t.k');
    expect(log.single.url.path, '/api/v1/auth/refresh');
    expect(log.single.headers['Authorization'], 'Bearer old.t.k');
  });

  test('searchCategories builds the §5 query and maps hits', () async {
    final log = <http.Request>[];
    final a = api(log: log, (_) async {
      // Real server bodies are UTF-8 (the ' › ' path joiner is non-Latin-1);
      // the client must decode bodyBytes as UTF-8 regardless of headers.
      return http.Response.bytes(
        utf8.encode(json.encode([
          {'id': 'c1', 'slug': 'monstera-deliciosa', 'name': 'Monstera deliciosa', 'path': 'Plante › Monstera deliciosa', 'score': 0.93},
          {'id': 'c2', 'slug': 'monstera-adansonii', 'name': 'Monstera adansonii', 'path': 'Plante › Monstera adansonii', 'score': 0.5},
        ])),
        200,
      );
    });
    final hits = await a.searchCategories('monstera', lang: 'ro', limit: 10);
    expect(hits.map((h) => h.id), ['c1', 'c2']);
    expect(hits.first.path, 'Plante › Monstera deliciosa');
    expect(hits.first.score, 0.93);
    final q = log.single.url.queryParameters;
    expect(q, {'q': 'monstera', 'lang': 'ro', 'limit': '10', 'approved_only': '1'});
    expect(log.single.url.path, '/api/v1/categories/search');
  });

  test('createPost sends every §5 field + repeated images parts and parses id/upload_warnings', () async {
    final log = <http.Request>[];
    final a = api(log: log, (_) async {
      return http.Response(
        json.encode({'id': 'post-1', 'status': 'active', 'upload_warnings': ['image 2: too small']}),
        201,
      );
    });
    final result = await a.createPost(
      token: 'jwt',
      title: 'Monstera',
      description: 'Big leaves',
      price: '45',
      categoryId: 'c1',
      county: 'Cluj',
      city: 'Cluj-Napoca',
      images: [
        UploadImage(bytes: Uint8ListX.of([1, 2, 3]), fileName: 'photo-1.jpg'),
        UploadImage(bytes: Uint8ListX.of([4, 5]), fileName: 'photo-2.jpg'),
      ],
    );
    expect(result.id, 'post-1');
    expect(result.uploadWarnings, ['image 2: too small']);

    final req = log.single;
    expect(req.method, 'POST');
    expect(req.url.path, '/api/v1/posts');
    expect(req.headers['Authorization'], 'Bearer jwt');
    final parsed = parseMultipart(req);
    expect(parsed.fields, {
      'title': 'Monstera',
      'description': 'Big leaves',
      'price': '45',
      'category_id': 'c1',
      'state': 'Romania',
      'county': 'Cluj',
      'city': 'Cluj-Napoca',
      'delivery_pickup': 'true',
      'delivery_seller': 'false',
      'delivery_courier': 'false',
    });
    expect(parsed.files.map((f) => f.name), ['images', 'images']);
    expect(parsed.files.map((f) => f.filename), ['photo-1.jpg', 'photo-2.jpg']);
    expect(parsed.files.map((f) => f.contentType), everyElement('image/jpeg'));
    expect(parsed.files[0].bytes, [1, 2, 3]);
    expect(parsed.files[1].bytes, [4, 5]);
  });

  test('createPost treats a 2xx without an id as a server error', () async {
    final a = api((_) async => http.Response('{"status":"active"}', 201));
    await expectLater(
      a.createPost(token: 't', title: 'x', description: '', price: '1', categoryId: 'c', images: [
        UploadImage(bytes: Uint8ListX.of([1])),
      ]),
      throwsA(isA<PlantlyApiException>().having((e) => e.status, 'status', 201)),
    );
  });

  test('createPost surfaces 429 with retry hint', () async {
    final a = api((_) async => http.Response('{"error":"rate limited"}', 429, headers: {'retry-after': '30'}));
    await expectLater(
      a.createPost(token: 't', title: 'x', description: '', price: '1', categoryId: 'c', images: [
        UploadImage(bytes: Uint8ListX.of([1])),
      ]),
      throwsA(isA<PlantlyApiException>().having((e) => e.retryAfter, 'retryAfter', 30)),
    );
  });

  test('markSold POSTs /posts/{id}/sold with the bearer token', () async {
    final log = <http.Request>[];
    final a = api(log: log, (_) async => http.Response('{"status":"sold"}', 200));
    await a.markSold('jwt', 'post-9');
    expect(log.single.method, 'POST');
    expect(log.single.url.path, '/api/v1/posts/post-9/sold');
    expect(log.single.headers['Authorization'], 'Bearer jwt');
  });

  group('shared collections (CLOUD-SYNC-CONTRACT §3)', () {
    test('fetchCollections: top-level caller_entitled parsed (MULTI-USER-V2 §8); absent / bare array / non-bool → true', () async {
      final withFlag = api((_) async => http.Response(
            json.encode({
              'collections': [
                {'id': 'c2', 'name': 'Shared', 'role': 'editor', 'owner_user_id': 'u2', 'member_count': 3},
              ],
              'caller_entitled': false,
            }),
            200,
          ));
      final listing = await withFlag.fetchCollections('tok');
      expect(listing.callerEntitled, isFalse);
      expect(listing.items.map((c) => c.id), ['c2']);
      expect((await withFlag.listCollections('tok')).single.id, 'c2', reason: 'items unchanged');

      final absent = api((_) async => http.Response(json.encode({'collections': []}), 200));
      expect((await absent.fetchCollections('tok')).callerEntitled, isTrue);
      final bare = api((_) async => http.Response(json.encode([{'id': 'c3', 'name': 'x'}]), 200));
      expect((await bare.fetchCollections('tok')).callerEntitled, isTrue);
      final odd = api((_) async => http.Response(json.encode({'collections': [], 'caller_entitled': 'no'}), 200));
      expect((await odd.fetchCollections('tok')).callerEntitled, isTrue);
      final yes = api((_) async => http.Response(json.encode({'collections': [], 'caller_entitled': true}), 200));
      expect((await yes.fetchCollections('tok')).callerEntitled, isTrue);
    });

    test('listCollections: GET /inventory/collections with client header → id/name/role/owner/member_count', () async {
      final log = <http.Request>[];
      final a = api(log: log, (_) async => http.Response(
            json.encode({
              'collections': [
                {'id': 'c1', 'name': 'Mine', 'role': 'owner', 'owner_user_id': 'u1', 'member_count': 1},
                {'id': 'c2', 'name': 'Shared', 'role': 'editor', 'owner_user_id': 'u2', 'member_count': 3},
              ]
            }),
            200,
          ));
      final cols = await a.listCollections('tok');
      expect(log.single.method, 'GET');
      expect(log.single.url.toString(), '$host/api/v1/inventory/collections');
      expect(log.single.headers['Authorization'], 'Bearer tok');
      expect(log.single.headers['X-Plantly-Client'], startsWith('inventory/'));
      expect(cols.map((c) => c.id), ['c1', 'c2']);
      expect(cols[0].isOwner, isTrue);
      expect(cols[1].role, 'editor');
      expect(cols[1].ownerUserId, 'u2');
      expect(cols[1].memberCount, 3);
      // A bare array is tolerated too; rows without an id are dropped.
      final b = api((_) async => http.Response(json.encode([{'id': 'c3', 'name': 'x'}, {'name': 'no id'}]), 200));
      expect((await b.listCollections('tok')).map((c) => c.id), ['c3']);
      expect((await b.listCollections('tok')).single.memberCount, 1);
    });

    test('createInvite: POST …/{id}/invites → code/url/expires_at; missing code = broken reply', () async {
      final log = <http.Request>[];
      final a = api(log: log, (_) async => http.Response(
            json.encode({'code': 'ABCDEFGH', 'url': 'https://plantly.ro/app/inventory/join#c=ABCDEFGH', 'expires_at': '2026-10-04T10:00:00Z'}),
            201,
          ));
      final inv = await a.createInvite('tok', 'c1');
      expect(log.single.method, 'POST');
      expect(log.single.url.toString(), '$host/api/v1/inventory/collections/c1/invites');
      expect(log.single.headers['X-Plantly-Client'], startsWith('inventory/'));
      expect(inv.code, 'ABCDEFGH');
      expect(inv.url, endsWith('/join#c=ABCDEFGH'));
      expect(inv.expiresAt, DateTime.utc(2026, 10, 4, 10));
      // Enveloped variant.
      final b = api((_) async => http.Response(json.encode({'invite': {'code': 'HGFEDCBA', 'url': 'u'}}), 200));
      expect((await b.createInvite('tok', 'c1')).code, 'HGFEDCBA');
      final c = api((_) async => http.Response('{}', 200));
      await expectLater(c.createInvite('tok', 'c1'), throwsA(isA<PlantlyApiException>()));
      // Server limits: 429 too_many_invites carries max_active; 403 owner_only.
      final d = api((_) async => http.Response('{"error":"too many","code":"too_many_invites","max_active":5}', 429));
      await expectLater(
        d.createInvite('tok', 'c1'),
        throwsA(isA<PlantlyApiException>()
            .having((e) => e.code, 'code', 'too_many_invites')
            .having((e) => e.details['max_active'], 'max_active', 5)),
      );
      final f = api((_) async => http.Response('{"error":"nope","code":"owner_only"}', 403));
      await expectLater(f.createInvite('tok', 'c1'),
          throwsA(isA<PlantlyApiException>().having((e) => e.code, 'code', 'owner_only')));
    });

    test('joinCollection: POST /inventory/collections/join {code} → collection; stable error codes pass through', () async {
      final log = <http.Request>[];
      final a = api(log: log, (_) async => http.Response(
            json.encode({'collection': {'id': 'c2', 'name': 'Shared', 'role': 'editor', 'owner_user_id': 'u2', 'member_count': 2}}),
            200,
          ));
      final col = await a.joinCollection('tok', 'ABCDEFGH');
      expect(log.single.url.toString(), '$host/api/v1/inventory/collections/join');
      expect(log.single.headers['Content-Type'], startsWith('application/json'));
      expect(json.decode(log.single.body), {'code': 'ABCDEFGH'});
      expect(col.id, 'c2');
      expect(col.role, 'editor');
      for (final (status, code) in [(404, 'invite_invalid'), (409, 'already_member')]) {
        final b = api((_) async => http.Response('{"error":"nope","code":"$code"}', status));
        await expectLater(
          b.joinCollection('tok', 'ABCDEFGH'),
          throwsA(isA<PlantlyApiException>().having((e) => e.status, 'status', status).having((e) => e.code, 'code', code)),
        );
      }
    });

    test('listMembers / removeMember: GET + DELETE on …/{id}/members[/{user_id}]', () async {
      final log = <http.Request>[];
      final a = api(log: log, (req) async {
        if (req.method == 'DELETE') return http.Response('', 204);
        return http.Response(
          json.encode({
            'members': [
              {'user_id': 'u1', 'username': 'alice', 'role': 'owner', 'joined_at': '2026-09-01T00:00:00Z'},
              {'user_id': 'u2', 'username': 'bob', 'role': 'editor', 'joined_at': '2026-09-20T00:00:00Z'},
            ]
          }),
          200,
        );
      });
      final members = await a.listMembers('tok', 'c1');
      expect(members.map((m) => m.username), ['alice', 'bob']);
      expect(members.first.isOwner, isTrue);
      expect(members.last.joinedAt, DateTime.utc(2026, 9, 20));
      expect(log.last.url.toString(), '$host/api/v1/inventory/collections/c1/members');
      await a.removeMember('tok', 'c1', 'u2');
      expect(log.last.method, 'DELETE');
      expect(log.last.url.toString(), '$host/api/v1/inventory/collections/c1/members/u2');
      expect(log.last.headers['X-Plantly-Client'], startsWith('inventory/'));
      // Ids are path-encoded.
      await a.removeMember('tok', 'c 1', 'u/2');
      expect(log.last.url.path, '/api/v1/inventory/collections/c%201/members/u%2F2');
      for (final (status, code) in [(409, 'owner_cannot_leave'), (404, 'member_not_found')]) {
        final b = api((_) async => http.Response('{"error":"nope","code":"$code"}', status));
        await expectLater(b.removeMember('tok', 'c1', 'u1'),
            throwsA(isA<PlantlyApiException>().having((e) => e.status, 'status', status).having((e) => e.code, 'code', code)));
      }
    });

    test('listDevices: GET /inventory/devices?device_id= → wrapped {devices:[…]} parsed; bare list tolerated', () async {
      final log = <http.Request>[];
      final a = api(log: log, (req) async {
        return http.Response(
          json.encode({
            'devices': [
              {
                'device_id': 'dev-a',
                'platform': 'android',
                'app_version': '1.2.3',
                'device_name': 'Pixel 8',
                'first_seen_at': '2026-09-01T10:00:00Z',
                'last_seen_at': '2026-10-02T08:30:00Z',
                'current': true,
              },
              {'device_id': 'dev-b', 'platform': 'web', 'current': false},
              {'platform': 'ios'}, // no device_id → dropped
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final list = await a.listDevices('tok', deviceId: 'dev-a');
      final req = log.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/api/v1/inventory/devices');
      expect(req.url.queryParameters['device_id'], 'dev-a');
      expect(req.headers['Authorization'], 'Bearer tok');
      expect(req.headers['X-Plantly-Client'], startsWith('inventory/'));
      expect(list.map((d) => d.deviceId), ['dev-a', 'dev-b']);
      expect(list.first.current, isTrue);
      expect(list.first.deviceName, 'Pixel 8');
      expect(list.first.appVersion, '1.2.3');
      expect(list.first.platform, 'android');
      expect(list.first.lastSeenAt, DateTime.utc(2026, 10, 2, 8, 30));
      expect(list.first.firstSeenAt, DateTime.utc(2026, 9, 1, 10));
      expect(list.last.current, isFalse);
      expect(list.last.deviceName, isNull);

      // No deviceId → no query; bare-list reply (older server) still parses.
      final log2 = <http.Request>[];
      final b = api(log: log2, (_) async => http.Response(
            json.encode([
              {'device_id': 'dev-c', 'platform': 'linux'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          ));
      final bare = await b.listDevices('tok');
      expect(log2.single.url.queryParameters.containsKey('device_id'), isFalse);
      expect(bare.single.deviceId, 'dev-c');
      expect(bare.single.current, isFalse);
    });

    test('revokeDevice: DELETE /inventory/devices/{id} with the bearer; errors pass through', () async {
      final log = <http.Request>[];
      final a = api(log: log, (_) async => http.Response('', 204));
      await a.revokeDevice('tok', 'dev b/1');
      final req = log.single;
      expect(req.method, 'DELETE');
      expect(req.url.toString(), '$host/api/v1/inventory/devices/dev%20b%2F1');
      expect(req.headers['Authorization'], 'Bearer tok');

      final gone = api((_) async => http.Response('{"error":"device_not_found"}', 404));
      await expectLater(
        gone.revokeDevice('tok', 'dev-x'),
        throwsA(isA<PlantlyApiException>().having((e) => e.status, 'status', 404)),
      );
    });

    test('InviteCode: 8 chars from A-HJ-NP-Z2-9, case/dash/space tolerant', () {
      expect(InviteCode.normalize('ABCDEFGH'), 'ABCDEFGH');
      expect(InviteCode.normalize(' abcd-efgh '), 'ABCDEFGH');
      expect(InviteCode.normalize('2345 6789'), '23456789');
      expect(InviteCode.isValid('ABCDEFG'), isFalse, reason: '7 chars');
      expect(InviteCode.isValid('ABCDEFGHJ'), isFalse, reason: '9 chars');
      expect(InviteCode.isValid('ABCDEFGI'), isFalse, reason: 'I excluded');
      expect(InviteCode.isValid('ABCDEFGO'), isFalse, reason: 'O excluded');
      expect(InviteCode.isValid('ABCDEFG0'), isFalse, reason: '0 excluded');
      expect(InviteCode.isValid('ABCDEFG1'), isFalse, reason: '1 excluded');
      expect(InviteCode.isValid(''), isFalse);
    });
  });
}
