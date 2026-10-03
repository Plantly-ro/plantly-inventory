import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/cloud/collections.dart';
import 'package:plantly_inventory/features/plant_detail/assignee_picker.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/marketplace/plantly_api.dart';
import 'package:plantly_inventory/shared/assignee_initial.dart';
import 'package:plantly_inventory/theme/tokens.dart';

import '../../helpers/test_app.dart';

/// The "Assignee" row of the reminder editors (MULTI-USER-V2 §0): hidden
/// unless the collection is shared with ≥2 members; lists Everyone + the
/// cached members with the signed-in user marked "(you)".
void main() {
  const col = CloudCollection(id: 'col-2', name: 'Family', role: 'editor', ownerUserId: 'u-2', memberCount: 2);
  const members = [
    CollectionMember(userId: 'u-2', username: 'bob', role: 'owner'),
    CollectionMember(userId: 'u-1', username: 'alice', role: 'editor'),
  ];

  Widget host({required bool visible, String? value, ValueChanged<String?>? onChanged, Locale locale = const Locale('en')}) {
    return buildTestApp(
      overrides: [
        assigneePickerVisibleProvider.overrideWithValue(visible),
        activeCollectionProvider.overrideWithValue(col),
        currentUserIdProvider.overrideWithValue('u-1'),
        membersProvider.overrideWith((ref, id) async => members),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AssigneePicker(value: value, onChanged: onChanged ?? (_) {}, surface: PlantlySurface.light),
        ),
      ),
    );
  }

  testWidgets('hidden when the collection is not shared with ≥2 members', (tester) async {
    await tester.pumpWidget(host(visible: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assignee-picker')), findsNothing);
    expect(find.text('Assignee'), findsNothing);
  });

  testWidgets('visible: shows Everyone, opens the member list with "(you)", reports the pick', (tester) async {
    String? picked = 'unset';
    await tester.pumpWidget(host(visible: true, onChanged: (v) => picked = v));
    await tester.pumpAndSettle();
    expect(find.text('Assignee'), findsOneWidget);
    expect(find.text('Everyone'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assignee-picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('assignee-option-everyone')), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('alice (you)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('assignee-option-u-2')));
    await tester.pumpAndSettle();
    expect(picked, 'u-2');
  });

  testWidgets('with a value: shows the member name + initial; picking Everyone reports null', (tester) async {
    String? picked = 'unset';
    await tester.pumpWidget(host(visible: true, value: 'u-2', onChanged: (v) => picked = v));
    await tester.pumpAndSettle();
    expect(find.text('bob'), findsOneWidget);
    expect(find.descendant(of: find.byType(AssigneeInitial), matching: find.text('B')), findsOneWidget);

    await tester.tap(find.byKey(const Key('assignee-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assignee-option-everyone')));
    await tester.pumpAndSettle();
    expect(picked, isNull);
  });

  testWidgets('Romanian copy', (tester) async {
    await tester.pumpWidget(host(visible: true, locale: const Locale('ro')));
    await tester.pumpAndSettle();
    expect(find.text('Responsabil'), findsOneWidget);
    expect(find.text('Toți'), findsOneWidget);
  });

  testWidgets('AssigneeInitial: nothing for null, "?" + former-member tooltip for an unknown id', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: Column(children: [
          AssigneeInitial(userId: null, members: members),
          AssigneeInitial(userId: 'u-9', members: members),
          AssigneeInitial(userId: 'u-1', members: members),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('?'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.byTooltip('Former member'), findsOneWidget);
    expect(find.byTooltip('Assigned to alice'), findsOneWidget);
    expect(tester.widgetList(find.byType(Tooltip)), hasLength(2), reason: 'null renders nothing');
  });
}
