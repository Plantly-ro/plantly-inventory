import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/domain/services/reminder_engine.dart';

/// `ReminderEngine.buildUpcoming` feeds two consumers with different needs:
/// the iCal export / calendar wants overdue items surfaced at `now`; the OS
/// notification path (`ReminderSync`) must drop them so nothing fires the
/// moment it is scheduled (QA B3 — five notifications on first permission
/// grant, one per seeded-overdue demo plant).
void main() {
  final now = DateTime.utc(2026, 5, 1, 9);

  CareScheduleRow schedule(String id, DateTime due) => CareScheduleRow(
        id: id,
        tenantId: 'local',
        plantId: 'plant-$id',
        type: 'water',
        baseIntervalDays: 7,
        currentIntervalDays: 7,
        nextDueAt: due.millisecondsSinceEpoch,
        snoozeCount: 0,
        recentEventsJson: '[]',
        enabled: true,
        recurrenceMode: 'on_done',
        notificationsMuted: false,
        updatedHlc: 'hlc',
        deletedAt: null,
        deviceId: 'dev',
      );

  PlantRow plant(String id) => PlantRow(
        id: 'plant-$id',
        tenantId: 'local',
        nickname: id,
        speciesId: null,
        locationId: null,
        pinX: null,
        pinY: null,
        notificationsMuted: false,
        status: 'alive',
        acquiredAt: null,
        source: null,
        notes: null,
        potSizeCm: null,
        updatedHlc: 'hlc',
        deletedAt: null,
        deviceId: 'dev',
      );

  final schedules = [
    schedule('overdue', now.subtract(const Duration(days: 2))),
    schedule('justPast', now.subtract(const Duration(milliseconds: 1))),
    schedule('exactlyNow', now),
    schedule('future', now.add(const Duration(days: 2))),
    schedule('beyondWindow', now.add(const Duration(days: 40))),
  ];
  final plants = {for (final s in schedules) s.plantId: plant(s.id)};

  test('default (includeOverdue: true) clamps overdue items to now — calendar / iCal view', () {
    final events = ReminderEngine.buildUpcoming(
      schedules: schedules,
      plantsById: plants,
      locationsById: const {},
      now: now,
    );
    expect(events.map((e) => e.summary).toList(),
        ['Water — overdue', 'Water — justPast', 'Water — exactlyNow', 'Water — future']);
    expect(events.where((e) => e.start == now), hasLength(3), reason: 'overdue + just-past + now all clamp to now');
  });

  test('includeOverdue: false drops anything strictly before now; future items are kept', () {
    final events = ReminderEngine.buildUpcoming(
      schedules: schedules,
      plantsById: plants,
      locationsById: const {},
      now: now,
      includeOverdue: false,
    );
    expect(events.map((e) => e.summary).toList(), ['Water — exactlyNow', 'Water — future']);
    expect(events.every((e) => !e.start.isBefore(now)), isTrue);
    expect(events.last.start, now.add(const Duration(days: 2)));
  });

  test('includeOverdue: false with only overdue schedules yields an empty list', () {
    final events = ReminderEngine.buildUpcoming(
      schedules: schedules.take(2).toList(),
      plantsById: plants,
      locationsById: const {},
      now: now,
      includeOverdue: false,
    );
    expect(events, isEmpty);
  });
}
