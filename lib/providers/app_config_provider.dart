import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:adguard_home_manager/constants/languages.dart';
import 'package:adguard_home_manager/services/platform_locale.dart';

class AppConfigProvider with ChangeNotifier {
  final SharedPreferences sharedPreferencesInstance;

  AppConfigProvider({required this.sharedPreferencesInstance});

  static const String appVersion =
      String.fromEnvironment('FLUTTER_BUILD_NAME', defaultValue: '2.24.11');

  int _selectedScreen = 0;
  bool _showingSnackbar = false;
  int _selectedTheme = 0; // 0: system, 1: light, 2: dark
  String? _selectedLanguage;
  int _selectedFiltersTab = 0;
  String _moduleHttpAddress = '';

  final bool useThemeColorForStatus = false;

  ThemeMode get selectedTheme {
    switch (_selectedTheme) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      case 0:
      default:
        return ThemeMode.system;
    }
  }

  int get selectedThemeNumber => _selectedTheme;

  String? get selectedLanguage => _selectedLanguage;

  Locale? get selectedLocale => languageFromTag(_selectedLanguage)?.locale;

  int get selectedFiltersTab => _selectedFiltersTab;

  int get selectedScreen => _selectedScreen;

  bool get showingSnackbar => _showingSnackbar;

  String get moduleHttpAddress => _moduleHttpAddress;

  void setSelectedFiltersTab(int tab, {bool notify = false}) {
    if (_selectedFiltersTab == tab) return;
    _selectedFiltersTab = tab;
    if (notify) {
      notifyListeners();
    }
  }

  void setSelectedScreen(int screen) {
    if (_selectedScreen == screen) return;
    _selectedScreen = screen;
    notifyListeners();
  }

  void setShowingSnackbar(bool status) {
    if (_showingSnackbar == status) return;
    _showingSnackbar = status;
    notifyListeners();
  }

  Future<bool> setSelectedTheme(int value) async {
    try {
      await sharedPreferencesInstance.setInt('selectedTheme', value);
      _selectedTheme = value;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setSelectedLanguage(String? value) async {
    try {
      if (value == null || value == 'system') {
        await sharedPreferencesInstance.remove('selectedLanguage');
        _selectedLanguage = null;
      } else {
        await sharedPreferencesInstance.setString('selectedLanguage', value);
        _selectedLanguage = value;
      }
      await PlatformLocaleService.setApplicationLocale(_selectedLanguage);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncLanguageWithSystem() async {
    try {
      final systemTag = await PlatformLocaleService.getApplicationLocale();
      final resolved = languageFromTag(systemTag)?.tag;
      if (resolved == _selectedLanguage) return;
      if (systemTag == null && _selectedLanguage != null) {
        await PlatformLocaleService.setApplicationLocale(_selectedLanguage);
        return;
      }
      _selectedLanguage = resolved;
      if (resolved == null) {
        await sharedPreferencesInstance.remove('selectedLanguage');
      } else {
        await sharedPreferencesInstance.setString('selectedLanguage', resolved);
      }
      notifyListeners();
    } catch (_) {}
  }

  void setModuleHttpAddress(String value) {
    if (_moduleHttpAddress == value) return;
    _moduleHttpAddress = value;
    sharedPreferencesInstance.setString('moduleHttpAddress', value);
    notifyListeners();
  }

  void saveFromSharedPreferences() {
    _selectedTheme = sharedPreferencesInstance.getInt('selectedTheme') ?? 0;
    _selectedLanguage = sharedPreferencesInstance.getString('selectedLanguage');
    _moduleHttpAddress =
        sharedPreferencesInstance.getString('moduleHttpAddress') ?? '';
  }
}
