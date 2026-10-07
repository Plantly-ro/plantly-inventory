// Adversarial review tests for the applier robustness change (unique-key
// conflicts, re-create after delete, mixed 1.1.0 fleet).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';

String hlcAt(int ms, {String dev = 'dev-b'}) => Hlc(ms, 0, dev).encode();

SyncOpDto op(String entity, String id, String field, Object? value, String hlc) =>
    SyncOpDto(entity: entity, entityId: id, field: field, value: value, hlc: hlc);

Map<String, dynamic> scheduleJson(String id, {int days = 7, String dev = 'dev-b'}) => {
      'id': id, 'plant_id': 'p1', 'type': 'water', 'base_interval_days': days, 'current_interval_days': days,
      'enabled': true, 'recurrence_mode': 'fixed', 'device_id': dev,
    };

Map<String, dynamic> plantJson(String id, {String? nickname = 'Remote', int pot = 10}) => {
      'id': id, 'nickname': nickname, 'species_id': null, 'location_id': null, 'pin_x': null, 'pin_y': null,
      'notifications_muted': false, 'status': 'active', 'acquired_at': '2023-11-14T22:13:20.000Z', 'source': null,
      'notes': null, 'pot_size_cm': pot, 'deleted_at': null, 'device_id': 'dev-b',
    };

class Device {
  Device(this.deviceId, {bool readOnly = false}) {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    clock = HlcClock(deviceId: deviceId, nowProvider: () => DateTime.fromMillisecondsSinceEpoch(_wall++, isUtc: true));
    opLog = OpLogWriter(db: db, clock: clock, tenantId: 'col-1');
    applier = SyncApplier(db: db, opLog: opLog, clock: clock, readOnly: readOnly, nowMillis: () => 99);
  }
  final String deviceId;
  int _wall = 1000;
  late final AppDatabase db;
  late final HlcClock clock;
  late final OpLogWriter opLog;
  late final SyncApplier applier;

  Future<List<String>> liveSchedules() async => [
        for (final s in await db.select(db.careSchedules).get())
          if (s.deletedAt == null) '${s.id}/${s.baseIntervalDays}',
      ]..sort();

  Future<int> localOpCount() async =>
      (await db.select(db.syncOps).get()).where((o) => o.deviceId == deviceId).length;

  Future<List<String>> localOps() async => [
        for (final o in await db.select(db.syncOps).get())
          if (o.deviceId == deviceId) '${o.entityId}.${o.field}',
      ];
}

List<List<int>> permutations(List<int> xs) {
  if (xs.length <= 1) return [xs];
  return [
    for (var i = 0; i < xs.length; i++)
      for (final rest in permutations([...xs]..removeAt(i))) [xs[i], ...rest],
  ];
}

void main() {
  group('(3) delete + re-create under a new id converges in every arrival order', () {
    // Old row A: create, edit, tombstone. New row C re-created later under
    // the same (plant, type) key, then edited.
    final ops = [
      op('care_schedules', 'cs-a', '*', scheduleJson('cs-a', days: 7), hlcAt(1000, dev: 'dev-x')),
      op('care_schedules', 'cs-a', 'base_interval_days', 8, hlcAt(1500, dev: 'dev-y')),
      op('care_schedules', 'cs-a', '__tombstone__', null, hlcAt(2000, dev: 'dev-x')),
      op('care_schedules', 'cs-c', '*', scheduleJson('cs-c', days: 3), hlcAt(3000, dev: 'dev-x')),
      op('care_schedules', 'cs-c', 'base_interval_days', 4, hlcAt(3500, dev: 'dev-y')),
    ];
    // Decision A (1.1.0-compatible rule): a writer that sees cs-a's `*` while
    // cs-c is live (or cs-c beat a live cs-a) pushes a tombstone for cs-a —
    // which is dead anyway. A viewer records nothing.
    test('all 120 orders: only the new row is live, with its latest edit; at most a redundant cs-a tombstone', () async {
      for (final order in permutations([0, 1, 2, 3, 4])) {
        for (final readOnly in [false, true]) {
          final d = Device('dev-r', readOnly: readOnly);
          try {
            for (final i in order) {
              await d.applier.applyBatch([ops[i]]);
            }
            expect(await d.liveSchedules(), ['cs-c/4.0'], reason: 'order $order readOnly $readOnly');
            final local = await d.localOps();
            if (readOnly) {
              expect(local, isEmpty, reason: 'order $order');
            } else {
              expect(local.every((o) => o == 'cs-a.__tombstone__'), isTrue, reason: 'order $order: $local');
            }
          } finally {
            await d.db.close();
          }
        }
      }
    });

    test('same, but the whole history in one batch (fresh device pulling from 0)', () async {
      for (final order in permutations([0, 1, 2, 3, 4])) {
        final d = Device('dev-r');
        try {
          await d.applier.applyBatch([for (final i in order) ops[i]]);
          expect(await d.liveSchedules(), ['cs-c/4.0'], reason: 'order $order');
        } finally {
          await d.db.close();
        }
      }
    });
  });

  group('(4) live/live conflict: every arrival order picks the later create', () {
    final ops = [
      op('care_schedules', 'cs-1', '*', scheduleJson('cs-1', days: 1), hlcAt(1000, dev: 'dev-x')),
      op('care_schedules', 'cs-1', 'base_interval_days', 11, hlcAt(5000, dev: 'dev-x')), // edit AFTER cs-2 exists
      op('care_schedules', 'cs-2', '*', scheduleJson('cs-2', days: 2), hlcAt(2000, dev: 'dev-y')),
      op('care_schedules', 'cs-2', 'base_interval_days', 22, hlcAt(2500, dev: 'dev-y')),
    ];
    test('all 24 orders converge on cs-2', skip: 'DECISION A: the 1.1.0 rule (incoming op HLC vs holder updated_hlc) is kept '
        'for mixed-fleet convergence; per-device local results depend on order until the tombstone ops propagate.', () async {
      for (final order in permutations([0, 1, 2, 3])) {
        final d = Device('dev-r');
        try {
          for (final i in order) {
            await d.applier.applyBatch([ops[i]]);
          }
          expect(await d.liveSchedules(), ['cs-2/22.0'], reason: 'order $order');
        } finally {
          await d.db.close();
        }
      }
    });
  });

  group('(1) a `*` op with a dropped (invalid) column still outranks that column in LWW', () {
    // p1 exists (nickname A). A valid rename to B @5000 and a `*` re-send
    // @10000 whose nickname is null (invalid → dropped, pot_size 20 applies).
    final ops = [
      op('plants', 'p1', '*', plantJson('p1', nickname: 'A'), hlcAt(1000)),
      op('plants', 'p1', 'nickname', 'B', hlcAt(5000, dev: 'dev-y')),
      op('plants', 'p1', '*', plantJson('p1', nickname: null, pot: 20), hlcAt(10000, dev: 'dev-z')),
    ];
    Future<String?> nick(List<int> order) async {
      final d = Device('dev-r');
      try {
        for (final i in order) {
          await d.applier.applyBatch([ops[i]]);
        }
        return (await (d.db.select(d.db.plants)..where((p) => p.id.equals('p1'))).getSingle()).nickname;
      } finally {
        await d.db.close();
      }
    }

    test('arrival order must not change the nickname', () async {
      expect(await nick([0, 1, 2]), await nick([0, 2, 1]));
    });
  });

  group('mixed fleet with 1.1.0 clients (old rule: incoming op HLC vs holder updated_hlc, loser TOMBSTONED via op)', () {
    // dev-o runs 1.1.0. It created cs-a @1000 and edited it @3000 (a care
    // event bumps updated_hlc). dev-n (new) created cs-b @2000 offline.
    // On dev-o, cs-b arrives: 2000 < updated_hlc 3000 → old rule keeps cs-a
    // and pushes a TOMBSTONE for cs-b @3500. Old client's final state: cs-a.
    final ops = [
      op('care_schedules', 'cs-a', '*', scheduleJson('cs-a', days: 1, dev: 'dev-o'), hlcAt(1000, dev: 'dev-o')),
      op('care_schedules', 'cs-a', 'base_interval_days', 9, hlcAt(3000, dev: 'dev-o')),
      op('care_schedules', 'cs-b', '*', scheduleJson('cs-b', days: 2, dev: 'dev-n'), hlcAt(2000, dev: 'dev-n')),
      op('care_schedules', 'cs-b', '__tombstone__', null, hlcAt(3500, dev: 'dev-o')),
    ];
    test('a new client converges with the 1.1.0 client (cs-a live), in server order', () async {
      final d = Device('dev-r');
      try {
        await d.applier.applyBatch(ops);
        // Actual today: [] — cs-a purged as the "earlier create", then cs-b
        // killed by the 1.1.0 tombstone. The reminder is gone on every new
        // client while 1.1.0 still shows cs-a.
        expect(await d.liveSchedules(), ['cs-a/9.0']);
      } finally {
        await d.db.close();
      }
    });
  });
}
