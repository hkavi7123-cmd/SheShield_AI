import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_guardian_service.dart';

/// Centralized Settings & User Preferences Service for SheShield AI.
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._internal();

  SettingsService._internal();

  SharedPreferences? _prefs;

  // Keys
  static const String _keySosCountdown = 'settings_sos_countdown';
  static const String _keySosConfirmation = 'settings_sos_confirmation';
  static const String _keyEmergencyMessage = 'settings_emergency_message';
  static const String _keyAiGuardianEnabled = 'settings_ai_guardian_enabled';
  static const String _keyMovementDetectionEnabled = 'settings_movement_detection_enabled';
  static const String _keyVoiceDetectionEnabled = 'settings_voice_detection_enabled';
  static const String _keyTransportDetectionEnabled = 'settings_transport_detection_enabled';
  static const String _keyProtectionMode = 'settings_protection_mode';
  static const String _keyLocationSharing = 'settings_location_sharing';
  static const String _keySafetyAlerts = 'settings_safety_alerts';
  static const String _keyEmergencyAlerts = 'settings_emergency_alerts';
  static const String _keyMovementAlerts = 'settings_movement_alerts';
  static const String _keyVoiceAlerts = 'settings_voice_alerts';
  static const String _keyCommunityAlerts = 'settings_community_alerts';
  static const String _keyThemeMode = 'settings_theme_mode';
  static const String _keyLanguage = 'settings_language';
  static const String _keyAlertSound = 'settings_alert_sound';
  static const String _keyVibration = 'settings_vibration';
  static const String _keySosSound = 'settings_sos_sound';

  // Default values
  int _sosCountdown = 5;
  bool _sosConfirmation = false;
  String _emergencyMessage = "🚨 EMERGENCY SOS ALERT - SheShield AI\n⚠️ I am in danger and require urgent assistance!";
  bool _aiGuardianEnabled = true;
  bool _movementDetectionEnabled = true;
  bool _voiceDetectionEnabled = true;
  bool _transportDetectionEnabled = true;
  bool _protectionMode = true;
  bool _locationSharing = true;
  bool _safetyAlerts = true;
  bool _emergencyAlerts = true;
  bool _movementAlerts = true;
  bool _voiceAlerts = true;
  bool _communityAlerts = true;
  ThemeMode _themeMode = ThemeMode.system;
  String _language = 'en'; // 'en' (English), 'ta' (Tamil)
  bool _alertSound = true;
  bool _vibration = true;
  bool _sosSound = true;

  // Getters
  int get sosCountdown => _sosCountdown;
  bool get sosConfirmation => _sosConfirmation;
  String get emergencyMessage => _emergencyMessage;
  bool get aiGuardianEnabled => _aiGuardianEnabled;
  bool get movementDetectionEnabled => _movementDetectionEnabled;
  bool get voiceDetectionEnabled => _voiceDetectionEnabled;
  bool get transportDetectionEnabled => _transportDetectionEnabled;
  bool get protectionMode => _protectionMode;
  bool get locationSharing => _locationSharing;
  bool get safetyAlerts => _safetyAlerts;
  bool get emergencyAlerts => _emergencyAlerts;
  bool get movementAlerts => _movementAlerts;
  bool get voiceAlerts => _voiceAlerts;
  bool get communityAlerts => _communityAlerts;
  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get alertSound => _alertSound;
  bool get vibration => _vibration;
  bool get sosSound => _sosSound;

  /// Initializes SharedPreferences and loads saved settings
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _loadSettings();
    } catch (e) {
      debugPrint("SettingsService init error: $e");
    }
  }

  void _loadSettings() {
    if (_prefs == null) return;

    _sosCountdown = _prefs!.getInt(_keySosCountdown) ?? 5;
    _sosConfirmation = _prefs!.getBool(_keySosConfirmation) ?? false;
    _emergencyMessage = _prefs!.getString(_keyEmergencyMessage) ??
        "🚨 EMERGENCY SOS ALERT - SheShield AI\n⚠️ I am in danger and require urgent assistance!";
    _aiGuardianEnabled = _prefs!.getBool(_keyAiGuardianEnabled) ?? true;
    _movementDetectionEnabled = _prefs!.getBool(_keyMovementDetectionEnabled) ?? true;
    _voiceDetectionEnabled = _prefs!.getBool(_keyVoiceDetectionEnabled) ?? true;
    _transportDetectionEnabled = _prefs!.getBool(_keyTransportDetectionEnabled) ?? true;
    _protectionMode = _prefs!.getBool(_keyProtectionMode) ?? true;
    _locationSharing = _prefs!.getBool(_keyLocationSharing) ?? true;
    _safetyAlerts = _prefs!.getBool(_keySafetyAlerts) ?? true;
    _emergencyAlerts = _prefs!.getBool(_keyEmergencyAlerts) ?? true;
    _movementAlerts = _prefs!.getBool(_keyMovementAlerts) ?? true;
    _voiceAlerts = _prefs!.getBool(_keyVoiceAlerts) ?? true;
    _communityAlerts = _prefs!.getBool(_keyCommunityAlerts) ?? true;

    final themeStr = _prefs!.getString(_keyThemeMode) ?? 'system';
    if (themeStr == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeStr == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _language = _prefs!.getString(_keyLanguage) ?? 'en';
    _alertSound = _prefs!.getBool(_keyAlertSound) ?? true;
    _vibration = _prefs!.getBool(_keyVibration) ?? true;
    _sosSound = _prefs!.getBool(_keySosSound) ?? true;

    notifyListeners();
  }

  // =========================================================
  // SETTERS (PERSISTENCE)
  // =========================================================

  Future<void> setSosCountdown(int seconds) async {
    _sosCountdown = seconds;
    await _prefs?.setInt(_keySosCountdown, seconds);
    notifyListeners();
  }

  Future<void> setSosConfirmation(bool value) async {
    _sosConfirmation = value;
    await _prefs?.setBool(_keySosConfirmation, value);
    notifyListeners();
  }

  Future<void> setEmergencyMessage(String message) async {
    _emergencyMessage = message;
    await _prefs?.setString(_keyEmergencyMessage, message);
    notifyListeners();
  }

  Future<void> setAiGuardianEnabled(bool value) async {
    _aiGuardianEnabled = value;
    await _prefs?.setBool(_keyAiGuardianEnabled, value);
    notifyListeners();
  }

  Future<void> setMovementDetectionEnabled(bool value) async {
    _movementDetectionEnabled = value;
    await _prefs?.setBool(_keyMovementDetectionEnabled, value);
    notifyListeners();
  }

  Future<void> setVoiceDetectionEnabled(bool value) async {
    _voiceDetectionEnabled = value;
    await _prefs?.setBool(_keyVoiceDetectionEnabled, value);
    notifyListeners();
  }

  Future<void> setTransportDetectionEnabled(bool value) async {
    _transportDetectionEnabled = value;
    await _prefs?.setBool(_keyTransportDetectionEnabled, value);
    notifyListeners();
  }

  Future<void> setProtectionMode(bool value) async {
    _protectionMode = value;
    await _prefs?.setBool(_keyProtectionMode, value);

    // Synchronize with AI Guardian Service
    if (value) {
      AIGuardianService.instance.startProtection();
    } else {
      AIGuardianService.instance.stopProtection();
    }

    notifyListeners();
  }

  Future<void> setLocationSharing(bool value) async {
    _locationSharing = value;
    await _prefs?.setBool(_keyLocationSharing, value);
    notifyListeners();
  }

  Future<void> setSafetyAlerts(bool value) async {
    _safetyAlerts = value;
    await _prefs?.setBool(_keySafetyAlerts, value);
    notifyListeners();
  }

  Future<void> setEmergencyAlerts(bool value) async {
    _emergencyAlerts = value;
    await _prefs?.setBool(_keyEmergencyAlerts, value);
    notifyListeners();
  }

  Future<void> setMovementAlerts(bool value) async {
    _movementAlerts = value;
    await _prefs?.setBool(_keyMovementAlerts, value);
    notifyListeners();
  }

  Future<void> setVoiceAlerts(bool value) async {
    _voiceAlerts = value;
    await _prefs?.setBool(_keyVoiceAlerts, value);
    notifyListeners();
  }

  Future<void> setCommunityAlerts(bool value) async {
    _communityAlerts = value;
    await _prefs?.setBool(_keyCommunityAlerts, value);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _prefs?.setString(_keyThemeMode, modeStr);
    notifyListeners();
  }

  Future<void> setLanguage(String langCode) async {
    _language = langCode;
    await _prefs?.setString(_keyLanguage, langCode);
    notifyListeners();
  }

  Future<void> setAlertSound(bool value) async {
    _alertSound = value;
    await _prefs?.setBool(_keyAlertSound, value);
    notifyListeners();
  }

  Future<void> setVibration(bool value) async {
    _vibration = value;
    await _prefs?.setBool(_keyVibration, value);
    notifyListeners();
  }

  Future<void> setSosSound(bool value) async {
    _sosSound = value;
    await _prefs?.setBool(_keySosSound, value);
    notifyListeners();
  }
}
