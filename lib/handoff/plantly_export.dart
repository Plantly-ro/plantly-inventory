import 'dart:convert';
import 'dart:typed_data';

/// PlantlyExport v1 — the cross-app handoff payload (CONTRACT §4). This is
/// the *reader* side: tolerant of unknown keys, degrades unknown enum values
/// to null/`other`, never throws on optional fields.
class PlantlyExportPayload {
  const PlantlyExportPayload({
    required this.schemaVersion,
    required this.source,
    required this.scientificName,
    this.commonName,
    this.chosenScientificName,
    this.candidates = const [],
    this.healthStatus,
    this.observations,
    this.photoSha256,
    this.photoThumbJpegBase64,
    this.marketplacePostId,
    this.capturedAt,
    this.exportedAt,
  });

  static const int supportedSchemaVersion = 1;

  /// `d` (and therefore the whole URL) must stay under 100 KiB (§4).
  static const int maxEncodedBytes = 100 * 1024;

  /// Thumb cap: 64 KiB of decoded JPEG (§4). Anything larger, or not a JPEG,
  /// is dropped — the rest of the payload still imports.
  static const int maxThumbBytes = 64 * 1024;

  /// Attacker-controlled free text is truncated (never rejected) to these.
  static const int maxNameChars = 200;
  static const int maxNoteChars = 500;

  static const Set<String> knownHealthStatuses = {'healthy', 'stressed', 'diseased', 'unknown'};
  static const Set<String> knownObservationKinds = {'yellowing', 'browning', 'spots', 'wilting', 'pests', 'other'};

  final int schemaVersion;
  final String source;
  final String scientificName;
  final String? commonName;
  final String? chosenScientificName;
  final List<ExportCandidate> candidates;

  /// One of [knownHealthStatuses], or null when absent/unknown.
  final String? healthStatus;
  final List<ExportObservation>? observations;
  final String? photoSha256;
  final String? photoThumbJpegBase64;
  final String? marketplacePostId;
  final DateTime? capturedAt;
  final DateTime? exportedAt;

  bool get isFromMarketplace => source == 'plantly-marketplace';

  /// Display name for the import sheet: `commonName ?? scientificName` (§4b).
  String get defaultNickname => (commonName?.trim().isNotEmpty ?? false) ? commonName!.trim() : scientificName;

  /// Decoded thumb bytes, or null when absent, malformed, over the cap, or
  /// not a JPEG (SOI marker `FF D8 FF`).
  Uint8List? get thumbBytes {
    final raw = photoThumbJpegBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      final bytes = base64Decode(base64.normalize(raw.trim()));
      if (bytes.length < 4 || bytes.length > maxThumbBytes) return null;
      if (bytes[0] != 0xFF || bytes[1] != 0xD8 || bytes[2] != 0xFF) return null;
      return bytes;
    } on FormatException {
      return null;
    }
  }

  /// Decode the `d=` link parameter: base64url (padding optional) → UTF-8 →
  /// JSON → payload. Throws [PlantlyExportFormatException] on anything that
  /// cannot become a v1 payload with a scientific name.
  static PlantlyExportPayload decodeParam(String d) {
    if (d.length > maxEncodedBytes) {
      throw const PlantlyExportFormatException(PlantlyExportFormatError.tooLarge);
    }
    final String text;
    try {
      text = utf8.decode(base64Url.decode(base64Url.normalize(d.trim())));
    } catch (_) {
      throw const PlantlyExportFormatException(PlantlyExportFormatError.badEncoding);
    }
    final Object? decoded;
    try {
      decoded = json.decode(text);
    } catch (_) {
      throw const PlantlyExportFormatException(PlantlyExportFormatError.badJson);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PlantlyExportFormatException(PlantlyExportFormatError.badJson);
    }
    return fromJson(decoded);
  }

  static PlantlyExportPayload fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version is! num || version.toInt() != supportedSchemaVersion) {
      throw const PlantlyExportFormatException(PlantlyExportFormatError.unsupportedVersion);
    }
    final sci = json['scientificName'];
    if (sci is! String || sci.trim().isEmpty) {
      throw const PlantlyExportFormatException(PlantlyExportFormatError.missingName);
    }
    final rawCandidates = json['candidates'];
    final rawObservations = json['observations'];
    final status = json['healthStatus'];
    return PlantlyExportPayload(
      schemaVersion: version.toInt(),
      source: json['source'] is String ? json['source'] as String : 'unknown',
      scientificName: _clip(sci.trim(), maxNameChars),
      commonName: _string(json['commonName'], maxNameChars),
      chosenScientificName: _string(json['chosenScientificName'], maxNameChars),
      candidates: [
        if (rawCandidates is List)
          for (final c in rawCandidates)
            if (c is Map && c['scientificName'] is String)
              ExportCandidate(
                scientificName: _clip(c['scientificName'] as String, maxNameChars),
                confidence: _double(c['confidence']),
              ),
      ],
      healthStatus: status is String && knownHealthStatuses.contains(status) ? status : null,
      observations: rawObservations is List
          ? [
              for (final o in rawObservations)
                if (o is Map)
                  ExportObservation(
                    kind: o['kind'] is String && knownObservationKinds.contains(o['kind']) ? o['kind'] as String : 'other',
                    severity: _double(o['severity']),
                    note: _string(o['note'], maxNoteChars),
                  ),
            ]
          : null,
      photoSha256: _string(json['photoSha256']),
      photoThumbJpegBase64: _string(json['photoThumbJpegBase64']),
      marketplacePostId: _string(json['marketplacePostId']),
      capturedAt: _date(json['capturedAt']),
      exportedAt: _date(json['exportedAt']),
    );
  }

  static String? _string(Object? v, [int? max]) =>
      v is String && v.trim().isNotEmpty ? (max == null ? v : _clip(v, max)) : null;
  static String _clip(String v, int max) => v.length <= max ? v : v.substring(0, max);
  static double _double(Object? v) => v is num ? v.toDouble() : 0.0;
  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
}

class ExportCandidate {
  const ExportCandidate({required this.scientificName, required this.confidence});
  final String scientificName;
  final double confidence;
}

class ExportObservation {
  const ExportObservation({required this.kind, required this.severity, this.note});
  final String kind;
  final double severity;
  final String? note;
}

enum PlantlyExportFormatError { tooLarge, badEncoding, badJson, unsupportedVersion, missingName }

class PlantlyExportFormatException implements Exception {
  const PlantlyExportFormatException(this.error);
  final PlantlyExportFormatError error;

  @override
  String toString() => 'PlantlyExportFormatException(${error.name})';
}
