import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;

/// One dummy row per table, satisfying every `requiredDuringInsert` column
/// with a type-appropriate value, so the migration test covers the whole
/// schema without hand-written companions (a new table can't be missed).
Future<void> insertDummy(AppDatabase db, TableInfo<Table, dynamic> table, String tenant, {String suffix = ''}) async {
  final cols = table.$columns.where((c) => c.requiredDuringInsert || c.name == 'tenant_id').toList();
  Variable<Object> value(GeneratedColumn c) {
    if (c.name == 'tenant_id') return Variable<String>(tenant);
    return switch (c.type) {
      DriftSqlType.string => Variable<String>('${c.name}-$suffix'),
      DriftSqlType.int || DriftSqlType.bigInt => const Variable<int>(1),
      DriftSqlType.bool => const Variable<bool>(false),
      DriftSqlType.double => const Variable<double>(1.0),
      _ => Variable<String>('${c.name}-$suffix'),
    };
  }

  await db.customInsert(
    'INSERT INTO ${table.actualTableName} (${cols.map((c) => c.name).join(', ')}) '
    'VALUES (${List.filled(cols.length, '?').join(', ')})',
    variables: cols.map(value).toList(),
    updates: {table},
  );
}

Future<int> countTenant(AppDatabase db, TableInfo<Table, dynamic> table, String tenant) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS n FROM ${table.actualTableName} WHERE tenant_id = ?', variables: [Variable(tenant)])
      .getSingle();
  return row.read<int>('n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('migrateTenant', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('every table carries tenant_id (schema invariant the migration relies on)', () {
      final tenantTables = db.allTables.where((t) => t.columnsByName.containsKey('tenant_id')).map((t) => t.actualTableName);
      expect(tenantTables, containsAll(['species', 'locations', 'plants', 'photos', 'plant_photos', 'location_photos', 'tags', 'plant_tags', 'care_events', 'care_schedules', 'inventory_transactions', 'sync_ops']));
      expect(tenantTables.length, db.allTables.length, reason: 'a table without tenant_id would be skipped by the migration');
    });

    test('rewrites tenant_id in every entity table + sync_ops in one go; idempotent on re-run', () async {
      final tables = db.allTables.toList();
      for (final t in tables) {
        await insertDummy(db, t, 'local', suffix: 'a');
        await insertDummy(db, t, 'other', suffix: 'b');
      }
      final rewritten = await migrateTenant(db, from: 'local', to: 'col-1');
      expect(rewritten, tables.length);
      for (final t in tables) {
        expect(await countTenant(db, t, 'local'), 0, reason: '${t.actualTableName} still has local rows');
        expect(await countTenant(db, t, 'col-1'), 1, reason: '${t.actualTableName} missing migrated row');
        expect(await countTenant(db, t, 'other'), 1, reason: '${t.actualTableName}: foreign tenant must be untouched');
      }
      // sync_ops explicitly: the pending ops must survive under the new tenant.
      final ops = await db.select(db.syncOps).get();
      expect(ops.where((o) => o.tenantId == 'col-1'), hasLength(1));
      expect(ops.where((o) => o.tenantId == 'col-1').single.pushedAt, isNull);

      expect(await migrateTenant(db, from: 'local', to: 'col-1'), 0);
      expect(await migrateTenant(db, from: 'col-1', to: 'col-1'), 0);
      for (final t in tables) {
        expect(await countTenant(db, t, 'col-1'), 1);
      }
    });

    test('the plants FTS shadow follows the rename (search stays scoped)', () async {
      await insertDummy(db, db.plants, 'local');
      await migrateTenant(db, from: 'local', to: 'col-1');
      final fts = await db.customSelect("SELECT tenant_id FROM plants_fts").get();
      expect(fts.map((r) => r.read<String>('tenant_id')), ['col-1']);
    });
  });

  group('CollectionLinkService', () {
    final token = fakeJwt(
      iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
    );
    late int creates;
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      creates = 0;
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() => db.close());

    ProviderContainer make({String? storedToken}) {
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(storedToken)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              if (req.method == 'POST' && req.url.path.endsWith('/inventory/collections/default')) {
                expect(req.headers['Authorization'], 'Bearer $token');
                expect(req.headers['X-Plantly-Client'], startsWith('inventory/'));
                creates++;
                return http.Response(
                  json.encode({
                    'collection': {'id': 'col-1', 'name': 'My plants', 'role': 'owner', 'created_at': '2026-09-27T10:00:00Z'},
                  }),
                  200,
                );
              }
              return http.Response('{"error":"nope"}', 404);
            })),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('link(): default collection → tenant migration (incl. sync_ops) → prefs → tenant provider flips; unlink keeps data', () async {
      final c = make(storedToken: token);
      final ctx = await c.read(appContextProvider.future);
      expect(ctx.tenantId, kDefaultTenantId);
      final seededPlants = await db.managers.plants.count();
      expect(seededPlants, greaterThan(0));
      final pendingBefore = await ctx.opLog.pendingCount();
      expect(pendingBefore, greaterThan(0));

      final link = await c.read(collectionLinkProvider.notifier).link();
      expect(link, const CollectionLink(id: 'col-1', name: 'My plants', userId: 'u-1', username: 'alice'));
      expect(creates, 1);
      expect(c.read(currentTenantIdProvider), 'col-1');
      expect(c.read(collectionLinkProvider).link, link);
      expect(c.read(collectionLinkProvider).unlinkedByUser, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kTenantIdPrefKey), 'col-1');
      expect(prefs.getString(kCollectionIdPrefKey), 'col-1');
      expect(prefs.getString(kCollectionNamePrefKey), 'My plants');
      expect(prefs.getString(kCollectionUserIdPrefKey), 'u-1');
      expect(prefs.getString(kCollectionUsernamePrefKey), 'alice');

      expect(await countTenant(db, db.plants, 'local'), 0);
      expect(await countTenant(db, db.plants, 'col-1'), seededPlants);
      expect(await countTenant(db, db.syncOps, 'local'), 0);
      expect(await countTenant(db, db.syncOps, 'col-1'), pendingBefore);

      // The app context rebuilt under the new tenant — and did NOT re-seed.
      final ctx2 = await c.read(appContextProvider.future);
      expect(ctx2.tenantId, 'col-1');
      expect(ctx2.opLog.tenantId, 'col-1');
      expect(await db.managers.plants.count(), seededPlants);
      expect(await ctx2.opLog.pendingCount(), pendingBefore);
      expect(identical(ctx2.clock, ctx.clock), isTrue, reason: 'HLC clock survives the flip');

      // Re-link is a no-op migration (same collection).
      await c.read(collectionLinkProvider.notifier).ensureLinked();
      expect(creates, 1);

      await c.read(collectionLinkProvider.notifier).unlink();
      expect(c.read(collectionLinkProvider).link, isNull);
      expect(c.read(collectionLinkProvider).unlinkedByUser, isTrue);
      expect(prefs.getBool(kCloudUnlinkedPrefKey), isTrue);
      expect(c.read(currentTenantIdProvider), 'col-1', reason: 'unlink never renames back');
      expect(prefs.getString(kTenantIdPrefKey), 'col-1');
      expect(prefs.getString(kCollectionIdPrefKey), isNull);
      expect(await countTenant(db, db.plants, 'col-1'), seededPlants);

      // Linking again (user asked) clears the unlinked flag; same collection → no migration.
      await c.read(collectionLinkProvider.notifier).link();
      expect(c.read(collectionLinkProvider).unlinkedByUser, isFalse);
      expect(prefs.getBool(kCloudUnlinkedPrefKey), isNull);
      expect(c.read(currentTenantIdProvider), 'col-1');
    });

    Future<ProviderContainer> heldByOther() async {
      SharedPreferences.setMockInitialValues({
        kTenantIdPrefKey: 'col-other',
        kCollectionIdPrefKey: 'col-other',
        kCollectionNamePrefKey: 'Theirs',
        kCollectionUserIdPrefKey: 'u-other',
        kCollectionUsernamePrefKey: 'bob',
      });
      final c = make(storedToken: token);
      await c.read(appContextProvider.future); // seeds under col-other (A's data)
      expect(await countTenant(db, db.plants, 'col-other'), greaterThan(0));
      return c;
    }

    test('account switch, no decision: ensureLinked() links nothing and touches nothing', () async {
      final c = await heldByOther();
      final plantsA = await countTenant(db, db.plants, 'col-other');
      expect(await c.read(collectionLinkProvider.notifier).ensureLinked(), isNull);
      expect(creates, 0);
      expect(c.read(currentTenantIdProvider), 'col-other');
      expect(await countTenant(db, db.plants, 'col-other'), plantsA);
      expect(c.read(collectionLinkProvider).link?.accountLabel, 'bob');
    });

    test('account switch, "Move": link() migrates the rows into the new account\'s collection', () async {
      final c = await heldByOther();
      final plantsA = await countTenant(db, db.plants, 'col-other');
      final link = await c.read(collectionLinkProvider.notifier).link();
      expect(link.id, 'col-1');
      expect(link.userId, 'u-1');
      expect(link.username, 'alice');
      expect(creates, 1);
      expect(await countTenant(db, db.plants, 'col-other'), 0);
      expect(await countTenant(db, db.plants, 'col-1'), plantsA);
      expect(c.read(currentTenantIdProvider), 'col-1');
    });

    test('account switch, "Start empty": fresh tenant, A\'s rows untouched and invisible, no demo seed', () async {
      final c = await heldByOther();
      final plantsA = await countTenant(db, db.plants, 'col-other');
      final opsA = await countTenant(db, db.syncOps, 'col-other');
      final link = await c.read(collectionLinkProvider.notifier).startEmpty();
      expect(link.id, 'col-1');
      expect(creates, 1);
      // The tenant differs from A's, so no pull can ever land in A's rows.
      expect(c.read(currentTenantIdProvider), 'col-1');
      expect(c.read(currentTenantIdProvider), isNot('col-other'));
      expect(await countTenant(db, db.plants, 'col-other'), plantsA, reason: "A's rows stay on disk");
      expect(await countTenant(db, db.syncOps, 'col-other'), opsA, reason: "A's pending ops stay parked");
      // Nothing was migrated and the seed stayed off for the empty tenant.
      final ctx = await c.read(appContextProvider.future);
      expect(ctx.tenantId, 'col-1');
      expect(await countTenant(db, db.plants, 'col-1'), 0);
      expect(await countTenant(db, db.locations, 'col-1'), 0);
      expect(await ctx.opLog.pendingCount(), 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kSkipSeedPrefKey), isTrue);
      expect(prefs.getString(kTenantIdPrefKey), 'col-1');
      expect(prefs.getString(kCollectionUserIdPrefKey), 'u-1');
      // Recovery path: relinking A's collection id makes A's rows visible again.
      await migrateTenant(db, from: 'col-1', to: 'col-other');
      expect(await countTenant(db, db.plants, 'col-other'), plantsA);
    });

    test('a fresh container boots straight into the persisted tenant + link', () async {
      SharedPreferences.setMockInitialValues({
        kTenantIdPrefKey: 'col-1',
        kCollectionIdPrefKey: 'col-1',
        kCollectionNamePrefKey: 'My plants',
        kCollectionUserIdPrefKey: 'u-1',
      });
      final c = make(storedToken: token);
      final ctx = await c.read(appContextProvider.future);
      expect(ctx.tenantId, 'col-1');
      expect(c.read(currentTenantIdProvider), 'col-1');
      expect(await countTenant(db, db.plants, 'local'), 0, reason: 'seed must land under the persisted tenant');
      final links = c.read(collectionLinkProvider.notifier);
      await links.ready;
      expect(c.read(collectionLinkProvider).link, const CollectionLink(id: 'col-1', name: 'My plants', userId: 'u-1'));
    });

    test('link() when signed out throws and touches nothing', () async {
      final c = make(storedToken: null);
      await c.read(appContextProvider.future);
      await expectLater(c.read(collectionLinkProvider.notifier).link(), throwsStateError);
      expect(creates, 0);
      expect(c.read(currentTenantIdProvider), kDefaultTenantId);
    });
  });
}
