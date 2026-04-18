import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/sync/hlc.dart';

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
}
