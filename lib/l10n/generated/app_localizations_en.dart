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
}
