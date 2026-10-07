// MULTI-USER-V2 §8 — every member of a shared collection needs their OWN
// Inventory Cloud plan. The join sheet: not entitled → the requirement
// step + the invite parked (7 days); a server 402 `cloud_required` lands
// on the same step; "Try again" / an entitlement flip resume the join;
// "Not now" clears the parked code. HandoffListener reopens a parked join
// once the plan is active.
import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/app/side_sheet.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/join_parking.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/collections/join_collection_sheet.dart';
import 'package:plantly_inventory/features/me/cloud_section.dart' show cloudPurchaseLinkAllowedProvider;
import 'package:plantly_inventory/handoff/handoff_listener.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

/// An entitlement notifier whose value a test flips; `refresh()` re-runs
/// `build` (no hooks, no network).
class SwitchableEntitlement extends CloudEntitlementNotifier {
  SwitchableEntitlement(this.value);
  CloudEntitlement? value;

  @override
  Future<CloudEntitlement?> build() async {
    ref.watch(plantlyAuthProvider);
    return value;
  }
}

void main() {
  final nowSecs = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  final carolToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400, username: 'carol', userId: 'u-3');
  const code = 'ABCDEFGH';

  late AppDatabase db;
  late List<http.Request> requests;
  late bool serverEntitled; // POST /join answers 402 cloud_required when false
  late String joinErrorCode;
  late int joinErrorStatus;
  late bool joined;
  final bobToken = fakeJwt(iat: nowSecs, exp: nowSecs + 86400, username: 'bob', userId: 'u-2');
  late SwitchableEntitlement entitlement;
  late bool offlineJoin;

  Map<String, dynamic> col(String id, String name, {String role = 'owner', String owner = 'u-3', int members = 1}) =>
      {'id': id, 'name': name, 'role': role, 'owner_user_id': owner, 'member_count': members};

  http.Response jsonRes(Object body, [int status = 200]) =>
      http.Response(json.encode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  List<String> paths(String suffix) => [for (final r in requests) if (r.url.path.endsWith(suffix)) r.url.path];

  Future<void> pumpFrames(WidgetTester tester, [int n = 12]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  setUp(() async {
    // Carol's own device: linked to her default, nothing foreign.
    SharedPreferences.setMockInitialValues({
      'plantly_onboarded': true,
      kCollectionIdPrefKey: 'col-9',
      kCollectionNamePrefKey: "Carol's plants",
      kCollectionUserIdPrefKey: 'u-3',
      kCollectionUsernamePrefKey: 'carol',
      kDataOwnerUserIdPrefKey: 'u-3',
      kDataOwnerUsernamePrefKey: 'carol',
      kTenantIdPrefKey: 'col-9',
      kSkipSeedPrefKey: true,
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    requests = [];
    serverEntitled = true;
    joinErrorCode = 'cloud_required';
    joinErrorStatus = 402;
    joined = false;
    entitlement = SwitchableEntitlement(CloudEntitlement.none);
    offlineJoin = false;
  });

  tearDown(() => db.close());

  MockClient client() => MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (req.method == 'GET' && path.endsWith('/subscriptions/me')) {
          final e = entitlement.value;
          return jsonRes({
            'entitlements': {
              'inventory_cloud': {'active': e?.active ?? false, 'source': e?.active == true ? 'pro' : null},
            },
          });
        }
        if (req.method == 'GET' && path.endsWith('/inventory/collections')) {
          return jsonRes({
            'collections': [
              col('col-9', "Carol's plants"),
              if (joined) col('col-3', 'Office jungle', role: 'editor', owner: 'u-2', members: 2),
            ],
            'caller_entitled': serverEntitled,
          });
        }
        if (req.method == 'POST' && path.endsWith('/inventory/collections/join')) {
          expect(json.decode(req.body), {'code': code});
          if (offlineJoin) throw http.ClientException('offline');
          if (!serverEntitled) return jsonRes({'error': joinErrorCode}, joinErrorStatus);
          joined = true;
          return jsonRes({'collection': col('col-3', 'Office jungle', role: 'editor', owner: 'u-2', members: 2)});
        }
        return jsonRes({'error': 'unexpected ${req.method} $path'}, 404);
      });

  List<Override> overrides({bool purchaseLink = true}) => [
        cloudEnabledProvider.overrideWithValue(true),
        databaseProvider.overrideWithValue(db),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(carolToken)),
        cloudEntitlementProvider.overrideWith(() => entitlement),
        cloudPurchaseLinkAllowedProvider.overrideWithValue(purchaseLink),
        collectionsRefreshIntervalProvider.overrideWithValue(Duration.zero),
        syncRunnerProvider.overrideWithValue(const NoopSyncRunner()),
        httpClientProvider.overrideWith((_) => client()),
      ];

  Future<ProviderContainer> pumpSheet(
    WidgetTester tester, {
    bool purchaseLink = true,
    Locale locale = const Locale('ro'),
    Size? size,
  }) async {
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(buildTestApp(
      overrides: overrides(purchaseLink: purchaseLink),
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              key: const Key('open'),
              onPressed: () => showJoinCollectionSheet(ctx, initialCode: code),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('open'))));
    await container.read(plantlyAuthProvider.notifier).current();
    await container.read(collectionLinkProvider.notifier).ready;
    await container.read(joinParkingProvider.notifier).ready;
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(JoinCollectionSheet), findsOneWidget);
    return container;
  }

  Future<String?> parkedInPrefs() async => (await SharedPreferences.getInstance()).getString(JoinParking.codeKey);

  Future<void> seedPark({String user = 'u-3', ParkReason reason = ParkReason.cloudRequired, Duration age = Duration.zero}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(JoinParking.codeKey, code);
    await prefs.setInt(JoinParking.atKey, DateTime.now().toUtc().subtract(age).millisecondsSinceEpoch);
    await prefs.setString(JoinParking.userKey, user);
    await prefs.setString(JoinParking.reasonKey, reason.name);
  }

  testWidgets('not entitled (ro, desktop): note up front; Join → requirement step, invite parked, no /join; subscribe link + retry + dismiss',
      (tester) async {
    final c = await pumpSheet(tester);
    expect(find.byKey(const Key('join-cloud-required-note')), findsOneWidget);
    expect(find.text('Inventory Cloud este necesar pentru colecțiile partajate'), findsOneWidget);
    expect(c.read(openJoinSheetsProvider), 1);

    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsOneWidget);
    expect(find.byKey(const Key('join-cloud-required-body')), findsOneWidget);
    expect(find.textContaining('Fiecare membru al unei colecții partajate are nevoie de propriul plan Inventory Cloud'),
        findsOneWidget);
    expect(find.text('Inclus în Plantly Pro sau Plantly Inventory Cloud'), findsOneWidget, reason: 'Pro note');
    expect(find.text('Invitația ABCD-EFGH e păstrată pe acest dispozitiv 7 zile.'), findsOneWidget);
    expect(find.byKey(const Key('join-cloud-subscribe')), findsOneWidget);
    expect(find.text('Abonează-te pe plantly.ro'), findsOneWidget);
    expect(find.text('Reîncearcă'), findsOneWidget);
    expect(find.text('Renunță'), findsOneWidget);
    expect(find.byKey(const Key('join-collection-code')), findsNothing, reason: 'the step replaces the form');
    expect(paths('/inventory/collections/join'), isEmpty, reason: 'known not entitled: no request, invite untouched');
    expect(c.read(joinParkingProvider),
        const ParkedJoin(code: code, reason: ParkReason.cloudRequired, userId: 'u-3'));
    expect(await parkedInPrefs(), code);
  });

  testWidgets('not entitled (en, Android): policy copy, NO subscribe link; retry while still not entitled says so',
      (tester) async {
    final c = await pumpSheet(tester, purchaseLink: false, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsOneWidget);
    expect(find.text('Inventory Cloud is required for shared collections'), findsOneWidget);
    expect(find.byKey(const Key('join-cloud-subscribe')), findsNothing);
    expect(find.textContaining('plantly.ro'), findsNothing, reason: 'Play policy: no purchase pointer');
    expect(find.text('Included with Plantly Pro or Plantly Inventory Cloud'), findsOneWidget);
    expect(find.byKey(const Key('join-cloud-retry')), findsOneWidget);
    expect(find.byKey(const Key('join-cloud-dismiss')), findsOneWidget);

    await tester.tap(find.byKey(const Key('join-cloud-retry')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsOneWidget);
    expect(find.byKey(const Key('join-cloud-still-required')), findsOneWidget);
    expect(find.text('Your plan is not active yet.'), findsOneWidget);
    expect(paths('/inventory/collections/join'), isEmpty);
    expect(c.read(joinParkingProvider)?.code, code);
  });

  testWidgets('server 402 cloud_required (client thought it was entitled) → same step, parked; Try again after subscribing → joined, cleared',
      (tester) async {
    entitlement.value = const CloudEntitlement(active: true, source: 'pro');
    serverEntitled = false;
    final c = await pumpSheet(tester);
    expect(find.byKey(const Key('join-cloud-required-note')), findsNothing);
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(paths('/inventory/collections/join'), hasLength(1));
    expect(find.byKey(const Key('join-cloud-required')), findsOneWidget);
    expect(c.read(joinParkingProvider)?.code, code);
    expect(await parkedInPrefs(), code);

    serverEntitled = true;
    await tester.tap(find.byKey(const Key('join-cloud-retry')));
    await pumpFrames(tester, 30);
    await tester.pumpAndSettle();
    expect(paths('/inventory/collections/join'), hasLength(2));
    expect(find.byKey(const Key('join-cloud-required')), findsNothing);
    expect(find.byKey(const Key('join-collection-title')), findsNothing, reason: 'closed on success');
    expect(find.text('Te-ai alăturat colecției Office jungle'), findsOneWidget);
    expect(c.read(joinParkingProvider), isNull);
    expect(await parkedInPrefs(), isNull);
    expect(c.read(openJoinSheetsProvider), 0);
    expect(c.read(currentTenantIdProvider), 'col-3');
  });

  testWidgets('402 cloud_required_owner on join → a plain error (the owner\'s plan), nothing parked', (tester) async {
    entitlement.value = const CloudEntitlement(active: true, source: 'pro');
    serverEntitled = false;
    joinErrorCode = 'cloud_required_owner';
    final c = await pumpSheet(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsNothing);
    expect(tester.widget<TextField>(find.byKey(const Key('join-collection-code'))).decoration!.errorText,
        contains('owner’s plan lapsed'));
    expect(c.read(joinParkingProvider), isNull);
  });

  testWidgets('entitlement flips to active while the step is showing → the join resumes by itself', (tester) async {
    final c = await pumpSheet(tester);
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsOneWidget);
    expect(paths('/inventory/collections/join'), isEmpty);

    entitlement.value = const CloudEntitlement(active: true, source: 'pro');
    unawaited(c.read(cloudEntitlementProvider.notifier).refresh());
    await pumpFrames(tester, 40);
    await tester.pumpAndSettle();
    expect(paths('/inventory/collections/join'), hasLength(1));
    expect(find.byKey(const Key('join-collection-title')), findsNothing);
    expect(find.byKey(const Key('join-cloud-required')), findsNothing);
    expect(c.read(joinParkingProvider), isNull);
    expect(c.read(currentTenantIdProvider), 'col-3');
  });

  testWidgets('"Not now" clears the parked invite and closes', (tester) async {
    final c = await pumpSheet(tester);
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(c.read(joinParkingProvider)?.code, code);
    await tester.tap(find.byKey(const Key('join-cloud-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('join-cloud-required')), findsNothing);
    expect(find.byKey(const Key('join-collection-title')), findsNothing);
    expect(c.read(joinParkingProvider), isNull);
    expect(await parkedInPrefs(), isNull);
    expect(c.read(openJoinSheetsProvider), 0);
  });

  testWidgets('P2-a: a terminal failure after a park (404 invite_invalid) clears it and returns to the form with the error',
      (tester) async {
    entitlement.value = const CloudEntitlement(active: true, source: 'pro');
    serverEntitled = false;
    final c = await pumpSheet(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsOneWidget);
    expect(c.read(joinParkingProvider)?.code, code);

    joinErrorCode = 'invite_invalid';
    joinErrorStatus = 404;
    await tester.tap(find.byKey(const Key('join-cloud-retry')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsNothing, reason: 'nothing left to wait for');
    expect(tester.widget<TextField>(find.byKey(const Key('join-collection-code'))).decoration!.errorText,
        contains('invite'));
    expect(c.read(joinParkingProvider), isNull);
    expect(await parkedInPrefs(), isNull);
  });

  testWidgets('P2-a: a network error keeps the park (and the step, with the line)', (tester) async {
    final c = await pumpSheet(tester, locale: const Locale('en'));
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(c.read(joinParkingProvider)?.code, code);
    // Entitled now, but the server is unreachable.
    entitlement.value = const CloudEntitlement(active: true, source: 'pro');
    c.read(httpClientProvider); // keep the provider alive while swapping below
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('open'))));
    expect(identical(container, c), isTrue);
    offlineJoin = true;
    await tester.tap(find.byKey(const Key('join-cloud-retry')));
    await pumpFrames(tester);
    expect(find.byKey(const Key('join-cloud-required')), findsOneWidget);
    expect(find.byKey(const Key('join-cloud-error')), findsOneWidget);
    expect(c.read(joinParkingProvider)?.code, code, reason: 'offline: keep the invite for next time');
  });

  testWidgets('P1: alice parks → signs out → bob (entitled) signs in: zero /join, parking null', (tester) async {
    final c = await pumpSheet(tester);
    await tester.tap(find.byKey(const Key('join-collection-submit')));
    await pumpFrames(tester);
    expect(c.read(joinParkingProvider)?.userId, 'u-3');
    // Close the sheet without dismissing the park (swipe/back).
    Navigator.of(tester.element(find.byKey(const Key('join-cloud-required')))).pop();
    await tester.pumpAndSettle();
    expect(c.read(joinParkingProvider)?.code, code, reason: 'a plain close keeps the park');

    final auth = c.read(plantlyAuthProvider.notifier);
    await tester.runAsync(() => auth.signOut());
    await pumpFrames(tester);
    expect(c.read(joinParkingProvider), isNull, reason: 'sign-out drops alice\'s park');

    entitlement.value = const CloudEntitlement(active: true, source: 'pro');
    await tester.runAsync(() => auth.adoptToken(bobToken));
    await pumpFrames(tester, 30);
    await tester.pumpAndSettle();
    expect(paths('/inventory/collections/join'), isEmpty);
    expect(c.read(joinParkingProvider), isNull);
    expect(await parkedInPrefs(), isNull);
  });

  // #29: the desktop side sheet's SheetChrome header already shows the
  // title + subtitle; the body must not repeat them. Phone keeps its
  // in-body title (no header there).
  group('title / subtitle exactly once (#29)', () {
    const phone = Size(390, 844);
    const desktop = Size(1280, 960);
    const joinTitle = 'Alătură-te unei colecții partajate';
    const joinBody = 'Introdu codul de 8 caractere din invitația primită.';
    const reqTitle = 'Inventory Cloud este necesar pentru colecțiile partajate';

    for (final (label, size) in [('phone', phone), ('desktop', desktop)]) {
      final isDesktop = size == desktop;

      testWidgets('join form ($label)', (tester) async {
        entitlement.value = const CloudEntitlement(active: true, source: 'pro');
        await pumpSheet(tester, size: size);
        expect(find.byType(SideSheetPanel), isDesktop ? findsOneWidget : findsNothing);
        expect(find.byType(BottomSheet), isDesktop ? findsNothing : findsOneWidget);
        expect(find.text(joinTitle), findsOneWidget);
        expect(find.text(joinBody), findsOneWidget);
        expect(find.byKey(const Key('join-collection-title')), isDesktop ? findsNothing : findsOneWidget);
        expect(find.byKey(const Key('join-collection-code')), findsOneWidget);
        expect(find.byKey(const Key('join-collection-submit')), findsOneWidget);
      });

      testWidgets('requirement step ($label)', (tester) async {
        await pumpSheet(tester, size: size);
        await tester.tap(find.byKey(const Key('join-collection-submit')));
        await pumpFrames(tester);
        expect(find.byKey(const Key('join-cloud-retry')), findsOneWidget, reason: 'on the requirement step');
        expect(find.text(reqTitle), findsOneWidget);
        expect(find.textContaining('Fiecare membru al unei colecții partajate are nevoie de propriul plan Inventory Cloud'),
            findsOneWidget);
        expect(find.byKey(const Key('join-cloud-required')), isDesktop ? findsNothing : findsOneWidget);
        expect(find.byKey(const Key('join-cloud-required-body')), isDesktop ? findsNothing : findsOneWidget);
        expect(find.byKey(const Key('join-cloud-parked')), findsOneWidget);
      });
    }

    testWidgets('requirement step (desktop, ro): header title wraps, no ellipsis / overflow, semantic header',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSheet(tester, size: desktop);
      await tester.tap(find.byKey(const Key('join-collection-submit')));
      await pumpFrames(tester);
      final title = find.text(reqTitle);
      expect(title, findsOneWidget);
      final p = tester.renderObject<RenderParagraph>(title);
      expect(p.didExceedMaxLines, isFalse, reason: 'full title, no ellipsis');
      expect(p.size.height, greaterThan(30), reason: 'the long ro title takes two lines');
      expect(tester.getSemantics(title), isSemantics(isHeader: true));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  group('HandoffListener resume', () {
    late FakeIncomingLinks links;
    Future<ProviderContainer> pumpApp(WidgetTester tester, {required bool sheetAlreadyOpen}) async {
      addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
      links = FakeIncomingLinks();
      addTearDown(links.dispose);
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(buildTestApp(
        overrides: [
          ...overrides(),
          incomingLinksProvider.overrideWithValue(links),
          if (sheetAlreadyOpen) openJoinSheetsProvider.overrideWith((_) => 1),
        ],
        child: MaterialApp(
          navigatorKey: navKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => HandoffListener(navigatorKey: navKey, child: child!),
          home: Consumer(builder: (context, ref, _) {
            ref.watch(appContextProvider);
            return const Scaffold(body: Text('home', key: Key('home')));
          }),
        ),
      ));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('home'))));
      await container.read(plantlyAuthProvider.notifier).current();
      await container.read(joinParkingProvider.notifier).ready;
      return container;
    }

    testWidgets('parked code + plan turns active → the join sheet reopens with the code and submits by itself', (tester) async {
      await seedPark();
      final c = await pumpApp(tester, sheetAlreadyOpen: false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join-collection-title')), findsNothing, reason: 'not entitled yet: nothing happens');
      expect(c.read(joinParkingProvider)?.code, code);

      entitlement.value = const CloudEntitlement(active: true, source: 'pro');
      await tester.runAsync(() => c.read(cloudEntitlementProvider.notifier).refresh());
      await pumpFrames(tester, 30);
      await tester.pumpAndSettle();
      expect(paths('/inventory/collections/join'), hasLength(1), reason: 'resumed and submitted');
      expect(find.byKey(const Key('join-collection-title')), findsNothing, reason: 'closed on success');
      expect(c.read(joinParkingProvider), isNull);
      expect(c.read(currentTenantIdProvider), 'col-3');
    });

    testWidgets('P1: another account\'s park (alice) never resumes for bob; the Cloud-screen row stays hidden for him',
        (tester) async {
      await seedPark(user: 'u-1');
      entitlement.value = const CloudEntitlement(active: true, source: 'pro');
      final c = await pumpApp(tester, sheetAlreadyOpen: false);
      await pumpFrames(tester, 20);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join-collection-title')), findsNothing);
      expect(paths('/inventory/collections/join'), isEmpty);
      expect(c.read(parkedJoinForSessionProvider), isNull, reason: 'what the Cloud screen row reads');
    });

    testWidgets('P2-b: a gated park replays as a prefilled form — no auto-join, even when entitled', (tester) async {
      await seedPark(reason: ParkReason.gated);
      entitlement.value = const CloudEntitlement(active: true, source: 'pro');
      final c = await pumpApp(tester, sheetAlreadyOpen: false);
      await pumpFrames(tester, 20);
      expect(find.byKey(const Key('join-collection-title')), findsNothing, reason: 'gated parks are not resumed by the listener');
      links.emit(Uri.parse('plantlyinventory://join#c=$code'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join-collection-title')), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('join-collection-code'))).controller!.text, code);
      expect(paths('/inventory/collections/join'), isEmpty, reason: 'form only, user taps Join');
      expect(tester.widget<FilledButton>(find.byKey(const Key('join-collection-submit'))).onPressed, isNotNull);
      expect(c.read(joinParkingProvider)?.reason, ParkReason.gated);
    });

    testWidgets('a join sheet already on screen resumes alone — the listener does not open a second one', (tester) async {
      await seedPark();
      final c = await pumpApp(tester, sheetAlreadyOpen: true);
      entitlement.value = const CloudEntitlement(active: true, source: 'pro');
      await tester.runAsync(() => c.read(cloudEntitlementProvider.notifier).refresh());
      await pumpFrames(tester, 20);
      expect(find.byKey(const Key('join-collection-title')), findsNothing);
      expect(paths('/inventory/collections/join'), isEmpty);
      expect(c.read(joinParkingProvider)?.code, code, reason: 'left for the open sheet');
    });

    testWidgets('expired parked code (> 7 days) is dropped, nothing resumes', (tester) async {
      await seedPark(age: const Duration(days: 8));
      entitlement.value = const CloudEntitlement(active: true, source: 'pro');
      final c = await pumpApp(tester, sheetAlreadyOpen: false);
      await pumpFrames(tester, 20);
      expect(c.read(joinParkingProvider), isNull);
      expect(find.byKey(const Key('join-collection-title')), findsNothing);
      expect(paths('/inventory/collections/join'), isEmpty);
    });
  });
}
