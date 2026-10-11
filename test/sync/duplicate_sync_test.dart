import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/data/repositories/tag_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

class _Device {
  _Device(String id) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = HlcClock(deviceId: id);
    opLog = OpLogWriter(db: db, clock: clock, tenantId: 'col-1');
    applier = SyncApplier(db: db, opLog: opLog, clock: clock);
    plants = PlantRepository(db: db, opLog: opLog);
    schedules = CareScheduleRepository(db: db, opLog: opLog);
    tags = TagRepository(db: db, opLog: opLog);
    plantTags = PlantTagRepository(db: db, opLog: opLog);
  }

  late final AppDatabase db;
  late final HlcClock clock;
  late final OpLogWriter opLog;
  late final SyncApplier applier;
  late final PlantRepository plants;
  late final CareScheduleRepository schedules;
  late final TagRepository tags;
  late final PlantTagRepository plantTags;

  Future<List<SyncOpDto>> push() async {
    final rows = await (db.select(db.syncOps)
          ..where((o) => o.pushedAt.isNull())
          ..orderBy([(o) => OrderingTerm(expression: o.seq)]))
        .get();
    await (db.update(db.syncOps)..where((o) => o.pushedAt.isNull())).write(const SyncOpsCompanion(pushedAt: Value(1)));
    return [for (final r in rows) SyncOpDto.fromRow(r)];
  }

  Future<CareScheduleRow> scheduleOf(String plantId) =>
      (db.select(db.careSchedules)..where((s) => s.plantId.equals(plantId))).getSingle();
}

void main() {
  late _Device a;
  late _Device b;
  setUp(() {
    a = _Device('dev-a');
    b = _Device('dev-b');
  });
  tearDown(() async {
    await a.db.close();
    await b.db.close();
  });

  Future<void> sync(_Device from, _Device to) async => to.applier.applyBatch(await from.push());

  test('a duplicated plant reaches peers with the same schedules and tags', () async {
    final source = await a.plants.create(nickname: 'Monstera');
    await a.schedules.upsert(plantId: source.id, type: 'water', baseIntervalDays: 4, recurrenceMode: 'fixed');
    final tag = await a.tags.ensure('Kitchen');
    await a.plantTags.attach(source.id, tag.id);
    await sync(a, b);

    final child = await a.plants.duplicate(source.id);
    await sync(a, b);

    final peerChild = await (b.db.select(b.db.plants)..where((p) => p.id.equals(child.id))).getSingle();
    expect(peerChild.nickname, child.nickname);
    expect(peerChild.updatedHlc, child.updatedHlc);

    final mine = await a.scheduleOf(child.id);
    final theirs = await b.scheduleOf(child.id);
    expect(mine.nextDueAt, isNotNull);
    for (final s in [mine, theirs]) {
      expect(s.id, mine.id);
      expect(s.nextDueAt, mine.nextDueAt);
      expect(s.baseIntervalDays, 4);
      expect(s.currentIntervalDays, 4);
      expect(s.recurrenceMode, 'fixed');
      expect(s.enabled, isTrue);
      expect(s.recentEventsJson, '[]');
      expect(s.snoozeCount, 0);
      expect(s.updatedHlc, mine.updatedHlc);
    }

    final aTags = await (a.db.select(a.db.plantTags)..where((r) => r.plantId.equals(child.id))).get();
    final bTags = await (b.db.select(b.db.plantTags)..where((r) => r.plantId.equals(child.id))).get();
    expect(aTags, hasLength(1));
    expect(aTags.single.id, isNot(contains('/')), reason: 'row ids are ULIDs like every other attach');
    expect(bTags.map((r) => (r.id, r.tagId, r.addedHlc, r.removedHlc)),
        [(aTags.single.id, tag.id, aTags.single.addedHlc, null)]);

    // Detaching the copied tag on B converges on A.
    await b.plantTags.detach(child.id, tag.id);
    await sync(b, a);
    expect(await a.plantTags.watchAttached(child.id).first, isEmpty);
    expect(await a.plantTags.watchAttached(source.id).first, [tag.id]);
  });
}
