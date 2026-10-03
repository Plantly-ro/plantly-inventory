// Activity screen copy + widgets (MULTI-USER-V2 §3), the plant-detail
// "last edited by" line, the Cloud screen entry row and the shared-access
// copy on the Cloud section.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:plantly_inventory/app/navigation.dart';
import 'package:plantly_inventory/cloud/collection_activity.dart';
import 'package:plantly_inventory/cloud/collection_link.dart';
import 'package:plantly_inventory/cloud/cloud_sync.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/cloud/entitlement.dart';
import 'package:plantly_inventory/cloud/sync_runner.dart';
import 'package:plantly_inventory/config/plantly_features.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/collections/collection_activity_screen.dart';
import 'package:plantly_inventory/features/me/cloud_screen.dart';
import 'package:plantly_inventory/features/me/cloud_section.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/marketplace/session_store.dart';
import 'package:plantly_inventory/theme/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cloud/cloud_state_test.dart' show FixedEntitlement;
import '../../cloud/collection_activity_test.dart' show ev;
import '../../helpers/test_app.dart';
import '../../marketplace/plantly_session_test.dart' show fakeJwt;
import '../me/cloud_section_test.dart' show RecordingRunner;

/// Feed notifier with a fixed state and no network; counts the actions.
class SeededActivity extends CollectionActivityNotifier {
  SeededActivity(super.ref, super.id, ActivityFeedState seed) : super(autoStart: false) {
    state = seed;
  }
  int refreshes = 0;
  int loadMores = 0;

  @override
  Future<void> refresh() async => refreshes++;

  @override
  Future<void> loadMore() async => loadMores++;
}

void main() {
  // Pure-Dart copy tests format dates without the Material delegates.
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ro');
  });

  final en = AppLocalizationsEn();
  final ro = AppLocalizationsRo();
  final now = DateTime.utc(2026, 10, 3, 12);

  const shared = CloudCollection(id: 'col-2', name: 'Family greenhouse', role: 'editor', ownerUserId: 'u-2', memberCount: 3);
  const mineShared = CloudCollection(id: 'col-1', name: 'My plants', role: 'owner', ownerUserId: 'u-1', memberCount: 2);
  const private = CloudCollection(id: 'col-1', name: 'My plants', role: 'owner', ownerUserId: 'u-1', memberCount: 1);

  group('copy', () {
    test('isSharedCollection: >1 member or not owner', () {
      expect(isSharedCollection(shared), isTrue);
      expect(isSharedCollection(mineShared), isTrue);
      expect(isSharedCollection(private), isFalse);
      expect(isSharedCollection(null), isFalse);
    });

    test('entity × kind, named (en/ro)', () {
      String en_(String entity, ActivityKind k) => describeActivityEvent(en, ev(1, entity: entity, kind: k, name: 'Monstera'));
      String ro_(String entity, ActivityKind k) => describeActivityEvent(ro, ev(1, entity: entity, kind: k, name: 'Monstera'));

      expect(en_('plants', ActivityKind.created), 'maria added Monstera');
      expect(ro_('plants', ActivityKind.created), 'maria a adăugat Monstera');
      expect(en_('plants', ActivityKind.updated), 'maria edited Monstera');
      expect(ro_('plants', ActivityKind.updated), 'maria a modificat Monstera');
      expect(en_('plants', ActivityKind.deleted), 'maria removed Monstera');
      expect(ro_('plants', ActivityKind.deleted), 'maria a șters Monstera');

      expect(en_('locations', ActivityKind.created), 'maria added the space Monstera');
      expect(ro_('locations', ActivityKind.created), 'maria a adăugat spațiul Monstera');
      expect(en_('care_schedules', ActivityKind.updated), 'maria edited a reminder for Monstera');
      expect(ro_('care_schedules', ActivityKind.updated), 'maria a modificat un memento pentru Monstera');
      expect(en_('care_events', ActivityKind.created), 'maria added a care entry for Monstera');
      expect(ro_('care_events', ActivityKind.created), 'maria a adăugat o îngrijire pentru Monstera');
      expect(en_('photos', ActivityKind.deleted), 'maria removed a photo of Monstera');
      expect(ro_('photos', ActivityKind.deleted), 'maria a șters o fotografie la Monstera');
      expect(en_('plant_photos', ActivityKind.created), 'maria added a photo of Monstera');
      expect(en_('tags', ActivityKind.created), 'maria added Monstera', reason: 'unknown entity with a name');
    });

    test('entity × kind, unnamed + unknown user (en/ro)', () {
      String en_(String entity) => describeActivityEvent(en, ev(1, entity: entity, name: null, username: ''));
      String ro_(String entity) => describeActivityEvent(ro, ev(1, entity: entity, name: null, username: ''));
      expect(en_('plants'), 'Another member added a plant');
      expect(ro_('plants'), 'Alt membru a adăugat o plantă');
      expect(en_('locations'), 'Another member added a space');
      expect(ro_('locations'), 'Alt membru a adăugat un spațiu');
      expect(en_('care_schedules'), 'Another member added a reminder');
      expect(ro_('care_schedules'), 'Alt membru a adăugat un memento');
      expect(en_('care_events'), 'Another member added a care entry');
      expect(ro_('care_events'), 'Alt membru a adăugat o îngrijire');
      expect(en_('photos'), 'Another member added a photo');
      expect(ro_('photos'), 'Alt membru a adăugat o fotografie');
      expect(en_('whatever'), 'Another member added an item');
      expect(ro_('whatever'), 'Alt membru a adăugat un element');
      // Blank name counts as unnamed.
      expect(describeActivityEvent(ro, ev(1, name: '  ')), 'maria a adăugat o plantă');
    });

    test('relative time (en/ro)', () {
      String en_(Duration d) => describeActivityTime(en, now.subtract(d), now: now);
      String ro_(Duration d) => describeActivityTime(ro, now.subtract(d), now: now);
      expect(en_(const Duration(seconds: 20)), 'just now');
      expect(ro_(const Duration(seconds: 20)), 'chiar acum');
      expect(en_(const Duration(minutes: 5)), '5 min ago');
      expect(ro_(const Duration(minutes: 5)), 'acum 5 min');
      expect(en_(const Duration(hours: 3)), '3 h ago');
      expect(ro_(const Duration(hours: 3)), 'acum 3 h');
      expect(en_(const Duration(days: 2)), '2 d ago');
      expect(ro_(const Duration(days: 2)), 'acum 2 z');
      expect(en_(const Duration(days: 30)), 'Sep 3');
      expect(ro_(const Duration(days: 30)), isNot(contains('ago')));
    });

    test('last edited by: excludes me, newest first, null when unknown', () {
      final events = [
        ev(10, userId: 'u-1', username: 'alice', entityId: 'p-1', kind: ActivityKind.updated, at: now),
        ev(8, userId: 'u-2', username: 'maria', entityId: 'p-1', kind: ActivityKind.updated,
            at: now.subtract(const Duration(minutes: 5))),
        ev(7, userId: 'u-3', username: 'ion', entityId: 'p-1', at: now.subtract(const Duration(hours: 2))),
      ];
      expect(describeLastEditedBy(ro, events, entityId: 'p-1', me: 'u-1', now: now),
          'Ultima modificare de maria · acum 5 min');
      expect(describeLastEditedBy(en, events, entityId: 'p-1', me: 'u-1', now: now), 'Last edited by maria · 5 min ago');
      expect(describeLastEditedBy(en, events, entityId: 'p-1', me: 'u-2', now: now), 'Last edited by alice · just now');
      expect(describeLastEditedBy(en, events, entityId: 'p-2', me: 'u-1', now: now), isNull);
      expect(describeLastEditedBy(en, const [], entityId: 'p-1', me: 'u-1', now: now), isNull);
    });

    test('last edited by without a timestamp → name only (en/ro)', () {
      const noTime = ActivityEvent(
        seq: 3,
        user: ActivityUser(id: 'u-2', username: 'maria'),
        entity: 'plants',
        entityId: 'p-1',
        kind: ActivityKind.updated,
      );
      expect(describeLastEditedBy(en, const [noTime], entityId: 'p-1', me: 'u-1', now: now), 'Last edited by maria');
      expect(describeLastEditedBy(ro, const [noTime], entityId: 'p-1', me: 'u-1', now: now), 'Ultima modificare de maria');
      expect(describeActivityEvent(ro, ev(1, username: '   ')), 'Alt membru a adăugat Monstera',
          reason: 'whitespace-only user = unknown');
    });

    test('route helper encodes the id', () {
      expect(AppRoutes.collectionActivity('col-2'), '/collections/col-2/activity');
      expect(AppRoutes.collectionActivity('a b'), '/collections/a%20b/activity');
    });
  });

  group('CollectionActivityScreen', () {
    late SeededActivity seeded;

    Future<void> pump(
      WidgetTester tester, {
      required ActivityFeedState feed,
      Locale locale = const Locale('ro'),
      List<CloudCollection> collections = const [shared],
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildTestApp(
        overrides: [
          cloudEnabledProvider.overrideWithValue(true),
          collectionsProvider.overrideWith((ref) => CollectionsNotifier(ref, autoStart: false, initial: collections)),
          collectionActivityProvider.overrideWith((ref, id) => seeded = SeededActivity(ref, id, feed)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CollectionActivityScreen(collectionId: 'col-2'),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('rows render user · action · relative time, newest first; collection name in the title', (tester) async {
      final feed = ActivityFeedState(
        loaded: true,
        events: [
          ev(12, at: DateTime.now().toUtc().subtract(const Duration(minutes: 5))),
          ev(11, entity: 'care_events', entityId: 'e-1', username: 'ion', name: 'Ficus',
              at: DateTime.now().toUtc().subtract(const Duration(hours: 3))),
          ev(10, entity: 'plants', entityId: 'p-9', kind: ActivityKind.deleted, name: null,
              at: DateTime.now().toUtc().subtract(const Duration(days: 2))),
        ],
      );
      await pump(tester, feed: feed);
      expect(find.text('Activitate'), findsOneWidget);
      expect(find.byKey(const Key('activity-collection-name')), findsOneWidget);
      expect(find.text('Family greenhouse'), findsOneWidget);
      expect(find.byKey(const Key('activity-list')), findsOneWidget);
      expect(find.text('maria a adăugat Monstera'), findsOneWidget);
      expect(find.text('acum 5 min'), findsOneWidget);
      expect(find.text('ion a adăugat o îngrijire pentru Ficus'), findsOneWidget);
      expect(find.text('acum 3 h'), findsOneWidget);
      expect(find.text('maria a șters o plantă'), findsOneWidget);
      expect(find.text('acum 2 z'), findsOneWidget);
      // Order on screen = seq desc.
      final y12 = tester.getTopLeft(find.byKey(const Key('activity-event-12'))).dy;
      final y10 = tester.getTopLeft(find.byKey(const Key('activity-event-10'))).dy;
      expect(y12, lessThan(y10));
      expect(find.byKey(const Key('activity-load-more')), findsNothing);
      expect(find.byKey(const Key('activity-offline-banner')), findsNothing);
    });

    testWidgets('row without a timestamp shows no time; blank user gets the neutral avatar glyph', (tester) async {
      const noTime = ActivityEvent(
        seq: 9,
        user: ActivityUser(id: 'u-9', username: ' '),
        entity: 'plants',
        entityId: 'p-1',
        kind: ActivityKind.created,
        summaryName: 'Monstera',
      );
      await pump(tester, feed: const ActivityFeedState(loaded: true, events: [noTime]), locale: const Locale('en'));
      expect(find.text('Another member added Monstera'), findsOneWidget);
      expect(find.textContaining('ago'), findsNothing);
      expect(find.text('just now'), findsNothing);
      expect(find.text('Jan 1'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('activity-event-9')), matching: find.text('?')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('activity-event-9')), matching: find.text('A')), findsNothing);
    });

    testWidgets('"Load more" when the server has older rows; tapping asks the notifier', (tester) async {
      await pump(tester, feed: ActivityFeedState(loaded: true, hasMore: true, events: [ev(5)]));
      expect(find.byKey(const Key('activity-load-more')), findsOneWidget);
      expect(find.text('Încarcă mai mult'), findsOneWidget);
      await tester.tap(find.byKey(const Key('activity-load-more')));
      await tester.pump();
      expect(seeded.loadMores, 1);
    });

    testWidgets('pull-to-refresh calls refresh', (tester) async {
      await pump(tester, feed: ActivityFeedState(loaded: true, events: [ev(5)]));
      await tester.fling(find.byKey(const Key('activity-list')), const Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(seeded.refreshes, 1);
    });

    testWidgets('offline with cache: rows + banner (ro)', (tester) async {
      await pump(
        tester,
        feed: ActivityFeedState(loaded: true, fromCache: true, error: PlantlyNetworkException('down'), events: [ev(5)]),
      );
      expect(find.byKey(const Key('activity-offline-banner')), findsOneWidget);
      expect(find.text('Offline — se afișează ultima activitate salvată'), findsOneWidget);
      expect(find.text('maria a adăugat Monstera'), findsOneWidget);
    });

    testWidgets('empty (en) and error-without-cache states', (tester) async {
      await pump(tester, feed: const ActivityFeedState(loaded: true), locale: const Locale('en'));
      expect(find.byKey(const Key('activity-empty')), findsOneWidget);
      expect(find.textContaining('No activity yet'), findsOneWidget);

      await pump(
        tester,
        feed: ActivityFeedState(loaded: true, fromCache: true, error: PlantlyNetworkException('down')),
        locale: const Locale('en'),
      );
      expect(find.byKey(const Key('activity-error')), findsOneWidget);
      expect(find.textContaining("Couldn't load the activity"), findsOneWidget);
    });
  });

  group('LastEditedByLine (plant detail)', () {
    Future<void> pump(
      WidgetTester tester, {
      required List<CloudCollection> collections,
      required List<ActivityEvent> events,
      String? me = 'u-1',
      bool enabled = true,
      Locale locale = const Locale('ro'),
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildTestApp(
        overrides: [
          cloudEnabledProvider.overrideWithValue(enabled),
          currentUserIdProvider.overrideWithValue(me),
          collectionsProvider.overrideWith((ref) => CollectionsNotifier(ref, autoStart: false, initial: collections)),
          collectionActivityProvider.overrideWith(
            (ref, id) => SeededActivity(ref, id, ActivityFeedState(loaded: true, events: events)),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: LastEditedByLine(tenantId: 'col-2', entityId: 'p-1', surface: PlantlySurface.light),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    final fiveMin = DateTime.now().toUtc().subtract(const Duration(minutes: 5));

    testWidgets('shared collection + another member edited → line shown', (tester) async {
      await pump(tester, collections: const [shared], events: [
        ev(3, userId: 'u-1', username: 'alice', entityId: 'p-1', kind: ActivityKind.updated),
        ev(2, userId: 'u-2', username: 'maria', entityId: 'p-1', kind: ActivityKind.updated, at: fiveMin),
      ]);
      expect(find.byKey(const Key('plant-last-edited-by')), findsOneWidget);
      expect(find.text('Ultima modificare de maria · acum 5 min'), findsOneWidget);
    });

    testWidgets('hidden: private collection / only my edits / unknown collection / flag off', (tester) async {
      final mine = [ev(2, userId: 'u-1', username: 'alice', entityId: 'p-1', kind: ActivityKind.updated)];
      final theirs = [ev(2, userId: 'u-2', username: 'maria', entityId: 'p-1', at: fiveMin)];
      await pump(tester, collections: const [shared], events: mine);
      expect(find.byKey(const Key('plant-last-edited-by')), findsNothing);
      await pump(tester, collections: [private.copyWithId('col-2')], events: theirs);
      expect(find.byKey(const Key('plant-last-edited-by')), findsNothing);
      await pump(tester, collections: const [], events: theirs);
      expect(find.byKey(const Key('plant-last-edited-by')), findsNothing);
      await pump(tester, collections: const [shared], events: theirs, enabled: false);
      expect(find.byKey(const Key('plant-last-edited-by')), findsNothing);
    });
  });

  group('Cloud screen', () {
    final token = fakeJwt(
      iat: DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000,
      exp: DateTime.now().toUtc().add(const Duration(hours: 24)).millisecondsSinceEpoch ~/ 1000,
    );

    Future<void> pump(
      WidgetTester tester, {
      required Widget child,
      CloudEntitlement? entitlement,
      bool linked = true,
      Locale locale = const Locale('ro'),
      bool purchaseLink = true,
      List<Override> extra = const [],
    }) async {
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues({
        'plantly_onboarded': true,
        if (linked) kCollectionIdPrefKey: 'col-1',
        if (linked) kCollectionNamePrefKey: 'My plants',
        if (linked) kCollectionUserIdPrefKey: 'u-1',
        if (linked) kCollectionUsernamePrefKey: 'alice',
        if (linked) kTenantIdPrefKey: 'col-1',
      });
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
      await tester.pumpWidget(buildTestApp(
        overrides: [
          cloudEnabledProvider.overrideWithValue(true),
          sessionStoreProvider.overrideWith((_) => InMemorySessionStore(token)),
          cloudEntitlementProvider.overrideWith(() => FixedEntitlement(entitlement)),
          syncRunnerProvider.overrideWithValue(RecordingRunner(SyncStatus.empty)),
          cloudPurchaseLinkAllowedProvider.overrideWithValue(purchaseLink),
          collectionsProvider.overrideWith((ref) => CollectionsNotifier(ref, autoStart: false, initial: const [private])),
          ...extra,
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      ));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('shared access only (ro): explanatory row replaces "not included", subscribe hint stays', (tester) async {
      await pump(
        tester,
        linked: false,
        entitlement: const CloudEntitlement(active: false, sharedAccess: SharedAccess(active: true, collections: 1)),
        child: const Scaffold(body: SingleChildScrollView(child: CloudRows(surface: PlantlySurface.light, detailed: true))),
      );
      expect(find.byKey(const Key('cloud-shared-access')), findsOneWidget);
      expect(find.text('Acces prin colecția partajată'), findsOneWidget);
      expect(find.text('Ai acces prin colecția partajată. Colecția ta personală rămâne doar pe acest dispozitiv.'),
          findsOneWidget);
      expect(find.byKey(const Key('cloud-not-included')), findsNothing);
      expect(find.byKey(const Key('cloud-subscribe')), findsOneWidget);
      expect(find.text('Abonează-te pe plantly.ro'), findsOneWidget);
      expect(find.byKey(const Key('cloud-status')), findsNothing, reason: 'personal collection: no sync here');
    });

    testWidgets('shared access only (en) + no shared access → plain "not included"', (tester) async {
      await pump(
        tester,
        linked: false,
        locale: const Locale('en'),
        entitlement: const CloudEntitlement(active: false, sharedAccess: SharedAccess(active: true, collections: 2)),
        child: const Scaffold(body: SingleChildScrollView(child: CloudRows(surface: PlantlySurface.light, detailed: true))),
      );
      expect(find.text('Access via a shared collection'), findsOneWidget);
      expect(find.textContaining('Your own collection stays on this device only.'), findsOneWidget);

      await pump(
        tester,
        linked: false,
        locale: const Locale('en'),
        entitlement: CloudEntitlement.none,
        child: const Scaffold(body: SingleChildScrollView(child: CloudRows(surface: PlantlySurface.light, detailed: true))),
      );
      expect(find.byKey(const Key('cloud-shared-access')), findsNothing);
      expect(find.byKey(const Key('cloud-not-included')), findsOneWidget);
    });

    testWidgets('own plan active → no shared-access row even with shared_access.active', (tester) async {
      await pump(
        tester,
        entitlement: const CloudEntitlement(active: true, source: 'pro', sharedAccess: SharedAccess(active: true, collections: 1)),
        child: const Scaffold(body: SingleChildScrollView(child: CloudRows(surface: PlantlySurface.light, detailed: true))),
      );
      expect(find.byKey(const Key('cloud-shared-access')), findsNothing);
      expect(find.byKey(const Key('cloud-status')), findsOneWidget);
    });

    testWidgets('CloudScreen: Activity row for a shared active collection, none for a private one', (tester) async {
      await pump(
        tester,
        entitlement: const CloudEntitlement(active: true, source: 'pro'),
        child: const CloudScreen(),
        extra: [activeCollectionProvider.overrideWithValue(shared)],
      );
      expect(find.byKey(const Key('cloud-activity')), findsOneWidget);
      expect(find.text('Activitate'), findsOneWidget);
      expect(find.text('Cine a modificat ce în această colecție'), findsOneWidget);

      await pump(
        tester,
        entitlement: const CloudEntitlement(active: true, source: 'pro'),
        child: const CloudScreen(),
        extra: [activeCollectionProvider.overrideWithValue(private)],
      );
      expect(find.byKey(const Key('cloud-activity')), findsNothing);
    });

    testWidgets('tapping the Activity row opens the feed screen (no GoRouter → imperative push)', (tester) async {
      await pump(
        tester,
        entitlement: const CloudEntitlement(active: true, source: 'pro'),
        child: const CloudScreen(),
        extra: [
          activeCollectionProvider.overrideWithValue(shared),
          collectionActivityProvider.overrideWith(
            (ref, id) => SeededActivity(ref, id, ActivityFeedState(loaded: true, events: [ev(1)])),
          ),
        ],
      );
      await tester.ensureVisible(find.byKey(const Key('cloud-activity')));
      await tester.tap(find.byKey(const Key('cloud-activity')));
      await tester.pumpAndSettle();
      expect(find.byType(CollectionActivityScreen), findsOneWidget);
      expect(find.text('maria a adăugat Monstera'), findsOneWidget);
    });
  });
}

extension on CloudCollection {
  CloudCollection copyWithId(String newId) =>
      CloudCollection(id: newId, name: name, role: role, ownerUserId: ownerUserId, memberCount: memberCount);
}
