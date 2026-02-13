import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Wav2VecService {
  late String _baseUrl;
  static const String _endpoint = '/transcribe';
  
  Wav2VecService() {
    _loadBaseUrl();
  }

  Future<void> _loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('wav2vec_endpoint') ?? 'https://your-wav2vec-api.com';
  }

  Future<String> getBaseUrl() async {
    if (_baseUrl.isEmpty) {
      await _loadBaseUrl();
    }
    return _baseUrl;
  }

  Future<void> setBaseUrl(String baseUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wav2vec_endpoint', baseUrl);
    _baseUrl = baseUrl;
  }

  Future<String> transcribeAudio(String audioFilePath) async {
    try {
      await _loadBaseUrl(); // Ensure we have the latest base URL
      final file = File(audioFilePath);
      if (!file.existsSync()) {
        throw Exception('Audio file not found');
      }

      // Read audio file bytes
      final audioBytes = await file.readAsBytes();
      
      // Create the request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$_endpoint'),
      );

      // Add headers (modify based on your API requirements)
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        // Add authentication headers if needed
        // 'Authorization': 'Bearer $apiKey',
      });

      // Add audio file
      final audioFile = http.MultipartFile.fromBytes(
        'audio', // Change field name based on your API
        audioBytes,
        filename: 'recording.wav',
      );
      request.files.add(audioFile);

      // Add form fields (modify based on your API requirements)
      request.fields['model'] = 'wav2vec2';
      request.fields['language'] = 'en';
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // Parse response based on your API format
        final responseData = json.decode(response.body);
        
        // Adjust this based on your API response structure
        if (responseData['text'] != null) {
          return responseData['text'].toString().trim();
        } else if (responseData['transcription'] != null) {
          return responseData['transcription'].toString().trim();
        } else {
          return response.body.trim();
        }
      } else {
        final errorBody = response.statusCode == 200 
            ? response.body 
            : json.decode(response.body);
        throw Exception('API Error: ${errorBody['error'] ?? errorBody['message'] ?? 'Unknown error'}');
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

  // Alternative method for streaming audio (if your API supports it)
  Future<String> transcribeAudioStream(List<int> audioBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl$_endpoint'),
      );

      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
      });

      final audioFile = http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'recording.wav',
      );
      request.files.add(audioFile);

      request.fields['model'] = 'wav2vec2';
      request.fields['language'] = 'en';
      request.fields['streaming'] = 'true';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['text']?.toString().trim() ?? response.body.trim();
      } else {
        throw Exception('API Error: ${response.body}');
      }
    } catch (e) {
      throw Exception('Streaming transcription failed: $e');
    }
  }

  // Method to test API connectivity
  Future<bool> testConnection() async {
    try {
      await _loadBaseUrl(); // Ensure we have the latest base URL
      final response = await http.get(
        Uri.parse('$_baseUrl/health'), // Adjust endpoint as needed
        headers: {'Content-Type': 'application/json'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Method to get supported languages (if your API supports this)
  Future<List<String>> getSupportedLanguages() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/languages'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return List<String>.from(responseData['languages'] ?? ['en']);
      }
      return ['en']; // Default to English if API call fails
    } catch (e) {
      return ['en']; // Default to English if API call fails
    }
  }
}
