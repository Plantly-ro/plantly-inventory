import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/database/app_database.dart';
import 'entity_codecs.dart';
import 'hlc.dart';
import 'op_log.dart';
import 'sync_rejections.dart' show kIdCollisionReason;
import 'sync_transport.dart';

/// A pulled `*` op the applier refused because [entityId] already exists on
/// this device under [heldByTenant] (primary keys are `{id}`, not
/// tenant-scoped). Parked in `sync_rejections` as [kIdCollisionReason]
/// against the remote op's [opSeq].
class SyncIdCollision {
  const SyncIdCollision({
    required this.entity,
    required this.entityId,
    required this.heldByTenant,
    required this.opSeq,
  });
  final String entity;
  final String entityId;
  final String heldByTenant;
  final int opSeq;

  @override
  String toString() => 'SyncIdCollision($entity/$entityId held by $heldByTenant, op_seq $opSeq)';
}

/// Outcome of one [SyncApplier.applyBatch].
class SyncApplyResult {
  int applied = 0;

  /// Ops persisted without touching a row (duplicates, unknown entities,
  /// ops for rows we do not have yet, losers of the LWW comparison).
  int skipped = 0;

  /// `photos` rows created from remote ops whose blob is not on this device
  /// (`remote_state='remote'`). Callers may prefetch; the UI fetches lazily
  /// through `PhotoFetcher`.
  final List<String> remotePhotoShas = [];

  /// Whole-row ops skipped because the id belongs to another tenant here
  /// (counted in [skipped] too).
  final List<SyncIdCollision> idCollisions = [];

  @override
  String toString() =>
      'SyncApplyResult(applied: $applied, skipped: $skipped, idCollisions: ${idCollisions.length})';
}

/// Applies remote ops per CLOUD-SYNC-CONTRACT §2.3.
///
/// One Drift transaction per batch. For every op:
///   1. duplicate (same entity/id/field/hlc/device) → skip;
///   2. the HLC clock absorbs the remote HLC;
///   3. the op is applied iff its HLC beats the local HLC for the same
///      (entity, entity_id, field) — the latest `sync_ops` row for that field
///      or for `*` (a whole-row op writes every field), else the row's
///      `updated_hlc` / `added_hlc`; ties fall to the HLC's device suffix;
///   4. the op is recorded in `sync_ops` with its origin `device_id` and
///      `pushed_at` set, so it informs future comparisons but is never
///      pushed back.
///
/// On OR-Set join tables `added_hlc` is the HLC of the add: metadata field
/// ops (caption, captured_at, display_order) and `removed_hlc` never
/// re-stamp it — see [_orSetMembershipColumns].
///
/// Tombstones are final: a tombstoned row ignores every later op. A field op
/// for a row we have not received yet is kept and materialised when the `*`
/// op arrives (newer field ops override the `*` payload).
class SyncApplier {
  SyncApplier({
    required this.db,
    required this.opLog,
    required this.clock,
    int Function()? nowMillis,
  }) : _nowMillis = nowMillis ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final AppDatabase db;
  final OpLogWriter opLog;
  final HlcClock clock;
  final int Function() _nowMillis;

  /// Set by [_insertFromWholeRow] when the op's id is held by another
  /// tenant; consumed by [_applyOne] once the remote op has a `seq`.
  String? _collisionTenant;

  String get tenantId => opLog.tenantId;
  EntityCodecs get codecs => opLog.codecs;

  Future<SyncApplyResult> applyBatch(List<SyncOpDto> ops) async {
    final result = SyncApplyResult();
    await _replayParkedPhotoCollisions(result);
    if (ops.isEmpty) return result;
    await db.transaction(() async {
      for (final op in ops) {
        await _applyOne(op, result);
      }
    });
    return result;
  }

  Future<void> _applyOne(SyncOpDto op, SyncApplyResult result) async {
    final Hlc opHlc;
    try {
      opHlc = Hlc.parse(op.hlc);
    } on FormatException {
      result.skipped++;
      return;
    }
    final deviceId = op.deviceId ?? opHlc.deviceId;
    final codec = codecs.forEntity(op.entity);
    if (codec == null) {
      result.skipped++;
      return;
    }
    if (await opLog.hasOp(
      entity: op.entity,
      entityId: op.entityId,
      field: op.field,
      hlc: op.hlc,
      deviceId: deviceId,
    )) {
      result.skipped++;
      return;
    }
    clock.merge(opHlc);

    final bool applied;
    if (op.field == kTombstoneField) {
      applied = await _applyTombstone(codec, op, opHlc, deviceId);
    } else if (op.field == kWholeRowField) {
      applied = await _applyWholeRow(codec, op, opHlc, deviceId, result);
    } else if (codec.isOrSet && op.field == 'removed_hlc' && op.entityId.contains('/')) {
      applied = await _applyLegacyPairRemove(codec, op, opHlc, deviceId);
    } else {
      applied = await _applyField(codec, op, opHlc, deviceId);
    }
    if (applied) {
      result.applied++;
    } else {
      result.skipped++;
    }
    final seq = await opLog.recordRemote(op, deviceId: deviceId, nowMillis: _nowMillis());
    final held = _collisionTenant;
    if (held != null) {
      _collisionTenant = null;
      await _parkIdCollision(op, seq: seq, heldByTenant: held, result: result);
    }
  }

  bool _photoCollisionsReplayed = false;

  /// Before schema 13 a pulled `photos` `*` op for a sha this device held
  /// under another tenant was parked as [kIdCollisionReason]. Photos are
  /// keyed per tenant now, so those rows can be materialised: once per
  /// applier, insert each parked op's row (unless it exists or was
  /// tombstoned since) and clear the ledger entry.
  Future<void> _replayParkedPhotoCollisions(SyncApplyResult result) async {
    if (_photoCollisionsReplayed) return;
    _photoCollisionsReplayed = true;
    final codec = codecs.forEntity('photos');
    if (codec == null) return;
    final parked = await (db.select(db.syncRejections)
          ..where((r) =>
              r.tenantId.equals(tenantId) & r.entity.equals('photos') & r.reason.equals(kIdCollisionReason)))
        .get();
    if (parked.isEmpty) return;
    await db.transaction(() async {
      for (final r in parked) {
        final row = await (db.select(db.syncOps)..where((o) => o.seq.equals(r.opSeq))).getSingleOrNull();
        if (row != null && row.field == kWholeRowField && await _readRow(codec, row.entityId) == null) {
          final op = SyncOpDto.fromRow(row);
          final value = op.value;
          final ops = await opLog.opsFor(entity: 'photos', entityId: row.entityId);
          if (value is Map && !ops.any((o) => o.field == kTombstoneField)) {
            try {
              await _insertFromWholeRow(
                  codec, op, Hlc.parse(op.hlc), row.deviceId, value.map((k, v) => MapEntry('$k', v)), ops, result);
            } on FormatException {
              // unparseable HLC: nothing to replay
            }
          }
        }
        await (db.delete(db.syncRejections)..where((x) => x.opSeq.equals(r.opSeq))).go();
      }
    });
  }

  /// Ledger entry for a `*` op we could not materialise because its id is
  /// taken by another tenant on this device. The op is already stored as
  /// remote (`pushed_at` set); the ledger row is parked so it shows up in
  /// Me → Cloud without ever being pushed.
  Future<void> _parkIdCollision(
    SyncOpDto op, {
    required int seq,
    required String heldByTenant,
    required SyncApplyResult result,
  }) async {
    await db.into(db.syncRejections).insert(
          SyncRejectionsCompanion.insert(
            opSeq: Value(seq),
            tenantId: tenantId,
            entity: op.entity,
            entityId: op.entityId,
            field: op.field,
            reason: kIdCollisionReason,
            hlc: op.hlc,
            at: _nowMillis(),
            parked: const Value(true),
          ),
          mode: InsertMode.insertOrReplace,
        );
    result.idCollisions.add(
      SyncIdCollision(entity: op.entity, entityId: op.entityId, heldByTenant: heldByTenant, opSeq: seq),
    );
  }

  // --- op kinds ------------------------------------------------------------

  Future<bool> _applyTombstone(EntityCodec codec, SyncOpDto op, Hlc opHlc, String deviceId) async {
    final row = await _readRow(codec, op.entityId);
    if (row == null) return false;
    if (_rowIsDeleted(codec, row)) return false;
    final rowHlc = _rowHlc(codec, row);
    final bump = rowHlc == null || opHlc > rowHlc;
    await _update(codec, op.entityId, {
      if (codec.isOrSet) 'removed_hlc': op.hlc else 'deleted_at': opHlc.physicalMs,
      if (bump && !codec.isOrSet) codec.hlcColumn: op.hlc,
      if (bump) 'device_id': deviceId,
    });
    return true;
  }

  Future<bool> _applyWholeRow(
    EntityCodec codec,
    SyncOpDto op,
    Hlc opHlc,
    String deviceId,
    SyncApplyResult result,
  ) async {
    final value = op.value;
    if (value is! Map) return false;
    final wire = value.map((k, v) => MapEntry('$k', v));
    final row = await _readRow(codec, op.entityId);
    if (row != null && _rowIsDeleted(codec, row)) return false;
    final ops = await opLog.opsFor(entity: op.entity, entityId: op.entityId);
    if (ops.any((o) => o.field == kTombstoneField)) return false;

    final fieldMax = _fieldMaxHlcs(ops);
    final starHlc = fieldMax[kWholeRowField];

    if (row == null) {
      return _insertFromWholeRow(codec, op, opHlc, deviceId, wire, ops, result);
    }

    final rowHlc = _rowHlc(codec, row);
    final decoded = codec.decodeRow(wire);
    final updates = <String, Object?>{};
    for (final e in decoded.entries) {
      final c = e.key;
      if (_isMetaColumn(codec, c)) continue;
      final local = _maxHlc(fieldMax[c], starHlc) ?? rowHlc;
      if (local == null || opHlc > local) updates[c] = e.value;
    }
    if (updates.isEmpty) return false;
    if (rowHlc == null || opHlc > rowHlc) {
      updates[codec.hlcColumn] = op.hlc;
      updates['device_id'] = deviceId;
    }
    // A `*` op re-sent for a row we already hold (e.g. synthesized on
    // another device): attribute it when we did not know the actor yet.
    if (codec.entity == 'care_events' && op.userId != null && row['actor_user_id'] == null) {
      updates['actor_user_id'] = op.userId;
    }
    await _update(codec, op.entityId, updates);
    return true;
  }

  Future<bool> _insertFromWholeRow(
    EntityCodec codec,
    SyncOpDto op,
    Hlc opHlc,
    String deviceId,
    Map<String, dynamic> wire,
    List<SyncOpRow> ops,
    SyncApplyResult result,
  ) async {
    // `_readRow` is tenant-scoped; the primary key is not. A row with this id
    // under another tenant (e.g. a legacy literal seed id, or the same user's
    // local rows next to a joined collection) must never be overwritten or
    // silently swallowed by the PK failure below: skip and park.
    final holder = await _tenantHolding(codec, op.entityId);
    if (holder != null && holder != tenantId) {
      debugPrint('sync: id_collision ${op.entity}/${op.entityId} held by tenant $holder');
      _collisionTenant = holder;
      return false;
    }

    final sql = codec.decodeRow(wire, fillDefaults: true);
    sql[codec.idColumn] = op.entityId;
    sql['tenant_id'] = tenantId;

    // Row HLC: the payload's own stamp when it parses, else the op HLC.
    var rowHlc = opHlc;
    final wireHlc = sql[codec.hlcColumn];
    if (wireHlc is String) {
      try {
        final h = Hlc.parse(wireHlc);
        if (h > rowHlc) rowHlc = h;
      } on FormatException {
        // fall through to opHlc
      }
    }
    if (sql['device_id'] is! String || (sql['device_id'] as String).isEmpty) {
      sql['device_id'] = deviceId;
    }

    // Field ops that arrived before the row: the newest per field wins over
    // the `*` payload.
    final newest = <String, SyncOpRow>{};
    for (final o in ops) {
      if (o.field == kWholeRowField || o.field == kTombstoneField) continue;
      if (!codec.isWireColumn(o.field)) continue;
      final h = Hlc.parse(o.hlc);
      if (h <= opHlc) continue;
      final prev = newest[o.field];
      if (prev == null || h > Hlc.parse(prev.hlc)) newest[o.field] = o;
    }
    for (final e in newest.entries) {
      final dto = SyncOpDto.fromRow(e.value);
      sql[e.key] = codec.decodeField(e.key, dto.value);
      if (codec.isOrSet && e.key == 'removed_hlc') sql[e.key] ??= e.value.hlc;
      if (!_restampsRowHlc(codec, e.key)) continue;
      final h = Hlc.parse(e.value.hlc);
      if (h > rowHlc) {
        rowHlc = h;
        sql['device_id'] = e.value.deviceId;
      }
    }
    sql[codec.hlcColumn] = rowHlc.encode();

    if (codec.entity == 'photos') {
      sql['remote_state'] = 'remote';
      sql['local_path'] = null;
    }
    // Shared collections (§3): who logged it. Device-local column fed from
    // the pulled op's `user_id`; older servers omit it → null.
    if (codec.entity == 'care_events' && op.userId != null) {
      sql['actor_user_id'] = op.userId;
    }

    if (!await _resolveUniqueConflict(codec, op.entityId, opHlc, sql)) return false;

    try {
      await db.into(codec.table).insert(codec.insertable(sql));
    } on Exception {
      // Constraint violation we could not resolve (e.g. duplicate OR-Set add
      // with an identical added_hlc): keep the op, drop the row.
      return false;
    }
    if (codec.entity == 'photos') result.remotePhotoShas.add(op.entityId);
    return true;
  }

  Future<bool> _applyField(EntityCodec codec, SyncOpDto op, Hlc opHlc, String deviceId) async {
    if (!codec.isWireColumn(op.field) || _isMetaColumn(codec, op.field) && op.field != 'removed_hlc') {
      return false;
    }
    final row = await _readRow(codec, op.entityId);
    if (row == null) return false; // materialised by the `*` op later
    if (_rowIsDeleted(codec, row)) return false;
    final latest = await opLog.latestOpFor(
      entity: op.entity,
      entityId: op.entityId,
      fields: [op.field, kWholeRowField, kTombstoneField],
    );
    if (latest != null && latest.field == kTombstoneField) return false;
    final rowHlc = _rowHlc(codec, row);
    final local = latest == null ? rowHlc : Hlc.parse(latest.hlc);
    if (local != null && opHlc <= local) return false;

    Object? value = codec.decodeField(op.field, op.value);
    if (codec.isOrSet && op.field == 'removed_hlc') value ??= op.hlc;
    final newer = rowHlc == null || opHlc > rowHlc;
    final restamp = newer && _restampsRowHlc(codec, op.field);
    await _update(codec, op.entityId, {
      op.field: value,
      if (restamp) codec.hlcColumn: op.hlc,
      if (restamp || newer && codec.isOrSet && op.field == 'removed_hlc') 'device_id': deviceId,
    });
    return true;
  }

  /// OR-Set columns whose change is a new membership assertion (e.g. a
  /// `plant_tags` row re-pointed at a surviving tag) and therefore re-stamps
  /// `added_hlc`. Every other OR-Set field op — `removed_hlc` or metadata
  /// such as caption / captured_at / display_order — leaves `added_hlc`
  /// alone: it is the HLC of the add, compared against removes for presence
  /// (PlantPhotoRepository) and shown as the fallback "date added".
  static const Set<String> _orSetMembershipColumns = {'plant_id', 'location_id', 'photo_sha', 'tag_id'};

  /// Whether a field op on [field] moves the row-level HLC column.
  bool _restampsRowHlc(EntityCodec codec, String field) =>
      !codec.isOrSet || _orSetMembershipColumns.contains(field);

  /// Pre-cloud clients recorded detaches as `removed_hlc` ops keyed
  /// `<parent_id>/<child_id>`; honour them by stamping every live add-row of
  /// the pair.
  Future<bool> _applyLegacyPairRemove(EntityCodec codec, SyncOpDto op, Hlc opHlc, String deviceId) async {
    final slash = op.entityId.indexOf('/');
    final parentId = op.entityId.substring(0, slash);
    final childId = op.entityId.substring(slash + 1);
    final parentCol = codec.entity == 'location_photos' ? 'location_id' : 'plant_id';
    final childCol = codec.entity == 'plant_tags' ? 'tag_id' : 'photo_sha';
    final removedAt = op.value is String ? op.value as String : op.hlc;
    final n = await db.customUpdate(
      'UPDATE ${codec.table.actualTableName} SET removed_hlc = ?, device_id = ? '
      'WHERE tenant_id = ? AND $parentCol = ? AND $childCol = ? AND removed_hlc IS NULL '
      'AND added_hlc < ?',
      variables: [
        Variable<String>(removedAt),
        Variable<String>(deviceId),
        Variable<String>(tenantId),
        Variable<String>(parentId),
        Variable<String>(childId),
        Variable<String>(op.hlc),
      ],
      updates: {codec.table},
      updateKind: UpdateKind.update,
    );
    return n > 0;
  }

  // --- unique constraints ---------------------------------------------------

  /// `care_schedules UNIQUE(tenant_id, plant_id, type)` and
  /// `tags UNIQUE(tenant_id, name)` can collide when two devices created the
  /// "same" row independently. Deterministic resolution: the row with the
  /// greater HLC survives; the loser is tombstoned through a LOCAL op so
  /// every device converges on the same survivor (a local loser row is
  /// physically removed — see below). Returns false when the incoming row
  /// lost (caller must not insert). For `tags`, live `plant_tags` rows are
  /// re-pointed at the survivor first (see [_repointPlantTags]).
  Future<bool> _resolveUniqueConflict(
    EntityCodec codec,
    String incomingId,
    Hlc incomingHlc,
    Map<String, Object?> sql,
  ) async {
    final List<(String, Object?)> key;
    switch (codec.entity) {
      case 'care_schedules':
        key = [('plant_id', sql['plant_id']), ('type', sql['type'])];
      case 'tags':
        key = [('name', sql['name'])];
      default:
        return true;
    }
    if (key.any((k) => k.$2 == null)) return true;
    final where = key.map((k) => '${k.$1} = ?').join(' AND ');
    final existing = await db
        .customSelect(
          'SELECT * FROM ${codec.table.actualTableName} '
          'WHERE tenant_id = ? AND deleted_at IS NULL AND ${codec.idColumn} != ? AND $where',
          variables: [
            Variable<String>(tenantId),
            Variable<String>(incomingId),
            for (final k in key) Variable<String>('${k.$2}'),
          ],
          readsFrom: {codec.table},
        )
        .getSingleOrNull();
    if (existing == null) return true;
    final existingId = existing.data[codec.idColumn] as String;
    final existingHlc = _rowHlc(codec, existing.data) ?? const Hlc(0, 0, '');
    if (incomingHlc > existingHlc) {
      if (codec.entity == 'tags') await _repointPlantTags(loserId: existingId, survivorId: incomingId);
      // The unique index is not partial, so a soft-deleted loser would still
      // block the insert: emit its tombstone op (what other devices need)
      // and drop the physical row.
      await opLog.recordTombstone(entity: codec.entity, entityId: existingId);
      await db.customUpdate(
        'DELETE FROM ${codec.table.actualTableName} WHERE ${codec.idColumn} = ? AND tenant_id = ?',
        variables: [Variable<String>(existingId), Variable<String>(tenantId)],
        updates: {codec.table},
        updateKind: UpdateKind.delete,
      );
      return true;
    }
    if (codec.entity == 'tags') await _repointPlantTags(loserId: incomingId, survivorId: existingId);
    await opLog.recordTombstone(entity: codec.entity, entityId: incomingId);
    return false;
  }

  /// Move live `plant_tags` rows off a losing tag onto the survivor, as
  /// ordinary LOCAL field ops so every device converges. Where the plant
  /// already carries the survivor, the loser's row is detached instead
  /// (`removed_hlc`), so nothing keeps pointing at a deleted tag.
  Future<void> _repointPlantTags({required String loserId, required String survivorId}) async {
    final rows = await (db.select(db.plantTags)
          ..where((r) => r.tenantId.equals(tenantId) & r.tagId.equals(loserId) & r.removedHlc.isNull()))
        .get();
    if (rows.isEmpty) return;
    final alreadyOnSurvivor = {
      for (final r in await (db.select(db.plantTags)
            ..where((r) => r.tenantId.equals(tenantId) & r.tagId.equals(survivorId) & r.removedHlc.isNull()))
          .get())
        r.plantId,
    };
    for (final row in rows) {
      if (alreadyOnSurvivor.contains(row.plantId)) {
        final h = await opLog.recordFieldUpdate(
            entity: 'plant_tags', entityId: row.id, field: 'removed_hlc', value: null);
        await (db.update(db.plantTags)..where((r) => r.id.equals(row.id))).write(
          PlantTagsCompanion(removedHlc: Value(h.encode()), deviceId: Value(clock.deviceId)),
        );
      } else {
        final h = await opLog.recordFieldUpdate(
            entity: 'plant_tags', entityId: row.id, field: 'tag_id', value: survivorId);
        await (db.update(db.plantTags)..where((r) => r.id.equals(row.id))).write(
          PlantTagsCompanion(
            tagId: Value(survivorId),
            addedHlc: Value(h.encode()),
            deviceId: Value(clock.deviceId),
          ),
        );
        alreadyOnSurvivor.add(row.plantId);
      }
    }
  }

  // --- row helpers -----------------------------------------------------------

  /// Tenant of the row with primary key [id], any tenant; null when absent.
  /// Always null for tables keyed per tenant (`photos`: (tenant_id, sha256))
  /// — the same sha in another collection is a separate row, not a collision.
  Future<String?> _tenantHolding(EntityCodec codec, String id) async {
    if (codec.table.$primaryKey.any((c) => c.name == 'tenant_id')) return null;
    final row = await db
        .customSelect(
          'SELECT tenant_id FROM ${codec.table.actualTableName} WHERE ${codec.idColumn} = ?',
          variables: [Variable<String>(id)],
          readsFrom: {codec.table},
        )
        .getSingleOrNull();
    return row?.read<String>('tenant_id');
  }

  Future<Map<String, Object?>?> _readRow(EntityCodec codec, String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM ${codec.table.actualTableName} WHERE ${codec.idColumn} = ? AND tenant_id = ?',
          variables: [Variable<String>(id), Variable<String>(tenantId)],
          readsFrom: {codec.table},
        )
        .getSingleOrNull();
    return row?.data;
  }

  Future<void> _update(EntityCodec codec, String id, Map<String, Object?> sql) async {
    if (sql.isEmpty) return;
    final idCol = codec.table.columnsByName[codec.idColumn]! as GeneratedColumn<String>;
    final tenantCol = codec.table.columnsByName['tenant_id']! as GeneratedColumn<String>;
    await (db.update(codec.table)..where((_) => idCol.equals(id) & tenantCol.equals(tenantId)))
        .write(codec.insertable(sql));
  }

  bool _rowIsDeleted(EntityCodec codec, Map<String, Object?> row) =>
      codec.isOrSet ? row['removed_hlc'] != null : row['deleted_at'] != null;

  Hlc? _rowHlc(EntityCodec codec, Map<String, Object?> row) {
    final raw = row[codec.hlcColumn];
    if (raw is! String) return null;
    try {
      return Hlc.parse(raw);
    } on FormatException {
      return null;
    }
  }

  /// Columns the applier manages itself rather than as LWW fields.
  bool _isMetaColumn(EntityCodec codec, String c) =>
      c == codec.idColumn || c == 'tenant_id' || c == codec.hlcColumn || c == 'device_id';

  Map<String, Hlc> _fieldMaxHlcs(List<SyncOpRow> ops) {
    final out = <String, Hlc>{};
    for (final o in ops) {
      final Hlc h;
      try {
        h = Hlc.parse(o.hlc);
      } on FormatException {
        continue;
      }
      final prev = out[o.field];
      if (prev == null || h > prev) out[o.field] = h;
    }
    return out;
  }

  Hlc? _maxHlc(Hlc? a, Hlc? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a > b ? a : b;
  }
}
