import 'dart:async';

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
    Set<String> Function()? mutedTypesSnapshot,
    DateTime Function()? clock,
  })  : _mutedTypesSnapshot = mutedTypesSnapshot,
        _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final NotificationService notifications;
  final String tenantId;

  /// Source of "now" for reminder windowing. Injectable so the record /
  /// snooze re-sync path (which doesn't pass an explicit `now`) is
  /// deterministic under test instead of reading the wall clock.
  final DateTime Function() _clock;
  /// Returns the current set of globally-muted care-type keys. Called
  /// per sync so toggles in the Me screen take effect on the next write
  /// without wiring a listener into this class.
  final Set<String> Function()? _mutedTypesSnapshot;

  // Single-flight + trailing run. Every repository mutation calls
  // [syncFromDatabase]; a bulk mute/delete of N plants would otherwise do
  // N full cancelAll+schedule rounds against the OS. While a run is in
  // flight, later callers mark the state dirty and share ONE trailing
  // run that starts after the current one finishes — so 20 overlapping
  // calls cost at most 2 pipeline runs, and the trailing run always sees
  // the newest rows.
  Future<int>? _inflight;
  Completer<int>? _trailing;
  bool _dirty = false;
  DateTime? _pendingNow;
  Duration _pendingWindow = const Duration(days: 30);

  /// Rebuild the entire reminder set from the current schedule rows and
  /// hand it to the platform plugin. Called on every schedule-affecting
  /// mutation — conservative but cheap, and coalesced (see above).
  ///
  /// Callers that arrive while a run is in flight get the future of the
  /// trailing run, so `await syncFromDatabase()` always means "a rebuild
  /// that observed my write has completed".
  Future<int> syncFromDatabase({
    DateTime? now,
    Duration window = const Duration(days: 30),
  }) {
    if (_inflight != null) {
      _dirty = true;
      _pendingNow = now;
      _pendingWindow = window;
      return (_trailing ??= Completer<int>()).future;
    }
    return _inflight = _drive(now, window);
  }

  Future<int> _drive(DateTime? now, Duration window) async {
    try {
      return await _runOnce(now: now, window: window);
    } finally {
      _inflight = null;
      if (_dirty) {
        _dirty = false;
        final completer = _trailing!;
        _trailing = null;
        // The trailing run becomes the new in-flight run, so anything that
        // arrives while it executes coalesces onto the next one.
        final next = _inflight = _drive(_pendingNow, _pendingWindow);
        next.then(completer.complete, onError: completer.completeError);
      }
    }
  }

  Future<int> _runOnce({
    required DateTime? now,
    required Duration window,
  }) async {
    final nowUtc = (now ?? _clock()).toUtc();
    final schedules = await (db.select(db.careSchedules)
          ..where((s) =>
              s.tenantId.equals(tenantId) &
              s.deletedAt.isNull() &
              s.enabled.equals(true) &
              s.nextDueAt.isNotNull() &
              s.notificationsMuted.equals(false)))
        .get();
    final plantRows = await (db.select(db.plants)
          ..where((p) => p.tenantId.equals(tenantId) & p.deletedAt.isNull()))
        .get();
    final locationRows = await (db.select(db.locations)
          ..where((l) => l.tenantId.equals(tenantId) & l.deletedAt.isNull()))
        .get();
    final plantsById = {for (final p in plantRows) p.id: p};
    final locationsById = {for (final l in locationRows) l.id: l};

    final mutedTypes = _mutedTypesSnapshot?.call() ?? const <String>{};
    // Drop schedules whose plant is muted, whose location is muted, or
    // whose care-type is globally silenced.
    final activeSchedules = [
      for (final s in schedules)
        if (!mutedTypes.contains(s.type) &&
            !(plantsById[s.plantId]?.notificationsMuted ?? false) &&
            !((plantsById[s.plantId]?.locationId != null &&
                (locationsById[plantsById[s.plantId]!.locationId]?.notificationsMuted ?? false))))
          s
    ];

    final events = ReminderEngine.buildUpcoming(
      schedules: activeSchedules,
      plantsById: plantsById,
      locationsById: locationsById,
      now: nowUtc,
      window: window,
    );
    await notifications.syncAll(events);
    return events.length;
  }
}
