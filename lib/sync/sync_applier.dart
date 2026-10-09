import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../data/database/app_database.dart';
import 'entity_codecs.dart';
import 'hlc.dart';
import 'op_log.dart';
import 'sync_markers.dart';
import 'sync_rejections.dart' show kApplyErrorReason, kIdCollisionReason, kInvalidRemoteOpReason;
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

  /// Entities with at least one applied op (e.g. `care_schedules`) — lets
  /// listeners react only to changes they care about.
  final Set<String> appliedEntities = {};

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

  /// Ops this device could not apply — invalid for the local schema
  /// ([kInvalidRemoteOpReason]) or failing in SQL ([kApplyErrorReason]).
  /// Each is stored as an already-pushed remote op (so the pull cursor moves
  /// on and a re-delivery is an idempotent skip) and parked in
  /// `sync_rejections`. Counted in [skipped] too.
  final List<SyncRejectedInbound> rejected = [];

  @override
  String toString() => 'SyncApplyResult(applied: $applied, skipped: $skipped, '
      'idCollisions: ${idCollisions.length}, rejected: ${rejected.length})';
}

/// A pulled op the applier parked instead of applying (see
/// [SyncApplyResult.rejected]).
class SyncRejectedInbound {
  const SyncRejectedInbound({required this.op, required this.reason, required this.opSeq, this.error});
  final SyncOpDto op;
  final String reason;
  final int opSeq;

  /// The exception text for [kApplyErrorReason]; null for validation verdicts.
  final String? error;

  @override
  String toString() => 'SyncRejectedInbound(${op.entity}/${op.entityId}.${op.field} $reason, op_seq $opSeq)';
}

/// Whether [error], thrown while applying one pulled op, would recur on every
/// attempt (so parking the op is right) rather than being an environmental
/// hiccup (so the batch must abort and be retried).
///
/// Deterministic: SQLite result codes CONSTRAINT (19, any extended code),
/// MISMATCH (20), RANGE (25) and exactly ERROR (1, SQL logic) — except the
/// code-1 messages that describe connection / transaction / schema state
/// rather than the op (no such savepoint / table / module, transaction
/// misuse) — plus Dart type/format/argument errors. Everything else — BUSY, LOCKED, IOERR, FULL, CANTOPEN, NOMEM, a
/// closed database, OPFS/IndexedDB failures, unknown errors — is transient.
/// Matched on the message because `SqliteException` may arrive wrapped
/// (`DriftRemoteException` from the background isolate / web worker), whose
/// `toString()` is the cause's.
bool isDeterministicApplyFailure(Object error) {
  if (error is TypeError || error is FormatException || error is ArgumentError) return true;
  final text = '$error';
  final m = RegExp(r'SqliteException\((\d+)\)').firstMatch(text);
  if (m == null) return false;
  final code = int.parse(m.group(1)!);
  if (code == 1) {
    return !RegExp(r'no such savepoint|no transaction is active|within a transaction|no such table|no such module')
        .hasMatch(text);
  }
  return const {19, 20, 25}.contains(code & 0xff);
}

/// Applies remote ops per CLOUD-SYNC-CONTRACT §2.3.
///
/// One Drift transaction per batch, one savepoint per op: an op that is
/// invalid for this schema or fails in SQL is stored as remote and parked in
/// `sync_rejections` instead of rolling the batch back (which would retry
/// the same page forever, on every member's device). For every op:
///   1. duplicate (same entity/id/field/hlc/device) → skip;
///   2. the HLC clock absorbs the remote HLC;
///   3. the op is applied iff its HLC beats the local HLC for the same
///      (entity, entity_id, field) — the latest usable `sync_ops` row (ops
///      refused as invalid never count; a `*` counts only for the columns it
///      carries validly) for that field
///      or for `*` (a whole-row op writes every field), else the row's
///      `updated_hlc` / `added_hlc`; ties fall to the HLC's device suffix;
///   4. the op is recorded in `sync_ops` with its origin `device_id` and
///      `pushed_at` set, so it informs future comparisons but is never
///      pushed back.
///
/// On OR-Set join tables `added_hlc` is the HLC of the add: metadata field
/// ops (caption, captured_at, display_order) and `removed_hlc` never
/// re-stamp it — see [_orSetMembershipColumns].
/// Unique-key conflicts follow the 1.1.0 rule ([_resolveUniqueConflict]);
/// a [readOnly] applier resolves them without recording ops. [repair]
/// re-materialises rows missing without a tombstone, retries parked ops and
/// re-applies 1.1.0 `@applyCareEvent` ops, which are expanded into
/// per-column LWW writes ([_applyLegacyCareEvent]) and count as covering
/// those columns in every comparison.
///
/// Tombstones are final: a tombstoned row ignores every later op. A field op
/// for a row we have not received yet is kept and materialised when the `*`
/// op arrives (newer field ops override the `*` payload).
class SyncApplier {
  SyncApplier({
    required this.db,
    required this.opLog,
    required this.clock,
    this.readOnly = false,
    int Function()? nowMillis,
  }) : _nowMillis = nowMillis ?? (() => DateTime.now().toUtc().millisecondsSinceEpoch);

  final AppDatabase db;
  final OpLogWriter opLog;
  final HlcClock clock;

  /// The account cannot push to this collection (a viewer). Conflict
  /// resolution then changes rows locally WITHOUT recording ops: they could
  /// never be pushed (the pending count would never drop), and every writer
  /// resolving the same conflict pushes the same tombstone / re-point ops.
  final bool readOnly;
  final int Function() _nowMillis;

  /// Whether [repair] already ran its full pass on this instance.
  bool _repaired = false;

  /// Set by [_insertFromWholeRow] when the op's id is held by another
  /// tenant; consumed by [_applyOne] once the remote op has a `seq`.
  String? _collisionTenant;

  String get tenantId => opLog.tenantId;
  EntityCodecs get codecs => opLog.codecs;

  /// Never throws because of one op: each op runs in its own savepoint
  /// ([_applyIsolated]), so a page with a bad op still commits and the pull
  /// cursor advances. Only a failure of the bookkeeping itself (the DB is
  /// gone) aborts the batch.
  Future<SyncApplyResult> applyBatch(List<SyncOpDto> ops) async {
    final result = SyncApplyResult();
    await _replayParkedPhotoCollisions(result);
    if (ops.isEmpty) return result;
    _scheduleCover = {};
    try {
      await db.transaction(() async {
        for (final op in ops) {
          await _applyIsolated(op, result);
        }
      });
    } finally {
      _scheduleCover = null;
    }
    return result;
  }

  /// One op inside a nested transaction (SQLite savepoint). Invalid ops are
  /// refused up front ([_invalidReason]); anything that still throws rolls
  /// back to the savepoint — no half-applied row, no half-resolved conflict.
  /// A deterministic failure ([isDeterministicApplyFailure]) is parked as
  /// [kApplyErrorReason] ([repair] retries it); anything else (busy/locked
  /// DB, I/O, disk full, closed DB) is rethrown so the batch aborts and the
  /// pull retries the page later instead of parking a good op.
  Future<void> _applyIsolated(SyncOpDto op, SyncApplyResult result) async {
    final applied = result.applied;
    final appliedEntities = {...result.appliedEntities};
    final skipped = result.skipped;
    final photos = result.remotePhotoShas.length;
    final collisions = result.idCollisions.length;
    try {
      // requireNew: throws UnsupportedError (→ rethrown below) instead of
      // silently running unisolated on an executor without savepoints.
      await db.transaction(() => _applyOne(op, result), requireNew: true);
    } catch (e) {
      // Restore the counters the failed attempt may have touched.
      result.applied = applied;
      result.appliedEntities
        ..clear()
        ..addAll(appliedEntities);
      result.skipped = skipped;
      result.remotePhotoShas.length = photos;
      result.idCollisions.length = collisions;
      _collisionTenant = null;
      _scheduleCover?.clear(); // the savepoint rolled back what it saw
      if (!isDeterministicApplyFailure(e)) rethrow;
      debugPrint('sync: could not apply ${op.entity}/${op.entityId}.${op.field} @${op.hlc}: $e');
      await _parkInbound(op, reason: kApplyErrorReason, result: result, error: '$e');
    }
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

    final invalid = _invalidReason(codec, op);
    if (invalid != null) {
      debugPrint('sync: refusing ${op.entity}/${op.entityId}.${op.field} @${op.hlc}: $invalid');
      await _parkInbound(op, reason: kInvalidRemoteOpReason, result: result, deviceId: deviceId);
      return;
    }

    final bool applied;
    if (op.field == kTombstoneField) {
      applied = await _applyTombstone(codec, op, opHlc, deviceId);
    } else if (op.field == kWholeRowField) {
      applied = await _applyWholeRow(codec, op, opHlc, deviceId, result);
    } else if (codec.isOrSet && op.field == 'removed_hlc' && op.entityId.contains('/')) {
      applied = await _applyLegacyPairRemove(codec, op, opHlc, deviceId);
    } else if (_isLegacyCareEvent(codec, op.field)) {
      applied = await _applyLegacyCareEvent(codec, op, opHlc, deviceId);
    } else {
      applied = await _applyField(codec, op, opHlc, deviceId);
    }
    if (applied) {
      result.applied++;
      result.appliedEntities.add(op.entity);
    } else {
      result.skipped++;
    }
    final seq = await opLog.recordRemote(op, deviceId: deviceId, nowMillis: _nowMillis());
    if (codec.entity == 'care_schedules') _noteScheduleOp(codec, op, opHlc);
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

  /// Store [op] as an already-pushed remote op (a re-delivery is then an
  /// idempotent skip) and park it in `sync_rejections` under [reason]. The
  /// ledger shows it in Me → Cloud; "Retry all" only forgets it (it is not
  /// ours to push).
  Future<void> _parkInbound(
    SyncOpDto op, {
    required String reason,
    required SyncApplyResult result,
    String? deviceId,
    String? error,
  }) async {
    final origin = deviceId ?? op.deviceId ?? _hlcDevice(op.hlc);
    final seq = await opLog.recordRemote(op, deviceId: origin, nowMillis: _nowMillis());
    await db.into(db.syncRejections).insert(
          SyncRejectionsCompanion.insert(
            opSeq: Value(seq),
            tenantId: tenantId,
            entity: op.entity,
            entityId: op.entityId,
            field: op.field,
            reason: reason,
            hlc: op.hlc,
            at: _nowMillis(),
            parked: const Value(true),
          ),
          mode: InsertMode.insertOrReplace,
        );
    result.skipped++;
    result.rejected.add(SyncRejectedInbound(op: op, reason: reason, opSeq: seq, error: error));
  }

  static String _hlcDevice(String hlc) {
    try {
      return Hlc.parse(hlc).deviceId;
    } on FormatException {
      return '';
    }
  }

  // --- validation -------------------------------------------------------------

  /// Why [op] can never be applied on this schema, or null when it can.
  /// A pure function of the op, so every device reaches the same verdict and
  /// [_isUsable] can drop such ops from LWW comparisons consistently.
  ///
  ///  * a field op whose value does not decode to the column type, or is
  ///    null for a NOT NULL column (e.g. `{plants, nickname, null}` pushed by
  ///    an older client — the server takes it, every SQLite update fails);
  ///  * a `*` op whose value is not an object.
  ///
  /// A `*` payload with individual bad columns is NOT refused: those columns
  /// are treated as absent (see [EntityCodec.decodeRow] `dropInvalid`).
  String? _invalidReason(EntityCodec codec, SyncOpDto op) {
    if (op.field == kTombstoneField) return null;
    if (op.field == kWholeRowField) return op.value is Map ? null : 'whole-row value is not an object';
    if (!codec.isWireColumn(op.field) || _isMetaColumn(codec, op.field)) return null; // ignored, not invalid
    if (codec.isOrSet && op.field == 'removed_hlc') {
      if (op.entityId.contains('/')) return null; // legacy pair remove
      if (op.value == null) return null; // "removed at the op's own HLC"
    }
    return codec.acceptsValue(op.field, op.value) ? null : 'bad value for ${op.field}';
  }

  /// Stored ops that take part in LWW: everything except ops refused by
  /// [_invalidReason] (they were never applied anywhere, so letting them
  /// outrank an older valid op would make the result depend on arrival
  /// order).
  bool _isUsable(EntityCodec codec, SyncOpRow row) {
    if (Hlc.tryParse(row.hlc) == null) return false;
    final Object? value;
    try {
      value = row.valueJson == null ? null : json.decode(row.valueJson!);
    } on FormatException {
      return row.field == kTombstoneField;
    }
    return _invalidReason(
          codec,
          SyncOpDto(entity: row.entity, entityId: row.entityId, field: row.field, value: value, hlc: row.hlc),
        ) ==
        null;
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
    final ops = await _usableOps(codec, op.entity, op.entityId);
    if (ops.any((o) => o.field == kTombstoneField)) return false;

    if (row == null) {
      return _insertFromWholeRow(codec, op, opHlc, deviceId, wire, ops, result);
    }

    final columnMax = _columnMaxHlcs(codec, ops);
    final rowHlc = _rowHlc(codec, row);
    final decoded = codec.decodeRow(wire, dropInvalid: true);
    final updates = <String, Object?>{};
    for (final e in decoded.entries) {
      final c = e.key;
      if (_isMetaColumn(codec, c)) continue;
      final local = columnMax[c] ?? rowHlc;
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

    final sql = codec.decodeRow(wire, fillDefaults: true, dropInvalid: true);
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

    // Per column, the newest op wins: the `*` payload covers only the
    // columns it carries validly ([_starCovers]). Other `*` ops already in
    // the log for this id (a re-send, or the one being repaired) are folded
    // in column by column first.
    final cover = <String, Hlc>{
      for (final c in codec.decodeRow(wire, dropInvalid: true).keys) c: opHlc,
    };
    for (final o in ops) {
      if (o.field != kWholeRowField || (o.hlc == op.hlc && o.deviceId == deviceId)) continue;
      final h = Hlc.parse(o.hlc);
      final payload = _starPayload(o);
      for (final c in codec.decodeRow(payload, dropInvalid: true).keys) {
        if (_isMetaColumn(codec, c)) continue;
        final prev = cover[c];
        if (prev != null && h <= prev) continue;
        cover[c] = h;
        sql[c] = codec.decodeField(c, payload[c]);
        if (h > rowHlc) {
          rowHlc = h;
          sql['device_id'] = o.deviceId;
        }
      }
    }

    // Field ops that arrived before the row (and legacy `@applyCareEvent`
    // ops, column by column): the newest per field wins over the `*`
    // payload(s).
    final newest = <String, (Hlc, Object?, SyncOpRow)>{};
    void offer(String column, Hlc h, Object? wireValue, SyncOpRow o) {
      final covered = cover[column];
      if (covered != null && h <= covered) return;
      final prev = newest[column];
      if (prev == null || h > prev.$1) newest[column] = (h, wireValue, o);
    }

    for (final o in ops) {
      if (o.field == kWholeRowField || o.field == kTombstoneField) continue;
      if (_isLegacyCareEvent(codec, o.field)) {
        final h = Hlc.parse(o.hlc);
        for (final e in _legacyCareEventColumns(codec, _starPayload(o)).entries) {
          offer(e.key, h, e.value, o);
        }
        continue;
      }
      if (!codec.isWireColumn(o.field)) continue;
      offer(o.field, Hlc.parse(o.hlc), SyncOpDto.fromRow(o).value, o);
    }
    for (final e in newest.entries) {
      final (h, wireValue, o) = e.value;
      sql[e.key] = codec.decodeField(e.key, wireValue);
      if (codec.isOrSet && e.key == 'removed_hlc') sql[e.key] ??= o.hlc;
      if (!_restampsRowHlc(codec, e.key)) continue;
      if (h > rowHlc) {
        rowHlc = h;
        sql['device_id'] = o.deviceId;
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
    } catch (e) {
      // Constraint violation we could not resolve (e.g. duplicate OR-Set add
      // with an identical added_hlc): keep the op, drop the row ([repair]
      // retries rows that are missing without a tombstone). A transient
      // failure must abort the batch instead.
      if (!isDeterministicApplyFailure(e)) rethrow;
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
    final rowHlc = _rowHlc(codec, row);
    final Hlc? local;
    if (codec.entity == 'care_schedules' && kLegacyCareEventColumns.contains(op.field)) {
      // Same rule as below, but a 1.1.0 `@applyCareEvent` op covers these
      // columns too; answered from the per-batch cover map (linear in the
      // batch — a schedule's log grows by six ops per watering).
      final cover = await _legacyCoverFor(codec, op.entityId);
      if (cover == null) return false; // tombstoned
      local = cover[op.field] ?? rowHlc;
    } else {
      final latest = _latest(
        codec,
        await _usableOps(codec, op.entity, op.entityId, fields: [op.field, kWholeRowField, kTombstoneField]),
        op.field,
      );
      if (latest != null && latest.field == kTombstoneField) return false;
      local = latest == null ? rowHlc : Hlc.parse(latest.hlc);
    }
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

  // --- legacy `@applyCareEvent` ---------------------------------------------

  /// The columns a 1.1.0 `@applyCareEvent` op may write — exactly what that
  /// build put in its payload. Anything else in the object is ignored, so a
  /// malformed / forged op cannot move a schedule to another plant or
  /// delete it.
  static const Set<String> kLegacyCareEventColumns = {
    'last_done_at',
    'current_interval_days',
    'next_due_at',
    'snooze_count',
    'recent_events_json',
    'enabled',
  };

  bool _isLegacyCareEvent(EntityCodec codec, String field) =>
      field == kLegacyApplyCareEventField && codec.entity == 'care_schedules';

  /// The usable columns of a legacy payload, as wire values.
  Map<String, Object?> _legacyCareEventColumns(EntityCodec codec, Map<String, dynamic> payload) => {
        for (final e in payload.entries)
          if (kLegacyCareEventColumns.contains(e.key) && codec.acceptsValue(e.key, e.value)) e.key: e.value,
      };

  /// Per-batch cache for [_applyLegacyCareEvent]: care_schedules id → the
  /// newest HLC bearing on each legacy column (field ops, covering `*`, other
  /// legacy ops), or null when the row has a tombstone. Built from the log on
  /// first touch, then kept current as ops of the batch are recorded
  /// ([_noteScheduleOp]), so a page of N legacy ops for one schedule is O(N)
  /// instead of re-reading and re-decoding the whole log per op.
  Map<String, Map<String, Hlc>?>? _scheduleCover;

  Future<Map<String, Hlc>?> _legacyCoverFor(EntityCodec codec, String id) async {
    final cache = _scheduleCover;
    if (cache != null && cache.containsKey(id)) return cache[id];
    final ops = await _usableOps(codec, codec.entity, id,
        fields: [...kLegacyCareEventColumns, kWholeRowField, kTombstoneField, kLegacyApplyCareEventField]);
    final cover = ops.any((o) => o.field == kTombstoneField) ? null : _columnMaxHlcs(codec, ops);
    cache?[id] = cover;
    return cover;
  }

  /// Keep [_scheduleCover] in step with a `care_schedules` op just recorded
  /// by [_applyOne].
  void _noteScheduleOp(EntityCodec codec, SyncOpDto op, Hlc opHlc) {
    final cache = _scheduleCover;
    if (cache == null) return;
    if (op.field == kWholeRowField) {
      cache.clear(); // may also have resolved a unique conflict on another id
      return;
    }
    if (!cache.containsKey(op.entityId)) return;
    final cover = cache[op.entityId];
    if (cover == null) return;
    if (op.field == kTombstoneField) {
      cache[op.entityId] = null;
      return;
    }
    void bump(String c) {
      final prev = cover[c];
      if (prev == null || opHlc > prev) cover[c] = opHlc;
    }

    if (_isLegacyCareEvent(codec, op.field)) {
      final v = op.value;
      if (v is Map) _legacyCareEventColumns(codec, v.map((k, v) => MapEntry('$k', v))).keys.forEach(bump);
    } else if (kLegacyCareEventColumns.contains(op.field)) {
      bump(op.field);
    }
  }

  /// A 1.1.0 `@applyCareEvent` op carries the absolute post-event values of
  /// the schedule (not a delta), so it is applied as if it were one field op
  /// per payload column, all at the op's HLC: each column is written iff the
  /// op beats the newest op bearing on that column (field op, covering `*`,
  /// other legacy op). The comparison is against the log, not the row, so
  /// arrival order does not matter.
  Future<bool> _applyLegacyCareEvent(EntityCodec codec, SyncOpDto op, Hlc opHlc, String deviceId) async {
    final value = op.value;
    if (value is! Map) return false;
    final columns = _legacyCareEventColumns(codec, value.map((k, v) => MapEntry('$k', v)));
    if (columns.isEmpty) return false;
    final row = await _readRow(codec, op.entityId);
    if (row == null) return false; // folded in when the `*` op materialises the row
    if (_rowIsDeleted(codec, row)) return false;
    final cover = await _legacyCoverFor(codec, op.entityId);
    if (cover == null) return false; // tombstoned
    final rowHlc = _rowHlc(codec, row);
    final updates = <String, Object?>{};
    for (final e in columns.entries) {
      final local = cover[e.key] ?? rowHlc;
      if (local == null || opHlc > local) updates[e.key] = codec.decodeField(e.key, e.value);
    }
    if (updates.isEmpty) return false;
    if (rowHlc == null || opHlc > rowHlc) {
      updates[codec.hlcColumn] = op.hlc;
      updates['device_id'] = deviceId;
    }
    await _update(codec, op.entityId, updates);
    return true;
  }

  static const String _legacyCareEventsMarker = 'reapply_legacy_care_events_v1';

  /// One-shot (per tenant, per database) repair: re-apply the stored
  /// `@applyCareEvent` ops. Builds before this one stored them as "ignored",
  /// so a device that pulled a 1.1.0 peer's waterings still shows the old
  /// due date, and a 1.1.0 device's own waterings could have been
  /// overwritten by older field ops. Ops pulled from now on go through
  /// [_applyLegacyCareEvent], hence the marker.
  ///
  /// Linear per schedule: the log is decoded once; per column the newest
  /// legacy op is written iff it beats the newest non-legacy op bearing on
  /// that column and the row does not already hold its value.
  Future<void> _reapplyLegacyCareEvents(SyncApplyResult result) async {
    final codec = codecs.forEntity('care_schedules');
    if (codec == null) return;
    if (await hasSyncMarker(db, tenantId: tenantId, name: _legacyCareEventsMarker)) return;

    final ids = await db
        .customSelect(
          'SELECT DISTINCT entity_id AS id FROM sync_ops WHERE tenant_id = ? AND entity = ? AND field = ?',
          variables: [
            Variable<String>(tenantId),
            Variable<String>(codec.entity),
            Variable<String>(kLegacyApplyCareEventField),
          ],
          readsFrom: {db.syncOps},
        )
        .get();
    for (final m in ids) {
      final id = m.read<String>('id');
      try {
        final applied = await db.transaction(() => _reapplyLegacyFor(codec, id), requireNew: true);
        if (applied) result.applied++;
      } catch (e) {
        if (!isDeterministicApplyFailure(e)) rethrow;
        debugPrint('sync: repair could not re-apply legacy care events of care_schedules/$id: $e');
      }
    }
    await setSyncMarker(db, tenantId: tenantId, name: _legacyCareEventsMarker, atMillis: _nowMillis());
  }

  Future<bool> _reapplyLegacyFor(EntityCodec codec, String id) async {
    final row = await _readRow(codec, id);
    if (row == null || _rowIsDeleted(codec, row)) return false;
    final ops = await _usableOps(codec, codec.entity, id);
    if (ops.any((o) => o.field == kTombstoneField)) return false;
    final others = _columnMaxHlcs(codec, [for (final o in ops) if (o.field != kLegacyApplyCareEventField) o]);
    final best = <String, (Hlc, Object?, String)>{};
    for (final o in ops) {
      if (o.field != kLegacyApplyCareEventField) continue;
      final h = Hlc.parse(o.hlc);
      for (final e in _legacyCareEventColumns(codec, _starPayload(o)).entries) {
        final prev = best[e.key];
        if (prev == null || h > prev.$1) best[e.key] = (h, e.value, o.deviceId);
      }
    }
    final rowHlc = _rowHlc(codec, row);
    Hlc? stamp;
    String? stampDevice;
    final updates = <String, Object?>{};
    for (final e in best.entries) {
      final (h, wire, device) = e.value;
      final other = others[e.key];
      if (other != null && h <= other) continue;
      final v = codec.decodeField(e.key, wire);
      final current = row[e.key];
      if (v == current || v is bool && current == (v ? 1 : 0)) continue;
      updates[e.key] = v;
      if ((rowHlc == null || h > rowHlc) && (stamp == null || h > stamp)) {
        stamp = h;
        stampDevice = device;
      }
    }
    if (updates.isEmpty) return false;
    if (stamp != null) {
      updates[codec.hlcColumn] = stamp.encode();
      updates['device_id'] = stampDevice;
    }
    await _update(codec, id, updates);
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
  /// "same" row independently, or when a row was deleted and re-created under
  /// a new id (the index is not partial, so a soft-deleted row still holds
  /// the key).
  ///
  /// * A soft-deleted holder is dead: its row is purged (no op — its
  ///   tombstone is already in the log, so later ops for it stay inert).
  /// * Live vs live keeps the rule 1.1.0 clients apply, so a mixed fleet
  ///   converges: the incoming op's HLC against the holder's row HLC, the
  ///   greater survives; the loser is tombstoned through a LOCAL op (a local
  ///   loser row is physically removed). For `tags`, live `plant_tags` rows
  ///   are re-pointed at the survivor first ([_repointPlantTags]).
  ///   When [readOnly] the same changes are made locally without ops — the
  ///   writers resolving the same conflict push them.
  /// Returns false when the incoming row lost (caller must not insert).
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
    final holders = await db
        .customSelect(
          'SELECT * FROM ${codec.table.actualTableName} '
          'WHERE tenant_id = ? AND ${codec.idColumn} != ? AND $where',
          variables: [
            Variable<String>(tenantId),
            Variable<String>(incomingId),
            for (final k in key) Variable<String>('${k.$2}'),
          ],
          readsFrom: {codec.table},
        )
        .get();
    for (final existing in holders) {
      final existingId = existing.data[codec.idColumn] as String;
      if (!_rowIsDeleted(codec, existing.data)) {
        final existingHlc = _rowHlc(codec, existing.data) ?? const Hlc(0, 0, '');
        if (!(incomingHlc > existingHlc)) {
          if (codec.entity == 'tags') await _repointPlantTags(loserId: incomingId, survivorId: existingId);
          if (!readOnly) await opLog.recordTombstone(entity: codec.entity, entityId: incomingId);
          return false;
        }
        if (codec.entity == 'tags') await _repointPlantTags(loserId: existingId, survivorId: incomingId);
        if (!readOnly) await opLog.recordTombstone(entity: codec.entity, entityId: existingId);
      }
      await db.customUpdate(
        'DELETE FROM ${codec.table.actualTableName} WHERE ${codec.idColumn} = ? AND tenant_id = ?',
        variables: [Variable<String>(existingId), Variable<String>(tenantId)],
        updates: {codec.table},
        updateKind: UpdateKind.delete,
      );
    }
    return true;
  }

  /// Move live `plant_tags` rows off a losing tag onto the survivor, as
  /// ordinary LOCAL field ops so every device converges (local-only when
  /// [readOnly]). Where the plant already carries the survivor, the loser's
  /// row is detached instead (`removed_hlc`), so nothing keeps pointing at a
  /// deleted tag.
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
        final h = readOnly
            ? clock.now()
            : await opLog.recordFieldUpdate(entity: 'plant_tags', entityId: row.id, field: 'removed_hlc', value: null);
        await (db.update(db.plantTags)..where((r) => r.id.equals(row.id))).write(
          PlantTagsCompanion(removedHlc: Value(h.encode()), deviceId: Value(clock.deviceId)),
        );
      } else {
        final h = readOnly
            ? clock.now()
            : await opLog.recordFieldUpdate(entity: 'plant_tags', entityId: row.id, field: 'tag_id', value: survivorId);
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

  // --- repair -----------------------------------------------------------------

  /// Self-healing pass, run by the sync runner before pulling. The first
  /// call on an instance (i.e. every launch / collection switch) does the
  /// full pass; later calls only retry what the user asked to retry.
  ///
  ///  1. Re-applies ops parked as [kApplyErrorReason] — all of them on the
  ///     full pass, afterwards only rows "Retry all" flagged (`parked`
  ///     false). Each goes through the normal per-op path again and is
  ///     re-parked if it still fails.
  ///  2. Full pass only: every `*` op in the log whose row is missing here
  ///     and that has no tombstone is materialised again (its newest `*`
  ///     plus the newer field ops), resolving unique-key conflicts as usual.
  ///     Heals rows earlier builds dropped — notably a reminder / tag
  ///     re-created after a delete, whose insert 1.1.0 lost to the dead row
  ///     still holding the unique key — and `*` ops whose insert failed.
  ///  3. Full pass only: re-applies stored 1.1.0 `@applyCareEvent` ops
  ///     ([_reapplyLegacyCareEvents]) that earlier builds ignored.
  ///
  /// Transient failures propagate (the runner retries the cycle).
  Future<SyncApplyResult> repair() async {
    final full = !_repaired;
    final result = SyncApplyResult();
    await db.transaction(() async {
      final parked = await (db.select(db.syncRejections)
            ..where((r) =>
                r.tenantId.equals(tenantId) &
                r.reason.equals(kApplyErrorReason) &
                (full ? const Constant(true) : r.parked.equals(false))))
          .get();
      for (final r in parked) {
        await (db.delete(db.syncRejections)..where((x) => x.opSeq.equals(r.opSeq))).go();
        final stored = await (db.select(db.syncOps)
              ..where((o) => o.seq.equals(r.opSeq) & o.tenantId.equals(tenantId)))
            .getSingleOrNull();
        if (stored == null) continue;
        // Our own op (e.g. a still-pending local `*` whose re-materialise
        // failed) is never re-recorded as remote — that would mark it pushed
        // and it would never reach the server. The repair scan retries it.
        if (stored.pushedAt == null || stored.deviceId == clock.deviceId) continue;
        await (db.delete(db.syncOps)..where((o) => o.seq.equals(stored.seq))).go();
        await _applyIsolated(SyncOpDto.fromRow(stored), result);
      }
      if (full) {
        for (final codec in codecs.all) {
          await _rematerialiseMissing(codec, result);
        }
        await _reapplyLegacyCareEvents(result);
      }
    });
    _repaired = true;
    return result;
  }

  Future<void> _rematerialiseMissing(EntityCodec codec, SyncApplyResult result) async {
    final table = codec.table.actualTableName;
    final missing = await db
        .customSelect(
          'SELECT DISTINCT o.entity_id AS id FROM sync_ops o '
          'WHERE o.tenant_id = ? AND o.entity = ? AND o.field = ? '
          'AND NOT EXISTS (SELECT 1 FROM $table t WHERE t.${codec.idColumn} = o.entity_id) '
          'AND NOT EXISTS (SELECT 1 FROM sync_ops x WHERE x.tenant_id = o.tenant_id '
          'AND x.entity = o.entity AND x.entity_id = o.entity_id AND x.field = ?)',
          variables: [
            Variable<String>(tenantId),
            Variable<String>(codec.entity),
            Variable<String>(kWholeRowField),
            Variable<String>(kTombstoneField),
          ],
          readsFrom: {db.syncOps, codec.table},
        )
        .get();
    for (final m in missing) {
      final id = m.read<String>('id');
      final ops = await _usableOps(codec, codec.entity, id);
      final star = _latest(codec, ops, null, onlyField: kWholeRowField);
      if (star == null) continue;
      final dto = SyncOpDto.fromRow(star);
      try {
        final inserted = await db.transaction(
          () => _insertFromWholeRow(
              codec, dto, Hlc.parse(star.hlc), star.deviceId, _starPayload(star), ops, result),
          requireNew: true,
        );
        _collisionTenant = null;
        if (inserted) {
          result.applied++;
          result.appliedEntities.add(codec.entity);
        }
      } catch (e) {
        _collisionTenant = null;
        if (!isDeterministicApplyFailure(e)) rethrow;
        debugPrint('sync: repair could not materialise ${codec.entity}/$id: $e');
        await db.into(db.syncRejections).insert(
              SyncRejectionsCompanion.insert(
                opSeq: Value(star.seq),
                tenantId: tenantId,
                entity: codec.entity,
                entityId: id,
                field: kWholeRowField,
                reason: kApplyErrorReason,
                hlc: star.hlc,
                at: _nowMillis(),
                parked: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    }
  }

  // --- row helpers -----------------------------------------------------------

  /// `sync_ops` rows for one entity row that take part in LWW ([_isUsable]),
  /// restricted to [fields] (checked before any JSON is decoded).
  Future<List<SyncOpRow>> _usableOps(EntityCodec codec, String entity, String entityId, {List<String>? fields}) async => [
        for (final o in await opLog.opsFor(entity: entity, entityId: entityId, fields: fields))
          if (_isUsable(codec, o)) o,
      ];

  /// Decoded `*` payload of a stored op (empty when not an object).
  Map<String, dynamic> _starPayload(SyncOpRow star) {
    final raw = star.valueJson;
    if (raw == null) return const {};
    try {
      final v = json.decode(raw);
      return v is Map ? v.map((k, v) => MapEntry('$k', v)) : const {};
    } on FormatException {
      return const {};
    }
  }

  /// Whether a stored `*` op wrote [column]: its payload carries the column
  /// with a value the column accepts. A column it lacks or carried invalidly
  /// (dropped on apply) is not outranked by it.
  bool _starCovers(EntityCodec codec, SyncOpRow star, String column) {
    final payload = _starPayload(star);
    if (_isLegacyCareEvent(codec, star.field) && !kLegacyCareEventColumns.contains(column)) return false;
    return payload.containsKey(column) && codec.acceptsValue(column, payload[column]);
  }

  /// Highest-HLC op among [ops] that bears on [column]: a field op on it, a
  /// `*` that covers it ([_starCovers]) or a tombstone. With [onlyField],
  /// the highest op of that field instead.
  SyncOpRow? _latest(EntityCodec codec, List<SyncOpRow> ops, String? column, {String? onlyField}) {
    SyncOpRow? best;
    Hlc? bestHlc;
    for (final o in ops) {
      if (onlyField != null) {
        if (o.field != onlyField) continue;
      } else if (o.field == kWholeRowField || _isLegacyCareEvent(codec, o.field)) {
        if (!_starCovers(codec, o, column!)) continue;
      } else if (o.field != column && o.field != kTombstoneField) {
        continue;
      }
      final h = Hlc.parse(o.hlc);
      if (bestHlc == null || h > bestHlc) {
        best = o;
        bestHlc = h;
      }
    }
    return best;
  }

  /// Per column, the highest HLC among field ops on it and `*` ops that
  /// cover it.
  Map<String, Hlc> _columnMaxHlcs(EntityCodec codec, List<SyncOpRow> ops) {
    final out = <String, Hlc>{};
    void bump(String c, Hlc h) {
      final prev = out[c];
      if (prev == null || h > prev) out[c] = h;
    }

    for (final o in ops) {
      final h = Hlc.parse(o.hlc);
      if (o.field == kWholeRowField) {
        final payload = _starPayload(o);
        for (final e in payload.entries) {
          if (codec.isWireColumn(e.key) && codec.acceptsValue(e.key, e.value)) bump(e.key, h);
        }
      } else if (_isLegacyCareEvent(codec, o.field)) {
        for (final c in _legacyCareEventColumns(codec, _starPayload(o)).keys) {
          bump(c, h);
        }
      } else if (o.field != kTombstoneField) {
        bump(o.field, h);
      }
    }
    return out;
  }

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
}
