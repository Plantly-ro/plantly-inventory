import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/collections.dart' show deviceRevokedNoticeProvider;
import 'package:plantly_inventory/cloud/local_data_wipe.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/notifications/notification_service.dart';
import 'package:plantly_inventory/shared/page_reload.dart';
import 'package:plantly_inventory/shared/session_tab_events.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/http_sync_runner.dart';
import 'package:plantly_inventory/sync/op_log.dart';
import 'package:plantly_inventory/sync/sync_engine.dart';
import 'package:plantly_inventory/sync/sync_transport.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../marketplace/plantly_session_test.dart' show fakeJwt;
import 'collection_link_test.dart' show countTenant, insertDummy;

/// Audit P1 + review 2026-10-07: on a shared computer an explicit web
/// sign-out must not leave the collection behind — and nothing else may
/// wipe local data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final token = fakeJwt(
    iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
  );

  late AppDatabase db;
  late InMemoryPhotoBlobStore blobs;
  late int reloads;

  Map<String, Object> accountPrefs() => {
        kTenantIdPrefKey: 'col-1',
        kCollectionIdPrefKey: 'col-1',
        kCollectionNamePrefKey: 'My plants',
        kCollectionUserIdPrefKey: 'u-1',
        kCollectionUsernamePrefKey: 'alice',
        kDataOwnerUserIdPrefKey: 'u-1',
        kDataOwnerUsernamePrefKey: 'alice',
        'plantly_sync_cursor/col-1': '42',
        'plantly_collections_cache': '[]',
        'plantly_collection_members/col-1': '[]',
        'plantly_cloud_entitlement': '{}',
        'plantly_cloud_entitlement_user': 'u-1',
        'plantly_user_name': 'Alice',
        'plantly_seed_manifest': '{}',
        kSkipSeedPrefKey: true,
        'plantly_theme': 'dark',
        'plantly_layout': 'grouped',
        'plantly_onboarded': true,
        'plantly_device_id': 'dev-browser',
      };

  setUp(() async {
    SharedPreferences.setMockInitialValues(accountPrefs());
    db = AppDatabase.forTesting(NativeDatabase.memory());
    blobs = InMemoryPhotoBlobStore();
    reloads = 0;
    for (final t in db.allTables) {
      await insertDummy(db, t, 'col-1', suffix: 'a');
      await insertDummy(db, t, 'col-other', suffix: 'b');
    }
    await blobs.write(sha: 'sha-1', mime: 'image/jpeg', bytes: Uint8List.fromList([1, 2, 3]));
  });
  tearDown(() => db.close());

  Future<void> expectWiped() async {
    for (final t in db.allTables) {
      expect(await countTenant(db, t, 'col-1'), 0, reason: t.actualTableName);
      expect(await countTenant(db, t, 'col-other'), 0, reason: '${t.actualTableName}: every tenant goes');
    }
    expect(await db.customSelect('SELECT * FROM plants_fts').get(), isEmpty);
    expect(blobs.blobs, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), {'plantly_theme', 'plantly_layout', 'plantly_onboarded', 'plantly_device_id'});
  }

  Future<void> expectKept() async {
    for (final t in db.allTables) {
      expect(await countTenant(db, t, 'col-1'), 1, reason: t.actualTableName);
    }
    expect(blobs.blobs, isNotEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kCollectionIdPrefKey), 'col-1');
    expect(prefs.getString(kDataOwnerUserIdPrefKey), 'u-1', reason: 'the gate keeps guarding the rows');
  }

  test('wipeLocalData: every row of every tenant, the blobs, the account prefs — UI prefs + device id stay', () async {
    await wipeLocalData(db: db, blobs: blobs, prefs: await SharedPreferences.getInstance());
    await expectWiped();
    expect((await db.customSelect('PRAGMA secure_delete').getSingle()).data.values.single, 1);
  });

  test('a failed database wipe leaves blobs and prefs alone and rethrows', () async {
    await db.customStatement("CREATE TRIGGER no_wipe BEFORE DELETE ON plants BEGIN SELECT RAISE(ABORT, 'disk says no'); END");
    await expectLater(
      wipeLocalData(db: db, blobs: blobs, prefs: await SharedPreferences.getInstance()),
      throwsA(anything),
    );
    await expectKept();
  });

  late StreamController<void> otherTab;

  ProviderContainer make({required bool web, SyncRunner? runner}) {
    otherTab = StreamController<void>.broadcast();
    addTearDown(otherTab.close);
    final c = ProviderContainer(overrides: [
      webPlatformProvider.overrideWithValue(web),
      databaseProvider.overrideWithValue(db),
      photoBlobStoreProvider.overrideWithValue(blobs),
      notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
      pageReloaderProvider.overrideWithValue(() => reloads++),
      sessionRemovedInOtherTabProvider.overrideWithValue(otherTab.stream),
      if (runner != null) syncRunnerProvider.overrideWithValue(runner),
    ]);
    addTearDown(c.dispose);
    c.read(webSessionGuardProvider);
    return c;
  }

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('policy: wipe only on an explicit decision', () {
    test('web, involuntary sign-out (refresh 401 / max age / plugin 401) keeps everything, no reload', () async {
      final c = make(web: true);
      await c.read(plantlyAuthProvider.notifier).current();
      await c.read(plantlyAuthProvider.notifier).signOut();
      await settle();
      expect(reloads, 0);
      await expectKept();
    });

    test('web, explicit sign-out: session gone, browser wiped, reload at the root', () async {
      final c = make(web: true);
      await c.read(plantlyAuthProvider.notifier).current();
      await c.read(localDataWiperProvider).signOutAndWipe();
      expect(c.read(plantlyAuthProvider).valueOrNull, isNull);
      await expectWiped();
      expect(reloads, 1);
    });

    test('web, confirmed device_revoked wipes and reloads; Android keeps it', () async {
      final c = make(web: true);
      c.read(deviceRevokedNoticeProvider.notifier).state = true;
      await settle();
      await expectWiped();
      expect(reloads, 1);
    });

    test('Android: device_revoked and sign-out keep everything on the phone', () async {
      final c = make(web: false);
      await c.read(plantlyAuthProvider.notifier).current();
      c.read(deviceRevokedNoticeProvider.notifier).state = true;
      await c.read(plantlyAuthProvider.notifier).signOut();
      otherTab.add(null);
      await settle();
      expect(reloads, 0);
      await expectKept();
    });

    test('web, another tab dropped the session: this tab reloads at once (no writes after), data kept', () async {
      make(web: true);
      otherTab.add(null);
      await settle();
      expect(reloads, 1);
      await expectKept();
    });
  });

  group('flush before sign-out', () {
    test('loops syncNow until nothing is pending (an in-flight cycle may predate the last edit)', () async {
      await db.customStatement('UPDATE sync_ops SET pushed_at = NULL, user_id = NULL');
      await insertDummy(db, db.syncOps, 'col-1', suffix: 'c');
      await db.customStatement('UPDATE sync_ops SET pushed_at = NULL, user_id = NULL');
      final runner = _OnePerCycleRunner(db);
      final c = make(web: true, runner: runner);
      final wiper = c.read(localDataWiperProvider);
      expect(await wiper.pendingCount(), 3);
      expect(await wiper.flush(pause: Duration.zero), 0);
      expect(runner.cycles, 3);
    });

    test('gives up at the deadline and reports what is left', () async {
      await db.customStatement('UPDATE sync_ops SET pushed_at = NULL, user_id = NULL');
      final c = make(web: true, runner: const NoopSyncRunner());
      final left = await c
          .read(localDataWiperProvider)
          .flush(timeout: const Duration(milliseconds: 50), pause: const Duration(milliseconds: 10));
      expect(left, 2);
    });

    test('another account\'s pending ops are not counted', () async {
      await db.customStatement("UPDATE sync_ops SET pushed_at = NULL, user_id = 'u-other'");
      final c = make(web: true);
      await c.read(plantlyAuthProvider.notifier).current();
      expect(await c.read(localDataWiperProvider).pendingCount(), 0);
    });
  });

  test('P0-1: wipe → sign in again → a server that returns own-device ops restores everything', () async {
    final server = _EchoServer();
    final clock = HlcClock(deviceId: 'dev-browser');
    final fresh = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(fresh.close);
    final prefs = await SharedPreferences.getInstance();

    HttpSyncRunner runnerFor(AppDatabase d) => HttpSyncRunner(
          db: d,
          opLog: OpLogWriter(db: d, clock: clock, tenantId: 'col-1'),
          transport: server,
          cursor: PrefsSyncCursor(prefs: prefs, tenantId: 'col-1'),
          deviceId: 'dev-browser',
          collectionId: 'col-1',
          periodic: Duration.zero,
          observeLifecycle: false,
        );

    // Before: two plants on this browser, synced.
    final before = runnerFor(fresh);
    final log = before.opLog;
    for (final id in ['p1', 'p2']) {
      final h = await log.recordCreate(entity: 'plants', entityId: id, value: {'id': id, 'nickname': id, 'status': 'alive'});
      await fresh.into(fresh.plants).insert(PlantsCompanion.insert(
            id: id, tenantId: 'col-1', nickname: id, status: 'alive', updatedHlc: h.encode(), deviceId: 'dev-browser'));
    }
    await before.syncNow();
    await before.dispose();
    expect(server.log, hasLength(2));

    // Explicit sign-out wipes; the same device id signs in again.
    await wipeLocalData(db: fresh, blobs: blobs, prefs: prefs);
    expect(await fresh.select(fresh.plants).get(), isEmpty);
    expect(prefs.getString('plantly_device_id'), 'dev-browser');

    final after = runnerFor(fresh);
    await after.syncNow();
    await after.dispose();
    expect({for (final p in await fresh.select(fresh.plants).get()) p.id}, {'p1', 'p2'});

    // A surviving stale cursor (no wipe of prefs, e.g. OPFS evicted) heals too.
    await wipeDatabase(fresh);
    await PrefsSyncCursor(prefs: prefs, tenantId: 'col-1').set('2');
    final healed = runnerFor(fresh);
    await healed.syncNow();
    await healed.dispose();
    expect({for (final p in await fresh.select(fresh.plants).get()) p.id}, {'p1', 'p2'});
  });

  test('boot: a stored session with nothing linked links at start (no visit to Me needed)', () async {
    SharedPreferences.setMockInitialValues({kSkipSeedPrefKey: true});
    final c = ProviderContainer(overrides: [
      cloudEnabledProvider.overrideWithValue(true),
      databaseProvider.overrideWithValue(db),
      notificationServiceProvider.overrideWith((_) => FakeNotificationService()),
      sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
      collectionLinkProvider.overrideWith((ref) => _RecordingLinks(ref)),
    ]);
    addTearDown(c.dispose);
    final coordinator = c.read(cloudSyncCoordinatorProvider);
    await coordinator.booted;
    expect((c.read(collectionLinkProvider.notifier) as _RecordingLinks).ensureCalls, 1);
  });
}

/// Pushes one pending op per cycle — a flush must keep going.
class _OnePerCycleRunner implements SyncRunner {
  _OnePerCycleRunner(this.db);
  final AppDatabase db;
  int cycles = 0;
  @override
  Future<void> syncNow() async {
    cycles++;
    await db.customStatement(
        'UPDATE sync_ops SET pushed_at = 1 WHERE seq = (SELECT MIN(seq) FROM sync_ops WHERE pushed_at IS NULL)');
  }

  @override
  Stream<SyncStatus> get status => Stream.value(SyncStatus.empty);
}

/// be!285 semantics: pull returns every op of the collection after `since`,
/// the caller's own device included.
class _EchoServer implements SyncTransport {
  final List<SyncOpDto> log = [];
  @override
  Future<PushResponse> push(PushRequest request) async {
    log.addAll([
      for (final o in request.ops)
        SyncOpDto(entity: o.entity, entityId: o.entityId, field: o.field, value: o.value, hlc: o.hlc, deviceId: request.deviceId),
    ]);
    return PushResponse(accepted: request.ops.length, rejected: const [], cursor: '${log.length}', freshOps: const [], hasMore: false);
  }

  @override
  Future<PullResponse> pull(PullRequest request) async {
    final since = int.tryParse(request.since) ?? 0;
    return PullResponse(ops: log.skip(since).toList(), cursor: '${log.length}', hasMore: false);
  }
}

class _RecordingLinks extends CollectionLinkService {
  _RecordingLinks(super.ref);
  int ensureCalls = 0;
  @override
  Future<CollectionLink?> ensureLinked() async {
    ensureCalls++;
    return null;
  }
}
