import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:greenvoice/providers/audio_recorder_provider.dart';
import 'package:greenvoice/providers/settings_provider.dart';
import 'package:greenvoice/themes/app_theme.dart';
import 'package:greenvoice/widgets/custom_button.dart';
import 'package:greenvoice/widgets/transcription_display.dart';
import 'package:greenvoice/screens/history_screen.dart';
import 'package:greenvoice/screens/settings_screen.dart';
import 'package:greenvoice/screens/collaboration_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> 
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('GreenVoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CollaborationScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
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
                  // Status Section
                  _buildStatusSection(audioProvider),
                  
                  const SizedBox(height: 30),
                  
                  // Microphone Button
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: _buildMicrophoneButton(audioProvider, settingsProvider),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Transcription Display
                  Expanded(
                    flex: 3,
                    child: TranscriptionDisplay(
                      text: audioProvider.transcribedText,
                      fontSize: settingsProvider.fontSize,
                      highContrast: settingsProvider.highContrast,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Action Buttons
                  _buildActionButtons(audioProvider, settingsProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(AudioRecorderProvider audioProvider) {
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (audioProvider.isRecording) {
      statusText = 'Recording...';
      statusColor = Colors.red;
      statusIcon = Icons.fiber_manual_record;
    } else if (audioProvider.isProcessing) {
      statusText = 'Processing...';
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    } else if (audioProvider.transcribedText.isNotEmpty) {
      statusText = 'Transcription Complete';
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle;
    } else {
      statusText = 'Ready to Record';
      statusColor = AppTheme.primaryGreen;
      statusIcon = Icons.mic_none;
    }

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
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicrophoneButton(AudioRecorderProvider audioProvider, SettingsProvider settingsProvider) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: audioProvider.isRecording ? _pulseAnimation.value : 1.0,
          child: GestureDetector(
            onTap: () async {
              if (settingsProvider.vibrationEnabled) {
                await Vibration.vibrate(duration: 50);
              }
              
              if (audioProvider.isRecording) {
                await audioProvider.stopRecording();
              } else {
                await audioProvider.startRecording();
              }
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: audioProvider.isRecording 
                    ? Colors.red 
                    : audioProvider.isProcessing 
                        ? Colors.orange 
                        : AppTheme.primaryGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (audioProvider.isRecording 
                        ? Colors.red 
                        : AppTheme.primaryGreen).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: audioProvider.isRecording ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                audioProvider.isRecording ? Icons.stop : Icons.mic,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(AudioRecorderProvider audioProvider, SettingsProvider settingsProvider) {
    if (audioProvider.transcribedText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: CustomButton(
            text: 'Share',
            icon: Icons.share,
            onPressed: () async {
              if (audioProvider.transcribedText.isNotEmpty) {
                // For web, we'll copy to clipboard instead
                await Clipboard.setData(ClipboardData(text: audioProvider.transcribedText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Text copied to clipboard!')),
                );
              }
            },
            backgroundColor: AppTheme.lightGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CustomButton(
            text: 'Clear',
            icon: Icons.clear,
            onPressed: () {
              audioProvider.clearCurrentTranscription();
            },
            backgroundColor: AppTheme.warningColor,
          ),
        ),
        if (audioProvider.currentFilePath.isNotEmpty) ...[
          const SizedBox(width: 12),
          Expanded(
            child: CustomButton(
              text: 'Play',
              icon: Icons.play_arrow,
              onPressed: () {
                audioProvider.playRecording();
              },
              backgroundColor: AppTheme.primaryGreen,
            ),
          ),
        ],
      ],
    );
  }
}
