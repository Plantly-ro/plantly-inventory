import 'dart:convert';

import '../data/database/app_database.dart';

/// The wire transport for op-log sync — CLOUD-SYNC-CONTRACT §2.2:
/// `POST /api/v1/inventory/collections/{id}/sync/push` and
/// `GET .../sync/pull`. Concrete implementations (HTTP against the monolith,
/// or a fake in tests) implement this; the engine/runner drive it and know
/// nothing about HTTP.
abstract class SyncTransport {
  /// `POST .../sync/push`.
  Future<PushResponse> push(PushRequest request);

  /// `GET .../sync/pull?since=&limit=`.
  Future<PullResponse> pull(PullRequest request);
}

/// `GET .../collections/{id}/usage`.
abstract class CollectionUsageSource {
  Future<CollectionUsage> usage();
}

class CollectionUsage {
  const CollectionUsage({
    required this.bytesStored,
    required this.bytesQuota,
    this.opsCount = 0,
  });
  final int bytesStored;
  final int bytesQuota;
  final int opsCount;

  factory CollectionUsage.fromJson(Map<String, dynamic> m) => CollectionUsage(
        bytesStored: (m['bytes_stored'] as num?)?.toInt() ?? 0,
        bytesQuota: (m['bytes_quota'] as num?)?.toInt() ?? 0,
        opsCount: (m['ops_count'] as num?)?.toInt() ?? 0,
      );
}

// --- errors ---------------------------------------------------------------

/// Base class for transport failures the runner reacts to.
sealed class SyncError implements Exception {
  const SyncError(this.message);
  final String message;
  @override
  String toString() => '$runtimeType($message)';
}

/// 401 — token rejected. Runner refreshes once, then surfaces `unauthorized`.
class SyncAuthError extends SyncError {
  const SyncAuthError([super.message = 'unauthorized']);
}

/// 402 `cloud_required` — entitlement lapsed. Runner stops syncing.
class SyncEntitlementError extends SyncError {
  const SyncEntitlementError([super.message = 'cloud_required']);
}

/// 403 `not_a_member` / 404 `collection_not_found`.
class SyncCollectionError extends SyncError {
  const SyncCollectionError(super.message, {required this.status});
  final int status;
}

/// 429 / 5xx / network failure — retry with backoff.
class SyncRetryableError extends SyncError {
  const SyncRetryableError(super.message, {this.retryAfter, this.status});

  /// Server hint (`Retry-After`), when present.
  final Duration? retryAfter;
  final int? status;
}

/// 413 on `/sync/push` — the batch body exceeded the server's 4 MiB cap.
/// The engine halves the batch and retries; a single op that still trips it
/// is marked permanently rejected (`op_too_large`).
class SyncBatchTooLargeError extends SyncError {
  const SyncBatchTooLargeError([super.message = 'batch_too_large']);
}

/// 413 `quota_exceeded` on photo upload.
class SyncQuotaError extends SyncError {
  const SyncQuotaError({this.bytesQuota, this.bytesStored})
      : super('quota_exceeded');
  final int? bytesQuota;
  final int? bytesStored;
}

/// Any other non-2xx (400 bad request, 200 with a malformed body, …).
class SyncProtocolError extends SyncError {
  const SyncProtocolError(super.message, {this.status});
  final int? status;
}

// --- DTOs -----------------------------------------------------------------

/// One mutation in the wire format:
/// `{ entity, entity_id, field, value, hlc }` outbound; pulled ops also carry
/// `device_id`, `seq` and (shared collections, §3) `user_id`. `value` is the
/// decoded JSON value (null for tombstones), not the stored JSON string.
class SyncOpDto {
  const SyncOpDto({
    required this.entity,
    required this.entityId,
    required this.field,
    required this.value,
    required this.hlc,
    this.deviceId,
    this.seq,
    this.userId,
  });

  final String entity;
  final String entityId;
  final String field;
  final Object? value;
  final String hlc;

  /// Origin device — set on ops received from the server. Falls back to the
  /// HLC's embedded device id when the server omits it.
  final String? deviceId;

  /// Server sequence number (pull only).
  final String? seq;

  /// plantly.ro user id of the account that pushed the op (pulled / fresh
  /// ops only; additive — older servers omit it). Never sent outbound: the
  /// server stamps it from the bearer token.
  final String? userId;

  /// Build from a stored `sync_ops` row, decoding `value_json`.
  factory SyncOpDto.fromRow(SyncOpRow row) {
    return SyncOpDto(
      entity: row.entity,
      entityId: row.entityId,
      field: row.field,
      value: row.valueJson == null ? null : json.decode(row.valueJson!),
      hlc: row.hlc,
      deviceId: row.deviceId,
    );
  }

  /// Outbound shape — never includes `device_id` (the request carries it) or
  /// `seq`.
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
        deviceId: m['device_id'] as String?,
        seq: switch (m['seq']) {
          null => null,
          final num n => n.toInt().toString(),
          final Object o => o.toString(),
        },
        userId: switch (m['user_id']) {
          final String s when s.isNotEmpty => s,
          _ => null,
        },
      );
}

class PushRequest {
  const PushRequest({
    required this.deviceId,
    required this.ops,
    required this.since,
  });

  final String deviceId;
  final List<SyncOpDto> ops;

  /// Opaque server cursor (`server_seq`); `'0'` before the first pull.
  final String since;

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'ops': [for (final o in ops) o.toJson()],
        'since': since.isEmpty ? '0' : since,
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
    required this.cursor,
    this.freshOps = const [],
    this.hasMore = false,
  });

  final int accepted;
  final List<OpRejection> rejected;

  /// New cursor after this push (covers `fresh_ops`).
  final String cursor;

  /// Ops appended by OTHER devices since `since`, ≤ 500.
  final List<SyncOpDto> freshOps;

  /// More fresh ops remain beyond [cursor]; follow up with pulls.
  final bool hasMore;

  factory PushResponse.fromJson(Map<String, dynamic> m) => PushResponse(
        accepted: (m['accepted'] as num?)?.toInt() ?? 0,
        rejected: [
          for (final r in (m['rejected'] as List? ?? const []))
            OpRejection.fromJson(r as Map<String, dynamic>)
        ],
        cursor: _cursor(m['cursor']),
        freshOps: [
          for (final o in (m['fresh_ops'] as List? ?? const []))
            SyncOpDto.fromJson(o as Map<String, dynamic>)
        ],
        hasMore: (m['has_more'] as bool?) ?? false,
      );
}

class PullRequest {
  const PullRequest({
    required this.since,
    this.limit = 500,
  });

  final String since;
  final int limit;
}

class PullResponse {
  const PullResponse({
    required this.ops,
    required this.cursor,
    required this.hasMore,
  });

  final List<SyncOpDto> ops;
  final String cursor;
  final bool hasMore;

  factory PullResponse.fromJson(Map<String, dynamic> m) => PullResponse(
        ops: [
          for (final o in (m['ops'] as List? ?? const []))
            SyncOpDto.fromJson(o as Map<String, dynamic>)
        ],
        cursor: _cursor(m['cursor']),
        hasMore: (m['has_more'] as bool?) ?? false,
      );
}

/// The server sends the cursor as a string; tolerate a bare number too.
String _cursor(Object? raw) => switch (raw) {
      null => '',
      final num n => n.toInt().toString(),
      final Object o => o.toString(),
    };
