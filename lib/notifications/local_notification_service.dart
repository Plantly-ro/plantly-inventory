import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/services/ical_export.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/care_type_labels.dart';
import 'dnd_settings.dart';
import 'notification_service.dart';

/// Android channel id — stable across locales; only the user-visible
/// name/description are localized.
const String kPlantCareChannelId = 'plant_care';

/// The plant-care channel, localized from [t] so a Romanian device sees
/// Romanian text in Settings → Notifications. Created explicitly in [init]
/// (see [plantCareChannel]); per-notification details keep the plugin's
/// default `createIfNotExists` action — passing `update` there would skip
/// channel creation entirely on a fresh install (plugin predicate:
/// `channel == null && action == Update` creates nothing) and every
/// reminder would be silently dropped by Android 8+.
AndroidNotificationChannel plantCareChannel(AppLocalizations t) => AndroidNotificationChannel(
      kPlantCareChannelId,
      t.notifChannelName,
      description: t.notifChannelDescription,
      importance: Importance.defaultImportance,
    );

/// Android details for a plant-care reminder (same channel, same copy).
AndroidNotificationDetails androidReminderDetails(AppLocalizations t) => AndroidNotificationDetails(
      kPlantCareChannelId,
      t.notifChannelName,
      channelDescription: t.notifChannelDescription,
      importance: Importance.defaultImportance,
    );

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
    // Create the channel up front (no-op once it exists) so the first
    // reminder never targets a missing channel.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(plantCareChannel(appLocalizationsForPlatform()));
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
  Future<bool?> checkPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return android.areNotificationsEnabled();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) return (await ios.checkPermissions())?.isEnabled;
    final macos = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    if (macos != null) return (await macos.checkPermissions())?.isEnabled;
    // Desktop hosts without a permission model: nothing to grant.
    return true;
  }

  @override
  Future<void> schedule({required int id, required ICalEvent event}) async {
    await init();
    final nowTz = tz.TZDateTime.now(tz.local);
    final when = tz.TZDateTime.from(event.start, tz.local);
    // `zonedSchedule` throws ArgumentError on a past timestamp (helpers.dart
    // `validateDateIsInTheFuture`). We used to nudge such times 1s ahead,
    // which made every already-due reminder fire the moment it was
    // (re)scheduled — i.e. a burst of N notifications right after the
    // permission was granted on a fresh install. ReminderSync already
    // drops overdue rows; this is the last-line guard for the exactly-now /
    // clock-drift case. The item stays visible in-app.
    if (!when.isAfter(nowTz)) return;
    await _plugin.zonedSchedule(
      id,
      event.summary,
      event.description ?? '',
      when,
      NotificationDetails(
        android: androidReminderDetails(appLocalizationsForPlatform()),
        iOS: const DarwinNotificationDetails(),
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
