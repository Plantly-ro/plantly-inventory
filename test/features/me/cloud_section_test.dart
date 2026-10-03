import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/me/cloud_screen.dart';
import 'package:plantly_inventory/features/me/cloud_section.dart';
import 'package:plantly_inventory/features/me/me_screen.dart';
import 'package:plantly_inventory/features/me/sync_rejections_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/sync/sync_providers.dart';
import 'package:plantly_inventory/sync/sync_rejections.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cloud/cloud_state_test.dart' show FixedEntitlement;
import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

class RecordingRunner implements SyncRunner {
  RecordingRunner(this.current);
  SyncStatus current;
  int syncNowCalls = 0;
  final _controller = StreamController<SyncStatus>.broadcast();

  @override
  Future<void> syncNow() async => syncNowCalls++;

  @override
  Stream<SyncStatus> get status async* {
    yield current;
    yield* _controller.stream;
  }
}

void main() {
  final token = fakeJwt(
    iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
    exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
  );

  late int collectionCreates;
  var failCollectionCreate = false;
  setUp(() {
    collectionCreates = 0;
    failCollectionCreate = false;
  });

  Future<RecordingRunner> pump(
    WidgetTester tester, {
    bool enabled = true,
    bool signedIn = true,
    CloudEntitlement? entitlement,
    bool linked = true,
    String linkUser = 'u-1',
    Locale locale = const Locale('en'),
    SyncStatus status = SyncStatus.empty,
    Widget? child,
    AppDatabase? db,
    bool? purchaseLink,
    List<Override> extra = const [],
  }) async {
    SharedPreferences.setMockInitialValues({
      'plantly_onboarded': true,
      if (linked) kCollectionIdPrefKey: 'col-1',
      if (linked) kCollectionNamePrefKey: 'My plants',
      if (linked) kCollectionUserIdPrefKey: linkUser,
      if (linked) kCollectionUsernamePrefKey: linkUser == 'u-1' ? 'alice' : 'bob',
      if (linked) kTenantIdPrefKey: 'col-1',
    });
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    final runner = RecordingRunner(status);
    await tester.pumpWidget(buildTestApp(
      overrides: [
        cloudEnabledProvider.overrideWithValue(enabled),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(signedIn ? token : null)),
        cloudEntitlementProvider.overrideWith(() => FixedEntitlement(entitlement)),
        syncRunnerProvider.overrideWithValue(runner),
        if (purchaseLink != null) cloudPurchaseLinkAllowedProvider.overrideWithValue(purchaseLink),
        if (db != null) databaseProvider.overrideWithValue(db),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              if (req.method == 'POST' && req.url.path.endsWith('/inventory/collections/default')) {
                collectionCreates++;
                if (failCollectionCreate) return http.Response('{"error":"boom"}', 503);
                return http.Response(
                  json.encode({
                    'collection': {'id': 'col-9', 'name': 'Colecția mea', 'role': 'owner'},
                  }),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                );
              }
              return http.Response('{"error":"nope"}', 404);
            })),
        ...extra,
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child ??
            Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: const [CloudSection(surface: PlantlySurface.light)],
              ),
            ),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return runner;
  }

  group('CloudSection per phase', () {
    testWidgets('flag off → renders nothing', (tester) async {
      await pump(tester, enabled: false, entitlement: const CloudEntitlement(active: true, source: 'pro'));
      expect(find.byKey(const Key('me-cloud-section')), findsNothing);
      expect(find.text('CLOUD'), findsNothing);
      expect(find.text('Cloud'), findsNothing);
    });

    testWidgets('signedOut (en): sign-in row + pitch; tapping opens the login sheet with social buttons', (tester) async {
      await pump(tester, signedIn: false);
      expect(find.byKey(const Key('me-cloud-section')), findsOneWidget);
      expect(find.text('Sign in to plantly.ro'), findsOneWidget);
      expect(find.text('Back up your plants and sync them across devices'), findsOneWidget);
      expect(find.byKey(const Key('cloud-subscribe')), findsNothing);
      expect(find.byKey(const Key('cloud-status')), findsNothing);
      await tester.tap(find.byKey(const Key('cloud-sign-in')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plantly-login-google')), findsOneWidget);
      expect(find.byKey(const Key('plantly-login-facebook')), findsOneWidget);
      // Opened from Cloud → the cloud subtitle, not the listing one.
      expect(find.text('Use your plantly.ro account for cloud backup & sync.'), findsOneWidget);
      expect(find.text('Use your plantly.ro account to post listings.'), findsNothing);
    });

    testWidgets('signedOut (ro)', (tester) async {
      await pump(tester, signedIn: false, locale: const Locale('ro'));
      expect(find.text('Conectează-te la plantly.ro'), findsOneWidget);
      expect(find.text('Fă backup plantelor tale și sincronizează-le între dispozitive'), findsOneWidget);
    });

    test('purchase link gate: web/desktop yes, Android/iOS no (Play policy)', () {
      bool allowed(TargetPlatform p) {
        debugDefaultTargetPlatformOverride = p;
        try {
          final c = ProviderContainer();
          addTearDown(c.dispose);
          return c.read(cloudPurchaseLinkAllowedProvider);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      expect(allowed(TargetPlatform.android), isFalse);
      expect(allowed(TargetPlatform.iOS), isFalse);
      expect(allowed(TargetPlatform.linux), isTrue);
      expect(allowed(TargetPlatform.macOS), isTrue);
      expect(allowed(TargetPlatform.windows), isTrue);
    });

    testWidgets('notEntitled on Android: text + Refresh, NO subscribe link (Play policy)', (tester) async {
      await pump(tester, entitlement: CloudEntitlement.none, linked: false, purchaseLink: false);
      expect(find.text('Cloud backup & sync'), findsOneWidget);
      expect(find.text('Included with Plantly Pro or Plantly Inventory Cloud'), findsOneWidget);
      expect(find.byKey(const Key('cloud-refresh')), findsOneWidget);
      expect(find.text('Refresh status'), findsOneWidget);
      expect(find.byKey(const Key('cloud-subscribe')), findsNothing);
      expect(find.textContaining('Subscribe'), findsNothing);
      expect(find.byKey(const Key('cloud-account')), findsOneWidget);
      expect(find.text('Signed in as alice · tap to sign out'), findsOneWidget);
      expect(find.byKey(const Key('cloud-sync-now')), findsNothing);
    });

    testWidgets('notEntitled on desktop (ro): subscribe link present', (tester) async {
      await pump(tester, entitlement: CloudEntitlement.none, linked: false, locale: const Locale('ro'), purchaseLink: true);
      expect(find.text('Backup și sincronizare în cloud'), findsOneWidget);
      expect(find.text('Inclus în Plantly Pro sau Plantly Inventory Cloud'), findsOneWidget);
      expect(find.byKey(const Key('cloud-subscribe')), findsOneWidget);
      expect(find.text('Abonează-te pe plantly.ro'), findsOneWidget);
      expect(find.text('Reîmprospătează starea'), findsOneWidget);
      expect(find.text('Conectat ca alice · apasă pentru deconectare'), findsOneWidget);
    });

    testWidgets('ready (en): status from SyncStatus, Sync now calls the runner, account, unlink with server-data-kept copy', (tester) async {
      final now = DateTime.now().toUtc();
      final runner = await pump(
        tester,
        entitlement: const CloudEntitlement(active: true, source: 'pro'),
        status: SyncStatus(
          lastSyncAt: now.subtract(const Duration(minutes: 5)),
          pendingOps: 3,
          bytesStored: 12 * 1024 * 1024,
          bytesQuota: 2 * 1024 * 1024 * 1024,
        ),
      );
      expect(find.byKey(const Key('cloud-status')), findsOneWidget);
      expect(find.text('Synced 5 min ago · 3 changes waiting · 12 MB of 2 GB used'), findsOneWidget);
      expect(find.byKey(const Key('cloud-subscribe')), findsNothing);
      expect(find.byKey(const Key('cloud-not-included')), findsNothing);

      await tester.tap(find.byKey(const Key('cloud-sync-now')));
      await tester.pumpAndSettle();
      expect(runner.syncNowCalls, 1);
      expect(find.text('Syncing…'), findsOneWidget); // snackbar

      expect(find.text('Signed in as alice · tap to sign out'), findsOneWidget);

      await tester.tap(find.byKey(const Key('cloud-unlink')));
      await tester.pumpAndSettle();
      expect(find.text('Unlink this device?'), findsOneWidget);
      expect(
        find.text(
            'Sync stops on this device. Nothing is deleted: your plants stay here and your data stays in your plantly.ro account. Sign in again any time to relink.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('cloud-unlink-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Device unlinked'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kCollectionIdPrefKey), isNull);
      expect(prefs.getString(kTenantIdPrefKey), 'col-1', reason: 'tenant id stays');

      // Sticky: no automatic re-link, an explicit "turn it on" row instead.
      expect(collectionCreates, 0);
      expect(find.text('Sync is off on this device — tap to turn it on'), findsOneWidget);
      expect(find.byKey(const Key('cloud-sync-now')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cloud-status')));
      await tester.pumpAndSettle();
      expect(collectionCreates, 1);
      expect(prefs.getString(kCollectionIdPrefKey), 'col-9');
      expect(find.textContaining('Synced 5 min ago'), findsOneWidget);
    });

    testWidgets('a failed auto-link shows "tap to retry" once — no retry storm', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      failCollectionCreate = true;
      await pump(tester, entitlement: const CloudEntitlement(active: true, source: 'pro'), linked: false, db: db);
      await tester.pumpAndSettle();
      expect(collectionCreates, 1);
      expect(find.text("Couldn't set up cloud sync. Tap to retry."), findsOneWidget);
      failCollectionCreate = false;
      await tester.tap(find.byKey(const Key('cloud-status')));
      await tester.pumpAndSettle();
      expect(collectionCreates, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kCollectionIdPrefKey), 'col-9');
    });

    testWidgets('ready (ro): status copy with diacritics', (tester) async {
      await pump(
        tester,
        locale: const Locale('ro'),
        entitlement: const CloudEntitlement(active: true, source: 'inventory_cloud'),
        status: const SyncStatus(pendingOps: 0),
      );
      expect(find.text('Sincronizare cloud'), findsOneWidget);
      expect(find.text('Încă nesincronizat · toate modificările încărcate'), findsOneWidget);
      expect(find.text('Sincronizează acum'), findsOneWidget);
      expect(find.text('Deconectează acest dispozitiv'), findsOneWidget);
    });

    testWidgets('ready but not linked yet → links the default collection automatically', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await pump(tester, entitlement: const CloudEntitlement(active: true, source: 'pro'), linked: false, db: db);
      await tester.pumpAndSettle();
      expect(collectionCreates, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kCollectionIdPrefKey), 'col-9');
      expect(prefs.getString(kTenantIdPrefKey), 'col-9');
      expect(find.text('Setting up your cloud collection…'), findsNothing);
      expect(find.byKey(const Key('cloud-sync-now')), findsOneWidget);
    });

    testWidgets('account switch: decision rows, nothing automatic; Move confirms then links', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await pump(tester, entitlement: const CloudEntitlement(active: true, source: 'pro'), linkUser: 'u-other', db: db);
      await tester.pumpAndSettle();
      expect(collectionCreates, 0, reason: 'never auto-link over another account\'s data');
      expect(find.text('This device holds plants synced by bob.'), findsOneWidget);
      expect(find.byKey(const Key('cloud-move-to-me')), findsOneWidget);
      expect(find.byKey(const Key('cloud-start-empty')), findsOneWidget);
      expect(find.text("Move this device's plants to alice's cloud"), findsOneWidget);
      expect(find.text('Start empty for alice'), findsOneWidget);
      expect(find.byKey(const Key('cloud-sync-now')), findsNothing);

      // Cancel = stay as is.
      await tester.tap(find.byKey(const Key('cloud-move-to-me')));
      await tester.pumpAndSettle();
      expect(find.textContaining("leaves bob's collection"), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(collectionCreates, 0);
      expect(find.byKey(const Key('cloud-move-to-me')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cloud-move-to-me')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cloud-move-confirm')));
      await tester.pumpAndSettle();
      expect(collectionCreates, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kCollectionUserIdPrefKey), 'u-1');
      expect(prefs.getString(kTenantIdPrefKey), 'col-9');
      expect(prefs.getBool(kSkipSeedPrefKey), isNull);
      expect(find.byKey(const Key('cloud-move-to-me')), findsNothing);
      expect(find.byKey(const Key('cloud-sync-now')), findsOneWidget);
    });

    testWidgets('QA2 BUG-4: notEntitled + heldByOther → the decision rows, not the paywall', (tester) async {
      await pump(
        tester,
        entitlement: CloudEntitlement.none,
        linked: false,
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: const [CloudRows(surface: PlantlySurface.light, detailed: true)],
          ),
        ),
        extra: [
          cloudStateProvider.overrideWithValue(const CloudState(phase: CloudPhase.notEntitled, account: 'carol', heldByOther: 'alice')),
        ],
      );
      expect(find.byKey(const Key('cloud-held-by-other')), findsOneWidget);
      expect(find.text('This device holds plants synced by alice.'), findsOneWidget);
      expect(find.byKey(const Key('cloud-move-to-me')), findsOneWidget);
      expect(find.text("Move this device's plants to carol's cloud"), findsOneWidget);
      expect(find.byKey(const Key('cloud-start-empty')), findsOneWidget);
      expect(find.text('Start empty for carol'), findsOneWidget);
      expect(find.byKey(const Key('cloud-not-included')), findsNothing, reason: 'decision first, paywall later');
      expect(find.byKey(const Key('cloud-subscribe')), findsNothing);
      expect(find.byKey(const Key('cloud-refresh')), findsNothing);
      expect(collectionCreates, 0, reason: 'nothing automatic');
      // Same confirm dialog as the ready-phase rows.
      await tester.tap(find.byKey(const Key('cloud-move-to-me')));
      await tester.pumpAndSettle();
      expect(find.text('Move plants to your cloud?'), findsOneWidget);
      expect(find.byKey(const Key('cloud-move-confirm')), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(collectionCreates, 0);
    });

    testWidgets('account switch (ro): Start empty → fresh tenant, skip-seed set, linked for the new user', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await pump(tester,
          entitlement: const CloudEntitlement(active: true, source: 'pro'), linkUser: 'u-other', db: db, locale: const Locale('ro'));
      expect(find.text('Pe acest dispozitiv sunt plante sincronizate de bob.'), findsOneWidget);
      expect(find.text('Începe de la zero pentru alice'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cloud-start-empty')));
      await tester.pumpAndSettle();
      expect(collectionCreates, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kSkipSeedPrefKey), isTrue);
      expect(prefs.getString(kTenantIdPrefKey), 'col-9');
      expect(prefs.getString(kCollectionUserIdPrefKey), 'u-1');
      expect(find.byKey(const Key('cloud-start-empty')), findsNothing);
      expect(find.text('Sincronizează acum'), findsOneWidget);
    });

    testWidgets('section title opens the Cloud screen with plan + collection detail', (tester) async {
      await pump(
        tester,
        entitlement: CloudEntitlement(active: true, source: 'pro', currentPeriodEnd: DateTime.utc(2026, 10, 27)),
        status: const SyncStatus(lastError: 'cloud_required'),
      );
      await tester.tap(find.byKey(const Key('cloud-section-title')));
      await tester.pumpAndSettle();
      expect(find.byType(CloudScreen), findsOneWidget);
      expect(find.byKey(const Key('cloud-screen-intro')), findsOneWidget);
      expect(find.byKey(const Key('cloud-plan')), findsOneWidget);
      expect(find.textContaining('Included with Plantly Pro · renews'), findsOneWidget);
      expect(find.byKey(const Key('cloud-collection')), findsOneWidget);
      expect(find.text('My plants'), findsOneWidget);
      expect(find.byKey(const Key('cloud-last-error')), findsOneWidget);
    });
  });

  group('rejected changes', () {
    SyncRejectionRow rejection(int seq, {String reason = 'bad_hlc', bool parked = true}) => SyncRejectionRow(
          opSeq: seq,
          tenantId: 'col-1',
          entity: 'plants',
          entityId: 'plant-$seq',
          field: seq.isEven ? '*' : 'nickname',
          reason: reason,
          hlc: '00001790504286459-00000-dev',
          at: DateTime.utc(2026, 9, 27, 10).millisecondsSinceEpoch,
          parked: parked,
        );

    testWidgets('en: last-error copy from the ledger; Details opens the list; Dismiss clears + syncs', (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final store = SyncRejectionStore(db: db, tenantId: 'col-1');
      final rows = [rejection(2), rejection(1, reason: 'hlc_future', parked: false)];
      final runner = await pump(
        tester,
        entitlement: const CloudEntitlement(active: true, source: 'pro'),
        status: const SyncStatus(
          lastError: 'rejected',
          lastErrorDetail: '2 changes could not be synced (bad_hlc)',
          rejectedOps: 2,
          rejectedReason: 'bad_hlc',
        ),
        extra: [
          syncRejectionStoreProvider.overrideWithValue(store),
          syncRejectionsProvider.overrideWith((_) => Stream.value(rows)),
        ],
        child: const Scaffold(body: CloudScreen()),
      );
      expect(find.byKey(const Key('cloud-last-error')), findsOneWidget);
      expect(find.text('2 changes could not be synced (bad_hlc)'), findsOneWidget);
      expect(find.byKey(const Key('cloud-rejections')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cloud-rejections')));
      await tester.pumpAndSettle();
      expect(find.byType(SyncRejectionsScreen), findsOneWidget);
      expect(find.text('Changes not synced'), findsOneWidget);
      expect(find.byKey(const Key('cloud-rejection-2')), findsOneWidget);
      expect(find.byKey(const Key('cloud-rejection-1')), findsOneWidget);
      expect(find.text('plants · *'), findsOneWidget);
      expect(find.text('plants · nickname'), findsOneWidget);
      expect(find.textContaining('bad_hlc · gave up'), findsOneWidget);
      expect(find.textContaining('hlc_future · retrying'), findsOneWidget);
      expect(find.byKey(const Key('cloud-rejections-empty')), findsNothing);

      await tester.tap(find.byKey(const Key('cloud-rejections-dismiss')));
      await tester.pumpAndSettle();
      expect(runner.syncNowCalls, 1);
    });

    testWidgets('ro: plural copy + empty state', (tester) async {
      await pump(
        tester,
        locale: const Locale('ro'),
        entitlement: const CloudEntitlement(active: true, source: 'pro'),
        status: const SyncStatus(lastError: 'rejected', rejectedOps: 1, rejectedReason: 'bad_value'),
        extra: [
          syncRejectionsProvider.overrideWith((_) => Stream.value(const <SyncRejectionRow>[])),
        ],
        child: const Scaffold(body: CloudScreen()),
      );
      expect(find.text('1 modificare nu a putut fi sincronizată (bad_value)'), findsOneWidget);
      await tester.tap(find.byKey(const Key('cloud-rejections')));
      await tester.pumpAndSettle();
      expect(find.text('Modificări nesincronizate'), findsOneWidget);
      expect(find.byKey(const Key('cloud-rejections-empty')), findsOneWidget);
      expect(find.byKey(const Key('cloud-rejections-retry')), findsNothing);
    });

    test('describeSyncError: collection_unavailable + not_a_member names the collection; generic otherwise', () {
      final t = lookupAppLocalizations(const Locale('en'));
      expect(describeSyncError(t, 'collection_unavailable', detail: 'not_a_member', collectionName: 'Family greenhouse'),
          'You were removed from Family greenhouse');
      expect(describeSyncError(lookupAppLocalizations(const Locale('ro')), 'collection_unavailable', detail: 'not_a_member', collectionName: 'Sera'),
          'Ai fost eliminat din Sera');
      expect(describeSyncError(t, 'collection_unavailable', detail: 'not_a_member'), t.cloudErrCollectionUnavailable,
          reason: 'no name to show → generic copy');
      expect(describeSyncError(t, 'collection_unavailable', detail: 'collection_not_found', collectionName: 'x'), t.cloudErrCollectionUnavailable);
    });

    test('describeSyncError: MULTI-USER-V2 halts — read_only, device_revoked, too_many_devices; device_lookup_failed retry', () {
      final t = lookupAppLocalizations(const Locale('en'));
      final ro = lookupAppLocalizations(const Locale('ro'));
      expect(describeSyncError(t, 'collection_unavailable', detail: 'read_only'), t.shareErrReadOnly);
      expect(describeSyncError(ro, 'collection_unavailable', detail: 'read_only'), ro.shareErrReadOnly);
      expect(describeSyncError(t, 'collection_unavailable', detail: 'read_only', collectionName: 'x'), t.shareErrReadOnly,
          reason: 'the name only matters for not_a_member');
      expect(describeSyncError(t, 'collection_unavailable', detail: 'device_revoked'), t.shareErrDeviceRevoked);
      expect(describeSyncError(t, 'collection_unavailable', detail: 'too_many_devices'), t.shareErrTooManyDevices);
      expect(describeSyncError(t, 'retrying', detail: 'device_lookup_failed'), t.shareErrDeviceLookupFailed);
      expect(describeSyncError(t, 'retrying'), t.cloudErrRetrying);
      expect(describeSyncError(t, 'retrying', detail: 'HTTP 502'), t.cloudErrRetrying);
    });

    test('describeSyncError: rejected uses the typed count/reason, falls back to the detail string', () {
      final t = lookupAppLocalizations(const Locale('en'));
      expect(
        describeSyncError(t, 'rejected', status: const SyncStatus(lastError: 'rejected', rejectedOps: 3, rejectedReason: 'bad_hlc')),
        '3 changes could not be synced (bad_hlc)',
      );
      expect(describeSyncError(t, 'rejected', detail: 'raw detail'), 'raw detail');
      expect(describeSyncError(t, 'op_too_large', detail: 'plants/x'), 'One change is too large to upload and was skipped (plants/x)');
    });
  });

  group('Me screen wiring', () {
    testWidgets('Cloud section sits right above Backup when enabled, absent when off', (tester) async {
      await pump(tester, signedIn: false, child: const MeScreen());
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('BACKUP'), 200, scrollable: scrollable);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('me-cloud-section')), findsOneWidget);
      final cloud = tester.getTopLeft(find.byKey(const Key('cloud-sign-in')));
      final backup = tester.getTopLeft(find.text('BACKUP'));
      expect(cloud.dy, lessThan(backup.dy));
      expect(backup.dy - cloud.dy, lessThanOrEqualTo(120));
    });

    testWidgets('flag off → no Cloud section on the Me screen', (tester) async {
      await pump(tester, enabled: false, signedIn: false, child: const MeScreen());
      await tester.scrollUntilVisible(find.text('BACKUP'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('me-cloud-section')), findsNothing);
    });
  });

  group('formatting helpers', () {
    test('formatCloudBytes', () {
      expect(formatCloudBytes(0), '0 B');
      expect(formatCloudBytes(512), '512 B');
      expect(formatCloudBytes(1536), '1.5 KB');
      expect(formatCloudBytes(12 * 1024 * 1024), '12 MB');
      expect(formatCloudBytes(2 * 1024 * 1024 * 1024), '2 GB');
      expect(formatCloudBytes((1.25 * 1024 * 1024 * 1024).round()), '1.3 GB');
    });
  });
}
