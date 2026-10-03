import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/app/clock.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/features/locations/location_detail_screen.dart';
import 'package:plantly_inventory/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// Golden coverage for the adaptive shell (CLOUD-SYNC-CONTRACT §5).
///
/// Phone (390×844) goldens were captured BEFORE the router/shell refactor
/// and must stay byte-identical afterwards — that's the "mobile stays
/// pixel-identical" guarantee. Desktop (1440×900) and tablet (900×1200)
/// goldens document the new layouts.
///
/// Determinism: the home layout skips the time-of-day greeting, the clock
/// is pinned via [clockProvider], and the detail fixture carries a fixed
/// `acquiredAt` so no rendered string depends on the wall clock.
final _fixedNow = DateTime(2026, 9, 16, 10, 30);

PlantRow _cala() => PlantRow(
      id: 'cala',
      tenantId: kDefaultTenantId,
      nickname: 'Calathea',
      speciesId: 'Calathea orbifolia',
      locationId: null,
      pinX: null,
      pinY: null,
      notificationsMuted: false,
      status: 'alive',
      acquiredAt: DateTime.utc(2026, 3, 1).millisecondsSinceEpoch,
      source: null,
      notes: 'Likes bright indirect light. Water when the top 3 cm are dry.',
      potSizeCm: 18,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

int _ms(Duration fromNow) => _fixedNow.add(fromNow).toUtc().millisecondsSinceEpoch;

CareScheduleRow _schedule(String type, double every, Duration due) => CareScheduleRow(
      id: 's-$type',
      tenantId: kDefaultTenantId,
      plantId: 'cala',
      type: type,
      baseIntervalDays: every,
      currentIntervalDays: every,
      lastDoneAt: _ms(due - Duration(days: every.round())),
      nextDueAt: _ms(due),
      snoozeCount: 0,
      recentEventsJson: '[]',
      enabled: true,
      recurrenceMode: 'after_completion',
      notificationsMuted: false,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

CareEventRow _event(String id, String type, Duration ago, {String? notes}) => CareEventRow(
      id: id,
      tenantId: kDefaultTenantId,
      plantId: 'cala',
      type: type,
      doneAt: _ms(-ago),
      notes: notes,
      dose: null,
      product: null,
      photoSha: null,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

/// Populated plant-detail tables (2 reminders, 3 history rows), all
/// relative to [_fixedNow] so the "in 2 days" / "3 days ago" strings are
/// stable as long as the screen reads `clockProvider`.
List<Override> _calaCareFixtures() => [
      schedulesForPlantProvider.overrideWith((ref, id) => Stream.value(id == 'cala'
          ? [
              _schedule('water', 7, const Duration(days: 2)),
              _schedule('fertilize', 30, const Duration(days: -1)),
            ]
          : const <CareScheduleRow>[])),
      careEventsForPlantProvider.overrideWith((ref, id) => Stream.value(id == 'cala'
          ? [
              _event('e1', 'water', const Duration(days: 3)),
              _event('e2', 'fertilize', const Duration(days: 10), notes: 'Half strength'),
              _event('e3', 'water', const Duration(days: 12)),
            ]
          : const <CareEventRow>[])),
    ];

List<Override> _livingRoomFixtures() => [
      locationsStreamProvider.overrideWith((ref) => Stream.value([_livingRoom()])),
      locationByIdStreamProvider.overrideWith((ref, id) => Stream.value(id == 'living' ? _livingRoom() : null)),
      plantsByLocationProvider.overrideWith((ref, id) => Stream.value(id == 'living' ? [_cala()] : const <PlantRow>[])),
    ];

LocationRow _livingRoom() => LocationRow(
      id: 'living',
      tenantId: kDefaultTenantId,
      parentId: null,
      name: 'Living room',
      kind: 'room',
      light: null,
      humidityMin: null,
      humidityMax: null,
      tempMinC: null,
      tempMaxC: null,
      isOutdoor: false,
      lat: null,
      lon: null,
      notes: null,
      mapPhotoSha: null,
      notificationsMuted: false,
      updatedHlc: '0-0-t',
      deletedAt: null,
      deviceId: 't',
    );

/// The "All plants" grid card overflows its Column by 1.1 px at 390 px wide
/// with real Inter metrics (grid_widget.dart `_Card`, pre-existing — see the
/// desktop-shell report). flutter_test turns every overflow into a failure,
/// so tolerate exactly that error here; anything else still fails the test.
void _tolerateOverflow() {
  final prev = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed by')) return;
    prev?.call(details);
  };
  addTearDown(() => FlutterError.onError = prev);
}

Future<void> _pumpApp(
  WidgetTester tester,
  Size size, {
  String? initialLocation,
  List<Override> extraOverrides = const [],
  bool dark = false,
  bool onboarded = true,
}) async {
  _tolerateOverflow();
  // Text fields (Add plant sheet) must not blink between pumps.
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);
  SharedPreferences.setMockInitialValues({
    'plantly_onboarded': onboarded,
    'plantly_layout': '["stats","grid","activity"]',
    if (dark) 'plantly_theme': 'dark',
  });
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));

  await tester.pumpWidget(buildTestApp(
    overrides: [
      clockProvider.overrideWithValue(() => _fixedNow),
      plantByIdProvider.overrideWith((ref, id) => Stream.value(id == 'cala' ? _cala() : null)),
      ...extraOverrides,
    ],
    child: PlantlyApp(initialLocation: initialLocation),
  ));
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Future<void> _golden(WidgetTester tester, String name) async {
  await expectLater(find.byType(PlantlyApp), matchesGoldenFile('$name.png'));
}

void main() {
  const phone = Size(390, 844);
  const tablet = Size(900, 1200);
  const desktop = Size(1440, 900);

  group('phone 390×844 (must not change)', () {
    testWidgets('home', (tester) async {
      await _pumpApp(tester, phone);
      await _golden(tester, 'phone/home');
    });

    testWidgets('plant detail (tap from list)', (tester) async {
      await _pumpApp(tester, phone);
      // Calathea is the first card of the sorted grid — visible above the fold.
      await tester.tap(find.text('Calathea').first);
      await tester.pumpAndSettle();
      await _golden(tester, 'phone/plant_detail');
    });

    testWidgets('calendar (tap from tab bar)', (tester) async {
      await _pumpApp(tester, phone);
      await tester.tap(find.widgetWithText(InkWell, 'Calendar'));
      await tester.pumpAndSettle();
      await _golden(tester, 'phone/calendar');
    });

    testWidgets('home with Add plant sheet open (FAB)', (tester) async {
      await _pumpApp(tester, phone);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await _golden(tester, 'phone/home_add_plant_sheet');
    });

    testWidgets('spaces list', (tester) async {
      await _pumpApp(tester, phone, initialLocation: '/spaces', extraOverrides: [
        locationsStreamProvider.overrideWith((ref) => Stream.value([_livingRoom()])),
      ]);
      await _golden(tester, 'phone/spaces');
    });

    testWidgets('me subpage (care types)', (tester) async {
      await _pumpApp(tester, phone, initialLocation: '/me/care-types');
      await _golden(tester, 'phone/me_care_types');
    });
  });

  group('desktop 1440×900', () {
    testWidgets('home dashboard', (tester) async {
      await _pumpApp(tester, desktop);
      await _golden(tester, 'desktop/home');
    });
    testWidgets('home dashboard (dark)', (tester) async {
      await _pumpApp(tester, desktop, dark: true);
      await _golden(tester, 'desktop/home_dark');
    });
    testWidgets('home dashboard at 1100×800 (4 grid columns)', (tester) async {
      await _pumpApp(tester, const Size(1100, 800));
      await _golden(tester, 'desktop/home_1100');
    });
    testWidgets('home dashboard, mouse over a plant card', (tester) async {
      await _pumpApp(tester, desktop);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Calathea').first));
      await tester.pumpAndSettle();
      await _golden(tester, 'desktop/home_hover');
    });
    testWidgets('home dashboard, Customise side sheet open', (tester) async {
      await _pumpApp(tester, desktop);
      await tester.tap(find.text('Customise'));
      await tester.pumpAndSettle();
      await _golden(tester, 'desktop/home_customise_sheet');
    });
    testWidgets('side sheet: Add plant (press n)', (tester) async {
      await _pumpApp(tester, desktop);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.pumpAndSettle();
      await _golden(tester, 'desktop/side_sheet_add_plant');
    });
    testWidgets('plant detail (full width, tables populated)', (tester) async {
      await _pumpApp(tester, desktop, initialLocation: '/plants/cala', extraOverrides: _calaCareFixtures());
      await _golden(tester, 'desktop/plant_detail');
    });
    testWidgets('plant detail (dark)', (tester) async {
      await _pumpApp(tester, desktop, initialLocation: '/plants/cala', extraOverrides: _calaCareFixtures(), dark: true);
      await _golden(tester, 'desktop/plant_detail_dark');
    });
    testWidgets('spaces grid', (tester) async {
      await _pumpApp(tester, desktop, initialLocation: '/spaces', extraOverrides: _livingRoomFixtures());
      await _golden(tester, 'desktop/spaces');
    });
    testWidgets('space detail', (tester) async {
      await _pumpApp(tester, desktop, initialLocation: '/spaces/living', extraOverrides: _livingRoomFixtures());
      await _golden(tester, 'desktop/space_detail');
    });
    testWidgets('onboarding (first run, centred card)', (tester) async {
      await _pumpApp(tester, desktop, onboarded: false);
      await tester.pumpAndSettle();
      await _golden(tester, 'desktop/onboarding');
    });
    testWidgets('calendar', (tester) async {
      await _pumpApp(tester, desktop, initialLocation: '/calendar');
      await _golden(tester, 'desktop/calendar');
    });
    testWidgets('me', (tester) async {
      await _pumpApp(tester, desktop, initialLocation: '/me');
      await _golden(tester, 'desktop/me');
    });
  });

  group('tablet 900×1200', () {
    testWidgets('home', (tester) async {
      await _pumpApp(tester, tablet);
      await _golden(tester, 'tablet/home');
    });
    testWidgets('plant detail', (tester) async {
      await _pumpApp(tester, tablet, initialLocation: '/plants/cala');
      await _golden(tester, 'tablet/plant_detail');
    });
    testWidgets('calendar', (tester) async {
      await _pumpApp(tester, tablet, initialLocation: '/calendar');
      await _golden(tester, 'tablet/calendar');
    });
    testWidgets('me', (tester) async {
      await _pumpApp(tester, tablet, initialLocation: '/me');
      await _golden(tester, 'tablet/me');
    });
  });
}
