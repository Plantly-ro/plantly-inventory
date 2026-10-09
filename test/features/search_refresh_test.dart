import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/providers.dart';
import 'package:plantly_inventory/data/repositories/search_repository.dart';
import 'package:plantly_inventory/features/search/search_screen.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

PlantRow _row(String id, String name) => PlantRow(
      id: id,
      tenantId: kDefaultTenantId,
      nickname: name,
      speciesId: null,
      locationId: null,
      pinX: null,
      pinY: null,
      notificationsMuted: false,
      status: 'alive',
      acquiredAt: null,
      source: null,
      notes: null,
      potSizeCm: null,
      updatedHlc: HlcClock(deviceId: 'd').now().encode(),
      deletedAt: null,
      deviceId: 'd',
    );

class _FakeSearch extends SearchRepository {
  _FakeSearch() : super(db: AppDatabase.forTesting(NativeDatabase.memory()), tenantId: kDefaultTenantId);
  List<PlantRow> rows = [];
  @override
  Future<List<PlantRow>> search(String rawQuery, {int limit = 50}) async =>
      rows.where((r) => r.nickname.toLowerCase().contains(rawQuery.trim().toLowerCase())).toList();
}

/// QA (c): a plant opened from search and deleted stayed in the results.
void main() {
  testWidgets('results follow plant changes (deleted plant disappears without retyping)', (tester) async {
    SharedPreferences.setMockInitialValues({'plantly_onboarded': true});
    addTearDown(() => tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50))));
    final plants = StreamController<List<PlantRow>>.broadcast();
    addTearDown(plants.close);
    final search = _FakeSearch()..rows = [_row('a', 'Monstera'), _row('b', 'Monstera mini')];
    addTearDown(search.db.close);
    await tester.pumpWidget(buildTestApp(
      overrides: [
        plantsStreamProvider.overrideWith((ref) => plants.stream),
        searchRepositoryProvider.overrideWithValue(search),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SearchScreen(),
      ),
    ));
    await tester.enterText(find.byType(TextField), 'monst');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Monstera mini'), findsOneWidget);

    search.rows = [_row('a', 'Monstera')]; // 'b' deleted elsewhere
    plants.add(search.rows);
    await tester.pumpAndSettle();
    expect(find.text('Monstera mini'), findsNothing);
    expect(find.text('Monstera'), findsOneWidget);
  });
}
