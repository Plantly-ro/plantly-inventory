import 'package:flutter/foundation.dart';

import '../domain/services/ical_export.dart';
import 'dnd_settings.dart';

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
  Future<bool> requestPermissions();
  Future<void> schedule({required int id, required ICalEvent event});
  Future<void> cancel(int id);
  Future<void> cancelAll();

  DndSettings get dnd;
  set dnd(DndSettings value);

  /// Replace the whole schedule in one call — easiest way to keep the OS
  /// in sync with [ReminderEngine.buildUpcoming]. Applies the DND window
  /// if set, shifting each event out of the quiet hours.
  Future<void> syncAll(Iterable<ICalEvent> events) async {
    await cancelAll();
    var i = 0;
    for (final e in events) {
      final shifted = dnd.enabled
          ? ICalEvent(
              uid: e.uid,
              summary: e.summary,
              description: e.description,
              location: e.location,
              start: dnd.pushPastWindow(e.start.toLocal()).toUtc(),
              end: e.end == null ? null : dnd.pushPastWindow(e.end!.toLocal()).toUtc(),
            )
          : e;
      await schedule(id: i++, event: shifted);
    }
  }
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
  Future<void> schedule({required int id, required ICalEvent event}) async {}

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

  @override
  DndSettings dnd = DndSettings.disabled;

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
      final shifted = dnd.enabled
          ? ICalEvent(
              uid: e.uid,
              summary: e.summary,
              description: e.description,
              location: e.location,
              start: dnd.pushPastWindow(e.start.toLocal()).toUtc(),
              end: e.end == null ? null : dnd.pushPastWindow(e.end!.toLocal()).toUtc(),
            )
          : e;
      await schedule(id: i++, event: shifted);
    }
  }
}

@immutable
class ScheduledCall {
  const ScheduledCall({required this.id, required this.event});
  final int id;
  final ICalEvent event;
}
