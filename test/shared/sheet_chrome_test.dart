import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/shared/sheet_chrome.dart';
import 'package:plantly_inventory/theme/tokens.dart';

/// Desktop SheetChrome header: min 56 px, a 2-line title grows it (no
/// ellipsis on long ro copy), one-line titles keep the 56 px bar, and the
/// title is a semantic header.
void main() {
  Future<void> pump(WidgetTester tester, String title, {Size size = const Size(1280, 960)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 480,
            child: SheetChrome(
              surface: PlantlySurface.light,
              title: title,
              subtitle: 'Helper line',
              children: const [Text('body')],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  double headerHeight(WidgetTester tester) => tester.getTopLeft(find.byType(Divider)).dy;

  testWidgets('one-line title: 56 px header, single line, semantic header', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, 'Collections');
    expect(headerHeight(tester), 56);
    final p = tester.renderObject<RenderParagraph>(find.text('Collections'));
    expect(p.didExceedMaxLines, isFalse);
    expect(tester.getSemantics(find.text('Collections')), isSemantics(isHeader: true, label: 'Collections'));
    semantics.dispose();
  });

  testWidgets('long title wraps to 2 lines: header grows, no ellipsis, subtitle still shown', (tester) async {
    const long = 'Inventory Cloud este necesar pentru colecțiile partajate';
    await pump(tester, long);
    final p = tester.renderObject<RenderParagraph>(find.text(long));
    expect(p.didExceedMaxLines, isFalse);
    expect(p.size.height, greaterThan(30), reason: 'two lines');
    expect(headerHeight(tester), greaterThanOrEqualTo(56));
    expect(find.text('Helper line'), findsOneWidget);
  });

  testWidgets('phone: no chrome header (title is the sheet body\'s job)', (tester) async {
    await pump(tester, 'Collections', size: const Size(390, 844));
    expect(find.text('Collections'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });
}
