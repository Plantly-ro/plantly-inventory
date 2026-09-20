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

  @override
  String get commonSave => 'Salvează';

  @override
  String get commonDelete => 'Șterge';

  @override
  String get commonRemove => 'Elimină';

  @override
  String get commonEdit => 'Modifică';

  @override
  String get commonConfirm => 'Confirmă';

  @override
  String get commonClear => 'Golește';

  @override
  String get commonOk => 'OK';

  @override
  String get commonTodayLabel => 'Astăzi';

  @override
  String get commonNextLabel => 'Următorul';

  @override
  String get plantDetailEdit => 'Modifică planta';

  @override
  String get plantDetailAddPhotos => 'Adaugă fotografii';

  @override
  String get plantDetailMoveToSpace => 'Mută în spațiul…';

  @override
  String get plantDetailDuplicate => 'Duplică planta';

  @override
  String get plantDetailPropagate => 'Propagă…';

  @override
  String get plantDetailMuteAll => 'Oprește toate notificările';

  @override
  String get plantDetailUnmuteAll => 'Reactivează notificările';

  @override
  String get plantDetailGift => 'Am dăruit…';

  @override
  String get plantDetailSold => 'Am vândut…';

  @override
  String get plantDetailMarkDead => 'Marcată decedată…';

  @override
  String get plantDetailDelete => 'Șterge planta…';

  @override
  String get plantDetailSectionStats => 'STATISTICI';

  @override
  String get plantDetailSectionUpcoming => 'ÎNGRIJIRI URMĂTOARE';

  @override
  String get plantDetailSectionTimeline => 'ISTORIC';

  @override
  String get plantDetailSectionLedger => 'REGISTRU';

  @override
  String get plantDetailNoReminders =>
      'Niciun memento încă — apasă mai jos pentru a adăuga unul.';

  @override
  String get plantDetailAddReminder => 'Adaugă memento';

  @override
  String get plantDetailNoEvents =>
      'Niciun eveniment încă — înregistrează prima udare mai jos.';

  @override
  String get plantDetailDeleteEvent => 'Șterge evenimentul';

  @override
  String get plantDetailEventRemoved => 'Eveniment eliminat';

  @override
  String get plantDetailQuickAction => 'Buton acțiune rapidă';

  @override
  String get plantDetailQuickActionHelp =>
      'Alege ce acțiune execută butonul cu o atingere.';

  @override
  String get plantDetailNotInCollection =>
      'Această plantă nu mai există în colecția ta.';

  @override
  String get plantDetailCaptionTitle => 'Adaugă descriere la fotografie';

  @override
  String get plantDetailCaptionHint => 'ex.: frunză îngălbenită';

  @override
  String get plantDetailRemovePhotoTitle => 'Elimini fotografia?';

  @override
  String get plantDetailRemovePhotoBody =>
      'Fișierul rămâne pe dispozitiv (poate fi folosit la alte plante) — se desparte doar de această plantă.';

  @override
  String get logEventTitle => 'Înregistrează eveniment';

  @override
  String get logEventWhat => 'CE';

  @override
  String get logEventWhen => 'CÂND';

  @override
  String get logEventOther => 'Altceva';

  @override
  String get logEventOtherHint => 'ex.: tratament păianjen roșu';

  @override
  String get logEventProduct => 'PRODUS (OPȚIONAL)';

  @override
  String get logEventProductHint => 'ex.: stropitoare ferigă';

  @override
  String get logEventNotes => 'NOTE (OPȚIONAL)';

  @override
  String get logEventNotesHint => 'ex.: frunză nouă deschizându-se';

  @override
  String get logEventEnterName => 'Introdu un nume pentru eveniment';

  @override
  String get editEventTitle => 'Modifică evenimentul';

  @override
  String get editEventDose => 'DOZĂ (OPȚIONAL)';

  @override
  String get editEventDoseHint => 'ex.: 100 ml';

  @override
  String get addReminderTitle => 'Adaugă memento';

  @override
  String get addReminderType => 'TIP';

  @override
  String get addReminderCustom => 'Personalizat';

  @override
  String get addReminderCustomHint => 'ex.: stropitor cu neem';

  @override
  String get addReminderPresets => 'PRESETĂRI';

  @override
  String get addReminderEvery => 'LA FIECARE';

  @override
  String get addReminderUnitMin => 'min';

  @override
  String get addReminderUnitHr => 'oră';

  @override
  String get addReminderUnitDay => 'zi';

  @override
  String get addReminderUnitMo => 'lună';

  @override
  String get addReminderRepeat => 'REPETĂ';

  @override
  String get addReminderRepeatOnDone => 'După ce marchez ca efectuat';

  @override
  String get addReminderRepeatFixed => 'Pe un program fix';

  @override
  String get addReminderRepeatOnce => 'O singură dată';

  @override
  String get addReminderFirstDue => 'PRIMA SCADENȚĂ';

  @override
  String get addReminderEnterPositive => 'Introdu un număr pozitiv';

  @override
  String get addReminderNameCustom => 'Denumește memento-ul personalizat';

  @override
  String get addReminderFiresOnce => 'SE DECLANȘEAZĂ O DATĂ';

  @override
  String addReminderNextReminders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count MEMENTO-URI',
      one: 'MEMENTO',
    );
    return 'URMĂTOARELE $_temp0';
  }

  @override
  String get addReminderPresetDaily => 'Zilnic';

  @override
  String get addReminderPresetEveryOtherDay => 'O zi da, o zi nu';

  @override
  String get addReminderPresetWeekly => 'Săptămânal';

  @override
  String get addReminderPresetMondays => 'Luni 09:00';

  @override
  String get addReminderPresetBiweekly => 'La două săptămâni';

  @override
  String get addReminderPresetMonthly => 'Lunar';

  @override
  String editReminderTitle(String type) {
    return 'Modifică memento-ul $type';
  }

  @override
  String get editReminderNextDue => 'URMĂTOAREA SCADENȚĂ';

  @override
  String get editReminderDeleteTitle => 'Ștergi memento-ul?';

  @override
  String get editReminderDeleteBody =>
      'Elimină acest program. Evenimentele anterioare rămân în istoric.';

  @override
  String get meSectionYou => 'TU';

  @override
  String get meSectionAppearance => 'ASPECT';

  @override
  String get meSectionLists => 'LISTE';

  @override
  String get meSectionNotifications => 'NOTIFICĂRI';

  @override
  String get notificationsWebUnavailable => 'Indisponibil în browser';

  @override
  String get notificationsWebUnavailableDetail =>
      'Versiunea din browser nu poate afișa notificări de sistem. Mementourile apar în continuare în aplicație și în calendar — folosește aplicația Android pentru alerte.';

  @override
  String get meSectionBackup => 'COPIE DE SIGURANȚĂ';

  @override
  String get meSectionCalendar => 'CALENDAR';

  @override
  String get meSectionAbout => 'DESPRE';

  @override
  String get meStatsValue =>
      'Activitate pe tipuri, plante de top, ultimele 30 de zile.';

  @override
  String get meStatsLabel => 'Statistici';

  @override
  String get mePrivacyLabel => 'Confidențialitate și date';

  @override
  String get mePrivacyValue =>
      'Rapoarte de eroare, uz anonim — ambele opționale.';

  @override
  String get meCareTypesLabel => 'Tipuri de îngrijire';

  @override
  String get meCareTypesValue =>
      'Redenumește, reordonează sau adaugă memento-uri personalizate.';

  @override
  String get meMutedLabel => 'Memento-uri oprite';

  @override
  String get meMutedValue =>
      'Vezi ce e tăcut; reactivează dintr-un singur loc.';

  @override
  String get meYourName => 'Numele tău';

  @override
  String get meYourNameEmpty => 'Adaugă unul pentru salut.';

  @override
  String get meYourNameHint => 'ex.: Ana';

  @override
  String get calendarToday => 'Astăzi';

  @override
  String get calendarNext => 'Următor';

  @override
  String get calendarWeek => 'Săptămână';

  @override
  String get calendarMonth => 'Lună';

  @override
  String get calendarYear => 'An';

  @override
  String get calendarUpcoming => 'URMĂTOARELE';

  @override
  String get calendarDayScheduled => 'PROGRAMAT';

  @override
  String get calendarDayDone => 'EFECTUAT';

  @override
  String get calendarDayEmpty =>
      'Nimic programat sau înregistrat în această zi.';

  @override
  String get searchTitle => 'Căutare';

  @override
  String get careTypesTitle => 'Tipuri de îngrijire';

  @override
  String get careTypesReset => 'Resetează la implicite';

  @override
  String get careTypesResetTitle => 'Resetezi la implicite?';

  @override
  String get careTypesResetBody =>
      'Restaurează cele 6 tipuri implicite + elimină cele personalizate. Programele și evenimentele existente își păstrează cheile.';

  @override
  String get statsTitle => 'Statistici';

  @override
  String get statsActivityHeader => 'ACTIVITATE ÎN 30 DE ZILE PE TIPURI';

  @override
  String get statsTopPlants => 'PLANTE DE TOP — 30 DE ZILE';

  @override
  String get activityTitle => 'Activitate';

  @override
  String get activityEmpty =>
      'Nicio activitate încă.\nÎnregistrează primul eveniment pe orice plantă.';

  @override
  String get quickLogTitle => 'Înregistrare rapidă';

  @override
  String get quickLogWater => 'Udare';

  @override
  String get quickLogFertilize => 'Fertilizare';

  @override
  String get quickLogMist => 'Pulverizare';

  @override
  String get quickLogRotate => 'Rotire';

  @override
  String get tipOfTheDay => 'SFATUL ZILEI';

  @override
  String get exportTitleField => 'TITLU';

  @override
  String get exportDescriptionField => 'DESCRIERE';

  @override
  String get exportPriceField => 'PREȚ';

  @override
  String get exportPriceUnit => 'lei';

  @override
  String get exportCategoryField => 'CATEGORIE';

  @override
  String get exportCategoryDefault => 'Plantă de interior';

  @override
  String get exportLocationField => 'LOCAȚIE';

  @override
  String exportPhotosField(int count) {
    return 'FOTOGRAFII ($count/6)';
  }

  @override
  String get exportNoPhotos =>
      'Nicio fotografie atașată. Adaugă mai întâi în ecranul plantei.';

  @override
  String get exportDraftSaved => 'Ciornă salvată';

  @override
  String get exportPostOnPlantlyRoCta => 'Publică pe plantly.ro';

  @override
  String get exportSavedLocally =>
      'Salvat local — sincronizarea cu plantly.ro vine în Faza 2';

  @override
  String get tagAdd => 'Adaugă o etichetă';

  @override
  String get tagHint => 'ex.: variegat';

  @override
  String get tagPickExisting => 'SAU ALEGE DIN EXISTENTE';

  @override
  String get tagAddTitle => 'Adaugă etichetă';

  @override
  String exportPostTitle(String name) {
    return 'Publică „$name”';
  }

  @override
  String get exportCategorySearchHint => 'Caută o categorie (ex. Monstera)';

  @override
  String get exportCategoryChangeHint => 'Caută pentru a schimba categoria';

  @override
  String get exportCategoryNoResults =>
      'Nicio categorie potrivită — încearcă alt cuvânt';

  @override
  String get exportCategorySearchFailed =>
      'Nu s-a putut contacta plantly.ro — verifică conexiunea';

  @override
  String get exportCategorySelected => 'Categorie selectată';

  @override
  String get exportCountyPlaceholder => 'Județ';

  @override
  String get exportCountyTitle => 'Județ';

  @override
  String get exportCityPlaceholder => 'Localitate';

  @override
  String get exportDeliveryNote =>
      'Deocamdată doar ridicare personală — poți activa livrarea prin curier pe plantly.ro după publicare.';

  @override
  String get exportSaveDraft => 'Salvează ciorna';

  @override
  String get exportPostNow => 'Publică acum';

  @override
  String get exportPosting => 'Se publică pe plantly.ro…';

  @override
  String get exportPosted => 'Publicat pe plantly.ro';

  @override
  String exportPostedWithWarnings(String warnings) {
    return 'Publicat pe plantly.ro — $warnings';
  }

  @override
  String get exportOpenListing => 'Deschide';

  @override
  String exportFailedServer(String message) {
    return 'Nu s-a putut publica: $message';
  }

  @override
  String get exportIssueTitleRequired => 'Titlul este obligatoriu';

  @override
  String get exportIssueTitleTooLong =>
      'Titlul este prea lung (max. 64 de caractere)';

  @override
  String get exportIssueDescriptionTooLong =>
      'Descrierea este prea lungă (max. 2000 de caractere)';

  @override
  String get exportIssuePriceInvalid => 'Introdu un preț mai mare decât 0';

  @override
  String get exportIssueCategoryRequired => 'Alege o categorie';

  @override
  String get exportIssuePhotosRequired => 'Selectează cel puțin o fotografie';

  @override
  String get exportIssuePhotosTooMany => 'Cel mult 6 fotografii';

  @override
  String get plantlyLoginTitle => 'Conectare la plantly.ro';

  @override
  String get plantlyLoginSubtitle =>
      'Folosește contul tău plantly.ro pentru a publica anunțuri.';

  @override
  String get plantlyLoginEmail => 'Email';

  @override
  String get plantlyLoginPassword => 'Parolă';

  @override
  String get plantlyLoginSubmit => 'Conectare';

  @override
  String get plantlyLoginCreateAccount => 'Creează cont';

  @override
  String get plantlyLoginForgot => 'Ai uitat parola?';

  @override
  String get plantlyLoginMissingFields => 'Introdu emailul și parola';

  @override
  String get plantlyLoginInvalid => 'Email sau parolă greșită';

  @override
  String get plantlyLoginNotVerified =>
      'Confirmă-ți mai întâi emailul — verifică inboxul';

  @override
  String get plantlyLoginSuspended => 'Acest cont este suspendat';

  @override
  String get plantlyLoginFailed => 'Conectarea a eșuat — încearcă din nou';

  @override
  String get plantlyErrorNetwork =>
      'Fără conexiune la plantly.ro — verifică internetul și încearcă din nou';

  @override
  String get plantlyErrorRateLimited =>
      'Prea multe încercări — așteaptă un minut și încearcă din nou';

  @override
  String get plantlyErrorSignInAgain =>
      'Sesiunea plantly.ro a expirat — conectează-te din nou';

  @override
  String get listedOnPlantly => 'Listată pe plantly.ro';

  @override
  String get listedStatusActive => 'ACTIV';

  @override
  String get listedStatusSold => 'VÂNDUT';

  @override
  String get listedOpen => 'Deschide';

  @override
  String get listedMarkSold => 'Marchează vândut';

  @override
  String get listedMarkSoldTitle => 'Marchezi ca vândut?';

  @override
  String get listedMarkSoldBody =>
      'Anunțul de pe plantly.ro va fi închis. Nu se poate anula din aplicație.';

  @override
  String get listedMarkedSold => 'Marcat ca vândut pe plantly.ro';

  @override
  String get listedCancel => 'Anulează';

  @override
  String get meSectionPlantlyAccount => 'CONT PLANTLY';

  @override
  String get mePlantlyAccountLabel => 'plantly.ro';

  @override
  String mePlantlySignedInAs(String username) {
    return 'Conectat ca $username';
  }

  @override
  String get mePlantlySignedOut => 'Conectare';

  @override
  String get mePlantlySignOutTitle => 'Te deconectezi?';

  @override
  String mePlantlySignOutBody(String username) {
    return 'Vei fi deconectat de la plantly.ro ($username) pe acest dispozitiv.';
  }

  @override
  String get mePlantlySignOut => 'Deconectare';

  @override
  String get importTitle => 'Adaugă la plantele tale';

  @override
  String get importSourceAssistant => 'DIN PLANTLY ASSISTANT';

  @override
  String get importSourceMarketplace => 'DE PE PLANTLY.RO';

  @override
  String get importNicknameLabel => 'NUME';

  @override
  String get importNoSchedulesHint =>
      'Mementourile de îngrijire nu se creează automat — le setezi din pagina plantei.';

  @override
  String get importRecentDuplicate =>
      'Ai adăugat-o pe aceasta chiar acum — o adaugi din nou?';

  @override
  String get importCancel => 'Anulează';

  @override
  String get importConfirm => 'Adaugă planta';

  @override
  String get importConfirmAgain => 'Adaugă din nou';

  @override
  String importHealthLine(String status) {
    return 'Sănătate: $status';
  }

  @override
  String get importHealthHealthy => 'sănătoasă';

  @override
  String get importHealthStressed => 'stresată';

  @override
  String get importHealthDiseased => 'bolnavă';

  @override
  String get importHealthUnknown => 'necunoscută';

  @override
  String get importObsYellowing => 'îngălbenire';

  @override
  String get importObsBrowning => 'brunificare';

  @override
  String get importObsSpots => 'pete';

  @override
  String get importObsWilting => 'ofilire';

  @override
  String get importObsPests => 'dăunători';

  @override
  String get importObsOther => 'altele';

  @override
  String importNotesIdentified(String date) {
    return 'Identificată cu Plantly Assistant pe $date.';
  }

  @override
  String get importNotesIdentifiedNoDate =>
      'Identificată cu Plantly Assistant.';

  @override
  String importNotesBought(String date) {
    return 'Cumpărată de pe plantly.ro pe $date.';
  }

  @override
  String get importNotesBoughtNoDate => 'Cumpărată de pe plantly.ro.';

  @override
  String importNotesHealth(String status) {
    return 'Sănătate: $status.';
  }

  @override
  String importNotesObservations(String items) {
    return 'Observații: $items.';
  }

  @override
  String get importErrorTitle => 'Nu am putut citi planta';

  @override
  String get importErrorMalformed =>
      'Linkul este deteriorat sau incomplet. Încearcă să exporți din nou din cealaltă aplicație.';

  @override
  String get importErrorTooLarge =>
      'Linkul este prea mare pentru a fi deschis. Încearcă să exporți din nou fără fotografie.';

  @override
  String get importErrorVersion =>
      'Acest link a fost creat de o versiune mai nouă a aplicației. Actualizează Plantly Inventory și încearcă din nou.';

  @override
  String get exportIssueCategoryInvalid =>
      'Alege o categorie din rezultatele căutării';

  @override
  String get importErrorSave => 'Nu s-a putut salva planta — încearcă din nou.';

  @override
  String get exportDraftCta => 'Pregătește ciorna anunțului';

  @override
  String get exportDraftEyebrow => 'CIORNĂ ANUNȚ';

  @override
  String exportDraftTitle(String name) {
    return 'Ciornă „$name”';
  }

  @override
  String get exportCategoryPlaceholder => 'Alege categoria';

  @override
  String get exportCategoryTitle => 'Categorie';

  @override
  String get importErrorDismiss => 'OK';
}
