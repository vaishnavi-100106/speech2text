import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VNRTransformerService {
  late String _vnrUrl;
  static const String _transcribeEndpoint = '/transcribe';
  static const String _healthEndpoint = '/health';
  static const String _modelsEndpoint = '/models';
  static const String _startRecordingEndpoint = '/start_recording';
  static const String _stopRecordingEndpoint = '/stop_recording';
  static const String _streamTranscribeEndpoint = '/stream_transcribe';
  
  VNRTransformerService() {
    _loadVnrUrl();
  }

  Future<void> _loadVnrUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _vnrUrl = prefs.getString('vnr_url') ?? 'http://localhost:5000';
  }

  Future<String> getVnrUrl() async {
    if (_vnrUrl.isEmpty) {
      await _loadVnrUrl();
    }
    return _vnrUrl;
  }

  Future<void> setVnrUrl(String vnrUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vnr_url', vnrUrl);
    _vnrUrl = vnrUrl;
  }

  Future<String> transcribeAudio(String audioFilePath, {String model = 'wav2vec2'}) async {
    try {
      await _loadVnrUrl();
      final file = File(audioFilePath);
      if (!file.existsSync()) {
        throw Exception('Audio file not found');
      }

      // Read audio file bytes
      final audioBytes = await file.readAsBytes();
      
      // Create the request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_vnrUrl$_transcribeEndpoint'),
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

      // Add form fields for Wav2Vec2 configuration
      request.fields['model'] = model;
      request.fields['language'] = 'en';
      request.fields['features'] = 'noise_reduction';
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // Handle different response formats from VNR server
        if (responseData['text'] != null) {
          return responseData['text'].toString().trim();
        } else if (responseData['transcription'] != null) {
          return responseData['transcription'].toString().trim();
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
        throw Exception('VNR Server Error: $errorMessage');
      }
    } catch (e) {
      if (e is SocketException) {
        throw Exception('Network error: Unable to connect to VNR server. Please check the URL and your internet connection.');
      } else if (e is HttpException) {
        throw Exception('HTTP error: ${e.message}');
      } else if (e is FormatException) {
        throw Exception('Response format error: The VNR server returned an invalid response format.');
      } else {
        throw Exception('Wav2Vec2 transcription failed: $e');
      }
    }
  }

  // Method for real-time transcription (VNR special feature)
  Future<String> transcribeAudioStream(List<int> audioBytes, {String model = 'wav2vec2'}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_vnrUrl$_streamTranscribeEndpoint'),
      );

      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      });

      final audioFile = http.MultipartFile.fromBytes(
        'audio_data',
        audioBytes,
        filename: 'recording.wav',
      );
      request.files.add(audioFile);

      request.fields['model'] = model;
      request.fields['language'] = 'en';

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['transcription']?.toString().trim() ?? response.body.trim();
      } else {
        throw Exception('Wav2Vec2 streaming transcription failed: ${response.body}');
      }
    } catch (e) {
      throw Exception('Wav2Vec2 streaming transcription failed: $e');
    }
  }

  // Test connection to VNR Transformer
  Future<bool> testConnection() async {
    try {
      await _loadVnrUrl();
      final response = await http.get(
        Uri.parse('$_vnrUrl$_healthEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Get available models from VNR
  Future<List<String>> getAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$_vnrUrl$_modelsEndpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['models'] != null) {
          return List<String>.from(responseData['models']);
        }
      }
      // Default Wav2Vec2 models if API call fails
      return ['wav2vec2'];
    } catch (e) {
      return ['wav2vec2'];
    }
  }

  // Get server info and capabilities
  Future<Map<String, dynamic>> getServerInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$_vnrUrl/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (e) {
          return {
            'status': 'running',
            'message': 'VNR Transformer is running but not providing detailed info'
          };
        }
      }
      throw Exception('VNR server not responding');
    } catch (e) {
      throw Exception('Unable to get VNR server info: $e');
    }
  }

  // Method to start real-time recording (VNR special feature)
  Future<bool> startRealTimeRecording() async {
    try {
      await _loadVnrUrl();
      final response = await http.post(
        Uri.parse('$_vnrUrl$_startRecordingEndpoint'),
        headers: {'Content-Type': 'application/json'},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Failed to start VNR real-time recording: $e');
    }
  }

  // Method to stop real-time recording and get transcription
  Future<String> stopRealTimeRecording() async {
    try {
      await _loadVnrUrl();
      final response = await http.post(
        Uri.parse('$_vnrUrl$_stopRecordingEndpoint'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['transcription']?.toString().trim() ?? '';
      } else {
        throw Exception('Failed to stop VNR recording: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to stop VNR real-time recording: $e');
    }
  }

  // Check if the VNR URL is accessible
  Future<bool> isUrlAccessible(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme) {
        return false;
      }
      
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }

  // Validate VNR URL format
  bool isValidVnrUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
