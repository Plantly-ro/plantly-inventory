import '../../data/database/app_database.dart';
import 'ical_export.dart';

/// Pure "schedules → events" pipeline. Given the current [CareScheduleRow]s
/// (with `next_due_at` populated by the adaptive scheduler), produces the
/// list of reminders due within a window, ready to be (a) serialised to
/// iCal or (b) registered with `flutter_local_notifications`.
///
/// [buildUpcoming]'s `typeLabel` maps a `care_schedules.type` key to the
/// text used in the event summary (= notification title). Optional so the
/// pure engine stays locale-free; callers that own a locale pass one in.
class ReminderEngine {
  ReminderEngine._();

  /// Reminders for all enabled schedules with `next_due_at` within
  /// [window] from [now]. Past-due schedules (next_due_at < now) are
  /// surfaced at `now` so the user still sees them on the calendar.
  static List<ICalEvent> buildUpcoming({
    required List<CareScheduleRow> schedules,
    required Map<String, PlantRow> plantsById,
    required Map<String, LocationRow> locationsById,
    required DateTime now,
    Duration window = const Duration(days: 30),
    String Function(String type)? typeLabel,
  }) {
    final cutoff = now.add(window);
    final events = <ICalEvent>[];
    for (final s in schedules) {
      if (!s.enabled) continue;
      if (s.deletedAt != null) continue;
      final due = s.nextDueAt;
      if (due == null) continue;
      final at = DateTime.fromMillisecondsSinceEpoch(due, isUtc: true);
      if (at.isAfter(cutoff)) continue;
      final effective = at.isBefore(now) ? now : at;
      final plant = plantsById[s.plantId];
      if (plant == null) continue;
      final summary = '${(typeLabel ?? _verb)(s.type)} — ${plant.nickname}';
      events.add(ICalEvent(
        uid: '${s.id}@plantly.inventory',
        summary: summary,
        start: effective,
        end: effective.add(const Duration(minutes: 15)),
        description: plant.notes,
        location: plant.locationId != null
            ? locationsById[plant.locationId]?.name
            : null,
      ));
    }
    events.sort((a, b) => a.start.compareTo(b.start));
    return events;
  }

  /// English fallback used when no [typeLabel] resolver is supplied (pure
  /// unit tests). The app injects a localized, registry-aware resolver via
  /// `ReminderSync.typeLabel` so OS notification titles follow the device
  /// locale and any user renames.
  static String _verb(String type) {
    switch (type) {
      case 'water':
        return 'Water';
      case 'fertilize':
        return 'Fertilize';
      case 'repot':
        return 'Repot';
      case 'prune':
        return 'Prune';
      case 'mist':
        return 'Mist';
      case 'rotate':
        return 'Rotate';
      default:
        return type;
    }
  }
}
