import 'package:drift/drift.dart';

import '../data/database/app_database.dart';
import '../domain/services/reminder_engine.dart';
import 'notification_service.dart';

/// Glue between the Drift-backed care_schedules + plants + locations and
/// the platform `NotificationService`. Call [syncFromDatabase] any time
/// the schedule state changes so the OS reminders track reality.
///
/// Deliberately a plain class (no Riverpod) so it's trivial to unit-test
/// by injecting a [FakeNotificationService] + an in-memory Drift.
class ReminderSync {
  ReminderSync({
    required this.db,
    required this.notifications,
    required this.tenantId,
  });

  final AppDatabase db;
  final NotificationService notifications;
  final String tenantId;

  /// Rebuild the entire reminder set from the current schedule rows and
  /// hand it to the platform plugin. Called on care-event record /
  /// snooze / schedule edit — conservative but cheap.
  Future<int> syncFromDatabase({
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) async {
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final schedules = await (db.select(db.careSchedules)
          ..where((s) =>
              s.tenantId.equals(tenantId) &
              s.deletedAt.isNull() &
              s.enabled.equals(true) &
              s.nextDueAt.isNotNull()))
        .get();
    final plantRows = await (db.select(db.plants)
          ..where((p) => p.tenantId.equals(tenantId) & p.deletedAt.isNull()))
        .get();
    final locationRows = await (db.select(db.locations)
          ..where((l) => l.tenantId.equals(tenantId) & l.deletedAt.isNull()))
        .get();
    final plantsById = {for (final p in plantRows) p.id: p};
    final locationsById = {for (final l in locationRows) l.id: l};

    final events = ReminderEngine.buildUpcoming(
      schedules: schedules,
      plantsById: plantsById,
      locationsById: locationsById,
      now: nowUtc,
      window: window,
    );
    await notifications.syncAll(events);
    return events.length;
  }
}
