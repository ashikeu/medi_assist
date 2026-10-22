import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medi_assist/core/localization/app_locales.dart';
import 'package:medi_assist/core/localization/twelve_hour_material_localizations.dart';

/// Guards the fix for Bengali showing a 0–23 dial: `GlobalMaterialLocalizations`
/// declares `TimeOfDayFormat.H_colon_mm` for `bn`, and `alwaysUse24HourFormat`
/// only selects the locale's own default rather than forcing 12-hour.
Future<MaterialLocalizations> _load(Locale locale) =>
    TwelveHourMaterialLocalizations.delegate.load(locale);

void main() {
  test('every supported language is covered by the delegate', () {
    for (final language in AppLocales.supported) {
      expect(
        TwelveHourMaterialLocalizations.delegate.isSupported(language.locale),
        isTrue,
        reason: '${language.locale} must resolve through the wrapper',
      );
    }
  });

  test('every supported language gets a 12-hour dial', () async {
    for (final language in AppLocales.supported) {
      final l10n = await _load(language.locale);
      expect(
        hourFormat(of: l10n.timeOfDayFormat()),
        HourFormat.h,
        reason: '${language.locale} must use a 12-hour dial',
      );
      // The picker passes the device setting straight through; it must not be
      // able to drag any locale back to 24-hour.
      expect(
        hourFormat(of: l10n.timeOfDayFormat(alwaysUse24HourFormat: true)),
        HourFormat.h,
        reason: '${language.locale} must ignore the 24-hour device setting',
      );
    }
  });

  test('Bengali, the regression, no longer reports 24-hour', () async {
    final bare = await GlobalMaterialLocalizations.delegate.load(
      const Locale('bn', 'BD'),
    );
    // Documents *why* the wrapper exists — if this ever changes upstream the
    // wrapper is merely redundant, not wrong.
    expect(bare.timeOfDayFormat(), TimeOfDayFormat.H_colon_mm);

    final wrapped = await _load(const Locale('bn', 'BD'));
    expect(wrapped.timeOfDayFormat(), TimeOfDayFormat.h_colon_mm_space_a);
  });

  test('afternoon hours render as 12-hour with a marker, not 13:00', () async {
    for (final language in AppLocales.supported) {
      final l10n = await _load(language.locale);
      const oneThirtyPm = TimeOfDay(hour: 13, minute: 30);

      expect(l10n.formatHour(oneThirtyPm), isNot(contains('13')));
      expect(
        l10n.formatTimeOfDay(oneThirtyPm),
        contains(l10n.postMeridiemAbbreviation),
        reason: '${language.locale} must show a PM marker',
      );
    }
  });

  test('midnight renders as 12, not 0', () async {
    final l10n = await _load(const Locale('bn', 'BD'));
    const midnight = TimeOfDay(hour: 0, minute: 5);
    expect(l10n.formatHour(midnight), l10n.formatDecimal(12));
    expect(l10n.formatTimeOfDay(midnight),
        contains(l10n.anteMeridiemAbbreviation));
  });

  test('forwarded strings still come from the wrapped locale', () async {
    final en = await _load(const Locale('en', 'US'));
    final bn = await _load(const Locale('bn', 'BD'));
    // The picker's own chrome must stay localized — that is the whole reason
    // this wraps the real delegate instead of substituting an English one.
    expect(bn.okButtonLabel, isNot(en.okButtonLabel));
    expect(bn.cancelButtonLabel, isNot(en.cancelButtonLabel));
  });

  testWidgets('the real picker shows an AM/PM selector in Bangla', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('bn', 'BD'),
      localizationsDelegates: const [
        TwelveHourMaterialLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('bn', 'BD'), Locale('en', 'US')],
      home: Builder(builder: (context) {
        ctx = context;
        return const SizedBox();
      }),
    ));

    showTimePicker(context: ctx, initialTime: const TimeOfDay(hour: 13, minute: 30));
    await tester.pumpAndSettle();

    final l10n = MaterialLocalizations.of(ctx);
    // The AM/PM control only exists on a 12-hour dial.
    expect(find.text(l10n.anteMeridiemAbbreviation), findsOneWidget);
    expect(find.text(l10n.postMeridiemAbbreviation), findsOneWidget);
    // 13:30 must read as 1:30, and 13 must appear nowhere.
    expect(find.text(l10n.formatDecimal(1)), findsWidgets);
    expect(find.text(l10n.formatDecimal(13)), findsNothing);
    // Chrome stays Bangla.
    expect(find.text(l10n.cancelButtonLabel), findsOneWidget);
  });
}
