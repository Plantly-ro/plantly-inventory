import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;

/// MULTI-USER-V2 §0: pulling the members list clears assignments whose
/// assignee is no longer a member — as a local op, so it syncs. Only after
/// a SUCCESSFUL fetch for the repository's own tenant, when the list is
/// non-empty, names the signed-in account and that account may edit; the
/// cache path never clears.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final aliceToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400); // user id u-1

  late AppDatabase db;
  late ProviderContainer container;
  late bool membersDown;
  late int memberFetches;
  late List<Map<String, dynamic>> members;

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  setUp(() {
    SharedPreferences.setMockInitialValues({kSkipSeedPrefKey: true, kTenantIdPrefKey: 'col-2'});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    membersDown = false;
    memberFetches = 0;
    members = [
      {'user_id': 'u-2', 'username': 'bob', 'role': 'owner'},
      {'user_id': 'u-1', 'username': 'alice', 'role': 'editor'},
    ];
    container = ProviderContainer(overrides: [
      cloudEnabledProvider.overrideWithValue(true),
      databaseProvider.overrideWithValue(db),
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore(aliceToken)),
      notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
      photoBlobStoreProvider.overrideWithValue(InMemoryPhotoBlobStore()),
      collectionsRefreshIntervalProvider.overrideWithValue(Duration.zero),
      httpClientProvider.overrideWith((_) => MockClient((req) async {
            final path = req.url.path;
            if (req.method == 'GET' && path.endsWith('/members')) {
              memberFetches++;
              if (membersDown) return jsonRes({'error': 'down'}, 503);
              return jsonRes({'members': members});
            }
            if (req.method == 'GET' && path.endsWith('/inventory/collections')) {
              return jsonRes({
                'collections': [
                  {'id': 'col-2', 'name': 'Family', 'role': 'editor', 'owner_user_id': 'u-2', 'member_count': 2},
                ]
              });
            }
            return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
          })),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await db.close();
  });

  Future<String?> assigneeOf(String id) async =>
      (await (db.select(db.careSchedules)..where((r) => r.id.equals(id))).getSingle()).assigneeUserId;

  Future<List<SyncOpRow>> assigneeOps() async =>
      (await db.select(db.syncOps).get()).where((o) => o.field == 'assignee_user_id').toList();

  Future<(String keep, String stale)> seed() async {
    await container.read(appContextProvider.future);
    expect(container.read(currentTenantIdProvider), 'col-2');
    final plant = await container.read(plantRepositoryProvider).create(nickname: 'Fern');
    final repo = container.read(careScheduleRepositoryProvider);
    final keep = await repo.upsert(plantId: plant.id, type: 'water', baseIntervalDays: 7, assigneeUserId: 'u-2');
    final stale = await repo.upsert(plantId: plant.id, type: 'mist', baseIntervalDays: 2, assigneeUserId: 'u-9');
    expect(await assigneeOps(), isEmpty);
    return (keep.id, stale.id);
  }

  test('a successful members fetch of the active tenant clears assignments to removed members (pending null op)', () async {
    final (keep, stale) = await seed();
    // Signed in as alice (session store holds her token).
    expect(await container.read(plantlyAuthProvider.notifier).current(), isNotNull);

    final members = await container.read(membersProvider('col-2').future);
    expect(members.map((m) => m.userId), ['u-2', 'u-1']);

    // The sweep is fire-and-forget from the provider: poll for the write.
    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (await assigneeOf(stale) != null) {
      if (DateTime.now().isAfter(deadline)) fail('stale assignee was not cleared');
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(await assigneeOf(keep), 'u-2', reason: 'current member keeps the assignment');

    final ops = await assigneeOps();
    expect(ops, hasLength(1));
    expect(ops.single.entity, 'care_schedules');
    expect(ops.single.entityId, stale);
    expect(ops.single.valueJson, 'null');
    expect(ops.single.pushedAt, isNull, reason: 'local op, pending push');
    expect(ops.single.tenantId, 'col-2');
    expect(ops.single.userId, 'u-1', reason: 'attributed to the signed-in account');
  });

  test('the cache path (fetch failed) never clears anything', () async {
    final (_, stale) = await seed();
    // Prime the cache with a successful fetch that lists u-9 as a member.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${kMembersCachePrefPrefix}col-2',
        json.encode([{'user_id': 'u-2', 'username': 'bob', 'role': 'owner'}]));
    membersDown = true;
    final cached = await container.read(membersProvider('col-2').future);
    expect(cached.map((m) => m.userId), ['u-2']);
    expect(memberFetches, 1);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await assigneeOf(stale), 'u-9', reason: 'cache fallback is not authoritative');
    expect(await assigneeOps(), isEmpty);
  });

  Future<void> expectNothingCleared(String stale) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(await assigneeOf(stale), 'u-9');
    expect(await assigneeOps(), isEmpty);
  }

  test('members of another collection (not the repository tenant) are not applied', () async {
    final (_, stale) = await seed();
    expect(container.read(appContextProvider).requireValue.opLog.tenantId, 'col-2');
    await container.read(membersProvider('col-7').future);
    await expectNothingCleared(stale);
  });

  test('tenant pref flipped mid-switch but the repository is still bound to col-2 → col-7 members do not clear', () async {
    final (_, stale) = await seed();
    // The guard is the op log\'s tenant, not whatever the pref says right now.
    container.read(currentTenantIdProvider.notifier).state = 'col-7';
    expect(container.read(appContextProvider).requireValue.opLog.tenantId, 'col-2');
    await container.read(membersProvider('col-7').future);
    await expectNothingCleared(stale);
    expect(memberFetches, 1);
  });

  test('an EMPTY members list is not authoritative → nothing cleared', () async {
    final (_, stale) = await seed();
    members = [];
    final got = await container.read(membersProvider('col-2').future);
    expect(got, isEmpty);
    expect(memberFetches, 1);
    await expectNothingCleared(stale);
  });

  test('signed-in account is a VIEWER → no ops (the server would reject them as read_only)', () async {
    final (_, stale) = await seed();
    members = [
      {'user_id': 'u-2', 'username': 'bob', 'role': 'owner'},
      {'user_id': 'u-1', 'username': 'alice', 'role': 'viewer'},
    ];
    final got = await container.read(membersProvider('col-2').future);
    expect(got.map((m) => m.userId), ['u-2', 'u-1']);
    await expectNothingCleared(stale);
  });

  test('a list that does not name the signed-in account is not authoritative → nothing cleared', () async {
    final (_, stale) = await seed();
    members = [
      {'user_id': 'u-2', 'username': 'bob', 'role': 'owner'},
      {'user_id': 'u-5', 'username': 'carol', 'role': 'editor'},
    ];
    await container.read(membersProvider('col-2').future);
    await expectNothingCleared(stale);
  });
}
