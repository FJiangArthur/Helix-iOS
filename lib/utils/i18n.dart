import '../services/settings_manager.dart';

/// Lightweight i18n helper. Returns Chinese text when uiLanguage == 'zh',
/// otherwise returns the English text.
String tr(String en, String zh) {
  return SettingsManager.instance.uiLanguage == 'zh' ? zh : en;
}
