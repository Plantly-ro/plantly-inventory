import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

void main() {
  group('Hlc wire format', () {
    test('encode → parse is lossless', () {
      final h = Hlc(1776511234567, 42, 'device-abc');
      expect(Hlc.parse(h.encode()), equals(h));
    });

    test('lexicographic order matches temporal order', () {
      final early = Hlc(1000, 0, 'zzz');
      final lateLogical = Hlc(1000, 1, 'aaa');
      final latePhysical = Hlc(1001, 0, 'aaa');
      final encoded = [early, lateLogical, latePhysical].map((h) => h.encode()).toList()..sort();
      expect(encoded, [early.encode(), lateLogical.encode(), latePhysical.encode()]);
    });

    test('device id breaks ties after physical + logical', () {
      final a = Hlc(1000, 0, 'aaa');
      final b = Hlc(1000, 0, 'bbb');
      expect(a < b, isTrue);
    });
  });

  group('HlcClock.now', () {
    test('strictly monotonic across rapid calls', () {
      final clock = HlcClock(deviceId: 'dev', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(1000));
      final a = clock.now();
      final b = clock.now();
      final c = clock.now();
      expect(b > a, isTrue);
      expect(c > b, isTrue);
    });

    test('resets logical counter when physical advances', () {
      int now = 1000;
      final clock = HlcClock(deviceId: 'dev', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(now));
      final first = clock.now();
      now = 2000;
      final second = clock.now();
      expect(second.physicalMs, 2000);
      expect(second.logical, 0);
      expect(second > first, isTrue);
    });
  });

  group('HlcClock.merge', () {
    test('next now is strictly greater than a remote hlc from the future', () {
      final clock = HlcClock(deviceId: 'dev', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(1000));
      final remote = Hlc(5000, 3, 'remote');
      clock.merge(remote);
      final local = clock.now();
      expect(local > remote, isTrue);
      expect(local.physicalMs, greaterThanOrEqualTo(remote.physicalMs));
    });

    test('remote from the past does not rewind the clock', () {
      int now = 5000;
      final clock = HlcClock(deviceId: 'dev', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(now));
      final first = clock.now(); // physical=5000, logical=0
      clock.merge(Hlc(1000, 99, 'remote'));
      final second = clock.now();
      expect(second > first, isTrue);
      expect(second.physicalMs, greaterThanOrEqualTo(first.physicalMs));
    });
  });

  group('HlcClock.merge drift guard', () {
    test('a remote further than maxRemoteDrift ahead is ignored, logged, and leaves now() on local time', () {
      final logs = <String>[];
      final clock = HlcClock(deviceId: 'dev', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(1000), log: logs.add);
      // "2026-09-27 10:29:54" written as a 14-digit number and read as unix ms = year ~2612.
      final farFuture = Hlc(20260927102954, 1, 'qadev');
      expect(clock.merge(farFuture), isFalse);
      expect(clock.ignoredRemoteCount, 1);
      expect(logs.single, contains('ignoring remote HLC 20260927102954-00001-qadev'));
      final local = clock.now();
      expect(local.physicalMs, 1000);
      expect(local.logical, 0);
    });

    test('a remote inside the window still merges and now() is strictly greater', () {
      final clock = HlcClock(deviceId: 'dev', nowProvider: () => DateTime.fromMillisecondsSinceEpoch(1000));
      final ahead = Hlc(1000 + const Duration(hours: 23).inMilliseconds, 5, 'peer');
      expect(clock.merge(ahead), isTrue);
      expect(clock.ignoredRemoteCount, 0);
      expect(clock.now() > ahead, isTrue);
    });

    test('boundary: exactly maxRemoteDrift ahead merges, one ms more does not', () {
      const drift = Duration(minutes: 5);
      final clock = HlcClock(
        deviceId: 'dev',
        nowProvider: () => DateTime.fromMillisecondsSinceEpoch(1000),
        maxRemoteDrift: drift,
        log: (_) {},
      );
      expect(clock.merge(Hlc(1000 + drift.inMilliseconds, 0, 'peer')), isTrue);
      expect(clock.merge(Hlc(1000 + drift.inMilliseconds + 1, 0, 'peer')), isFalse);
    });
  });

  group('lanes (several browser tabs sharing one device id)', () {
    tearDown(() => HlcClock.defaultLane = null);

    test('two tabs, same device, same millisecond: stamps never collide and stay monotonic per tab', () {
      final t = DateTime.utc(2026, 10, 7, 12);
      final a = HlcClock(deviceId: 'dev', nowProvider: () => t, lane: 0);
      final b = HlcClock(deviceId: 'dev', nowProvider: () => t, lane: 1);
      final seen = <String>{};
      Hlc? lastA, lastB;
      for (var i = 0; i < 500; i++) {
        final ha = a.now();
        final hb = b.now();
        expect(seen.add(ha.encode()), isTrue);
        expect(seen.add(hb.encode()), isTrue);
        if (lastA != null) expect(ha > lastA, isTrue);
        if (lastB != null) expect(hb > lastB, isTrue);
        expect(ha.logical % HlcClock.laneCount, 0);
        expect(hb.logical % HlcClock.laneCount, 1);
        lastA = ha;
        lastB = hb;
      }
      // Wire format unchanged: 5-digit logical, device id as is.
      expect(lastA!.encode(), matches(RegExp(r'^\d{14}-\d{5}-dev$')));
    });

    test('merge keeps the lane and the "strictly after remote" guarantee', () {
      final t = DateTime.utc(2026, 10, 7, 12);
      final c = HlcClock(deviceId: 'dev', nowProvider: () => t, lane: 7);
      final remote = Hlc(t.millisecondsSinceEpoch, 42, 'other');
      c.merge(remote);
      final h = c.now();
      expect(h > remote, isTrue);
      expect(h.logical % HlcClock.laneCount, 7);
    });

    test('logical overflow inside a lane moves to the next millisecond, never a 6th digit', () {
      final t = DateTime.utc(2026, 10, 7, 12);
      final c = HlcClock(deviceId: 'dev', nowProvider: () => t, lane: 99);
      Hlc last = c.now();
      for (var i = 0; i < 1200; i++) {
        final h = c.now();
        expect(h > last, isTrue);
        expect(h.logical, lessThanOrEqualTo(99999));
        expect(h.logical % HlcClock.laneCount, 99);
        last = h;
      }
      expect(last.physicalMs, greaterThan(t.millisecondsSinceEpoch));
    });

    test('defaultLane applies to clocks built without one; no lane = the original step-by-1 clock', () {
      final t = DateTime.utc(2026, 10, 7, 12);
      final plain = HlcClock(deviceId: 'dev', nowProvider: () => t);
      plain.now();
      expect(plain.now().logical, 1);
      HlcClock.defaultLane = 3;
      final tab = HlcClock(deviceId: 'dev', nowProvider: () => t);
      expect(tab.lane, 3);
      expect(tab.now().logical, 3);
      expect(tab.now().logical, 103);
      expect(() => HlcClock(deviceId: 'dev', lane: 100), throwsArgumentError);
    });
  });

  test('boot seeding from sync_ops (applier) composes with lanes: seeded through merge(), stays in the lane', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final t = DateTime.now().toUtc();
    final stored = Hlc(t.millisecondsSinceEpoch + 5000, 42, 'other-tab');
    await db.customStatement(
        "INSERT INTO sync_ops (tenant_id, entity, entity_id, field, hlc, device_id, value_json, pushed_at) "
        "VALUES ('local', 'plants', 'p1', 'nickname', '${stored.encode()}', 'dev', '\"x\"', NULL)");
    final clock = HlcClock(deviceId: 'dev', lane: 7);
    expect(await seedClockFromOpLog(db, clock), stored);
    final next = clock.now();
    expect(next > stored, isTrue);
    expect(next.logical % HlcClock.laneCount, 7);
  });
}
