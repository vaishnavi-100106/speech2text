import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:greenvoice/services/vnr_transformer_service.dart';
import 'package:greenvoice/services/storage_service.dart';

class AudioRecorderProvider extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final VNRTransformerService _vnrService = VNRTransformerService();
  final StorageService _storageService = StorageService();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  String _transcribedText = '';
  String _currentFilePath = '';
  List<Map<String, dynamic>> _transcriptionHistory = [];
  String? _errorMessage;

  // Getters
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  String get transcribedText => _transcribedText;
  String get currentFilePath => _currentFilePath;
  List<Map<String, dynamic>> get transcriptionHistory => _transcriptionHistory;
  String? get errorMessage => _errorMessage;

  AudioRecorderProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      _transcriptionHistory = await _storageService.getTranscriptionHistory();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load history: $e');
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      final microphoneStatus = await Permission.microphone.request();
      final storageStatus = await Permission.storage.request();
      
      return microphoneStatus == PermissionStatus.granted && 
             storageStatus == PermissionStatus.granted;
    } catch (e) {
      _setError('Permission request failed: $e');
      return false;
    }
  }

  Future<void> startRecording() async {
    try {
      if (_isRecording) return;
      
      // Clear previous errors
      _errorMessage = null;
      
      // Request permissions
      final hasPermissions = await _requestPermissions();
      if (!hasPermissions) {
        _setError('Microphone and storage permissions are required');
        return;
      }

      // Vibrate to indicate recording start
      await Vibration.vibrate(duration: 100);

      // Start recording
      final directory = await _storageService.getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentFilePath = '$directory/recording_$timestamp.wav';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          bitRate: 128000,
        ),
        path: _currentFilePath,
      );

      _isRecording = true;
      notifyListeners();
    } catch (e) {
      _setError('Failed to start recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      if (!_isRecording) return;

      // Vibrate to indicate recording stop
      await Vibration.vibrate(duration: 100);

      // Stop recording
      final path = await _recorder.stop();
      _currentFilePath = path ?? _currentFilePath;
      _isRecording = false;
      
      notifyListeners();

      // Start transcription
      await _transcribeAudio();
    } catch (e) {
      _isRecording = false;
      _setError('Failed to stop recording: $e');
      notifyListeners();
    }
  }

  Future<void> _transcribeAudio() async {
    try {
      _isProcessing = true;
      _errorMessage = null;
      notifyListeners();

      String transcription;
      
      // Always use the speech-to-text service
      transcription = await _vnrService.transcribeAudio(_currentFilePath);
      
      _transcribedText = transcription;
      
      // Save to history
      await _saveToHistory(transcription);
      
      _isProcessing = false;
      notifyListeners();
    } catch (e) {
      _isProcessing = false;
      _setError('Transcription failed: $e');
      notifyListeners();
    }
  }

  Future<void> _saveToHistory(String text) async {
    try {
      final transcription = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
        'audioPath': _currentFilePath,
      };
      
      await _storageService.saveTranscription(transcription);
      _transcriptionHistory.insert(0, transcription);
      
      // Keep only last 100 transcriptions
      if (_transcriptionHistory.length > 100) {
        _transcriptionHistory = _transcriptionHistory.take(100).toList();
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to save transcription: $e');
    }
  }

  Future<void> playRecording() async {
    try {
      if (_currentFilePath.isEmpty) return;
      await _player.play(DeviceFileSource(_currentFilePath));
    } catch (e) {
      _setError('Failed to play recording: $e');
    }
  }

  Future<void> deleteTranscription(String id) async {
    try {
      await _storageService.deleteTranscription(id);
      _transcriptionHistory.removeWhere((item) => item['id'] == id);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete transcription: $e');
    }
  }

  Future<void> clearHistory() async {
    try {
      await _storageService.clearTranscriptionHistory();
      _transcriptionHistory.clear();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear history: $e');
    }
  }

  void clearCurrentTranscription() {
    _transcribedText = '';
    _currentFilePath = '';
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> testConnection() async {
    try {
      // Always test the speech-to-text service connection
      return await _vnrService.testConnection();
    } catch (e) {
      _setError('Connection test failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }
}
