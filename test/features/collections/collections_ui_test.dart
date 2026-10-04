import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plantly_inventory/cloud/cloud_state.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/collections/sharing_rows.dart';
import 'package:plantly_inventory/features/home/widgets/activity_widget.dart';
import 'package:plantly_inventory/features/me/cloud_screen.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/main.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/plantly_auth.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;

const _mine = CloudCollection(id: 'col-1', name: 'My plants', role: 'owner', ownerUserId: 'u-1', memberCount: 2);
const _shared = CloudCollection(id: 'col-2', name: 'Family greenhouse', role: 'editor', ownerUserId: 'u-2', memberCount: 3);

const _ready = CloudState(phase: CloudPhase.ready, account: 'alice', collectionId: 'col-1', collectionName: 'My plants');

List<Override> _collections(List<CloudCollection> items,
        {CloudCollection? active, bool cloud = true, bool callerEntitled = true}) =>
    [
      cloudEnabledProvider.overrideWithValue(cloud),
      collectionsProvider.overrideWith(
          (ref) => CollectionsNotifier(ref, autoStart: false, initial: items, callerEntitled: callerEntitled)),
      activeCollectionProvider.overrideWithValue(active ?? (items.isEmpty ? null : items.first)),
      activeCollectionIdProvider.overrideWithValue((active ?? (items.isEmpty ? null : items.first))?.id),
      syncRunnerProvider.overrideWithValue(const NoopSyncRunner()),
    ];

void main() {
  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  /// The phone grid has a pre-existing 1.1 px overflow (see the golden
  /// test's `_tolerateOverflow`); not what these tests are about.
  void tolerateOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed by')) return;
      prev?.call(details);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> pumpApp(WidgetTester tester, Size size, List<Override> overrides, {String location = '/'}) async {
    tolerateOverflow();
    SharedPreferences.setMockInitialValues({
      'plantly_onboarded': true,
      'plantly_layout': '["stats","grid","activity"]',
    });
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(buildTestApp(overrides: overrides, child: PlantlyApp(initialLocation: location)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
  }

  /// [scroll] false = [child] is a full screen (its own Scaffold). The
  /// whole ProviderScope subtree is keyed per pump so a re-pump within one
  /// test gets fresh overrides and a fresh Navigator (no sheet lingering).
  Future<void> pumpBare(WidgetTester tester, Widget child, List<Override> overrides, {bool scroll = true}) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    await tester.pumpWidget(KeyedSubtree(
      key: UniqueKey(),
      child: buildTestApp(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: scroll ? Scaffold(body: SingleChildScrollView(child: child)) : child,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('switcher visibility', () {
    for (final (label, items) in [('0 collections', <CloudCollection>[]), ('1 collection', [_mine])]) {
      testWidgets('phone + desktop: hidden with $label', (tester) async {
        await pumpApp(tester, phone, _collections(items));
        expect(find.byKey(const Key('collection-switcher-chip')), findsNothing);
        await pumpApp(tester, desktop, _collections(items));
        expect(find.byKey(const Key('collection-switcher-dropdown')), findsNothing);
        expect(find.byKey(const Key('active-collection-label')), findsNothing);
      });
    }

    testWidgets('flag off: hidden even with 2 collections', (tester) async {
      await pumpApp(tester, phone, _collections([_mine, _shared], cloud: false));
      expect(find.byKey(const Key('collection-switcher-chip')), findsNothing);
    });

    testWidgets('phone with 2: chip shows the active name; sheet lists mine / shared with roles + join', (tester) async {
      await pumpApp(tester, phone, _collections([_mine, _shared]));
      final chip = find.byKey(const Key('collection-switcher-chip'));
      expect(chip, findsOneWidget);
      expect(find.descendant(of: chip, matching: find.text('My plants')), findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-switcher-sheet-title')), findsOneWidget);
      expect(find.text('MY COLLECTIONS'), findsOneWidget);
      expect(find.text('SHARED WITH ME'), findsOneWidget);
      expect(find.byKey(const Key('collection-tile-col-1')), findsOneWidget);
      expect(find.byKey(const Key('collection-tile-col-2')), findsOneWidget);
      expect(find.byKey(const Key('collection-active-col-1')), findsOneWidget);
      expect(find.byKey(const Key('collection-active-col-2')), findsNothing);
      expect(find.text('Owner'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('3 members'), findsOneWidget);
      expect(find.byKey(const Key('collection-join-with-code')), findsOneWidget);
      await tester.tap(find.byKey(const Key('collection-join-with-code')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('join-collection-title')), findsOneWidget);
    });

    testWidgets('§8: caller_entitled=false → "Needs Inventory Cloud" marker on shared collections only (sheet + dropdown)',
        (tester) async {
      await pumpApp(tester, phone, _collections([_mine, _shared], callerEntitled: false));
      await tester.tap(find.byKey(const Key('collection-switcher-chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-needs-cloud-col-2')), findsOneWidget);
      expect(find.byKey(const Key('collection-needs-cloud-col-1')), findsNothing, reason: 'own collection: no marker');
      expect(find.text('Needs Inventory Cloud'), findsOneWidget);
      expect(find.byKey(const Key('collection-paused-col-2')), findsNothing, reason: 'owner is fine');
      // Still switchable (read-only there).
      await tester.tap(find.byKey(const Key('collection-tile-col-2')));
      await tester.pumpAndSettle();

      await pumpApp(tester, desktop, _collections([_mine, _shared], callerEntitled: false));
      await tester.tap(find.byKey(const Key('collection-switcher-dropdown')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-needs-cloud-col-2')), findsWidgets);
      expect(find.byKey(const Key('collection-needs-cloud-col-1')), findsNothing);
    });

    testWidgets('§8: client verdict alone (notEntitled, flag absent) → marker on shared collections', (tester) async {
      const notEntitled = CloudState(phase: CloudPhase.notEntitled, account: 'alice', collectionId: 'col-1');
      await pumpApp(tester, phone, [
        ..._collections([_mine, _shared]),
        cloudStateProvider.overrideWithValue(notEntitled),
      ]);
      await tester.tap(find.byKey(const Key('collection-switcher-chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-needs-cloud-col-2')), findsOneWidget);
      expect(find.byKey(const Key('collection-needs-cloud-col-1')), findsNothing);
    });

    testWidgets('§8: entitled (or an older server without the flag) → no "Needs Inventory Cloud" marker', (tester) async {
      await pumpApp(tester, phone, _collections([_mine, _shared]));
      await tester.tap(find.byKey(const Key('collection-switcher-chip')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('collection-tile-col-2')), findsOneWidget);
      expect(find.byKey(const Key('collection-needs-cloud-col-2')), findsNothing);
      expect(find.text('Needs Inventory Cloud'), findsNothing);
    });

    testWidgets('desktop with 2: dropdown under the logo + active name in the Home toolbar', (tester) async {
      await pumpApp(tester, desktop, _collections([_mine, _shared], active: _shared));
      expect(find.byKey(const Key('collection-switcher-dropdown')), findsOneWidget);
      final label = find.byKey(const Key('active-collection-label'));
      expect(label, findsOneWidget);
      expect(find.descendant(of: label, matching: find.text('Family greenhouse')), findsOneWidget);
      await tester.tap(find.byKey(const Key('collection-switcher-dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('Join with code…'), findsOneWidget);
      expect(find.text('My plants'), findsWidgets);
    });
  });

  group('Sharing rows (Me → Cloud)', () {
    testWidgets('owner: Invite + Members + Join, no Leave; nothing while the device cannot sync', (tester) async {
      await pumpBare(tester, SharingRows(surface: PlantlySurface.light), [
        ..._collections([_mine, _shared]),
        cloudStateProvider.overrideWithValue(_ready),
      ]);
      expect(find.byKey(const Key('share-rows')), findsOneWidget);
      expect(find.text('My plants · Owner'), findsOneWidget);
      expect(find.byKey(const Key('share-invite')), findsOneWidget);
      expect(find.byKey(const Key('share-members')), findsOneWidget);
      expect(find.byKey(const Key('share-join')), findsOneWidget);
      expect(find.byKey(const Key('share-leave')), findsNothing);

      await pumpBare(tester, SharingRows(surface: PlantlySurface.light), [
        ..._collections([_mine, _shared]),
        cloudStateProvider.overrideWithValue(const CloudState(phase: CloudPhase.notEntitled, account: 'alice')),
      ]);
      expect(find.byKey(const Key('share-rows')), findsNothing);
    });

    testWidgets('editor on a shared collection: Leave + Members, no Invite', (tester) async {
      await pumpBare(tester, SharingRows(surface: PlantlySurface.light), [
        ..._collections([_mine, _shared], active: _shared),
        cloudStateProvider.overrideWithValue(_ready),
      ]);
      expect(find.text('Family greenhouse · Editor'), findsOneWidget);
      expect(find.byKey(const Key('share-invite')), findsNothing);
      expect(find.byKey(const Key('share-leave')), findsOneWidget);
      expect(find.byKey(const Key('share-members')), findsOneWidget);
      await tester.tap(find.byKey(const Key('share-leave')));
      await tester.pumpAndSettle();
      expect(find.text('Leave Family greenhouse?'), findsOneWidget);
      expect(find.byKey(const Key('share-leave-confirm')), findsOneWidget);
    });

    testWidgets('CloudScreen embeds the Sharing rows; Me section summary row only with > 1 collection', (tester) async {
      await pumpBare(tester, const CloudScreen(), [
        ..._collections([_mine, _shared]),
        cloudStateProvider.overrideWithValue(_ready),
      ], scroll: false);
      expect(find.byType(SharingRows), findsOneWidget);
      expect(find.byKey(const Key('share-rows')), findsOneWidget);

      await pumpBare(tester, SharingSummaryRow(surface: PlantlySurface.light, onTap: () {}), _collections([_mine]));
      expect(find.byKey(const Key('share-summary')), findsNothing);
      await pumpBare(tester, SharingSummaryRow(surface: PlantlySurface.light, onTap: () {}), _collections([_mine, _shared]));
      expect(find.byKey(const Key('share-summary')), findsOneWidget);
      expect(find.text('2 collections'), findsOneWidget);
    });

    testWidgets('Invite someone: POST invites → code + link, Copy and Share carry url + code + 7-day note', (tester) async {
      final token = fakeJwt(iat: 1, exp: 4102444800);
      final shared = <String>[];
      final log = <http.Request>[];
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await pumpBare(tester, SharingRows(surface: PlantlySurface.light), [
        ..._collections([_mine, _shared]),
        cloudStateProvider.overrideWithValue(_ready),
        sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
        shareTextProvider.overrideWithValue((text, {subject}) async => shared.add(text)),
        httpClientProvider.overrideWith((_) => MockClient((req) async {
              log.add(req);
              return http.Response(
                json.encode({'code': 'BCDFGHJK', 'url': 'https://plantly.ro/app/inventory/join#c=BCDFGHJK', 'expires_at': '2026-10-04T10:00:00Z'}),
                201,
              );
            })),
      ]);
      await tester.tap(find.byKey(const Key('share-invite')));
      await tester.pumpAndSettle();
      expect(log, isEmpty, reason: 'v2 shows the form first; nothing is minted until Create');
      await tester.tap(find.byKey(const Key('invite-create')));
      await tester.pumpAndSettle();
      expect(log.single.method, 'POST');
      expect(json.decode(log.single.body), {'role': 'editor', 'max_uses': 1, 'ttl_days': 7});
      expect(log.single.url.path, '/api/v1/inventory/collections/col-1/invites');
      expect(find.text('Invite to My plants'), findsWidgets);
      expect(find.text('BCDF-GHJK'), findsOneWidget);
      expect(find.byKey(const Key('invite-url')), findsOneWidget);
      // The result line is role · uses; the TTL is shown as the expiry date.
      expect(find.text('Editor · single use'), findsOneWidget);
      expect(find.textContaining('7 days'), findsNothing);
      expect(find.textContaining('2026'), findsOneWidget, reason: 'expires_at rendered as a date');
      await tester.tap(find.byKey(const Key('invite-share')));
      await tester.pumpAndSettle();
      expect(shared.single, contains('https://plantly.ro/app/inventory/join#c=BCDFGHJK'));
      expect(shared.single, contains('BCDFGHJK'));
      expect(shared.single, contains('My plants'));
      await tester.tap(find.byKey(const Key('invite-copy')));
      await tester.pumpAndSettle();
      expect(clipboard, shared.single);
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('Members: owner can remove others (not self); editor sees Leave on own row', (tester) async {
      final token = fakeJwt(iat: 1, exp: 4102444800);
      final log = <http.Request>[];
      List<Override> withMembers(CloudCollection active) => [
            ..._collections([_mine, _shared], active: active),
            cloudStateProvider.overrideWithValue(_ready),
            sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
            httpClientProvider.overrideWith((_) => MockClient((req) async {
                  log.add(req);
                  if (req.method == 'DELETE') return http.Response('', 204);
                  if (req.url.path.endsWith('/inventory/collections')) {
                    return http.Response(json.encode({'collections': []}), 200);
                  }
                  if (req.url.path.endsWith('/invites')) return http.Response(json.encode({'invites': []}), 200);
                  return http.Response(
                    json.encode({
                      'members': [
                        {'user_id': active.ownerUserId, 'username': active.isOwner ? 'alice' : 'bob', 'role': 'owner', 'joined_at': '2026-09-01T10:00:00Z'},
                        {'user_id': active.isOwner ? 'u-2' : 'u-1', 'username': active.isOwner ? 'bob' : 'alice', 'role': 'editor', 'joined_at': '2026-09-20T10:00:00Z'},
                      ]
                    }),
                    200,
                  );
                })),
          ];

      await pumpBare(tester, SharingRows(surface: PlantlySurface.light), withMembers(_mine));
      await tester.tap(find.byKey(const Key('share-members')));
      await tester.pumpAndSettle();
      expect(find.text('Members of My plants'), findsWidgets);
      expect(find.text('alice (you)'), findsOneWidget);
      expect(find.text('bob'), findsOneWidget);
      expect(find.byKey(const Key('member-menu-u-1')), findsNothing, reason: 'no actions on self');
      expect(find.byKey(const Key('member-menu-u-2')), findsOneWidget);
      expect(find.byKey(const Key('member-leave')), findsNothing);
      await tester.tap(find.byKey(const Key('member-menu-u-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-remove-u-2')), findsOneWidget);
      await tester.tap(find.byKey(const Key('member-remove-u-2')));
      await tester.pumpAndSettle();
      expect(find.text('Remove bob?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('member-remove-confirm')));
      await tester.pumpAndSettle();
      expect(log.any((r) => r.method == 'DELETE' && r.url.path.endsWith('/inventory/collections/col-1/members/u-2')), isTrue);

      await pumpBare(tester, SharingRows(surface: PlantlySurface.light), withMembers(_shared));
      await tester.tap(find.byKey(const Key('share-members')));
      await tester.pumpAndSettle();
      expect(find.text('bob'), findsOneWidget);
      expect(find.text('alice (you)'), findsOneWidget);
      expect(find.byKey(const Key('member-menu-u-2')), findsNothing, reason: 'editors remove nobody');
      expect(find.byKey(const Key('member-leave')), findsOneWidget);
    });
  });

  group('who did what', () {
    CareEventRow event(String id, String? actor) => CareEventRow(
          id: id,
          tenantId: 'col-1',
          plantId: 'p-$id',
          type: 'water',
          doneAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          notes: null,
          dose: null,
          product: null,
          photoSha: null,
          updatedHlc: '0-0-t',
          deletedAt: null,
          deviceId: 't',
          actorUserId: actor,
        );

    testWidgets('Activity rows show "· by <username>" for other members, nothing for me, fallback when unknown', (tester) async {
      await pumpBare(tester, ActivityWidget(surface: PlantlySurface.light), [
        cloudEnabledProvider.overrideWithValue(true),
        currentUserIdProvider.overrideWithValue('u-1'),
        recentCareEventsProvider.overrideWith((ref) => Stream.value([event('a', 'u-2'), event('b', 'u-1'), event('c', 'u-9'), event('d', null)])),
        membersProvider.overrideWith((ref, id) async => [
              CollectionMember(userId: 'u-2', username: 'bob', role: 'owner'),
              CollectionMember(userId: 'u-1', username: 'alice', role: 'editor'),
            ]),
      ]);
      expect(find.textContaining('· by bob'), findsOneWidget);
      expect(find.textContaining('· by another member'), findsOneWidget);
      expect(find.textContaining('by alice'), findsNothing, reason: 'my own rows are not attributed');
      expect(find.textContaining('by '), findsNWidgets(2));
    });

    testWidgets('flag off → no attribution at all', (tester) async {
      await pumpBare(tester, ActivityWidget(surface: PlantlySurface.light), [
        cloudEnabledProvider.overrideWithValue(false),
        currentUserIdProvider.overrideWithValue('u-1'),
        recentCareEventsProvider.overrideWith((ref) => Stream.value([event('a', 'u-2')])),
        membersProvider.overrideWith((ref, id) async => [CollectionMember(userId: 'u-2', username: 'bob', role: 'owner')]),
      ]);
      expect(find.textContaining('by '), findsNothing);
    });
  });

  testWidgets('/join?c= lands on Home and opens the join sheet with the code', (tester) async {
    await pumpApp(
      tester,
      phone,
      [
        ..._collections([_mine]),
        incomingLinksProvider.overrideWithValue(FakeIncomingLinks(initialUri: Uri.parse('https://inventory.plantly.ro/join?c=BCDFGHJK'))),
      ],
      location: '/join?c=BCDFGHJK',
    );
    expect(find.byKey(const Key('join-collection-title')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('join-collection-code'))).controller!.text, 'BCDFGHJK');
  });
}
