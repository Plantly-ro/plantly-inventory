import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:ulid/ulid.dart';

import '../../domain/services/adaptive_schedule.dart';
import '../../domain/services/local_calendar.dart';
import '../../notifications/reminder_sync.dart';
import '../../sync/op_log.dart';
import '../database/app_database.dart';

/// CRUD + runtime for `care_schedules`. In addition to plain persistence,
/// it runs `AdaptiveSchedule.adjust()` on every recorded care event to
/// maintain `current_interval_days` and stamp `next_due_at`.
///
/// The rolling window of events is persisted in `recent_events_json` as a
/// list of `{done_at, snoozed}` records, newest-first, capped at
/// [AdaptiveSchedule.windowSize] entries.
class CareScheduleRepository {
  CareScheduleRepository({
    required this.db,
    required this.opLog,
    this.reminderSync,
    this.calendar = const LocalCalendar(),
  });

  final AppDatabase db;
  final OpLogWriter opLog;
  final ReminderSync? reminderSync;

  /// Due-date arithmetic in the user's local zone (DST-safe).
  final LocalCalendar calendar;

  static const int maxWindow = AdaptiveSchedule.windowSize;

  /// Live stream of schedules due on or before [cutoff] (ms since epoch).
  /// Used by OverdueWidget (today's wall-clock) and TodayWidget
  /// (cutoff = end of local day).
  Stream<List<CareScheduleRow>> watchDueBefore(int cutoffMs) {
    return (db.select(db.careSchedules)
          ..where((s) =>
              s.tenantId.equals(opLog.tenantId) &
              s.deletedAt.isNull() &
              s.enabled.equals(true) &
              s.nextDueAt.isNotNull() &
              s.nextDueAt.isSmallerOrEqualValue(cutoffMs))
          ..orderBy([(s) => OrderingTerm(expression: s.nextDueAt)]))
        .watch();
  }

  Stream<List<CareScheduleRow>> watchForPlant(String plantId) {
    return (db.select(db.careSchedules)
          ..where((s) =>
              s.tenantId.equals(opLog.tenantId) &
              s.plantId.equals(plantId) &
              s.deletedAt.isNull()))
        .watch();
  }

  Future<CareScheduleRow?> forPlantAndType(String plantId, String type) {
    return (db.select(db.careSchedules)
          ..where((s) =>
              s.tenantId.equals(opLog.tenantId) &
              s.plantId.equals(plantId) &
              s.type.equals(type) &
              s.deletedAt.isNull()))
        .getSingleOrNull();
  }

  /// `UNIQUE(tenant_id, plant_id, type)` is not partial, so a soft-deleted
  /// schedule still holds the key and re-adding the same reminder type would
  /// fail. Deletes are final on the wire (CLOUD-SYNC-CONTRACT §2.3), so the
  /// dead row is not revived: it is dropped here (its tombstone op stays in
  /// `sync_ops`) and the caller creates a fresh row under a new id, which
  /// every peer accepts the same way (`SyncApplier._resolveUniqueConflict`).
  Future<void> _purgeDeleted(String plantId, String type) {
    return (db.delete(db.careSchedules)
          ..where((s) =>
              s.tenantId.equals(opLog.tenantId) &
              s.plantId.equals(plantId) &
              s.type.equals(type) &
              s.deletedAt.isNotNull()))
        .go();
  }

  /// Create a schedule with a base interval. `next_due_at` is computed
  /// from [firstDueAt] (defaults to "now + base_interval_days").
  /// [recurrenceMode] — `after_completion` (default — re-schedule from
  /// the moment the user marks the event done), `fixed` (keeps the
  /// original cadence regardless of when the user logs the event), or
  /// `once` (disable the schedule after one event).
  Future<CareScheduleRow> upsert({
    required String plantId,
    required String type,
    required double baseIntervalDays,
    DateTime? firstDueAt,
    String recurrenceMode = 'after_completion',
    String? assigneeUserId,
  }) async {
    final existing = await forPlantAndType(plantId, type);
    final row = existing ??
        await db.transaction<CareScheduleRow>(() async {
          await _purgeDeleted(plantId, type);
          final id = Ulid().toString();
          final firstDue = firstDueAt ??
              DateTime.fromMillisecondsSinceEpoch(
                calendar.addDays(DateTime.now().millisecondsSinceEpoch, baseIntervalDays),
                isUtc: true,
              );
          final value = {
            'id': id,
            'tenant_id': opLog.tenantId,
            'plant_id': plantId,
            'type': type,
            'base_interval_days': baseIntervalDays,
            'current_interval_days': baseIntervalDays,
            'next_due_at': firstDue.millisecondsSinceEpoch,
            'enabled': 1,
            'recent_events_json': '[]',
            'snooze_count': 0,
            'recurrence_mode': recurrenceMode,
            'assignee_user_id': ?assigneeUserId,
          };
          final hlc = await opLog.recordCreate(
            entity: 'care_schedules',
            entityId: id,
            value: value,
          );
          await db.into(db.careSchedules).insert(
                CareSchedulesCompanion.insert(
                  id: id,
                  tenantId: opLog.tenantId,
                  plantId: plantId,
                  type: type,
                  baseIntervalDays: baseIntervalDays,
                  currentIntervalDays: baseIntervalDays,
                  nextDueAt: Value(firstDue.millisecondsSinceEpoch),
                  recurrenceMode: Value(recurrenceMode),
                  assigneeUserId: Value(assigneeUserId),
                  updatedHlc: hlc.encode(),
                  deviceId: opLog.clock.deviceId,
                ),
              );
          return (await forPlantAndType(plantId, type))!;
        });
    // Register the alarm now, not on the next pull-to-refresh: this is the
    // Add-reminder → Save path and it used to be the only mutator that
    // never re-synced (issue #13). Also runs on the idempotent branch so a
    // caller can rely on "upsert ⇒ OS reminders are current".
    await _resync();
    return row;
  }

  /// Called by CareEventRepository after recording an event. Appends the
  /// new sample to `recent_events_json`, runs the adaptive algorithm, and
  /// updates `current_interval_days` / `next_due_at` / `last_done_at`.
  /// [snoozedBeforeDone] counts how many snoozes the user tapped between
  /// `next_due_at` and the actual completion.
  Future<void> applyCareEvent({
    required String plantId,
    required String type,
    required DateTime doneAt,
    int snoozedBeforeDone = 0,
  }) async {
    final s = await forPlantAndType(plantId, type);
    if (s == null) return; // no schedule → nothing to update

    return db.transaction(() async {
      final nowMs = doneAt.millisecondsSinceEpoch;
      final events = _decodeWindow(s.recentEventsJson);
      final actualInterval = s.lastDoneAt == null
          ? null
          : (nowMs - s.lastDoneAt!) / (86400.0 * 1000);
      final newEvent = _EventSample(
        doneAt: nowMs,
        snoozed: snoozedBeforeDone > 0,
        actualIntervalDays: actualInterval,
      );
      final updatedWindow = [newEvent, ...events].take(maxWindow).toList();

      final decision = AdaptiveSchedule.adjust(
        baseIntervalDays: s.baseIntervalDays,
        currentIntervalDays: s.currentIntervalDays,
        recentEvents: [
          for (final e in updatedWindow)
            CompletedCareEvent(
              snoozed: e.snoozed,
              actualIntervalDays: e.actualIntervalDays,
            ),
        ],
        consecutiveHighSnoozeCycles: s.snoozeCount,
      );

      // Branch on recurrence mode. `after_completion` is the existing
      // behaviour (adaptive-interval-from-now). `fixed` preserves the
      // original cadence anchored on the first-due timestamp. `once`
      // disables the schedule after the event lands.
      int? nextDueAtMs;
      bool stillEnabled = s.enabled;
      double intervalDaysForPersist = decision.nextIntervalDays;
      switch (s.recurrenceMode) {
        case 'once':
          nextDueAtMs = null;
          stillEnabled = false;
          intervalDaysForPersist = s.currentIntervalDays;
          break;
        case 'fixed':
          // The schedule's original next_due_at is the anchor; advance
          // by whole-interval steps (local calendar days, so the time of
          // day survives DST) until we land strictly after doneAt.
          final intervalMs = (s.currentIntervalDays * 86400 * 1000).round();
          if (intervalMs <= 0) {
            nextDueAtMs = null;
            stillEnabled = false;
          } else {
            var next = s.nextDueAt ?? nowMs;
            while (next <= nowMs) {
              next = calendar.addDays(next, s.currentIntervalDays);
            }
            nextDueAtMs = next;
            intervalDaysForPersist = s.currentIntervalDays; // no adaptation
          }
          break;
        case 'after_completion':
        default:
          nextDueAtMs = calendar.addDays(nowMs, decision.nextIntervalDays);
          break;
      }

      // One ordinary field op per column, all six every time so the
      // schedule a peer ends up with is one coherent "after this care
      // event" state under LWW. 1.1.0 recorded a single `@applyCareEvent`
      // op instead, which no applier understood (the schedule never moved
      // on other devices); SyncApplier still expands those.
      final hlc = (await opLog.recordFieldUpdates(
        entity: 'care_schedules',
        entityId: s.id,
        fields: {
          'last_done_at': nowMs,
          'current_interval_days': intervalDaysForPersist,
          'next_due_at': nextDueAtMs,
          'snooze_count': decision.consecutiveHighSnoozeCycles,
          'recent_events_json': _encodeWindow(updatedWindow),
          'enabled': stillEnabled,
        },
      ))!;

      await (db.update(db.careSchedules)..where((row) => row.id.equals(s.id))).write(
        CareSchedulesCompanion(
          lastDoneAt: Value(nowMs),
          currentIntervalDays: Value(intervalDaysForPersist),
          nextDueAt: Value(nextDueAtMs),
          snoozeCount: Value(decision.consecutiveHighSnoozeCycles),
          recentEventsJson: Value(_encodeWindow(updatedWindow)),
          enabled: Value(stillEnabled),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
  }

  /// In-place edit of an existing schedule. Updates interval, recurrence
  /// mode, and next_due_at atomically so the adaptive algorithm picks
  /// up the new baseline on the next care event. The adaptive window is
  /// reset too (a manual edit is an authoritative signal that overrides
  /// past snooze/early data). Every column that actually changes gets its
  /// own op — nothing more, nothing less.
  ///
  /// [assigneeUserId] (MULTI-USER-V2 §0) is only written when the caller
  /// passes it (`Value.absent()` = leave as is; `Value(null)` = back to
  /// "everyone"); it records its own `assignee_user_id` op when it changes.
  Future<void> edit(
    String scheduleId, {
    required double baseIntervalDays,
    required String recurrenceMode,
    required DateTime nextDueAt,
    Value<String?> assigneeUserId = const Value.absent(),
  }) async {
    await db.transaction(() async {
      final current =
          await (db.select(db.careSchedules)..where((r) => r.id.equals(scheduleId))).getSingleOrNull();
      if (current == null) return;
      final nextDueMs = nextDueAt.millisecondsSinceEpoch;
      final assigneeChanged = assigneeUserId.present && current.assigneeUserId != assigneeUserId.value;
      final hlc = await opLog.recordFieldUpdates(entity: 'care_schedules', entityId: scheduleId, fields: {
        if (current.baseIntervalDays != baseIntervalDays) 'base_interval_days': baseIntervalDays,
        if (current.currentIntervalDays != baseIntervalDays) 'current_interval_days': baseIntervalDays,
        if (current.recurrenceMode != recurrenceMode) 'recurrence_mode': recurrenceMode,
        if (current.nextDueAt != nextDueMs) 'next_due_at': nextDueMs,
        if (!current.enabled) 'enabled': true,
        if (current.snoozeCount != 0) 'snooze_count': 0,
        if (current.recentEventsJson != '[]') 'recent_events_json': '[]',
        if (assigneeChanged) 'assignee_user_id': assigneeUserId.value,
      });
      if (hlc == null) return;
      await (db.update(db.careSchedules)..where((r) => r.id.equals(scheduleId))).write(
        CareSchedulesCompanion(
          baseIntervalDays: Value(baseIntervalDays),
          currentIntervalDays: Value(baseIntervalDays),
          recurrenceMode: Value(recurrenceMode),
          nextDueAt: Value(nextDueMs),
          enabled: const Value(true),
          snoozeCount: const Value(0),
          recentEventsJson: const Value('[]'),
          assigneeUserId: assigneeChanged ? Value(assigneeUserId.value) : const Value.absent(),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
    await _resync();
  }

  /// Set / clear the assignee of one schedule without touching anything
  /// else (null = everyone). Records one `assignee_user_id` op when the
  /// value changes.
  Future<void> setAssignee(String scheduleId, String? assigneeUserId) async {
    await db.transaction(() async {
      final current =
          await (db.select(db.careSchedules)..where((r) => r.id.equals(scheduleId))).getSingleOrNull();
      if (current == null || current.assigneeUserId == assigneeUserId) return;
      await _writeAssignee(scheduleId, assigneeUserId);
    });
    await _resync();
  }

  /// MULTI-USER-V2 §0 stale-assignee rule: after a successful members
  /// fetch, every live schedule of this tenant assigned to someone who is
  /// NOT in [memberIds] goes back to "everyone" (`assignee_user_id = null`)
  /// through an ordinary local field op, so the other devices converge.
  /// Returns how many schedules were cleared. The server never validates
  /// the assignee, so this is the only place a removed member's
  /// assignments are undone.
  Future<int> clearAssigneesNotIn(Set<String> memberIds) async {
    final stale = await (db.select(db.careSchedules)
          ..where((s) => s.tenantId.equals(opLog.tenantId) & s.deletedAt.isNull() & s.assigneeUserId.isNotNull()))
        .get();
    final toClear = [
      for (final s in stale)
        if (!memberIds.contains(s.assigneeUserId)) s.id,
    ];
    if (toClear.isEmpty) return 0;
    await db.transaction(() async {
      for (final id in toClear) {
        await _writeAssignee(id, null);
      }
    });
    await _resync();
    return toClear.length;
  }

  /// Clear every live assignment of [userId] in this tenant (a member who
  /// left / was removed). Returns the count.
  Future<int> clearAssigneesFor(String userId) async {
    final rows = await (db.select(db.careSchedules)
          ..where((s) => s.tenantId.equals(opLog.tenantId) & s.deletedAt.isNull() & s.assigneeUserId.equals(userId)))
        .get();
    if (rows.isEmpty) return 0;
    await db.transaction(() async {
      for (final s in rows) {
        await _writeAssignee(s.id, null);
      }
    });
    await _resync();
    return rows.length;
  }

  Future<void> _writeAssignee(String scheduleId, String? assigneeUserId) async {
    final hlc = await opLog.recordFieldUpdate(
      entity: 'care_schedules',
      entityId: scheduleId,
      field: 'assignee_user_id',
      value: assigneeUserId,
    );
    await (db.update(db.careSchedules)..where((r) => r.id.equals(scheduleId))).write(
      CareSchedulesCompanion(
        assigneeUserId: Value(assigneeUserId),
        updatedHlc: Value(hlc.encode()),
        deviceId: Value(opLog.clock.deviceId),
      ),
    );
  }

  /// Remove a schedule entirely (tombstone). For one-off reminders the
  /// "once" recurrence mode handles auto-disable; this is the explicit
  /// user-pulled-the-plug path.
  Future<void> softDelete(String scheduleId) async {
    await db.transaction(() async {
      final hlc = await opLog.recordTombstone(entity: 'care_schedules', entityId: scheduleId);
      await (db.update(db.careSchedules)..where((r) => r.id.equals(scheduleId))).write(
        CareSchedulesCompanion(
          deletedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
    await _resync();
  }

  /// Toggle per-schedule notification mute. ReminderSync reads this.
  Future<void> setNotificationsMuted(String scheduleId, bool muted) async {
    await db.transaction(() async {
      final hlc = await opLog.recordFieldUpdate(
        entity: 'care_schedules',
        entityId: scheduleId,
        field: 'notifications_muted',
        value: muted,
      );
      await (db.update(db.careSchedules)..where((r) => r.id.equals(scheduleId))).write(
        CareSchedulesCompanion(
          notificationsMuted: Value(muted),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
    await _resync();
  }

  Future<void> snooze(String scheduleId, {Duration by = const Duration(days: 1)}) async {
    await db.transaction(() async {
      final s = await (db.select(db.careSchedules)..where((r) => r.id.equals(scheduleId))).getSingleOrNull();
      if (s == null || s.nextDueAt == null) return;
      final next = calendar.addDuration(s.nextDueAt!, by);
      // snooze_count is written below too, so it needs its own op — it used
      // to change locally only and drift from every peer.
      final hlc = (await opLog.recordFieldUpdates(
        entity: 'care_schedules',
        entityId: s.id,
        fields: {'next_due_at': next, 'snooze_count': s.snoozeCount + 1},
      ))!;
      await (db.update(db.careSchedules)..where((r) => r.id.equals(scheduleId))).write(
        CareSchedulesCompanion(
          nextDueAt: Value(next),
          snoozeCount: Value(s.snoozeCount + 1),
          updatedHlc: Value(hlc.encode()),
          deviceId: Value(opLog.clock.deviceId),
        ),
      );
    });
    await _resync();
  }

  /// Rebuild the OS reminder set after a committed schedule mutation.
  /// Best-effort: a notification-plugin failure must never fail the write.
  Future<void> _resync() async {
    try {
      await reminderSync?.syncFromDatabase();
    } catch (e) {
      if (kDebugMode) debugPrint('reminder re-sync failed: $e');
    }
  }

  List<_EventSample> _decodeWindow(String json_) {
    try {
      final list = (json.decode(json_) as List).cast<Map<String, dynamic>>();
      return list.map(_EventSample.fromJson).toList();
    } catch (_) {
      return const [];
    }
  }

  String _encodeWindow(List<_EventSample> events) =>
      json.encode([for (final e in events) e.toJson()]);
}

class _EventSample {
  const _EventSample({
    required this.doneAt,
    required this.snoozed,
    required this.actualIntervalDays,
  });

  final int doneAt;
  final bool snoozed;
  final double? actualIntervalDays;

  factory _EventSample.fromJson(Map<String, dynamic> m) => _EventSample(
        doneAt: m['done_at'] as int,
        snoozed: m['snoozed'] as bool? ?? false,
        actualIntervalDays: (m['actual_interval_days'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'done_at': doneAt,
        'snoozed': snoozed,
        if (actualIntervalDays != null) 'actual_interval_days': actualIntervalDays,
      };
}
