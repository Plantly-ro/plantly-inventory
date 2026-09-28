import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import 'entity_codecs.dart';
import 'hlc.dart';
import 'sync_transport.dart';

/// Tombstone field sentinel used in sync_ops.field for soft-deletes.
const String kTombstoneField = '__tombstone__';

/// Whole-row create/upsert sentinel used in sync_ops.field.
const String kWholeRowField = '*';

/// Writes to every synced entity go through this helper so (a) the HLC is
/// stamped consistently and (b) a sync_ops row is produced for later push.
///
/// Use inside a single transaction so partial failures don't leave orphan
/// op-log entries.
///
/// `sync_ops` holds two kinds of rows:
///   * local ops — `device_id` = this device, `pushed_at` NULL until the
///     server accepted them (the pending queue);
///   * remote ops — recorded by the applier via [recordRemote] with their
///     origin `device_id` and `pushed_at` already set, so they are never
///     pushed but DO take part in the per-(entity, id, field) LWW lookup
///     ([latestHlcFor]) and in the idempotency check ([hasOp]).
class OpLogWriter {
  OpLogWriter({required this.db, required this.clock, required this.tenantId})
      : codecs = EntityCodecs(db);

  final AppDatabase db;
  final HlcClock clock;
  final String tenantId;
  final EntityCodecs codecs;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Fires after every LOCAL op is recorded (never for remote ops). The sync
  /// runner debounces this into a push.
  Stream<void> get changes => _changes.stream;

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> dispose() => _changes.close();

  /// Record a whole-row create (`field='*'`). [value] may be partial and
  /// loosely typed; it is canonicalised through the entity's [EntityCodec]
  /// (full column set, ISO timestamps, JSON booleans, row HLC + device
  /// stamped) so every client emits the same shape. Entities without a
  /// codec are stored verbatim.
  Future<Hlc> recordCreate({
    required String entity,
    required String entityId,
    required Map<String, dynamic> value,
  }) async {
    final hlc = clock.now();
    final codec = codecs.forEntity(entity);
    final payload = codec == null
        ? value
        : codec.canonicalRow(
            {...value, codec.idColumn: value[codec.idColumn] ?? entityId},
            hlc: hlc.encode(),
            deviceId: clock.deviceId,
          );
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenantId,
          entity: entity,
          entityId: entityId,
          field: kWholeRowField,
          hlc: hlc.encode(),
          deviceId: clock.deviceId,
          valueJson: Value(json.encode(payload)),
        ));
    _notify();
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
    _notify();
    return hlc;
  }

  /// Record a per-field update for an existing entity. Value is encoded as
  /// JSON so numbers/strings/bools survive the round-trip; timestamp columns
  /// are rendered ISO-8601 through the codec so the wire shape matches `*`.
  Future<Hlc> recordFieldUpdate({
    required String entity,
    required String entityId,
    required String field,
    required Object? value,
  }) async {
    final hlc = clock.now();
    final codec = codecs.forEntity(entity);
    final wire = codec == null || !codec.hasColumn(field) ? value : codec.encodeField(field, value);
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenantId,
          entity: entity,
          entityId: entityId,
          field: field,
          hlc: hlc.encode(),
          deviceId: clock.deviceId,
          valueJson: Value(json.encode(wire)),
        ));
    _notify();
    return hlc;
  }

  /// Record one field op per entry of [fields] (in iteration order) and
  /// return the HLC of the last one, or null when [fields] is empty. Edit
  /// paths pass only the fields whose value actually changed, so an
  /// untouched form field never produces an op.
  Future<Hlc?> recordFieldUpdates({
    required String entity,
    required String entityId,
    required Map<String, Object?> fields,
  }) async {
    Hlc? last;
    for (final e in fields.entries) {
      last = await recordFieldUpdate(entity: entity, entityId: entityId, field: e.key, value: e.value);
    }
    return last;
  }

  /// Record a synthesized `*` op for a row that already exists locally
  /// (initial upload). [hlc] is the row's own `updated_hlc`/`added_hlc`, not
  /// a fresh tick, so it cannot outrank edits made elsewhere in the meantime.
  Future<void> recordSynthesized({
    required String entity,
    required String entityId,
    required Map<String, dynamic> wireRow,
    required String hlc,
    required String deviceId,
  }) async {
    await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenantId,
          entity: entity,
          entityId: entityId,
          field: kWholeRowField,
          hlc: hlc,
          deviceId: deviceId,
          valueJson: Value(json.encode(wireRow)),
        ));
  }

  /// Persist an op received from the server. Stored with its origin
  /// `device_id` and `pushed_at` = [nowMillis] so it never enters the pending
  /// queue; no change notification is emitted. Returns the row's `seq`.
  Future<int> recordRemote(SyncOpDto op, {required String deviceId, required int nowMillis}) {
    return db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenantId,
          entity: op.entity,
          entityId: op.entityId,
          field: op.field,
          hlc: op.hlc,
          deviceId: deviceId,
          valueJson: Value(op.value == null ? null : json.encode(op.value)),
          pushedAt: Value(nowMillis),
        ));
  }

  /// Idempotency check on the contract's natural key
  /// (entity, entity_id, field, hlc, device_id).
  Future<bool> hasOp({
    required String entity,
    required String entityId,
    required String field,
    required String hlc,
    required String deviceId,
  }) async {
    final row = await (db.select(db.syncOps)
          ..where((o) =>
              o.tenantId.equals(tenantId) &
              o.entity.equals(entity) &
              o.entityId.equals(entityId) &
              o.field.equals(field) &
              o.hlc.equals(hlc) &
              o.deviceId.equals(deviceId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Highest-HLC op row for (entity, entity_id) among [fields], local or
  /// remote; null when none exists.
  Future<SyncOpRow?> latestOpFor({
    required String entity,
    required String entityId,
    required List<String> fields,
  }) async {
    final rows = await (db.select(db.syncOps)
          ..where((o) =>
              o.tenantId.equals(tenantId) &
              o.entity.equals(entity) &
              o.entityId.equals(entityId) &
              o.field.isIn(fields)))
        .get();
    SyncOpRow? best;
    Hlc? bestHlc;
    for (final r in rows) {
      final h = Hlc.parse(r.hlc);
      if (bestHlc == null || h > bestHlc) {
        best = r;
        bestHlc = h;
      }
    }
    return best;
  }

  /// All op rows for one entity row — used by the applier to resolve
  /// per-field winners when materialising a `*` op.
  Future<List<SyncOpRow>> opsFor({required String entity, required String entityId}) {
    return (db.select(db.syncOps)
          ..where((o) =>
              o.tenantId.equals(tenantId) & o.entity.equals(entity) & o.entityId.equals(entityId)))
        .get();
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
