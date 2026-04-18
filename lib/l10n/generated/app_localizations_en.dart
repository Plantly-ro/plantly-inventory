// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PlantlyInventory';

  @override
  String goodMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String get statOverdue => 'Overdue';

  @override
  String get statDueToday => 'Due today';

  @override
  String get statPlants => 'Plants';

  @override
  String get statSpaces => 'Spaces';

  @override
  String get customizeHome => 'Customize home';

  @override
  String get doneBtn => 'Done';

  @override
  String get snoozeBtn => 'Snooze';

  @override
  String get saveDraft => 'Save draft';

  @override
  String get postNow => 'Post now';

  @override
  String get addPlant => 'Add a plant';

  @override
  String get nickname => 'Nickname';

  @override
  String get notesLabel => 'Notes';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get allPlants => 'All plants';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get search => 'Search plants, notes…';

  @override
  String get spaces => 'Spaces';

  @override
  String get thisWeek => 'This week';

  @override
  String get rainExpected => 'Rain expected';

  @override
  String get skipOutdoor => 'Skip outdoor watering — we\'ll reschedule.';

  @override
  String get nothingOverdue => 'Nothing overdue — nice.';

  @override
  String get allCaughtUp => 'All caught up for today.';

  @override
  String get postOnPlantlyRo => 'Post on plantly.ro';

  @override
  String get upcomingCare => 'Upcoming care';

  @override
  String get timeline => 'Timeline';
}
