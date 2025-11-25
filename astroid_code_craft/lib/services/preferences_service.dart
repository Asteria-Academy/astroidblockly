// lib/services/preferences_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyShowcaseShown = 'showcase_shown';
  static const String _keyMusicEnabled = 'music_enabled';
  static const String _keyMusicVolume = 'music_volume';
  static const String _keyWebViewVolume = 'webview_volume';

  static PreferencesService? _instance;
  static SharedPreferences? _prefs;

  PreferencesService._();

  static Future<PreferencesService> getInstance() async {
    if (_instance == null) {
      _instance = PreferencesService._();
      _prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  bool hasShownShowcase() {
    return _prefs?.getBool(_keyShowcaseShown) ?? false;
  }

  Future<bool> setShowcaseShown(bool shown) async {
    return await _prefs?.setBool(_keyShowcaseShown, shown) ?? false;
  }

  Future<bool> resetShowcase() async {
    return await setShowcaseShown(false);
  }

  // === Music Settings ===
  bool isMusicEnabled() {
    return _prefs?.getBool(_keyMusicEnabled) ?? true;
  }

  Future<bool> setMusicEnabled(bool enabled) async {
    return await _prefs?.setBool(_keyMusicEnabled, enabled) ?? false;
  }

  double getMusicVolume() {
    return _prefs?.getDouble(_keyMusicVolume) ?? 0.2;
  }

  Future<bool> setMusicVolume(double volume) async {
    return await _prefs?.setDouble(_keyMusicVolume, volume.clamp(0.0, 1.0)) ??
        false;
  }

  // === WebView Settings ===
  double getWebViewVolume() {
    return _prefs?.getDouble(_keyWebViewVolume) ?? 1.0;
  }

  Future<bool> setWebViewVolume(double volume) async {
    return await _prefs?.setDouble(_keyWebViewVolume, volume.clamp(0.0, 1.0)) ??
        false;
  }
}
