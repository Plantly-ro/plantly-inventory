import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

/// Romanian framework strings in the informal "tu" the app speaks
/// ("Afișează meniul", not Flutter's stock "Afișați meniul"). Everything
/// not overridden (dates, numbers, labels without a verb) is the stock
/// [MaterialLocalizationRo]. Other locales fall through to
/// [GlobalMaterialLocalizations.delegate] (first delegate of a type wins,
/// so this one goes before it).
class RoInformalMaterialLocalizations extends MaterialLocalizationRo {
  const RoInformalMaterialLocalizations({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });

  static const LocalizationsDelegate<MaterialLocalizations> delegate = _Delegate();

  @override
  String get calendarModeButtonLabel => 'Treci la calendar';
  @override
  String get cancelButtonLabel => 'Anulează';
  @override
  String get clearButtonTooltip => 'Șterge textul';
  @override
  String get closeButtonLabel => 'Închide';
  @override
  String get closeButtonTooltip => 'Închide';
  @override
  String get collapsedIconTapHint => 'Extinde';
  @override
  String get continueButtonLabel => 'Continuă';
  @override
  String get copyButtonLabel => 'Copiază';
  @override
  String get cutButtonLabel => 'Decupează';
  @override
  String get dateInputLabel => 'Introdu data';
  @override
  String get datePickerHelpText => 'Alege data';
  @override
  String get dateRangePickerHelpText => 'Alege intervalul';
  @override
  String get deleteButtonTooltip => 'Șterge';
  @override
  String get dialModeButtonLabel => 'Treci la cadran';
  @override
  String get expandedIconTapHint => 'Restrânge';
  @override
  String get expansionTileCollapsedHint => 'atinge de două ori ca să extinzi';
  @override
  String get expansionTileCollapsedTapHint => 'Extinde pentru mai multe detalii';
  @override
  String get expansionTileExpandedHint => 'atinge de două ori ca să restrângi';
  @override
  String get expansionTileExpandedTapHint => 'Restrânge';
  @override
  String get hideAccountsLabel => 'Ascunde conturile';
  @override
  String get inputDateModeButtonLabel => 'Treci la introducerea textului';
  @override
  String get inputTimeModeButtonLabel => 'Treci la introducerea textului';
  @override
  String get invalidTimeLabel => 'Introdu o oră validă';
  @override
  String get menuDismissLabel => 'Închide meniul';
  @override
  String get modalBarrierDismissLabel => 'Închide';
  @override
  String get openAppDrawerTooltip => 'Deschide meniul de navigare';
  @override
  String get pasteButtonLabel => 'Lipește';
  @override
  String get refreshIndicatorSemanticLabel => 'Reîmprospătează';
  @override
  String get reorderItemDown => 'Mută în jos';
  @override
  String get reorderItemLeft => 'Mută la stânga';
  @override
  String get reorderItemRight => 'Mută la dreapta';
  @override
  String get reorderItemToEnd => 'Mută la sfârșit';
  @override
  String get reorderItemToStart => 'Mută la început';
  @override
  String get reorderItemUp => 'Mută în sus';
  @override
  String get saveButtonLabel => 'Salvează';
  @override
  String get scanTextButtonLabel => 'Scanează textul';
  @override
  String get scrimOnTapHintRaw => r'Închide $modalRouteContentName';
  @override
  String get searchFieldLabel => 'Caută';
  @override
  String get searchWebButtonLabel => 'Caută pe web';
  @override
  String get selectAllButtonLabel => 'Selectează tot';
  @override
  String get selectYearSemanticsLabel => 'Alege anul';
  @override
  String get shareButtonLabel => 'Trimite';
  @override
  String get showAccountsLabel => 'Afișează conturile';
  @override
  String get showMenuTooltip => 'Afișează meniul';
  @override
  String get signedInLabel => 'Te-ai conectat';
  @override
  String get timePickerDialHelpText => 'Alege ora';
  @override
  String get timePickerHourModeAnnouncement => 'Alege ora';
  @override
  String get timePickerInputHelpText => 'Introdu ora';
  @override
  String get timePickerMinuteModeAnnouncement => 'Alege minutele';
  @override
  String get viewLicensesButtonLabel => 'Vezi licențele';
}

class _Delegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) => GlobalMaterialLocalizations.delegate.isSupported(locale);

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // The stock delegate also loads intl's date symbols; reuse it for
    // every locale and only swap the Romanian bundle.
    final stock = GlobalMaterialLocalizations.delegate.load(locale);
    if (locale.languageCode != 'ro') return stock;
    // `stock` is a SynchronousFuture: `then` stays synchronous (no frame
    // without localizations).
    return stock.then<MaterialLocalizations>((_) {
      const name = 'ro';
      return RoInformalMaterialLocalizations(
        fullYearFormat: intl.DateFormat.y(name),
        compactDateFormat: intl.DateFormat.yMd(name),
        shortDateFormat: intl.DateFormat.yMMMd(name),
        mediumDateFormat: intl.DateFormat.MMMEd(name),
        longDateFormat: intl.DateFormat.yMMMMEEEEd(name),
        yearMonthFormat: intl.DateFormat.yMMMM(name),
        shortMonthDayFormat: intl.DateFormat.MMMd(name),
        decimalFormat: intl.NumberFormat.decimalPattern(name),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', name),
      );
    });
  }

  @override
  bool shouldReload(_Delegate old) => false;
}
