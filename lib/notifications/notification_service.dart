import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/services/ical_export.dart';
import 'dnd_settings.dart';
import 'reminder_payload.dart';

/// Tiny surface over `flutter_local_notifications` so the rest of the app
/// can schedule/cancel reminders without depending on the plugin directly.
/// The plugin-backed implementation lives in `local_notification_service.dart`
/// (io only); web gets [UnsupportedNotificationService]. A
/// [FakeNotificationService] is provided for tests.
abstract class NotificationService {
  /// False where the platform can't fire scheduled OS notifications (web).
  /// UI uses this to say so instead of offering a permission prompt.
  bool get isSupported => true;

  Future<void> init();

  /// Prompt the OS permission dialog (Android 13+ POST_NOTIFICATIONS, iOS
  /// UNUserNotificationCenter). Only user-initiated surfaces call this —
  /// onboarding's "Allow" button, the Home banner, Me → Notifications.
  /// Startup must use [checkPermissions] instead so the system dialog never
  /// pre-empts the first onboarding page.
  Future<bool> requestPermissions();

  /// Current permission state WITHOUT prompting. `null` when the platform
  /// can't tell (no plugin implementation for this host).
  Future<bool?> checkPermissions();
  /// [payload] travels with the OS notification and comes back on tap
  /// (see [ReminderPayload]); null for notifications that open nothing.
  Future<void> schedule({required int id, required ICalEvent event, String? payload});
  Future<void> cancel(int id);
  Future<void> cancelAll();

  DndSettings get dnd;
  set dnd(DndSettings value);

  /// Payloads of reminders the user tapped while the app was running (or
  /// in the background). Cold-start taps come from [takeLaunchPayload].
  Stream<String> get taps => const Stream<String>.empty();

  /// Payload of the reminder whose tap launched the app, once — null when
  /// the app was started any other way (or it was already taken).
  Future<String?> takeLaunchPayload() async => null;

  /// Cancel every reminder that is SCHEDULED but not yet shown. Reminders
  /// already in the notification shade stay there. Default: [cancelAll]
  /// (fakes / hosts without a pending-request query).
  Future<void> cancelPending() => cancelAll();

  /// Replace the whole schedule in one call — easiest way to keep the OS
  /// in sync with [ReminderEngine.buildUpcoming]. Only pending reminders are
  /// replaced ([cancelPending]); displayed ones are left alone. Ids are
  /// stable per event uid ([reminderNotificationIds]), so a re-sync never
  /// reuses a delivered notification's id for another plant. Applies the
  /// DND window if set, shifting each event out of the quiet hours.
  /// [tenantId] is the tenant the events belong to; together with each
  /// event's plant id it becomes the tap payload.
  Future<void> syncAll(Iterable<ICalEvent> events, {String? tenantId}) async {
    await cancelPending();
    final list = events.toList();
    final ids = reminderNotificationIds([for (final e in list) e.uid]);
    for (var i = 0; i < list.length; i++) {
      final e = list[i];
      await schedule(id: ids[i], event: applyDnd(e), payload: reminderPayloadFor(e, tenantId));
    }
  }

  /// [e] shifted out of the DND window (unchanged when DND is off).
  @protected
  ICalEvent applyDnd(ICalEvent e) => dnd.enabled
      ? ICalEvent(
          uid: e.uid,
          summary: e.summary,
          description: e.description,
          location: e.location,
          plantId: e.plantId,
          start: dnd.pushPastWindow(e.start.toLocal()).toUtc(),
          end: e.end == null ? null : dnd.pushPastWindow(e.end!.toLocal()).toUtc(),
        )
      : e;
}

/// Stable 31-bit notification ids for [uids] (FNV-1a of the uid, linear
/// probing on a collision within the batch) — the same reminder keeps its
/// id across re-syncs.
List<int> reminderNotificationIds(List<String> uids) {
  final used = <int>{};
  return [
    for (final uid in uids)
      () {
        var id = _fnv1a31(uid);
        while (!used.add(id)) {
          id = (id + 1) & 0x7fffffff;
        }
        return id;
      }(),
  ];
}

int _fnv1a31(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0x7fffffff;
}

/// Tap payload for a reminder event, or null when it names no plant.
String? reminderPayloadFor(ICalEvent e, String? tenantId) {
  final plantId = e.plantId;
  if (plantId == null || plantId.isEmpty) return null;
  return ReminderPayload(plantId: plantId, tenantId: tenantId).encode();
}

/// Web: browsers have no scheduled-local-notification story (no
/// flutter_local_notifications implementation, and Web Push needs a
/// server). Accept every call, schedule nothing, report unsupported so
/// the Me screen shows honest copy. In-app reminders still work — they
/// read the schedule table directly.
class UnsupportedNotificationService extends NotificationService {
  @override
  bool get isSupported => false;

  @override
  DndSettings dnd = DndSettings.disabled;

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<bool?> checkPermissions() async => false;

  @override
  Future<void> schedule({required int id, required ICalEvent event, String? payload}) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelAll() async {}
}

/// In-memory fake used by tests. Records the scheduled events so tests
/// can assert on them without spinning up the platform plugin.
class FakeNotificationService extends NotificationService {
  final List<ScheduledCall> calls = [];
  final Set<int> cancelled = {};
  bool initCalled = false;
  bool cancelAllCalled = false;

  /// What [checkPermissions] reports and what [requestPermissions] "grants".
  bool? permissionGranted = true;

  /// Number of times the (prompting) [requestPermissions] was called —
  /// bootstrap must leave this at 0.
  int requestPermissionsCalls = 0;
  int checkPermissionsCalls = 0;

  @override
  DndSettings dnd = DndSettings.disabled;

  @override
  Future<void> init() async {
    initCalled = true;
  }

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCalls++;
    return permissionGranted ?? true;
  }

  @override
  Future<bool?> checkPermissions() async {
    checkPermissionsCalls++;
    return permissionGranted;
  }

  @override
  Future<void> schedule({required int id, required ICalEvent event, String? payload}) async {
    calls.add(ScheduledCall(id: id, event: event, payload: payload));
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

  final StreamController<String> _taps = StreamController<String>.broadcast();

  /// Payload [takeLaunchPayload] hands out once (a cold-start tap).
  String? launchPayload;

  /// Simulate the user tapping a delivered reminder.
  void tap(String payload) => _taps.add(payload);

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchPayload() async {
    final p = launchPayload;
    launchPayload = null;
    return p;
  }
}

@immutable
class ScheduledCall {
  const ScheduledCall({required this.id, required this.event, this.payload});
  final int id;
  final ICalEvent event;
  final String? payload;
}
