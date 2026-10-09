import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/domain/services/ical_export.dart';
import 'package:plantly_inventory/notifications/local_notification_service.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

/// Review 2026-10-08 (P2): every launch / applying pull re-syncs the OS
/// reminders, and `cancelAll()` also cleared the ones already in the
/// shade. A re-sync now cancels only the PENDING requests.
class _FakePlugin implements FlutterLocalNotificationsPlugin {
  /// Scheduled, not yet shown.
  final Map<int, String?> pending = {};

  /// Already in the shade.
  final Set<int> displayed = {};
  int cancelAllCalls = 0;

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async =>
      [for (final e in pending.entries) PendingNotificationRequest(e.key, null, null, e.value)];

  @override
  Future<void> cancel(int id, {String? tag}) async {
    pending.remove(id);
    displayed.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    pending.clear();
    displayed.clear();
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required UILocalNotificationDateInterpretation uiLocalNotificationDateInterpretation,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    pending[id] = payload;
  }

  /// `resolvePlatformSpecificImplementation` (no platform plugin on the
  /// test VM) → null; anything else is unexpected.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #resolvePlatformSpecificImplementation) return null;
    return super.noSuchMethod(invocation);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ICalEvent evt(String uid, int days) => ICalEvent(
        uid: uid,
        summary: 'Water $uid',
        plantId: 'p-$uid',
        start: DateTime.now().toUtc().add(Duration(days: days)),
      );

  test('syncAll replaces pending reminders only; delivered ones stay in the shade', () async {
    final plugin = _FakePlugin();
    final svc = LocalNotificationService(plugin: plugin);
    await svc.syncAll([evt('a', 1), evt('b', 2)], tenantId: 't');
    final ids = reminderNotificationIds(['a', 'b']);
    expect(plugin.pending.keys, unorderedEquals(ids));
    expect(plugin.pending[ids[0]], contains('p-a'), reason: 'tap payload rides along');

    // 'a' fired and sits in the shade; a stale pending one from an older sync.
    plugin.pending.remove(ids[0]);
    plugin.displayed.add(ids[0]);
    plugin.pending[424242] = null;

    await svc.syncAll([evt('b', 2), evt('c', 3)], tenantId: 't');
    expect(plugin.cancelAllCalls, 0);
    expect(plugin.displayed, {ids[0]}, reason: 'the delivered reminder is not wiped');
    expect(plugin.pending.keys, unorderedEquals(reminderNotificationIds(['b', 'c'])));
  });
}
