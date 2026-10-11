import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/features/calendar/calendar_screen.dart';
import 'package:plantly_inventory/features/home/widgets/grid_widget.dart' show homeDueLabel;
import 'package:plantly_inventory/features/plant_detail/plant_detail_screen.dart' show describeScheduleDue, lastCareStat;
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/shared/relative_days.dart';

/// "In N days" copy counts CALENDAR days, the same way on every screen
/// (web QA 2026-10-07: Calendar said "in 4 days" for Oct 12 on Oct 7 and
/// "in 6 days" where the plant page said "in 7 days"), and week arithmetic
/// survives DST weeks (Android QA: week title "Oct 25–30").
///
/// DST cases are meaningful when the suite runs in a zone with DST (this
/// box: Europe/Bucharest; `TZ=Europe/Bucharest flutter test` elsewhere) and
/// trivially true in UTC.
void main() {
  final en = AppLocalizationsEn();
  int ms(DateTime d) => d.toUtc().millisecondsSinceEpoch;

  group('calendarDaysBetween', () {
    test('ignores the time of day', () {
      expect(calendarDaysBetween(DateTime(2026, 10, 7, 10), DateTime(2026, 10, 12, 9)), 5);
      expect(calendarDaysBetween(DateTime(2026, 10, 7, 20), DateTime(2026, 10, 14, 8)), 7);
      expect(calendarDaysBetween(DateTime(2026, 10, 7, 23, 59), DateTime(2026, 10, 8, 0, 1)), 1);
      expect(calendarDaysBetween(DateTime(2026, 10, 7, 0, 1), DateTime(2026, 10, 7, 23, 59)), 0);
      expect(calendarDaysBetween(DateTime(2026, 10, 12, 9), DateTime(2026, 10, 7, 10)), -5);
    });

    test('DST weeks are 7 calendar days (169 h in autumn, 167 h in spring)', () {
      expect(calendarDaysBetween(DateTime(2026, 10, 24, 12), DateTime(2026, 10, 31, 12)), 7);
      expect(calendarDaysBetween(DateTime(2027, 3, 27, 12), DateTime(2027, 4, 3, 12)), 7);
      expect(calendarDaysUntilMs(ms(DateTime(2027, 4, 3, 12)), DateTime(2027, 3, 27, 12)), 7);
    });

    test('addCalendarDays stays on the date across DST', () {
      expect(addCalendarDays(DateTime(2026, 10, 25), 6), DateTime(2026, 10, 31));
      expect(addCalendarDays(DateTime(2027, 3, 30), -2), DateTime(2027, 3, 28));
    });
  });

  group('Calendar', () {
    test('"in N days" counts calendar days, not 24 h periods', () {
      expect(upcomingDueLabel(en, DateTime(2026, 10, 7, 10), DateTime(2026, 10, 12, 9)).$1, 'in 5 days');
      expect(upcomingDueLabel(en, DateTime(2026, 10, 7, 20), DateTime(2026, 10, 14, 8)).$1, 'in 7 days');
      expect(upcomingDueLabel(en, DateTime(2026, 10, 7, 22), DateTime(2026, 10, 8, 7)).$1, 'tomorrow');
      expect(upcomingDueLabel(en, DateTime(2027, 3, 27, 12), DateTime(2027, 4, 3, 12)).$1, 'in 7 days');
      expect(upcomingDueLabel(en, DateTime(2026, 10, 7, 9), DateTime(2026, 10, 7, 15)).$1, 'in 6 hours');
      expect(upcomingDueLabel(en, DateTime(2026, 10, 9, 8), DateTime(2026, 10, 7, 20)).$1, '2 days overdue');
    });

    test('week title in the DST week ends on the 7th day', () {
      // 2026-10-25 is the fall-back Sunday (EEST → EET).
      final (s1, e1) = weekRangeOf(DateTime(2026, 10, 27), DateTime.sunday);
      expect(s1, DateTime(2026, 10, 25));
      expect(e1, DateTime(2026, 10, 31));
      final (s2, e2) = weekRangeOf(DateTime(2026, 10, 28), DateTime.monday);
      expect((s2, e2), (DateTime(2026, 10, 26), DateTime(2026, 11, 1)));
      // Spring-forward week (2027-03-28).
      final (s3, e3) = weekRangeOf(DateTime(2027, 3, 30), DateTime.sunday);
      expect((s3, e3), (DateTime(2027, 3, 28), DateTime(2027, 4, 3)));
      final (s4, e4) = weekRangeOf(DateTime(2027, 3, 24), DateTime.monday);
      expect((s4, e4), (DateTime(2027, 3, 22), DateTime(2027, 3, 28)));
    });

    test('weekStartOf never slips to the previous date across spring-forward', () {
      expect(weekStartOf(DateTime(2027, 3, 30), DateTime.sunday), DateTime(2027, 3, 28));
      expect(weekStartOf(DateTime(2027, 4, 2), DateTime.monday), DateTime(2027, 3, 29));
    });

    test('stepping weeks across DST lands on the neighbouring week', () {
      expect(stepCalendarAnchor(DateTime(2027, 3, 30), CalendarView.week, -1), DateTime(2027, 3, 23));
      expect(stepCalendarAnchor(DateTime(2026, 10, 20), CalendarView.week, 1), DateTime(2026, 10, 27));
      expect(stepCalendarAnchor(DateTime(2026, 12, 15), CalendarView.month, 1), DateTime(2027, 1, 1));
      expect(stepCalendarAnchor(DateTime(2026, 1, 15), CalendarView.month, -1), DateTime(2025, 12, 1));
    });
  });

  group('Plant detail + Home agree with Calendar', () {
    final now = DateTime(2026, 10, 7, 10);
    test('same due date → same day count everywhere', () {
      for (final (due, days) in [
        (DateTime(2026, 10, 12, 9), 5),
        (DateTime(2026, 10, 14, 8), 7),
        (DateTime(2026, 10, 14, 23), 7),
        (DateTime(2026, 10, 9, 1), 2),
      ]) {
        expect(upcomingDueLabel(en, now, due).$1, 'in $days days');
        expect(describeScheduleDue(en, ms(due), now: now).$1, 'in $days days');
        expect(homeDueLabel(en, ms(due), now), 'in $days d');
      }
      final tomorrow = DateTime(2026, 10, 8, 6);
      expect(upcomingDueLabel(en, now, tomorrow).$1, 'tomorrow');
      expect(describeScheduleDue(en, ms(tomorrow), now: now).$1, 'tomorrow');
      expect(homeDueLabel(en, ms(tomorrow), now), en.homeDueTomorrow);
    });

    test('overdue by calendar days', () {
      final due = DateTime(2026, 10, 4, 22); // 2.5 days ago, 3 calendar days
      expect(describeScheduleDue(en, ms(due), now: now).$1, en.detailOverdueDays(3));
      expect(homeDueLabel(en, ms(due), now), en.homeDueLateDays(3));
      expect(upcomingDueLabel(en, now, due).$1, en.detailOverdueDays(3));
    });
  });

  group('Plant detail · last care stat', () {
    CareEventRow ev(String id, DateTime at) => CareEventRow(
          id: id,
          tenantId: 'local',
          plantId: 'p',
          type: 'water',
          doneAt: ms(at),
          updatedHlc: 'h',
          deviceId: 'd',
        );
    final now = DateTime(2026, 10, 7, 10);

    test('a future-dated event is not "last": the newest past one is, in calendar days', () {
      final events = [ev('future', DateTime(2026, 10, 23, 9)), ev('past', DateTime(2026, 10, 4, 20))];
      final stat = lastCareStat(events, now)!;
      expect(stat.event.id, 'past');
      expect(stat.days, 3);
      expect(stat.future, isFalse);
    });

    test('only future events → the nearest one, labelled as upcoming (never negative)', () {
      final events = [ev('far', DateTime(2026, 10, 30, 9)), ev('near', DateTime(2026, 10, 23, 9))];
      final stat = lastCareStat(events, now)!;
      expect(stat.event.id, 'near');
      expect(stat.days, 16);
      expect(stat.future, isTrue);
    });

    test('today and none', () {
      expect(lastCareStat([ev('t', DateTime(2026, 10, 7, 8))], now)!.days, 0);
      expect(lastCareStat(const [], now), isNull);
    });
  });
}
