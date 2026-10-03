// QA2 BUG-4: a join link on a device another account linked. The join
// sheet must ask the data-owner question (Move / Start empty / Cancel)
// BEFORE `POST /collections/join`, and only join once the device is linked
// for the signed-in user — otherwise the join lands nowhere (no link of
// ours, no switcher, ops pending forever under the previous account's
// tenant).
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/collections/join_collection_sheet.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cloud/cloud_state_test.dart' show FixedEntitlement;
import '../../cloud/collection_link_test.dart' show insertDummy;
import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

void main() {
  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final carolToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400, username: 'carol', userId: 'u-3');

  late AppDatabase db;
  late List<http.Request> requests;
  late bool linkedForCarol;
  late bool joined;

  Map<String, dynamic> col(String id, String name, {String role = 'owner', String owner = 'u-3', int members = 1}) =>
      {'id': id, 'name': name, 'role': role, 'owner_user_id': owner, 'member_count': members};

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  List<String> paths(String suffix) => [for (final r in requests) if (r.url.path.endsWith(suffix)) r.url.path];

  /// While the sheet is busy its submit button spins (an endless animation),
  /// so `pumpAndSettle` would never return — pump a bounded number of frames.
  Future<void> pumpFrames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() async {
    // Device A as user 1 (alice) left it: her link, her data-owner marker,
    // her collection as the tenant, and rows under it.
    SharedPreferences.setMockInitialValues({
      'plantly_onboarded': true,
      kCollectionIdPrefKey: 'col-1',
      kCollectionNamePrefKey: 'My plants',
      kCollectionUserIdPrefKey: 'u-1',
      kCollectionUsernamePrefKey: 'alice',
      kDataOwnerUserIdPrefKey: 'u-1',
      kDataOwnerUsernamePrefKey: 'alice',
      kTenantIdPrefKey: 'col-1',
      kSkipSeedPrefKey: true,
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await insertDummy(db, db.plants, 'col-1');
    requests = [];
    linkedForCarol = false;
    joined = false;
  });

  tearDown(() => db.close());

  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(buildTestApp(
      overrides: [
        cloudEnabledProvider.overrideWithValue(true),
        databaseProvider.overrideWithValue(db),
        // User 3 (carol, no plan) signed in — the join deep link's login step already happened.
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(carolToken)),
        cloudEntitlementProvider.overrideWith(() => FixedEntitlement(CloudEntitlement.none)),
        collectionsRefreshIntervalProvider.overrideWithValue(Duration.zero),
        syncRunnerProvider.overrideWithValue(const NoopSyncRunner()),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              requests.add(req);
              final path = req.url.path;
              if (req.method == 'GET' && path.endsWith('/subscriptions/me')) {
                return jsonRes({'is_pro': false, 'entitlements': {}});
              }
              if (req.method == 'POST' && path.endsWith('/inventory/collections/default')) {
                expect(req.headers['Authorization'], 'Bearer $carolToken');
                linkedForCarol = true;
                return jsonRes({'collection': col('col-9', "Carol's plants")});
              }
              if (req.method == 'GET' && path.endsWith('/inventory/collections')) {
                return jsonRes({
                  'collections': [
                    if (linkedForCarol) col('col-9', "Carol's plants"),
                    if (joined) col('col-3', 'Office jungle', role: 'editor', owner: 'u-2', members: 2),
                  ]
                });
              }
              if (req.method == 'POST' && path.endsWith('/inventory/collections/join')) {
                expect(req.headers['Authorization'], 'Bearer $carolToken');
                expect(json.decode(req.body), {'code': 'ABCDEFGH'});
                joined = true;
                return jsonRes({'collection': col('col-3', 'Office jungle', role: 'editor', owner: 'u-2', members: 2)});
              }
              return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
            })),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              key: const Key('open'),
              onPressed: () => showJoinCollectionSheet(ctx, initialCode: 'ABCDEFGH'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('open'))));
    // Session + persisted link read before anything is tapped.
    await container.read(plantlyAuthProvider.notifier).current();
    await container.read(collectionLinkProvider.notifier).ready;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-collection-title')), findsOneWidget);
    expect(find.byKey(const Key('join-paywall-note')), findsOneWidget, reason: 'no plan: the §3 note stays');
    return container;
  }

  testWidgets('Join → decision dialog first (no /join yet); Start empty → link for carol, then join, switched to it', (tester) async {
    final c = await pumpSheet(tester);
    final before = c.read(cloudStateProvider);
    expect(before.phase, CloudPhase.notEntitled);
    expect(before.linked, isFalse, reason: 'alice\'s link is not ours');
    expect(before.heldByOther, 'alice');
    expect(c.read(activeCollectionIdProvider), isNull);

    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-held-by-other')), findsOneWidget);
    expect(find.text('This device holds plants synced by alice.'), findsOneWidget);
    expect(find.byKey(const Key('cloud-move-to-me')), findsOneWidget);
    expect(find.text("Move this device's plants to carol's cloud"), findsOneWidget);
    expect(find.byKey(const Key('cloud-start-empty')), findsOneWidget);
    expect(find.text('Start empty for carol'), findsOneWidget);
    expect(paths('/inventory/collections/join'), isEmpty, reason: 'decision comes BEFORE the join');
    expect(paths('/inventory/collections/default'), isEmpty);

    await tester.tap(find.byKey(const Key('cloud-start-empty')));
    await pumpFrames(tester, 30);
    await tester.pumpAndSettle();

    // Order: link for carol (POST /default) → join.
    final order = [
      for (final r in requests)
        if (r.url.path.endsWith('/inventory/collections/default') || r.url.path.endsWith('/inventory/collections/join'))
          r.url.path.split('/').last
    ];
    expect(order, ['default', 'join']);
    expect(find.byKey(const Key('join-held-by-other')), findsNothing);
    expect(find.byKey(const Key('join-collection-title')), findsNothing, reason: 'sheet closed on success');
    expect(find.text('Joined Office jungle'), findsOneWidget);

    final after = c.read(cloudStateProvider);
    expect(after.linked, isTrue);
    expect(after.collectionId, 'col-9', reason: 'home = carol\'s own default');
    expect(after.heldByOther, isNull);
    expect(c.read(currentTenantIdProvider), 'col-3', reason: 'switched to the joined collection');
    expect(c.read(collectionsProvider).items.map((x) => x.id), containsAll(['col-9', 'col-3']));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kCollectionUserIdPrefKey), 'u-3');
    expect(prefs.getString(kDataOwnerUserIdPrefKey), 'u-3');
    expect(prefs.getBool(kSkipSeedPrefKey), isTrue);
    expect(prefs.getString(kTenantIdPrefKey), 'col-3');
    // Alice's rows are untouched on disk under her collection id.
    final aliceRows = await db.customSelect("SELECT COUNT(*) AS n FROM plants WHERE tenant_id = 'col-1'").getSingle();
    expect(aliceRows.read<int>('n'), 1);
  });

  testWidgets('Cancel → no /join, no link, sheet stays open and usable', (tester) async {
    final c = await pumpSheet(tester);
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-held-by-other')), findsOneWidget);

    await tester.tap(find.byKey(const Key('join-held-by-other-cancel')));
    await pumpFrames(tester);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-held-by-other')), findsNothing);
    expect(find.byKey(const Key('join-collection-title')), findsOneWidget, reason: 'sheet still open');
    expect(paths('/inventory/collections/join'), isEmpty);
    expect(paths('/inventory/collections/default'), isEmpty);
    expect(c.read(cloudStateProvider).linked, isFalse);
    expect(c.read(cloudStateProvider).heldByOther, 'alice');
    expect(c.read(currentTenantIdProvider), 'col-1');
    // Not busy, no error: the user can try again.
    final button = tester.widget<FilledButton>(find.byKey(const Key('join-collection-submit')));
    expect(button.onPressed, isNotNull);
    expect(tester.widget<TextField>(find.byKey(const Key('join-collection-code'))).decoration!.errorText, isNull);
  });
}
