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

  /// No description provided for @homeTip1Title.
  ///
  /// In en, this message translates to:
  /// **'Check soil moisture before watering'**
  String get homeTip1Title;

  /// No description provided for @homeTip1Body.
  ///
  /// In en, this message translates to:
  /// **'Most houseplants prefer the top 2–3 cm to dry out between waterings.'**
  String get homeTip1Body;

  /// No description provided for @homeTip2Title.
  ///
  /// In en, this message translates to:
  /// **'Rotate toward the light'**
  String get homeTip2Title;

  /// No description provided for @homeTip2Body.
  ///
  /// In en, this message translates to:
  /// **'A quarter turn each week keeps growth even and upright.'**
  String get homeTip2Body;

  /// No description provided for @homeTip3Title.
  ///
  /// In en, this message translates to:
  /// **'Feed lightly in growing season'**
  String get homeTip3Title;

  /// No description provided for @homeTip3Body.
  ///
  /// In en, this message translates to:
  /// **'Dilute fertiliser to half-strength to avoid root burn on sensitive species.'**
  String get homeTip3Body;

  /// No description provided for @homeTip4Title.
  ///
  /// In en, this message translates to:
  /// **'Watch for pests after seasonal change'**
  String get homeTip4Title;

  /// No description provided for @homeTip4Body.
  ///
  /// In en, this message translates to:
  /// **'Thrips and spider mites love warm, dry indoor air — check leaf undersides.'**
  String get homeTip4Body;

  /// No description provided for @homeTip5Title.
  ///
  /// In en, this message translates to:
  /// **'Repot when roots circle the pot'**
  String get homeTip5Title;

  /// No description provided for @homeTip5Body.
  ///
  /// In en, this message translates to:
  /// **'Go up one pot size only — oversized pots hold too much moisture.'**
  String get homeTip5Body;

  /// No description provided for @homeTip6Title.
  ///
  /// In en, this message translates to:
  /// **'Wipe dust off leaves'**
  String get homeTip6Title;

  /// No description provided for @homeTip6Body.
  ///
  /// In en, this message translates to:
  /// **'Clean leaves photosynthesise better and let you spot pests early.'**
  String get homeTip6Body;

  /// No description provided for @homeTip7Title.
  ///
  /// In en, this message translates to:
  /// **'Humidity helps aroids + calatheas'**
  String get homeTip7Title;

  /// No description provided for @homeTip7Body.
  ///
  /// In en, this message translates to:
  /// **'Group plants or run a pebble tray — easier than misting all day.'**
  String get homeTip7Body;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get navCalendar;

  /// No description provided for @navSpaces.
  ///
  /// In en, this message translates to:
  /// **'Spaces'**
  String get navSpaces;

  /// No description provided for @navMe.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get navMe;

  /// No description provided for @homeDbOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open local database.\n{error}'**
  String homeDbOpenFailed(String error);

  /// No description provided for @homeSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search plants'**
  String get homeSearchTooltip;

  /// No description provided for @homeEditHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press to customise your home'**
  String get homeEditHint;

  /// No description provided for @homeAddWidget.
  ///
  /// In en, this message translates to:
  /// **'ADD WIDGET'**
  String get homeAddWidget;

  /// No description provided for @homePresets.
  ///
  /// In en, this message translates to:
  /// **'PRESETS'**
  String get homePresets;

  /// No description provided for @homeResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get homeResetDefault;

  /// No description provided for @homeAllWidgetsAdded.
  ///
  /// In en, this message translates to:
  /// **'Every widget is already on your home screen. Apply a preset below to reshuffle.'**
  String get homeAllWidgetsAdded;

  /// No description provided for @homeAddBtn.
  ///
  /// In en, this message translates to:
  /// **'+ Add'**
  String get homeAddBtn;

  /// No description provided for @homeNoPlantsTitle.
  ///
  /// In en, this message translates to:
  /// **'No plants yet'**
  String get homeNoPlantsTitle;

  /// No description provided for @homeNoPlantsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the + button to add your first plant. You can set up reminders once it lands.'**
  String get homeNoPlantsBody;

  /// No description provided for @homeNotifOffBanner.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off — reminders won\'t fire. Tap to enable.'**
  String get homeNotifOffBanner;

  /// No description provided for @homeWidgetGreeting.
  ///
  /// In en, this message translates to:
  /// **'Greeting'**
  String get homeWidgetGreeting;

  /// No description provided for @homeWidgetStats.
  ///
  /// In en, this message translates to:
  /// **'Stats row'**
  String get homeWidgetStats;

  /// No description provided for @homeWidgetTip.
  ///
  /// In en, this message translates to:
  /// **'Tip of the day'**
  String get homeWidgetTip;

  /// No description provided for @homeWidgetOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get homeWidgetOverdue;

  /// No description provided for @homeWidgetToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get homeWidgetToday;

  /// No description provided for @homeWidgetGrid.
  ///
  /// In en, this message translates to:
  /// **'All plants (grid)'**
  String get homeWidgetGrid;

  /// No description provided for @homeWidgetActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get homeWidgetActivity;

  /// No description provided for @homeWidgetQuickLog.
  ///
  /// In en, this message translates to:
  /// **'Quick log'**
  String get homeWidgetQuickLog;

  /// No description provided for @homePresetGrouped.
  ///
  /// In en, this message translates to:
  /// **'Grouped'**
  String get homePresetGrouped;

  /// No description provided for @homePresetDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get homePresetDashboard;

  /// No description provided for @homePresetFeed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get homePresetFeed;

  /// No description provided for @homePresetMinimal.
  ///
  /// In en, this message translates to:
  /// **'Minimal'**
  String get homePresetMinimal;

  /// No description provided for @homeMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get homeMoveUp;

  /// No description provided for @homeMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get homeMoveDown;

  /// No description provided for @homeGreetingStillUp.
  ///
  /// In en, this message translates to:
  /// **'Still up?'**
  String get homeGreetingStillUp;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeCareWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get homeCareWater;

  /// No description provided for @homeCareFertilize.
  ///
  /// In en, this message translates to:
  /// **'Fertilize'**
  String get homeCareFertilize;

  /// No description provided for @homeCareMist.
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get homeCareMist;

  /// No description provided for @homeCareRepot.
  ///
  /// In en, this message translates to:
  /// **'Repot'**
  String get homeCareRepot;

  /// No description provided for @homeCarePrune.
  ///
  /// In en, this message translates to:
  /// **'Prune'**
  String get homeCarePrune;

  /// No description provided for @homeCareRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get homeCareRotate;

  /// No description provided for @homeCareDoneWater.
  ///
  /// In en, this message translates to:
  /// **'Watered'**
  String get homeCareDoneWater;

  /// No description provided for @homeCareDoneFertilize.
  ///
  /// In en, this message translates to:
  /// **'Fertilized'**
  String get homeCareDoneFertilize;

  /// No description provided for @homeCareDoneMist.
  ///
  /// In en, this message translates to:
  /// **'Misted'**
  String get homeCareDoneMist;

  /// No description provided for @homeCareDoneRepot.
  ///
  /// In en, this message translates to:
  /// **'Repotted'**
  String get homeCareDoneRepot;

  /// No description provided for @homeCareDonePrune.
  ///
  /// In en, this message translates to:
  /// **'Pruned'**
  String get homeCareDonePrune;

  /// No description provided for @homeCareDoneRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotated'**
  String get homeCareDoneRotate;

  /// No description provided for @homeCareDoneGeneric.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get homeCareDoneGeneric;

  /// No description provided for @homeOverdueLate.
  ///
  /// In en, this message translates to:
  /// **'{days} d late · {action}'**
  String homeOverdueLate(int days, String action);

  /// No description provided for @homeDueNow.
  ///
  /// In en, this message translates to:
  /// **'{action} now'**
  String homeDueNow(String action);

  /// No description provided for @homeToastLoggedCare.
  ///
  /// In en, this message translates to:
  /// **'Logged care for {name}'**
  String homeToastLoggedCare(String name);

  /// No description provided for @homeToastActionLogged.
  ///
  /// In en, this message translates to:
  /// **'{action} logged for {name}'**
  String homeToastActionLogged(String action, String name);

  /// No description provided for @homeViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get homeViewAll;

  /// No description provided for @homeActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet — tap \"Done\" on a reminder.'**
  String get homeActivityEmpty;

  /// No description provided for @homeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get homeYesterday;

  /// No description provided for @homeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} d ago'**
  String homeDaysAgo(int days);

  /// No description provided for @homeSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSearchAction;

  /// No description provided for @homeGridEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'No plants yet — tap the + button to add one.'**
  String get homeGridEmptyAll;

  /// No description provided for @homeGridEmptyDueToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing due today — all caught up.'**
  String get homeGridEmptyDueToday;

  /// No description provided for @homeLoadPlantsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load plants.\n{error}'**
  String homeLoadPlantsFailed(String error);

  /// No description provided for @homeSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort plants'**
  String get homeSortTooltip;

  /// No description provided for @homeSortNameAZ.
  ///
  /// In en, this message translates to:
  /// **'Name A–Z'**
  String get homeSortNameAZ;

  /// No description provided for @homeSortNameZA.
  ///
  /// In en, this message translates to:
  /// **'Name Z–A'**
  String get homeSortNameZA;

  /// No description provided for @homeSortNextDue.
  ///
  /// In en, this message translates to:
  /// **'Next due'**
  String get homeSortNextDue;

  /// No description provided for @homeSortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest added'**
  String get homeSortNewest;

  /// No description provided for @homeSortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest added'**
  String get homeSortOldest;

  /// No description provided for @homeSortBySpace.
  ///
  /// In en, this message translates to:
  /// **'By space'**
  String get homeSortBySpace;

  /// No description provided for @homeDueLateDays.
  ///
  /// In en, this message translates to:
  /// **'{days} d late'**
  String homeDueLateDays(int days);

  /// No description provided for @homeDueLateHours.
  ///
  /// In en, this message translates to:
  /// **'{hours} h late'**
  String homeDueLateHours(int hours);

  /// No description provided for @homeDueNowShort.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get homeDueNowShort;

  /// No description provided for @homeDueUnderHour.
  ///
  /// In en, this message translates to:
  /// **'< 1h'**
  String get homeDueUnderHour;

  /// No description provided for @homeDueInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours} h'**
  String homeDueInHours(int hours);

  /// No description provided for @homeDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get homeDueTomorrow;

  /// No description provided for @homeDueInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days} d'**
  String homeDueInDays(int days);

  /// No description provided for @homeBulkSelected.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String homeBulkSelected(int count);

  /// No description provided for @homeBulkMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get homeBulkMove;

  /// No description provided for @homeBulkMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get homeBulkMute;

  /// No description provided for @homeBulkUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get homeBulkUnmute;

  /// No description provided for @homeBulkRemovedFromSpace.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Removed 1 plant from any space} other{Removed {count} plants from any space}}'**
  String homeBulkRemovedFromSpace(int count);

  /// No description provided for @homeBulkMoved.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Moved 1 plant} other{Moved {count} plants}}'**
  String homeBulkMoved(int count);

  /// No description provided for @homeBulkDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 plant?} other{Delete {count} plants?}}'**
  String homeBulkDeleteTitle(int count);

  /// No description provided for @homeBulkDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Use Gave away / Sold / Marked dead from a single plant if you want a ledger entry instead.'**
  String get homeBulkDeleteBody;

  /// No description provided for @homeBulkDeleted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Deleted 1 plant} other{Deleted {count} plants}}'**
  String homeBulkDeleted(int count);

  /// No description provided for @homeBulkUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get homeBulkUndo;

  /// No description provided for @homeQuickLogWhich.
  ///
  /// In en, this message translates to:
  /// **'{action} which plant?'**
  String homeQuickLogWhich(String action);

  /// No description provided for @homeQuickLogRecordsNow.
  ///
  /// In en, this message translates to:
  /// **'Records a care event immediately.'**
  String get homeQuickLogRecordsNow;

  /// No description provided for @homeQuickLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plants yet — add one from Home.'**
  String get homeQuickLogEmpty;

  /// No description provided for @addPlantNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'NICKNAME'**
  String get addPlantNicknameLabel;

  /// No description provided for @addPlantSpaceLabel.
  ///
  /// In en, this message translates to:
  /// **'SPACE'**
  String get addPlantSpaceLabel;

  /// No description provided for @addPlantNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get addPlantNotesLabel;

  /// No description provided for @addPlantNoLocation.
  ///
  /// In en, this message translates to:
  /// **'— no location —'**
  String get addPlantNoLocation;

  /// No description provided for @addPlantLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get addPlantLoading;

  /// No description provided for @addPlantAddSpaceFirst.
  ///
  /// In en, this message translates to:
  /// **'Add a space from the Spaces tab first.'**
  String get addPlantAddSpaceFirst;

  /// No description provided for @addPlantSubmit.
  ///
  /// In en, this message translates to:
  /// **'Add plant'**
  String get addPlantSubmit;

  /// No description provided for @onbContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onbContinue;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Start using Plantly'**
  String get onbStart;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Plantly'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A calm, offline-first way to track your houseplants — watering, fertilising, propagation, spaces, and more. Everything lives on your phone.'**
  String get onbWelcomeBody;

  /// No description provided for @onbNameLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR NAME (OPTIONAL)'**
  String get onbNameLabel;

  /// No description provided for @onbNameHelp.
  ///
  /// In en, this message translates to:
  /// **'We use this only in the greeting at the top of the home screen. You can change or remove it later in Me.'**
  String get onbNameHelp;

  /// No description provided for @onbNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Plant reminders'**
  String get onbNotifTitle;

  /// No description provided for @onbNotifBody.
  ///
  /// In en, this message translates to:
  /// **'We schedule local notifications on your phone when a plant is due for care. Nothing is sent to a server.'**
  String get onbNotifBody;

  /// No description provided for @onbNotifGranted.
  ///
  /// In en, this message translates to:
  /// **'Reminders are enabled.'**
  String get onbNotifGranted;

  /// No description provided for @onbNotifAsk.
  ///
  /// In en, this message translates to:
  /// **'Grant permission so reminders can fire.'**
  String get onbNotifAsk;

  /// No description provided for @onbGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get onbGrant;

  /// No description provided for @onbNotifSkip.
  ///
  /// In en, this message translates to:
  /// **'You can skip this and turn reminders on later in Me → Notifications.'**
  String get onbNotifSkip;

  /// No description provided for @onbPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Help us improve'**
  String get onbPrivacyTitle;

  /// No description provided for @onbPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'Both are off by default. Plant data never leaves your device for any reason. You can change these any time in Me → Privacy & data.'**
  String get onbPrivacyBody;

  /// No description provided for @onbCrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash reports'**
  String get onbCrashTitle;

  /// No description provided for @onbCrashSub.
  ///
  /// In en, this message translates to:
  /// **'Send a stack trace if the app crashes. No plant data, no photos.'**
  String get onbCrashSub;

  /// No description provided for @onbUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous usage'**
  String get onbUsageTitle;

  /// No description provided for @onbUsageSub.
  ///
  /// In en, this message translates to:
  /// **'Tap counts by screen — helps us know which features are loved.'**
  String get onbUsageSub;

  /// No description provided for @spaceKindHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get spaceKindHome;

  /// No description provided for @spaceKindRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get spaceKindRoom;

  /// No description provided for @spaceKindZone.
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get spaceKindZone;

  /// No description provided for @spaceKindShelf.
  ///
  /// In en, this message translates to:
  /// **'Shelf'**
  String get spaceKindShelf;

  /// No description provided for @spaceKindOutdoorBed.
  ///
  /// In en, this message translates to:
  /// **'Outdoor bed'**
  String get spaceKindOutdoorBed;

  /// No description provided for @spaceLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load locations.\n{error}'**
  String spaceLoadFailed(String error);

  /// No description provided for @spacePlantCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 plant} other{{count} plants}}'**
  String spacePlantCount(int count);

  /// No description provided for @spaceAddPlants.
  ///
  /// In en, this message translates to:
  /// **'Add plants'**
  String get spaceAddPlants;

  /// No description provided for @spaceManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get spaceManage;

  /// No description provided for @spaceNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get spaceNameRequired;

  /// No description provided for @spaceEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit \"{name}\"'**
  String spaceEditTitle(String name);

  /// No description provided for @spaceNameLabel.
  ///
  /// In en, this message translates to:
  /// **'NAME'**
  String get spaceNameLabel;

  /// No description provided for @spaceNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Living room'**
  String get spaceNameHint;

  /// No description provided for @spaceKindUpper.
  ///
  /// In en, this message translates to:
  /// **'KIND'**
  String get spaceKindUpper;

  /// No description provided for @spaceInsideLabel.
  ///
  /// In en, this message translates to:
  /// **'INSIDE (OPTIONAL)'**
  String get spaceInsideLabel;

  /// No description provided for @spaceTopLevelHint.
  ///
  /// In en, this message translates to:
  /// **'Top level'**
  String get spaceTopLevelHint;

  /// No description provided for @spaceOutdoor.
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get spaceOutdoor;

  /// No description provided for @spaceOutdoorSub.
  ///
  /// In en, this message translates to:
  /// **'Exposed to weather'**
  String get spaceOutdoorSub;

  /// No description provided for @spaceLightLabel.
  ///
  /// In en, this message translates to:
  /// **'LIGHT LEVEL (OPTIONAL)'**
  String get spaceLightLabel;

  /// No description provided for @spaceUnspecifiedHint.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get spaceUnspecifiedHint;

  /// No description provided for @spaceUnspecified.
  ///
  /// In en, this message translates to:
  /// **'— unspecified —'**
  String get spaceUnspecified;

  /// No description provided for @spaceLightBrightDirect.
  ///
  /// In en, this message translates to:
  /// **'bright direct'**
  String get spaceLightBrightDirect;

  /// No description provided for @spaceLightBrightIndirect.
  ///
  /// In en, this message translates to:
  /// **'bright indirect'**
  String get spaceLightBrightIndirect;

  /// No description provided for @spaceLightMedium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get spaceLightMedium;

  /// No description provided for @spaceLightLow.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get spaceLightLow;

  /// No description provided for @spaceHumidityLabel.
  ///
  /// In en, this message translates to:
  /// **'HUMIDITY RANGE (% — optional)'**
  String get spaceHumidityLabel;

  /// No description provided for @spaceMin.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get spaceMin;

  /// No description provided for @spaceMax.
  ///
  /// In en, this message translates to:
  /// **'max'**
  String get spaceMax;

  /// No description provided for @spaceTempLabel.
  ///
  /// In en, this message translates to:
  /// **'TEMPERATURE RANGE (°C — optional)'**
  String get spaceTempLabel;

  /// No description provided for @spaceNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get spaceNotesLabel;

  /// No description provided for @spaceAssignTitle.
  ///
  /// In en, this message translates to:
  /// **'Plants in \"{name}\"'**
  String spaceAssignTitle(String name);

  /// No description provided for @spaceAssignSub.
  ///
  /// In en, this message translates to:
  /// **'Toggle to add or remove from this space.'**
  String get spaceAssignSub;

  /// No description provided for @spaceAssignEmpty.
  ///
  /// In en, this message translates to:
  /// **'No plants to assign yet.'**
  String get spaceAssignEmpty;

  /// No description provided for @spaceInThisSpace.
  ///
  /// In en, this message translates to:
  /// **'In this space'**
  String get spaceInThisSpace;

  /// No description provided for @spaceInAnotherSpace.
  ///
  /// In en, this message translates to:
  /// **'In another space'**
  String get spaceInAnotherSpace;

  /// No description provided for @spaceNoSpace.
  ///
  /// In en, this message translates to:
  /// **'No space'**
  String get spaceNoSpace;

  /// No description provided for @spacePickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Move to space'**
  String get spacePickerTitle;

  /// No description provided for @spacePickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No spaces yet — add one from the Spaces tab.'**
  String get spacePickerEmpty;

  /// No description provided for @spaceLoadOneFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load location.\n{error}'**
  String spaceLoadOneFailed(String error);

  /// No description provided for @spaceGone.
  ///
  /// In en, this message translates to:
  /// **'Location no longer exists.'**
  String get spaceGone;

  /// No description provided for @spaceDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete space?'**
  String get spaceDeleteTitle;

  /// No description provided for @spaceDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Removes \"{name}\". Plants keep their existing position in other spaces.'**
  String spaceDeleteBody(String name);

  /// No description provided for @spaceMenuAssign.
  ///
  /// In en, this message translates to:
  /// **'Assign plants…'**
  String get spaceMenuAssign;

  /// No description provided for @spaceMenuMute.
  ///
  /// In en, this message translates to:
  /// **'Mute notifications'**
  String get spaceMenuMute;

  /// No description provided for @spaceMenuUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute notifications'**
  String get spaceMenuUnmute;

  /// No description provided for @spaceMenuAddMap.
  ///
  /// In en, this message translates to:
  /// **'Add map image…'**
  String get spaceMenuAddMap;

  /// No description provided for @spaceMenuRemoveMap.
  ///
  /// In en, this message translates to:
  /// **'Remove map image'**
  String get spaceMenuRemoveMap;

  /// No description provided for @spaceMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete space…'**
  String get spaceMenuDelete;

  /// No description provided for @spaceSectionMap.
  ///
  /// In en, this message translates to:
  /// **'MAP'**
  String get spaceSectionMap;

  /// No description provided for @spaceDonePlacing.
  ///
  /// In en, this message translates to:
  /// **'Done placing'**
  String get spaceDonePlacing;

  /// No description provided for @spacePlacePins.
  ///
  /// In en, this message translates to:
  /// **'Place pins'**
  String get spacePlacePins;

  /// No description provided for @spaceSectionGallery.
  ///
  /// In en, this message translates to:
  /// **'GALLERY'**
  String get spaceSectionGallery;

  /// No description provided for @spaceSectionPlants.
  ///
  /// In en, this message translates to:
  /// **'PLANTS ({count})'**
  String spaceSectionPlants(int count);

  /// No description provided for @spaceChipOutdoor.
  ///
  /// In en, this message translates to:
  /// **'outdoor'**
  String get spaceChipOutdoor;

  /// No description provided for @spaceChipLight.
  ///
  /// In en, this message translates to:
  /// **'light: {light}'**
  String spaceChipLight(String light);

  /// No description provided for @spaceChipHumidity.
  ///
  /// In en, this message translates to:
  /// **'humidity {range}%'**
  String spaceChipHumidity(String range);

  /// No description provided for @spaceChipTemp.
  ///
  /// In en, this message translates to:
  /// **'temp {range}°C'**
  String spaceChipTemp(String range);

  /// No description provided for @spaceChipMuted.
  ///
  /// In en, this message translates to:
  /// **'muted'**
  String get spaceChipMuted;

  /// No description provided for @spaceAddLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a layout image'**
  String get spaceAddLayoutTitle;

  /// No description provided for @spaceAddLayoutBody.
  ///
  /// In en, this message translates to:
  /// **'Room photo or a rough sketch — drop plant pins on top.'**
  String get spaceAddLayoutBody;

  /// No description provided for @spaceMapMissing.
  ///
  /// In en, this message translates to:
  /// **'Map image missing'**
  String get spaceMapMissing;

  /// No description provided for @spacePinHintPlace.
  ///
  /// In en, this message translates to:
  /// **'Tap to place • drag to move • long-press to remove'**
  String get spacePinHintPlace;

  /// No description provided for @spacePinHintDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag pins to move • long-press to remove'**
  String get spacePinHintDrag;

  /// No description provided for @spacePlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed {name}'**
  String spacePlaced(String name);

  /// No description provided for @spaceNoPlantsHere.
  ///
  /// In en, this message translates to:
  /// **'No plants here yet.'**
  String get spaceNoPlantsHere;

  /// No description provided for @spacePhotoEditDate.
  ///
  /// In en, this message translates to:
  /// **'Edit date'**
  String get spacePhotoEditDate;

  /// No description provided for @spacePhotoEditCaption.
  ///
  /// In en, this message translates to:
  /// **'Edit caption'**
  String get spacePhotoEditCaption;

  /// No description provided for @spacePhotoRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from this space'**
  String get spacePhotoRemove;

  /// No description provided for @spaceCaptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get spaceCaptionTitle;

  /// No description provided for @spaceCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. morning light corner'**
  String get spaceCaptionHint;

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

  /// No description provided for @exportPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Post \"{name}\"'**
  String exportPostTitle(String name);

  /// No description provided for @exportCategorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a category (e.g. Monstera)'**
  String get exportCategorySearchHint;

  /// No description provided for @exportCategoryChangeHint.
  ///
  /// In en, this message translates to:
  /// **'Search to change category'**
  String get exportCategoryChangeHint;

  /// No description provided for @exportCategoryNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching category — try another word'**
  String get exportCategoryNoResults;

  /// No description provided for @exportCategorySearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach plantly.ro — check your connection'**
  String get exportCategorySearchFailed;

  /// No description provided for @exportCategorySelected.
  ///
  /// In en, this message translates to:
  /// **'Category selected'**
  String get exportCategorySelected;

  /// No description provided for @exportCountyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'County'**
  String get exportCountyPlaceholder;

  /// No description provided for @exportCountyTitle.
  ///
  /// In en, this message translates to:
  /// **'County'**
  String get exportCountyTitle;

  /// No description provided for @exportCityPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get exportCityPlaceholder;

  /// No description provided for @exportDeliveryNote.
  ///
  /// In en, this message translates to:
  /// **'Pickup only for now — you can enable courier delivery on plantly.ro after posting.'**
  String get exportDeliveryNote;

  /// No description provided for @exportSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get exportSaveDraft;

  /// No description provided for @exportPostNow.
  ///
  /// In en, this message translates to:
  /// **'Post now'**
  String get exportPostNow;

  /// No description provided for @exportPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting to plantly.ro…'**
  String get exportPosting;

  /// No description provided for @exportPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted on plantly.ro'**
  String get exportPosted;

  /// No description provided for @exportPostedWithWarnings.
  ///
  /// In en, this message translates to:
  /// **'Posted on plantly.ro — {warnings}'**
  String exportPostedWithWarnings(String warnings);

  /// No description provided for @exportOpenListing.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get exportOpenListing;

  /// No description provided for @exportFailedServer.
  ///
  /// In en, this message translates to:
  /// **'Could not post: {message}'**
  String exportFailedServer(String message);

  /// No description provided for @exportIssueTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get exportIssueTitleRequired;

  /// No description provided for @exportIssueTitleTooLong.
  ///
  /// In en, this message translates to:
  /// **'Title is too long (max 64 characters)'**
  String get exportIssueTitleTooLong;

  /// No description provided for @exportIssueDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Description is too long (max 2000 characters)'**
  String get exportIssueDescriptionTooLong;

  /// No description provided for @exportIssuePriceInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a price greater than 0'**
  String get exportIssuePriceInvalid;

  /// No description provided for @exportIssueCategoryRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a category'**
  String get exportIssueCategoryRequired;

  /// No description provided for @exportIssuePhotosRequired.
  ///
  /// In en, this message translates to:
  /// **'Select at least one photo'**
  String get exportIssuePhotosRequired;

  /// No description provided for @exportIssuePhotosTooMany.
  ///
  /// In en, this message translates to:
  /// **'At most 6 photos'**
  String get exportIssuePhotosTooMany;

  /// No description provided for @plantlyLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to plantly.ro'**
  String get plantlyLoginTitle;

  /// No description provided for @plantlyLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use your plantly.ro account to post listings.'**
  String get plantlyLoginSubtitle;

  /// No description provided for @plantlyLoginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get plantlyLoginEmail;

  /// No description provided for @plantlyLoginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get plantlyLoginPassword;

  /// No description provided for @plantlyLoginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get plantlyLoginSubmit;

  /// No description provided for @plantlyLoginCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get plantlyLoginCreateAccount;

  /// No description provided for @plantlyLoginForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get plantlyLoginForgot;

  /// No description provided for @plantlyLoginMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password'**
  String get plantlyLoginMissingFields;

  /// No description provided for @plantlyLoginInvalid.
  ///
  /// In en, this message translates to:
  /// **'Wrong email or password'**
  String get plantlyLoginInvalid;

  /// No description provided for @plantlyLoginNotVerified.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email first — check your inbox'**
  String get plantlyLoginNotVerified;

  /// No description provided for @plantlyLoginSuspended.
  ///
  /// In en, this message translates to:
  /// **'This account is suspended'**
  String get plantlyLoginSuspended;

  /// No description provided for @plantlyLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed — please try again'**
  String get plantlyLoginFailed;

  /// No description provided for @plantlyErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'No connection to plantly.ro — check your internet and try again'**
  String get plantlyErrorNetwork;

  /// No description provided for @plantlyErrorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — wait a minute and try again'**
  String get plantlyErrorRateLimited;

  /// No description provided for @plantlyErrorSignInAgain.
  ///
  /// In en, this message translates to:
  /// **'Your plantly.ro session expired — sign in again'**
  String get plantlyErrorSignInAgain;

  /// No description provided for @listedOnPlantly.
  ///
  /// In en, this message translates to:
  /// **'Listed on plantly.ro'**
  String get listedOnPlantly;

  /// No description provided for @listedStatusActive.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get listedStatusActive;

  /// No description provided for @listedStatusSold.
  ///
  /// In en, this message translates to:
  /// **'SOLD'**
  String get listedStatusSold;

  /// No description provided for @listedOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get listedOpen;

  /// No description provided for @listedMarkSold.
  ///
  /// In en, this message translates to:
  /// **'Mark as sold'**
  String get listedMarkSold;

  /// No description provided for @listedMarkSoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as sold?'**
  String get listedMarkSoldTitle;

  /// No description provided for @listedMarkSoldBody.
  ///
  /// In en, this message translates to:
  /// **'The listing on plantly.ro will be closed. This can\'t be undone from the app.'**
  String get listedMarkSoldBody;

  /// No description provided for @listedMarkedSold.
  ///
  /// In en, this message translates to:
  /// **'Marked as sold on plantly.ro'**
  String get listedMarkedSold;

  /// No description provided for @listedCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get listedCancel;

  /// No description provided for @meSectionPlantlyAccount.
  ///
  /// In en, this message translates to:
  /// **'PLANTLY ACCOUNT'**
  String get meSectionPlantlyAccount;

  /// No description provided for @mePlantlyAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'plantly.ro'**
  String get mePlantlyAccountLabel;

  /// No description provided for @mePlantlySignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username}'**
  String mePlantlySignedInAs(String username);

  /// No description provided for @mePlantlySignedOut.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get mePlantlySignedOut;

  /// No description provided for @mePlantlySignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get mePlantlySignOutTitle;

  /// No description provided for @mePlantlySignOutBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ll be signed out of plantly.ro ({username}) on this device.'**
  String mePlantlySignOutBody(String username);

  /// No description provided for @mePlantlySignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get mePlantlySignOut;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to your plants'**
  String get importTitle;

  /// No description provided for @importSourceAssistant.
  ///
  /// In en, this message translates to:
  /// **'FROM PLANTLY ASSISTANT'**
  String get importSourceAssistant;

  /// No description provided for @importSourceMarketplace.
  ///
  /// In en, this message translates to:
  /// **'FROM PLANTLY.RO'**
  String get importSourceMarketplace;

  /// No description provided for @importNicknameLabel.
  ///
  /// In en, this message translates to:
  /// **'NICKNAME'**
  String get importNicknameLabel;

  /// No description provided for @importNoSchedulesHint.
  ///
  /// In en, this message translates to:
  /// **'Care reminders aren\'t created automatically — set them up from the plant page.'**
  String get importNoSchedulesHint;

  /// No description provided for @importRecentDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You added this one just now — add again?'**
  String get importRecentDuplicate;

  /// No description provided for @importCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get importCancel;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Add plant'**
  String get importConfirm;

  /// No description provided for @importConfirmAgain.
  ///
  /// In en, this message translates to:
  /// **'Add again'**
  String get importConfirmAgain;

  /// No description provided for @importHealthLine.
  ///
  /// In en, this message translates to:
  /// **'Health: {status}'**
  String importHealthLine(String status);

  /// No description provided for @importHealthHealthy.
  ///
  /// In en, this message translates to:
  /// **'healthy'**
  String get importHealthHealthy;

  /// No description provided for @importHealthStressed.
  ///
  /// In en, this message translates to:
  /// **'stressed'**
  String get importHealthStressed;

  /// No description provided for @importHealthDiseased.
  ///
  /// In en, this message translates to:
  /// **'diseased'**
  String get importHealthDiseased;

  /// No description provided for @importHealthUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get importHealthUnknown;

  /// No description provided for @importObsYellowing.
  ///
  /// In en, this message translates to:
  /// **'yellowing'**
  String get importObsYellowing;

  /// No description provided for @importObsBrowning.
  ///
  /// In en, this message translates to:
  /// **'browning'**
  String get importObsBrowning;

  /// No description provided for @importObsSpots.
  ///
  /// In en, this message translates to:
  /// **'spots'**
  String get importObsSpots;

  /// No description provided for @importObsWilting.
  ///
  /// In en, this message translates to:
  /// **'wilting'**
  String get importObsWilting;

  /// No description provided for @importObsPests.
  ///
  /// In en, this message translates to:
  /// **'pests'**
  String get importObsPests;

  /// No description provided for @importObsOther.
  ///
  /// In en, this message translates to:
  /// **'other'**
  String get importObsOther;

  /// No description provided for @importNotesIdentified.
  ///
  /// In en, this message translates to:
  /// **'Identified with Plantly Assistant on {date}.'**
  String importNotesIdentified(String date);

  /// No description provided for @importNotesIdentifiedNoDate.
  ///
  /// In en, this message translates to:
  /// **'Identified with Plantly Assistant.'**
  String get importNotesIdentifiedNoDate;

  /// No description provided for @importNotesBought.
  ///
  /// In en, this message translates to:
  /// **'Bought on plantly.ro on {date}.'**
  String importNotesBought(String date);

  /// No description provided for @importNotesBoughtNoDate.
  ///
  /// In en, this message translates to:
  /// **'Bought on plantly.ro.'**
  String get importNotesBoughtNoDate;

  /// No description provided for @importNotesHealth.
  ///
  /// In en, this message translates to:
  /// **'Health: {status}.'**
  String importNotesHealth(String status);

  /// No description provided for @importNotesObservations.
  ///
  /// In en, this message translates to:
  /// **'Observations: {items}.'**
  String importNotesObservations(String items);

  /// No description provided for @importErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that plant'**
  String get importErrorTitle;

  /// No description provided for @importErrorMalformed.
  ///
  /// In en, this message translates to:
  /// **'The link is damaged or incomplete. Try exporting it again from the other app.'**
  String get importErrorMalformed;

  /// No description provided for @importErrorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The link is too large to open. Try exporting it again without the photo.'**
  String get importErrorTooLarge;

  /// No description provided for @importErrorVersion.
  ///
  /// In en, this message translates to:
  /// **'This link was made by a newer app version. Update Plantly Inventory and try again.'**
  String get importErrorVersion;

  /// No description provided for @exportIssueCategoryInvalid.
  ///
  /// In en, this message translates to:
  /// **'Pick a category from the search results'**
  String get exportIssueCategoryInvalid;

  /// No description provided for @importErrorSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the plant — please try again.'**
  String get importErrorSave;

  /// No description provided for @exportDraftCta.
  ///
  /// In en, this message translates to:
  /// **'Prepare listing draft'**
  String get exportDraftCta;

  /// No description provided for @exportDraftEyebrow.
  ///
  /// In en, this message translates to:
  /// **'LISTING DRAFT'**
  String get exportDraftEyebrow;

  /// No description provided for @exportDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Draft \"{name}\"'**
  String exportDraftTitle(String name);

  /// No description provided for @exportCategoryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get exportCategoryPlaceholder;

  /// No description provided for @exportCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get exportCategoryTitle;

  /// No description provided for @importErrorDismiss.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get importErrorDismiss;

  /// No description provided for @meTitle.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get meTitle;

  /// No description provided for @meStatCardPlants.
  ///
  /// In en, this message translates to:
  /// **'PLANTS'**
  String get meStatCardPlants;

  /// No description provided for @meStatCardSpaces.
  ///
  /// In en, this message translates to:
  /// **'SPACES'**
  String get meStatCardSpaces;

  /// No description provided for @meAboutApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get meAboutApp;

  /// No description provided for @meAboutAppValue.
  ///
  /// In en, this message translates to:
  /// **'PlantlyInventory · Phase 1'**
  String get meAboutAppValue;

  /// No description provided for @meAboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get meAboutLicense;

  /// No description provided for @meThemeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get meThemeLabel;

  /// No description provided for @meThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get meThemeDark;

  /// No description provided for @meThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get meThemeLight;

  /// No description provided for @meNotificationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get meNotificationsLabel;

  /// No description provided for @meNotifChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get meNotifChecking;

  /// No description provided for @meNotifEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get meNotifEnabled;

  /// No description provided for @meNotifDisabledRetry.
  ///
  /// In en, this message translates to:
  /// **'Disabled — tap to retry'**
  String get meNotifDisabledRetry;

  /// No description provided for @meNotifEnabledToast.
  ///
  /// In en, this message translates to:
  /// **'Notifications enabled'**
  String get meNotifEnabledToast;

  /// No description provided for @meNotifStillDenied.
  ///
  /// In en, this message translates to:
  /// **'Still denied — enable in system settings'**
  String get meNotifStillDenied;

  /// No description provided for @meExportZipLabel.
  ///
  /// In en, this message translates to:
  /// **'Export ZIP (with photos)'**
  String get meExportZipLabel;

  /// No description provided for @meExportJsonLabel.
  ///
  /// In en, this message translates to:
  /// **'Export JSON (signed)'**
  String get meExportJsonLabel;

  /// No description provided for @meExportZipValue.
  ///
  /// In en, this message translates to:
  /// **'Includes every attached photo. Larger file.'**
  String get meExportZipValue;

  /// No description provided for @meExportJsonValue.
  ///
  /// In en, this message translates to:
  /// **'HMAC-signed JSON of every plant / schedule / event.'**
  String get meExportJsonValue;

  /// No description provided for @meBackupPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Backup passphrase'**
  String get meBackupPassphrase;

  /// No description provided for @meBackupPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Pick anything — needed to import again'**
  String get meBackupPassphraseHint;

  /// No description provided for @meBackupSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved: {where}'**
  String meBackupSaved(String where);

  /// No description provided for @meExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String meExportFailed(String error);

  /// No description provided for @meImportLabel.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get meImportLabel;

  /// No description provided for @meImportValue.
  ///
  /// In en, this message translates to:
  /// **'Pick a .json or .zip from this device.'**
  String get meImportValue;

  /// No description provided for @meImportFileType.
  ///
  /// In en, this message translates to:
  /// **'Plantly backup'**
  String get meImportFileType;

  /// No description provided for @meImportWrongPassphrase.
  ///
  /// In en, this message translates to:
  /// **'Wrong passphrase for this backup.'**
  String get meImportWrongPassphrase;

  /// No description provided for @meImportInvalidBackup.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup: {message}'**
  String meImportInvalidBackup(String message);

  /// No description provided for @meImportInvalidZip.
  ///
  /// In en, this message translates to:
  /// **'Invalid ZIP: {message}'**
  String meImportInvalidZip(String message);

  /// No description provided for @meImportFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String meImportFailed(String error);

  /// No description provided for @meImportedRows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 row} other{Imported {count} rows}}'**
  String meImportedRows(int count);

  /// No description provided for @meImportedPhotos.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo} other{{count} photos}}'**
  String meImportedPhotos(int count);

  /// No description provided for @meIcsLabel.
  ///
  /// In en, this message translates to:
  /// **'Download .ics'**
  String get meIcsLabel;

  /// No description provided for @meIcsValue.
  ///
  /// In en, this message translates to:
  /// **'Open the next 30 days of reminders in any calendar app.'**
  String get meIcsValue;

  /// No description provided for @meIcsShareText.
  ///
  /// In en, this message translates to:
  /// **'PlantlyInventory reminders'**
  String get meIcsShareText;

  /// No description provided for @meIcsSaved.
  ///
  /// In en, this message translates to:
  /// **'.ics saved: {where}'**
  String meIcsSaved(String where);

  /// No description provided for @meCsvLabel.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get meCsvLabel;

  /// No description provided for @meCsvValue.
  ///
  /// In en, this message translates to:
  /// **'Plants + care events as a spreadsheet-friendly dump.'**
  String get meCsvValue;

  /// No description provided for @meCsvShareText.
  ///
  /// In en, this message translates to:
  /// **'PlantlyInventory CSV'**
  String get meCsvShareText;

  /// No description provided for @meCsvSaved.
  ///
  /// In en, this message translates to:
  /// **'CSV saved: {where}'**
  String meCsvSaved(String where);

  /// No description provided for @meCsvFailed.
  ///
  /// In en, this message translates to:
  /// **'CSV export failed: {error}'**
  String meCsvFailed(String error);

  /// No description provided for @mePrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & data'**
  String get mePrivacyTitle;

  /// No description provided for @mePrivacyWhatLeaves.
  ///
  /// In en, this message translates to:
  /// **'What leaves your device'**
  String get mePrivacyWhatLeaves;

  /// No description provided for @mePrivacyBulletLocal.
  ///
  /// In en, this message translates to:
  /// **'Nothing by default. Plants, photos, care events, and schedules live in a local SQLite database on your phone.'**
  String get mePrivacyBulletLocal;

  /// No description provided for @mePrivacyBulletBackups.
  ///
  /// In en, this message translates to:
  /// **'Backups (JSON or ZIP) only leave the device when you tap Export — you choose where they go via the share sheet.'**
  String get mePrivacyBulletBackups;

  /// No description provided for @mePrivacyBulletNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications fire locally via the OS alarm system. We do not use a push server.'**
  String get mePrivacyBulletNotifications;

  /// No description provided for @mePrivacyBulletMarketplace.
  ///
  /// In en, this message translates to:
  /// **'If you later post a plant to plantly.ro, only the fields you review in the Export dialog are sent — never the full database.'**
  String get mePrivacyBulletMarketplace;

  /// No description provided for @mePrivacySectionTelemetry.
  ///
  /// In en, this message translates to:
  /// **'OPT-IN TELEMETRY'**
  String get mePrivacySectionTelemetry;

  /// No description provided for @mePrivacyCrashTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash reports'**
  String get mePrivacyCrashTitle;

  /// No description provided for @mePrivacyCrashBody.
  ///
  /// In en, this message translates to:
  /// **'If the app crashes, send the stack trace to help us fix it. No plant data, no photos.'**
  String get mePrivacyCrashBody;

  /// No description provided for @mePrivacyUsageTitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous usage'**
  String get mePrivacyUsageTitle;

  /// No description provided for @mePrivacyUsageBody.
  ///
  /// In en, this message translates to:
  /// **'Tap counts by screen — so we know which features are loved. No identifiers, no text you enter.'**
  String get mePrivacyUsageBody;

  /// No description provided for @mePrivacySectionLegal.
  ///
  /// In en, this message translates to:
  /// **'LEGAL'**
  String get mePrivacySectionLegal;

  /// No description provided for @mePrivacyLicenseValue.
  ///
  /// In en, this message translates to:
  /// **'AGPL-3.0-or-later · source: github.com/URunDEAD/PlantlyInventory'**
  String get mePrivacyLicenseValue;

  /// No description provided for @meCareTypeNew.
  ///
  /// In en, this message translates to:
  /// **'New care type'**
  String get meCareTypeNew;

  /// No description provided for @meCareTypeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit \"{label}\"'**
  String meCareTypeEdit(String label);

  /// No description provided for @meCareTypeLabelField.
  ///
  /// In en, this message translates to:
  /// **'LABEL'**
  String get meCareTypeLabelField;

  /// No description provided for @meCareTypeLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Neem spray'**
  String get meCareTypeLabelHint;

  /// No description provided for @meCareTypeIntervalField.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT INTERVAL (DAYS)'**
  String get meCareTypeIntervalField;

  /// No description provided for @meCareTypeIconField.
  ///
  /// In en, this message translates to:
  /// **'ICON'**
  String get meCareTypeIconField;

  /// No description provided for @meCareTypeColourField.
  ///
  /// In en, this message translates to:
  /// **'COLOUR'**
  String get meCareTypeColourField;

  /// No description provided for @meCareTypeColourDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get meCareTypeColourDefault;

  /// No description provided for @meCareTypeDefaultEvery.
  ///
  /// In en, this message translates to:
  /// **'Default: every {days} {count, plural, =1{day} other{days}}'**
  String meCareTypeDefaultEvery(String days, int count);

  /// No description provided for @meCareTypeMuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute this care type everywhere'**
  String get meCareTypeMuteTooltip;

  /// No description provided for @meCareTypeUnmuteTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute this care type everywhere'**
  String get meCareTypeUnmuteTooltip;

  /// No description provided for @meMutedPlantsHeader.
  ///
  /// In en, this message translates to:
  /// **'MUTED PLANTS ({count})'**
  String meMutedPlantsHeader(int count);

  /// No description provided for @meMutedRemindersHeader.
  ///
  /// In en, this message translates to:
  /// **'MUTED REMINDERS ({count})'**
  String meMutedRemindersHeader(int count);

  /// No description provided for @meMutedSpacesHeader.
  ///
  /// In en, this message translates to:
  /// **'MUTED SPACES ({count})'**
  String meMutedSpacesHeader(int count);

  /// No description provided for @meMutedPlantBody.
  ///
  /// In en, this message translates to:
  /// **'Every reminder for this plant is silenced.'**
  String get meMutedPlantBody;

  /// No description provided for @meMutedReminderBody.
  ///
  /// In en, this message translates to:
  /// **'Single schedule muted — other reminders for this plant still fire.'**
  String get meMutedReminderBody;

  /// No description provided for @meMutedSpaceBody.
  ///
  /// In en, this message translates to:
  /// **'Every plant in this space is silenced.'**
  String get meMutedSpaceBody;

  /// No description provided for @meNothingMuted.
  ///
  /// In en, this message translates to:
  /// **'Nothing muted'**
  String get meNothingMuted;

  /// No description provided for @meNothingMutedBody.
  ///
  /// In en, this message translates to:
  /// **'Silence reminders per plant, schedule, or space from the relevant detail screen.'**
  String get meNothingMutedBody;

  /// No description provided for @meUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get meUnmute;

  /// No description provided for @meDndTitle.
  ///
  /// In en, this message translates to:
  /// **'Do not disturb'**
  String get meDndTitle;

  /// No description provided for @meDndActive.
  ///
  /// In en, this message translates to:
  /// **'Quiet between {start} and {end} (reminders delayed)'**
  String meDndActive(String start, String end);

  /// No description provided for @meDndInactive.
  ///
  /// In en, this message translates to:
  /// **'Fire reminders whenever they\'re due'**
  String get meDndInactive;

  /// No description provided for @meDndStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get meDndStart;

  /// No description provided for @meDndEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get meDndEnd;

  /// No description provided for @meNotifPermChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking system permission…'**
  String get meNotifPermChecking;

  /// No description provided for @meNotifPermGranted.
  ///
  /// In en, this message translates to:
  /// **'OS notifications are allowed for PlantlyInventory.'**
  String get meNotifPermGranted;

  /// No description provided for @meNotifPermDenied.
  ///
  /// In en, this message translates to:
  /// **'OS notifications are OFF. Reminders won\'t fire.'**
  String get meNotifPermDenied;

  /// No description provided for @statsCellPlants.
  ///
  /// In en, this message translates to:
  /// **'PLANTS'**
  String get statsCellPlants;

  /// No description provided for @statsCellEvents.
  ///
  /// In en, this message translates to:
  /// **'EVENTS'**
  String get statsCellEvents;

  /// No description provided for @statsCellLast30.
  ///
  /// In en, this message translates to:
  /// **'LAST 30d'**
  String get statsCellLast30;

  /// No description provided for @statsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No care events yet. Log your first reminder to see stats here.'**
  String get statsEmpty;

  /// No description provided for @statsCardLast.
  ///
  /// In en, this message translates to:
  /// **'LAST {type}'**
  String statsCardLast(String type);

  /// No description provided for @statsCardAvg.
  ///
  /// In en, this message translates to:
  /// **'AVG {type}'**
  String statsCardAvg(String type);

  /// No description provided for @statsCardToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get statsCardToday;

  /// No description provided for @statsCardDaysShort.
  ///
  /// In en, this message translates to:
  /// **'{count}d'**
  String statsCardDaysShort(int count);

  /// No description provided for @statsCardAvgDaysShort.
  ///
  /// In en, this message translates to:
  /// **'~{value}d'**
  String statsCardAvgDaysShort(String value);

  /// No description provided for @activityToday.
  ///
  /// In en, this message translates to:
  /// **'TODAY'**
  String get activityToday;

  /// No description provided for @activityYesterday.
  ///
  /// In en, this message translates to:
  /// **'YESTERDAY'**
  String get activityYesterday;

  /// No description provided for @detailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load plant.\n{error}'**
  String detailLoadFailed(String error);

  /// No description provided for @detailNoLocation.
  ///
  /// In en, this message translates to:
  /// **'No location set'**
  String get detailNoLocation;

  /// No description provided for @detailLoadingLocation.
  ///
  /// In en, this message translates to:
  /// **'Loading location…'**
  String get detailLoadingLocation;

  /// No description provided for @detailFabNow.
  ///
  /// In en, this message translates to:
  /// **'{action} now'**
  String detailFabNow(String action);

  /// No description provided for @detailFabTooltip.
  ///
  /// In en, this message translates to:
  /// **'Long-press to change'**
  String get detailFabTooltip;

  /// No description provided for @detailDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete plant?'**
  String get detailDeleteTitle;

  /// No description provided for @detailDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Removes \"{name}\" from your collection. Use Gave away / Sold / Marked dead if you want a ledger entry.'**
  String detailDeleteBody(String name);

  /// No description provided for @detailDeletedToast.
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String detailDeletedToast(String name);

  /// No description provided for @detailUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get detailUndo;

  /// No description provided for @detailAddedOn.
  ///
  /// In en, this message translates to:
  /// **'Added {date}'**
  String detailAddedOn(String date);

  /// No description provided for @detailAcquiredOn.
  ///
  /// In en, this message translates to:
  /// **'Acquired {date}'**
  String detailAcquiredOn(String date);

  /// No description provided for @detailRemovedFromSpace.
  ///
  /// In en, this message translates to:
  /// **'Removed from any space'**
  String get detailRemovedFromSpace;

  /// No description provided for @detailMovedTo.
  ///
  /// In en, this message translates to:
  /// **'Moved to {space}'**
  String detailMovedTo(String space);

  /// No description provided for @detailThatSpace.
  ///
  /// In en, this message translates to:
  /// **'that space'**
  String get detailThatSpace;

  /// No description provided for @detailReorderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get detailReorderTooltip;

  /// No description provided for @detailEditDateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit date'**
  String get detailEditDateTooltip;

  /// No description provided for @detailCaptionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Caption'**
  String get detailCaptionTooltip;

  /// No description provided for @detailMuteReminderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mute this reminder'**
  String get detailMuteReminderTooltip;

  /// No description provided for @detailUnmuteReminderTooltip.
  ///
  /// In en, this message translates to:
  /// **'Unmute this reminder'**
  String get detailUnmuteReminderTooltip;

  /// No description provided for @detailSnoozedToast.
  ///
  /// In en, this message translates to:
  /// **'Snoozed 3 days'**
  String get detailSnoozedToast;

  /// No description provided for @detailNoDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get detailNoDueDate;

  /// No description provided for @detailOverdue.
  ///
  /// In en, this message translates to:
  /// **'overdue'**
  String get detailOverdue;

  /// No description provided for @detailOverdueDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day overdue} other{{count} days overdue}}'**
  String detailOverdueDays(int count);

  /// No description provided for @detailDueToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get detailDueToday;

  /// No description provided for @detailDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get detailDueTomorrow;

  /// No description provided for @detailDueInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 day} other{in {count} days}}'**
  String detailDueInDays(int count);

  /// No description provided for @detailVerbRepot.
  ///
  /// In en, this message translates to:
  /// **'Repot'**
  String get detailVerbRepot;

  /// No description provided for @detailVerbPrune.
  ///
  /// In en, this message translates to:
  /// **'Prune'**
  String get detailVerbPrune;

  /// No description provided for @detailPastWater.
  ///
  /// In en, this message translates to:
  /// **'Watered'**
  String get detailPastWater;

  /// No description provided for @detailPastFertilize.
  ///
  /// In en, this message translates to:
  /// **'Fertilized'**
  String get detailPastFertilize;

  /// No description provided for @detailPastMist.
  ///
  /// In en, this message translates to:
  /// **'Misted'**
  String get detailPastMist;

  /// No description provided for @detailPastRepot.
  ///
  /// In en, this message translates to:
  /// **'Repotted'**
  String get detailPastRepot;

  /// No description provided for @detailPastPrune.
  ///
  /// In en, this message translates to:
  /// **'Pruned'**
  String get detailPastPrune;

  /// No description provided for @detailPastRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotated'**
  String get detailPastRotate;

  /// No description provided for @detailDeleteEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get detailDeleteEventTitle;

  /// No description provided for @detailDeleteEventBody.
  ///
  /// In en, this message translates to:
  /// **'Removes this \"{text}\" record from the timeline.'**
  String detailDeleteEventBody(String text);

  /// No description provided for @detailLedgerPropagatedOut.
  ///
  /// In en, this message translates to:
  /// **'Propagated off this plant'**
  String get detailLedgerPropagatedOut;

  /// No description provided for @detailLedgerPropagatedIn.
  ///
  /// In en, this message translates to:
  /// **'Propagated from a parent'**
  String get detailLedgerPropagatedIn;

  /// No description provided for @detailLedgerGaveTo.
  ///
  /// In en, this message translates to:
  /// **'Gave to {who}'**
  String detailLedgerGaveTo(String who);

  /// No description provided for @detailLedgerSomeone.
  ///
  /// In en, this message translates to:
  /// **'someone'**
  String get detailLedgerSomeone;

  /// No description provided for @detailLedgerSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get detailLedgerSold;

  /// No description provided for @detailLedgerSoldTo.
  ///
  /// In en, this message translates to:
  /// **'Sold to {buyer}'**
  String detailLedgerSoldTo(String buyer);

  /// No description provided for @detailLedgerMarkedDead.
  ///
  /// In en, this message translates to:
  /// **'Marked dead'**
  String get detailLedgerMarkedDead;

  /// No description provided for @detailReorderPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder photos'**
  String get detailReorderPhotosTitle;

  /// No description provided for @detailPhotoN.
  ///
  /// In en, this message translates to:
  /// **'Photo {n}'**
  String detailPhotoN(int n);

  /// No description provided for @sheetNicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Nickname is required'**
  String get sheetNicknameRequired;

  /// No description provided for @sheetFieldSpace.
  ///
  /// In en, this message translates to:
  /// **'SPACE'**
  String get sheetFieldSpace;

  /// No description provided for @sheetFieldSpecies.
  ///
  /// In en, this message translates to:
  /// **'SPECIES'**
  String get sheetFieldSpecies;

  /// No description provided for @sheetSpeciesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Monstera deliciosa'**
  String get sheetSpeciesHint;

  /// No description provided for @sheetFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get sheetFieldNotes;

  /// No description provided for @sheetNoLocation.
  ///
  /// In en, this message translates to:
  /// **'— no location —'**
  String get sheetNoLocation;

  /// No description provided for @sheetLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get sheetLoading;

  /// No description provided for @sheetGaveAwayTitle.
  ///
  /// In en, this message translates to:
  /// **'Gave away'**
  String get sheetGaveAwayTitle;

  /// No description provided for @sheetGaveAwayHint.
  ///
  /// In en, this message translates to:
  /// **'Who did you give it to? (optional)'**
  String get sheetGaveAwayHint;

  /// No description provided for @sheetSoldTitle.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get sheetSoldTitle;

  /// No description provided for @sheetSoldHint.
  ///
  /// In en, this message translates to:
  /// **'Buyer (optional)'**
  String get sheetSoldHint;

  /// No description provided for @sheetMarkedDeadTitle.
  ///
  /// In en, this message translates to:
  /// **'Marked dead'**
  String get sheetMarkedDeadTitle;

  /// No description provided for @sheetInventoryRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{name}\" from your active collection.'**
  String sheetInventoryRemoveBody(String name);

  /// No description provided for @sheetPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Price (optional)'**
  String get sheetPriceHint;

  /// No description provided for @sheetNotesOptionalHint.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get sheetNotesOptionalHint;

  /// No description provided for @sheetPropagateTitle.
  ///
  /// In en, this message translates to:
  /// **'Propagate {name}'**
  String sheetPropagateTitle(String name);

  /// No description provided for @sheetChildNickname.
  ///
  /// In en, this message translates to:
  /// **'Child nickname'**
  String get sheetChildNickname;

  /// No description provided for @sheetPropagateNotesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. cut from node 3; rooting in water'**
  String get sheetPropagateNotesHint;

  /// No description provided for @sheetPropagateDefaultName.
  ///
  /// In en, this message translates to:
  /// **'{name} · propagation'**
  String sheetPropagateDefaultName(String name);

  /// No description provided for @sheetPropagateAction.
  ///
  /// In en, this message translates to:
  /// **'Propagate'**
  String get sheetPropagateAction;

  /// No description provided for @careTypeWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get careTypeWater;

  /// No description provided for @careTypeFertilize.
  ///
  /// In en, this message translates to:
  /// **'Fertilize'**
  String get careTypeFertilize;

  /// No description provided for @careTypeMist.
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get careTypeMist;

  /// No description provided for @careTypeRepot.
  ///
  /// In en, this message translates to:
  /// **'Repot'**
  String get careTypeRepot;

  /// No description provided for @careTypePrune.
  ///
  /// In en, this message translates to:
  /// **'Prune'**
  String get careTypePrune;

  /// No description provided for @careTypeRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get careTypeRotate;

  /// No description provided for @seedPlantBob.
  ///
  /// In en, this message translates to:
  /// **'Monstera \"Bob\"'**
  String get seedPlantBob;

  /// No description provided for @seedPlantGreen.
  ///
  /// In en, this message translates to:
  /// **'Pothos \"Green\"'**
  String get seedPlantGreen;

  /// No description provided for @seedPlantSnake.
  ///
  /// In en, this message translates to:
  /// **'Snake plant'**
  String get seedPlantSnake;

  /// No description provided for @seedPlantCala.
  ///
  /// In en, this message translates to:
  /// **'Calathea'**
  String get seedPlantCala;

  /// No description provided for @seedPlantFid.
  ///
  /// In en, this message translates to:
  /// **'Fiddle fig'**
  String get seedPlantFid;

  /// No description provided for @seedPlantFern.
  ///
  /// In en, this message translates to:
  /// **'Fern spray'**
  String get seedPlantFern;

  /// No description provided for @seedPlantSuc.
  ///
  /// In en, this message translates to:
  /// **'Hens & chicks'**
  String get seedPlantSuc;

  /// No description provided for @seedPlantPete.
  ///
  /// In en, this message translates to:
  /// **'Prickly Pete'**
  String get seedPlantPete;

  /// No description provided for @seedSpaceHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get seedSpaceHome;

  /// No description provided for @seedSpaceLivingRoom.
  ///
  /// In en, this message translates to:
  /// **'Living room'**
  String get seedSpaceLivingRoom;

  /// No description provided for @seedSpaceBalcony.
  ///
  /// In en, this message translates to:
  /// **'Balcony'**
  String get seedSpaceBalcony;

  /// No description provided for @notifChannelName.
  ///
  /// In en, this message translates to:
  /// **'Plant care reminders'**
  String get notifChannelName;

  /// No description provided for @notifChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Watering, fertilising, and other plant care reminders.'**
  String get notifChannelDescription;

  /// No description provided for @calPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get calPrevious;

  /// No description provided for @calDayFree.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get calDayFree;

  /// No description provided for @calOverdueMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 min overdue} other{{count} min overdue}}'**
  String calOverdueMinutes(int count);

  /// No description provided for @calOverdueHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour overdue} other{{count} hours overdue}}'**
  String calOverdueHours(int count);

  /// No description provided for @calInMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 min} other{in {count} min}}'**
  String calInMinutes(int count);

  /// No description provided for @calInHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{in 1 hour} other{in {count} hours}}'**
  String calInHours(int count);

  /// No description provided for @photoSrcTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get photoSrcTakePhoto;

  /// No description provided for @photoSrcTakePhotoSub.
  ///
  /// In en, this message translates to:
  /// **'Open the camera'**
  String get photoSrcTakePhotoSub;

  /// No description provided for @photoSrcGalleryMulti.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get photoSrcGalleryMulti;

  /// No description provided for @photoSrcGalleryMultiSub.
  ///
  /// In en, this message translates to:
  /// **'Select multiple images'**
  String get photoSrcGalleryMultiSub;

  /// No description provided for @photoSrcGalleryOne.
  ///
  /// In en, this message translates to:
  /// **'Choose one from gallery'**
  String get photoSrcGalleryOne;

  /// No description provided for @photoSrcGalleryOneSub.
  ///
  /// In en, this message translates to:
  /// **'Pick a single image'**
  String get photoSrcGalleryOneSub;

  /// No description provided for @spacePickerChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a space'**
  String get spacePickerChooseTitle;

  /// No description provided for @cloudSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloudSectionTitle;

  /// No description provided for @cloudScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud'**
  String get cloudScreenTitle;

  /// No description provided for @cloudScreenIntro.
  ///
  /// In en, this message translates to:
  /// **'Your plants, photos and care history are backed up to your plantly.ro account and kept in sync on every device you sign in on. Nothing leaves this device until you link it.'**
  String get cloudScreenIntro;

  /// No description provided for @cloudSignInLabel.
  ///
  /// In en, this message translates to:
  /// **'Sign in to plantly.ro'**
  String get cloudSignInLabel;

  /// No description provided for @cloudSignInPitch.
  ///
  /// In en, this message translates to:
  /// **'Back up your plants and sync them across devices'**
  String get cloudSignInPitch;

  /// No description provided for @cloudNotIncludedLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup & sync'**
  String get cloudNotIncludedLabel;

  /// No description provided for @cloudNotIncludedValue.
  ///
  /// In en, this message translates to:
  /// **'Included with Plantly Pro or Plantly Inventory Cloud'**
  String get cloudNotIncludedValue;

  /// No description provided for @cloudChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking your subscription…'**
  String get cloudChecking;

  /// No description provided for @cloudSubscribeLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscribe on plantly.ro'**
  String get cloudSubscribeLabel;

  /// No description provided for @cloudSubscribeValue.
  ///
  /// In en, this message translates to:
  /// **'Opens your plantly.ro account in the browser'**
  String get cloudSubscribeValue;

  /// No description provided for @cloudRefreshStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get cloudRefreshStatusLabel;

  /// No description provided for @cloudRefreshStatusValue.
  ///
  /// In en, this message translates to:
  /// **'Check your subscription again'**
  String get cloudRefreshStatusValue;

  /// No description provided for @cloudStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync'**
  String get cloudStatusLabel;

  /// No description provided for @cloudSettingUp.
  ///
  /// In en, this message translates to:
  /// **'Setting up your cloud collection…'**
  String get cloudSettingUp;

  /// No description provided for @cloudSetupFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set up cloud sync. Tap to retry.'**
  String get cloudSetupFailed;

  /// No description provided for @cloudSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get cloudSyncing;

  /// No description provided for @cloudLastSyncNever.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get cloudLastSyncNever;

  /// No description provided for @cloudLastSyncJustNow.
  ///
  /// In en, this message translates to:
  /// **'Synced just now'**
  String get cloudLastSyncJustNow;

  /// No description provided for @cloudLastSyncMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Synced 1 min ago} other{Synced {count} min ago}}'**
  String cloudLastSyncMinutes(int count);

  /// No description provided for @cloudLastSyncHours.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Synced 1 hour ago} other{Synced {count} hours ago}}'**
  String cloudLastSyncHours(int count);

  /// No description provided for @cloudLastSyncDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Synced 1 day ago} other{Synced {count} days ago}}'**
  String cloudLastSyncDays(int count);

  /// No description provided for @cloudPendingOps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{all changes uploaded} =1{1 change waiting} other{{count} changes waiting}}'**
  String cloudPendingOps(int count);

  /// No description provided for @cloudStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {quota} used'**
  String cloudStorageUsed(String used, String quota);

  /// No description provided for @cloudSyncNowLabel.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get cloudSyncNowLabel;

  /// No description provided for @cloudSyncNowValue.
  ///
  /// In en, this message translates to:
  /// **'Upload pending changes and fetch updates'**
  String get cloudSyncNowValue;

  /// No description provided for @cloudPlanLabel.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get cloudPlanLabel;

  /// No description provided for @cloudEntitlementSourcePro.
  ///
  /// In en, this message translates to:
  /// **'Included with Plantly Pro'**
  String get cloudEntitlementSourcePro;

  /// No description provided for @cloudEntitlementSourceCloud.
  ///
  /// In en, this message translates to:
  /// **'Plantly Inventory Cloud'**
  String get cloudEntitlementSourceCloud;

  /// No description provided for @cloudRenewsOn.
  ///
  /// In en, this message translates to:
  /// **'renews {date}'**
  String cloudRenewsOn(String date);

  /// No description provided for @cloudCollectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get cloudCollectionLabel;

  /// No description provided for @cloudLastErrorLabel.
  ///
  /// In en, this message translates to:
  /// **'Last error'**
  String get cloudLastErrorLabel;

  /// No description provided for @cloudAccountLabel.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get cloudAccountLabel;

  /// No description provided for @cloudAccountValue.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {username} · tap to sign out'**
  String cloudAccountValue(String username);

  /// No description provided for @cloudSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out of plantly.ro?'**
  String get cloudSignOutTitle;

  /// No description provided for @cloudSignOutBody.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync pauses until {username} signs in again. Your plants stay on this device.'**
  String cloudSignOutBody(String username);

  /// No description provided for @cloudSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get cloudSignOut;

  /// No description provided for @cloudUnlinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Unlink this device'**
  String get cloudUnlinkLabel;

  /// No description provided for @cloudUnlinkValue.
  ///
  /// In en, this message translates to:
  /// **'Stop syncing here; keeps local and server data'**
  String get cloudUnlinkValue;

  /// No description provided for @cloudUnlinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlink this device?'**
  String get cloudUnlinkTitle;

  /// No description provided for @cloudUnlinkBody.
  ///
  /// In en, this message translates to:
  /// **'Sync stops on this device. Nothing is deleted: your plants stay here and your data stays in your plantly.ro account. Sign in again any time to relink.'**
  String get cloudUnlinkBody;

  /// No description provided for @cloudUnlink.
  ///
  /// In en, this message translates to:
  /// **'Unlink'**
  String get cloudUnlink;

  /// No description provided for @cloudUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Device unlinked'**
  String get cloudUnlinked;

  /// No description provided for @cloudLoginGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get cloudLoginGoogle;

  /// No description provided for @cloudLoginFacebook.
  ///
  /// In en, this message translates to:
  /// **'Continue with Facebook'**
  String get cloudLoginFacebook;

  /// No description provided for @cloudLoginOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get cloudLoginOr;

  /// No description provided for @cloudLoginOauthWaiting.
  ///
  /// In en, this message translates to:
  /// **'Finish signing in in your browser — we\'ll pick it up here.'**
  String get cloudLoginOauthWaiting;

  /// No description provided for @cloudSyncOffHere.
  ///
  /// In en, this message translates to:
  /// **'Sync is off on this device — tap to turn it on'**
  String get cloudSyncOffHere;

  /// No description provided for @cloudHeldByOther.
  ///
  /// In en, this message translates to:
  /// **'This device holds plants synced by {username}.'**
  String cloudHeldByOther(String username);

  /// No description provided for @cloudMoveToMeLabel.
  ///
  /// In en, this message translates to:
  /// **'Move this device\'s plants to {username}\'s cloud'**
  String cloudMoveToMeLabel(String username);

  /// No description provided for @cloudMoveToMeValue.
  ///
  /// In en, this message translates to:
  /// **'They leave {username}\'s collection and sync to yours'**
  String cloudMoveToMeValue(String username);

  /// No description provided for @cloudMoveConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Move plants to your cloud?'**
  String get cloudMoveConfirmTitle;

  /// No description provided for @cloudMoveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Everything on this device leaves {from}\'s collection and is uploaded to {to}\'s. {from} keeps what was already synced from other devices.'**
  String cloudMoveConfirmBody(String from, String to);

  /// No description provided for @cloudMove.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get cloudMove;

  /// No description provided for @cloudStartEmptyLabel.
  ///
  /// In en, this message translates to:
  /// **'Start empty for {username}'**
  String cloudStartEmptyLabel(String username);

  /// No description provided for @cloudStartEmptyValue.
  ///
  /// In en, this message translates to:
  /// **'{username}\'s plants stay hidden on this device; sign {username} in again to see them'**
  String cloudStartEmptyValue(String username);
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
