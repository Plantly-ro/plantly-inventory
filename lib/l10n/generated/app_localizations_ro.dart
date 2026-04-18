// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'PlantlyInventory';

  @override
  String goodMorning(String name) {
    return 'Bună dimineața, $name';
  }

  @override
  String get statOverdue => 'Întârziate';

  @override
  String get statDueToday => 'Astăzi';

  @override
  String get statPlants => 'Plante';

  @override
  String get statSpaces => 'Spații';

  @override
  String get customizeHome => 'Personalizează ecranul';

  @override
  String get doneBtn => 'Gata';

  @override
  String get snoozeBtn => 'Amână';

  @override
  String get saveDraft => 'Salvează ciorna';

  @override
  String get postNow => 'Publică acum';

  @override
  String get addPlant => 'Adaugă o plantă';

  @override
  String get nickname => 'Nume';

  @override
  String get notesLabel => 'Note';

  @override
  String get addPhoto => 'Adaugă fotografie';

  @override
  String get allPlants => 'Toate plantele';

  @override
  String get recentActivity => 'Activitate recentă';

  @override
  String get search => 'Caută plante, note…';

  @override
  String get spaces => 'Spații';

  @override
  String get thisWeek => 'Săptămâna aceasta';

  @override
  String get rainExpected => 'Se așteaptă ploaie';

  @override
  String get skipOutdoor => 'Sari peste udatul exterior — reprogramăm automat.';

  @override
  String get nothingOverdue => 'Nimic restant — super.';

  @override
  String get allCaughtUp => 'Totul e la zi pentru azi.';

  @override
  String get postOnPlantlyRo => 'Publică pe plantly.ro';

  @override
  String get upcomingCare => 'Îngrijiri viitoare';

  @override
  String get timeline => 'Istoric';
}
