/// iCalendar (RFC 5545) generation for the calendar-subscription feature
/// (PLAN.md §Phase 1 "iCal export"). Pure function — no I/O, no native
/// dependencies — so the unit tests run without a Flutter toolchain.
///
/// Each reminder becomes a `VEVENT` with UID derived from the schedule id
/// so iCal clients dedupe on refresh. Times are emitted as UTC (`Z`
/// suffix) so DST transitions don't silently shift reminders.
library;

import 'dart:convert';

const _lineBreak = '\r\n'; // RFC 5545 requires CRLF

class ICalEvent {
  const ICalEvent({
    required this.uid,
    required this.summary,
    required this.start,
    this.end,
    this.description,
    this.location,
  });

  /// Globally unique event id. Conventional form: `<ulid>@plantly.inventory`.
  final String uid;
  final String summary;
  final DateTime start;
  final DateTime? end;
  final String? description;
  final String? location;
}

class ICalExport {
  ICalExport._();

  /// Serialize a list of events to a single VCALENDAR document.
  static String fromEvents({
    required String productId,
    required List<ICalEvent> events,
    DateTime Function()? nowProvider,
  }) {
    final buf = StringBuffer();
    final now = _utc(nowProvider?.call() ?? DateTime.now().toUtc());

    buf
      ..write('BEGIN:VCALENDAR')..write(_lineBreak)
      ..write('VERSION:2.0')..write(_lineBreak)
      ..write('PRODID:-//$productId//EN')..write(_lineBreak)
      ..write('CALSCALE:GREGORIAN')..write(_lineBreak)
      ..write('METHOD:PUBLISH')..write(_lineBreak);

    for (final e in events) {
      buf
        ..write('BEGIN:VEVENT')..write(_lineBreak)
        ..write('UID:')..write(e.uid)..write(_lineBreak)
        ..write('DTSTAMP:')..write(_formatUtc(now))..write(_lineBreak)
        ..write('DTSTART:')..write(_formatUtc(e.start))..write(_lineBreak);
      if (e.end != null) {
        buf..write('DTEND:')..write(_formatUtc(e.end!))..write(_lineBreak);
      }
      buf..write('SUMMARY:')..write(_fold(_escape(e.summary)))..write(_lineBreak);
      if (e.description != null && e.description!.isNotEmpty) {
        buf..write('DESCRIPTION:')..write(_fold(_escape(e.description!)))..write(_lineBreak);
      }
      if (e.location != null && e.location!.isNotEmpty) {
        buf..write('LOCATION:')..write(_fold(_escape(e.location!)))..write(_lineBreak);
      }
      buf..write('END:VEVENT')..write(_lineBreak);
    }

    buf..write('END:VCALENDAR')..write(_lineBreak);
    return buf.toString();
  }

  /// RFC 5545 line folding: any content line > 75 octets is split, and
  /// continuation lines start with a single space.
  static String _fold(String s) {
    final bytes = utf8.encode(s);
    if (bytes.length <= 75) return s;
    final out = StringBuffer();
    var start = 0;
    while (start < bytes.length) {
      final end = (start + 75).clamp(0, bytes.length);
      out.write(utf8.decode(bytes.sublist(start, end)));
      start = end;
      if (start < bytes.length) {
        out.write('$_lineBreak ');
      }
    }
    return out.toString();
  }

  /// RFC 5545 TEXT escaping: backslash-escape \, ;, , and newlines.
  static String _escape(String s) {
    return s
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n');
  }

  /// Render as basic UTC: `YYYYMMDDTHHMMSSZ`.
  static String _formatUtc(DateTime dt) {
    final u = _utc(dt);
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${u.year.toString().padLeft(4, '0')}'
        '${pad2(u.month)}${pad2(u.day)}T'
        '${pad2(u.hour)}${pad2(u.minute)}${pad2(u.second)}Z';
  }

  static DateTime _utc(DateTime dt) => dt.isUtc ? dt : dt.toUtc();
}
