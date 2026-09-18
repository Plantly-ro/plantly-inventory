import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ro.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ro'),
  ];

  /// Application title shown in task switcher and app bar
  ///
  /// In en, this message translates to:
  /// **'PlantlyInventory'**
  String get appTitle;

  /// Greeting on the home screen
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String goodMorning(String name);

  /// No description provided for @statOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get statOverdue;

  /// No description provided for @statDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get statDueToday;

  /// No description provided for @statPlants.
  ///
  /// In en, this message translates to:
  /// **'Plants'**
  String get statPlants;

  /// No description provided for @statSpaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get statSpaces;

  /// No description provided for @customizeHome.
  ///
  /// In en, this message translates to:
  /// **'Customize home'**
  String get customizeHome;

  /// No description provided for @doneBtn.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get doneBtn;

  /// No description provided for @snoozeBtn.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get snoozeBtn;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @postNow.
  ///
  /// In en, this message translates to:
  /// **'Post now'**
  String get postNow;

  /// No description provided for @addPlant.
  ///
  /// In en, this message translates to:
  /// **'Add a plant'**
  String get addPlant;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesLabel;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Monstera Bob'**
  String get nicknameHint;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get notesHint;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @allPlants.
  ///
  /// In en, this message translates to:
  /// **'All plants'**
  String get allPlants;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search plants, notes…'**
  String get search;

  /// No description provided for @searchEmptyStart.
  ///
  /// In en, this message translates to:
  /// **'Type to search your plants by nickname or notes.'**
  String get searchEmptyStart;

  /// No description provided for @searchNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No plants match \"{query}\".'**
  String searchNoMatch(String query);

  /// No description provided for @spaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get spaces;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get thisWeek;

  /// No description provided for @rainExpected.
  ///
  /// In en, this message translates to:
  /// **'Rain expected'**
  String get rainExpected;

  /// No description provided for @skipOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Skip outdoor watering — we\'ll reschedule.'**
  String get skipOutdoor;

  /// No description provided for @nothingOverdue.
  ///
  /// In en, this message translates to:
  /// **'Nothing overdue — nice.'**
  String get nothingOverdue;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up for today.'**
  String get allCaughtUp;

  /// No description provided for @postOnPlantlyRo.
  ///
  /// In en, this message translates to:
  /// **'Post on plantly.ro'**
  String get postOnPlantlyRo;

  /// No description provided for @upcomingCare.
  ///
  /// In en, this message translates to:
  /// **'Upcoming care'**
  String get upcomingCare;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get filterOverdue;

  /// No description provided for @filterDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get filterDueToday;

  /// No description provided for @openingGarden.
  ///
  /// In en, this message translates to:
  /// **'Opening your garden…'**
  String get openingGarden;

  /// No description provided for @noSpacesYet.
  ///
  /// In en, this message translates to:
  /// **'No spaces yet. Tap + to add a room, shelf, or balcony.'**
  String get noSpacesYet;

  /// No description provided for @addSpace.
  ///
  /// In en, this message translates to:
  /// **'Add a space'**
  String get addSpace;

  /// No description provided for @kindLabel.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get kindLabel;

  /// No description provided for @insideLabel.
  ///
  /// In en, this message translates to:
  /// **'Inside (optional)'**
  String get insideLabel;

  /// No description provided for @topLevel.
  ///
  /// In en, this message translates to:
  /// **'— top level —'**
  String get topLevel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @addBtn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addBtn;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonTodayLabel;

  /// No description provided for @commonNextLabel.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNextLabel;

  /// No description provided for @plantDetailEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit plant'**
  String get plantDetailEdit;

  /// No description provided for @plantDetailAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get plantDetailAddPhotos;

  /// No description provided for @plantDetailMoveToSpace.
  ///
  /// In en, this message translates to:
  /// **'Move to space…'**
  String get plantDetailMoveToSpace;

  /// No description provided for @plantDetailDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate plant'**
  String get plantDetailDuplicate;

  /// No description provided for @plantDetailPropagate.
  ///
  /// In en, this message translates to:
  /// **'Propagate…'**
  String get plantDetailPropagate;

  /// No description provided for @plantDetailMuteAll.
  ///
  /// In en, this message translates to:
  /// **'Mute all notifications'**
  String get plantDetailMuteAll;

  /// No description provided for @plantDetailUnmuteAll.
  ///
  /// In en, this message translates to:
  /// **'Unmute notifications'**
  String get plantDetailUnmuteAll;

  /// No description provided for @plantDetailGift.
  ///
  /// In en, this message translates to:
  /// **'Gave away…'**
  String get plantDetailGift;

  /// No description provided for @plantDetailSold.
  ///
  /// In en, this message translates to:
  /// **'Sold…'**
  String get plantDetailSold;

  /// No description provided for @plantDetailMarkDead.
  ///
  /// In en, this message translates to:
  /// **'Marked dead…'**
  String get plantDetailMarkDead;

  /// No description provided for @plantDetailDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete plant…'**
  String get plantDetailDelete;

  /// No description provided for @plantDetailSectionStats.
  ///
  /// In en, this message translates to:
  /// **'STATS'**
  String get plantDetailSectionStats;

  /// No description provided for @plantDetailSectionUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING CARE'**
  String get plantDetailSectionUpcoming;

  /// No description provided for @plantDetailSectionTimeline.
  ///
  /// In en, this message translates to:
  /// **'TIMELINE'**
  String get plantDetailSectionTimeline;

  /// No description provided for @plantDetailSectionLedger.
  ///
  /// In en, this message translates to:
  /// **'LEDGER'**
  String get plantDetailSectionLedger;

  /// No description provided for @plantDetailNoReminders.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet — tap below to add one.'**
  String get plantDetailNoReminders;

  /// No description provided for @plantDetailAddReminder.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get plantDetailAddReminder;

  /// No description provided for @plantDetailNoEvents.
  ///
  /// In en, this message translates to:
  /// **'No events yet — log your first watering below.'**
  String get plantDetailNoEvents;

  /// No description provided for @plantDetailDeleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Delete event'**
  String get plantDetailDeleteEvent;

  /// No description provided for @plantDetailEventRemoved.
  ///
  /// In en, this message translates to:
  /// **'Event removed'**
  String get plantDetailEventRemoved;

  /// No description provided for @plantDetailQuickAction.
  ///
  /// In en, this message translates to:
  /// **'Quick-action button'**
  String get plantDetailQuickAction;

  /// No description provided for @plantDetailQuickActionHelp.
  ///
  /// In en, this message translates to:
  /// **'Pick which care action the FAB performs with one tap.'**
  String get plantDetailQuickActionHelp;

  /// No description provided for @plantDetailNotInCollection.
  ///
  /// In en, this message translates to:
  /// **'This plant is no longer in your collection.'**
  String get plantDetailNotInCollection;

  /// No description provided for @plantDetailCaptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption this photo'**
  String get plantDetailCaptionTitle;

  /// No description provided for @plantDetailCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. yellow leaf spotted'**
  String get plantDetailCaptionHint;

  /// No description provided for @plantDetailRemovePhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove photo?'**
  String get plantDetailRemovePhotoTitle;

  /// No description provided for @plantDetailRemovePhotoBody.
  ///
  /// In en, this message translates to:
  /// **'The file stays on disk (other plants may use it) — it just detaches from this plant.'**
  String get plantDetailRemovePhotoBody;

  /// No description provided for @logEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Log event'**
  String get logEventTitle;

  /// No description provided for @logEventWhat.
  ///
  /// In en, this message translates to:
  /// **'WHAT'**
  String get logEventWhat;

  /// No description provided for @logEventWhen.
  ///
  /// In en, this message translates to:
  /// **'WHEN'**
  String get logEventWhen;

  /// No description provided for @logEventOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get logEventOther;

  /// No description provided for @logEventOtherHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. spider-mite treatment'**
  String get logEventOtherHint;

  /// No description provided for @logEventProduct.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT (OPTIONAL)'**
  String get logEventProduct;

  /// No description provided for @logEventProductHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Fern spray'**
  String get logEventProductHint;

  /// No description provided for @logEventNotes.
  ///
  /// In en, this message translates to:
  /// **'NOTES (OPTIONAL)'**
  String get logEventNotes;

  /// No description provided for @logEventNotesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. new leaf unfurling'**
  String get logEventNotesHint;

  /// No description provided for @logEventEnterName.
  ///
  /// In en, this message translates to:
  /// **'Enter a name for the event'**
  String get logEventEnterName;

  /// No description provided for @editEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get editEventTitle;

  /// No description provided for @editEventDose.
  ///
  /// In en, this message translates to:
  /// **'DOSE (OPTIONAL)'**
  String get editEventDose;

  /// No description provided for @editEventDoseHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 100 ml'**
  String get editEventDoseHint;

  /// No description provided for @addReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get addReminderTitle;

  /// No description provided for @addReminderType.
  ///
  /// In en, this message translates to:
  /// **'TYPE'**
  String get addReminderType;

  /// No description provided for @addReminderCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get addReminderCustom;

  /// No description provided for @addReminderCustomHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. neem spray'**
  String get addReminderCustomHint;

  /// No description provided for @addReminderPresets.
  ///
  /// In en, this message translates to:
  /// **'PRESETS'**
  String get addReminderPresets;

  /// No description provided for @addReminderEvery.
  ///
  /// In en, this message translates to:
  /// **'EVERY'**
  String get addReminderEvery;

  /// No description provided for @addReminderUnitMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get addReminderUnitMin;

  /// No description provided for @addReminderUnitHr.
  ///
  /// In en, this message translates to:
  /// **'hr'**
  String get addReminderUnitHr;

  /// No description provided for @addReminderUnitDay.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get addReminderUnitDay;

  /// No description provided for @addReminderUnitMo.
  ///
  /// In en, this message translates to:
  /// **'mo'**
  String get addReminderUnitMo;

  /// No description provided for @addReminderRepeat.
  ///
  /// In en, this message translates to:
  /// **'REPEAT'**
  String get addReminderRepeat;

  /// No description provided for @addReminderRepeatOnDone.
  ///
  /// In en, this message translates to:
  /// **'After I mark it done'**
  String get addReminderRepeatOnDone;

  /// No description provided for @addReminderRepeatFixed.
  ///
  /// In en, this message translates to:
  /// **'On a fixed schedule'**
  String get addReminderRepeatFixed;

  /// No description provided for @addReminderRepeatOnce.
  ///
  /// In en, this message translates to:
  /// **'Just once'**
  String get addReminderRepeatOnce;

  /// No description provided for @addReminderFirstDue.
  ///
  /// In en, this message translates to:
  /// **'FIRST DUE'**
  String get addReminderFirstDue;

  /// No description provided for @addReminderEnterPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive number'**
  String get addReminderEnterPositive;

  /// No description provided for @addReminderNameCustom.
  ///
  /// In en, this message translates to:
  /// **'Name the custom reminder'**
  String get addReminderNameCustom;

  /// No description provided for @addReminderFiresOnce.
  ///
  /// In en, this message translates to:
  /// **'FIRES ONCE'**
  String get addReminderFiresOnce;

  /// No description provided for @addReminderNextReminders.
  ///
  /// In en, this message translates to:
  /// **'NEXT {count, plural, =1{REMINDER} other{{count} REMINDERS}}'**
  String addReminderNextReminders(int count);

  /// No description provided for @addReminderPresetDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get addReminderPresetDaily;

  /// No description provided for @addReminderPresetEveryOtherDay.
  ///
  /// In en, this message translates to:
  /// **'Every other day'**
  String get addReminderPresetEveryOtherDay;

  /// No description provided for @addReminderPresetWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get addReminderPresetWeekly;

  /// No description provided for @addReminderPresetMondays.
  ///
  /// In en, this message translates to:
  /// **'Mondays 09:00'**
  String get addReminderPresetMondays;

  /// No description provided for @addReminderPresetBiweekly.
  ///
  /// In en, this message translates to:
  /// **'Bi-weekly'**
  String get addReminderPresetBiweekly;

  /// No description provided for @addReminderPresetMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get addReminderPresetMonthly;

  /// No description provided for @editReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {type} reminder'**
  String editReminderTitle(String type);

  /// No description provided for @editReminderNextDue.
  ///
  /// In en, this message translates to:
  /// **'NEXT DUE'**
  String get editReminderNextDue;

  /// No description provided for @editReminderDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete reminder?'**
  String get editReminderDeleteTitle;

  /// No description provided for @editReminderDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Removes this schedule. Past events stay in the timeline.'**
  String get editReminderDeleteBody;

  /// No description provided for @meSectionYou.
  ///
  /// In en, this message translates to:
  /// **'YOU'**
  String get meSectionYou;

  /// No description provided for @meSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get meSectionAppearance;

  /// No description provided for @meSectionLists.
  ///
  /// In en, this message translates to:
  /// **'LISTS'**
  String get meSectionLists;

  /// No description provided for @meSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get meSectionNotifications;

  /// Me screen row value shown on the web build, where OS notifications can't be scheduled
  ///
  /// In en, this message translates to:
  /// **'Not available in the browser'**
  String get notificationsWebUnavailable;

  /// Notifications screen permission card body on the web build
  ///
  /// In en, this message translates to:
  /// **'The browser version can\'t show system notifications. Reminders still appear in the app and the calendar — use the Android app for alerts.'**
  String get notificationsWebUnavailableDetail;

  /// No description provided for @meSectionBackup.
  ///
  /// In en, this message translates to:
  /// **'BACKUP'**
  String get meSectionBackup;

  /// No description provided for @meSectionCalendar.
  ///
  /// In en, this message translates to:
  /// **'CALENDAR'**
  String get meSectionCalendar;

  /// No description provided for @meSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get meSectionAbout;

  /// No description provided for @meStatsValue.
  ///
  /// In en, this message translates to:
  /// **'Activity by care type, top plants, last 30 days.'**
  String get meStatsValue;

  /// No description provided for @meStatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get meStatsLabel;

  /// No description provided for @mePrivacyLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get mePrivacyLabel;

  /// No description provided for @mePrivacyValue.
  ///
  /// In en, this message translates to:
  /// **'Crash reports, anonymous usage — both opt-in.'**
  String get mePrivacyValue;

  /// No description provided for @meCareTypesLabel.
  ///
  /// In en, this message translates to:
  /// **'Care types'**
  String get meCareTypesLabel;

  /// No description provided for @meCareTypesValue.
  ///
  /// In en, this message translates to:
  /// **'Rename, reorder, or add custom reminders and events.'**
  String get meCareTypesValue;

  /// No description provided for @meMutedLabel.
  ///
  /// In en, this message translates to:
  /// **'Muted reminders'**
  String get meMutedLabel;

  /// No description provided for @meMutedValue.
  ///
  /// In en, this message translates to:
  /// **'See what\'s silenced; unmute in one place.'**
  String get meMutedValue;

  /// No description provided for @meYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get meYourName;

  /// No description provided for @meYourNameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add one for the greeting.'**
  String get meYourNameEmpty;

  /// No description provided for @meYourNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ana'**
  String get meYourNameHint;

  /// No description provided for @calendarToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// No description provided for @calendarNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get calendarNext;

  /// No description provided for @calendarWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarWeek;

  /// No description provided for @calendarMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarMonth;

  /// No description provided for @calendarYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get calendarYear;

  /// No description provided for @calendarUpcoming.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get calendarUpcoming;

  /// No description provided for @calendarDayScheduled.
  ///
  /// In en, this message translates to:
  /// **'SCHEDULED'**
  String get calendarDayScheduled;

  /// No description provided for @calendarDayDone.
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get calendarDayDone;

  /// No description provided for @calendarDayEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled or logged on this day.'**
  String get calendarDayEmpty;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchTitle;

  /// No description provided for @careTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'Care types'**
  String get careTypesTitle;

  /// No description provided for @careTypesReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get careTypesReset;

  /// No description provided for @careTypesResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults?'**
  String get careTypesResetTitle;

  /// No description provided for @careTypesResetBody.
  ///
  /// In en, this message translates to:
  /// **'Restores the built-in 6 types + drops any custom ones. Existing schedules and events keep their keys.'**
  String get careTypesResetBody;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsTitle;

  /// No description provided for @statsActivityHeader.
  ///
  /// In en, this message translates to:
  /// **'30-DAY ACTIVITY BY TYPE'**
  String get statsActivityHeader;

  /// No description provided for @statsTopPlants.
  ///
  /// In en, this message translates to:
  /// **'TOP PLANTS — 30 DAYS'**
  String get statsTopPlants;

  /// No description provided for @activityTitle.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activityTitle;

  /// No description provided for @activityEmpty.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.\nLog your first care event on any plant.'**
  String get activityEmpty;

  /// No description provided for @quickLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick log'**
  String get quickLogTitle;

  /// No description provided for @quickLogWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get quickLogWater;

  /// No description provided for @quickLogFertilize.
  ///
  /// In en, this message translates to:
  /// **'Fertilize'**
  String get quickLogFertilize;

  /// No description provided for @quickLogMist.
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get quickLogMist;

  /// No description provided for @quickLogRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get quickLogRotate;

  /// No description provided for @tipOfTheDay.
  ///
  /// In en, this message translates to:
  /// **'TIP OF THE DAY'**
  String get tipOfTheDay;

  /// No description provided for @exportTitleField.
  ///
  /// In en, this message translates to:
  /// **'TITLE'**
  String get exportTitleField;

  /// No description provided for @exportDescriptionField.
  ///
  /// In en, this message translates to:
  /// **'DESCRIPTION'**
  String get exportDescriptionField;

  /// No description provided for @exportPriceField.
  ///
  /// In en, this message translates to:
  /// **'PRICE'**
  String get exportPriceField;

  /// No description provided for @exportPriceUnit.
  ///
  /// In en, this message translates to:
  /// **'lei'**
  String get exportPriceUnit;

  /// No description provided for @exportCategoryField.
  ///
  /// In en, this message translates to:
  /// **'CATEGORY'**
  String get exportCategoryField;

  /// No description provided for @exportCategoryDefault.
  ///
  /// In en, this message translates to:
  /// **'Indoor plant'**
  String get exportCategoryDefault;

  /// No description provided for @exportLocationField.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get exportLocationField;

  /// No description provided for @exportPhotosField.
  ///
  /// In en, this message translates to:
  /// **'PHOTOS ({count}/6)'**
  String exportPhotosField(int count);

  /// No description provided for @exportNoPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos attached. Add some on the plant detail screen first.'**
  String get exportNoPhotos;

  /// No description provided for @exportDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved'**
  String get exportDraftSaved;

  /// No description provided for @exportPostOnPlantlyRoCta.
  ///
  /// In en, this message translates to:
  /// **'Post on plantly.ro'**
  String get exportPostOnPlantlyRoCta;

  /// No description provided for @exportSavedLocally.
  ///
  /// In en, this message translates to:
  /// **'Saved locally — plantly.ro sync lands in Phase 2'**
  String get exportSavedLocally;

  /// No description provided for @tagAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a tag'**
  String get tagAdd;

  /// No description provided for @tagHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. variegated'**
  String get tagHint;

  /// No description provided for @tagPickExisting.
  ///
  /// In en, this message translates to:
  /// **'OR PICK EXISTING'**
  String get tagPickExisting;

  /// No description provided for @tagAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get tagAddTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ro'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ro':
      return AppLocalizationsRo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
