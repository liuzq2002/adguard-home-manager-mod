import 'package:flutter/material.dart';

class AppLanguage {
  final String languageCode;
  final String? countryCode;
  final String name;

  const AppLanguage({
    required this.languageCode,
    this.countryCode,
    required this.name,
  });

  Locale get locale => Locale(languageCode, countryCode ?? '');

  /// BCP 47 tag, used by the Android and iOS locale settings.
  String get tag => countryCode != null
    ? '$languageCode-$countryCode'
    : languageCode;
}

/// zh-CN is left out on purpose: it resolves to the same translations as zh.
const List<AppLanguage> appLanguages = [
  AppLanguage(languageCode: 'zh', name: '简体中文'),
  AppLanguage(languageCode: 'en', name: 'English'),
];

List<AppLanguage> get sortedAppLanguages {
  return List<AppLanguage>.from(appLanguages);
}

AppLanguage? languageFromTag(String? tag) {
  if (tag == null) return null;
  for (final language in appLanguages) {
    if (language.tag == tag) return language;
  }
  final languageCode = tag.split('-').first;
  for (final language in appLanguages) {
    if (language.languageCode == languageCode) return language;
  }
  return null;
}
