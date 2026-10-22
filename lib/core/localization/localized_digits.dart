import 'app_locales.dart';

const List<String> _banglaDigits = [
  '০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯',
];

/// Renders Western digits as Bengali ones while Bangla is selected.
///
/// A Bangla screen with `12 Jan` and `08:00` on it reads half-translated, so
/// anything the app *displays* goes through here. What the user typed —
/// measurement values, search terms — is left exactly as entered, and so is
/// anything parsed back into a number.
extension LocalizedDigits on String {
  String get localizedDigits {
    if (!AppLocales.isBangla) return this;
    final buffer = StringBuffer();
    for (final unit in runes) {
      // 0x30..0x39 is ASCII '0'..'9'.
      if (unit >= 0x30 && unit <= 0x39) {
        buffer.write(_banglaDigits[unit - 0x30]);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }
}

extension LocalizedNumber on num {
  /// The number as display text, in the digits of the current language.
  String get localizedDigits => toString().localizedDigits;
}
