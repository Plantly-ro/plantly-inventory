import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/handoff/plantly_export.dart';

String encodeParam(Map<String, Object?> json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

Map<String, Object?> sample({Map<String, Object?> extra = const {}}) => {
      'schemaVersion': 1,
      'source': 'plantly-assistant',
      'scientificName': 'Monstera deliciosa',
      'commonName': 'Swiss cheese plant',
      'chosenScientificName': 'Monstera deliciosa',
      'candidates': [
        {'scientificName': 'Monstera deliciosa', 'confidence': 0.92},
        {'scientificName': 'Monstera adansonii', 'confidence': 0.05},
      ],
      'healthStatus': 'stressed',
      'observations': [
        {'kind': 'yellowing', 'severity': 0.7, 'note': 'lower leaves'},
      ],
      'photoSha256': 'ab' * 32,
      'capturedAt': '2026-08-07T10:30:00.000',
      'exportedAt': '2026-08-07T10:31:00.000',
      ...extra,
    };

void main() {
  group('decodeParam', () {
    test('decodes a full v1 payload (base64url, no padding)', () {
      final d = encodeParam(sample());
      expect(d, isNot(contains('=')));
      final p = PlantlyExportPayload.decodeParam(d);
      expect(p.schemaVersion, 1);
      expect(p.source, 'plantly-assistant');
      expect(p.scientificName, 'Monstera deliciosa');
      expect(p.commonName, 'Swiss cheese plant');
      expect(p.defaultNickname, 'Swiss cheese plant');
      expect(p.candidates.length, 2);
      expect(p.candidates.first.confidence, 0.92);
      expect(p.healthStatus, 'stressed');
      expect(p.observations!.single.kind, 'yellowing');
      expect(p.observations!.single.severity, 0.7);
      expect(p.observations!.single.note, 'lower leaves');
      expect(p.capturedAt, DateTime.parse('2026-08-07T10:30:00.000'));
      expect(p.isFromMarketplace, isFalse);
      expect(p.thumbBytes, isNull);
    });

    test('accepts padded base64url too', () {
      final padded = base64Url.encode(utf8.encode(jsonEncode(sample())));
      expect(PlantlyExportPayload.decodeParam(padded).scientificName, 'Monstera deliciosa');
    });

    test('minimal payload: only schemaVersion + scientificName', () {
      final p = PlantlyExportPayload.decodeParam(encodeParam({'schemaVersion': 1, 'scientificName': 'Ficus lyrata'}));
      expect(p.defaultNickname, 'Ficus lyrata');
      expect(p.candidates, isEmpty);
      expect(p.observations, isNull);
      expect(p.source, 'unknown');
    });

    test('unknown enum values degrade: status → null, kind → other; unknown keys ignored', () {
      final p = PlantlyExportPayload.decodeParam(encodeParam(sample(extra: {
        'healthStatus': 'thriving',
        'observations': [
          {'kind': 'glitter', 'severity': 0.2},
          'not-a-map',
        ],
        'futureKey': {'nested': true},
      })));
      expect(p.healthStatus, isNull);
      expect(p.observations!.single.kind, 'other');
    });

    test('marketplace source + marketplacePostId', () {
      final p = PlantlyExportPayload.decodeParam(encodeParam(sample(extra: {
        'source': 'plantly-marketplace',
        'marketplacePostId': 'post-uuid',
      })));
      expect(p.isFromMarketplace, isTrue);
      expect(p.marketplacePostId, 'post-uuid');
    });

    test('thumb decodes when it is a JPEG ≤ 64 KiB; non-JPEG, oversized or invalid base64 → null', () {
      final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, ...List<int>.generate(1000, (i) => i % 251)];
      final p = PlantlyExportPayload.decodeParam(encodeParam(sample(extra: {
        'photoThumbJpegBase64': base64Encode(jpeg),
      })));
      expect(p.thumbBytes, jpeg);

      final png = [0x89, 0x50, 0x4E, 0x47, ...List<int>.generate(100, (i) => i)];
      expect(PlantlyExportPayload.decodeParam(encodeParam(sample(extra: {'photoThumbJpegBase64': base64Encode(png)}))).thumbBytes, isNull);

      // Cap boundary checked on fromJson: a 64 KiB thumb is base64'd twice on
      // the wire (inside the JSON, then the JSON as `d`), so such a link is
      // already over the 100 KiB URL cap and decodeParam rejects it earlier.
      final big = [0xFF, 0xD8, 0xFF, ...List<int>.filled(64 * 1024, 0)];
      expect(PlantlyExportPayload.fromJson(sample(extra: {'photoThumbJpegBase64': base64Encode(big)})).thumbBytes, isNull);

      final exact = [0xFF, 0xD8, 0xFF, ...List<int>.filled(64 * 1024 - 3, 0)];
      expect(PlantlyExportPayload.fromJson(sample(extra: {'photoThumbJpegBase64': base64Encode(exact)})).thumbBytes, hasLength(64 * 1024));

      final bad = PlantlyExportPayload.decodeParam(encodeParam(sample(extra: {'photoThumbJpegBase64': '!!!'})));
      expect(bad.thumbBytes, isNull);
    });

    test('over-long strings are truncated, not rejected', () {
      final p = PlantlyExportPayload.decodeParam(encodeParam(sample(extra: {
        'scientificName': 'S' * 1000,
        'commonName': 'C' * 1000,
        'chosenScientificName': 'X' * 1000,
        'candidates': [
          {'scientificName': 'K' * 1000, 'confidence': 0.5},
        ],
        'observations': [
          {'kind': 'spots', 'severity': 0.1, 'note': 'N' * 5000},
        ],
      })));
      expect(p.scientificName, hasLength(200));
      expect(p.commonName, hasLength(200));
      expect(p.chosenScientificName, hasLength(200));
      expect(p.candidates.single.scientificName, hasLength(200));
      expect(p.observations!.single.note, hasLength(500));
    });

    test('rejects oversized param (> 100 KiB)', () {
      final d = 'A' * (100 * 1024 + 1);
      expect(
        () => PlantlyExportPayload.decodeParam(d),
        throwsA(isA<PlantlyExportFormatException>().having((e) => e.error, 'error', PlantlyExportFormatError.tooLarge)),
      );
    });

    test('rejects bad encoding / bad JSON / non-object', () {
      expect(() => PlantlyExportPayload.decodeParam('%%%'),
          throwsA(isA<PlantlyExportFormatException>().having((e) => e.error, 'e', PlantlyExportFormatError.badEncoding)));
      final notJson = base64Url.encode(utf8.encode('{nope')).replaceAll('=', '');
      expect(() => PlantlyExportPayload.decodeParam(notJson),
          throwsA(isA<PlantlyExportFormatException>().having((e) => e.error, 'e', PlantlyExportFormatError.badJson)));
      final list = base64Url.encode(utf8.encode('[1]')).replaceAll('=', '');
      expect(() => PlantlyExportPayload.decodeParam(list),
          throwsA(isA<PlantlyExportFormatException>().having((e) => e.error, 'e', PlantlyExportFormatError.badJson)));
    });

    test('rejects unsupported schemaVersion and missing scientificName', () {
      expect(() => PlantlyExportPayload.decodeParam(encodeParam({'schemaVersion': 2, 'scientificName': 'x'})),
          throwsA(isA<PlantlyExportFormatException>().having((e) => e.error, 'e', PlantlyExportFormatError.unsupportedVersion)));
      expect(() => PlantlyExportPayload.decodeParam(encodeParam({'schemaVersion': 1})),
          throwsA(isA<PlantlyExportFormatException>().having((e) => e.error, 'e', PlantlyExportFormatError.missingName)));
      expect(() => PlantlyExportPayload.decodeParam(encodeParam({'schemaVersion': 1, 'scientificName': '  '})),
          throwsA(isA<PlantlyExportFormatException>().having((e) => e.error, 'e', PlantlyExportFormatError.missingName)));
    });
  });
}
