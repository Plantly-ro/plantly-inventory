import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/ro_locations.dart';
import 'package:plantly_inventory/plugins/export_plugin.dart';
import 'package:plantly_inventory/plugins/local_draft/local_draft_plugin.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('roCounties', () {
    test('has all 42 județe, no duplicates', () {
      expect(roCounties.length, 42);
      expect(roCounties.toSet().length, 42);
    });

    test('includes București and a diacritic-bearing county', () {
      expect(roCounties, contains('București'));
      expect(roCounties, contains('Timiș'));
    });
  });

  test('exportCategories are non-empty and unique', () {
    expect(exportCategories, isNotEmpty);
    expect(exportCategories.toSet().length, exportCategories.length);
  });

  test('draft round-trips category / county / city through the local store',
      () async {
    SharedPreferences.setMockInitialValues({});
    final plugin = LocalDraftExportPlugin();
    await plugin.saveDraft(const ExportDraft(
      sourcePlantId: 'p1',
      title: 'Aloe',
      description: 'd',
      priceLei: 40,
      category: 'Succulent / Cactus',
      county: 'Cluj',
      city: 'Cluj-Napoca',
    ));

    final loaded = await plugin.loadDraft('p1');
    expect(loaded!.category, 'Succulent / Cactus');
    expect(loaded.county, 'Cluj');
    expect(loaded.city, 'Cluj-Napoca');
  });
}
