import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/services/ical_export.dart';
import 'dnd_settings.dart';
import 'notification_service.dart';

/// io platforms: schedule through `flutter_local_notifications`.
class LocalNotificationService extends NotificationService {
  LocalNotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  @override
  DndSettings dnd = DndSettings.disabled;

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
    final nowTz = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime.from(event.start, tz.local);
    // `zonedSchedule` throws ArgumentError on a past timestamp. ReminderEngine
    // clamps overdue reminders to `now`, which can drift microseconds into
    // the past by the time we reach this call — nudge it forward instead of
    // losing the reminder altogether.
    if (!when.isAfter(nowTz)) {
      when = nowTz.add(const Duration(seconds: 1));
    }
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
