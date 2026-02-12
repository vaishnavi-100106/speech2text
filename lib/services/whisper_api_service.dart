import 'dart:io';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WhisperApiService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _apiKeyKey = 'OPENAI_API_KEY';
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      final apiKey = await _getApiKey();
      if (apiKey.isEmpty) {
        throw Exception('OpenAI API key not configured');
      }

      final file = File(audioFilePath);
      if (!file.existsSync()) {
        throw Exception('Audio file not found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/audio/transcriptions'),
      );

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'multipart/form-data',
      });

      // Add file
      final audioFile = await http.MultipartFile.fromPath(
        'file',
        audioFilePath,
      );
      request.files.add(audioFile);

      // Add form fields
      request.fields['model'] = 'whisper-1';
      request.fields['language'] = 'en';
      request.fields['response_format'] = 'text';
      request.fields['temperature'] = '0.2';

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return response.body.trim();
      } else {
        final errorBody = json.decode(response.body);
        throw Exception('API Error: ${errorBody['error']['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Network error: Please check your internet connection');
      } else if (e is HttpException) {
        throw Exception('HTTP error: ${e.message}');
      } else {
        throw Exception('Transcription failed: $e');
      }
    }
  }

  Future<String> _getApiKey() async {
    try {
      // Try to get from secure storage first
      final storedKey = await _secureStorage.read(key: _apiKeyKey);
      if (storedKey != null && storedKey.isNotEmpty) {
        return storedKey;
      }

      // Fallback to environment variable
      final envKey = dotenv.env[_apiKeyKey] ?? '';
      if (envKey.isNotEmpty && envKey != 'your_openai_api_key_here') {
        // Store in secure storage for future use
        await _secureStorage.write(key: _apiKeyKey, value: envKey);
        return envKey;
      }

      return '';
    } catch (e) {
      return '';
    }
  }

  Future<bool> setApiKey(String apiKey) async {
    try {
      if (apiKey.isEmpty) {
        await _secureStorage.delete(key: _apiKeyKey);
        return true;
      }

      // Validate API key format (should start with 'sk-')
      if (!apiKey.startsWith('sk-')) {
        throw Exception('Invalid API key format');
      }

      await _secureStorage.write(key: _apiKeyKey, value: apiKey);
      return true;
    } catch (e) {
      throw Exception('Failed to save API key: $e');
    }
  }

  Future<bool> hasApiKey() async {
    final apiKey = await _getApiKey();
    return apiKey.isNotEmpty;
  }

  Future<void> clearApiKey() async {
    await _secureStorage.delete(key: _apiKeyKey);
  }
}
