import 'package:timezone/timezone.dart' as tz;

/// Reminder date arithmetic in the user's local calendar.
///
/// `next_due_at` is stored as UTC millis, but a "water every 3 days at 09:00"
/// reminder means 09:00 on the wall clock: adding `n * 86 400 000` ms drifts
/// an hour whenever a DST change falls inside the interval (Europe/Bucharest
/// 09:00 EEST + 1 day across the October fall-back is 08:00 EET).
///
/// Rule: an interval of `d` days advances by `floor(d)` calendar days in the
/// local zone, keeping the wall-clock time of day, then by the fractional
/// remainder as plain elapsed time (`0.5` day = 12 h). Whole-day intervals —
/// everything a user can set — therefore keep their time of day; adaptive
/// fractional intervals (`AdaptiveSchedule` scales by 0.85 / 1.2) keep the
/// same length they always had, just DST-corrected for the whole-day part.
///
/// A wall-clock time that does not exist on the target day (inside a
/// spring-forward gap) is normalised forward by the zone rules; an ambiguous
/// one (repeated hour on fall-back) resolves to one of its two instants.
///
/// [location] null (production) = the platform's local zone through
/// `DateTime` — the device zone on Android/iOS, the browser's on web; no
/// timezone database needed. Tests pass an explicit `tz.Location`.
class LocalCalendar {
  const LocalCalendar({this.location});

  final tz.Location? location;

  /// [utcMs] advanced by [days] (≥ 0) per the class rule.
  int addDays(int utcMs, double days) {
    // Round the total first: 123/30*30 = 122.99999999999999 must be 123
    // calendar days, not 122 days + ~24h of elapsed time.
    final total = (days * Duration.millisecondsPerDay).round();
    final whole = total ~/ Duration.millisecondsPerDay;
    final fracMs = total - whole * Duration.millisecondsPerDay;
    return _addCalendarDays(utcMs, whole) + fracMs;
  }

  /// [utcMs] advanced by [by]: its whole days on the calendar, the rest as
  /// elapsed time (snooze "1 day" lands at the same wall-clock time).
  int addDuration(int utcMs, Duration by) {
    final whole = by.inDays;
    final restMs = (by - Duration(days: whole)).inMilliseconds;
    return _addCalendarDays(utcMs, whole) + restMs;
  }

  int _addCalendarDays(int utcMs, int days) {
    if (days == 0) return utcMs;
    final loc = location;
    if (loc != null) {
      final t = tz.TZDateTime.fromMillisecondsSinceEpoch(loc, utcMs);
      return tz.TZDateTime(loc, t.year, t.month, t.day + days, t.hour, t.minute, t.second, t.millisecond)
          .millisecondsSinceEpoch;
    }
    final t = DateTime.fromMillisecondsSinceEpoch(utcMs);
    return DateTime(t.year, t.month, t.day + days, t.hour, t.minute, t.second, t.millisecond)
        .millisecondsSinceEpoch;
  }
}
