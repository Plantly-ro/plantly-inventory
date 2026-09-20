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
  String get nicknameHint => 'e.g. Monstera Bob';

  @override
  String get notesHint => 'optional';

  @override
  String get saving => 'Saving…';

  @override
  String get addPhoto => 'Add photo';

  @override
  String get allPlants => 'All plants';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get search => 'Search plants, notes…';

  @override
  String get searchEmptyStart =>
      'Type to search your plants by nickname or notes.';

  @override
  String searchNoMatch(String query) {
    return 'No plants match \"$query\".';
  }

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

  @override
  String get filterAll => 'All';

  @override
  String get filterOverdue => 'Overdue';

  @override
  String get filterDueToday => 'Due today';

  @override
  String get openingGarden => 'Opening your garden…';

  @override
  String get noSpacesYet =>
      'No spaces yet. Tap + to add a room, shelf, or balcony.';

  @override
  String get addSpace => 'Add a space';

  @override
  String get kindLabel => 'Kind';

  @override
  String get insideLabel => 'Inside (optional)';

  @override
  String get topLevel => '— top level —';

  @override
  String get cancel => 'Cancel';

  @override
  String get addBtn => 'Add';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonOk => 'OK';

  @override
  String get commonTodayLabel => 'Today';

  @override
  String get commonNextLabel => 'Next';

  @override
  String get plantDetailEdit => 'Edit plant';

  @override
  String get plantDetailAddPhotos => 'Add photos';

  @override
  String get plantDetailMoveToSpace => 'Move to space…';

  @override
  String get plantDetailDuplicate => 'Duplicate plant';

  @override
  String get plantDetailPropagate => 'Propagate…';

  @override
  String get plantDetailMuteAll => 'Mute all notifications';

  @override
  String get plantDetailUnmuteAll => 'Unmute notifications';

  @override
  String get plantDetailGift => 'Gave away…';

  @override
  String get plantDetailSold => 'Sold…';

  @override
  String get plantDetailMarkDead => 'Marked dead…';

  @override
  String get plantDetailDelete => 'Delete plant…';

  @override
  String get plantDetailSectionStats => 'STATS';

  @override
  String get plantDetailSectionUpcoming => 'UPCOMING CARE';

  @override
  String get plantDetailSectionTimeline => 'TIMELINE';

  @override
  String get plantDetailSectionLedger => 'LEDGER';

  @override
  String get plantDetailNoReminders =>
      'No reminders yet — tap below to add one.';

  @override
  String get plantDetailAddReminder => 'Add reminder';

  @override
  String get plantDetailNoEvents =>
      'No events yet — log your first watering below.';

  @override
  String get plantDetailDeleteEvent => 'Delete event';

  @override
  String get plantDetailEventRemoved => 'Event removed';

  @override
  String get plantDetailQuickAction => 'Quick-action button';

  @override
  String get plantDetailQuickActionHelp =>
      'Pick which care action the FAB performs with one tap.';

  @override
  String get plantDetailNotInCollection =>
      'This plant is no longer in your collection.';

  @override
  String get plantDetailCaptionTitle => 'Caption this photo';

  @override
  String get plantDetailCaptionHint => 'e.g. yellow leaf spotted';

  @override
  String get plantDetailRemovePhotoTitle => 'Remove photo?';

  @override
  String get plantDetailRemovePhotoBody =>
      'The file stays on disk (other plants may use it) — it just detaches from this plant.';

  @override
  String get logEventTitle => 'Log event';

  @override
  String get logEventWhat => 'WHAT';

  @override
  String get logEventWhen => 'WHEN';

  @override
  String get logEventOther => 'Other';

  @override
  String get logEventOtherHint => 'e.g. spider-mite treatment';

  @override
  String get logEventProduct => 'PRODUCT (OPTIONAL)';

  @override
  String get logEventProductHint => 'e.g. Fern spray';

  @override
  String get logEventNotes => 'NOTES (OPTIONAL)';

  @override
  String get logEventNotesHint => 'e.g. new leaf unfurling';

  @override
  String get logEventEnterName => 'Enter a name for the event';

  @override
  String get editEventTitle => 'Edit event';

  @override
  String get editEventDose => 'DOSE (OPTIONAL)';

  @override
  String get editEventDoseHint => 'e.g. 100 ml';

  @override
  String get addReminderTitle => 'Add reminder';

  @override
  String get addReminderType => 'TYPE';

  @override
  String get addReminderCustom => 'Custom';

  @override
  String get addReminderCustomHint => 'e.g. neem spray';

  @override
  String get addReminderPresets => 'PRESETS';

  @override
  String get addReminderEvery => 'EVERY';

  @override
  String get addReminderUnitMin => 'min';

  @override
  String get addReminderUnitHr => 'hr';

  @override
  String get addReminderUnitDay => 'day';

  @override
  String get addReminderUnitMo => 'mo';

  @override
  String get addReminderRepeat => 'REPEAT';

  @override
  String get addReminderRepeatOnDone => 'After I mark it done';

  @override
  String get addReminderRepeatFixed => 'On a fixed schedule';

  @override
  String get addReminderRepeatOnce => 'Just once';

  @override
  String get addReminderFirstDue => 'FIRST DUE';

  @override
  String get addReminderEnterPositive => 'Enter a positive number';

  @override
  String get addReminderNameCustom => 'Name the custom reminder';

  @override
  String get addReminderFiresOnce => 'FIRES ONCE';

  @override
  String addReminderNextReminders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count REMINDERS',
      one: 'REMINDER',
    );
    return 'NEXT $_temp0';
  }

  @override
  String get addReminderPresetDaily => 'Daily';

  @override
  String get addReminderPresetEveryOtherDay => 'Every other day';

  @override
  String get addReminderPresetWeekly => 'Weekly';

  @override
  String get addReminderPresetMondays => 'Mondays 09:00';

  @override
  String get addReminderPresetBiweekly => 'Bi-weekly';

  @override
  String get addReminderPresetMonthly => 'Monthly';

  @override
  String editReminderTitle(String type) {
    return 'Edit $type reminder';
  }

  @override
  String get editReminderNextDue => 'NEXT DUE';

  @override
  String get editReminderDeleteTitle => 'Delete reminder?';

  @override
  String get editReminderDeleteBody =>
      'Removes this schedule. Past events stay in the timeline.';

  @override
  String get meSectionYou => 'YOU';

  @override
  String get meSectionAppearance => 'APPEARANCE';

  @override
  String get meSectionLists => 'LISTS';

  @override
  String get meSectionNotifications => 'NOTIFICATIONS';

  @override
  String get notificationsWebUnavailable => 'Not available in the browser';

  @override
  String get notificationsWebUnavailableDetail =>
      'The browser version can\'t show system notifications. Reminders still appear in the app and the calendar — use the Android app for alerts.';

  @override
  String get meSectionBackup => 'BACKUP';

  @override
  String get meSectionCalendar => 'CALENDAR';

  @override
  String get meSectionAbout => 'ABOUT';

  @override
  String get meStatsValue => 'Activity by care type, top plants, last 30 days.';

  @override
  String get meStatsLabel => 'Stats';

  @override
  String get mePrivacyLabel => 'Privacy & data';

  @override
  String get mePrivacyValue => 'Crash reports, anonymous usage — both opt-in.';

  @override
  String get meCareTypesLabel => 'Care types';

  @override
  String get meCareTypesValue =>
      'Rename, reorder, or add custom reminders and events.';

  @override
  String get meMutedLabel => 'Muted reminders';

  @override
  String get meMutedValue => 'See what\'s silenced; unmute in one place.';

  @override
  String get meYourName => 'Your name';

  @override
  String get meYourNameEmpty => 'Add one for the greeting.';

  @override
  String get meYourNameHint => 'e.g. Ana';

  @override
  String get calendarToday => 'Today';

  @override
  String get calendarNext => 'Next';

  @override
  String get calendarWeek => 'Week';

  @override
  String get calendarMonth => 'Month';

  @override
  String get calendarYear => 'Year';

  @override
  String get calendarUpcoming => 'UPCOMING';

  @override
  String get calendarDayScheduled => 'SCHEDULED';

  @override
  String get calendarDayDone => 'DONE';

  @override
  String get calendarDayEmpty => 'Nothing scheduled or logged on this day.';

  @override
  String get searchTitle => 'Search';

  @override
  String get careTypesTitle => 'Care types';

  @override
  String get careTypesReset => 'Reset to defaults';

  @override
  String get careTypesResetTitle => 'Reset to defaults?';

  @override
  String get careTypesResetBody =>
      'Restores the built-in 6 types + drops any custom ones. Existing schedules and events keep their keys.';

  @override
  String get statsTitle => 'Stats';

  @override
  String get statsActivityHeader => '30-DAY ACTIVITY BY TYPE';

  @override
  String get statsTopPlants => 'TOP PLANTS — 30 DAYS';

  @override
  String get activityTitle => 'Activity';

  @override
  String get activityEmpty =>
      'No activity yet.\nLog your first care event on any plant.';

  @override
  String get quickLogTitle => 'Quick log';

  @override
  String get quickLogWater => 'Water';

  @override
  String get quickLogFertilize => 'Fertilize';

  @override
  String get quickLogMist => 'Mist';

  @override
  String get quickLogRotate => 'Rotate';

  @override
  String get tipOfTheDay => 'TIP OF THE DAY';

  @override
  String get exportTitleField => 'TITLE';

  @override
  String get exportDescriptionField => 'DESCRIPTION';

  @override
  String get exportPriceField => 'PRICE';

  @override
  String get exportPriceUnit => 'lei';

  @override
  String get exportCategoryField => 'CATEGORY';

  @override
  String get exportCategoryDefault => 'Indoor plant';

  @override
  String get exportLocationField => 'LOCATION';

  @override
  String exportPhotosField(int count) {
    return 'PHOTOS ($count/6)';
  }

  @override
  String get exportNoPhotos =>
      'No photos attached. Add some on the plant detail screen first.';

  @override
  String get exportDraftSaved => 'Draft saved';

  @override
  String get exportPostOnPlantlyRoCta => 'Post on plantly.ro';

  @override
  String get exportSavedLocally =>
      'Saved locally — plantly.ro sync lands in Phase 2';

  @override
  String get tagAdd => 'Add a tag';

  @override
  String get tagHint => 'e.g. variegated';

  @override
  String get tagPickExisting => 'OR PICK EXISTING';

  @override
  String get tagAddTitle => 'Add tag';
}
