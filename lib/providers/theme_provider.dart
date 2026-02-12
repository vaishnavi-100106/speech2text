import 'package:flutter/material.dart';
import 'package:greenvoice/services/storage_service.dart';

class ThemeProvider extends ChangeNotifier {
  final StorageService _storageService = StorageService();
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      _isDarkMode = await _storageService.getDarkModePreference();
      notifyListeners();
    } catch (e) {
      // Default to light mode if there's an error
      _isDarkMode = false;
      notifyListeners();
    }
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _storageService.setDarkModePreference(_isDarkMode);
    notifyListeners();
  }
}
