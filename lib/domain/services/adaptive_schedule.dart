import 'dart:math';

/// Adaptive schedule algorithm (PLAN.md §Phase 1).
///
/// For each (plant, care_type) track the EWMA of actual interval (α=0.3)
/// and a rolling window of the last 5 events. Signal = snooze_ratio within
/// that window. The algorithm adjusts `current_interval_days` relative to
/// `base_interval_days` within [0.5× base, 2× base]:
///
/// - If snooze_ratio > 0.5 for 3 consecutive cycles → current *= 1.2
///   (i.e. the plant tolerates longer intervals than expected).
/// - If > 30% of completions are early (< 80% of current interval) across
///   the window → current *= 0.85 (plant wants shorter intervals).
/// - Otherwise leave current_interval unchanged.
///
/// The user can override by locking the schedule; that's handled above
/// this function by skipping the call entirely.
class AdaptiveSchedule {
  AdaptiveSchedule._();

  /// Alpha for the EWMA of actual intervals. Higher = react faster.
  static const double ewmaAlpha = 0.3;

  /// Window size for the snooze-ratio / early-completion signals.
  static const int windowSize = 5;

  /// Lower bound on the adaptive multiplier, relative to base_interval.
  static const double minMultiplier = 0.5;

  /// Upper bound on the adaptive multiplier, relative to base_interval.
  static const double maxMultiplier = 2.0;

  /// Multiplier applied when the "too-soon" signal fires.
  static const double earlyAdjustmentFactor = 0.85;

  /// Multiplier applied when the "too-often" signal fires.
  static const double snoozeAdjustmentFactor = 1.2;

  /// Compute the next `current_interval_days` based on the rolling window.
  ///
  /// [recentEvents] is newest-first: the most recent care event at index 0.
  /// [consecutiveHighSnoozeCycles] is the count of consecutive past cycles
  /// in which snooze_ratio > 0.5; the algorithm only stretches the interval
  /// once three such cycles have been observed.
  static AdaptiveDecision adjust({
    required double baseIntervalDays,
    required double currentIntervalDays,
    required List<CompletedCareEvent> recentEvents,
    required int consecutiveHighSnoozeCycles,
  }) {
    final minInterval = baseIntervalDays * minMultiplier;
    final maxInterval = baseIntervalDays * maxMultiplier;

    // Keep only the last windowSize events (or all, if fewer).
    final window = recentEvents.length > windowSize
        ? recentEvents.sublist(0, windowSize)
        : recentEvents;

    if (window.isEmpty) {
      // Not enough data — no change.
      return AdaptiveDecision(
        nextIntervalDays: currentIntervalDays,
        reason: AdjustmentReason.noData,
        snoozeRatio: 0,
        earlyRatio: 0,
        consecutiveHighSnoozeCycles: consecutiveHighSnoozeCycles,
      );
    }

    final snoozeCount = window.where((e) => e.snoozed).length;
    final snoozeRatio = snoozeCount / window.length;

    final earlyCount = window.where((e) {
      if (e.actualIntervalDays == null) return false;
      return e.actualIntervalDays! < currentIntervalDays * 0.8;
    }).length;
    final earlyRatio = earlyCount / window.length;

    // "Too often": more than 30% of recent completions were early →
    // shrink the current interval.
    if (earlyRatio > 0.3) {
      final next = max(
        minInterval,
        currentIntervalDays * earlyAdjustmentFactor,
      );
      return AdaptiveDecision(
        nextIntervalDays: next,
        reason: AdjustmentReason.tooOften,
        snoozeRatio: snoozeRatio,
        earlyRatio: earlyRatio,
        // The "too-often" signal resets the high-snooze streak since we're
        // moving in the opposite direction.
        consecutiveHighSnoozeCycles: 0,
      );
    }

    // "Too frequent" complaints": snooze_ratio > 0.5 this cycle.
    final highSnoozeCycles = snoozeRatio > 0.5
        ? consecutiveHighSnoozeCycles + 1
        : 0;

    if (highSnoozeCycles >= 3) {
      final next = min(
        maxInterval,
        currentIntervalDays * snoozeAdjustmentFactor,
      );
      return AdaptiveDecision(
        nextIntervalDays: next,
        reason: AdjustmentReason.tooFrequent,
        snoozeRatio: snoozeRatio,
        earlyRatio: earlyRatio,
        // Once we apply the adjustment the streak resets — the next three
        // cycles need to sustain the signal for another bump.
        consecutiveHighSnoozeCycles: 0,
      );
    }

    return AdaptiveDecision(
      nextIntervalDays: currentIntervalDays,
      reason: AdjustmentReason.none,
      snoozeRatio: snoozeRatio,
      earlyRatio: earlyRatio,
      consecutiveHighSnoozeCycles: highSnoozeCycles,
    );
  }

  /// Compute the EWMA of actual intervals for display / diagnostics.
  /// Returns null when the window doesn't contain any measured intervals.
  static double? ewma(List<CompletedCareEvent> recentEvents) {
    final intervals = recentEvents
        .map((e) => e.actualIntervalDays)
        .whereType<double>()
        .toList();
    if (intervals.isEmpty) return null;
    // Oldest → newest for a natural EWMA progression.
    final reversed = intervals.reversed.toList();
    double ewma = reversed.first;
    for (var i = 1; i < reversed.length; i++) {
      ewma = ewmaAlpha * reversed[i] + (1 - ewmaAlpha) * ewma;
    }
    return ewma;
  }
}

/// One slot in the rolling-window input to the scheduler.
class CompletedCareEvent {
  const CompletedCareEvent({
    required this.snoozed,
    required this.actualIntervalDays,
  });

  /// True if the user tapped "Snooze" on the reminder at least once before
  /// eventually completing the care event.
  final bool snoozed;

  /// The actual interval (days) between this event and the previous one of
  /// the same type. Null for the very first event.
  final double? actualIntervalDays;
}

enum AdjustmentReason { noData, none, tooOften, tooFrequent }

class AdaptiveDecision {
  const AdaptiveDecision({
    required this.nextIntervalDays,
    required this.reason,
    required this.snoozeRatio,
    required this.earlyRatio,
    required this.consecutiveHighSnoozeCycles,
  });

  final double nextIntervalDays;
  final AdjustmentReason reason;
  final double snoozeRatio;
  final double earlyRatio;

  /// Updated streak counter — stash this alongside the schedule row so the
  /// next call picks up where this one left off.
  final int consecutiveHighSnoozeCycles;
}
