import 'dart:convert';

import '../data/database/app_database.dart';

/// The wire transport for op-log sync. Mirrors the `POST /sync/push` +
/// `GET /sync/pull` contract in PLAN.md §"Sync API contract". Concrete
/// implementations (an HTTP client against the Go server, or a fake in tests)
/// implement this; [SyncEngine] drives it and knows nothing about HTTP.
///
/// Phase 2 status: the push side is wired end-to-end against `sync_ops`. The
/// pull DTOs are defined here so the contract is locked, but applying pulled
/// ops (field-level LWW + OR-Set reconciliation, PLAN.md §"Conflict semantics")
/// lands together with the server — see the note on [SyncEngine].
abstract class SyncTransport {
  /// `POST /sync/push`.
  Future<PushResponse> push(PushRequest request);

  /// `GET /sync/pull?since_hlc=...`.
  Future<PullResponse> pull(PullRequest request);
}

/// One mutation in the wire format: `{ entity, entity_id, field, value, hlc }`.
/// `value` is the decoded JSON value (null for tombstones), not the stored
/// JSON string.
class SyncOpDto {
  const SyncOpDto({
    required this.entity,
    required this.entityId,
    required this.field,
    required this.value,
    required this.hlc,
  });

  final String entity;
  final String entityId;
  final String field;
  final Object? value;
  final String hlc;

  /// Build from a stored `sync_ops` row, decoding `value_json`.
  factory SyncOpDto.fromRow(SyncOpRow row) {
    return SyncOpDto(
      entity: row.entity,
      entityId: row.entityId,
      field: row.field,
      value: row.valueJson == null ? null : json.decode(row.valueJson!),
      hlc: row.hlc,
    );
  }

  Map<String, dynamic> toJson() => {
        'entity': entity,
        'entity_id': entityId,
        'field': field,
        'value': value,
        'hlc': hlc,
      };

  factory SyncOpDto.fromJson(Map<String, dynamic> m) => SyncOpDto(
        entity: m['entity'] as String,
        entityId: m['entity_id'] as String,
        field: m['field'] as String,
        value: m['value'],
        hlc: m['hlc'] as String,
      );
}

class PushRequest {
  const PushRequest({
    required this.deviceId,
    required this.ops,
    required this.lastSeenServerHlc,
  });

  final String deviceId;
  final List<SyncOpDto> ops;
  final String lastSeenServerHlc;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'ops': [for (final o in ops) o.toJson()],
        'last_seen_server_hlc': lastSeenServerHlc,
      };
}

/// A server-side rejection of a single op, keyed to its index in the request.
class OpRejection {
  const OpRejection({required this.opIndex, required this.reason});
  final int opIndex;
  final String reason;

  factory OpRejection.fromJson(Map<String, dynamic> m) => OpRejection(
        opIndex: (m['op_index'] as num).toInt(),
        reason: (m['reason'] as String?) ?? 'unknown',
      );
}

class PushResponse {
  const PushResponse({
    required this.accepted,
    required this.rejected,
    required this.serverHlc,
    this.freshOps = const [],
  });

  final int accepted;
  final List<OpRejection> rejected;
  final String serverHlc;

  /// Ops the server already had newer state for and streamed back in the same
  /// round-trip (contract's `fresh_ops`). Applied by the pull/reconcile path.
  final List<SyncOpDto> freshOps;

  factory PushResponse.fromJson(Map<String, dynamic> m) => PushResponse(
        accepted: (m['accepted'] as num?)?.toInt() ?? 0,
        rejected: [
          for (final r in (m['rejected'] as List? ?? const []))
            OpRejection.fromJson(r as Map<String, dynamic>)
        ],
        serverHlc: (m['server_hlc'] as String?) ?? '',
        freshOps: [
          for (final o in (m['fresh_ops'] as List? ?? const []))
            SyncOpDto.fromJson(o as Map<String, dynamic>)
        ],
      );
}

class PullRequest {
  const PullRequest({
    required this.sinceHlc,
    required this.deviceId,
    this.limit = 500,
  });

  final String sinceHlc;
  final String deviceId;
  final int limit;
}

class PullResponse {
  const PullResponse({
    required this.ops,
    required this.serverHlc,
    required this.hasMore,
  });

  final List<SyncOpDto> ops;
  final String serverHlc;
  final bool hasMore;

  factory PullResponse.fromJson(Map<String, dynamic> m) => PullResponse(
        ops: [
          for (final o in (m['ops'] as List? ?? const []))
            SyncOpDto.fromJson(o as Map<String, dynamic>)
        ],
        serverHlc: (m['server_hlc'] as String?) ?? '',
        hasMore: (m['has_more'] as bool?) ?? false,
      );
}
