import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Forces Flutter's own time picker onto a 12-hour dial with an AM/PM selector
/// in every language.
///
/// A `MediaQuery` with `alwaysUse24HourFormat: false` is not enough on its own.
/// That flag means "use the locale's own default", not "use 12-hour", and
/// `GlobalMaterialLocalizations` hardcodes `TimeOfDayFormat.H_colon_mm` — a
/// 0–23 dial — for Bengali:
///
/// ```dart
/// class MaterialLocalizationBn extends GlobalMaterialLocalizations {
///   TimeOfDayFormat get timeOfDayFormatRaw => TimeOfDayFormat.H_colon_mm;
/// ```
///
/// So English got AM/PM and Bangla did not. `MaterialLocalizations` exposes no
/// "force 12-hour" switch, which leaves handing the picker a different
/// `MaterialLocalizations` as the only way to change its answer.
///
/// Rather than restate ~150 localized strings, this wraps whichever
/// `GlobalMaterialLocalizations` the active locale loaded and overrides only the
/// three members that decide the clock format. Everything else forwards
/// untouched, so the picker's own chrome — "Select time", "Cancel", "OK" — stays
/// in the user's language. AM/PM markers deliberately forward too: Flutter's own
/// Bengali data spells them `AM`/`PM`, and the app's `time_am`/`time_pm` keys are
/// unused in Bangla (`TimeUtils` names the part of the day there instead), so
/// borrowing them would invent a style that appears nowhere else.
///
/// The forwarding members below are generated. If a Flutter upgrade adds a
/// member to `MaterialLocalizations` this file stops compiling with a "missing
/// concrete implementation" error — add the forwarder then rather than guessing.
class TwelveHourMaterialLocalizations implements MaterialLocalizations {
  const TwelveHourMaterialLocalizations(this._inner);

  final MaterialLocalizations _inner;

  /// Register this *before* [GlobalMaterialLocalizations.delegate]: only the
  /// first delegate for a given type is loaded.
  static const LocalizationsDelegate<MaterialLocalizations> delegate =
      _TwelveHourMaterialLocalizationsDelegate();

  // ─── The three members that decide the clock format ─────────────────────────

  /// Ignores both [alwaysUse24HourFormat] and the locale's own preference on
  /// purpose — every clock in this app is 12-hour, see `TimeUtils`.
  @override
  TimeOfDayFormat timeOfDayFormat({bool alwaysUse24HourFormat = false}) =>
      TimeOfDayFormat.h_colon_mm_space_a;

  /// `GlobalMaterialLocalizations.formatHour` reads `this.timeOfDayFormat()`,
  /// and `this` there is the *wrapped* object, which still answers 24-hour.
  /// Forwarding it would print "13" beside a PM marker.
  @override
  String formatHour(TimeOfDay timeOfDay, {bool alwaysUse24HourFormat = false}) {
    final hour = timeOfDay.hourOfPeriod;
    return _inner.formatDecimal(hour == 0 ? 12 : hour);
  }

  /// Same reason as [formatHour] — it too asks `this.timeOfDayFormat()`, and
  /// picks the separator and marker placement from the answer.
  @override
  String formatTimeOfDay(
    TimeOfDay timeOfDay, {
    bool alwaysUse24HourFormat = false,
  }) {
    final marker = timeOfDay.period == DayPeriod.am
        ? _inner.anteMeridiemAbbreviation
        : _inner.postMeridiemAbbreviation;
    return '${formatHour(timeOfDay)}:${_inner.formatMinute(timeOfDay)} $marker';
  }

  // ─── Generated forwarders ───────────────────────────────────────────────────

  @override
  String get openAppDrawerTooltip => _inner.openAppDrawerTooltip;

  @override
  String get backButtonTooltip => _inner.backButtonTooltip;

  @override
  String get clearButtonTooltip => _inner.clearButtonTooltip;

  @override
  String get closeButtonTooltip => _inner.closeButtonTooltip;

  @override
  String get deleteButtonTooltip => _inner.deleteButtonTooltip;

  @override
  String get moreButtonTooltip => _inner.moreButtonTooltip;

  @override
  String get nextMonthTooltip => _inner.nextMonthTooltip;

  @override
  String get previousMonthTooltip => _inner.previousMonthTooltip;

  @override
  String get firstPageTooltip => _inner.firstPageTooltip;

  @override
  String get lastPageTooltip => _inner.lastPageTooltip;

  @override
  String get nextPageTooltip => _inner.nextPageTooltip;

  @override
  String get previousPageTooltip => _inner.previousPageTooltip;

  @override
  String get showMenuTooltip => _inner.showMenuTooltip;

  @override
  String aboutListTileTitle(String applicationName) =>
      _inner.aboutListTileTitle(applicationName);

  @override
  String get licensesPageTitle => _inner.licensesPageTitle;

  @override
  String licensesPackageDetailText(int licenseCount) =>
      _inner.licensesPackageDetailText(licenseCount);

  @override
  String pageRowsInfoTitle(int firstRow, int lastRow, int rowCount, bool rowCountIsApproximate) =>
      _inner.pageRowsInfoTitle(firstRow, lastRow, rowCount, rowCountIsApproximate);

  @override
  String get rowsPerPageTitle => _inner.rowsPerPageTitle;

  @override
  String tabLabel({required int tabIndex, required int tabCount}) =>
      _inner.tabLabel(tabIndex: tabIndex, tabCount: tabCount);

  @override
  String selectedRowCountTitle(int selectedRowCount) =>
      _inner.selectedRowCountTitle(selectedRowCount);

  @override
  String get cancelButtonLabel => _inner.cancelButtonLabel;

  @override
  String get closeButtonLabel => _inner.closeButtonLabel;

  @override
  String get continueButtonLabel => _inner.continueButtonLabel;

  @override
  String get copyButtonLabel => _inner.copyButtonLabel;

  @override
  String get cutButtonLabel => _inner.cutButtonLabel;

  @override
  String get scanTextButtonLabel => _inner.scanTextButtonLabel;

  @override
  String get okButtonLabel => _inner.okButtonLabel;

  @override
  String get pasteButtonLabel => _inner.pasteButtonLabel;

  @override
  String get selectAllButtonLabel => _inner.selectAllButtonLabel;

  @override
  String get lookUpButtonLabel => _inner.lookUpButtonLabel;

  @override
  String get searchWebButtonLabel => _inner.searchWebButtonLabel;

  @override
  String get shareButtonLabel => _inner.shareButtonLabel;

  @override
  String get viewLicensesButtonLabel => _inner.viewLicensesButtonLabel;

  @override
  String get anteMeridiemAbbreviation => _inner.anteMeridiemAbbreviation;

  @override
  String get postMeridiemAbbreviation => _inner.postMeridiemAbbreviation;

  @override
  String get timePickerHourModeAnnouncement => _inner.timePickerHourModeAnnouncement;

  @override
  String get timePickerMinuteModeAnnouncement => _inner.timePickerMinuteModeAnnouncement;

  @override
  String get modalBarrierDismissLabel => _inner.modalBarrierDismissLabel;

  @override
  String get menuDismissLabel => _inner.menuDismissLabel;

  @override
  String get drawerLabel => _inner.drawerLabel;

  @override
  String get popupMenuLabel => _inner.popupMenuLabel;

  @override
  String get menuBarMenuLabel => _inner.menuBarMenuLabel;

  @override
  String get dialogLabel => _inner.dialogLabel;

  @override
  String get alertDialogLabel => _inner.alertDialogLabel;

  @override
  String get searchFieldLabel => _inner.searchFieldLabel;

  @override
  String get currentDateLabel => _inner.currentDateLabel;

  @override
  String get selectedDateLabel => _inner.selectedDateLabel;

  @override
  String get scrimLabel => _inner.scrimLabel;

  @override
  String get bottomSheetLabel => _inner.bottomSheetLabel;

  @override
  String scrimOnTapHint(String modalRouteContentName) =>
      _inner.scrimOnTapHint(modalRouteContentName);

  @override
  ScriptCategory get scriptCategory => _inner.scriptCategory;

  @override
  String formatDecimal(int number) =>
      _inner.formatDecimal(number);

  @override
  String formatMinute(TimeOfDay timeOfDay) =>
      _inner.formatMinute(timeOfDay);

  @override
  String formatYear(DateTime date) =>
      _inner.formatYear(date);

  @override
  String formatCompactDate(DateTime date) =>
      _inner.formatCompactDate(date);

  @override
  String formatShortDate(DateTime date) =>
      _inner.formatShortDate(date);

  @override
  String formatMediumDate(DateTime date) =>
      _inner.formatMediumDate(date);

  @override
  String formatFullDate(DateTime date) =>
      _inner.formatFullDate(date);

  @override
  String formatMonthYear(DateTime date) =>
      _inner.formatMonthYear(date);

  @override
  String formatShortMonthDay(DateTime date) =>
      _inner.formatShortMonthDay(date);

  @override
  DateTime? parseCompactDate(String? inputString) =>
      _inner.parseCompactDate(inputString);

  @override
  List<String> get narrowWeekdays => _inner.narrowWeekdays;

  @override
  int get firstDayOfWeekIndex => _inner.firstDayOfWeekIndex;

  @override
  String get dateSeparator => _inner.dateSeparator;

  @override
  String get dateHelpText => _inner.dateHelpText;

  @override
  String get selectYearSemanticsLabel => _inner.selectYearSemanticsLabel;

  @override
  String get unspecifiedDate => _inner.unspecifiedDate;

  @override
  String get unspecifiedDateRange => _inner.unspecifiedDateRange;

  @override
  String get dateInputLabel => _inner.dateInputLabel;

  @override
  String get dateRangeStartLabel => _inner.dateRangeStartLabel;

  @override
  String get dateRangeEndLabel => _inner.dateRangeEndLabel;

  @override
  String dateRangeStartDateSemanticLabel(String formattedDate) =>
      _inner.dateRangeStartDateSemanticLabel(formattedDate);

  @override
  String dateRangeEndDateSemanticLabel(String formattedDate) =>
      _inner.dateRangeEndDateSemanticLabel(formattedDate);

  @override
  String get invalidDateFormatLabel => _inner.invalidDateFormatLabel;

  @override
  String get invalidDateRangeLabel => _inner.invalidDateRangeLabel;

  @override
  String get dateOutOfRangeLabel => _inner.dateOutOfRangeLabel;

  @override
  String get saveButtonLabel => _inner.saveButtonLabel;

  @override
  String get datePickerHelpText => _inner.datePickerHelpText;

  @override
  String get dateRangePickerHelpText => _inner.dateRangePickerHelpText;

  @override
  String get calendarModeButtonLabel => _inner.calendarModeButtonLabel;

  @override
  String get inputDateModeButtonLabel => _inner.inputDateModeButtonLabel;

  @override
  String get timePickerDialHelpText => _inner.timePickerDialHelpText;

  @override
  String get timePickerInputHelpText => _inner.timePickerInputHelpText;

  @override
  String get timePickerHourLabel => _inner.timePickerHourLabel;

  @override
  String get timePickerMinuteLabel => _inner.timePickerMinuteLabel;

  @override
  String get invalidTimeLabel => _inner.invalidTimeLabel;

  @override
  String get dialModeButtonLabel => _inner.dialModeButtonLabel;

  @override
  String get inputTimeModeButtonLabel => _inner.inputTimeModeButtonLabel;

  @override
  String get signedInLabel => _inner.signedInLabel;

  @override
  String get hideAccountsLabel => _inner.hideAccountsLabel;

  @override
  String get showAccountsLabel => _inner.showAccountsLabel;

  @override
  String get reorderItemToStart => _inner.reorderItemToStart;

  @override
  String get reorderItemToEnd => _inner.reorderItemToEnd;

  @override
  String get reorderItemUp => _inner.reorderItemUp;

  @override
  String get reorderItemDown => _inner.reorderItemDown;

  @override
  String get reorderItemLeft => _inner.reorderItemLeft;

  @override
  String get reorderItemRight => _inner.reorderItemRight;

  @override
  String remainingTextFieldCharacterCount(int remaining) =>
      _inner.remainingTextFieldCharacterCount(remaining);

  @override
  String get refreshIndicatorSemanticLabel => _inner.refreshIndicatorSemanticLabel;

  @override
  String get keyboardKeyAlt => _inner.keyboardKeyAlt;

  @override
  String get keyboardKeyAltGraph => _inner.keyboardKeyAltGraph;

  @override
  String get keyboardKeyBackspace => _inner.keyboardKeyBackspace;

  @override
  String get keyboardKeyCapsLock => _inner.keyboardKeyCapsLock;

  @override
  String get keyboardKeyChannelDown => _inner.keyboardKeyChannelDown;

  @override
  String get keyboardKeyChannelUp => _inner.keyboardKeyChannelUp;

  @override
  String get keyboardKeyControl => _inner.keyboardKeyControl;

  @override
  String get keyboardKeyDelete => _inner.keyboardKeyDelete;

  @override
  String get keyboardKeyEject => _inner.keyboardKeyEject;

  @override
  String get keyboardKeyEnd => _inner.keyboardKeyEnd;

  @override
  String get keyboardKeyEscape => _inner.keyboardKeyEscape;

  @override
  String get keyboardKeyFn => _inner.keyboardKeyFn;

  @override
  String get keyboardKeyHome => _inner.keyboardKeyHome;

  @override
  String get keyboardKeyInsert => _inner.keyboardKeyInsert;

  @override
  String get keyboardKeyMeta => _inner.keyboardKeyMeta;

  @override
  String get keyboardKeyMetaMacOs => _inner.keyboardKeyMetaMacOs;

  @override
  String get keyboardKeyMetaWindows => _inner.keyboardKeyMetaWindows;

  @override
  String get keyboardKeyNumLock => _inner.keyboardKeyNumLock;

  @override
  String get keyboardKeyNumpad1 => _inner.keyboardKeyNumpad1;

  @override
  String get keyboardKeyNumpad2 => _inner.keyboardKeyNumpad2;

  @override
  String get keyboardKeyNumpad3 => _inner.keyboardKeyNumpad3;

  @override
  String get keyboardKeyNumpad4 => _inner.keyboardKeyNumpad4;

  @override
  String get keyboardKeyNumpad5 => _inner.keyboardKeyNumpad5;

  @override
  String get keyboardKeyNumpad6 => _inner.keyboardKeyNumpad6;

  @override
  String get keyboardKeyNumpad7 => _inner.keyboardKeyNumpad7;

  @override
  String get keyboardKeyNumpad8 => _inner.keyboardKeyNumpad8;

  @override
  String get keyboardKeyNumpad9 => _inner.keyboardKeyNumpad9;

  @override
  String get keyboardKeyNumpad0 => _inner.keyboardKeyNumpad0;

  @override
  String get keyboardKeyNumpadAdd => _inner.keyboardKeyNumpadAdd;

  @override
  String get keyboardKeyNumpadComma => _inner.keyboardKeyNumpadComma;

  @override
  String get keyboardKeyNumpadDecimal => _inner.keyboardKeyNumpadDecimal;

  @override
  String get keyboardKeyNumpadDivide => _inner.keyboardKeyNumpadDivide;

  @override
  String get keyboardKeyNumpadEnter => _inner.keyboardKeyNumpadEnter;

  @override
  String get keyboardKeyNumpadEqual => _inner.keyboardKeyNumpadEqual;

  @override
  String get keyboardKeyNumpadMultiply => _inner.keyboardKeyNumpadMultiply;

  @override
  String get keyboardKeyNumpadParenLeft => _inner.keyboardKeyNumpadParenLeft;

  @override
  String get keyboardKeyNumpadParenRight => _inner.keyboardKeyNumpadParenRight;

  @override
  String get keyboardKeyNumpadSubtract => _inner.keyboardKeyNumpadSubtract;

  @override
  String get keyboardKeyPageDown => _inner.keyboardKeyPageDown;

  @override
  String get keyboardKeyPageUp => _inner.keyboardKeyPageUp;

  @override
  String get keyboardKeyPower => _inner.keyboardKeyPower;

  @override
  String get keyboardKeyPowerOff => _inner.keyboardKeyPowerOff;

  @override
  String get keyboardKeyPrintScreen => _inner.keyboardKeyPrintScreen;

  @override
  String get keyboardKeyScrollLock => _inner.keyboardKeyScrollLock;

  @override
  String get keyboardKeySelect => _inner.keyboardKeySelect;

  @override
  String get keyboardKeyShift => _inner.keyboardKeyShift;

  @override
  String get keyboardKeySpace => _inner.keyboardKeySpace;

  // These eight carry default bodies in the abstract class. `implements` does
  // not inherit them, so they need forwarders like everything else.
  @override
  String get expandedIconTapHint => _inner.expandedIconTapHint;

  @override
  String get collapsedIconTapHint => _inner.collapsedIconTapHint;

  @override
  String get expansionTileExpandedHint => _inner.expansionTileExpandedHint;

  @override
  String get expansionTileCollapsedHint => _inner.expansionTileCollapsedHint;

  @override
  String get expansionTileExpandedTapHint => _inner.expansionTileExpandedTapHint;

  @override
  String get expansionTileCollapsedTapHint =>
      _inner.expansionTileCollapsedTapHint;

  @override
  String get expandedHint => _inner.expandedHint;

  @override
  String get collapsedHint => _inner.collapsedHint;
}

class _TwelveHourMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _TwelveHourMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      GlobalMaterialLocalizations.delegate.isSupported(locale);

  /// `.then` on the delegate's `SynchronousFuture` stays synchronous, which
  /// keeps localizations loading in the same frame — an `async` body here would
  /// defer the first frame and show the previous locale for one build.
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate
          .load(locale)
          .then<MaterialLocalizations>(TwelveHourMaterialLocalizations.new);

  @override
  bool shouldReload(_TwelveHourMaterialLocalizationsDelegate old) => false;
}
