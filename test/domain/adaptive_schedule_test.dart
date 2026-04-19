import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/domain/services/adaptive_schedule.dart';

CompletedCareEvent onTime(double interval) =>
    CompletedCareEvent(snoozed: false, actualIntervalDays: interval);
CompletedCareEvent snoozedAt(double interval) =>
    CompletedCareEvent(snoozed: true, actualIntervalDays: interval);
CompletedCareEvent early(double interval) =>
    CompletedCareEvent(snoozed: false, actualIntervalDays: interval);

void main() {
  group('AdaptiveSchedule.adjust — baseline', () {
    test('no events → no change', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: const [],
        consecutiveHighSnoozeCycles: 0,
      );
      expect(d.nextIntervalDays, 7);
      expect(d.reason, AdjustmentReason.noData);
      expect(d.consecutiveHighSnoozeCycles, 0);
    });

    test('on-time events → no change', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: [onTime(7), onTime(7), onTime(7.2), onTime(6.9), onTime(7.1)],
        consecutiveHighSnoozeCycles: 0,
      );
      expect(d.nextIntervalDays, 7);
      expect(d.reason, AdjustmentReason.none);
    });
  });

  group('AdaptiveSchedule.adjust — too-often (shrink)', () {
    test('>30% early completions → shrink by 0.85', () {
      // Early = actual < 0.8 * current (< 5.6 when current=7)
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: [early(4), early(4.5), onTime(7), onTime(7), onTime(7)],
        consecutiveHighSnoozeCycles: 0,
      );
      expect(d.reason, AdjustmentReason.tooOften);
      expect(d.nextIntervalDays, closeTo(7 * 0.85, 1e-9));
    });

    test('shrink is clamped at 0.5× base', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 10,
        currentIntervalDays: 5.5, // already near the floor
        recentEvents: [early(2), early(2), early(2), early(2), early(2)],
        consecutiveHighSnoozeCycles: 0,
      );
      expect(d.reason, AdjustmentReason.tooOften);
      expect(d.nextIntervalDays, closeTo(5.0, 1e-9));
    });

    test('too-often resets the high-snooze streak', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: [early(3), early(3), early(3), snoozedAt(8), snoozedAt(8)],
        consecutiveHighSnoozeCycles: 2,
      );
      expect(d.reason, AdjustmentReason.tooOften);
      expect(d.consecutiveHighSnoozeCycles, 0);
    });
  });

  group('AdaptiveSchedule.adjust — too-frequent (stretch)', () {
    test('snooze_ratio > 0.5 once increments the streak but does not adjust', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: [snoozedAt(9), snoozedAt(9), snoozedAt(9), onTime(7), onTime(7)],
        consecutiveHighSnoozeCycles: 0,
      );
      expect(d.reason, AdjustmentReason.none);
      expect(d.consecutiveHighSnoozeCycles, 1);
      expect(d.nextIntervalDays, 7);
    });

    test('streak of 3 cycles → stretch by 1.2 then reset', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: [snoozedAt(9), snoozedAt(9), snoozedAt(9), onTime(7), onTime(7)],
        consecutiveHighSnoozeCycles: 2,
      );
      expect(d.reason, AdjustmentReason.tooFrequent);
      expect(d.nextIntervalDays, closeTo(7 * 1.2, 1e-9));
      expect(d.consecutiveHighSnoozeCycles, 0);
    });

    test('stretch is clamped at 2× base', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 13.5,
        recentEvents: [snoozedAt(15), snoozedAt(15), snoozedAt(15), snoozedAt(15), onTime(14)],
        consecutiveHighSnoozeCycles: 2,
      );
      expect(d.reason, AdjustmentReason.tooFrequent);
      expect(d.nextIntervalDays, closeTo(14.0, 1e-9));
    });

    test('single non-snooze cycle breaks the streak', () {
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: [onTime(7), onTime(7), onTime(7), onTime(7), onTime(7)],
        consecutiveHighSnoozeCycles: 2,
      );
      expect(d.reason, AdjustmentReason.none);
      expect(d.consecutiveHighSnoozeCycles, 0);
    });
  });

  group('AdaptiveSchedule.adjust — window', () {
    test('only the last 5 events count toward the signals', () {
      // A long history with many old snoozes but clean last-5 → no adjustment.
      final d = AdaptiveSchedule.adjust(
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        recentEvents: [
          onTime(7), onTime(7), onTime(7), onTime(7), onTime(7),
          snoozedAt(9), snoozedAt(9), snoozedAt(9), snoozedAt(9), snoozedAt(9),
        ],
        consecutiveHighSnoozeCycles: 2,
      );
      expect(d.reason, AdjustmentReason.none);
      expect(d.snoozeRatio, 0);
    });
  });

  group('AdaptiveSchedule.ewma', () {
    test('null when no measured intervals', () {
      expect(AdaptiveSchedule.ewma(const []), isNull);
    });

    test('single interval returns that interval', () {
      expect(AdaptiveSchedule.ewma([onTime(7)]), 7);
    });

    test('weighs newest observation with α', () {
      // Oldest-to-newest: 10, 10, 5. α=0.3.
      //   ewma_1 = 10
      //   ewma_2 = 0.3*10 + 0.7*10 = 10
      //   ewma_3 = 0.3*5  + 0.7*10 = 8.5
      expect(AdaptiveSchedule.ewma([onTime(5), onTime(10), onTime(10)]), closeTo(8.5, 1e-9));
    });
  });
}
