import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/features/collections/activity_local_names.dart';
import 'package:plantly_inventory/features/collections/collection_activity_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/marketplace/activity_models.dart';

import '../../cloud/collection_activity_test.dart' show ev;

/// QA (p): the feed said "qafinal1 edited a plant" — which one? Events the
/// server sent without `summary.name` take the name from this device's copy.
void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'p-1', tenantId: 'col-2', nickname: 'Monstera', status: 'alive', updatedHlc: '0-0-d', deviceId: 'd'));
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'p-gone', tenantId: 'col-2', nickname: 'Old fern', status: 'alive', updatedHlc: '0-0-d', deviceId: 'd',
        deletedAt: const Value(1)));
    await db.into(db.plants).insert(PlantsCompanion.insert(
        id: 'p-other', tenantId: 'col-9', nickname: 'Not here', status: 'alive', updatedHlc: '0-0-d', deviceId: 'd'));
    await db.into(db.careSchedules).insert(CareSchedulesCompanion.insert(
        id: 's-1', tenantId: 'col-2', plantId: 'p-1', type: 'water', baseIntervalDays: 7, currentIntervalDays: 7,
        updatedHlc: '0-0-d', deviceId: 'd'));
  });
  tearDown(() => db.close());

  test('plant / reminder events get the plant name; deleted rows still named; other tenants and named events untouched', () async {
    final events = [
      ev(1, entity: 'plants', entityId: 'p-1', kind: ActivityKind.updated, name: null),
      ev(2, entity: 'care_schedules', entityId: 's-1', kind: ActivityKind.updated, name: null),
      ev(3, entity: 'plants', entityId: 'p-gone', kind: ActivityKind.deleted, name: null),
      ev(4, entity: 'plants', entityId: 'p-other', name: null),
      ev(5, entity: 'plants', entityId: 'p-1', name: 'Server name'),
    ];
    final names = await resolveActivityNames(db, 'col-2', events);
    expect(names[activityNameKey('plants', 'p-1')], 'Monstera');
    expect(names[activityNameKey('care_schedules', 's-1')], 'Monstera');
    expect(names[activityNameKey('plants', 'p-gone')], 'Old fern');
    expect(names.containsKey(activityNameKey('plants', 'p-other')), isFalse);

    final en = AppLocalizationsEn();
    expect(describeActivityEvent(en, events[0], localName: names[activityNameKey('plants', 'p-1')]), 'maria edited Monstera');
    expect(describeActivityEvent(en, events[1], localName: 'Monstera'), 'maria edited a reminder for Monstera');
    expect(describeActivityEvent(en, events[4], localName: 'Local'), 'maria added Server name', reason: 'server name wins');
  });
}
