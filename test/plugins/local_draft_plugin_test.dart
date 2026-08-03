import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/plugins/export_plugin.dart';
import 'package:plantly_inventory/plugins/local_draft/local_draft_plugin.dart';
import 'package:plantly_inventory/plugins/plugin_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ExportDraft draft({
    String plant = 'p1',
    String title = 'Monstera',
    String description = 'Healthy split-leaf',
    int? price = 120,
    List<String> photos = const ['sha-a', 'sha-b'],
  }) =>
      ExportDraft(
        sourcePlantId: plant,
        title: title,
        description: description,
        priceLei: price,
        photoRefs: photos,
      );

  group('LocalDraftExportPlugin persistence', () {
    test('saveDraft → loadDraft round-trips the fields', () async {
      final plugin = LocalDraftExportPlugin();
      await plugin.saveDraft(draft());

      final loaded = await plugin.loadDraft('p1');
      expect(loaded, isNotNull);
      expect(loaded!.title, 'Monstera');
      expect(loaded.description, 'Healthy split-leaf');
      expect(loaded.priceLei, 120);
      expect(loaded.photoRefs, ['sha-a', 'sha-b']);
    });

    test('loadDraft returns null when no draft was saved', () async {
      expect(await LocalDraftExportPlugin().loadDraft('nope'), isNull);
    });

    test('drafts are keyed per plant', () async {
      final plugin = LocalDraftExportPlugin();
      await plugin.saveDraft(draft(plant: 'p1', title: 'One'));
      await plugin.saveDraft(draft(plant: 'p2', title: 'Two'));
      expect((await plugin.loadDraft('p1'))!.title, 'One');
      expect((await plugin.loadDraft('p2'))!.title, 'Two');
    });

    test('legacy `price` string key still resumes', () async {
      // Simulate a pre-plugin draft written with the old key shape.
      SharedPreferences.setMockInitialValues({
        'plantly_export_draft/legacy':
            '{"title":"Old","description":"d","price":"75","photos":[]}',
      });
      final loaded = await LocalDraftExportPlugin().loadDraft('legacy');
      expect(loaded!.priceLei, 75);
    });

    test('malformed draft is treated as absent', () async {
      SharedPreferences.setMockInitialValues({
        'plantly_export_draft/bad': 'not json',
      });
      expect(await LocalDraftExportPlugin().loadDraft('bad'), isNull);
    });
  });

  group('LocalDraftExportPlugin validation', () {
    test('empty title is an issue', () async {
      final preview =
          await LocalDraftExportPlugin().buildPreview(draft(title: '  '));
      expect(preview.isValid, isFalse);
      expect(preview.issues.first.field, 'title');
    });

    test('over-long title / description / too many photos are flagged',
        () async {
      final preview = await LocalDraftExportPlugin().buildPreview(draft(
        title: 'x' * 65,
        description: 'y' * 2001,
        photos: List.generate(7, (i) => 'sha-$i'),
      ));
      final fields = preview.issues.map((i) => i.field).toSet();
      expect(fields, containsAll(<String>{'title', 'description', 'photos'}));
    });

    test('a well-formed draft is valid', () async {
      final preview = await LocalDraftExportPlugin().buildPreview(draft());
      expect(preview.isValid, isTrue);
    });
  });

  group('LocalDraftExportPlugin submit', () {
    test('emits progress then a terminal success that persists postedAt',
        () async {
      final plugin = LocalDraftExportPlugin();
      final ticks = await plugin.submit(draft()).toList();

      expect(ticks.first.done, isFalse);
      final last = ticks.last;
      expect(last.done, isTrue);
      expect(last.succeeded, isTrue);
      expect(last.fraction, 1.0);
      expect(last.remoteId, isNotNull);

      final saved = await plugin.loadDraft('p1');
      expect(saved!.postedAt, isNotNull);
    });

    test('invalid draft yields a terminal error and no success', () async {
      final ticks =
          await LocalDraftExportPlugin().submit(draft(title: '')).toList();
      expect(ticks.last.done, isTrue);
      expect(ticks.last.error, isNotNull);
      expect(ticks.last.succeeded, isFalse);
    });
  });

  group('PluginRegistry', () {
    test('byId resolves the local plugin; unknown id is null', () {
      final reg = PluginRegistry([LocalDraftExportPlugin()]);
      expect(reg.byId(LocalDraftExportPlugin.pluginId), isNotNull);
      expect(reg.byId('does_not_exist'), isNull);
    });

    test('defaultPlugin falls back to local when no networked plugin', () {
      final reg = PluginRegistry([LocalDraftExportPlugin()]);
      expect(reg.defaultPlugin.manifest.authType, PluginAuthType.none);
    });
  });
}
