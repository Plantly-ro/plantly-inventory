import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/photo_blob_store.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/handoff/handoff_listener.dart';
import 'package:plantly_inventory/handoff/import_plant_sheet.dart';
import 'package:plantly_inventory/handoff/incoming_links.dart';
import 'package:plantly_inventory/handoff/plantly_export.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/features/plant_detail/plant_detail_screen.dart';
import 'package:plantly_inventory/handoff/import_plant_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

String encodeParam(Map<String, Object?> json) => base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// A real 2×2 JPEG (ImageMagick, q60) — the parser requires the JPEG SOI
/// marker and `Image.memory` must decode it cleanly in the preview.
final thumb = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAA0JCgsKCA0LCgsODg0PEyAVExISEyccHhcgLikxMC4pLSwzOko+MzZGNywtQFdBRkxOUlNSMj5aYVpQYEpRUk//2wBDAQ4ODhMREyYVFSZPNS01T09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0//wAARCAACAAIDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAX/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAgX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCcAKe//9k=',
);

Map<String, Object?> samplePayload() => {
      'schemaVersion': 1,
      'source': 'plantly-assistant',
      'scientificName': 'Monstera deliciosa',
      'commonName': 'Swiss cheese plant',
      'candidates': const [],
      'healthStatus': 'stressed',
      'observations': [
        {'kind': 'yellowing', 'severity': 0.7, 'note': 'lower leaves'},
      ],
      'photoThumbJpegBase64': base64Encode(thumb),
      'capturedAt': '2026-08-07T10:30:00.000',
      'exportedAt': '2026-08-07T10:31:00.000',
    };

/// Host with a real in-memory Drift DB (bootstrap + seed run for real), an
/// in-memory blob store, and a button that opens the sheet.
Widget host({
  required PlantlyExportPayload payload,
  required InMemoryPhotoBlobStore store,
  required GlobalKey<NavigatorState> navKey,
  List<Override> overrides = const [],
  Locale? locale,
}) {
  return buildTestApp(
    overrides: [
      photoBlobStoreProvider.overrideWithValue(store),
      // Detail-screen streams stay on the harness' static overrides: a live
      // Drift `watch()` at disposal leaves a pending Timer and fails the test.
      ...overrides,
    ],
    child: MaterialApp(
      navigatorKey: navKey,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Consumer(builder: (context, ref, _) {
        final boot = ref.watch(appContextProvider);
        return Scaffold(
          body: boot.when(
            loading: () => const Text('booting'),
            error: (e, _) => Text('error $e'),
            data: (_) => Center(
              child: TextButton(
                key: const Key('open'),
                onPressed: () => showImportPlantSheet(context, payload),
                child: const Text('open'),
              ),
            ),
          ),
        );
      }),
    ),
  );
}

/// Drift's in-memory executor completes under the fake clock, so plain
/// pumps are enough (same pattern as widget_test.dart); real async is only
/// used in tearDown to drain Drift's stream-teardown timer.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Future<void> drain(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'plantly_onboarded': true}));

  testWidgets('preview → confirm creates species + plant + photo rows and opens the detail', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => drain(tester));

    final store = InMemoryPhotoBlobStore();
    final navKey = GlobalKey<NavigatorState>();
    final payload = PlantlyExportPayload.decodeParam(encodeParam(samplePayload()));
    await tester.pumpWidget(host(payload: payload, store: store, navKey: navKey));
    await settle(tester);

    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);

    // Preview shows names, thumb, health, editable nickname.
    expect(find.text('Monstera deliciosa'), findsOneWidget);
    expect(find.text('Swiss cheese plant'), findsWidgets); // common name + nickname field
    expect(find.byKey(const Key('import-thumb')), findsOneWidget);
    expect(find.text('Health: stressed'), findsOneWidget);
    expect((tester.widget(find.byKey(const Key('import-nickname'))) as TextField).controller!.text, 'Swiss cheese plant');
    expect(find.byKey(const Key('import-recent-hint')), findsNothing);

    await tester.enterText(find.byKey(const Key('import-nickname')), 'Monty');
    await tester.tap(find.byKey(const Key('import-confirm')));
    await settle(tester);

    // Rows exist.
    final container = ProviderScope.containerOf(navKey.currentContext!);
    final db = container.read(databaseProvider);
    final species = await db.select(db.species).get();
    expect(species.map((s) => s.scientificName), contains('Monstera deliciosa'));
    final sp = species.firstWhere((s) => s.scientificName == 'Monstera deliciosa');
    expect(sp.commonNamesJson, '["Swiss cheese plant"]');
    expect(sp.isSeed, isFalse);

    final plants = await (db.select(db.plants)..where((p) => p.nickname.equals('Monty'))).get();
    expect(plants, hasLength(1));
    final plant = plants.single;
    expect(plant.speciesId, sp.id);
    expect(plant.source, 'plantly-assistant');
    expect(plant.acquiredAt, isNotNull);
    expect(plant.notes, 'Identified with Plantly Assistant on Aug 7, 2026. Health: stressed. Observations: yellowing (70%) — lower leaves.');

    final joins = await (db.select(db.plantPhotos)..where((r) => r.plantId.equals(plant.id))).get();
    expect(joins, hasLength(1));
    final photo = await (db.select(db.photos)..where((p) => p.sha256.equals(joins.single.photoSha))).getSingle();
    expect(photo.bytes, thumb.length);
    expect(store.blobs.keys.single, startsWith(photo.sha256));
    expect(await db.select(db.careSchedules).get(), isNot(contains(predicate<CareScheduleRow>((s) => s.plantId == plant.id))));

    // Navigated to the new plant's detail.
    expect(find.byType(PlantDetailScreen), findsOneWidget);
    expect((tester.widget(find.byType(PlantDetailScreen)) as PlantDetailScreen).plantId, plant.id);

    // Importing the same species again within 10 minutes shows the hint.
    navKey.currentState!.pop();
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);
    expect(find.byKey(const Key('import-recent-hint')), findsOneWidget);
    expect(find.text('Add again'), findsOneWidget);
    // Species is reused, not duplicated.
    await tester.tap(find.byKey(const Key('import-confirm')));
    await settle(tester);
    expect((await db.select(db.species).get()).where((s) => s.scientificName == 'Monstera deliciosa'), hasLength(1));
    expect(await (db.select(db.plants)..where((p) => p.speciesId.equals(sp.id))).get(), hasLength(2));
  });

  testWidgets('HandoffListener opens the sheet from an incoming link and the error sheet for junk', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => drain(tester));

    final links = FakeIncomingLinks(initialUri: Uri.parse('plantlyinventory://import#d=${encodeParam(samplePayload())}'));
    addTearDown(links.dispose);
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(buildTestApp(
      overrides: [
        incomingLinksProvider.overrideWithValue(links),
        photoBlobStoreProvider.overrideWithValue(InMemoryPhotoBlobStore()),
      ],
      child: MaterialApp(
        navigatorKey: navKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => HandoffListener(navigatorKey: navKey, child: child!),
        home: Consumer(builder: (context, ref, _) {
          ref.watch(appContextProvider); // trigger bootstrap
          return const Scaffold(body: Text('home'));
        }),
      ),
    ));
    await settle(tester);
    await settle(tester);
    expect(find.byKey(const Key('import-confirm')), findsOneWidget);
    expect(links.consumed, 1); // web half strips the hash here
    navKey.currentState!.pop();
    await settle(tester);

    // Same link again after the sheet closed → dedupe released → opens again.
    links.emit(links.initialUri!);
    await settle(tester);
    expect(find.byKey(const Key('import-confirm')), findsOneWidget);
    navKey.currentState!.pop();
    await settle(tester);

    links.emit(Uri.parse('http://127.0.0.1:8099/#/import?d=!!!not-base64!!!'));
    await settle(tester);
    expect(find.byKey(const Key('import-error')), findsOneWidget);
  });

  testWidgets('preview renders health + observation enums localized (ro)', (tester) async {
    tester.view.physicalSize = const Size(420, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => drain(tester));

    final store = InMemoryPhotoBlobStore();
    final navKey = GlobalKey<NavigatorState>();
    final payload = PlantlyExportPayload.decodeParam(encodeParam(samplePayload()));
    await tester.pumpWidget(host(payload: payload, store: store, navKey: navKey, locale: const Locale('ro')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('open')));
    await settle(tester);

    expect(find.text('Sănătate: stresată'), findsOneWidget);
    expect(find.text('îngălbenire'), findsOneWidget);
    expect(find.text('Health: stressed'), findsNothing);
    expect(find.text('yellowing'), findsNothing);
    expect(find.text('DIN PLANTLY ASSISTANT'), findsOneWidget);
    navKey.currentState!.pop();
    await settle(tester);
  });

  test('notes template localizes en + ro and omits absent parts', () {
    final full = PlantlyExportPayload.decodeParam(encodeParam(samplePayload()));
    expect(ImportPlantService.buildNotes(full, AppLocalizationsEn()),
        'Identified with Plantly Assistant on Aug 7, 2026. Health: stressed. Observations: yellowing (70%) — lower leaves.');
    expect(ImportPlantService.buildNotes(full, AppLocalizationsRo()),
        'Identificată cu Plantly Assistant pe 7 aug. 2026. Sănătate: stresată. Observații: îngălbenire (70%) — lower leaves.');

    final minimal = PlantlyExportPayload.decodeParam(encodeParam({'schemaVersion': 1, 'scientificName': 'Ficus'}));
    expect(ImportPlantService.buildNotes(minimal, AppLocalizationsEn()), 'Identified with Plantly Assistant.');

    final bought = PlantlyExportPayload.decodeParam(encodeParam({
      'schemaVersion': 1,
      'scientificName': 'Ficus',
      'source': 'plantly-marketplace',
      'capturedAt': '2026-09-01T00:00:00.000',
    }));
    expect(ImportPlantService.buildNotes(bought, AppLocalizationsEn()), 'Bought on plantly.ro on Sep 1, 2026.');
  });
}
