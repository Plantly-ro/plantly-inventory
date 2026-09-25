import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/domain/services/ical_export.dart';

DateTime _utc(int y, int mo, int d, [int h = 0, int m = 0, int s = 0]) =>
    DateTime.utc(y, mo, d, h, m, s);

void main() {
  group('ICalExport.fromEvents', () {
    test('folds long lines without splitting multi-byte UTF-8 (ro diacritics)', () {
      // 'ș' is 2 bytes; 40 of them = 80 octets, so the 75-octet fold lands
      // mid-character unless the folder backs off to a boundary.
      final summary = 'Udă — ${'ș' * 40}';
      final ics = ICalExport.fromEvents(
        productId: 'plantly.inventory',
        events: [
          ICalEvent(
            uid: 'evt-2@plantly.inventory',
            summary: summary,
            start: _utc(2026, 4, 18, 9),
            end: _utc(2026, 4, 18, 9, 15),
          ),
        ],
        nowProvider: () => _utc(2026, 4, 18, 9),
      );
      // Unfold (CRLF + single space) and the original text must survive intact.
      expect(ics.replaceAll('\r\n ', ''), contains('SUMMARY:$summary\r\n'));
      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75), reason: line);
      }
    });

    test('wraps a single event in a valid VCALENDAR', () {
      final ics = ICalExport.fromEvents(
        productId: 'plantly.inventory',
        events: [
          ICalEvent(
            uid: 'evt-1@plantly.inventory',
            summary: 'Water — Monstera',
            start: _utc(2026, 4, 18, 9),
            end: _utc(2026, 4, 18, 9, 15),
          ),
        ],
        nowProvider: () => _utc(2026, 4, 18, 9),
      );

      expect(ics, contains('BEGIN:VCALENDAR\r\n'));
      expect(ics, contains('END:VCALENDAR\r\n'));
      expect(ics, contains('VERSION:2.0\r\n'));
      expect(ics, contains('PRODID:-//plantly.inventory//EN\r\n'));
      expect(ics, contains('BEGIN:VEVENT\r\n'));
      expect(ics, contains('UID:evt-1@plantly.inventory\r\n'));
      expect(ics, contains('DTSTART:20260418T090000Z\r\n'));
      expect(ics, contains('DTEND:20260418T091500Z\r\n'));
      expect(ics, contains('SUMMARY:Water — Monstera\r\n'));
      expect(ics, contains('END:VEVENT\r\n'));
    });

    test('escapes , ; \\ and newlines in TEXT fields', () {
      final ics = ICalExport.fromEvents(
        productId: 'x',
        events: [
          ICalEvent(
            uid: 'e',
            summary: r'Tricky ; commas, and \ backslashes',
            start: _utc(2026, 4, 18, 9),
            description: 'line 1\nline 2',
          ),
        ],
        nowProvider: () => _utc(2026, 4, 18, 9),
      );
      expect(ics, contains(r'Tricky \; commas\, and \\ backslashes'));
      expect(ics, contains(r'DESCRIPTION:line 1\nline 2'));
    });

    test('folds long lines at 75 octets with leading space continuation', () {
      final longText = 'x' * 200;
      final ics = ICalExport.fromEvents(
        productId: 'x',
        events: [
          ICalEvent(
            uid: 'e',
            summary: longText,
            start: _utc(2026, 4, 18, 9),
          ),
        ],
        nowProvider: () => _utc(2026, 4, 18, 9),
      );
      // Line folding inserts "\r\n " after every 75-octet chunk.
      expect(ics, contains('\r\n x'));
    });

    test('times are emitted in UTC regardless of input zone', () {
      // A local-time DateTime on a device in UTC+3 would be 09:00 local →
      // 06:00 UTC. We feed a DateTime.utc to make the expectation
      // explicit; the serializer must never regress to local time.
      final ics = ICalExport.fromEvents(
        productId: 'x',
        events: [
          ICalEvent(
            uid: 'e',
            summary: 'S',
            start: DateTime.utc(2026, 4, 18, 6),
          ),
        ],
        nowProvider: () => _utc(2026, 4, 18, 6),
      );
      expect(ics, contains('DTSTART:20260418T060000Z\r\n'));
    });
  });
}
