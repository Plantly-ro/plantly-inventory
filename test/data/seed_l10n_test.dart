import 'dart:ui' show Color;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/data/database/app_database.dart';
import 'package:plantly_inventory/data/mock_plants.dart';
import 'package:plantly_inventory/data/seed.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_en.dart';
import 'package:plantly_inventory/l10n/generated/app_localizations_ro.dart';
import 'package:plantly_inventory/sync/hlc.dart';
import 'package:plantly_inventory/sync/op_log.dart';

/// QA B5 — a Romanian install showed English demo data ("Snake plant",
/// "Fiddle fig", spaces "Home" / "Living room" / "Balcony"). The seed runs
/// once without a BuildContext, so names come from the ARBs via
/// `appLocalizationsForPlatform()` (or an injected `l10n`).
void main() {
  late AppDatabase db;
  late OpLogWriter opLog;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    opLog = OpLogWriter(db: db, clock: HlcClock(deviceId: 'test-device'), tenantId: 'local');
  });

  tearDown(() => db.close());

  Future<List<String>> nicknames() async =>
      (await db.select(db.plants).get()).map((p) => p.nickname).toList()..sort();
  Future<List<String>> spaceNames() async =>
      (await db.select(db.locations).get()).map((l) => l.name).toList()..sort();

  test('Romanian locale seeds Romanian demo plants + spaces', () async {
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsRo());

    expect(await nicknames(), containsAll(<String>[
      'Limba soacrei', // snake plant
      'Ficus lira', // fiddle fig
      'Ferigă', // fern
      'Urechelniță', // hens & chicks
      'Cactus Pete', // prickly pete
      'Monstera "Bob"',
      'Pothos "Green"',
      'Calathea',
    ]));
    expect(await nicknames(), isNot(anyElement(startsWith('Snake'))));
    expect(await spaceNames(), ['Acasă', 'Balcon', 'Sufragerie']);
  });

  test('English locale keeps the original fixture names', () async {
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());

    expect(await nicknames(), containsAll(<String>['Snake plant', 'Fiddle fig', 'Fern spray', 'Hens & chicks', 'Prickly Pete']));
    expect(await spaceNames(), ['Balcony', 'Home', 'Living room']);
  });

  test('every seeded fixture has an ARB-backed name (no silent English fallback)', () {
    final ro = AppLocalizationsRo();
    for (final mock in MockPlants.all) {
      expect(seedPlantName(ro, mock), isNotEmpty, reason: mock.id);
    }
    // ids not in the fixture list fall back to the mock's own name.
    expect(seedPlantName(ro, const MockPlant(id: 'zzz', name: 'Zed', latin: '', location: '', acquired: '', tags: [], swatch: Color(0x00000000))), 'Zed');
  });

  test('without an injected l10n the platform locale is used (no BuildContext needed)', () async {
    TestWidgetsFlutterBinding.ensureInitialized(); // test binding reports en_US
    await seedIfEmpty(db: db, opLog: opLog);
    expect(await nicknames(), contains('Snake plant'));
  });

  test('seed is a no-op on an existing install (names are never rewritten)', () async {
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsEn());
    await seedIfEmpty(db: db, opLog: opLog, l10n: AppLocalizationsRo());
    expect(await nicknames(), contains('Snake plant'));
    expect(await nicknames(), isNot(contains('Limba soacrei')));
    expect(await spaceNames(), ['Balcony', 'Home', 'Living room']);
  });
}
