import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import 'hlc.dart';

/// Tombstone field sentinel used in sync_ops.field for soft-deletes.
const String kTombstoneField = '__tombstone__';

/// Whole-row create/upsert sentinel used in sync_ops.field.
const String kWholeRowField = '*';

/// Writes to every synced entity go through this helper so (a) the HLC is
/// stamped consistently and (b) a sync_ops row is produced for later push.
///
/// Use inside a single transaction so partial failures don't leave orphan
/// op-log entries.
class OpLogWriter {
  OpLogWriter({required this.db, required this.clock, required this.tenantId});

  final AppDatabase db;
  final HlcClock clock;
  final String tenantId;

  /// Record a whole-row create (`field='*'`). Value is serialized once and
  /// reused across the local write + op-log entry.
  Future<Hlc> recordCreate({
    required String entity,
    required String entityId,
    required Map<String, dynamic> value,
  }) async {
    final hlc = clock.now();
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenantId,
          entity: entity,
          entityId: entityId,
          field: kWholeRowField,
          hlc: hlc.encode(),
          deviceId: clock.deviceId,
          valueJson: Value(json.encode(value)),
        ));
    return hlc;
  }

  /// Record a tombstone (`field='__tombstone__'`, value null). Caller is
  /// responsible for flipping `deleted_at` on the entity row.
  Future<Hlc> recordTombstone({
    required String entity,
    required String entityId,
  }) async {
    final hlc = clock.now();
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenantId,
          entity: entity,
          entityId: entityId,
          field: kTombstoneField,
          hlc: hlc.encode(),
          deviceId: clock.deviceId,
        ));
    return hlc;
  }

  /// Record a per-field update for an existing entity. Value is encoded as
  /// JSON so numbers/strings/bools survive the round-trip.
  Future<Hlc> recordFieldUpdate({
    required String entity,
    required String entityId,
    required String field,
    required Object? value,
  }) async {
    final hlc = clock.now();
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenantId,
          entity: entity,
          entityId: entityId,
          field: field,
          hlc: hlc.encode(),
          deviceId: clock.deviceId,
          valueJson: Value(json.encode(value)),
        ));
    return hlc;
  }

  /// Count of ops still awaiting push (pushed_at IS NULL).
  Future<int> pendingCount() async {
    final row = await (db.selectOnly(db.syncOps)
          ..addColumns([db.syncOps.seq.count()])
          ..where(db.syncOps.pushedAt.isNull() &
              db.syncOps.tenantId.equals(tenantId)))
        .getSingle();
    return row.read(db.syncOps.seq.count()) ?? 0;
  }
}
