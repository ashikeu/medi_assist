import 'package:flutter_test/flutter_test.dart';
import 'package:medi_assist/core/localization/app_locales.dart';
import 'package:medi_assist/core/prayer/calculation_params.dart';
import 'package:medi_assist/models/prayer_location_model.dart';
import 'package:medi_assist/core/localization/app_translations.dart';

void main() {
  final translations = AppTranslations().keys;

  group('Translations', () {
    test('cover every supported language', () {
      for (final language in AppLocales.supported) {
        expect(
          translations.containsKey(language.tag),
          isTrue,
          reason: '${language.englishName} is offered in Settings but has no '
              'entry in AppTranslations',
        );
      }
    });

    // The failure this guards against is silent: GetX falls back to printing
    // the key itself, so a missing translation ships as "medicine_add" on the
    // button rather than as a crash.
    test('define exactly the same keys in every language', () {
      final reference = translations[AppLocales.fallback.tag]!.keys.toSet();

      for (final entry in translations.entries) {
        final keys = entry.value.keys.toSet();
        expect(
          keys.difference(reference),
          isEmpty,
          reason: '${entry.key} has keys that ${AppLocales.fallback.tag} lacks',
        );
        expect(
          reference.difference(keys),
          isEmpty,
          reason: '${entry.key} is missing keys',
        );
      }
    });

    test('leave no value blank', () {
      for (final entry in translations.entries) {
        for (final pair in entry.value.entries) {
          expect(
            pair.value.trim(),
            isNotEmpty,
            reason: '${entry.key}/${pair.key} is empty',
          );
        }
      }
    });

    test('keep placeholders consistent across languages', () {
      final placeholder = RegExp(r'@[a-zA-Z_]+');
      final reference = translations[AppLocales.fallback.tag]!;

      for (final entry in translations.entries) {
        if (entry.key == AppLocales.fallback.tag) continue;
        for (final pair in entry.value.entries) {
          final expected = placeholder
              .allMatches(reference[pair.key] ?? '')
              .map((m) => m.group(0))
              .toSet();
          final actual = placeholder
              .allMatches(pair.value)
              .map((m) => m.group(0))
              .toSet();
          expect(
            actual,
            expected,
            reason: '${entry.key}/${pair.key} uses $actual but '
                '${AppLocales.fallback.tag} uses $expected — a dropped '
                'placeholder renders as a literal "@name" to the user',
          );
        }
      }
    });
  });

  // The prayer module builds several of its keys from an enum's stored id —
  // `prayer_$id`, `calc_method_$id` and so on. A grep for string literals
  // cannot see those, so adding an enum value with no matching translation
  // would otherwise ship as a raw key on screen.
  group('Prayer translation keys', () {
    void expectKey(String key) {
      for (final entry in translations.entries) {
        expect(
          entry.value[key],
          isNotNull,
          reason: '${entry.key} is missing "$key", which is built from an '
              'enum id rather than written out as a literal',
        );
      }
    }

    test('name every prayer', () {
      for (final kind in PrayerKind.values) {
        expectKey(kind.nameKey);
      }
    });

    test('name every calculation method', () {
      for (final method in CalculationMethod.values) {
        expectKey(method.nameKey);
      }
    });

    test('name and explain every madhab', () {
      for (final madhab in Madhab.values) {
        expectKey(madhab.nameKey);
        expectKey('${madhab.nameKey}_detail');
      }
    });

    test('name and explain every high-latitude rule', () {
      for (final rule in HighLatitudeRule.values) {
        expectKey(rule.nameKey);
        expectKey('${rule.nameKey}_detail');
      }
    });

    test('name every location source', () {
      for (final source in PrayerLocationSource.values) {
        expectKey(source.nameKey);
      }
    });
  });

  group('AppLocales', () {
    test('defaults to English for an unknown or absent tag', () {
      expect(AppLocales.byTag(null), AppLocales.english);
      expect(AppLocales.byTag('fr_FR'), AppLocales.english);
      expect(AppLocales.fallback, AppLocales.english);
    });

    test('round-trips each language through its tag', () {
      for (final language in AppLocales.supported) {
        expect(AppLocales.byTag(language.tag), same(language));
      }
    });

    test('gives every language a distinct tag', () {
      final tags = AppLocales.supported.map((l) => l.tag).toSet();
      expect(tags.length, AppLocales.supported.length);
    });
  });
}
