// MULTI-USER-V2 §3 — viewer gating in the UI: the banner, the snackbar
// guard, and the Home screen's primary add action.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/features/collections/read_only_banner.dart';
import 'package:plantly_inventory/features/home/home_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

const _bannerKey = Key('read-only-banner');
const _snackKey = Key('read-only-snack');

Widget _app(Widget home, {required bool canEdit, Locale locale = const Locale('en')}) {
  return buildTestApp(
    overrides: [canEditActiveCollectionProvider.overrideWithValue(canEdit)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _GuardProbe extends ConsumerWidget {
  const _GuardProbe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const ReadOnlyBanner(),
          TextButton(
            key: const Key('probe-mutate'),
            onPressed: () {
              if (!ensureCanEdit(context, ref)) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(key: Key('probe-mutated'), content: Text('mutated')),
              );
            },
            child: const Text('mutate'),
          ),
        ],
      ),
    );
  }
}

Future<void> _drain(WidgetTester tester) async {
  // Drift's stream teardown schedules a zero-duration Timer that the
  // flutter_test fake clock leaves pending at widget-tree disposal.
  addTearDown(() async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
  });

  group('ReadOnlyBanner', () {
    testWidgets('viewer → banner with the EN copy', (tester) async {
      await _drain(tester);
      await tester.pumpWidget(_app(const _GuardProbe(), canEdit: false));
      await tester.pumpAndSettle();
      expect(find.byKey(_bannerKey), findsOneWidget);
      expect(find.text('View only — ask the owner for edit rights'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('viewer → banner with the RO copy', (tester) async {
      await _drain(tester);
      await tester.pumpWidget(_app(const _GuardProbe(), canEdit: false, locale: const Locale('ro')));
      await tester.pumpAndSettle();
      expect(find.text('Doar vizualizare — cere proprietarului drepturi de editare'), findsOneWidget);
    });

    testWidgets('editable → no banner, takes no space', (tester) async {
      await _drain(tester);
      await tester.pumpWidget(_app(const _GuardProbe(), canEdit: true));
      await tester.pumpAndSettle();
      expect(find.byKey(_bannerKey), findsNothing);
      expect(tester.getSize(find.byType(ReadOnlyBanner)), Size.zero);
    });
  });

  group('ensureCanEdit', () {
    testWidgets('viewer → snackbar, callback does not proceed', (tester) async {
      await _drain(tester);
      await tester.pumpWidget(_app(const _GuardProbe(), canEdit: false));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('probe-mutate')));
      await tester.pump();
      expect(find.byKey(_snackKey), findsOneWidget);
      expect(find.text('View only — ask the owner for edit rights.'), findsOneWidget);
      expect(find.byKey(const Key('probe-mutated')), findsNothing);
    });

    testWidgets('editable → no snackbar, callback proceeds', (tester) async {
      await _drain(tester);
      await tester.pumpWidget(_app(const _GuardProbe(), canEdit: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('probe-mutate')));
      await tester.pump();
      expect(find.byKey(_snackKey), findsNothing);
      expect(find.byKey(const Key('probe-mutated')), findsOneWidget);
    });
  });

  group('HomeScreen', () {
    Future<void> pumpHome(WidgetTester tester, {required bool canEdit}) async {
      tester.view.physicalSize = const Size(420, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _drain(tester);
      await tester.pumpWidget(_app(const HomeScreen(), canEdit: canEdit));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
    }

    testWidgets('viewer → no add FAB, banner shown, no quick-log tiles', (tester) async {
      await pumpHome(tester, canEdit: false);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(_bannerKey), findsOneWidget);
      expect(find.byType(Dismissible), findsNothing);
    });

    testWidgets('editor → add FAB present, no banner', (tester) async {
      await pumpHome(tester, canEdit: true);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byKey(_bannerKey), findsNothing);
    });
  });
}
