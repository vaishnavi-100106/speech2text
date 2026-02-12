import 'package:flutter/material.dart';
import 'package:greenvoice/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  
  double _fontSize = 16.0;
  bool _highContrast = false;
  bool _vibrationEnabled = true;
  String _selectedLanguage = 'en';
  bool _autoSave = true;

  // Getters
  double get fontSize => _fontSize;
  bool get highContrast => _highContrast;
  bool get vibrationEnabled => _vibrationEnabled;
  String get selectedLanguage => _selectedLanguage;
  bool get autoSave => _autoSave;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      _fontSize = await _storageService.getFontSize();
      _highContrast = await _storageService.getHighContrast();
      _vibrationEnabled = await _storageService.getVibrationEnabled();
      _selectedLanguage = await _storageService.getSelectedLanguage();
      _autoSave = await _storageService.getAutoSave();
      notifyListeners();
    } catch (e) {
      // Use default values if there's an error
      notifyListeners();
    }
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size.clamp(12.0, 24.0);
    await _storageService.setFontSize(_fontSize);
    notifyListeners();
  }

  Future<void> setHighContrast(bool enabled) async {
    _highContrast = enabled;
    await _storageService.setHighContrast(_highContrast);
    notifyListeners();
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    _vibrationEnabled = enabled;
    await _storageService.setVibrationEnabled(_vibrationEnabled);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    _selectedLanguage = language;
    await _storageService.setSelectedLanguage(_selectedLanguage);
    notifyListeners();
  }

  Future<void> setAutoSave(bool enabled) async {
    _autoSave = enabled;
    await _storageService.setAutoSave(_autoSave);
    notifyListeners();
  }

  Future<void> resetToDefaults() async {
    _fontSize = 16.0;
    _highContrast = false;
    _vibrationEnabled = true;
    _selectedLanguage = 'en';
    _autoSave = true;
    
    await _storageService.resetSettings();
    notifyListeners();
  }
}
