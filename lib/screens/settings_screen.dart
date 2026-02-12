import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:greenvoice/providers/settings_provider.dart';
import 'package:greenvoice/providers/theme_provider.dart';
import 'package:greenvoice/providers/audio_recorder_provider.dart';
import 'package:greenvoice/services/whisper_api_service.dart';
import 'package:greenvoice/themes/app_theme.dart';
import 'package:greenvoice/widgets/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  bool _showApiKey = false;
  bool _apiKeyValid = false;

  @override
  void initState() {
    super.initState();
    _checkApiKeyStatus();
  }

  Future<void> _checkApiKeyStatus() async {
    final whisperService = WhisperApiService();
    final hasKey = await whisperService.hasApiKey();
    setState(() {
      _apiKeyValid = hasKey;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API Configuration Section
            _buildApiSection(),
            
            const SizedBox(height: 24),
            
            // Accessibility Section
            _buildAccessibilitySection(),
            
            const SizedBox(height: 24),
            
            // Appearance Section
            _buildAppearanceSection(),
            
            const SizedBox(height: 24),
            
            // Language Section
            _buildLanguageSection(),
            
            const SizedBox(height: 24),
            
            // Reset Section
            _buildResetSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiSection() {
    return _buildSection(
      title: 'API Configuration',
      icon: Icons.api,
      children: [
        Consumer<AudioRecorderProvider>(
          builder: (context, audioProvider, child) {
            if (audioProvider.errorMessage != null) {
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: AppTheme.errorColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        audioProvider.errorMessage!,
                        style: TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => audioProvider.clearError(),
                      color: AppTheme.errorColor,
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        
        TextFormField(
          controller: _apiKeyController,
          obscureText: !_showApiKey,
          decoration: InputDecoration(
            labelText: 'OpenAI API Key',
            hintText: 'sk-...',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(_showApiKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _showApiKey = !_showApiKey;
                    });
                  },
                ),
                if (_apiKeyValid)
                  const Icon(Icons.check_circle, color: AppTheme.successColor),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        CustomButton(
          text: 'Save API Key',
          icon: Icons.save,
          onPressed: _saveApiKey,
          backgroundColor: AppTheme.primaryGreen,
        ),
        
        const SizedBox(height: 8),
        
        Text(
          'Your API key is stored securely on your device and is never shared.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessibilitySection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return _buildSection(
          title: 'Accessibility',
          icon: Icons.accessibility,
          children: [
            // Font Size
            ListTile(
              title: const Text('Font Size'),
              subtitle: Text('${settingsProvider.fontSize.toInt()}px'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      settingsProvider.setFontSize(settingsProvider.fontSize - 2);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      settingsProvider.setFontSize(settingsProvider.fontSize + 2);
                    },
                  ),
                ],
              ),
            ),
            
            // High Contrast
            SwitchListTile(
              title: const Text('High Contrast'),
              subtitle: const Text('Increase text contrast for better readability'),
              value: settingsProvider.highContrast,
              onChanged: (value) {
                settingsProvider.setHighContrast(value);
              },
            ),
            
            // Vibration
            SwitchListTile(
              title: const Text('Vibration Feedback'),
              subtitle: const Text('Vibrate on record start/stop'),
              value: settingsProvider.vibrationEnabled,
              onChanged: (value) {
                settingsProvider.setVibrationEnabled(value);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildAppearanceSection() {
    return Consumer2<ThemeProvider, SettingsProvider>(
      builder: (context, themeProvider, settingsProvider, child) {
        return _buildSection(
          title: 'Appearance',
          icon: Icons.palette,
          children: [
            // Dark Mode
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Switch between light and dark theme'),
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
            ),
            
            // Auto Save
            SwitchListTile(
              title: const Text('Auto-save Transcriptions'),
              subtitle: const Text('Automatically save transcriptions to history'),
              value: settingsProvider.autoSave,
              onChanged: (value) {
                settingsProvider.setAutoSave(value);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSection() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return _buildSection(
          title: 'Language',
          icon: Icons.language,
          children: [
            ListTile(
              title: const Text('Transcription Language'),
              subtitle: Text(_getLanguageName(settingsProvider.selectedLanguage)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showLanguageDialog,
            ),
          ],
        );
      },
    );
  }

  Widget _buildResetSection() {
    return _buildSection(
      title: 'Reset',
      icon: Icons.restore,
      children: [
        CustomButton(
          text: 'Reset All Settings',
          icon: Icons.restore,
          onPressed: _showResetDialog,
          backgroundColor: AppTheme.warningColor,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _saveApiKey() async {
    final apiKey = _apiKeyController.text.trim();
    
    if (apiKey.isEmpty) {
      _showErrorDialog('Please enter an API key');
      return;
    }
    
    if (!apiKey.startsWith('sk-')) {
      _showErrorDialog('Invalid API key format. API keys should start with "sk-"');
      return;
    }
    
    try {
      final whisperService = WhisperApiService();
      await whisperService.setApiKey(apiKey);
      
      setState(() {
        _apiKeyValid = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved successfully'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      
      _apiKeyController.clear();
    } catch (e) {
      _showErrorDialog('Failed to save API key: $e');
    }
  }

  void _showLanguageDialog() {
    final languages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
    };
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: languages.entries.map((entry) {
            return RadioListTile<String>(
              title: Text(entry.value),
              value: entry.key,
              groupValue: context.read<SettingsProvider>().selectedLanguage,
              onChanged: (value) {
                if (value != null) {
                  context.read<SettingsProvider>().setLanguage(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text('Are you sure you want to reset all settings to their default values? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<SettingsProvider>().resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to defaults')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.warningColor),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String code) {
    final languages = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'it': 'Italian',
      'pt': 'Portuguese',
      'ru': 'Russian',
      'ja': 'Japanese',
      'ko': 'Korean',
      'zh': 'Chinese',
    };
    return languages[code] ?? 'English';
  }
}
