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

  testWidgets('ro copy', (tester) async {
    final c = await pump(tester, locale: const Locale('ro'));
    c.read(collectionRemovedNoticeProvider.notifier).state = 'Sera familiei';
    await tester.pumpAndSettle();
    expect(find.text('Ai fost eliminat din Sera familiei'), findsOneWidget);
  });
}
