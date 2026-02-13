import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:greenvoice/providers/audio_recorder_provider.dart';
import 'package:greenvoice/providers/settings_provider.dart';
import 'package:greenvoice/themes/app_theme.dart';
import 'package:greenvoice/widgets/custom_button.dart';

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> 
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _messageController = TextEditingController();
  final List<CollaborationMessage> _messages = [];
  bool _isConnected = false;
  String _sessionId = '';
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _generateSessionId();
    _generateUserName();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController.repeat(reverse: true);
  }

  void _generateSessionId() {
    setState(() {
      _sessionId = 'Session ${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    });
  }

  void _generateUserName() {
    final names = ['User Alpha', 'User Beta', 'User Gamma', 'User Delta', 'User Epsilon'];
    setState(() {
      _userName = names[DateTime.now().millisecond % names.length];
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Collaboration'),
        actions: [
          IconButton(
            icon: Icon(_isConnected ? Icons.link : Icons.link_off),
            onPressed: _toggleConnection,
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showSessionInfo,
          ),
        ],
      ),
      body: Consumer2<AudioRecorderProvider, SettingsProvider>(
        builder: (context, audioProvider, settingsProvider, child) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Session Info
                  _buildSessionInfo(),
                  
                  const SizedBox(height: 20),
                  
                  // Connection Status
                  _buildConnectionStatus(),
                  
                  const SizedBox(height: 20),
                  
                  // Messages Area
                  Expanded(
                    flex: 3,
                    child: _buildMessagesArea(settingsProvider),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Input Area
                  _buildInputArea(audioProvider, settingsProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSessionInfo() {
    return Consumer<AudioRecorderProvider>(
      builder: (context, audioProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session: $_sessionId',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'You are: $_userName',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Service: Speech-to-Text',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.circle : Icons.hourglass_empty,
            color: _isConnected ? Colors.green : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 12),
          Text(
            _isConnected ? 'Connected to session' : 'Waiting to connect...',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _isConnected ? Colors.green : Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(SettingsProvider settingsProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Transcription',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start speaking or typing!',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: settingsProvider.fontSize,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message, settingsProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(CollaborationMessage message, SettingsProvider settingsProvider) {
    final isMyMessage = message.sender == _userName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMyMessage) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.lightGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isAudio ? Icons.mic : Icons.keyboard,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMyMessage ? AppTheme.primaryGreen : Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMyMessage 
                      ? AppTheme.primaryGreen.withOpacity(0.3)
                      : Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMyMessage)
                    Text(
                      message.sender,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isMyMessage 
                            ? Colors.white 
                            : AppTheme.primaryGreen,
                      ),
                    ),
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: settingsProvider.fontSize,
                      color: isMyMessage 
                          ? Colors.white 
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMyMessage 
                          ? Colors.white70 
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isMyMessage) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(
                message.isAudio ? Icons.mic : Icons.keyboard,
                size: 16,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(AudioRecorderProvider audioProvider, SettingsProvider settingsProvider) {
    return Column(
      children: [
        // Text Input
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                  ),
                  style: TextStyle(fontSize: settingsProvider.fontSize),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _sendTextMessage(),
                color: AppTheme.primaryGreen,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: audioProvider.isRecording ? 'Stop Recording' : 'Record Message',
                icon: audioProvider.isRecording ? Icons.stop : Icons.mic,
                onPressed: () => _toggleRecording(audioProvider, settingsProvider),
                backgroundColor: audioProvider.isRecording ? Colors.red : AppTheme.primaryGreen,
              ),
            ),
            if (audioProvider.transcribedText.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  text: 'Send Audio',
                  icon: Icons.send,
                  onPressed: () => _sendAudioMessage(audioProvider),
                  backgroundColor: AppTheme.lightGreen,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  void _toggleConnection() {
    setState(() {
      _isConnected = !_isConnected;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isConnected ? 'Connected to session' : 'Disconnected from session'),
        backgroundColor: _isConnected ? Colors.green : Colors.orange,
      ),
    );
  }

  void _showSessionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Session ID: $_sessionId'),
            const SizedBox(height: 8),
            Text('Your Name: $_userName'),
            const SizedBox(height: 8),
            Text('Status: ${_isConnected ? 'Connected' : 'Disconnected'}'),
            const SizedBox(height: 16),
            const Text(
              'Share this session ID with others to collaborate in real-time.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _sessionId));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Session ID copied to clipboard!')),
              );
            },
            child: const Text('Copy ID'),
          ),
        ],
      ),
    );
  }

  void _sendTextMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = CollaborationMessage(
      sender: _userName,
      content: text,
      timestamp: DateTime.now(),
      isAudio: false,
    );

    setState(() {
      _messages.add(message);
    });
    
    _messageController.clear();
    
    // Simulate receiving a response after a delay
    if (_isConnected) {
      Future.delayed(const Duration(seconds: 2), () {
        _simulateIncomingMessage();
      });
    }
  }

  void _sendAudioMessage(AudioRecorderProvider audioProvider) {
    if (audioProvider.transcribedText.isEmpty) return;

    final message = CollaborationMessage(
      sender: _userName,
      content: audioProvider.transcribedText,
      timestamp: DateTime.now(),
      isAudio: true,
    );

    setState(() {
      _messages.add(message);
    });
    
    audioProvider.clearCurrentTranscription();
    
    // Simulate receiving a response after a delay
    if (_isConnected) {
      Future.delayed(const Duration(seconds: 2), () {
        _simulateIncomingMessage();
      });
    }
  }

  void _toggleRecording(AudioRecorderProvider audioProvider, SettingsProvider settingsProvider) async {
    if (settingsProvider.vibrationEnabled) {
      await Vibration.vibrate(duration: 50);
    }
    
    if (audioProvider.isRecording) {
      await audioProvider.stopRecording();
    } else {
      await audioProvider.startRecording();
    }
  }

  void _simulateIncomingMessage() {
    final responses = [
      'That\'s interesting! Tell me more.',
      'I understand what you\'re saying.',
      'Could you clarify that point?',
      'Thanks for sharing!',
      'I agree with your perspective.',
    ];
    
    final otherUsers = ['User Alpha', 'User Beta', 'User Gamma', 'User Delta', 'User Epsilon']
        .where((name) => name != _userName)
        .toList();
    
    final message = CollaborationMessage(
      sender: otherUsers[DateTime.now().millisecond % otherUsers.length],
      content: responses[DateTime.now().millisecond % responses.length],
      timestamp: DateTime.now(),
      isAudio: false,
    );

    setState(() {
      _messages.add(message);
    });
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

class CollaborationMessage {
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isAudio;

  CollaborationMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isAudio,
  });
}
