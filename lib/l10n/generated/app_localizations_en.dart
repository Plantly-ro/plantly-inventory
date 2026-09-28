// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeTip1Title => 'Check soil moisture before watering';

  @override
  String get homeTip1Body =>
      'Most houseplants prefer the top 2–3 cm to dry out between waterings.';

  @override
  String get homeTip2Title => 'Rotate toward the light';

  @override
  String get homeTip2Body =>
      'A quarter turn each week keeps growth even and upright.';

  @override
  String get homeTip3Title => 'Feed lightly in growing season';

  @override
  String get homeTip3Body =>
      'Dilute fertiliser to half-strength to avoid root burn on sensitive species.';

  @override
  String get homeTip4Title => 'Watch for pests after seasonal change';

  @override
  String get homeTip4Body =>
      'Thrips and spider mites love warm, dry indoor air — check leaf undersides.';

  @override
  String get homeTip5Title => 'Repot when roots circle the pot';

  @override
  String get homeTip5Body =>
      'Go up one pot size only — oversized pots hold too much moisture.';

  @override
  String get homeTip6Title => 'Wipe dust off leaves';

  @override
  String get homeTip6Body =>
      'Clean leaves photosynthesise better and let you spot pests early.';

  @override
  String get homeTip7Title => 'Humidity helps aroids + calatheas';

  @override
  String get homeTip7Body =>
      'Group plants or run a pebble tray — easier than misting all day.';

  @override
  String get navHome => 'Home';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navSpaces => 'Spaces';

  @override
  String get navMe => 'Me';

  @override
  String homeDbOpenFailed(String error) {
    return 'Failed to open local database.\n$error';
  }

  @override
  String get homeSearchTooltip => 'Search plants';

  @override
  String get homeEditHint => 'Long-press to customise your home';

  @override
  String get homeAddWidget => 'ADD WIDGET';

  @override
  String get homePresets => 'PRESETS';

  @override
  String get homeResetDefault => 'Reset to default';

  @override
  String get homeAllWidgetsAdded =>
      'Every widget is already on your home screen. Apply a preset below to reshuffle.';

  @override
  String get homeAddBtn => '+ Add';

  @override
  String get homeNoPlantsTitle => 'No plants yet';

  @override
  String get homeNoPlantsBody =>
      'Tap the + button to add your first plant. You can set up reminders once it lands.';

  @override
  String get homeNotifOffBanner =>
      'Notifications are off — reminders won\'t fire. Tap to enable.';

  @override
  String get homeWidgetGreeting => 'Greeting';

  @override
  String get homeWidgetStats => 'Stats row';

  @override
  String get homeWidgetTip => 'Tip of the day';

  @override
  String get homeWidgetOverdue => 'Overdue';

  @override
  String get homeWidgetToday => 'Due today';

  @override
  String get homeWidgetGrid => 'All plants (grid)';

  @override
  String get homeWidgetActivity => 'Recent activity';

  @override
  String get homeWidgetQuickLog => 'Quick log';

  @override
  String get homePresetGrouped => 'Grouped';

  @override
  String get homePresetDashboard => 'Dashboard';

  @override
  String get homePresetFeed => 'Feed';

  @override
  String get homePresetMinimal => 'Minimal';

  @override
  String get homeMoveUp => 'Move up';

  @override
  String get homeMoveDown => 'Move down';

  @override
  String get homeGreetingStillUp => 'Still up?';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeCareWater => 'Water';

  @override
  String get homeCareFertilize => 'Fertilize';

  @override
  String get homeCareMist => 'Mist';

  @override
  String get homeCareRepot => 'Repot';

  @override
  String get homeCarePrune => 'Prune';

  @override
  String get homeCareRotate => 'Rotate';

  @override
  String get homeCareDoneWater => 'Watered';

  @override
  String get homeCareDoneFertilize => 'Fertilized';

  @override
  String get homeCareDoneMist => 'Misted';

  @override
  String get homeCareDoneRepot => 'Repotted';

  @override
  String get homeCareDonePrune => 'Pruned';

  @override
  String get homeCareDoneRotate => 'Rotated';

  @override
  String get homeCareDoneGeneric => 'Logged';

  @override
  String homeOverdueLate(int days, String action) {
    return '$days d late · $action';
  }

  @override
  String homeDueNow(String action) {
    return '$action now';
  }

  @override
  String homeToastLoggedCare(String name) {
    return 'Logged care for $name';
  }

  @override
  String homeToastActionLogged(String action, String name) {
    return '$action logged for $name';
  }

  @override
  String get homeViewAll => 'View all';

  @override
  String get homeActivityEmpty =>
      'Nothing logged yet — tap \"Done\" on a reminder.';

  @override
  String get homeYesterday => 'Yesterday';

  @override
  String homeDaysAgo(int days) {
    return '$days d ago';
  }

  @override
  String get homeSearchAction => 'Search';

  @override
  String get homeGridEmptyAll => 'No plants yet — tap the + button to add one.';

  @override
  String get homeGridEmptyDueToday => 'Nothing due today — all caught up.';

  @override
  String homeLoadPlantsFailed(String error) {
    return 'Could not load plants.\n$error';
  }

  @override
  String get homeSortTooltip => 'Sort plants';

  @override
  String get homeSortNameAZ => 'Name A–Z';

  @override
  String get homeSortNameZA => 'Name Z–A';

  @override
  String get homeSortNextDue => 'Next due';

  @override
  String get homeSortNewest => 'Newest added';

  @override
  String get homeSortOldest => 'Oldest added';

  @override
  String get homeSortBySpace => 'By space';

  @override
  String homeDueLateDays(int days) {
    return '$days d late';
  }

  @override
  String homeDueLateHours(int hours) {
    return '$hours h late';
  }

  @override
  String get homeDueNowShort => 'now';

  @override
  String get homeDueUnderHour => '< 1h';

  @override
  String homeDueInHours(int hours) {
    return 'in $hours h';
  }

  @override
  String get homeDueTomorrow => 'tomorrow';

  @override
  String homeDueInDays(int days) {
    return 'in $days d';
  }

  @override
  String homeBulkSelected(int count) {
    return '$count selected';
  }

  @override
  String get homeBulkMove => 'Move';

  @override
  String get homeBulkMute => 'Mute';

  @override
  String get homeBulkUnmute => 'Unmute';

  @override
  String homeBulkRemovedFromSpace(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count plants from any space',
      one: 'Removed 1 plant from any space',
    );
    return '$_temp0';
  }

  @override
  String homeBulkMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moved $count plants',
      one: 'Moved 1 plant',
    );
    return '$_temp0';
  }

  @override
  String homeBulkDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count plants?',
      one: 'Delete 1 plant?',
    );
    return '$_temp0';
  }

  @override
  String get homeBulkDeleteBody =>
      'Use Gave away / Sold / Marked dead from a single plant if you want a ledger entry instead.';

  @override
  String homeBulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count plants',
      one: 'Deleted 1 plant',
    );
    return '$_temp0';
  }

  @override
  String get homeBulkUndo => 'Undo';

  @override
  String homeQuickLogWhich(String action) {
    return '$action which plant?';
  }

  @override
  String get homeQuickLogRecordsNow => 'Records a care event immediately.';

  @override
  String get homeQuickLogEmpty => 'No plants yet — add one from Home.';

  @override
  String get addPlantNicknameLabel => 'NICKNAME';

  @override
  String get addPlantSpaceLabel => 'SPACE';

  @override
  String get addPlantNotesLabel => 'NOTES';

  @override
  String get addPlantNoLocation => '— no location —';

  @override
  String get addPlantLoading => 'Loading…';

  @override
  String get addPlantAddSpaceFirst => 'Add a space from the Spaces tab first.';

  @override
  String get addPlantSubmit => 'Add plant';

  @override
  String get onbContinue => 'Continue';

  @override
  String get onbStart => 'Start using Plantly';

  @override
  String get onbWelcomeTitle => 'Welcome to Plantly';

  @override
  String get onbWelcomeBody =>
      'A calm, offline-first way to track your houseplants — watering, fertilising, propagation, spaces, and more. Everything lives on your phone.';

  @override
  String get onbNameLabel => 'YOUR NAME (OPTIONAL)';

  @override
  String get onbNameHelp =>
      'We use this only in the greeting at the top of the home screen. You can change or remove it later in Me.';

  @override
  String get onbNotifTitle => 'Plant reminders';

  @override
  String get onbNotifBody =>
      'We schedule local notifications on your phone when a plant is due for care. Nothing is sent to a server.';

  @override
  String get onbNotifGranted => 'Reminders are enabled.';

  @override
  String get onbNotifAsk => 'Grant permission so reminders can fire.';

  @override
  String get onbGrant => 'Grant';

  @override
  String get onbNotifSkip =>
      'You can skip this and turn reminders on later in Me → Notifications.';

  @override
  String get onbPrivacyTitle => 'Help us improve';

  @override
  String get onbPrivacyBody =>
      'Both are off by default. Plant data never leaves your device for any reason. You can change these any time in Me → Privacy & data.';

  @override
  String get onbCrashTitle => 'Crash reports';

  @override
  String get onbCrashSub =>
      'Send a stack trace if the app crashes. No plant data, no photos.';

  @override
  String get onbUsageTitle => 'Anonymous usage';

  @override
  String get onbUsageSub =>
      'Tap counts by screen — helps us know which features are loved.';

  @override
  String get spaceKindHome => 'Home';

  @override
  String get spaceKindRoom => 'Room';

  @override
  String get spaceKindZone => 'Zone';

  @override
  String get spaceKindShelf => 'Shelf';

  @override
  String get spaceKindOutdoorBed => 'Outdoor bed';

  @override
  String spaceLoadFailed(String error) {
    return 'Could not load locations.\n$error';
  }

  @override
  String spacePlantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count plants',
      one: '1 plant',
    );
    return '$_temp0';
  }

  @override
  String get spaceAddPlants => 'Add plants';

  @override
  String get spaceManage => 'Manage';

  @override
  String get spaceNameRequired => 'Name is required';

  @override
  String spaceEditTitle(String name) {
    return 'Edit \"$name\"';
  }

  @override
  String get spaceNameLabel => 'NAME';

  @override
  String get spaceNameHint => 'e.g. Living room';

  @override
  String get spaceKindUpper => 'KIND';

  @override
  String get spaceInsideLabel => 'INSIDE (OPTIONAL)';

  @override
  String get spaceTopLevelHint => 'Top level';

  @override
  String get spaceOutdoor => 'Outdoor';

  @override
  String get spaceOutdoorSub => 'Exposed to weather';

  @override
  String get spaceLightLabel => 'LIGHT LEVEL (OPTIONAL)';

  @override
  String get spaceUnspecifiedHint => 'Unspecified';

  @override
  String get spaceUnspecified => '— unspecified —';

  @override
  String get spaceLightBrightDirect => 'bright direct';

  @override
  String get spaceLightBrightIndirect => 'bright indirect';

  @override
  String get spaceLightMedium => 'medium';

  @override
  String get spaceLightLow => 'low';

  @override
  String get spaceHumidityLabel => 'HUMIDITY RANGE (% — optional)';

  @override
  String get spaceMin => 'min';

  @override
  String get spaceMax => 'max';

  @override
  String get spaceTempLabel => 'TEMPERATURE RANGE (°C — optional)';

  @override
  String get spaceNotesLabel => 'NOTES';

  @override
  String spaceAssignTitle(String name) {
    return 'Plants in \"$name\"';
  }

  @override
  String get spaceAssignSub => 'Toggle to add or remove from this space.';

  @override
  String get spaceAssignEmpty => 'No plants to assign yet.';

  @override
  String get spaceInThisSpace => 'In this space';

  @override
  String get spaceInAnotherSpace => 'In another space';

  @override
  String get spaceNoSpace => 'No space';

  @override
  String get spacePickerTitle => 'Move to space';

  @override
  String get spacePickerEmpty => 'No spaces yet — add one from the Spaces tab.';

  @override
  String spaceLoadOneFailed(String error) {
    return 'Failed to load location.\n$error';
  }

  @override
  String get spaceGone => 'Location no longer exists.';

  @override
  String get spaceDeleteTitle => 'Delete space?';

  @override
  String spaceDeleteBody(String name) {
    return 'Removes \"$name\". Plants keep their existing position in other spaces.';
  }

  @override
  String get spaceMenuAssign => 'Assign plants…';

  @override
  String get spaceMenuMute => 'Mute notifications';

  @override
  String get spaceMenuUnmute => 'Unmute notifications';

  @override
  String get spaceMenuAddMap => 'Add map image…';

  @override
  String get spaceMenuRemoveMap => 'Remove map image';

  @override
  String get spaceMenuDelete => 'Delete space…';

  @override
  String get spaceSectionMap => 'MAP';

  @override
  String get spaceDonePlacing => 'Done placing';

  @override
  String get spacePlacePins => 'Place pins';

  @override
  String get spaceSectionGallery => 'GALLERY';

  @override
  String spaceSectionPlants(int count) {
    return 'PLANTS ($count)';
  }

  @override
  String get spaceChipOutdoor => 'outdoor';

  @override
  String spaceChipLight(String light) {
    return 'light: $light';
  }

  @override
  String spaceChipHumidity(String range) {
    return 'humidity $range%';
  }

  @override
  String spaceChipTemp(String range) {
    return 'temp $range°C';
  }

  @override
  String get spaceChipMuted => 'muted';

  @override
  String get spaceAddLayoutTitle => 'Add a layout image';

  @override
  String get spaceAddLayoutBody =>
      'Room photo or a rough sketch — drop plant pins on top.';

  @override
  String get spaceMapMissing => 'Map image missing';

  @override
  String get spacePinHintPlace =>
      'Tap to place • drag to move • long-press to remove';

  @override
  String get spacePinHintDrag => 'Drag pins to move • long-press to remove';

  @override
  String spacePlaced(String name) {
    return 'Placed $name';
  }

  @override
  String get spaceNoPlantsHere => 'No plants here yet.';

  @override
  String get spacePhotoEditDate => 'Edit date';

  @override
  String get spacePhotoEditCaption => 'Edit caption';

  @override
  String get spacePhotoRemove => 'Remove from this space';

  @override
  String get spacePhotoActionsTitle => 'Photo';

  @override
  String get spaceCaptionTitle => 'Caption';

  @override
  String get spaceCaptionHint => 'e.g. morning light corner';

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

  @override
  String exportPostTitle(String name) {
    return 'Post \"$name\"';
  }

  @override
  String get exportCategorySearchHint => 'Search a category (e.g. Monstera)';

  @override
  String get exportCategoryChangeHint => 'Search to change category';

  @override
  String get exportCategoryNoResults =>
      'No matching category — try another word';

  @override
  String get exportCategorySearchFailed =>
      'Couldn\'t reach plantly.ro — check your connection';

  @override
  String get exportCategorySelected => 'Category selected';

  @override
  String get exportCountyPlaceholder => 'County';

  @override
  String get exportCountyTitle => 'County';

  @override
  String get exportCityPlaceholder => 'City';

  @override
  String get exportDeliveryNote =>
      'Pickup only for now — you can enable courier delivery on plantly.ro after posting.';

  @override
  String get exportSaveDraft => 'Save draft';

  @override
  String get exportPostNow => 'Post now';

  @override
  String get exportPosting => 'Posting to plantly.ro…';

  @override
  String get exportPosted => 'Posted on plantly.ro';

  @override
  String exportPostedWithWarnings(String warnings) {
    return 'Posted on plantly.ro — $warnings';
  }

  @override
  String get exportOpenListing => 'Open';

  @override
  String exportFailedServer(String message) {
    return 'Could not post: $message';
  }

  @override
  String get exportIssueTitleRequired => 'Title is required';

  @override
  String get exportIssueTitleTooLong => 'Title is too long (max 64 characters)';

  @override
  String get exportIssueDescriptionTooLong =>
      'Description is too long (max 2000 characters)';

  @override
  String get exportIssuePriceInvalid => 'Enter a price greater than 0';

  @override
  String get exportIssueCategoryRequired => 'Pick a category';

  @override
  String get exportIssuePhotosRequired => 'Select at least one photo';

  @override
  String get exportIssuePhotosTooMany => 'At most 6 photos';

  @override
  String get plantlyLoginTitle => 'Sign in to plantly.ro';

  @override
  String get plantlyLoginSubtitle =>
      'Use your plantly.ro account to post listings.';

  @override
  String get plantlyLoginEmail => 'Email';

  @override
  String get plantlyLoginPassword => 'Password';

  @override
  String get plantlyLoginSubmit => 'Sign in';

  @override
  String get plantlyLoginCreateAccount => 'Create account';

  @override
  String get plantlyLoginForgot => 'Forgot password?';

  @override
  String get plantlyLoginMissingFields => 'Enter your email and password';

  @override
  String get plantlyLoginInvalid => 'Wrong email or password';

  @override
  String get plantlyLoginNotVerified =>
      'Please verify your email first — check your inbox';

  @override
  String get plantlyLoginSuspended => 'This account is suspended';

  @override
  String get plantlyLoginFailed => 'Sign-in failed — please try again';

  @override
  String get plantlyErrorNetwork =>
      'No connection to plantly.ro — check your internet and try again';

  @override
  String get plantlyErrorRateLimited =>
      'Too many attempts — wait a minute and try again';

  @override
  String get plantlyErrorSignInAgain =>
      'Your plantly.ro session expired — sign in again';

  @override
  String get listedOnPlantly => 'Listed on plantly.ro';

  @override
  String get listedStatusActive => 'ACTIVE';

  @override
  String get listedStatusSold => 'SOLD';

  @override
  String get listedOpen => 'Open';

  @override
  String get listedMarkSold => 'Mark as sold';

  @override
  String get listedMarkSoldTitle => 'Mark as sold?';

  @override
  String get listedMarkSoldBody =>
      'The listing on plantly.ro will be closed. This can\'t be undone from the app.';

  @override
  String get listedMarkedSold => 'Marked as sold on plantly.ro';

  @override
  String get listedCancel => 'Cancel';

  @override
  String get meSectionPlantlyAccount => 'PLANTLY ACCOUNT';

  @override
  String get mePlantlyAccountLabel => 'plantly.ro';

  @override
  String mePlantlySignedInAs(String username) {
    return 'Signed in as $username';
  }

  @override
  String get mePlantlySignedOut => 'Sign in';

  @override
  String get mePlantlySignOutTitle => 'Sign out?';

  @override
  String mePlantlySignOutBody(String username) {
    return 'You\'ll be signed out of plantly.ro ($username) on this device.';
  }

  @override
  String get mePlantlySignOut => 'Sign out';

  @override
  String get importTitle => 'Add to your plants';

  @override
  String get importSourceAssistant => 'FROM PLANTLY ASSISTANT';

  @override
  String get importSourceMarketplace => 'FROM PLANTLY.RO';

  @override
  String get importNicknameLabel => 'NICKNAME';

  @override
  String get importNoSchedulesHint =>
      'Care reminders aren\'t created automatically — set them up from the plant page.';

  @override
  String get importRecentDuplicate =>
      'You added this one just now — add again?';

  @override
  String get importCancel => 'Cancel';

  @override
  String get importConfirm => 'Add plant';

  @override
  String get importConfirmAgain => 'Add again';

  @override
  String importHealthLine(String status) {
    return 'Health: $status';
  }

  @override
  String get importHealthHealthy => 'healthy';

  @override
  String get importHealthStressed => 'stressed';

  @override
  String get importHealthDiseased => 'diseased';

  @override
  String get importHealthUnknown => 'unknown';

  @override
  String get importObsYellowing => 'yellowing';

  @override
  String get importObsBrowning => 'browning';

  @override
  String get importObsSpots => 'spots';

  @override
  String get importObsWilting => 'wilting';

  @override
  String get importObsPests => 'pests';

  @override
  String get importObsOther => 'other';

  @override
  String importNotesIdentified(String date) {
    return 'Identified with Plantly Assistant on $date.';
  }

  @override
  String get importNotesIdentifiedNoDate =>
      'Identified with Plantly Assistant.';

  @override
  String importNotesBought(String date) {
    return 'Bought on plantly.ro on $date.';
  }

  @override
  String get importNotesBoughtNoDate => 'Bought on plantly.ro.';

  @override
  String importNotesHealth(String status) {
    return 'Health: $status.';
  }

  @override
  String importNotesObservations(String items) {
    return 'Observations: $items.';
  }

  @override
  String get importErrorTitle => 'Couldn\'t read that plant';

  @override
  String get importErrorMalformed =>
      'The link is damaged or incomplete. Try exporting it again from the other app.';

  @override
  String get importErrorTooLarge =>
      'The link is too large to open. Try exporting it again without the photo.';

  @override
  String get importErrorVersion =>
      'This link was made by a newer app version. Update Plantly Inventory and try again.';

  @override
  String get exportIssueCategoryInvalid =>
      'Pick a category from the search results';

  @override
  String get importErrorSave => 'Couldn\'t save the plant — please try again.';

  @override
  String get exportDraftCta => 'Prepare listing draft';

  @override
  String get exportDraftEyebrow => 'LISTING DRAFT';

  @override
  String exportDraftTitle(String name) {
    return 'Draft \"$name\"';
  }

  @override
  String get exportCategoryPlaceholder => 'Select category';

  @override
  String get exportCategoryTitle => 'Category';

  @override
  String get importErrorDismiss => 'OK';

  @override
  String get meTitle => 'Me';

  @override
  String get meStatCardPlants => 'PLANTS';

  @override
  String get meStatCardSpaces => 'SPACES';

  @override
  String get meAboutApp => 'App';

  @override
  String get meAboutAppValue => 'PlantlyInventory · Phase 1';

  @override
  String get meAboutLicense => 'License';

  @override
  String get meThemeLabel => 'Theme';

  @override
  String get meThemeDark => 'Dark';

  @override
  String get meThemeLight => 'Light';

  @override
  String get meNotificationsLabel => 'Notifications';

  @override
  String get meNotifChecking => 'Checking…';

  @override
  String get meNotifEnabled => 'Enabled';

  @override
  String get meNotifDisabledRetry => 'Disabled — tap to retry';

  @override
  String get meNotifEnabledToast => 'Notifications enabled';

  @override
  String get meNotifStillDenied => 'Still denied — enable in system settings';

  @override
  String get meExportZipLabel => 'Export ZIP (with photos)';

  @override
  String get meExportJsonLabel => 'Export JSON (signed)';

  @override
  String get meExportZipValue => 'Includes every attached photo. Larger file.';

  @override
  String get meExportJsonValue =>
      'HMAC-signed JSON of every plant / schedule / event.';

  @override
  String get meBackupPassphrase => 'Backup passphrase';

  @override
  String get meBackupPassphraseHint => 'Pick anything — needed to import again';

  @override
  String meBackupSaved(String where) {
    return 'Backup saved: $where';
  }

  @override
  String meExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get meImportLabel => 'Import backup';

  @override
  String get meImportValue => 'Pick a .json or .zip from this device.';

  @override
  String get meImportFileType => 'Plantly backup';

  @override
  String get meImportWrongPassphrase => 'Wrong passphrase for this backup.';

  @override
  String meImportInvalidBackup(String message) {
    return 'Invalid backup: $message';
  }

  @override
  String meImportInvalidZip(String message) {
    return 'Invalid ZIP: $message';
  }

  @override
  String meImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String meImportedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count rows',
      one: 'Imported 1 row',
    );
    return '$_temp0';
  }

  @override
  String meImportedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos',
      one: '1 photo',
    );
    return '$_temp0';
  }

  @override
  String get meIcsLabel => 'Download .ics';

  @override
  String get meIcsValue =>
      'Open the next 30 days of reminders in any calendar app.';

  @override
  String get meIcsShareText => 'PlantlyInventory reminders';

  @override
  String meIcsSaved(String where) {
    return '.ics saved: $where';
  }

  @override
  String get meCsvLabel => 'Export CSV';

  @override
  String get meCsvValue =>
      'Plants + care events as a spreadsheet-friendly dump.';

  @override
  String get meCsvShareText => 'PlantlyInventory CSV';

  @override
  String meCsvSaved(String where) {
    return 'CSV saved: $where';
  }

  @override
  String meCsvFailed(String error) {
    return 'CSV export failed: $error';
  }

  @override
  String get mePrivacyTitle => 'Privacy & data';

  @override
  String get mePrivacyWhatLeaves => 'What leaves your device';

  @override
  String get mePrivacyBulletLocal =>
      'Nothing by default. Plants, photos, care events, and schedules live in a local SQLite database on your phone.';

  @override
  String get mePrivacyBulletBackups =>
      'Backups (JSON or ZIP) only leave the device when you tap Export — you choose where they go via the share sheet.';

  @override
  String get mePrivacyBulletNotifications =>
      'Notifications fire locally via the OS alarm system. We do not use a push server.';

  @override
  String get mePrivacyBulletMarketplace =>
      'If you later post a plant to plantly.ro, only the fields you review in the Export dialog are sent — never the full database.';

  @override
  String get mePrivacySectionTelemetry => 'OPT-IN TELEMETRY';

  @override
  String get mePrivacyCrashTitle => 'Crash reports';

  @override
  String get mePrivacyCrashBody =>
      'If the app crashes, send the stack trace to help us fix it. No plant data, no photos.';

  @override
  String get mePrivacyUsageTitle => 'Anonymous usage';

  @override
  String get mePrivacyUsageBody =>
      'Tap counts by screen — so we know which features are loved. No identifiers, no text you enter.';

  @override
  String get mePrivacySectionLegal => 'LEGAL';

  @override
  String get mePrivacyLicenseValue =>
      'AGPL-3.0-or-later · source: github.com/URunDEAD/PlantlyInventory';

  @override
  String get meCareTypeNew => 'New care type';

  @override
  String meCareTypeEdit(String label) {
    return 'Edit \"$label\"';
  }

  @override
  String get meCareTypeLabelField => 'LABEL';

  @override
  String get meCareTypeLabelHint => 'e.g. Neem spray';

  @override
  String get meCareTypeIntervalField => 'DEFAULT INTERVAL (DAYS)';

  @override
  String get meCareTypeIconField => 'ICON';

  @override
  String get meCareTypeColourField => 'COLOUR';

  @override
  String get meCareTypeColourDefault => 'Default';

  @override
  String meCareTypeDefaultEvery(String days, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return 'Default: every $days $_temp0';
  }

  @override
  String get meCareTypeMuteTooltip => 'Mute this care type everywhere';

  @override
  String get meCareTypeUnmuteTooltip => 'Unmute this care type everywhere';

  @override
  String meMutedPlantsHeader(int count) {
    return 'MUTED PLANTS ($count)';
  }

  @override
  String meMutedRemindersHeader(int count) {
    return 'MUTED REMINDERS ($count)';
  }

  @override
  String meMutedSpacesHeader(int count) {
    return 'MUTED SPACES ($count)';
  }

  @override
  String get meMutedPlantBody => 'Every reminder for this plant is silenced.';

  @override
  String get meMutedReminderBody =>
      'Single schedule muted — other reminders for this plant still fire.';

  @override
  String get meMutedSpaceBody => 'Every plant in this space is silenced.';

  @override
  String get meNothingMuted => 'Nothing muted';

  @override
  String get meNothingMutedBody =>
      'Silence reminders per plant, schedule, or space from the relevant detail screen.';

  @override
  String get meUnmute => 'Unmute';

  @override
  String get meDndTitle => 'Do not disturb';

  @override
  String meDndActive(String start, String end) {
    return 'Quiet between $start and $end (reminders delayed)';
  }

  @override
  String get meDndInactive => 'Fire reminders whenever they\'re due';

  @override
  String get meDndStart => 'Start';

  @override
  String get meDndEnd => 'End';

  @override
  String get meNotifPermChecking => 'Checking system permission…';

  @override
  String get meNotifPermGranted =>
      'OS notifications are allowed for PlantlyInventory.';

  @override
  String get meNotifPermDenied =>
      'OS notifications are OFF. Reminders won\'t fire.';

  @override
  String get statsCellPlants => 'PLANTS';

  @override
  String get statsCellEvents => 'EVENTS';

  @override
  String get statsCellLast30 => 'LAST 30d';

  @override
  String get statsEmpty =>
      'No care events yet. Log your first reminder to see stats here.';

  @override
  String statsCardLast(String type) {
    return 'LAST $type';
  }

  @override
  String statsCardAvg(String type) {
    return 'AVG $type';
  }

  @override
  String get statsCardToday => 'today';

  @override
  String statsCardDaysShort(int count) {
    return '${count}d';
  }

  @override
  String statsCardAvgDaysShort(String value) {
    return '~${value}d';
  }

  @override
  String get activityToday => 'TODAY';

  @override
  String get activityYesterday => 'YESTERDAY';

  @override
  String detailLoadFailed(String error) {
    return 'Failed to load plant.\n$error';
  }

  @override
  String get detailNoLocation => 'No location set';

  @override
  String get detailLoadingLocation => 'Loading location…';

  @override
  String detailFabNow(String action) {
    return '$action now';
  }

  @override
  String get detailFabTooltip => 'Long-press to change';

  @override
  String get detailDeleteTitle => 'Delete plant?';

  @override
  String detailDeleteBody(String name) {
    return 'Removes \"$name\" from your collection. Use Gave away / Sold / Marked dead if you want a ledger entry.';
  }

  @override
  String detailDeletedToast(String name) {
    return 'Deleted \"$name\"';
  }

  @override
  String get detailUndo => 'Undo';

  @override
  String detailAddedOn(String date) {
    return 'Added $date';
  }

  @override
  String detailAcquiredOn(String date) {
    return 'Acquired $date';
  }

  @override
  String get detailRemovedFromSpace => 'Removed from any space';

  @override
  String detailMovedTo(String space) {
    return 'Moved to $space';
  }

  @override
  String get detailThatSpace => 'that space';

  @override
  String get detailReorderTooltip => 'Reorder';

  @override
  String get detailEditDateTooltip => 'Edit date';

  @override
  String get detailCaptionTooltip => 'Caption';

  @override
  String get detailMuteReminderTooltip => 'Mute this reminder';

  @override
  String get detailUnmuteReminderTooltip => 'Unmute this reminder';

  @override
  String get detailSnoozedToast => 'Snoozed 3 days';

  @override
  String get detailNoDueDate => 'No due date';

  @override
  String get detailOverdue => 'overdue';

  @override
  String detailOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days overdue',
      one: '1 day overdue',
    );
    return '$_temp0';
  }

  @override
  String get detailDueToday => 'today';

  @override
  String get detailDueTomorrow => 'tomorrow';

  @override
  String detailDueInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count days',
      one: 'in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get detailVerbRepot => 'Repot';

  @override
  String get detailVerbPrune => 'Prune';

  @override
  String get detailPastWater => 'Watered';

  @override
  String get detailPastFertilize => 'Fertilized';

  @override
  String get detailPastMist => 'Misted';

  @override
  String get detailPastRepot => 'Repotted';

  @override
  String get detailPastPrune => 'Pruned';

  @override
  String get detailPastRotate => 'Rotated';

  @override
  String get detailDeleteEventTitle => 'Delete this event?';

  @override
  String detailDeleteEventBody(String text) {
    return 'Removes this \"$text\" record from the timeline.';
  }

  @override
  String get detailLedgerPropagatedOut => 'Propagated off this plant';

  @override
  String get detailLedgerPropagatedIn => 'Propagated from a parent';

  @override
  String detailLedgerGaveTo(String who) {
    return 'Gave to $who';
  }

  @override
  String get detailLedgerSomeone => 'someone';

  @override
  String get detailLedgerSold => 'Sold';

  @override
  String detailLedgerSoldTo(String buyer) {
    return 'Sold to $buyer';
  }

  @override
  String get detailLedgerMarkedDead => 'Marked dead';

  @override
  String get detailReorderPhotosTitle => 'Reorder photos';

  @override
  String detailPhotoN(int n) {
    return 'Photo $n';
  }

  @override
  String get sheetNicknameRequired => 'Nickname is required';

  @override
  String get sheetFieldSpace => 'SPACE';

  @override
  String get sheetFieldSpecies => 'SPECIES';

  @override
  String get sheetSpeciesHint => 'e.g. Monstera deliciosa';

  @override
  String get sheetFieldNotes => 'NOTES';

  @override
  String get sheetNoLocation => '— no location —';

  @override
  String get sheetLoading => 'Loading…';

  @override
  String get sheetGaveAwayTitle => 'Gave away';

  @override
  String get sheetGaveAwayHint => 'Who did you give it to? (optional)';

  @override
  String get sheetSoldTitle => 'Sold';

  @override
  String get sheetSoldHint => 'Buyer (optional)';

  @override
  String get sheetMarkedDeadTitle => 'Marked dead';

  @override
  String sheetInventoryRemoveBody(String name) {
    return 'This will remove \"$name\" from your active collection.';
  }

  @override
  String get sheetPriceHint => 'Price (optional)';

  @override
  String get sheetNotesOptionalHint => 'Notes (optional)';

  @override
  String sheetPropagateTitle(String name) {
    return 'Propagate $name';
  }

  @override
  String get sheetChildNickname => 'Child nickname';

  @override
  String get sheetPropagateNotesHint =>
      'e.g. cut from node 3; rooting in water';

  @override
  String sheetPropagateDefaultName(String name) {
    return '$name · propagation';
  }

  @override
  String get sheetPropagateAction => 'Propagate';

  @override
  String get careTypeWater => 'Water';

  @override
  String get careTypeFertilize => 'Fertilize';

  @override
  String get careTypeMist => 'Mist';

  @override
  String get careTypeRepot => 'Repot';

  @override
  String get careTypePrune => 'Prune';

  @override
  String get careTypeRotate => 'Rotate';

  @override
  String get seedPlantBob => 'Monstera \"Bob\"';

  @override
  String get seedPlantGreen => 'Pothos \"Green\"';

  @override
  String get seedPlantSnake => 'Snake plant';

  @override
  String get seedPlantCala => 'Calathea';

  @override
  String get seedPlantFid => 'Fiddle fig';

  @override
  String get seedPlantFern => 'Fern spray';

  @override
  String get seedPlantSuc => 'Hens & chicks';

  @override
  String get seedPlantPete => 'Prickly Pete';

  @override
  String get seedSpaceHome => 'Home';

  @override
  String get seedSpaceLivingRoom => 'Living room';

  @override
  String get seedSpaceBalcony => 'Balcony';

  @override
  String get notifChannelName => 'Plant care reminders';

  @override
  String get notifChannelDescription =>
      'Watering, fertilising, and other plant care reminders.';

  @override
  String get calPrevious => 'Previous';

  @override
  String get calDayFree => 'Clear';

  @override
  String calOverdueMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min overdue',
      one: '1 min overdue',
    );
    return '$_temp0';
  }

  @override
  String calOverdueHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours overdue',
      one: '1 hour overdue',
    );
    return '$_temp0';
  }

  @override
  String calInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count min',
      one: 'in 1 min',
    );
    return '$_temp0';
  }

  @override
  String calInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'in $count hours',
      one: 'in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String get photoSrcTakePhoto => 'Take photo';

  @override
  String get photoSrcTakePhotoSub => 'Open the camera';

  @override
  String get photoSrcGalleryMulti => 'Choose from gallery';

  @override
  String get photoSrcGalleryMultiSub => 'Select multiple images';

  @override
  String get photoSrcGalleryOne => 'Choose one from gallery';

  @override
  String get photoSrcGalleryOneSub => 'Pick a single image';

  @override
  String get spacePickerChooseTitle => 'Choose a space';

  @override
  String get cloudSectionTitle => 'Cloud';

  @override
  String get cloudScreenTitle => 'Cloud';

  @override
  String get cloudScreenIntro =>
      'Your plants, photos and care history are backed up to your plantly.ro account and kept in sync on every device you sign in on. Nothing leaves this device until you link it.';

  @override
  String get cloudSignInLabel => 'Sign in to plantly.ro';

  @override
  String get cloudSignInPitch =>
      'Back up your plants and sync them across devices';

  @override
  String get cloudNotIncludedLabel => 'Cloud backup & sync';

  @override
  String get cloudNotIncludedValue =>
      'Included with Plantly Pro or Plantly Inventory Cloud';

  @override
  String get cloudChecking => 'Checking your subscription…';

  @override
  String get cloudSubscribeLabel => 'Subscribe on plantly.ro';

  @override
  String get cloudSubscribeValue =>
      'Opens your plantly.ro account in the browser';

  @override
  String get cloudRefreshStatusLabel => 'Refresh status';

  @override
  String get cloudRefreshStatusValue => 'Check your subscription again';

  @override
  String get cloudStatusLabel => 'Cloud sync';

  @override
  String get cloudSettingUp => 'Setting up your cloud collection…';

  @override
  String get cloudSetupFailed => 'Couldn\'t set up cloud sync. Tap to retry.';

  @override
  String get cloudSyncing => 'Syncing…';

  @override
  String get cloudLastSyncNever => 'Not synced yet';

  @override
  String get cloudLastSyncJustNow => 'Synced just now';

  @override
  String cloudLastSyncMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced $count min ago',
      one: 'Synced 1 min ago',
    );
    return '$_temp0';
  }

  @override
  String cloudLastSyncHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced $count hours ago',
      one: 'Synced 1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String cloudLastSyncDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Synced $count days ago',
      one: 'Synced 1 day ago',
    );
    return '$_temp0';
  }

  @override
  String cloudPendingOps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '1 change waiting',
      zero: 'all changes uploaded',
    );
    return '$_temp0';
  }

  @override
  String cloudStorageUsed(String used, String quota) {
    return '$used of $quota used';
  }

  @override
  String get cloudSyncNowLabel => 'Sync now';

  @override
  String get cloudSyncNowValue => 'Upload pending changes and fetch updates';

  @override
  String get cloudPlanLabel => 'Plan';

  @override
  String get cloudEntitlementSourcePro => 'Included with Plantly Pro';

  @override
  String get cloudEntitlementSourceCloud => 'Plantly Inventory Cloud';

  @override
  String cloudRenewsOn(String date) {
    return 'renews $date';
  }

  @override
  String get cloudCollectionLabel => 'Collection';

  @override
  String get cloudLastErrorLabel => 'Last error';

  @override
  String get cloudAccountLabel => 'Account';

  @override
  String cloudAccountValue(String username) {
    return 'Signed in as $username · tap to sign out';
  }

  @override
  String get cloudSignOutTitle => 'Sign out of plantly.ro?';

  @override
  String cloudSignOutBody(String username) {
    return 'Cloud sync pauses until $username signs in again. Your plants stay on this device.';
  }

  @override
  String get cloudSignOut => 'Sign out';

  @override
  String get cloudUnlinkLabel => 'Unlink this device';

  @override
  String get cloudUnlinkValue =>
      'Stop syncing here; keeps local and server data';

  @override
  String get cloudUnlinkTitle => 'Unlink this device?';

  @override
  String get cloudUnlinkBody =>
      'Sync stops on this device. Nothing is deleted: your plants stay here and your data stays in your plantly.ro account. Sign in again any time to relink.';

  @override
  String get cloudUnlink => 'Unlink';

  @override
  String get cloudUnlinked => 'Device unlinked';

  @override
  String get cloudLoginGoogle => 'Continue with Google';

  @override
  String get cloudLoginFacebook => 'Continue with Facebook';

  @override
  String get cloudLoginOr => 'or';

  @override
  String get cloudLoginOauthWaiting =>
      'Finish signing in in your browser — we\'ll pick it up here.';

  @override
  String get cloudSyncOffHere =>
      'Sync is off on this device — tap to turn it on';

  @override
  String cloudHeldByOther(String username) {
    return 'This device holds plants synced by $username.';
  }

  @override
  String cloudMoveToMeLabel(String username) {
    return 'Move this device\'s plants to $username\'s cloud';
  }

  @override
  String cloudMoveToMeValue(String username) {
    return 'They leave $username\'s collection and sync to yours';
  }

  @override
  String get cloudMoveConfirmTitle => 'Move plants to your cloud?';

  @override
  String cloudMoveConfirmBody(String from, String to) {
    return 'Everything on this device leaves $from\'s collection and is uploaded to $to\'s. $from keeps what was already synced from other devices.';
  }

  @override
  String get cloudMove => 'Move';

  @override
  String cloudStartEmptyLabel(String username) {
    return 'Start empty for $username';
  }

  @override
  String cloudStartEmptyValue(String username) {
    return '$username\'s plants stay hidden on this device; sign $username in again to see them';
  }

  @override
  String get cloudErrCollectionUnavailable =>
      'This collection is no longer available — unlink this device and link it again';

  @override
  String get cloudErrQuotaExceeded =>
      'Cloud storage is full — new photos stay on this device until space frees up';

  @override
  String get cloudErrOpTooLarge =>
      'One change is too large to upload and was skipped';

  @override
  String cloudErrOpTooLargeDetail(String detail) {
    return 'One change is too large to upload and was skipped ($detail)';
  }

  @override
  String get cloudErrRetrying => 'Server busy — retrying shortly';

  @override
  String get cloudErrOffline => 'Offline — will sync when you are back online';

  @override
  String get cloudErrGeneric => 'Sync failed — will retry';

  @override
  String get shellSelectPlant => 'Select a plant to see its care history';

  @override
  String get shellSelectSpace => 'Select a space to see what grows there';

  @override
  String get shellSelectSection => 'Choose a section on the left';

  @override
  String get historyColDate => 'Date';

  @override
  String get historyColCare => 'Care';

  @override
  String get historyColDetails => 'Details';

  @override
  String get homeCustomise => 'Customise';

  @override
  String get homeSearchHint => 'Search plants…';

  @override
  String get detailPrevPlant => 'Previous plant';

  @override
  String get detailNextPlant => 'Next plant';

  @override
  String get detailMoreCareActions => 'More care actions';

  @override
  String get detailColCare => 'Care';

  @override
  String get detailColEvery => 'Every';

  @override
  String get detailColNextDue => 'Next due';

  @override
  String get detailFactSpace => 'Space';

  @override
  String get detailFactAcquired => 'Acquired';

  @override
  String get detailFactPotSize => 'Pot size';

  @override
  String get detailFactTags => 'Tags';

  @override
  String get detailFactNotes => 'Notes';

  @override
  String detailEveryNDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String spaceCardPlantCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n plants',
      one: '1 plant',
      zero: 'No plants',
    );
    return '$_temp0';
  }

  @override
  String get homeNoPlantsBodyDesktop =>
      'Add one with the button in the side bar. You can set up reminders once it lands.';

  @override
  String get shareSwitcherTitle => 'Collections';

  @override
  String get shareSwitcherTooltip => 'Switch collection';

  @override
  String get shareMineSection => 'My collections';

  @override
  String get shareSharedWithMe => 'Shared with me';

  @override
  String get shareRoleOwner => 'Owner';

  @override
  String get shareRoleEditor => 'Editor';

  @override
  String get shareJoinWithCode => 'Join with code…';

  @override
  String get shareJoinTitle => 'Join a shared collection';

  @override
  String get shareJoinBody =>
      'Enter the 8-character code from the invite you received.';

  @override
  String get shareJoinCodeLabel => 'Invite code';

  @override
  String get shareJoinCodeInvalid =>
      'Codes are 8 letters or digits (no I, O, 0 or 1).';

  @override
  String get shareJoinButton => 'Join';

  @override
  String get shareJoinSignInFirst =>
      'You will be asked to sign in to plantly.ro first.';

  @override
  String get shareJoinPaywallNote =>
      'You can use this shared collection — it runs on the owner’s plan. Your own plants stay local until you subscribe.';

  @override
  String shareJoined(String name) {
    return 'Joined $name';
  }

  @override
  String get shareJoinErrInvalid =>
      'This invite code is not valid — it may have expired or already been used.';

  @override
  String get shareJoinErrAlreadyMember =>
      'You are already a member of this collection.';

  @override
  String get shareSectionTitle => 'Sharing';

  @override
  String get shareSectionIntro =>
      'Invite family or a plant-sitter to log care in this collection with you.';

  @override
  String get shareActiveLabel => 'Active collection';

  @override
  String shareActiveValue(String name, String role) {
    return '$name · $role';
  }

  @override
  String shareMembersCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get shareInviteLabel => 'Invite someone';

  @override
  String get shareInviteValue => 'Create a code they can enter in their app';

  @override
  String shareInviteTitle(String name) {
    return 'Invite to $name';
  }

  @override
  String get shareInviteCodeHint =>
      'Share this code or link. It works once and expires in 7 days.';

  @override
  String get shareInviteCopy => 'Copy';

  @override
  String get shareInviteCopied => 'Copied';

  @override
  String get shareInviteShare => 'Share';

  @override
  String shareInviteMessage(String name, String url, String code) {
    return 'Join my plant collection “$name” in Plantly Inventory: $url (code $code)';
  }

  @override
  String get shareInviteCreating => 'Creating invite…';

  @override
  String get shareMembersLabel => 'Members';

  @override
  String get shareMembersValue => 'See who has access';

  @override
  String shareMembersTitle(String name) {
    return 'Members of $name';
  }

  @override
  String shareMemberJoined(String date) {
    return 'Joined $date';
  }

  @override
  String get shareMemberYou => 'you';

  @override
  String get shareRemoveMember => 'Remove';

  @override
  String shareRemoveMemberTitle(String username) {
    return 'Remove $username?';
  }

  @override
  String get shareRemoveMemberBody =>
      'They lose access to this collection. What they logged stays.';

  @override
  String shareRemoved(String username) {
    return '$username removed';
  }

  @override
  String get shareLeaveLabel => 'Leave collection';

  @override
  String shareLeaveValue(String name) {
    return 'Stop seeing $name on this device';
  }

  @override
  String shareLeaveTitle(String name) {
    return 'Leave $name?';
  }

  @override
  String get shareLeaveBody => 'You can rejoin later with a new invite.';

  @override
  String get shareLeave => 'Leave';

  @override
  String shareLeft(String name) {
    return 'You left $name';
  }

  @override
  String shareRemovedFromCollection(String name) {
    return 'You were removed from $name';
  }

  @override
  String shareByActor(String name) {
    return 'by $name';
  }

  @override
  String get shareByOtherMember => 'by another member';

  @override
  String shareSwitched(String name) {
    return 'Switched to $name';
  }

  @override
  String get shareSwitchUnavailable =>
      'Switching needs cloud sync to be on for this account.';

  @override
  String shareMeRowValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n collections',
      one: '1 collection',
    );
    return '$_temp0';
  }

  @override
  String get shareNoMembers => 'No members yet';

  @override
  String get shareMembersError => 'Could not load members';

  @override
  String shareErrTooManyInvites(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'You already have $n active invites — wait for one to be used or to expire.',
      one:
          'You already have 1 active invite — wait for it to be used or to expire.',
    );
    return '$_temp0';
  }

  @override
  String get shareErrOwnerOnly => 'Only the owner can invite people.';

  @override
  String get shareErrOwnerCannotLeave =>
      'The owner can’t leave their own collection.';

  @override
  String get shareErrMemberNotFound => 'That person is no longer a member.';

  @override
  String get shareErrOwnerLapsed =>
      'The owner’s plan lapsed — this shared collection is paused until they renew.';

  @override
  String cloudErrRejected(int n, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n changes could not be synced ($reason)',
      one: '1 change could not be synced ($reason)',
    );
    return '$_temp0';
  }

  @override
  String get cloudRejDetailsLabel => 'Details';

  @override
  String get cloudRejDetailsValue => 'See which changes the server refused';

  @override
  String get cloudRejScreenTitle => 'Changes not synced';

  @override
  String get cloudRejScreenIntro =>
      'The server refused these changes. Retry sends them all again; Dismiss keeps them on this device only.';

  @override
  String get cloudRejEmpty => 'Nothing here — every change has synced.';

  @override
  String get cloudRejRetry => 'Retry all';

  @override
  String get cloudRejDismiss => 'Dismiss all';

  @override
  String get cloudRejKindRetrying => 'retrying';

  @override
  String get cloudRejKindParked => 'gave up';

  @override
  String cloudRejRequeued(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n changes queued again',
      one: '1 change queued again',
    );
    return '$_temp0';
  }

  @override
  String get plantlyLoginSubtitleCloud =>
      'Use your plantly.ro account for cloud backup & sync.';

  @override
  String get cloudRejRetryValue => 'Send every listed change again';

  @override
  String get cloudRejDismissValue => 'Keep them on this device only';
}
