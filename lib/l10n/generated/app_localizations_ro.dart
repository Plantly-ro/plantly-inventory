// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get homeTip1Title => 'Verifică umiditatea solului înainte de udare';

  @override
  String get homeTip1Body =>
      'Majoritatea plantelor de apartament preferă ca primii 2–3 cm de sol să se usuce între udări.';

  @override
  String get homeTip2Title => 'Rotește planta spre lumină';

  @override
  String get homeTip2Body =>
      'Un sfert de rotație pe săptămână menține creșterea uniformă și dreaptă.';

  @override
  String get homeTip3Title => 'Fertilizează ușor în sezonul de creștere';

  @override
  String get homeTip3Body =>
      'Diluează îngrășământul la jumătate ca să eviți arsurile rădăcinilor la speciile sensibile.';

  @override
  String get homeTip4Title =>
      'Fii atent la dăunători la schimbarea anotimpului';

  @override
  String get homeTip4Body =>
      'Tripșii și păianjenii roșii adoră aerul cald și uscat din casă — verifică dosul frunzelor.';

  @override
  String get homeTip5Title =>
      'Replantează când rădăcinile înconjoară ghiveciul';

  @override
  String get homeTip5Body =>
      'Treci doar cu o mărime de ghiveci mai sus — ghivecele prea mari rețin prea multă umezeală.';

  @override
  String get homeTip6Title => 'Șterge praful de pe frunze';

  @override
  String get homeTip6Body =>
      'Frunzele curate fac fotosinteză mai bine și te ajută să observi dăunătorii din timp.';

  @override
  String get homeTip7Title => 'Umiditatea ajută aroideele și calateele';

  @override
  String get homeTip7Body =>
      'Grupează plantele sau folosește o tavă cu pietriș și apă — mai simplu decât să pulverizezi toată ziua.';

  @override
  String get navHome => 'Acasă';

  @override
  String get navCalendar => 'Calendar';

  @override
  String get navSpaces => 'Spații';

  @override
  String get navMe => 'Eu';

  @override
  String homeDbOpenFailed(String error) {
    return 'Nu s-a putut deschide baza de date locală.\n$error';
  }

  @override
  String get homeSearchTooltip => 'Caută plante';

  @override
  String get homeEditHint =>
      'Ține apăsat pentru a personaliza ecranul principal';

  @override
  String get homeAddWidget => 'ADAUGĂ WIDGET';

  @override
  String get homePresets => 'PRESETĂRI';

  @override
  String get homeResetDefault => 'Resetează la implicit';

  @override
  String get homeAllWidgetsAdded =>
      'Toate widgeturile sunt deja pe ecranul principal. Aplică o presetare de mai jos ca să le rearanjezi.';

  @override
  String get homeAddBtn => '+ Adaugă';

  @override
  String get homeNoPlantsTitle => 'Nicio plantă încă';

  @override
  String get homeNoPlantsBody =>
      'Apasă butonul + ca să adaugi prima plantă. Poți seta memento-uri după ce o adaugi.';

  @override
  String get homeNotifOffBanner =>
      'Notificările sunt oprite — memento-urile nu vor porni. Apasă pentru a le activa.';

  @override
  String get homeWidgetGreeting => 'Salut';

  @override
  String get homeWidgetStats => 'Statistici';

  @override
  String get homeWidgetTip => 'Sfatul zilei';

  @override
  String get homeWidgetOverdue => 'Întârziate';

  @override
  String get homeWidgetToday => 'Astăzi';

  @override
  String get homeWidgetGrid => 'Toate plantele (grilă)';

  @override
  String get homeWidgetActivity => 'Activitate recentă';

  @override
  String get homeWidgetQuickLog => 'Înregistrare rapidă';

  @override
  String get homePresetGrouped => 'Grupat';

  @override
  String get homePresetDashboard => 'Panou';

  @override
  String get homePresetFeed => 'Flux';

  @override
  String get homePresetMinimal => 'Minimal';

  @override
  String get homeMoveUp => 'Mută în sus';

  @override
  String get homeMoveDown => 'Mută în jos';

  @override
  String get homeGreetingStillUp => 'Încă treaz?';

  @override
  String get homeGreetingMorning => 'Bună dimineața';

  @override
  String get homeGreetingAfternoon => 'Bună ziua';

  @override
  String get homeGreetingEvening => 'Bună seara';

  @override
  String get homeCareWater => 'Udă';

  @override
  String get homeCareFertilize => 'Fertilizează';

  @override
  String get homeCareMist => 'Pulverizează';

  @override
  String get homeCareRepot => 'Replantează';

  @override
  String get homeCarePrune => 'Tunde';

  @override
  String get homeCareRotate => 'Rotește';

  @override
  String get homeCareDoneWater => 'Udare';

  @override
  String get homeCareDoneFertilize => 'Fertilizare';

  @override
  String get homeCareDoneMist => 'Pulverizare';

  @override
  String get homeCareDoneRepot => 'Replantare';

  @override
  String get homeCareDonePrune => 'Tundere';

  @override
  String get homeCareDoneRotate => 'Rotire';

  @override
  String get homeCareDoneGeneric => 'Înregistrat';

  @override
  String homeOverdueLate(int days, String action) {
    return '$days z întârziere · $action';
  }

  @override
  String homeDueNow(String action) {
    return '$action acum';
  }

  @override
  String homeToastLoggedCare(String name) {
    return 'Îngrijire înregistrată pentru $name';
  }

  @override
  String homeToastActionLogged(String action, String name) {
    return '$action — înregistrat pentru $name';
  }

  @override
  String get homeViewAll => 'Vezi tot';

  @override
  String get homeActivityEmpty =>
      'Nimic înregistrat încă — apasă „Gata” pe un memento.';

  @override
  String get homeYesterday => 'Ieri';

  @override
  String homeDaysAgo(int days) {
    return 'acum $days z';
  }

  @override
  String get homeSearchAction => 'Caută';

  @override
  String get homeGridEmptyAll =>
      'Nicio plantă încă — apasă butonul + ca să adaugi una.';

  @override
  String get homeGridEmptyDueToday => 'Nimic programat azi — totul e la zi.';

  @override
  String homeLoadPlantsFailed(String error) {
    return 'Nu s-au putut încărca plantele.\n$error';
  }

  @override
  String get homeSortTooltip => 'Sortează plantele';

  @override
  String get homeSortNameAZ => 'Nume A–Z';

  @override
  String get homeSortNameZA => 'Nume Z–A';

  @override
  String get homeSortNextDue => 'Următoarea scadență';

  @override
  String get homeSortNewest => 'Adăugate recent';

  @override
  String get homeSortOldest => 'Adăugate demult';

  @override
  String get homeSortBySpace => 'După spațiu';

  @override
  String homeDueLateDays(int days) {
    return '$days z întârziere';
  }

  @override
  String homeDueLateHours(int hours) {
    return '$hours h întârziere';
  }

  @override
  String get homeDueNowShort => 'acum';

  @override
  String get homeDueUnderHour => '< 1h';

  @override
  String homeDueInHours(int hours) {
    return 'în $hours h';
  }

  @override
  String get homeDueTomorrow => 'mâine';

  @override
  String homeDueInDays(int days) {
    return 'în $days z';
  }

  @override
  String homeBulkSelected(int count) {
    return '$count selectate';
  }

  @override
  String get homeBulkMove => 'Mută';

  @override
  String get homeBulkMute => 'Oprește';

  @override
  String get homeBulkUnmute => 'Pornește';

  @override
  String homeBulkRemovedFromSpace(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de plante scoase din spațiu',
      few: '$count plante scoase din spațiu',
      one: '1 plantă scoasă din spațiu',
    );
    return '$_temp0';
  }

  @override
  String homeBulkMoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de plante mutate',
      few: '$count plante mutate',
      one: '1 plantă mutată',
    );
    return '$_temp0';
  }

  @override
  String homeBulkDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ștergi $count de plante?',
      few: 'Ștergi $count plante?',
      one: 'Ștergi 1 plantă?',
    );
    return '$_temp0';
  }

  @override
  String get homeBulkDeleteBody =>
      'Dacă vrei o intrare în registru, folosește Am dăruit / Am vândut / Marcată decedată din pagina plantei.';

  @override
  String homeBulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de plante șterse',
      few: '$count plante șterse',
      one: '1 plantă ștearsă',
    );
    return '$_temp0';
  }

  @override
  String get homeBulkUndo => 'Anulează';

  @override
  String homeQuickLogWhich(String action) {
    return '$action — care plantă?';
  }

  @override
  String get homeQuickLogRecordsNow =>
      'Înregistrează imediat un eveniment de îngrijire.';

  @override
  String get homeQuickLogEmpty =>
      'Nicio plantă încă — adaugă una din ecranul principal.';

  @override
  String get addPlantNicknameLabel => 'NUME';

  @override
  String get addPlantSpaceLabel => 'SPAȚIU';

  @override
  String get addPlantNotesLabel => 'NOTE';

  @override
  String get addPlantNoLocation => '— fără spațiu —';

  @override
  String get addPlantLoading => 'Se încarcă…';

  @override
  String get addPlantAddSpaceFirst =>
      'Adaugă mai întâi un spațiu din fila Spații.';

  @override
  String get addPlantSubmit => 'Adaugă planta';

  @override
  String get onbContinue => 'Continuă';

  @override
  String get onbStart => 'Începe să folosești Plantly';

  @override
  String get onbWelcomeTitle => 'Bun venit la Plantly';

  @override
  String get onbWelcomeBody =>
      'Un mod calm, offline, de a-ți urmări plantele de apartament — udare, fertilizare, înmulțire, spații și altele. Totul rămâne pe telefonul tău.';

  @override
  String get onbNameLabel => 'NUMELE TĂU (OPȚIONAL)';

  @override
  String get onbNameHelp =>
      'Îl folosim doar în salutul din partea de sus a ecranului principal. Îl poți schimba sau șterge mai târziu din Eu.';

  @override
  String get onbNotifTitle => 'Memento-uri pentru plante';

  @override
  String get onbNotifBody =>
      'Programăm notificări locale pe telefonul tău când o plantă are nevoie de îngrijire. Nimic nu se trimite către un server.';

  @override
  String get onbNotifGranted => 'Memento-urile sunt activate.';

  @override
  String get onbNotifAsk =>
      'Acordă permisiunea ca memento-urile să poată porni.';

  @override
  String get onbGrant => 'Permite';

  @override
  String get onbNotifSkip =>
      'Poți sări peste acest pas și activa memento-urile mai târziu din Eu → Notificări.';

  @override
  String get onbPrivacyTitle => 'Ajută-ne să îmbunătățim';

  @override
  String get onbPrivacyBody =>
      'Ambele sunt oprite implicit. Datele despre plante nu părăsesc niciodată dispozitivul tău. Le poți schimba oricând din Eu → Confidențialitate și date.';

  @override
  String get onbCrashTitle => 'Rapoarte de erori';

  @override
  String get onbCrashSub =>
      'Trimite un raport tehnic dacă aplicația se blochează. Fără date despre plante, fără poze.';

  @override
  String get onbUsageTitle => 'Utilizare anonimă';

  @override
  String get onbUsageSub =>
      'Număr de atingeri pe ecran — ne ajută să aflăm ce funcții sunt îndrăgite.';

  @override
  String get spaceKindHome => 'Acasă';

  @override
  String get spaceKindRoom => 'Cameră';

  @override
  String get spaceKindZone => 'Zonă';

  @override
  String get spaceKindShelf => 'Raft';

  @override
  String get spaceKindOutdoorBed => 'Strat exterior';

  @override
  String spaceLoadFailed(String error) {
    return 'Nu s-au putut încărca spațiile.\n$error';
  }

  @override
  String spacePlantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de plante',
      few: '$count plante',
      one: '1 plantă',
    );
    return '$_temp0';
  }

  @override
  String get spaceAddPlants => 'Adaugă plante';

  @override
  String get spaceManage => 'Gestionează';

  @override
  String get spaceNameRequired => 'Numele este obligatoriu';

  @override
  String spaceEditTitle(String name) {
    return 'Editează „$name”';
  }

  @override
  String get spaceNameLabel => 'NUME';

  @override
  String get spaceNameHint => 'ex.: Sufragerie';

  @override
  String get spaceKindUpper => 'TIP';

  @override
  String get spaceInsideLabel => 'SPAȚIU PĂRINTE (OPȚIONAL)';

  @override
  String get spaceTopLevelHint => 'Nivel principal';

  @override
  String get spaceOutdoor => 'Exterior';

  @override
  String get spaceOutdoorSub => 'Expus la vreme';

  @override
  String get spaceLightLabel => 'NIVEL DE LUMINĂ (OPȚIONAL)';

  @override
  String get spaceUnspecifiedHint => 'Nespecificat';

  @override
  String get spaceUnspecified => '— nespecificat —';

  @override
  String get spaceLightBrightDirect => 'directă puternică';

  @override
  String get spaceLightBrightIndirect => 'indirectă puternică';

  @override
  String get spaceLightMedium => 'medie';

  @override
  String get spaceLightLow => 'slabă';

  @override
  String get spaceHumidityLabel => 'INTERVAL UMIDITATE (% — opțional)';

  @override
  String get spaceMin => 'min';

  @override
  String get spaceMax => 'max';

  @override
  String get spaceTempLabel => 'INTERVAL TEMPERATURĂ (°C — opțional)';

  @override
  String get spaceNotesLabel => 'NOTE';

  @override
  String spaceAssignTitle(String name) {
    return 'Plante în „$name”';
  }

  @override
  String get spaceAssignSub =>
      'Comută pentru a adăuga sau scoate din acest spațiu.';

  @override
  String get spaceAssignEmpty => 'Nicio plantă de alocat încă.';

  @override
  String get spaceInThisSpace => 'În acest spațiu';

  @override
  String get spaceInAnotherSpace => 'În alt spațiu';

  @override
  String get spaceNoSpace => 'Fără spațiu';

  @override
  String get spacePickerTitle => 'Mută în spațiu';

  @override
  String get spacePickerEmpty =>
      'Niciun spațiu încă — adaugă unul din fila Spații.';

  @override
  String spaceLoadOneFailed(String error) {
    return 'Nu s-a putut încărca spațiul.\n$error';
  }

  @override
  String get spaceGone => 'Spațiul nu mai există.';

  @override
  String get spaceDeleteTitle => 'Ștergi spațiul?';

  @override
  String spaceDeleteBody(String name) {
    return 'Șterge „$name”. Plantele își păstrează poziția în celelalte spații.';
  }

  @override
  String get spaceMenuAssign => 'Alocă plante…';

  @override
  String get spaceMenuMute => 'Oprește notificările';

  @override
  String get spaceMenuUnmute => 'Pornește notificările';

  @override
  String get spaceMenuAddMap => 'Adaugă imagine hartă…';

  @override
  String get spaceMenuRemoveMap => 'Șterge imaginea hărții';

  @override
  String get spaceMenuDelete => 'Șterge spațiul…';

  @override
  String get spaceSectionMap => 'HARTĂ';

  @override
  String get spaceDonePlacing => 'Gata cu plasarea';

  @override
  String get spacePlacePins => 'Plasează pini';

  @override
  String get spaceSectionGallery => 'GALERIE';

  @override
  String spaceSectionPlants(int count) {
    return 'PLANTE ($count)';
  }

  @override
  String get spaceChipOutdoor => 'exterior';

  @override
  String spaceChipLight(String light) {
    return 'lumină: $light';
  }

  @override
  String spaceChipHumidity(String range) {
    return 'umiditate $range%';
  }

  @override
  String spaceChipTemp(String range) {
    return 'temp. $range°C';
  }

  @override
  String get spaceChipMuted => 'fără notificări';

  @override
  String get spaceAddLayoutTitle => 'Adaugă o imagine a spațiului';

  @override
  String get spaceAddLayoutBody =>
      'O poză a camerei sau o schiță — pune pinii plantelor deasupra.';

  @override
  String get spaceMapMissing => 'Imaginea hărții lipsește';

  @override
  String get spacePinHintPlace =>
      'Atinge pentru a plasa • trage pentru a muta • ține apăsat pentru a șterge';

  @override
  String get spacePinHintDrag =>
      'Trage pinii pentru a muta • ține apăsat pentru a șterge';

  @override
  String spacePlaced(String name) {
    return '$name plasată';
  }

  @override
  String get spaceNoPlantsHere => 'Nicio plantă aici încă.';

  @override
  String get spacePhotoEditDate => 'Editează data';

  @override
  String get spacePhotoEditCaption => 'Editează descrierea';

  @override
  String get spacePhotoRemove => 'Scoate din acest spațiu';

  @override
  String get spacePhotoActionsTitle => 'Fotografie';

  @override
  String get spaceCaptionTitle => 'Descriere';

  @override
  String get spaceCaptionHint => 'ex.: colțul cu lumină de dimineață';

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
      other: '$count DE MEMENTO-URI',
      few: '$count MEMENTO-URI',
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

  @override
  String get meTitle => 'Eu';

  @override
  String get meStatCardPlants => 'PLANTE';

  @override
  String get meStatCardSpaces => 'SPAȚII';

  @override
  String get meAboutApp => 'Aplicație';

  @override
  String get meAboutAppValue => 'PlantlyInventory · Faza 1';

  @override
  String get meAboutLicense => 'Licență';

  @override
  String get meThemeLabel => 'Temă';

  @override
  String get meThemeDark => 'Întunecată';

  @override
  String get meThemeLight => 'Luminoasă';

  @override
  String get meNotificationsLabel => 'Notificări';

  @override
  String get meNotifChecking => 'Se verifică…';

  @override
  String get meNotifEnabled => 'Activate';

  @override
  String get meNotifDisabledRetry => 'Dezactivate — apasă pentru a reîncerca';

  @override
  String get meNotifEnabledToast => 'Notificări activate';

  @override
  String get meNotifStillDenied =>
      'Încă refuzate — activează-le din setările sistemului';

  @override
  String get meExportZipLabel => 'Exportă ZIP (cu fotografii)';

  @override
  String get meExportJsonLabel => 'Exportă JSON (semnat)';

  @override
  String get meExportZipValue =>
      'Include toate fotografiile atașate. Fișier mai mare.';

  @override
  String get meExportJsonValue =>
      'JSON semnat HMAC cu toate plantele / programele / evenimentele.';

  @override
  String get meBackupPassphrase => 'Parola copiei de siguranță';

  @override
  String get meBackupPassphraseHint => 'Alege orice — îți trebuie la import';

  @override
  String meBackupSaved(String where) {
    return 'Copie de siguranță salvată: $where';
  }

  @override
  String meExportFailed(String error) {
    return 'Exportul a eșuat: $error';
  }

  @override
  String get meImportLabel => 'Importă o copie de siguranță';

  @override
  String get meImportValue =>
      'Alege un fișier .json sau .zip de pe acest dispozitiv.';

  @override
  String get meImportFileType => 'Copie de siguranță Plantly';

  @override
  String get meImportWrongPassphrase =>
      'Parolă greșită pentru această copie de siguranță.';

  @override
  String meImportInvalidBackup(String message) {
    return 'Copie de siguranță invalidă: $message';
  }

  @override
  String meImportInvalidZip(String message) {
    return 'ZIP invalid: $message';
  }

  @override
  String meImportFailed(String error) {
    return 'Importul a eșuat: $error';
  }

  @override
  String meImportedRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Importate $count de rânduri',
      few: 'Importate $count rânduri',
      one: 'Importat 1 rând',
    );
    return '$_temp0';
  }

  @override
  String meImportedPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de fotografii',
      few: '$count fotografii',
      one: '1 fotografie',
    );
    return '$_temp0';
  }

  @override
  String get meIcsLabel => 'Descarcă .ics';

  @override
  String get meIcsValue =>
      'Deschide mementourile din următoarele 30 de zile în orice aplicație de calendar.';

  @override
  String get meIcsShareText => 'Mementouri PlantlyInventory';

  @override
  String meIcsSaved(String where) {
    return '.ics salvat: $where';
  }

  @override
  String get meCsvLabel => 'Exportă CSV';

  @override
  String get meCsvValue =>
      'Plante + evenimente de îngrijire, într-un fișier pentru foi de calcul.';

  @override
  String get meCsvShareText => 'CSV PlantlyInventory';

  @override
  String meCsvSaved(String where) {
    return 'CSV salvat: $where';
  }

  @override
  String meCsvFailed(String error) {
    return 'Exportul CSV a eșuat: $error';
  }

  @override
  String get mePrivacyTitle => 'Confidențialitate și date';

  @override
  String get mePrivacyWhatLeaves => 'Ce părăsește dispozitivul tău';

  @override
  String get mePrivacyBulletLocal =>
      'Nimic, implicit. Plantele, fotografiile, evenimentele de îngrijire și programele stau într-o bază de date SQLite locală, pe telefonul tău.';

  @override
  String get mePrivacyBulletBackups =>
      'Copiile de siguranță (JSON sau ZIP) părăsesc dispozitivul doar când apeși Exportă — tu alegi unde ajung, prin meniul de partajare.';

  @override
  String get mePrivacyBulletNotifications =>
      'Notificările se declanșează local, prin sistemul de alarme al telefonului. Nu folosim un server de push.';

  @override
  String get mePrivacyBulletMarketplace =>
      'Dacă publici ulterior o plantă pe plantly.ro, se trimit doar câmpurile pe care le verifici în dialogul de publicare — niciodată întreaga bază de date.';

  @override
  String get mePrivacySectionTelemetry => 'TELEMETRIE OPȚIONALĂ';

  @override
  String get mePrivacyCrashTitle => 'Rapoarte de eroare';

  @override
  String get mePrivacyCrashBody =>
      'Dacă aplicația se blochează, trimite detaliile erorii ca să o putem repara. Fără date despre plante, fără fotografii.';

  @override
  String get mePrivacyUsageTitle => 'Utilizare anonimă';

  @override
  String get mePrivacyUsageBody =>
      'Număr de atingeri pe ecran — ca să știm ce funcții sunt îndrăgite. Fără identificatori, fără textul pe care îl introduci.';

  @override
  String get mePrivacySectionLegal => 'LEGAL';

  @override
  String get mePrivacyLicenseValue =>
      'AGPL-3.0-or-later · sursă: github.com/URunDEAD/PlantlyInventory';

  @override
  String get meCareTypeNew => 'Tip de îngrijire nou';

  @override
  String meCareTypeEdit(String label) {
    return 'Modifică „$label”';
  }

  @override
  String get meCareTypeLabelField => 'DENUMIRE';

  @override
  String get meCareTypeLabelHint => 'ex.: stropitor cu neem';

  @override
  String get meCareTypeIntervalField => 'INTERVAL IMPLICIT (ZILE)';

  @override
  String get meCareTypeIconField => 'PICTOGRAMĂ';

  @override
  String get meCareTypeColourField => 'CULOARE';

  @override
  String get meCareTypeColourDefault => 'Implicită';

  @override
  String meCareTypeDefaultEvery(String days, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'de zile',
      few: 'zile',
      one: 'zi',
    );
    return 'Implicit: la fiecare $days $_temp0';
  }

  @override
  String get meCareTypeMuteTooltip =>
      'Oprește acest tip de îngrijire peste tot';

  @override
  String get meCareTypeUnmuteTooltip =>
      'Reactivează acest tip de îngrijire peste tot';

  @override
  String meMutedPlantsHeader(int count) {
    return 'PLANTE OPRITE ($count)';
  }

  @override
  String meMutedRemindersHeader(int count) {
    return 'MEMENTO-URI OPRITE ($count)';
  }

  @override
  String meMutedSpacesHeader(int count) {
    return 'SPAȚII OPRITE ($count)';
  }

  @override
  String get meMutedPlantBody =>
      'Toate mementourile acestei plante sunt oprite.';

  @override
  String get meMutedReminderBody =>
      'Un singur program oprit — celelalte mementouri ale plantei rămân active.';

  @override
  String get meMutedSpaceBody => 'Toate plantele din acest spațiu sunt oprite.';

  @override
  String get meNothingMuted => 'Nimic oprit';

  @override
  String get meNothingMutedBody =>
      'Oprește mementourile per plantă, program sau spațiu din ecranul de detalii respectiv.';

  @override
  String get meUnmute => 'Reactivează';

  @override
  String get meDndTitle => 'Nu deranja';

  @override
  String meDndActive(String start, String end) {
    return 'Liniște între $start și $end (mementourile sunt amânate)';
  }

  @override
  String get meDndInactive => 'Trimite mementourile când sunt scadente';

  @override
  String get meDndStart => 'Început';

  @override
  String get meDndEnd => 'Sfârșit';

  @override
  String get meNotifPermChecking => 'Se verifică permisiunea sistemului…';

  @override
  String get meNotifPermGranted =>
      'Notificările de sistem sunt permise pentru PlantlyInventory.';

  @override
  String get meNotifPermDenied =>
      'Notificările de sistem sunt OPRITE. Mementourile nu vor fi trimise.';

  @override
  String get statsCellPlants => 'PLANTE';

  @override
  String get statsCellEvents => 'EVENIMENTE';

  @override
  String get statsCellLast30 => 'ULTIMELE 30 Z';

  @override
  String get statsEmpty =>
      'Niciun eveniment de îngrijire încă. Înregistrează primul memento pentru a vedea statistici aici.';

  @override
  String statsCardLast(String type) {
    return 'ULTIMA $type';
  }

  @override
  String statsCardAvg(String type) {
    return 'MEDIE $type';
  }

  @override
  String get statsCardToday => 'azi';

  @override
  String statsCardDaysShort(int count) {
    return '$count z';
  }

  @override
  String statsCardAvgDaysShort(String value) {
    return '~$value z';
  }

  @override
  String get activityToday => 'ASTĂZI';

  @override
  String get activityYesterday => 'IERI';

  @override
  String detailLoadFailed(String error) {
    return 'Nu s-a putut încărca planta.\n$error';
  }

  @override
  String get detailNoLocation => 'Fără spațiu setat';

  @override
  String get detailLoadingLocation => 'Se încarcă spațiul…';

  @override
  String detailFabNow(String action) {
    return '$action acum';
  }

  @override
  String get detailFabTooltip => 'Ține apăsat pentru a schimba';

  @override
  String get detailDeleteTitle => 'Ștergi planta?';

  @override
  String detailDeleteBody(String name) {
    return 'Elimină „$name” din colecția ta. Folosește Am dăruit / Am vândut / Marcată decedată dacă vrei o intrare în registru.';
  }

  @override
  String detailDeletedToast(String name) {
    return '„$name” a fost ștearsă';
  }

  @override
  String get detailUndo => 'Anulează';

  @override
  String detailAddedOn(String date) {
    return 'Adăugată $date';
  }

  @override
  String detailAcquiredOn(String date) {
    return 'Achiziționată $date';
  }

  @override
  String get detailRemovedFromSpace => 'Scoasă din orice spațiu';

  @override
  String detailMovedTo(String space) {
    return 'Mutată în $space';
  }

  @override
  String get detailThatSpace => 'acel spațiu';

  @override
  String get detailReorderTooltip => 'Reordonează';

  @override
  String get detailEditDateTooltip => 'Modifică data';

  @override
  String get detailCaptionTooltip => 'Descriere';

  @override
  String get detailMuteReminderTooltip => 'Oprește acest memento';

  @override
  String get detailUnmuteReminderTooltip => 'Reactivează acest memento';

  @override
  String get detailSnoozedToast => 'Amânat 3 zile';

  @override
  String get detailNoDueDate => 'Fără scadență';

  @override
  String get detailOverdue => 'restant';

  @override
  String detailOverdueDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'restant de $count de zile',
      few: 'restant de $count zile',
      one: 'restant de o zi',
    );
    return '$_temp0';
  }

  @override
  String get detailDueToday => 'astăzi';

  @override
  String get detailDueTomorrow => 'mâine';

  @override
  String detailDueInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'în $count de zile',
      few: 'în $count zile',
      one: 'într-o zi',
    );
    return '$_temp0';
  }

  @override
  String get detailVerbRepot => 'Transplantare';

  @override
  String get detailVerbPrune => 'Tundere';

  @override
  String get detailPastWater => 'Udată';

  @override
  String get detailPastFertilize => 'Fertilizată';

  @override
  String get detailPastMist => 'Pulverizată';

  @override
  String get detailPastRepot => 'Replantată';

  @override
  String get detailPastPrune => 'Tunsă';

  @override
  String get detailPastRotate => 'Rotită';

  @override
  String get detailDeleteEventTitle => 'Ștergi acest eveniment?';

  @override
  String detailDeleteEventBody(String text) {
    return 'Elimină înregistrarea „$text” din istoric.';
  }

  @override
  String get detailLedgerPropagatedOut => 'Propagată din această plantă';

  @override
  String get detailLedgerPropagatedIn => 'Propagată dintr-o plantă-mamă';

  @override
  String detailLedgerGaveTo(String who) {
    return 'Dăruită către $who';
  }

  @override
  String get detailLedgerSomeone => 'cineva';

  @override
  String get detailLedgerSold => 'Vândută';

  @override
  String detailLedgerSoldTo(String buyer) {
    return 'Vândută către $buyer';
  }

  @override
  String get detailLedgerMarkedDead => 'Marcată decedată';

  @override
  String get detailReorderPhotosTitle => 'Reordonează fotografiile';

  @override
  String detailPhotoN(int n) {
    return 'Fotografia $n';
  }

  @override
  String get sheetNicknameRequired => 'Numele este obligatoriu';

  @override
  String get sheetFieldSpace => 'SPAȚIU';

  @override
  String get sheetFieldSpecies => 'SPECIE';

  @override
  String get sheetSpeciesHint => 'ex.: Monstera deliciosa';

  @override
  String get sheetFieldNotes => 'NOTE';

  @override
  String get sheetNoLocation => '— fără spațiu —';

  @override
  String get sheetLoading => 'Se încarcă…';

  @override
  String get sheetGaveAwayTitle => 'Am dăruit';

  @override
  String get sheetGaveAwayHint => 'Cui ai dăruit-o? (opțional)';

  @override
  String get sheetSoldTitle => 'Am vândut';

  @override
  String get sheetSoldHint => 'Cumpărător (opțional)';

  @override
  String get sheetMarkedDeadTitle => 'Marcată decedată';

  @override
  String sheetInventoryRemoveBody(String name) {
    return '„$name” va fi eliminată din colecția ta activă.';
  }

  @override
  String get sheetPriceHint => 'Preț (opțional)';

  @override
  String get sheetNotesOptionalHint => 'Note (opțional)';

  @override
  String sheetPropagateTitle(String name) {
    return 'Propagă $name';
  }

  @override
  String get sheetChildNickname => 'Numele noii plante';

  @override
  String get sheetPropagateNotesHint =>
      'ex.: tăiat de la nodul 3; înrădăcinare în apă';

  @override
  String sheetPropagateDefaultName(String name) {
    return '$name · propagare';
  }

  @override
  String get sheetPropagateAction => 'Propagă';

  @override
  String get careTypeWater => 'Udare';

  @override
  String get careTypeFertilize => 'Fertilizare';

  @override
  String get careTypeMist => 'Pulverizare';

  @override
  String get careTypeRepot => 'Replantare';

  @override
  String get careTypePrune => 'Tundere';

  @override
  String get careTypeRotate => 'Rotire';

  @override
  String get seedPlantBob => 'Monstera \"Bob\"';

  @override
  String get seedPlantGreen => 'Pothos \"Green\"';

  @override
  String get seedPlantSnake => 'Limba soacrei';

  @override
  String get seedPlantCala => 'Calathea';

  @override
  String get seedPlantFid => 'Ficus lira';

  @override
  String get seedPlantFern => 'Ferigă';

  @override
  String get seedPlantSuc => 'Urechelniță';

  @override
  String get seedPlantPete => 'Cactus Pete';

  @override
  String get seedSpaceHome => 'Acasă';

  @override
  String get seedSpaceLivingRoom => 'Sufragerie';

  @override
  String get seedSpaceBalcony => 'Balcon';

  @override
  String get notifChannelName => 'Memento-uri de îngrijire a plantelor';

  @override
  String get notifChannelDescription =>
      'Udare, fertilizare și alte memento-uri de îngrijire a plantelor.';

  @override
  String get calPrevious => 'Anterior';

  @override
  String get calDayFree => 'Liber';

  @override
  String calOverdueMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'restant de $count de minute',
      few: 'restant de $count minute',
      one: 'restant de un minut',
    );
    return '$_temp0';
  }

  @override
  String calOverdueHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'restant de $count de ore',
      few: 'restant de $count ore',
      one: 'restant de o oră',
    );
    return '$_temp0';
  }

  @override
  String calInMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'în $count de minute',
      few: 'în $count minute',
      one: 'într-un minut',
    );
    return '$_temp0';
  }

  @override
  String calInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'în $count de ore',
      few: 'în $count ore',
      one: 'într-o oră',
    );
    return '$_temp0';
  }

  @override
  String get photoSrcTakePhoto => 'Fă o poză';

  @override
  String get photoSrcTakePhotoSub => 'Deschide camera';

  @override
  String get photoSrcGalleryMulti => 'Alege din galerie';

  @override
  String get photoSrcGalleryMultiSub => 'Selectează mai multe imagini';

  @override
  String get photoSrcGalleryOne => 'Alege una din galerie';

  @override
  String get photoSrcGalleryOneSub => 'Alege o singură imagine';

  @override
  String get spacePickerChooseTitle => 'Alege spațiul';

  @override
  String get cloudSectionTitle => 'Cloud';

  @override
  String get cloudScreenTitle => 'Cloud';

  @override
  String get cloudScreenIntro =>
      'Plantele, pozele și istoricul de îngrijire sunt salvate în contul tău plantly.ro și ținute sincronizate pe orice dispozitiv pe care te conectezi. Nimic nu părăsește acest dispozitiv până nu îl conectezi.';

  @override
  String get cloudSignInLabel => 'Conectează-te la plantly.ro';

  @override
  String get cloudSignInPitch =>
      'Fă backup plantelor tale și sincronizează-le între dispozitive';

  @override
  String get cloudNotIncludedLabel => 'Backup și sincronizare în cloud';

  @override
  String get cloudNotIncludedValue =>
      'Inclus în Plantly Pro sau Plantly Inventory Cloud';

  @override
  String get cloudChecking => 'Se verifică abonamentul…';

  @override
  String get cloudSubscribeLabel => 'Abonează-te pe plantly.ro';

  @override
  String get cloudSubscribeValue => 'Deschide contul tău plantly.ro în browser';

  @override
  String get cloudRefreshStatusLabel => 'Reîmprospătează starea';

  @override
  String get cloudRefreshStatusValue => 'Verifică din nou abonamentul';

  @override
  String get cloudStatusLabel => 'Sincronizare cloud';

  @override
  String get cloudSettingUp => 'Se pregătește colecția ta în cloud…';

  @override
  String get cloudSetupFailed =>
      'Nu s-a putut activa sincronizarea. Apasă pentru a reîncerca.';

  @override
  String get cloudSyncing => 'Se sincronizează…';

  @override
  String get cloudLastSyncNever => 'Încă nesincronizat';

  @override
  String get cloudLastSyncJustNow => 'Sincronizat chiar acum';

  @override
  String cloudLastSyncMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizat acum $count de minute',
      few: 'Sincronizat acum $count minute',
      one: 'Sincronizat acum un minut',
    );
    return '$_temp0';
  }

  @override
  String cloudLastSyncHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizat acum $count de ore',
      few: 'Sincronizat acum $count ore',
      one: 'Sincronizat acum o oră',
    );
    return '$_temp0';
  }

  @override
  String cloudLastSyncDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sincronizat acum $count de zile',
      few: 'Sincronizat acum $count zile',
      one: 'Sincronizat acum o zi',
    );
    return '$_temp0';
  }

  @override
  String cloudPendingOps(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de modificări în așteptare',
      few: '$count modificări în așteptare',
      one: 'o modificare în așteptare',
      zero: 'toate modificările încărcate',
    );
    return '$_temp0';
  }

  @override
  String cloudStorageUsed(String used, String quota) {
    return '$used din $quota folosiți';
  }

  @override
  String get cloudSyncNowLabel => 'Sincronizează acum';

  @override
  String get cloudSyncNowValue =>
      'Încarcă modificările în așteptare și preia noutățile';

  @override
  String get cloudPlanLabel => 'Plan';

  @override
  String get cloudEntitlementSourcePro => 'Inclus în Plantly Pro';

  @override
  String get cloudEntitlementSourceCloud => 'Plantly Inventory Cloud';

  @override
  String cloudRenewsOn(String date) {
    return 'se reînnoiește $date';
  }

  @override
  String get cloudPlayPlansTitle => 'Abonează-te prin Google Play';

  @override
  String get cloudPlayPlanMonthly => 'Lunar';

  @override
  String get cloudPlayPlanYearly => 'Anual';

  @override
  String cloudPlayPerMonth(String price) {
    return '$price / lună';
  }

  @override
  String cloudPlayPerYear(String price) {
    return '$price / an';
  }

  @override
  String get cloudPlayLoadingPlans => 'Se încarcă prețurile din Google Play…';

  @override
  String get cloudPlayUnavailable =>
      'Plățile prin Google Play nu sunt disponibile acum pe acest dispozitiv.';

  @override
  String get cloudPlayRetry => 'Reîncearcă';

  @override
  String get cloudPlayActivating => 'Se activează…';

  @override
  String get cloudPlayManageLabel => 'Gestionezi abonamentul în Google Play';

  @override
  String get cloudPlayManageValue =>
      'Anulezi, pui pauză sau schimbi planul în Google Play';

  @override
  String get cloudEntitlementViaPlay => 'prin Google Play';

  @override
  String get cloudPlayAlreadyEntitledTitle => 'Ai deja Inventory Cloud';

  @override
  String get cloudPlayAlreadyEntitledBody =>
      'Ai deja Inventory Cloud (inclus în Plantly Pro / abonament web). Achiziția din Google Play nu a fost activată și va fi rambursată automat de Google în 3 zile.';

  @override
  String get cloudPlayPending =>
      'Plata este în așteptare. Inventory Cloud se activează după ce Google Play o confirmă.';

  @override
  String get cloudPlayVerified => 'Inventory Cloud este activ.';

  @override
  String get cloudPlayVerifyFailed =>
      'Nu s-a putut confirma achiziția cu plantly.ro.';

  @override
  String get cloudPlayPurchaseFailed =>
      'Google Play nu a putut finaliza achiziția.';

  @override
  String get cloudPlayTokenOwnedByOther =>
      'Acest abonament Google Play aparține altui cont plantly.ro.';

  @override
  String get cloudCollectionLabel => 'Colecție';

  @override
  String get cloudLastErrorLabel => 'Ultima eroare';

  @override
  String get cloudAccountLabel => 'Cont';

  @override
  String cloudAccountValue(String username) {
    return 'Conectat ca $username · apasă pentru deconectare';
  }

  @override
  String get cloudSignOutTitle => 'Te deconectezi de la plantly.ro?';

  @override
  String cloudSignOutBody(String username) {
    return 'Sincronizarea se oprește până când $username se conectează din nou. Plantele rămân pe acest dispozitiv.';
  }

  @override
  String get cloudSignOut => 'Deconectare';

  @override
  String get cloudUnlinkLabel => 'Deconectează acest dispozitiv';

  @override
  String get cloudUnlinkValue =>
      'Oprește sincronizarea aici; datele locale și din cloud rămân';

  @override
  String get cloudUnlinkTitle => 'Deconectezi acest dispozitiv?';

  @override
  String get cloudUnlinkBody =>
      'Sincronizarea se oprește pe acest dispozitiv. Nimic nu se șterge: plantele rămân aici, iar datele rămân în contul tău plantly.ro. Te poți conecta din nou oricând.';

  @override
  String get cloudUnlink => 'Deconectează';

  @override
  String get cloudUnlinked => 'Dispozitiv deconectat';

  @override
  String get cloudLoginGoogle => 'Continuă cu Google';

  @override
  String get cloudLoginFacebook => 'Continuă cu Facebook';

  @override
  String get cloudLoginOr => 'sau';

  @override
  String get cloudLoginOauthWaiting =>
      'Finalizează conectarea în browser — continuăm automat aici.';

  @override
  String get cloudSyncOffHere =>
      'Sincronizarea este oprită pe acest dispozitiv — apasă pentru a o porni';

  @override
  String cloudHeldByOther(String username) {
    return 'Pe acest dispozitiv sunt plante sincronizate de $username.';
  }

  @override
  String cloudMoveToMeLabel(String username) {
    return 'Mută plantele de pe acest dispozitiv în cloud-ul lui $username';
  }

  @override
  String cloudMoveToMeValue(String username) {
    return 'Părăsesc colecția lui $username și se sincronizează în a ta';
  }

  @override
  String get cloudMoveConfirmTitle => 'Muți plantele în cloud-ul tău?';

  @override
  String cloudMoveConfirmBody(String from, String to) {
    return 'Tot ce e pe acest dispozitiv părăsește colecția lui $from și se încarcă în cea a lui $to. $from păstrează ce era deja sincronizat de pe alte dispozitive.';
  }

  @override
  String get cloudMove => 'Mută';

  @override
  String cloudStartEmptyLabel(String username) {
    return 'Începe de la zero pentru $username';
  }

  @override
  String cloudStartEmptyValue(String username) {
    return 'Plantele lui $username rămân ascunse pe acest dispozitiv; conectează-l din nou pe $username ca să le vezi';
  }

  @override
  String get cloudErrCollectionUnavailable =>
      'Această colecție nu mai este disponibilă — deconectează dispozitivul și conectează-l din nou';

  @override
  String get cloudErrQuotaExceeded =>
      'Spațiul cloud este plin — pozele noi rămân pe acest dispozitiv până se eliberează spațiu';

  @override
  String get cloudErrOpTooLarge =>
      'O modificare este prea mare pentru încărcare și a fost omisă';

  @override
  String cloudErrOpTooLargeDetail(String detail) {
    return 'O modificare este prea mare pentru încărcare și a fost omisă ($detail)';
  }

  @override
  String get cloudErrRetrying => 'Serverul este ocupat — reîncercăm în curând';

  @override
  String get cloudErrOffline => 'Offline — sincronizăm când revine conexiunea';

  @override
  String get cloudErrGeneric => 'Sincronizarea a eșuat — reîncercăm';

  @override
  String get shellSelectPlant =>
      'Alege o plantă ca să-i vezi istoricul de îngrijire';

  @override
  String get shellSelectSpace => 'Alege un spațiu ca să vezi ce crește acolo';

  @override
  String get shellSelectSection => 'Alege o secțiune din stânga';

  @override
  String get historyColDate => 'Data';

  @override
  String get historyColCare => 'Îngrijire';

  @override
  String get historyColDetails => 'Detalii';

  @override
  String get homeCustomise => 'Personalizează';

  @override
  String get homeSearchHint => 'Caută plante…';

  @override
  String get detailPrevPlant => 'Planta anterioară';

  @override
  String get detailNextPlant => 'Planta următoare';

  @override
  String get detailMoreCareActions => 'Alte acțiuni de îngrijire';

  @override
  String get detailColCare => 'Îngrijire';

  @override
  String get detailColEvery => 'La fiecare';

  @override
  String get detailColNextDue => 'Următoarea';

  @override
  String get detailFactSpace => 'Spațiu';

  @override
  String get detailFactAcquired => 'Achiziționată';

  @override
  String get detailFactPotSize => 'Ghiveci';

  @override
  String get detailFactTags => 'Etichete';

  @override
  String get detailFactNotes => 'Note';

  @override
  String detailEveryNDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n de zile',
      few: '$n zile',
      one: '1 zi',
    );
    return '$_temp0';
  }

  @override
  String spaceCardPlantCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n de plante',
      few: '$n plante',
      one: '1 plantă',
      zero: 'Nicio plantă',
    );
    return '$_temp0';
  }

  @override
  String get homeNoPlantsBodyDesktop =>
      'Adaugă una cu butonul din bara laterală. Poți seta mementouri după ce apare.';

  @override
  String get shareSwitcherTitle => 'Colecții';

  @override
  String get shareSwitcherTooltip => 'Schimbă colecția';

  @override
  String get shareMineSection => 'Colecțiile mele';

  @override
  String get shareSharedWithMe => 'Partajate cu mine';

  @override
  String get shareRoleOwner => 'Proprietar';

  @override
  String get shareRoleEditor => 'Editor';

  @override
  String get shareJoinWithCode => 'Alătură-te cu un cod…';

  @override
  String get shareJoinTitle => 'Alătură-te unei colecții partajate';

  @override
  String get shareJoinBody =>
      'Introdu codul de 8 caractere din invitația primită.';

  @override
  String get shareJoinCodeLabel => 'Cod de invitație';

  @override
  String get shareJoinCodeInvalid =>
      'Codurile au 8 litere sau cifre (fără I, O, 0 sau 1).';

  @override
  String get shareJoinButton => 'Alătură-te';

  @override
  String get shareJoinSignInFirst =>
      'Mai întâi ți se va cere să te autentifici pe plantly.ro.';

  @override
  String get shareJoinPaywallNote =>
      'Poți folosi această colecție partajată — funcționează pe planul proprietarului. Plantele tale rămân locale până te abonezi.';

  @override
  String shareJoined(String name) {
    return 'Te-ai alăturat colecției $name';
  }

  @override
  String get shareJoinErrInvalid =>
      'Acest cod de invitație nu este valid — poate a expirat sau a fost deja folosit.';

  @override
  String get shareJoinErrAlreadyMember =>
      'Ești deja membru al acestei colecții.';

  @override
  String get shareSectionTitle => 'Partajare';

  @override
  String get shareSectionIntro =>
      'Invită familia sau pe cel care îți îngrijește plantele să noteze îngrijirea împreună cu tine.';

  @override
  String get shareActiveLabel => 'Colecția activă';

  @override
  String shareActiveValue(String name, String role) {
    return '$name · $role';
  }

  @override
  String shareMembersCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n de membri',
      few: '$n membri',
      one: '1 membru',
    );
    return '$_temp0';
  }

  @override
  String get shareInviteLabel => 'Invită pe cineva';

  @override
  String get shareInviteValue =>
      'Creează un cod pe care îl introduce în aplicația sa';

  @override
  String shareInviteTitle(String name) {
    return 'Invitație la $name';
  }

  @override
  String get shareInviteCodeHint =>
      'Trimite acest cod sau linkul. Funcționează o singură dată și expiră în 7 zile.';

  @override
  String get shareInviteCopy => 'Copiază';

  @override
  String get shareInviteCopied => 'Copiat';

  @override
  String get shareInviteShare => 'Trimite';

  @override
  String shareInviteMessage(String name, String url, String code) {
    return 'Alătură-te colecției mele de plante „$name” în Plantly Inventory: $url (cod $code)';
  }

  @override
  String get shareInviteCreating => 'Se creează invitația…';

  @override
  String get shareMembersLabel => 'Membri';

  @override
  String get shareMembersValue => 'Vezi cine are acces';

  @override
  String shareMembersTitle(String name) {
    return 'Membrii colecției $name';
  }

  @override
  String shareMemberJoined(String date) {
    return 'Membru din $date';
  }

  @override
  String get shareMemberYou => 'tu';

  @override
  String get shareRemoveMember => 'Elimină';

  @override
  String shareRemoveMemberTitle(String username) {
    return 'Elimini pe $username?';
  }

  @override
  String get shareRemoveMemberBody =>
      'Pierde accesul la această colecție. Ce a notat rămâne.';

  @override
  String shareRemoved(String username) {
    return '$username a fost eliminat';
  }

  @override
  String get shareLeaveLabel => 'Părăsește colecția';

  @override
  String shareLeaveValue(String name) {
    return 'Nu mai vezi $name pe acest dispozitiv';
  }

  @override
  String shareLeaveTitle(String name) {
    return 'Părăsești $name?';
  }

  @override
  String get shareLeaveBody => 'Poți reveni mai târziu cu o invitație nouă.';

  @override
  String get shareLeave => 'Părăsește';

  @override
  String shareLeft(String name) {
    return 'Ai părăsit $name';
  }

  @override
  String shareRemovedFromCollection(String name) {
    return 'Ai fost eliminat din $name';
  }

  @override
  String shareByActor(String name) {
    return 'de $name';
  }

  @override
  String get shareByOtherMember => 'de alt membru';

  @override
  String shareSwitched(String name) {
    return 'Ai trecut la $name';
  }

  @override
  String get shareSwitchUnavailable =>
      'Schimbarea colecției cere sincronizarea cloud activă pentru acest cont.';

  @override
  String shareMeRowValue(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n de colecții',
      few: '$n colecții',
      one: '1 colecție',
    );
    return '$_temp0';
  }

  @override
  String get shareNoMembers => 'Încă niciun membru';

  @override
  String get shareMembersError => 'Nu s-au putut încărca membrii';

  @override
  String shareErrTooManyInvites(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other:
          'Ai deja $n de invitații active — așteaptă ca una să fie folosită sau să expire.',
      few:
          'Ai deja $n invitații active — așteaptă ca una să fie folosită sau să expire.',
      one:
          'Ai deja 1 invitație activă — așteaptă să fie folosită sau să expire.',
    );
    return '$_temp0';
  }

  @override
  String get shareErrOwnerOnly => 'Doar proprietarul poate invita persoane.';

  @override
  String get shareErrOwnerCannotLeave =>
      'Proprietarul nu își poate părăsi propria colecție.';

  @override
  String get shareErrMemberNotFound =>
      'Persoana respectivă nu mai este membru.';

  @override
  String get shareErrOwnerLapsed =>
      'Planul proprietarului a expirat — această colecție partajată este în pauză până îl reînnoiește.';

  @override
  String cloudErrRejected(int n, String reason) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n de modificări nu au putut fi sincronizate ($reason)',
      few: '$n modificări nu au putut fi sincronizate ($reason)',
      one: '1 modificare nu a putut fi sincronizată ($reason)',
    );
    return '$_temp0';
  }

  @override
  String get cloudRejDetailsLabel => 'Detalii';

  @override
  String get cloudRejDetailsValue => 'Vezi ce modificări a refuzat serverul';

  @override
  String get cloudRejScreenTitle => 'Modificări nesincronizate';

  @override
  String get cloudRejScreenIntro =>
      'Serverul a refuzat aceste modificări. „Reîncearcă” le trimite din nou pe toate; „Ignoră” le păstrează doar pe acest dispozitiv.';

  @override
  String get cloudRejEmpty =>
      'Nimic aici — toate modificările s-au sincronizat.';

  @override
  String get cloudRejRetry => 'Reîncearcă tot';

  @override
  String get cloudRejDismiss => 'Ignoră tot';

  @override
  String get cloudRejKindRetrying => 'se reîncearcă';

  @override
  String get cloudRejKindParked => 'abandonat';

  @override
  String cloudRejRequeued(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n de modificări puse din nou la coadă',
      few: '$n modificări puse din nou la coadă',
      one: '1 modificare pusă din nou la coadă',
    );
    return '$_temp0';
  }

  @override
  String get plantlyLoginSubtitleCloud =>
      'Folosește contul tău plantly.ro pentru backup și sincronizare în cloud.';

  @override
  String get cloudRejRetryValue => 'Trimite din nou toate modificările listate';

  @override
  String get cloudRejDismissValue => 'Păstrează-le doar pe acest dispozitiv';
}
