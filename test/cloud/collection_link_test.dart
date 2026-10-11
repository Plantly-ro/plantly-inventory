import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/data/seed_manifest.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/sync/http_sync_runner.dart';
import 'package:plantly_inventory/sync/op_log.dart';
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

/// A plant created through the op log under [opLog]'s tenant (pending op).
Future<void> userPlant(OpLogWriter opLog, String id) async {
  final h = await opLog.recordCreate(entity: 'plants', entityId: id, value: {'id': id, 'nickname': id, 'status': 'alive'});
  await opLog.db.into(opLog.db.plants).insert(PlantsCompanion.insert(
        id: id,
        tenantId: opLog.tenantId,
        nickname: id,
        status: 'alive',
        updatedHlc: h.encode(),
        deviceId: opLog.clock.deviceId,
      ));
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

  group('migrateTenant — photos keyed (tenant_id, sha256)', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> photo(String tenant, String sha, String state) => db.into(db.photos).insert(PhotosCompanion.insert(
        sha256: sha, tenantId: tenant, mime: 'image/jpeg', bytes: 1, updatedHlc: 'h-$tenant', deviceId: 'd', remoteState: Value(state)));

    test('a sha already held by the target tenant keeps that row; the source duplicate is dropped', () async {
      await photo('local', 'shared-sha', 'local');
      await photo('local', 'only-local', 'local');
      await photo('col-1', 'shared-sha', 'remote');
      await migrateTenant(db, from: 'local', to: 'col-1');
      final rows = await db.select(db.photos).get();
      expect({for (final r in rows) r.sha256: (r.tenantId, r.remoteState)}, {
        'shared-sha': ('col-1', 'remote'),
        'only-local': ('col-1', 'local'),
      });
      expect(rows, hasLength(2));
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

    test('link(): default collection → tenant migration → prefs → tenant provider flips; unlink keeps data', () async {
      final c = make(storedToken: token);
      final ctx = await c.read(appContextProvider.future);
      expect(ctx.tenantId, kDefaultTenantId);
      expect(await db.managers.plants.count(), 8, reason: 'demo seed on a fresh install');
      // The user's own plant + one demo plant they renamed: both theirs now.
      await userPlant(ctx.opLog, 'mine');
      final renamed = (await db.select(db.plants).get()).firstWhere((p) => p.id != 'mine');
      await ctx.opLog.recordFieldUpdate(entity: 'plants', entityId: renamed.id, field: 'nickname', value: 'Bobby');
      const seededPlants = 2; // the 7 untouched demo plants never reach the collection
      expect(await ctx.opLog.pendingCount(), greaterThan(0));

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
      expect({for (final p in await db.select(db.plants).get()) p.id}, {'mine', renamed.id});
      expect(await countTenant(db, db.plants, 'col-1'), seededPlants);
      expect(await countTenant(db, db.locations, 'col-1'), 0, reason: 'untouched demo spaces dropped too');
      expect(await countTenant(db, db.syncOps, 'local'), 0);
      // The local op log is discarded: the runner re-synthesizes one `*`
      // per live row for the collection (see the "Move" tests).
      expect(await countTenant(db, db.syncOps, 'col-1'), 0);
      expect(prefs.getBool(kSkipSeedPrefKey), isTrue);
      expect(prefs.getString(kSeedManifestPrefKey), isNull);

      // The app context rebuilt under the new tenant — and did NOT re-seed.
      final ctx2 = await c.read(appContextProvider.future);
      expect(ctx2.tenantId, 'col-1');
      expect(ctx2.opLog.tenantId, 'col-1');
      expect(await db.managers.plants.count(), seededPlants);
      expect(await countTenant(db, db.locations, 'col-1'), 0, reason: 'never seeds a collection tenant');
      expect(identical(ctx2.clock, ctx.clock), isTrue, reason: 'HLC clock survives the flip');
      await synthesizeInitialOps(db: db, opLog: ctx2.opLog, deviceId: ctx2.deviceId);
      expect(await ctx2.opLog.pendingCount(), seededPlants + 1, reason: '2 plants + the kept demo plant\'s schedule');

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
      final ctx = await c.read(appContextProvider.future);
      // A's synced collection: three plants, their ops already pushed.
      final aLog = OpLogWriter(db: db, clock: ctx.clock, tenantId: 'col-other', currentUserId: () => 'u-other');
      for (final id in ['a1', 'a2', 'a3']) {
        await userPlant(aLog, id);
      }
      await db.customStatement("UPDATE sync_ops SET pushed_at = 1 WHERE tenant_id = 'col-other'");
      expect(await countTenant(db, db.plants, 'col-other'), 3);
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

    test('data-owner marker: A links → unlinks → B signs in: no auto-link; "Start empty" keeps A\'s rows, marker = B', () async {
      final bobToken = fakeJwt(
        iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
        exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
        username: 'bob',
        userId: 'u-2',
      );
      // Same shape as make(), but the default collection depends on who asks.
      final c = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              if (req.method == 'POST' && req.url.path.endsWith('/inventory/collections/default')) {
                creates++;
                final bob = req.headers['Authorization'] == 'Bearer $bobToken';
                return http.Response(
                  json.encode({
                    'collection': {'id': bob ? 'col-2' : 'col-1', 'name': bob ? 'Bob' : 'My plants', 'role': 'owner'},
                  }),
                  200,
                );
              }
              return http.Response('{"error":"nope"}', 404);
            })),
      ]);
      addTearDown(c.dispose);
      final ctx = await c.read(appContextProvider.future); // seeds the demo data under 'local'
      await userPlant(ctx.opLog, 'alices-plant'); // ...and A adds a plant of their own
      final links = c.read(collectionLinkProvider.notifier);
      final prefs = await SharedPreferences.getInstance();

      // A links, then unlinks: the link is gone, the marker is not.
      await links.link();
      expect(c.read(collectionLinkProvider).dataOwnerUserId, 'u-1');
      expect(prefs.getString(kDataOwnerUserIdPrefKey), 'u-1');
      expect(prefs.getString(kDataOwnerUsernamePrefKey), 'alice');
      await links.unlink();
      expect(c.read(collectionLinkProvider).link, isNull);
      expect(c.read(collectionLinkProvider).dataOwnerUserId, 'u-1', reason: 'unlink never clears the marker');
      expect(prefs.getString(kDataOwnerUserIdPrefKey), 'u-1');
      final plantsA = await countTenant(db, db.plants, 'col-1');
      expect(plantsA, greaterThan(0));

      // B signs in: nothing links, nothing moves — B must decide.
      await c.read(plantlyAuthProvider.notifier).adoptToken(bobToken);
      expect(c.read(collectionLinkProvider).dataHeldByOther('u-2'), isTrue);
      expect(c.read(collectionLinkProvider).dataOwnerLabel, 'alice');
      expect(await links.ensureLinked(), isNull);
      expect(creates, 1);
      expect(c.read(currentTenantIdProvider), 'col-1');
      expect(await countTenant(db, db.plants, 'col-1'), plantsA);

      // B: "Start empty" → fresh tenant linked to B's collection; A's rows parked; marker = B.
      final link = await links.startEmpty();
      expect(link.id, 'col-2');
      expect(link.userId, 'u-2');
      expect(creates, 2);
      expect(c.read(currentTenantIdProvider), 'col-2');
      expect(await countTenant(db, db.plants, 'col-1'), plantsA, reason: "A's rows untouched");
      expect(await countTenant(db, db.plants, 'col-2'), 0);
      expect(c.read(collectionLinkProvider).dataOwnerUserId, 'u-2');
      expect(c.read(collectionLinkProvider).dataOwnerUsername, 'bob');
      expect(prefs.getString(kDataOwnerUserIdPrefKey), 'u-2');
      expect(prefs.getString(kDataOwnerUsernamePrefKey), 'bob');
      expect(c.read(collectionLinkProvider).dataHeldByOther('u-2'), isFalse);
      expect(c.read(collectionLinkProvider).dataHeldByOther('u-1'), isTrue, reason: 'now A is the one who must decide');
      // B is linked for B → ensureLinked is a no-op.
      expect(await links.ensureLinked(), link);
      expect(creates, 2);
    });

    ProviderContainer twoAccounts(String bobToken, {bool web = false}) {
      final c = ProviderContainer(overrides: [
        cloudEnabledProvider.overrideWithValue(true),
        if (web) webPlatformProvider.overrideWithValue(true),
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              if (req.method == 'POST' && req.url.path.endsWith('/inventory/collections/default')) {
                creates++;
                final bob = req.headers['Authorization'] == 'Bearer $bobToken';
                return http.Response(
                  json.encode({
                    'collection': {'id': bob ? 'col-2' : 'col-1', 'name': bob ? 'Bob' : 'My plants', 'role': 'owner'},
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

    String bobJwt() => fakeJwt(
          iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
          exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
          username: 'bob',
          userId: 'u-2',
        );

    /// A (alice) has plants in col-1; B (bob) signs in and picks "Start
    /// empty" → B's col-2 is linked, empty, and the data-owner marker is B.
    Future<(ProviderContainer, int)> switchedToEmptyBob(String bobToken, {bool web = false}) async {
      final c = twoAccounts(bobToken, web: web);
      final ctx = await c.read(appContextProvider.future);
      await userPlant(ctx.opLog, 'alices-plant');
      final links = c.read(collectionLinkProvider.notifier);
      await links.link();
      final plantsA = await countTenant(db, db.plants, 'col-1');
      await c.read(plantlyAuthProvider.notifier).adoptToken(bobToken);
      await links.startEmpty();
      expect(c.read(currentTenantIdProvider), 'col-2');
      expect(creates, 2);
      return (c, plantsA);
    }

    test('switching back to A when B\'s collection holds nothing: no Move/Start-empty question, A\'s plants come back (QA u26)', () async {
      final bobToken = bobJwt();
      final (c, plantsA) = await switchedToEmptyBob(bobToken);
      final links = c.read(collectionLinkProvider.notifier);
      // B deleted a plant they had added: only a tombstone (pushed) is left.
      final bobCtx = await c.read(appContextProvider.future);
      await userPlant(bobCtx.opLog, 'bobs-gone');
      await (db.update(db.plants)..where((p) => p.id.equals('bobs-gone'))).write(const PlantsCompanion(deletedAt: Value(1)));
      await db.customStatement("UPDATE sync_ops SET pushed_at = 1 WHERE tenant_id = 'col-2'");

      await c.read(plantlyAuthProvider.notifier).adoptToken(token); // A again
      expect(await links.releaseEmptyForeignClaims('u-1'), isTrue);
      expect(c.read(collectionLinkProvider).heldByOtherLabel('u-1'), isNull);
      expect(c.read(cloudStateProvider).heldByOther, isNull, reason: 'nothing of bob\'s is visible here — no prompt');

      final link = await links.ensureLinked();
      expect(link?.id, 'col-1');
      expect(link?.userId, 'u-1');
      expect(c.read(currentTenantIdProvider), 'col-1');
      expect(await countTenant(db, db.plants, 'col-1'), plantsA, reason: "A's parked plants are back");
      expect(await countTenant(db, db.plants, 'col-2'), 1, reason: "B's leftovers stay parked under B's tenant");
      expect(c.read(collectionLinkProvider).dataOwnerUserId, 'u-1');
    });

    test('B\'s collection still holds a live plant (or unpushed ops): the decision stands', () async {
      final bobToken = bobJwt();
      final (c, _) = await switchedToEmptyBob(bobToken);
      final links = c.read(collectionLinkProvider.notifier);
      final bobCtx = await c.read(appContextProvider.future);
      await userPlant(bobCtx.opLog, 'bobs-plant'); // live row + pending op
      await c.read(plantlyAuthProvider.notifier).adoptToken(token);
      expect(await links.releaseEmptyForeignClaims('u-1'), isFalse);
      expect(c.read(cloudStateProvider).heldByOther, 'bob');
      expect(await links.ensureLinked(), isNull);

      // Plant gone but its ops never reached the server: still B's to push.
      await (db.update(db.plants)..where((p) => p.id.equals('bobs-plant'))).write(const PlantsCompanion(deletedAt: Value(1)));
      expect(await links.releaseEmptyForeignClaims('u-1'), isFalse);
      expect(c.read(cloudStateProvider).heldByOther, 'bob');
      expect(c.read(currentTenantIdProvider), 'col-2');
    });

    test('release refuses over a live tag, or over the other account\'s unpushed ops in ANY tenant', () async {
      final (c, _) = await switchedToEmptyBob(bobJwt());
      final links = c.read(collectionLinkProvider.notifier);
      await insertDummy(db, db.tags, 'col-2');
      await c.read(plantlyAuthProvider.notifier).adoptToken(token);
      expect(await links.releaseEmptyForeignClaims('u-1'), isFalse, reason: 'a live tag is data');
      await db.customStatement("UPDATE tags SET deleted_at = 1 WHERE tenant_id = 'col-2'");
      // An unpushed op of bob parked in some other tenant.
      await db.into(db.syncOps).insert(SyncOpsCompanion.insert(
          tenantId: 'col-bob-old', entity: 'plants', entityId: 'x', field: 'nickname', hlc: 'h', deviceId: 'd',
          userId: const Value('u-2')));
      expect(await links.releaseEmptyForeignClaims('u-1'), isFalse, reason: "bob's pending work elsewhere");
      await db.customStatement("UPDATE sync_ops SET pushed_at = 1 WHERE tenant_id = 'col-bob-old'");
      expect(await links.releaseEmptyForeignClaims('u-1'), isTrue);
    });

    test('release clears a sticky "unlinked by user" and, on web, deletes the released tenant\'s leftovers', () async {
      final (c, _) = await switchedToEmptyBob(bobJwt(), web: true);
      final links = c.read(collectionLinkProvider.notifier);
      final bobCtx = await c.read(appContextProvider.future);
      await userPlant(bobCtx.opLog, 'bobs-gone');
      await (db.update(db.plants)..where((p) => p.id.equals('bobs-gone'))).write(const PlantsCompanion(deletedAt: Value(1)));
      await db.customStatement("UPDATE sync_ops SET pushed_at = 1");
      await links.unlink();
      expect(c.read(collectionLinkProvider).unlinkedByUser, isTrue);
      await c.read(plantlyAuthProvider.notifier).adoptToken(token);
      expect(await links.releaseEmptyForeignClaims('u-1'), isTrue);
      expect(c.read(collectionLinkProvider).unlinkedByUser, isFalse);
      expect((await SharedPreferences.getInstance()).getBool(kCloudUnlinkedPrefKey), isNull);
      expect(await countTenant(db, db.plants, 'col-2'), 0, reason: "web: bob's leftovers don't stay in alice's browser");
      expect(await countTenant(db, db.syncOps, 'col-2'), 0);
    });

    test('REVIEW repro: B parked on an empty non-home tenant while B\'s home holds live plants + unpushed ops — must NOT release', () async {
      final bobToken = bobJwt();
      final (c, _) = await switchedToEmptyBob(bobToken);
      final links = c.read(collectionLinkProvider.notifier);
      final bobCtx = await c.read(appContextProvider.future);
      await userPlant(bobCtx.opLog, 'bobs-plant'); // live + pending under col-2 (B's home)
      // B switches to an (empty) owned / shared collection; sign-out keeps an owned one active.
      final p = await SharedPreferences.getInstance();
      await p.setString(kTenantIdPrefKey, 'col-office');
      c.read(currentTenantIdProvider.notifier).state = 'col-office';
      await c.read(plantlyAuthProvider.notifier).adoptToken(token); // A signs in
      expect(await links.releaseEmptyForeignClaims('u-1'), isFalse, reason: "B's home col-2 still holds B's data");
      expect(c.read(cloudStateProvider).heldByOther, 'bob');
    });

    test('data-owner marker on an empty tenant is dropped at load (fresh device / wiped data)', () async {
      SharedPreferences.setMockInitialValues({
        kTenantIdPrefKey: 'col-9',
        kSkipSeedPrefKey: true,
        kDataOwnerUserIdPrefKey: 'u-other',
        kDataOwnerUsernamePrefKey: 'bob',
      });
      final c = make(storedToken: token);
      await c.read(collectionLinkProvider.notifier).ready;
      final st = c.read(collectionLinkProvider);
      expect(st.dataOwnerUserId, isNull);
      expect(st.dataOwnerLabel, isNull);
      expect(st.dataHeldByOther('u-1'), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kDataOwnerUserIdPrefKey), isNull);
      expect(prefs.getString(kDataOwnerUsernamePrefKey), isNull);
      // ...and with a single row under the tenant the marker stands.
      SharedPreferences.setMockInitialValues({
        kTenantIdPrefKey: 'col-9',
        kSkipSeedPrefKey: true,
        kDataOwnerUserIdPrefKey: 'u-other',
        kDataOwnerUsernamePrefKey: 'bob',
      });
      await insertDummy(db, db.plants, 'col-9');
      final c2 = make(storedToken: token);
      await c2.read(collectionLinkProvider.notifier).ready;
      expect(c2.read(collectionLinkProvider).dataOwnerUserId, 'u-other');
      expect(c2.read(collectionLinkProvider).dataOwnerLabel, 'bob');
      expect(await c2.read(collectionLinkProvider.notifier).ensureLinked(), isNull);
      expect(creates, 0);
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
      expect(await countTenant(db, db.plants, 'local'), 0, reason: 'no seed under a stale local tenant');
      expect(await countTenant(db, db.plants, 'col-1'), 0, reason: 'and never into a collection tenant');
      expect(await countTenant(db, db.locations, 'col-1'), 0);
      final links = c.read(collectionLinkProvider.notifier);
      await links.ready;
      expect(c.read(collectionLinkProvider).link, const CollectionLink(id: 'col-1', name: 'My plants', userId: 'u-1'));
    });

    test('"Move to me" after A synced: A\'s op log is discarded; the runner re-uploads every live row for B', () async {
      final c = await heldByOther();
      final ctx = await c.read(appContextProvider.future);
      // A also left a pending edit (stamped u-other: B's engine would skip
      // it forever), a deleted plant, a synced photo and a rejection.
      final aLog = OpLogWriter(db: db, clock: ctx.clock, tenantId: 'col-other', currentUserId: () => 'u-other');
      await aLog.recordFieldUpdate(entity: 'plants', entityId: 'a1', field: 'nickname', value: 'A1 renamed');
      await userPlant(aLog, 'a-gone');
      await (db.update(db.plants)..where((p) => p.id.equals('a-gone'))).write(const PlantsCompanion(deletedAt: Value(5)));
      await db.into(db.photos).insert(PhotosCompanion.insert(
            sha256: 'sha-1',
            tenantId: 'col-other',
            mime: 'image/jpeg',
            bytes: 3,
            remoteState: const Value('synced'),
            updatedHlc: ctx.clock.now().encode(),
            deviceId: 'dev-a',
          ));
      await insertDummy(db, db.syncRejections, 'col-other');
      // ...and a photo pulled from A's cloud whose blob never came down,
      // attached to a1 and used as a care-event photo.
      await db.into(db.photos).insert(PhotosCompanion.insert(
            sha256: 'sha-remote',
            tenantId: 'col-other',
            mime: 'image/jpeg',
            bytes: 3,
            remoteState: const Value('remote'),
            updatedHlc: ctx.clock.now().encode(),
            deviceId: 'dev-b',
          ));
      await db.into(db.plantPhotos).insert(PlantPhotosCompanion.insert(
            id: 'pp-1',
            tenantId: 'col-other',
            plantId: 'a1',
            photoSha: 'sha-remote',
            addedHlc: ctx.clock.now().encode(),
            deviceId: 'dev-b',
          ));
      await db.into(db.careEvents).insert(CareEventsCompanion.insert(
            id: 'ev-1',
            tenantId: 'col-other',
            plantId: 'a1',
            type: 'water',
            doneAt: 1,
            photoSha: const Value('sha-remote'),
            updatedHlc: ctx.clock.now().encode(),
            deviceId: 'dev-b',
          ));

      await c.read(collectionLinkProvider.notifier).link();
      expect(await countTenant(db, db.syncOps, 'col-1'), 0);
      expect(await countTenant(db, db.syncRejections, 'col-1'), 0);
      expect((await db.select(db.photos).getSingle()).remoteState, 'local', reason: 'the blob must upload to B too');
      expect(await db.select(db.plantPhotos).get(), isEmpty, reason: 'unreachable remote photo dropped with its link');
      expect((await db.select(db.careEvents).getSingle()).photoSha, isNull);

      // B's runner: initial upload covers every live row, stamped for B.
      final bLog = OpLogWriter(db: db, clock: ctx.clock, tenantId: 'col-1', currentUserId: () => 'u-1');
      await synthesizeInitialOps(db: db, opLog: bLog, deviceId: ctx.deviceId);
      final ops = await (db.select(db.syncOps)..where((o) => o.tenantId.equals('col-1'))).get();
      expect(
        {for (final o in ops) '${o.entity}/${o.entityId}'},
        {'plants/a1', 'plants/a2', 'plants/a3', 'photos/sha-1', 'care_events/ev-1'},
        reason: 'live rows only — a fresh collection needs no tombstones',
      );
      expect(ops.every((o) => o.field == '*' && o.pushedAt == null && o.userId == 'u-1'), isTrue);
      final a1 = ops.firstWhere((o) => o.entityId == 'a1');
      expect(json.decode(a1.valueJson!)['nickname'], 'a1', reason: 'the row as it stands');
    });

    test('a re-created home (deleted / purged → new id) gets everything re-uploaded too', () async {
      SharedPreferences.setMockInitialValues({
        kTenantIdPrefKey: 'col-old',
        kCollectionIdPrefKey: 'col-old',
        kCollectionNamePrefKey: 'My plants',
        kCollectionUserIdPrefKey: 'u-1',
        kCollectionUsernamePrefKey: 'alice',
        kSkipSeedPrefKey: true,
      });
      final c = make(storedToken: token);
      final ctx = await c.read(appContextProvider.future);
      await userPlant(ctx.opLog, 'p1');
      await db.customStatement("UPDATE sync_ops SET pushed_at = 1 WHERE tenant_id = 'col-old'");
      final link = await c.read(collectionLinkProvider.notifier).link(); // server now answers col-1
      expect(link.id, 'col-1');
      expect(await countTenant(db, db.plants, 'col-1'), 1);
      expect(await countTenant(db, db.syncOps, 'col-1'), 0, reason: 'the pushed history belonged to col-old');
    });

    test('re-linking the SAME collection keeps the op log (pushed history and pending ops)', () async {
      SharedPreferences.setMockInitialValues({kTenantIdPrefKey: 'col-1', kSkipSeedPrefKey: true});
      final c = make(storedToken: token);
      final ctx = await c.read(appContextProvider.future);
      await userPlant(ctx.opLog, 'p1');
      await userPlant(ctx.opLog, 'p2');
      await db.customStatement("UPDATE sync_ops SET pushed_at = 1 WHERE entity_id = 'p1'");
      await c.read(collectionLinkProvider.notifier).link();
      final ops = await db.select(db.syncOps).get();
      expect(ops.map((o) => (o.entityId, o.pushedAt)), [('p1', 1), ('p2', null)]);
    });

    test('never seeds a collection tenant, nor on web', () async {
      SharedPreferences.setMockInitialValues({kTenantIdPrefKey: 'col-1'});
      final c = make(storedToken: token);
      await c.read(appContextProvider.future);
      expect(await db.select(db.plants).get(), isEmpty);
      expect(await db.select(db.locations).get(), isEmpty, reason: 'an empty locations table used to get demo spaces');

      SharedPreferences.setMockInitialValues({});
      final web = ProviderContainer(overrides: [
        databaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(null)),
        webPlatformProvider.overrideWithValue(true),
      ]);
      addTearDown(web.dispose);
      final ctx = await web.read(appContextProvider.future);
      expect(ctx.tenantId, kDefaultTenantId);
      expect(await db.select(db.plants).get(), isEmpty, reason: 'web is cloud-only: no demo plants');
      expect(await db.select(db.syncOps).get(), isEmpty);
    });

    test('a fresh install that signs in straight away links an empty tenant: nothing demo is uploaded', () async {
      final c = make(storedToken: token);
      final ctx = await c.read(appContextProvider.future);
      expect(await countTenant(db, db.plants, 'local'), 8);
      await c.read(collectionLinkProvider.notifier).link();
      final ctx2 = await c.read(appContextProvider.future);
      await synthesizeInitialOps(db: db, opLog: ctx2.opLog, deviceId: ctx.deviceId);
      expect(await db.select(db.plants).get(), isEmpty);
      expect(await db.select(db.locations).get(), isEmpty);
      expect(await db.select(db.careSchedules).get(), isEmpty);
      expect(await db.select(db.syncOps).get(), isEmpty, reason: 'nothing to push');
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
