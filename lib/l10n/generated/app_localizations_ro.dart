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
  String get nicknameHint => 'ex.: Monstera Bob';

  @override
  String get notesHint => 'opțional';

  @override
  String get saving => 'Se salvează…';

  @override
  String get addPhoto => 'Adaugă fotografie';

  @override
  String get allPlants => 'Toate plantele';

  @override
  String get recentActivity => 'Activitate recentă';

  @override
  String get search => 'Caută plante, note…';

  @override
  String get searchEmptyStart =>
      'Scrie pentru a căuta plantele după nume sau note.';

  @override
  String searchNoMatch(String query) {
    return 'Nicio plantă nu corespunde \"$query\".';
  }

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

  @override
  String get filterAll => 'Toate';

  @override
  String get filterOverdue => 'Întârziate';

  @override
  String get filterDueToday => 'Astăzi';

  @override
  String get openingGarden => 'Se deschide grădina ta…';

  @override
  String get noSpacesYet =>
      'Niciun spațiu încă. Apasă + pentru a adăuga o cameră, un raft sau balcon.';

  @override
  String get addSpace => 'Adaugă un spațiu';

  @override
  String get kindLabel => 'Tip';

  @override
  String get insideLabel => 'În interiorul (opțional)';

  @override
  String get topLevel => '— nivel superior —';

  @override
  String get cancel => 'Renunță';

  @override
  String get addBtn => 'Adaugă';
}
