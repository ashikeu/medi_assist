import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../constants/app_constants.dart';
import '../services/storage_service.dart';

/// One language the app ships.
class AppLanguage {
  const AppLanguage({
    required this.locale,
    required this.name,
    required this.englishName,
    required this.flag,
  });

  final Locale locale;

  /// The language's name in that language — a language list that reads
  /// "Bangla" to a Bangla speaker is no help to the person who needs it most.
  final String name;

  /// Used for the secondary line, so an English speaker who has landed in
  /// Bangla by accident can still find their way back.
  final String englishName;

  final String flag;

  /// Matches the key format GetX `Translations` maps use, e.g. `bn_BD`.
  String get tag => '${locale.languageCode}_${locale.countryCode}';
}

/// The app's language catalogue.
///
/// Adding a language means adding an entry here and a matching map in
/// `AppTranslations` — nothing else needs to know.
class AppLocales {
  AppLocales._();

  static const AppLanguage english = AppLanguage(
    locale: Locale('en', 'US'),
    name: 'English',
    englishName: 'English',
    flag: '🇬🇧',
  );

  static const AppLanguage bangla = AppLanguage(
    locale: Locale('bn', 'BD'),
    name: 'বাংলা',
    englishName: 'Bangla',
    flag: '🇧🇩',
  );

  static const List<AppLanguage> supported = [english, bangla];

  /// English unless the user says otherwise, per the product default.
  static const AppLanguage fallback = english;

  static List<Locale> get supportedLocales =>
      supported.map((l) => l.locale).toList();

  static AppLanguage byTag(String? tag) => supported.firstWhere(
        (l) => l.tag == tag,
        orElse: () => fallback,
      );

  /// The language to start the app in.
  ///
  /// Reads the settings box directly instead of going through
  /// [StorageService]: this is evaluated as an argument to the
  /// `GetMaterialApp` constructor, which happens *before* GetX runs
  /// `initialBinding` — so `StorageService.to` would not be registered yet.
  /// `main()` initialises both boxes before `runApp`, so the box itself is
  /// ready. Same box, same key as [StorageService.languageTag]; only the way
  /// in differs.
  static AppLanguage get initial {
    try {
      final tag = GetStorage(AppConstants.settingsBoxName)
          .read<String>(AppConstants.languageKey);
      return byTag(tag);
    } catch (_) {
      return fallback;
    }
  }

  /// The language currently in effect.
  static AppLanguage get current {
    final locale = Get.locale;
    if (locale == null) return initial;
    return byTag('${locale.languageCode}_${locale.countryCode}');
  }

  static bool get isBangla => current.locale.languageCode == 'bn';

  /// Switches language everywhere, immediately.
  ///
  /// `Get.updateLocale` rebuilds the whole widget tree, so every `.tr` is
  /// re-resolved without an app restart. Persisting first means the choice
  /// survives even if the process dies during the rebuild.
  static Future<void> change(AppLanguage language) async {
    await StorageService.to.setLanguageTag(language.tag);
    await Get.updateLocale(language.locale);
  }
}
