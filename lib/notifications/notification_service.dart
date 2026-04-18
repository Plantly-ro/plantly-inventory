import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/services/ical_export.dart';

/// Tiny surface over `flutter_local_notifications` so the rest of the app
/// can schedule/cancel reminders without depending on the plugin directly.
/// A [FakeNotificationService] is provided for tests.
abstract class NotificationService {
  Future<void> init();
  Future<bool> requestPermissions();
  Future<void> schedule({required int id, required ICalEvent event});
  Future<void> cancel(int id);
  Future<void> cancelAll();

  /// Replace the whole schedule in one call — easiest way to keep the OS
  /// in sync with [ReminderEngine.buildUpcoming].
  Future<void> syncAll(Iterable<ICalEvent> events) async {
    await cancelAll();
    var i = 0;
    for (final e in events) {
      await schedule(id: i++, event: e);
    }
  }
}

class LocalNotificationService extends NotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  @override
  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // Keeping the device zone configurable via build env would be ideal;
    // for now, fall back to UTC and let the timezone plugin resolve the
    // local zone lazily when scheduling.
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final androidOk = await android?.requestNotificationsPermission() ?? true;
    final iosOk = await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? true;
    return androidOk && iosOk;
  }

  @override
  Future<void> schedule({required int id, required ICalEvent event}) async {
    await init();
    final when = tz.TZDateTime.from(event.start, tz.local);
    await _plugin.zonedSchedule(
      id,
      event.summary,
      event.description ?? '',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'plant_care',
          'Plant care reminders',
          channelDescription: 'Watering, fertilising, and other plant care reminders.',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await init();
    await _plugin.cancel(id);
  }

  @override
  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }
}

/// In-memory fake used by tests. Records the scheduled events so tests
/// can assert on them without spinning up the platform plugin.
class FakeNotificationService extends NotificationService {
  final List<ScheduledCall> calls = [];
  final Set<int> cancelled = {};
  bool initCalled = false;
  bool cancelAllCalled = false;

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule({required int id, required ICalEvent event}) async {
    calls.add(ScheduledCall(id: id, event: event));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalled = true;
    calls.clear();
  }

  @override
  Future<void> syncAll(Iterable<ICalEvent> events) async {
    await cancelAll();
    var i = 0;
    for (final e in events) {
      await schedule(id: i++, event: e);
    }
  }
}

@immutable
class ScheduledCall {
  const ScheduledCall({required this.id, required this.event});
  final int id;
  final ICalEvent event;
}
