import 'package:flutter/material.dart';
import 'package:greenvoice/themes/app_theme.dart';

class TranscriptionDisplay extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool highContrast;

  const TranscriptionDisplay({
    super.key,
    required this.text,
    required this.fontSize,
    required this.highContrast,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return _buildEmptyState(context);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppTheme.primaryGreen.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.text_fields,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Transcription',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  height: 1.6,
                  color: highContrast 
                      ? Colors.black 
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: highContrast ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Word count and character count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatChip(
                context,
                '${text.split(' ').length} words',
                Icons.text_fields,
              ),
              _buildStatChip(
                context,
                '${text.length} characters',
                Icons.text_rotation_none,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 60,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No transcription yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the microphone button to start recording',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
