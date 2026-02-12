import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
// import 'package:share_plus/share_plus.dart';
import 'package:greenvoice/providers/audio_recorder_provider.dart';
import 'package:greenvoice/providers/settings_provider.dart';
import 'package:greenvoice/themes/app_theme.dart';
import 'package:greenvoice/widgets/custom_button.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          Consumer<AudioRecorderProvider>(
            builder: (context, audioProvider, child) {
              if (audioProvider.transcriptionHistory.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'clear_all') {
                    _showClearAllDialog(audioProvider);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear All'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<AudioRecorderProvider, SettingsProvider>(
        builder: (context, audioProvider, settingsProvider, child) {
          if (audioProvider.transcriptionHistory.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              // Summary Card
              _buildSummaryCard(audioProvider.transcriptionHistory.length),
              
              const SizedBox(height: 16),
              
              // History List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: audioProvider.transcriptionHistory.length,
                  itemBuilder: (context, index) {
                    final transcription = audioProvider.transcriptionHistory[index];
                    return _buildTranscriptionCard(
                      transcription,
                      audioProvider,
                      settingsProvider,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: AppTheme.primaryGreen.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No History Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start recording to see your transcriptions here',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int count) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.analytics,
              color: AppTheme.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Transcriptions',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionCard(
    Map<String, dynamic> transcription,
    AudioRecorderProvider audioProvider,
    SettingsProvider settingsProvider,
  ) {
    final timestamp = DateTime.parse(transcription['timestamp']);
    final formattedDate = DateFormat('MMM dd, yyyy').format(timestamp);
    final formattedTime = DateFormat('hh:mm a').format(timestamp);
    final text = transcription['text'] as String;
    final id = transcription['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            Text(
              formattedTime,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        subtitle: Text(
          text.length > 50 ? '${text.substring(0, 50)}...' : text,
          style: TextStyle(
            fontSize: settingsProvider.fontSize,
            color: settingsProvider.highContrast 
                ? Colors.black 
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Full Transcription:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: settingsProvider.fontSize,
                    color: settingsProvider.highContrast 
                        ? Colors.black 
                        : Theme.of(context).colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        text: 'Share',
                        icon: Icons.share,
                        onPressed: () {
                          // For web, we'll copy to clipboard instead
                          Clipboard.setData(ClipboardData(text: text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Text copied to clipboard!')),
                          );
                        },
                        backgroundColor: AppTheme.lightGreen,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CustomButton(
                        text: 'Delete',
                        icon: Icons.delete,
                        onPressed: () {
                          _showDeleteDialog(id, audioProvider);
                        },
                        backgroundColor: AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String id, AudioRecorderProvider audioProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transcription'),
        content: const Text('Are you sure you want to delete this transcription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              audioProvider.deleteTranscription(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transcription deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(AudioRecorderProvider audioProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History'),
        content: const Text('Are you sure you want to delete all transcriptions? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              audioProvider.clearHistory();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All history cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}
