import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_applier.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Audit P2: the HLC clock was created fresh (`_lastPhysical = 0`) on every
/// launch. After merging a peer op stamped ahead of our wall clock, a
/// restart + edit of the same field produced a LOWER HLC than the op we had
/// already seen → our later edit lost everywhere, permanently.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const wall = 1800000000000; // fixed "now"
  DateTime now() => DateTime.fromMillisecondsSinceEpoch(wall, isUtc: true);

  Future<void> insertOp(AppDatabase db, String hlc, {String tenant = 'col-1', String device = 'dev-b'}) =>
      db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: tenant, entity: 'plants', entityId: 'p1', field: 'notes', hlc: hlc, deviceId: device,
          pushedAt: const Value(1)));

  group('seedClockFromOpLog', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('restart after merging a peer op ahead of our wall clock: the next local op still outranks it', () async {
      // Session 1: the applier merges a peer op stamped 1 h ahead of us.
      final ahead = Hlc(wall + const Duration(hours: 1).inMilliseconds, 3, 'dev-b');
      final clock1 = HlcClock(deviceId: 'dev-a', nowProvider: now);
      final applier = SyncApplier(db: db, opLog: OpLogWriter(db: db, clock: clock1, tenantId: 'col-1'), clock: clock1);
      await applier.applyBatch([
        SyncOpDto(entity: 'plants', entityId: 'p1', field: 'notes', value: 'peer', hlc: ahead.encode(), deviceId: 'dev-b'),
      ]);

      // Session 2 (app restart): a fresh clock, unseeded, would lose.
      expect(HlcClock(deviceId: 'dev-a', nowProvider: now).now() < ahead, isTrue, reason: 'the bug');
      final clock2 = HlcClock(deviceId: 'dev-a', nowProvider: now);
      final seeded = await seedClockFromOpLog(db, clock2);
      expect(seeded, ahead);
      expect(clock2.now() > ahead, isTrue);
    });

    test('takes the max over every tenant (a link/unlink keeps the clock)', () async {
      await insertOp(db, Hlc(wall - 10, 0, 'dev-b').encode(), tenant: 'local');
      await insertOp(db, Hlc(wall + 5000, 7, 'dev-c').encode(), tenant: 'col-2');
      await insertOp(db, Hlc(wall + 4000, 0, 'dev-a').encode(), tenant: 'col-1', device: 'dev-a');
      final clock = HlcClock(deviceId: 'dev-a', nowProvider: now);
      await seedClockFromOpLog(db, clock);
      expect(clock.now() > Hlc(wall + 5000, 7, 'dev-c'), isTrue);
    });

    test('a forged far-future stamp is skipped; the newest sane one below it still seeds', () async {
      await insertOp(db, '20260927102954-00000-evil'); // year ~2612
      final sane = Hlc(wall + 1000, 0, 'dev-b');
      await insertOp(db, sane.encode());
      await insertOp(db, 'garbage');
      final clock = HlcClock(deviceId: 'dev-a', nowProvider: now);
      expect(await seedClockFromOpLog(db, clock), sane);
      final next = clock.now();
      expect(next > sane, isTrue);
      expect(next.physicalMs, lessThan(wall + const Duration(days: 1).inMilliseconds));
    });

    test('empty op log: clock untouched', () async {
      final clock = HlcClock(deviceId: 'dev-a', nowProvider: now);
      expect(await seedClockFromOpLog(db, clock), isNull);
      expect(clock.now().physicalMs, wall);
    });
  });

  test('hlcClockProvider hands out a clock already seeded from the op log (before any write)', () async {
    SharedPreferences.setMockInitialValues({'plantly_device_id': 'dev-a'});
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final ahead = Hlc(DateTime.now().toUtc().millisecondsSinceEpoch + const Duration(minutes: 30).inMilliseconds, 0, 'dev-b');
    await insertOp(db, ahead.encode());
    final container = ProviderContainer(overrides: [databaseProvider.overrideWithValue(db)]);
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final clock = await container.read(hlcClockProvider.future);
    expect(clock.now() > ahead, isTrue);
  });
}
