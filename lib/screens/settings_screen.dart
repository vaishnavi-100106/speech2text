import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:greenvoice/providers/settings_provider.dart';
import 'package:greenvoice/providers/theme_provider.dart';
import 'package:greenvoice/providers/audio_recorder_provider.dart';
import 'package:greenvoice/services/vnr_transformer_service.dart';
import 'package:greenvoice/themes/app_theme.dart';
import 'package:greenvoice/widgets/custom_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _vnrController = TextEditingController();
  bool _showVnrUrl = false;
  bool _vnrValid = false;

  @override
  void initState() {
    super.initState();
    _loadEndpointUrl();
  }

  Future<void> _loadEndpointUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVnrUrl = prefs.getString('vnr_url') ?? '';
    
    _vnrController.text = savedVnrUrl;
    
    setState(() {
      _vnrValid = savedVnrUrl.isNotEmpty;
    });
  }

  Future<void> _testVnrConnection() async {
    final vnrUrl = _vnrController.text.trim();
    
    if (vnrUrl.isEmpty) {
      _showErrorDialog('Please enter a VNR Transformer URL');
      return;
    }
    
    final vnrService = VNRTransformerService();
    if (!vnrService.isValidVnrUrl(vnrUrl)) {
      _showErrorDialog('Invalid VNR Transformer URL format');
      return;
    }
    
    try {
      final isConnected = await vnrService.testConnection();
      
      setState(() {
        _vnrValid = isConnected;
      });
      
      if (isConnected) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('vnr_url', vnrUrl);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('VNR Transformer connection successful!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } else {
        _showErrorDialog('VNR Transformer connection failed. Please check the URL and make sure the VNR server is running.');
      }
    } catch (e) {
      _showErrorDialog('VNR Transformer connection test failed: $e');
    }
  }

  @override
  void dispose() {
    _vnrController.dispose();
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
      title: 'Speech-to-Text Settings',
      icon: Icons.settings_voice,
      children: [
        Consumer<AudioRecorderProvider>(
          builder: (context, audioProvider, child) {
            if (audioProvider.errorMessage != null) {
              return Container(
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
            controller: _vnrController,
            obscureText: !_showVnrUrl,
            decoration: InputDecoration(
              labelText: 'Speech-to-Text Server URL',
              hintText: 'http://localhost:5000',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_showVnrUrl ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _showVnrUrl = !_showVnrUrl;
                      });
                    },
                  ),
                  if (_vnrValid)
                    const Icon(Icons.check_circle, color: AppTheme.successColor),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              final isValid = value.isNotEmpty && value.startsWith('http');
              setState(() {
                _vnrValid = isValid;
              });
            },
          ),
          
          const SizedBox(height: 12),
          
          CustomButton(
            text: 'Test Connection',
            icon: Icons.cloud_done,
            onPressed: _testVnrConnection,
            backgroundColor: AppTheme.primaryGreen,
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Configure your speech-to-text server URL. Make sure the service is accessible from your device.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
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
