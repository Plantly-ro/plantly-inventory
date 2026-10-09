/// Calendar-day arithmetic for relative date copy ("tomorrow", "in 5 days",
/// "3 days overdue", "2d ago"). Every screen that turns a due date or an
/// event date into a day count goes through here, so Calendar, Plant
/// detail and Home agree — and none of them counts 24-hour periods:
/// "in 5 days" for Oct 12 means the date is five calendar days after today
/// (whatever the time of day, and across DST weeks, which are 167 h / 169 h
/// long).
library;

/// Calendar days from [from]'s local date to [to]'s local date: positive
/// when [to] is on a later day, 0 on the same day, negative when earlier.
/// Times of day are ignored; DST-safe (the dates are compared in UTC).
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = from.toLocal();
  final b = to.toLocal();
  return DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
}

/// Calendar days from [now] until the instant [utcMs] (ms since epoch):
/// 0 = today, 1 = tomorrow, -1 = yesterday.
int calendarDaysUntilMs(int utcMs, DateTime now) =>
    calendarDaysBetween(now, DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true));

/// Local midnight [days] calendar days after [d]'s date — `DateTime(y, m,
/// d + n)`, never `add(Duration(days: n))`, which lands an hour off the
/// date in a DST week.
DateTime addCalendarDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);
