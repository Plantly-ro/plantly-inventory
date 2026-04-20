import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/repositories/plant_repository.dart';
import 'package:plantly_inventory/data/repositories/search_repository.dart';
import 'package:plantly_inventory/data/repositories/tag_repository.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

void main() {
  late AppDatabase db;
  late PlantRepository plants;
  late SearchRepository search;
  late TagRepository tags;
  late PlantTagRepository plantTags;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final clock = HlcClock(deviceId: 'test-device');
    final opLog = OpLogWriter(db: db, clock: clock, tenantId: 'tenant-local');
    plants = PlantRepository(db: db, opLog: opLog);
    tags = TagRepository(db: db, opLog: opLog);
    plantTags = PlantTagRepository(db: db, opLog: opLog);
    search = SearchRepository(db: db, tenantId: 'tenant-local');
  });

  tearDown(() async {
    await db.close();
  });

  group('SearchRepository.search', () {
    test('prefix match on nickname — "mons" finds "Monstera Bob"', () async {
      await plants.create(nickname: 'Monstera Bob');
      await plants.create(nickname: 'Pothos Green');
      await plants.create(nickname: 'Snake plant');
      final hits = await search.search('mons');
      expect(hits.map((p) => p.nickname), ['Monstera Bob']);
    });

    test('matches tokens in notes as well as nickname', () async {
      await plants.create(nickname: 'A', notes: 'lives in the kitchen shelf');
      await plants.create(nickname: 'B', notes: 'bright bathroom window');
      final hits = await search.search('kitchen');
      expect(hits.map((p) => p.nickname), ['A']);
    });

    test('multi-token query uses AND semantics', () async {
      await plants.create(nickname: 'Fiddle fig', notes: 'living room');
      await plants.create(nickname: 'Snake fig', notes: 'bedroom');
      final hits = await search.search('fiddle fig');
      expect(hits.map((p) => p.nickname), ['Fiddle fig']);
    });

    test('diacritics are folded via unicode61 remove_diacritics', () async {
      await plants.create(nickname: 'Papăsan Ficus', notes: 'from Timișoara');
      final hits = await search.search('timisoara');
      expect(hits.length, 1);
      expect(hits.single.nickname, 'Papăsan Ficus');
    });

    test('soft-deleted rows are hidden from search', () async {
      final p = await plants.create(nickname: 'will-be-deleted');
      expect((await search.search('will')).length, 1);
      await plants.softDelete(p.id);
      expect((await search.search('will')), isEmpty);
    });

    test('rename updates the FTS index on next search', () async {
      final p = await plants.create(nickname: 'Original');
      expect((await search.search('Original')).length, 1);
      await plants.rename(p.id, 'Renamed');
      expect((await search.search('Original')), isEmpty);
      expect((await search.search('Renamed')).length, 1);
    });

    test('empty query returns empty list', () async {
      await plants.create(nickname: 'X');
      expect(await search.search(''), isEmpty);
      expect(await search.search('   '), isEmpty);
    });

    test('query with FTS metacharacters is safely escaped', () async {
      await plants.create(nickname: 'Acer "palmatum" (japanese maple)');
      // These inputs would normally be FTS operators: unquoted, they'd
      // throw; the repo must wrap each token in quoted phrases.
      final hits = await search.search('acer*');
      expect(hits, isNotEmpty);
      final hits2 = await search.search('palmatum (japanese');
      expect(hits2, isNotEmpty);
    });

    test('tag-name prefix matches via the second pass', () async {
      await plants.create(nickname: 'Variegated monstera');
      final b = await plants.create(nickname: 'Plain pothos');
      final tag = await tags.ensure('variegated');
      await plantTags.attach(b.id, tag.id);
      // Typing "varieg" should match both: `a` via FTS on nickname and
      // `b` via the tag pass — with `a` ranking first.
      final hits = await search.search('varieg');
      expect(hits.map((p) => p.nickname), containsAll(['Variegated monstera', 'Plain pothos']));
    });

    test('tenant isolation — other tenants\' rows are invisible', () async {
      // Insert a raw row belonging to a different tenant, bypassing the
      // plants repo (which hard-codes our tenant) — mimics a future
      // household-sharing spoof attempt.
      await db.customStatement(
        "INSERT INTO plants(id, tenant_id, nickname, status, updated_hlc, device_id) VALUES ('spoof', 'other', 'shadow fig', 'alive', '0-0-x', 'other')",
      );
      await db.customStatement(
        "INSERT INTO plants_fts(plant_id, tenant_id, nickname, notes) VALUES ('spoof', 'other', 'shadow fig', '')",
      );
      final hits = await search.search('shadow');
      expect(hits, isEmpty);
    });
  });
}
