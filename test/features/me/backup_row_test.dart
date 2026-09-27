import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/domain/services/backup_service.dart';
import 'package:plantly_inventory/features/me/me_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/services/file_export.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

/// Issue #14: "Export JSON (signed)" threw `Bad state: Cannot use "ref"
/// after the widget was disposed`. The Me screen is a lazy ListView; the
/// passphrase dialog's soft keyboard (adjustResize) shrinks the viewport,
/// the row that started the export scrolls out of the cache extent and is
/// unmounted, and the post-`await` `ref.read` in the row blew up.
///
/// This test reproduces exactly that: park the row at the bottom edge,
/// open the dialog, shrink the viewport until the row is gone, then
/// complete the dialog — the export must still run and toast.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'plantly_onboarded': true}));

  Future<RecordingFileExporter> pumpMe(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final exporter = RecordingFileExporter();

    await tester.pumpWidget(buildTestApp(
      overrides: [
        backupServiceProvider.overrideWithValue(BackupService(db: db, tenantId: kDefaultTenantId)),
        fileExporterProvider.overrideWithValue(exporter),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MeScreen(),
      ),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    return exporter;
  }

  group('Me › Export JSON (signed)', () {
    testWidgets('completes when the row is unmounted while the passphrase dialog is open (#14)', (tester) async {
      final exporter = await pumpMe(tester, size: const Size(420, 900));

      // Bring the row in, then pin its bottom edge to the viewport's bottom
      // edge so it's the last visible row (the on-device repro).
      final row = find.text('Export JSON (signed)');
      await tester.scrollUntilVisible(row, 120, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(row), alignment: 1.0);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);

      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.text('Backup passphrase'), findsOneWidget);

      // Soft keyboard: shrink the viewport well past ListView's cacheExtent
      // (250px) so the row is garbage-collected out of the sliver.
      tester.view.physicalSize = const Size(420, 400);
      await tester.pumpAndSettle();
      expect(row, findsNothing, reason: 'the row must unmount for this test to exercise #14');
      expect(find.text('Backup passphrase'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Export failed'), findsNothing);
      expect(exporter.saved, hasLength(1));
      expect(exporter.saved.single.fileName, matches(RegExp(r'^plantly-backup-.*\.json$')));
      expect(exporter.saved.single.mimeType, 'application/json');
      expect(find.textContaining('Backup saved:'), findsOneWidget);
    });

    testWidgets('happy path with the row still mounted', (tester) async {
      final exporter = await pumpMe(tester, size: const Size(420, 2400));
      await tester.tap(find.text('Export JSON (signed)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'hunter2');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(exporter.saved, hasLength(1));
      // The blob is the signed document — decodes back to signature+payload.
      final blob = BackupService.decodeBlob(exporter.saved.single.bytes);
      expect(blob, contains('"signature"'));
      expect(blob, contains('"plantly_inventory.backup"'));
    });

    testWidgets('cancelling the passphrase dialog exports nothing', (tester) async {
      final exporter = await pumpMe(tester, size: const Size(420, 2400));
      await tester.tap(find.text('Export JSON (signed)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(exporter.saved, isEmpty);
    });
  });
}
