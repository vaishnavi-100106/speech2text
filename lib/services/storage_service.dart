import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _transcriptionKey = 'transcription_history';
  static const String _fontSizeKey = 'font_size';
  static const String _highContrastKey = 'high_contrast';
  static const String _vibrationKey = 'vibration_enabled';
  static const String _languageKey = 'selected_language';
  static const String _autoSaveKey = 'auto_save';
  static const String _darkModeKey = 'dark_mode';

  // Directory management
  Future<String> getTemporaryDirectory() async {
    final directory = await path_provider.getTemporaryDirectory();
    return directory.path;
  }

  Future<String> getApplicationDocumentsDirectory() async {
    final directory = await path_provider.getApplicationDocumentsDirectory();
    return directory.path;
  }

  // Transcription history management
  Future<List<Map<String, dynamic>>> getTranscriptionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_transcriptionKey) ?? '[]';
      final List<dynamic> historyList = json.decode(historyJson);
      return historyList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveTranscription(Map<String, dynamic> transcription) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getTranscriptionHistory();
      history.insert(0, transcription);
      
      // Keep only last 100 transcriptions
      if (history.length > 100) {
        history.removeRange(100, history.length);
      }
      
      await prefs.setString(_transcriptionKey, json.encode(history));
    } catch (e) {
      throw Exception('Failed to save transcription: $e');
    }
  }

  Future<void> deleteTranscription(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = await getTranscriptionHistory();
      history.removeWhere((item) => item['id'] == id);
      await prefs.setString(_transcriptionKey, json.encode(history));
    } catch (e) {
      throw Exception('Failed to delete transcription: $e');
    }
  }

  Future<void> clearTranscriptionHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_transcriptionKey);
    } catch (e) {
      throw Exception('Failed to clear history: $e');
    }
  }

  // Settings management
  Future<double> getFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_fontSizeKey) ?? 16.0;
    } catch (e) {
      return 16.0;
    }
  }

  Future<void> setFontSize(double size) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_fontSizeKey, size);
    } catch (e) {
      throw Exception('Failed to save font size: $e');
    }
  }

  Future<bool> getHighContrast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_highContrastKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setHighContrast(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_highContrastKey, enabled);
    } catch (e) {
      throw Exception('Failed to save high contrast setting: $e');
    }
  }

  Future<bool> getVibrationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_vibrationKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_vibrationKey, enabled);
    } catch (e) {
      throw Exception('Failed to save vibration setting: $e');
    }
  }

  Future<String> getSelectedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageKey) ?? 'en';
    } catch (e) {
      return 'en';
    }
  }

  Future<void> setSelectedLanguage(String language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, language);
    } catch (e) {
      throw Exception('Failed to save language setting: $e');
    }
  }

  Future<bool> getAutoSave() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_autoSaveKey) ?? true;
    } catch (e) {
      return true;
    }
  }

  Future<void> setAutoSave(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoSaveKey, enabled);
    } catch (e) {
      throw Exception('Failed to save auto-save setting: $e');
    }
  }

  Future<bool> getDarkModePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_darkModeKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> setDarkModePreference(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, isDarkMode);
    } catch (e) {
      throw Exception('Failed to save dark mode setting: $e');
    }
  }

  Future<void> resetSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fontSizeKey);
      await prefs.remove(_highContrastKey);
      await prefs.remove(_vibrationKey);
      await prefs.remove(_languageKey);
      await prefs.remove(_autoSaveKey);
    } catch (e) {
      throw Exception('Failed to reset settings: $e');
    }
  }

  // File management
  Future<void> deleteAudioFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Silently fail if file doesn't exist
    }
  }

  Future<void> cleanupOldAudioFiles() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final directory = Directory(tempDir);
      
      if (await directory.exists()) {
        final files = await directory.list().toList();
        final now = DateTime.now();
        
        for (final file in files) {
          if (file is File && file.path.endsWith('.wav')) {
            final stat = await file.stat();
            final difference = now.difference(stat.modified);
            
            // Delete files older than 7 days
            if (difference.inDays > 7) {
              await file.delete();
            }
          }
        }
      }
    } catch (e) {
      // Silently fail on cleanup errors
    }
  }
}
