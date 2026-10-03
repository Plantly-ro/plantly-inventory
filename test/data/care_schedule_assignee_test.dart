import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

import '../helpers/recording_reminder_sync.dart';

/// MULTI-USER-V2 §0 task assignment at the repository level: the synced
/// `assignee_user_id` column is written by upsert / edit / setAssignee,
/// every change is one `assignee_user_id` field op, and the stale-member
/// sweep (`clearAssigneesNotIn`) clears only what no longer points at a
/// member — through ops, so the other devices converge.
void main() {
  late AppDatabase db;
  late PlantRepository plants;
  late CareScheduleRepository schedules;
  late RecordingReminderSync sync;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'test-device'), tenantId: 'tenant-local');
    sync = RecordingReminderSync(db: db, clock: () => DateTime.utc(2026, 5, 1));
    plants = PlantRepository(db: db, opLog: opLog);
    schedules = CareScheduleRepository(db: db, opLog: opLog, reminderSync: sync);
  });
  tearDown(() => db.close());

  Future<List<SyncOpRow>> assigneeOps() async =>
      (await db.select(db.syncOps).get()).where((o) => o.field == 'assignee_user_id').toList();

  test('upsert stores the assignee on the row and in the `*` payload; unset = null', () async {
    final p = await plants.create(nickname: 'Bob');
    final a = await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, assigneeUserId: 'u-bob');
    final b = await schedules.upsert(plantId: p.id, type: 'mist', baseIntervalDays: 2);
    expect(a.assigneeUserId, 'u-bob');
    expect(b.assigneeUserId, isNull);
    final create = (await db.select(db.syncOps).get()).where((o) => o.entityId == a.id && o.field == '*').single;
    expect((json.decode(create.valueJson!) as Map)['assignee_user_id'], 'u-bob');
  });

  test('edit: absent leaves the assignee alone, Value(x) sets it with one op, Value(null) clears it', () async {
    final p = await plants.create(nickname: 'Fern');
    final s = await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, assigneeUserId: 'u-bob');
    final due = DateTime.utc(2026, 6, 1);

    await schedules.edit(s.id, baseIntervalDays: 5, recurrenceMode: 'fixed', nextDueAt: due);
    expect((await schedules.forPlantAndType(p.id, 'water'))!.assigneeUserId, 'u-bob', reason: 'absent = untouched');
    expect(await assigneeOps(), isEmpty);

    await schedules.edit(s.id, baseIntervalDays: 5, recurrenceMode: 'fixed', nextDueAt: due, assigneeUserId: const Value('u-bob'));
    expect(await assigneeOps(), isEmpty, reason: 'same value → no op');

    await schedules.edit(s.id, baseIntervalDays: 5, recurrenceMode: 'fixed', nextDueAt: due, assigneeUserId: const Value('u-alice'));
    expect((await schedules.forPlantAndType(p.id, 'water'))!.assigneeUserId, 'u-alice');
    var ops = await assigneeOps();
    expect(ops, hasLength(1));
    expect(json.decode(ops.single.valueJson!), 'u-alice');
    expect(ops.single.pushedAt, isNull, reason: 'pending, will sync');

    await schedules.edit(s.id, baseIntervalDays: 5, recurrenceMode: 'fixed', nextDueAt: due, assigneeUserId: const Value(null));
    expect((await schedules.forPlantAndType(p.id, 'water'))!.assigneeUserId, isNull);
    ops = await assigneeOps();
    expect(ops, hasLength(2));
    expect(ops.last.valueJson, 'null');
  });

  test('setAssignee writes one op per actual change and re-syncs reminders', () async {
    final p = await plants.create(nickname: 'Pete');
    final s = await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7);
    final before = sync.calls;
    await schedules.setAssignee(s.id, 'u-bob');
    await schedules.setAssignee(s.id, 'u-bob');
    expect((await schedules.forPlantAndType(p.id, 'water'))!.assigneeUserId, 'u-bob');
    expect(await assigneeOps(), hasLength(1));
    expect(sync.calls, greaterThan(before));
  });

  test('clearAssigneesNotIn: clears former members only, via pending null ops; deleted rows and other tenants untouched', () async {
    final p = await plants.create(nickname: 'A');
    final keep = await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, assigneeUserId: 'u-alice');
    final stale = await schedules.upsert(plantId: p.id, type: 'mist', baseIntervalDays: 2, assigneeUserId: 'u-gone');
    final none = await schedules.upsert(plantId: p.id, type: 'fertilize', baseIntervalDays: 30);
    final deleted = await schedules.upsert(plantId: p.id, type: 'rotate', baseIntervalDays: 10, assigneeUserId: 'u-gone');
    await schedules.softDelete(deleted.id);
    // A row of another tenant assigned to the removed user: not ours to touch.
    await db.into(db.careSchedules).insert(CareSchedulesCompanion.insert(
        id: 'other-tenant', tenantId: 'tenant-2', plantId: 'px', type: 'water', baseIntervalDays: 1, currentIntervalDays: 1,
        updatedHlc: '0-0-t', deviceId: 't', assigneeUserId: const Value('u-gone')));

    final before = sync.calls;
    expect(await schedules.clearAssigneesNotIn({'u-alice', 'u-me'}), 1);
    expect(sync.calls, greaterThan(before), reason: 'OS reminders re-derived after the sweep');

    Future<String?> assignee(String id) async =>
        (await (db.select(db.careSchedules)..where((r) => r.id.equals(id))).getSingle()).assigneeUserId;
    expect(await assignee(keep.id), 'u-alice');
    expect(await assignee(stale.id), isNull);
    expect(await assignee(none.id), isNull);
    expect(await assignee(deleted.id), 'u-gone', reason: 'tombstoned rows are left alone');
    expect(await assignee('other-tenant'), 'u-gone');

    final ops = await assigneeOps();
    expect(ops, hasLength(1));
    expect(ops.single.entityId, stale.id);
    expect(ops.single.valueJson, 'null');
    expect(ops.single.pushedAt, isNull);
    expect(ops.single.tenantId, 'tenant-local');

    // Idempotent: a second sweep with the same list is a no-op.
    expect(await schedules.clearAssigneesNotIn({'u-alice', 'u-me'}), 0);
    expect(await assigneeOps(), hasLength(1));
  });

  test('clearAssigneesFor clears exactly that user', () async {
    final p = await plants.create(nickname: 'B');
    final a = await schedules.upsert(plantId: p.id, type: 'water', baseIntervalDays: 7, assigneeUserId: 'u-gone');
    final b = await schedules.upsert(plantId: p.id, type: 'mist', baseIntervalDays: 2, assigneeUserId: 'u-gone');
    final c = await schedules.upsert(plantId: p.id, type: 'fertilize', baseIntervalDays: 30, assigneeUserId: 'u-alice');
    expect(await schedules.clearAssigneesFor('u-gone'), 2);
    expect(await schedules.clearAssigneesFor('u-gone'), 0);
    final rows = {for (final r in await db.select(db.careSchedules).get()) r.id: r.assigneeUserId};
    expect(rows[a.id], isNull);
    expect(rows[b.id], isNull);
    expect(rows[c.id], 'u-alice');
    expect(await assigneeOps(), hasLength(2));
  });
}
