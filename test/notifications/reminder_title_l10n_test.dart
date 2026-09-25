import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/care_types.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/care_schedule_repository.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/notifications/reminder_sync.dart';
import 'package:plantly_inventory/shared/care_type_labels.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

/// Issue #15 remainder — OS notification titles are built by
/// `ReminderEngine.buildUpcoming` at schedule time, outside the widget
/// tree. `ReminderSync.typeLabel` (wired in `providers.dart` to
/// `careKeyVerb(appLocalizationsForPlatform(), registry, key)`) is what
/// makes them follow the device locale and any user renames. These tests
/// pin the seam: same schedule, three resolvers, three titles.
void main() {
  late AppDatabase db;
  late FakeNotificationService fake;
  late PlantRepository plants;
  late OpLogWriter opLog;

  ReminderSync sync({String Function(String type)? typeLabel}) => ReminderSync(
        db: db,
        notifications: fake,
        tenantId: 'tenant-local',
        clock: () => DateTime.utc(2026, 5, 1),
        typeLabel: typeLabel,
      );

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'test-device'), tenantId: 'tenant-local');
    fake = FakeNotificationService();
    plants = PlantRepository(db: db, opLog: opLog);
  });

  tearDown(() => db.close());

  Future<void> seedWaterSchedule(ReminderSync s) async {
    final p = await plants.create(nickname: 'Bob');
    final schedules = CareScheduleRepository(db: db, opLog: opLog, reminderSync: s);
    await schedules.upsert(
      plantId: p.id,
      type: 'water',
      baseIntervalDays: 7,
      firstDueAt: DateTime.utc(2026, 5, 1),
    );
  }

  test('without a resolver the engine keeps its English fallback', () async {
    final s = sync();
    await seedWaterSchedule(s);
    await s.syncFromDatabase();
    expect(fake.calls.map((c) => c.event.summary), ['Water — Bob']);
  });

  test('a Romanian resolver yields a Romanian imperative title', () async {
    final ro = AppLocalizationsRo();
    final s = sync(typeLabel: (type) => careKeyVerb(ro, kBuiltInCareTypes, type));
    await seedWaterSchedule(s);
    await s.syncFromDatabase();
    expect(fake.calls.map((c) => c.event.summary), ['Udă — Bob']);
  });

  test('a renamed built-in is honoured in the title (resolver reads the live registry)', () async {
    final ro = AppLocalizationsRo();
    var registry = kBuiltInCareTypes;
    final s = sync(typeLabel: (type) => careKeyVerb(ro, registry, type));
    await seedWaterSchedule(s);
    await s.syncFromDatabase();
    expect(fake.calls.map((c) => c.event.summary), ['Udă — Bob']);

    // Rename after the first sync: the next run must reflect it without
    // rebuilding ReminderSync (this is the boot re-sync / pull-to-refresh
    // path in providers.dart, which reads `careTypesProvider` per call).
    registry = [for (final t in kBuiltInCareTypes) t.key == 'water' ? t.copyWith(label: 'Apă') : t];
    await s.syncFromDatabase();
    expect(fake.calls.map((c) => c.event.summary), ['Apă — Bob']);
  });

  test('a custom care type passes through the resolver with its own label', () async {
    final ro = AppLocalizationsRo();
    final types = [
      ...kBuiltInCareTypes,
      const CareType(key: 'neem_spray', label: 'Spray cu neem', iconCode: 0, defaultIntervalDays: 14),
    ];
    final s = sync(typeLabel: (type) => careKeyVerb(ro, types, type));
    final p = await plants.create(nickname: 'Bob');
    final schedules = CareScheduleRepository(db: db, opLog: opLog, reminderSync: s);
    await schedules.upsert(
      plantId: p.id,
      type: 'neem_spray',
      baseIntervalDays: 14,
      firstDueAt: DateTime.utc(2026, 5, 1),
    );
    await s.syncFromDatabase();
    expect(fake.calls.map((c) => c.event.summary), ['Spray cu neem — Bob']);
  });
}
