import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class GoogleColabService {
  late String _colabUrl;
  static const String _transcribeEndpoint = '/transcribe';
  static const String _healthEndpoint = '/health';
  static const String _modelsEndpoint = '/models';
  
  GoogleColabService() {
    _loadColabUrl();
  }

  Future<void> _loadColabUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _colabUrl = prefs.getString('colab_url') ?? 'http://localhost:5000';
  }

  Future<String> getColabUrl() async {
    if (_colabUrl.isEmpty) {
      await _loadColabUrl();
    }
    return _colabUrl;
  }

  Future<void> setColabUrl(String colabUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('colab_url', colabUrl);
    _colabUrl = colabUrl;
  }

  Future<String> transcribeAudio(String audioFilePath, {String model = 'whisper'}) async {
    try {
      await _loadColabUrl();
      final file = File(audioFilePath);
      if (!file.existsSync()) {
        throw Exception('Audio file not found');
      }

      // Read audio file bytes
      final audioBytes = await file.readAsBytes();
      
      // Create the request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_colabUrl$_transcribeEndpoint'),
      );

      // Add headers
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      });

      // Add audio file
      final audioFile = http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'recording.wav',
      );
      request.files.add(audioFile);

      // Add form fields for transformer configuration
      request.fields['model'] = model;
      request.fields['language'] = 'en';
      request.fields['task'] = 'transcribe';
      request.fields['return_timestamps'] = 'false';
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle different response formats from Colab
        if (responseData['text'] != null) {
          return responseData['text'].toString().trim();
        } else if (responseData['transcription'] != null) {
          return responseData['transcription'].toString().trim();
        } else if (responseData['segments'] != null) {
          // Handle segment-based response
          final segments = responseData['segments'] as List;
          final fullText = segments.map((segment) => segment['text']?.toString() ?? '').join(' ');
          return fullText.trim();
        } else {
          return response.body.trim();
        }
      } else {
        String errorMessage = 'Unknown error';
        try {
          final errorBody = json.decode(response.body);
          errorMessage = errorBody['error']?.toString() ?? 
                        errorBody['message']?.toString() ?? 
                        errorBody['detail']?.toString() ?? 
                        'Unknown error';
        } catch (e) {
          errorMessage = 'HTTP ${response.statusCode}: ${response.body}';
        }
        throw Exception('Colab API Error: $errorMessage');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Network error: Unable to connect to Google Colab. Please check the URL and your internet connection.');
      } else if (e is HttpException) {
        throw Exception('HTTP error: ${e.message}');
      } else if (e is FormatException) {
        throw Exception('Response format error: The Colab server returned an invalid response format.');
      } else {
        throw Exception('Transcription failed: $e');
      }
    }
  }

  // Method for real-time transcription (if supported by Colab)
  Future<String> transcribeAudioStream(List<int> audioBytes, {String model = 'whisper'}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_colabUrl$_transcribeEndpoint'),
      );

      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      });

      final audioFile = http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: 'recording.wav',
      );
      request.files.add(audioFile);

      request.fields['model'] = model;
      request.fields['language'] = 'en';
      request.fields['streaming'] = 'true';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['text']?.toString().trim() ?? response.body.trim();
      } else {
        throw Exception('Streaming transcription failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Streaming transcription failed: $e');
    }
  }

  // Test connection to Colab instance
  Future<bool> testConnection() async {
    try {
      await _loadColabUrl();
      final response = await http.get(
        Uri.parse('$_colabUrl$_healthEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get available models from Colab
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$_colabUrl$_modelsEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['models'] != null) {
          return List<String>.from(responseData['models']);
        }
      }
      // Default models if API call fails
      return ['whisper', 'wav2vec2', 'speechbrain'];
    } catch (e) {
      return ['whisper', 'wav2vec2', 'speechbrain'];
    }
  }

  // Get server info and capabilities
  Future<Map<String, dynamic>> getServerInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_colabUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {
            'status': 'running',
            'message': 'Colab instance is running but not providing detailed info'
          };
        }
      }
      throw Exception('Server not responding');
    } catch (e) {
      throw Exception('Unable to get server info: $e');
    }
  }

  // Method to start real-time recording
  Future<bool> startRealTimeRecording() async {
    try {
      await _loadColabUrl();
      final response = await http.post(
        Uri.parse('$_colabUrl/start_recording'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to start real-time recording: $e');
    }
  }

  // Method to stop real-time recording and get transcription
  Future<String> stopRealTimeRecording() async {
    try {
      await _loadColabUrl();
      final response = await http.post(
        Uri.parse('$_colabUrl/stop_recording'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['transcription']?.toString().trim() ?? '';
      } else {
        throw Exception('Failed to stop recording: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to stop real-time recording: $e');
    }
  }

  // Method for streaming audio chunks
  Future<String> streamAudioChunk(List<int> audioBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_colabUrl/stream_transcribe'),
      );

      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      });

      final audioFile = http.MultipartFile.fromBytes(
        'audio_data',
        audioBytes,
        filename: 'chunk.wav',
      );
      request.files.add(audioFile);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['transcription']?.toString().trim() ?? '';
      } else {
        throw Exception('Streaming failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Audio streaming failed: $e');
    }
  }

  // Validate Colab URL format
  bool isValidColabUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
