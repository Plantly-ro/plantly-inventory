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
      expect(req.headers['User-Agent'], 'PlantlyInventory/1.0.0 (+https://plantly.ro/app/inventory)');
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
}
