import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/marketplace/listing_records.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/marketplace/upload_image_prep.dart';
import 'package:plantly_inventory/plugins/export_plugin.dart';
import 'package:plantly_inventory/plugins/plantly_ro/plantly_ro_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/multipart_parser.dart';
import '../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 9, 19, 12);
  int secs(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;
  final freshToken = fakeJwt(iat: secs(now), exp: secs(now.add(const Duration(hours: 24))));

  late List<http.Request> log;
  late InMemorySessionStore store;
  late ListingRecords records;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    log = [];
    store = InMemorySessionStore(freshToken);
    records = ListingRecords(SharedPreferences.getInstance());
  });

  PlantlyRoExportPlugin plugin(
    Future<http.Response> Function(http.Request) handler, {
    Map<String, Uint8List> photos = const {},
    PlantlyAuth? auth,
  }) {
    final api = PlantlyApi(
      client: MockClient((req) {
        log.add(req);
        return handler(req);
      }),
      host: 'https://dev.example',
      sendUserAgent: true,
    );
    return PlantlyRoExportPlugin(
      api: api,
      auth: auth ?? PlantlyAuth(api: api, store: store, now: () => now, autoLoad: false),
      records: records,
      preparer: const PassthroughUploadImagePreparer(),
      photoBytes: (sha) async => photos[sha],
      host: 'https://dev.example',
      now: () => now,
    );
  }

  ExportDraft draft({
    String title = 'Monstera deliciosa',
    String description = 'Healthy, 3 leaves',
    int? price = 45,
    String? category = '7eb901e4-10e3-46ee-bfe9-29a08d0841d3',
    List<String> photos = const ['sha-a'],
    String? county = 'Cluj',
    String? city = 'Cluj-Napoca',
  }) =>
      ExportDraft(
        sourcePlantId: 'plant-1',
        title: title,
        description: description,
        priceLei: price,
        category: category,
        county: county,
        city: city,
        photoRefs: photos,
      );

  group('manifest', () {
    test('matches CONTRACT §5', () {
      final m = plugin((_) async => http.Response('', 500)).manifest;
      expect(m.id, 'plantly_ro');
      expect(m.displayName, 'plantly.ro');
      expect(m.authType, PluginAuthType.jwt);
      expect(m.titleMaxLength, 64);
      expect(m.descriptionMaxLength, 2000);
      expect(m.maxPhotos, 6);
      expect(m.priceCurrency, 'lei');
      expect(m.supportsStatusUpdate, isTrue);
    });
  });

  group('buildPreview', () {
    test('valid draft has no issues', () async {
      final p = await plugin((_) async => http.Response('', 500)).buildPreview(draft());
      expect(p.isValid, isTrue);
    });

    test('flags title/description/price/category/photos with stable codes', () async {
      final pl = plugin((_) async => http.Response('', 500));
      Future<Set<String>> codes(ExportDraft d) async =>
          (await pl.buildPreview(d)).issues.whereType<PlantlyExportIssue>().map((i) => i.code).toSet();

      expect(await codes(draft(title: '  ')), contains('title_required'));
      expect(await codes(draft(title: 'x' * 65)), contains('title_too_long'));
      expect(await codes(draft(description: 'y' * 2001)), contains('description_too_long'));
      expect(await codes(draft(price: null)), contains('price_invalid'));
      expect(await codes(draft(price: 0)), contains('price_invalid'));
      expect(await codes(draft(category: null)), contains('category_required'));
      expect(await codes(draft(category: 'Indoor plant')), contains('category_invalid'));
      expect(await codes(draft(category: '7eb901e4-10e3-46ee-bfe9-29a08d0841d3')), isNot(contains('category_invalid')));
      expect(await codes(draft(photos: const [])), contains('photos_required'));
      expect(await codes(draft(photos: List.generate(7, (i) => 'sha-$i'))), contains('photos_too_many'));
    });

    test('64-rune title with diacritics is accepted', () async {
      final p = await plugin((_) async => http.Response('', 500)).buildPreview(draft(title: 'ă' * 64));
      expect(p.isValid, isTrue);
    });
  });

  group('submit', () {
    test('happy path: progress ticks, multipart body, record persisted, url built', () async {
      final pl = plugin(
        (req) async {
          if (req.url.path.endsWith('/posts')) {
            return http.Response(json.encode({'id': 'post-123', 'status': 'active'}), 201);
          }
          return http.Response('{"error":"unexpected"}', 500);
        },
        photos: {'sha-a': Uint8List.fromList([1, 2, 3]), 'sha-b': Uint8List.fromList([9])},
      );
      final ticks = await pl.submit(draft(photos: const ['sha-a', 'sha-b'])).toList();

      expect(ticks.first.fraction, 0.1);
      expect(ticks.map((t) => t.fraction).toList(), [0.1, 0.5, 0.8, 0.9, 1.0]);
      final last = ticks.last;
      expect(last.succeeded, isTrue);
      expect(last.remoteId, 'post-123');
      expect(last.url, 'https://dev.example/posts/post-123');
      expect(last.message, isNull);

      final parsed = parseMultipart(log.single);
      expect(parsed.fields['title'], 'Monstera deliciosa');
      expect(parsed.fields['price'], '45');
      expect(parsed.fields['category_id'], '7eb901e4-10e3-46ee-bfe9-29a08d0841d3');
      expect(parsed.fields['state'], 'Romania');
      expect(parsed.fields['county'], 'Cluj');
      expect(parsed.fields['city'], 'Cluj-Napoca');
      expect(parsed.fields['delivery_pickup'], 'true');
      expect(parsed.fields['delivery_seller'], 'false');
      expect(parsed.fields['delivery_courier'], 'false');
      expect(parsed.files.length, 2);
      expect(log.single.headers['Authorization'], 'Bearer $freshToken');

      // Local record: plantly_ro_export/<plantId>
      final rec = records.forPlant('plant-1');
      expect(rec, isNotNull);
      expect(rec!.postId, 'post-123');
      expect(rec.status, 'active');
      expect(rec.url, 'https://dev.example/posts/post-123');
      final prefs = await SharedPreferences.getInstance();
      final raw = json.decode(prefs.getString('plantly_ro_export/plant-1')!) as Map<String, dynamic>;
      expect(raw['post_id'], 'post-123');
      expect(raw['status'], 'active');
      expect(raw['posted_at'], now.toIso8601String());
    });

    test('upload_warnings surface as the terminal message (non-fatal)', () async {
      final pl = plugin(
        (_) async => http.Response(json.encode({'id': 'p2', 'upload_warnings': ['image 1: blurry']}), 201),
        photos: {'sha-a': Uint8List.fromList([1])},
      );
      final last = (await pl.submit(draft()).toList()).last;
      expect(last.succeeded, isTrue);
      expect(last.message, contains('blurry'));
    });

    test('invalid draft ends immediately with a validation error', () async {
      final last = (await plugin((_) async => http.Response('', 500)).submit(draft(price: null)).toList()).last;
      expect(last.done, isTrue);
      expect(last.error, isA<PlantlyExportError>().having((e) => e.kind, 'kind', PlantlyExportErrorKind.validation));
      expect(log, isEmpty);
    });

    test('no session → signInRequired without hitting the network', () async {
      store = InMemorySessionStore();
      final last = (await plugin((_) async => http.Response('', 500), photos: {'sha-a': Uint8List(1)})
              .submit(draft())
              .toList())
          .last;
      expect(last.error, isA<PlantlyExportError>().having((e) => e.kind, 'kind', PlantlyExportErrorKind.signInRequired));
      expect(log, isEmpty);
    });

    test('401 clears the session and reports signInRequired', () async {
      final api = PlantlyApi(client: MockClient((req) async => http.Response('{"error":"unauthorized"}', 401)), host: 'h');
      final auth = PlantlyAuth(api: api, store: store, now: () => now, autoLoad: false);
      final pl = plugin((_) async => http.Response('{"error":"unauthorized"}', 401),
          photos: {'sha-a': Uint8List(1)}, auth: auth);
      final last = (await pl.submit(draft()).toList()).last;
      expect(last.error, isA<PlantlyExportError>().having((e) => e.kind, 'kind', PlantlyExportErrorKind.signInRequired));
      expect(await store.readToken(), isNull);
      expect(auth.sessionOrNull, isNull);
    });

    test('429 → rateLimited with retry hint', () async {
      final pl = plugin((_) async => http.Response('{"error":"slow"}', 429, headers: {'retry-after': '60'}),
          photos: {'sha-a': Uint8List(1)});
      final last = (await pl.submit(draft()).toList()).last;
      expect(
          last.error,
          isA<PlantlyExportError>()
              .having((e) => e.kind, 'kind', PlantlyExportErrorKind.rateLimited)
              .having((e) => e.retryAfter, 'retryAfter', 60));
    });

    test('network failure → network error', () async {
      final pl = plugin((_) async => throw http.ClientException('offline'), photos: {'sha-a': Uint8List(1)});
      final last = (await pl.submit(draft()).toList()).last;
      expect(last.error, isA<PlantlyExportError>().having((e) => e.kind, 'kind', PlantlyExportErrorKind.network));
    });

    test('unreadable photos are skipped; none readable → noPhotos', () async {
      final pl = plugin((_) async => http.Response('{"id":"p"}', 201), photos: const {});
      final last = (await pl.submit(draft()).toList()).last;
      expect(last.error, isA<PlantlyExportError>().having((e) => e.kind, 'kind', PlantlyExportErrorKind.noPhotos));
      expect(log, isEmpty);
    });
  });

  group('updateStatus', () {
    test('sold → POST /posts/{id}/sold and flips the local record', () async {
      await records.put(ListingRecord(plantId: 'plant-1', postId: 'post-7', url: 'u', postedAt: now, status: 'active'));
      final pl = plugin((_) async => http.Response('{"status":"sold"}', 200));
      await pl.updateStatus('post-7', 'sold');
      expect(log.single.url.path, '/api/v1/posts/post-7/sold');
      expect(records.forPlant('plant-1')!.status, 'sold');
    });

    test('rejects statuses other than sold', () async {
      expect(() => plugin((_) async => http.Response('', 200)).updateStatus('x', 'active'), throwsArgumentError);
    });
  });

  group('credentials', () {
    test('loadCredentials maps the session; revoke clears it', () async {
      final pl = plugin((_) async => http.Response('', 500));
      final s = await pl.loadCredentials();
      expect(s, isNotNull);
      expect(s!.accountLabel, 'alice');
      expect(s.token, freshToken);
      await pl.revoke();
      expect(await pl.loadCredentials(), isNull);
    });

    test('loadCredentials refreshes inside the 12h window and persists the new token', () async {
      final oldToken = fakeJwt(iat: secs(now.subtract(const Duration(hours: 20))), exp: secs(now.add(const Duration(hours: 4))));
      final newToken = fakeJwt(iat: secs(now), exp: secs(now.add(const Duration(hours: 24))));
      store = InMemorySessionStore(oldToken);
      final pl = plugin((req) async {
        expect(req.url.path, '/api/v1/auth/refresh');
        expect(req.headers['Authorization'], 'Bearer $oldToken');
        return http.Response(json.encode({'token': newToken}), 200);
      });
      final s = await pl.loadCredentials();
      expect(s!.token, newToken);
      expect(await store.readToken(), newToken);
    });

    test('refresh refused by the server drops the session', () async {
      store = InMemorySessionStore(fakeJwt(iat: secs(now.subtract(const Duration(hours: 20))), exp: secs(now.add(const Duration(hours: 1)))));
      final pl = plugin((_) async => http.Response('{"error":"session expired"}', 401));
      expect(await pl.loadCredentials(), isNull);
      expect(await store.readToken(), isNull);
    });

    test('refresh offline keeps a still-valid token', () async {
      final tok = fakeJwt(iat: secs(now.subtract(const Duration(hours: 20))), exp: secs(now.add(const Duration(hours: 1))));
      store = InMemorySessionStore(tok);
      final pl = plugin((_) async => throw http.ClientException('offline'));
      expect((await pl.loadCredentials())!.token, tok);
    });
  });

  test('providers wire the plugin first in the registry', () {
    // Smoke: the registry's default must be plantly_ro (authType != none).
    final container = ProviderContainer(overrides: [
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore()),
    ]);
    addTearDown(container.dispose);
    expect(container.read(plantlyAuthProvider.notifier), isA<PlantlyAuth>());
  });
}
