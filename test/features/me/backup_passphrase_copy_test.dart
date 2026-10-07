import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/features/me/backup_passphrase_dialog.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';

/// Android QA 2026-10-07: the import dialog showed the export hint ("Pick
/// anything — needed to import again"), and nothing said the passphrase
/// only signs the file (HMAC) — the contents are plaintext. Export and
/// import get their own copy, and export says plainly it is not encryption.
void main() {
  Future<void> pump(WidgetTester tester, BackupPassphrasePurpose purpose, {Locale locale = const Locale('en')}) async {
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showBackupPassphraseDialog(context, purpose: purpose),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool hasText(Pattern p) => find
      .byWidgetPredicate((w) =>
          (w is Text && (w.data ?? '').contains(p)) ||
          (w is TextField && (w.decoration?.hintText ?? '').contains(p)))
      .evaluate()
      .isNotEmpty;

  testWidgets('export: asks to choose a passphrase and says the file is not encrypted', (tester) async {
    await pump(tester, BackupPassphrasePurpose.export);
    expect(hasText('Choose a passphrase'), isTrue);
    expect(hasText('protects the file against tampering'), isTrue);
    expect(hasText('not encrypted'), isTrue);
    expect(hasText('Pick anything'), isFalse);
  });

  testWidgets('import: asks for the passphrase used at export, not the export hint', (tester) async {
    await pump(tester, BackupPassphrasePurpose.import);
    expect(hasText('The passphrase you chose when exporting'), isTrue);
    expect(hasText("you'll need it to import"), isFalse);
    expect(hasText('Pick anything'), isFalse);
    expect(hasText('not encrypted'), isFalse);
  });

  testWidgets('Romanian copy', (tester) async {
    await pump(tester, BackupPassphrasePurpose.export, locale: const Locale('ro'));
    expect(hasText('Alege o parolă'), isTrue);
    expect(hasText('nu este criptat'), isTrue);
    await tester.tap(find.text('Renunță'));
    await tester.pumpAndSettle();
    await pump(tester, BackupPassphrasePurpose.import, locale: const Locale('ro'));
    expect(hasText('Parola aleasă la export'), isTrue);
    expect(hasText('Alege o parolă'), isFalse);
  });

  testWidgets('returns the typed passphrase; Cancel returns null', (tester) async {
    String? result = 'unset';
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showBackupPassphraseDialog(context, purpose: BackupPassphrasePurpose.import),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hunter2');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result, 'hunter2');

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
