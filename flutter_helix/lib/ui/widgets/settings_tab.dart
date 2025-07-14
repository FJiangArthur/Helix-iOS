// ABOUTME: Comprehensive settings interface with categorized options
// ABOUTME: Full-featured settings management for API keys, audio, AI, privacy, and app preferences

import 'package:flutter/material.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  // Theme Settings
  bool _isDarkMode = false;
  bool _useSystemTheme = true;
  
  // AI Settings
  String _currentLLMProvider = 'openai';
  double _analysisConfidenceThreshold = 0.8;
  bool _enableFactChecking = true;
  bool _enableSentimentAnalysis = true;
  bool _enableActionItemExtraction = true;
  
  // Audio Settings
  double _audioQuality = 1.0; // 0.0 = low, 0.5 = medium, 1.0 = high
  bool _enableNoiseReduction = true;
  bool _enableAutoGainControl = true;
  double _microphoneSensitivity = 0.7;
  
  // Privacy Settings
  bool _enableDataCollection = false;
  bool _enableCrashReporting = true;
  bool _enableUsageAnalytics = false;
  String _dataRetentionPeriod = '30 days';
  
  // Glasses Settings
  double _hudBrightness = 0.7;
  String _hudPosition = 'center';
  bool _enableHapticFeedback = true;
  bool _enableAudioAlerts = false;
  
  // Notification Settings
  bool _enablePushNotifications = true;
  bool _enableFactCheckAlerts = true;
  bool _enableActionItemReminders = true;
  
  final TextEditingController _openaiKeyController = TextEditingController();
  final TextEditingController _anthropicKeyController = TextEditingController();
  
  @override
  void dispose() {
    _openaiKeyController.dispose();
    _anthropicKeyController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: _showResetDialog,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAISettingsCard(theme),
          const SizedBox(height: 16),
          _buildAudioSettingsCard(theme),
          const SizedBox(height: 16),
          _buildGlassesSettingsCard(theme),
          const SizedBox(height: 16),
          _buildPrivacySettingsCard(theme),
          const SizedBox(height: 16),
          _buildNotificationSettingsCard(theme),
          const SizedBox(height: 16),
          _buildAppearanceSettingsCard(theme),
          const SizedBox(height: 16),
          _buildAboutCard(theme),
        ],
      ),
    );
  }
  
  Widget _buildAISettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI & Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // API Keys Section
            Text(
              'API Configuration',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            // OpenAI API Key
            TextField(
              controller: _openaiKeyController,
              decoration: InputDecoration(
                labelText: 'OpenAI API Key',
                hintText: 'sk-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _showAPIKeyHelp('OpenAI'),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            
            // Anthropic API Key
            TextField(
              controller: _anthropicKeyController,
              decoration: InputDecoration(
                labelText: 'Anthropic API Key',
                hintText: 'sk-ant-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _showAPIKeyHelp('Anthropic'),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            
            // LLM Provider Selection
            DropdownButtonFormField<String>(
              value: _currentLLMProvider,
              decoration: const InputDecoration(
                labelText: 'Default AI Provider',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'openai', child: Text('OpenAI GPT')),
                DropdownMenuItem(value: 'anthropic', child: Text('Anthropic AI')),
                DropdownMenuItem(value: 'auto', child: Text('Auto Select')),
              ],
              onChanged: (value) {
                setState(() {
                  _currentLLMProvider = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Analysis Features
            Text(
              'Analysis Features',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            
            SwitchListTile(
              title: const Text('Fact Checking'),
              subtitle: const Text('Real-time claim verification'),
              value: _enableFactChecking,
              onChanged: (value) {
                setState(() {
                  _enableFactChecking = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Sentiment Analysis'),
              subtitle: const Text('Conversation mood detection'),
              value: _enableSentimentAnalysis,
              onChanged: (value) {
                setState(() {
                  _enableSentimentAnalysis = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Action Item Extraction'),
              subtitle: const Text('Automatic task identification'),
              value: _enableActionItemExtraction,
              onChanged: (value) {
                setState(() {
                  _enableActionItemExtraction = value;
                });
              },
            ),
            
            // Confidence Threshold
            ListTile(
              title: const Text('Analysis Confidence Threshold'),
              subtitle: Text('${(_analysisConfidenceThreshold * 100).round()}% minimum confidence'),
            ),
            Slider(
              value: _analysisConfidenceThreshold,
              min: 0.5,
              max: 1.0,
              divisions: 10,
              label: '${(_analysisConfidenceThreshold * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _analysisConfidenceThreshold = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAudioSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Audio Recording',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Audio Quality
            ListTile(
              title: const Text('Recording Quality'),
              subtitle: Text(_getAudioQualityLabel(_audioQuality)),
            ),
            Slider(
              value: _audioQuality,
              min: 0.0,
              max: 1.0,
              divisions: 2,
              label: _getAudioQualityLabel(_audioQuality),
              onChanged: (value) {
                setState(() {
                  _audioQuality = value;
                });
              },
            ),
            
            // Microphone Sensitivity
            ListTile(
              title: const Text('Microphone Sensitivity'),
              subtitle: Text('${(_microphoneSensitivity * 100).round()}%'),
            ),
            Slider(
              value: _microphoneSensitivity,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${(_microphoneSensitivity * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _microphoneSensitivity = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Noise Reduction'),
              subtitle: const Text('Filter background noise'),
              value: _enableNoiseReduction,
              onChanged: (value) {
                setState(() {
                  _enableNoiseReduction = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Auto Gain Control'),
              subtitle: const Text('Automatic volume adjustment'),
              value: _enableAutoGainControl,
              onChanged: (value) {
                setState(() {
                  _enableAutoGainControl = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGlassesSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.remove_red_eye, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Smart Glasses',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // HUD Brightness
            ListTile(
              title: const Text('HUD Brightness'),
              subtitle: Text('${(_hudBrightness * 100).round()}%'),
            ),
            Slider(
              value: _hudBrightness,
              min: 0.1,
              max: 1.0,
              divisions: 9,
              label: '${(_hudBrightness * 100).round()}%',
              onChanged: (value) {
                setState(() {
                  _hudBrightness = value;
                });
              },
            ),
            
            // HUD Position
            DropdownButtonFormField<String>(
              value: _hudPosition,
              decoration: const InputDecoration(
                labelText: 'HUD Position',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'top', child: Text('Top')),
                DropdownMenuItem(value: 'center', child: Text('Center')),
                DropdownMenuItem(value: 'bottom', child: Text('Bottom')),
              ],
              onChanged: (value) {
                setState(() {
                  _hudPosition = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Haptic Feedback'),
              subtitle: const Text('Vibration for notifications'),
              value: _enableHapticFeedback,
              onChanged: (value) {
                setState(() {
                  _enableHapticFeedback = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Audio Alerts'),
              subtitle: const Text('Sound notifications'),
              value: _enableAudioAlerts,
              onChanged: (value) {
                setState(() {
                  _enableAudioAlerts = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPrivacySettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Privacy & Data',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Data Collection'),
              subtitle: const Text('Allow anonymous usage data collection'),
              value: _enableDataCollection,
              onChanged: (value) {
                setState(() {
                  _enableDataCollection = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Crash Reporting'),
              subtitle: const Text('Help improve app stability'),
              value: _enableCrashReporting,
              onChanged: (value) {
                setState(() {
                  _enableCrashReporting = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Usage Analytics'),
              subtitle: const Text('Anonymous feature usage tracking'),
              value: _enableUsageAnalytics,
              onChanged: (value) {
                setState(() {
                  _enableUsageAnalytics = value;
                });
              },
            ),
            
            // Data Retention
            DropdownButtonFormField<String>(
              value: _dataRetentionPeriod,
              decoration: const InputDecoration(
                labelText: 'Data Retention Period',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '7 days', child: Text('7 days')),
                DropdownMenuItem(value: '30 days', child: Text('30 days')),
                DropdownMenuItem(value: '90 days', child: Text('90 days')),
                DropdownMenuItem(value: '1 year', child: Text('1 year')),
                DropdownMenuItem(value: 'forever', child: Text('Keep forever')),
              ],
              onChanged: (value) {
                setState(() {
                  _dataRetentionPeriod = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            Center(
              child: TextButton(
                onPressed: _showPrivacyPolicy,
                child: const Text('View Privacy Policy'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNotificationSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Notifications',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('General app notifications'),
              value: _enablePushNotifications,
              onChanged: (value) {
                setState(() {
                  _enablePushNotifications = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Fact Check Alerts'),
              subtitle: const Text('Notifications for disputed claims'),
              value: _enableFactCheckAlerts,
              onChanged: _enablePushNotifications ? (value) {
                setState(() {
                  _enableFactCheckAlerts = value;
                });
              } : null,
            ),
            
            SwitchListTile(
              title: const Text('Action Item Reminders'),
              subtitle: const Text('Reminders for pending tasks'),
              value: _enableActionItemReminders,
              onChanged: _enablePushNotifications ? (value) {
                setState(() {
                  _enableActionItemReminders = value;
                });
              } : null,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAppearanceSettingsCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Appearance',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('Use System Theme'),
              subtitle: const Text('Follow device theme settings'),
              value: _useSystemTheme,
              onChanged: (value) {
                setState(() {
                  _useSystemTheme = value;
                });
              },
            ),
            
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Use dark theme'),
              value: _isDarkMode,
              onChanged: _useSystemTheme ? null : (value) {
                setState(() {
                  _isDarkMode = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAboutCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'About',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            ListTile(
              title: const Text('Version'),
              subtitle: const Text('1.0.0 (Build 1)'),
              trailing: const Icon(Icons.info_outline),
              onTap: _showAboutDialog,
            ),
            
            ListTile(
              title: const Text('Licenses'),
              subtitle: const Text('Open source licenses'),
              trailing: const Icon(Icons.article),
              onTap: _showLicensePage,
            ),
            
            ListTile(
              title: const Text('Help & Support'),
              subtitle: const Text('Get help and support'),
              trailing: const Icon(Icons.help),
              onTap: _showHelpDialog,
            ),
            
            ListTile(
              title: const Text('Feedback'),
              subtitle: const Text('Send feedback and suggestions'),
              trailing: const Icon(Icons.feedback),
              onTap: _showFeedbackDialog,
            ),
          ],
        ),
      ),
    );
  }
  
  String _getAudioQualityLabel(double quality) {
    if (quality <= 0.33) return 'Low (8kHz)';
    if (quality <= 0.66) return 'Medium (16kHz)';
    return 'High (44.1kHz)';
  }
  
  void _showAPIKeyHelp(String provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$provider API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To use $provider services, you need an API key:'),
            const SizedBox(height: 12),
            if (provider == 'OpenAI') ...[
              const Text('• Visit https://platform.openai.com'),
              const Text('• Create an account or sign in'),
              const Text('• Go to API Keys section'),
              const Text('• Create a new secret key'),
            ] else ...[
              const Text('• Visit https://console.anthropic.com'),
              const Text('• Create an account or sign in'),
              const Text('• Go to API Keys section'),
              const Text('• Generate a new API key'),
            ],
            const SizedBox(height: 12),
            const Text(
              'Your API key is stored securely on your device and never shared.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to Defaults'),
        content: const Text(
          'This will reset all settings to their default values. Your API keys will be cleared. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetToDefaults();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
  
  void _resetToDefaults() {
    setState(() {
      _isDarkMode = false;
      _useSystemTheme = true;
      _currentLLMProvider = 'openai';
      _analysisConfidenceThreshold = 0.8;
      _enableFactChecking = true;
      _enableSentimentAnalysis = true;
      _enableActionItemExtraction = true;
      _audioQuality = 1.0;
      _enableNoiseReduction = true;
      _enableAutoGainControl = true;
      _microphoneSensitivity = 0.7;
      _enableDataCollection = false;
      _enableCrashReporting = true;
      _enableUsageAnalytics = false;
      _dataRetentionPeriod = '30 days';
      _hudBrightness = 0.7;
      _hudPosition = 'center';
      _enableHapticFeedback = true;
      _enableAudioAlerts = false;
      _enablePushNotifications = true;
      _enableFactCheckAlerts = true;
      _enableActionItemReminders = true;
    });
    
    _openaiKeyController.clear();
    _anthropicKeyController.clear();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings reset to defaults'),
      ),
    );
  }
  
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Helix',
      applicationVersion: '1.0.0',
      applicationLegalese: 'AI-Powered Conversation Intelligence for smart glasses.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Helix transforms conversations into actionable insights using advanced AI analysis, real-time fact-checking, and seamless integration with Even Realities smart glasses.',
        ),
      ],
    );
  }
  
  void _showLicensePage() {
    showLicensePage(
      context: context,
      applicationName: 'Helix',
      applicationVersion: '1.0.0',
      applicationLegalese: 'AI-Powered Conversation Intelligence for smart glasses.',
    );
  }
  
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Text(
            'Helix Privacy Policy\n\n'
            'Data Collection:\n'
            'We collect only the data necessary to provide our services. Audio recordings are processed locally when possible and are never stored without your explicit consent.\n\n'
            'AI Processing:\n'
            'Conversation data may be sent to AI providers (OpenAI, Anthropic) for analysis. These services have their own privacy policies.\n\n'
            'Data Storage:\n'
            'Your data is stored securely on your device. Cloud sync is optional and encrypted.\n\n'
            'For the complete privacy policy, visit: https://helix.example.com/privacy',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Getting Started:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Add your AI provider API keys in the AI settings'),
            Text('• Connect your Even Realities smart glasses'),
            Text('• Start a conversation to see real-time analysis'),
            SizedBox(height: 16),
            Text('Troubleshooting:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Check microphone permissions'),
            Text('• Ensure Bluetooth is enabled for glasses'),
            Text('• Verify your API keys are valid'),
            SizedBox(height: 16),
            Text('Contact: support@helix.example.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showFeedbackDialog() {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We love hearing from you! Share your thoughts, suggestions, or report issues.'),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                labelText: 'Your feedback',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Send feedback
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thank you for your feedback!'),
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}