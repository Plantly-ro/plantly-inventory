import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/cloud_notices.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // Same placement as main.dart: inside `builder`, under the root
        // ScaffoldMessenger, above the routes.
        builder: (context, child) => CloudNotices(child: child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Text('home')),
      ),
    ));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('removed-from-collection notice → SnackBar with the name, provider reset to null', (tester) async {
    final c = await pump(tester);
    expect(find.byKey(const Key('cloud-notice-removed')), findsNothing);

    c.read(collectionRemovedNoticeProvider.notifier).state = 'Family greenhouse';
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cloud-notice-removed')), findsOneWidget);
    expect(find.text('You were removed from Family greenhouse'), findsOneWidget);
    expect(c.read(collectionRemovedNoticeProvider), isNull, reason: 'one-shot');

    // A second notice shows again (the reset makes the next set a change).
    c.read(collectionRemovedNoticeProvider.notifier).state = 'Office jungle';
    await tester.pumpAndSettle();
    expect(find.text('You were removed from Office jungle'), findsOneWidget);
    expect(find.text('You were removed from Family greenhouse'), findsNothing, reason: 'previous SnackBar cleared');
  });

  testWidgets('collection-gone notice → SnackBar naming it (server default localized), provider reset', (tester) async {
    final c = await pump(tester);
    c.read(collectionGoneNoticeProvider.notifier).state = 'Olive Grove';
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cloud-notice-collection-gone')), findsOneWidget);
    expect(find.textContaining('“Olive Grove”'), findsOneWidget);
    expect(c.read(collectionGoneNoticeProvider), isNull, reason: 'one-shot');
  });

  testWidgets('collection-gone notice (ro, default name localized)', (tester) async {
    final c = await pump(tester, locale: const Locale('ro'));
    c.read(collectionGoneNoticeProvider.notifier).state = 'My plants';
    await tester.pumpAndSettle();
    expect(find.textContaining('„Plantele mele”'), findsOneWidget);
  });

  testWidgets('device-revoked notice → SnackBar, provider reset to false (en + ro)', (tester) async {
    final c = await pump(tester);
    expect(find.byKey(const Key('cloud-notice-device-revoked')), findsNothing);
    c.read(deviceRevokedNoticeProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cloud-notice-device-revoked')), findsOneWidget);
    expect(find.textContaining('Device disconnected'), findsOneWidget);
    expect(c.read(deviceRevokedNoticeProvider), isFalse, reason: 'one-shot');

    // Shows again on the next revoke (the reset makes `true` a change).
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    c.read(deviceRevokedNoticeProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cloud-notice-device-revoked')), findsOneWidget);
  });

  testWidgets('device-revoked notice (ro)', (tester) async {
    final c = await pump(tester, locale: const Locale('ro'));
    c.read(deviceRevokedNoticeProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(find.textContaining('Dispozitiv deconectat'), findsOneWidget);
  });

  testWidgets('ro copy', (tester) async {
    final c = await pump(tester, locale: const Locale('ro'));
    c.read(collectionRemovedNoticeProvider.notifier).state = 'Sera familiei';
    await tester.pumpAndSettle();
    expect(find.text('Ai fost eliminat din Sera familiei'), findsOneWidget);
  });

  testWidgets('home-lost notice → SnackBar (removed / deleted copy), provider reset to null', (tester) async {
    final c = await pump(tester);
    c.read(homeLostNoticeProvider.notifier).state =
        const HomeLoss(collectionId: 'col-1', name: 'My plants', reason: HomeLossReason.removed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cloud-notice-home-lost')), findsOneWidget);
    expect(find.textContaining('You no longer have access to My plants'), findsOneWidget);
    expect(c.read(homeLostNoticeProvider), isNull, reason: 'one-shot');
    c.read(homeLostNoticeProvider.notifier).state =
        const HomeLoss(collectionId: 'col-1', name: 'My plants', reason: HomeLossReason.deleted);
    await tester.pumpAndSettle();
    expect(find.textContaining('My plants was deleted on the server'), findsOneWidget);
  });
}
