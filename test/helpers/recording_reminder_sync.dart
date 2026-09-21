import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/notifications/reminder_sync.dart';

/// [ReminderSync] test double that counts `syncFromDatabase` calls and
/// otherwise runs the real pipeline against a [FakeNotificationService],
/// so tests can assert both "a re-sync happened" and "what the OS would
/// now hold".
class RecordingReminderSync extends ReminderSync {
  RecordingReminderSync._(
    this.fake, {
    required super.db,
    required super.tenantId,
    super.clock,
  }) : super(notifications: fake);

  factory RecordingReminderSync({
    required AppDatabase db,
    String tenantId = 'tenant-local',
    DateTime Function()? clock,
  }) =>
      RecordingReminderSync._(FakeNotificationService(), db: db, tenantId: tenantId, clock: clock);

  final FakeNotificationService fake;

  /// Number of `syncFromDatabase` invocations so far.
  int calls = 0;

  @override
  Future<int> syncFromDatabase({
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) {
    calls++;
    return super.syncFromDatabase(now: now, window: window);
  }
}
