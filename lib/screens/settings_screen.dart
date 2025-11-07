import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSettingsSection(
            title: 'Audio Settings',
            icon: Icons.mic_none,
            children: [
              _buildSwitchTile(
                title: 'High Quality Recording',
                subtitle: '48kHz sampling rate for better quality',
                value: true,
                icon: Icons.high_quality,
              ),
              _buildSwitchTile(
                title: 'Noise Cancellation',
                subtitle: 'Reduce background noise in recordings',
                value: true,
                icon: Icons.noise_control_off,
              ),
              _buildSliderTile(
                title: 'Voice Activity Detection',
                subtitle: 'Sensitivity level',
                value: 0.7,
                icon: Icons.graphic_eq,
              ),
              _buildListTile(
                title: 'Audio Format',
                subtitle: 'WAV (Lossless)',
                icon: Icons.audiotrack,
                onTap: () => _showAudioFormatDialog(context),
              ),
            ],
          ),
          
          _buildSettingsSection(
            title: 'AI Configuration',
            icon: Icons.psychology,
            children: [
              _buildListTile(
                title: 'Default AI Model',
                subtitle: 'GPT-4 Turbo',
                icon: Icons.model_training,
                onTap: () => _showModelSelectionDialog(context),
              ),
              _buildSliderTile(
                title: 'Response Speed',
                subtitle: 'Balance between speed and accuracy',
                value: 0.5,
                icon: Icons.speed,
              ),
              _buildSwitchTile(
                title: 'Auto-summarize',
                subtitle: 'Automatically generate conversation summaries',
                value: true,
                icon: Icons.summarize,
              ),
              _buildListTile(
                title: 'API Keys',
                subtitle: 'Manage provider credentials',
                icon: Icons.key,
                onTap: () => _showApiKeysDialog(context),
              ),
            ],
          ),
          
          _buildSettingsSection(
            title: 'Privacy & Security',
            icon: Icons.security,
            children: [
              _buildSwitchTile(
                title: 'Local Processing',
                subtitle: 'Process data on device when possible',
                value: false,
                icon: Icons.phone_android,
              ),
              _buildSwitchTile(
                title: 'Auto-delete Recordings',
                subtitle: 'Remove after 30 days',
                value: false,
                icon: Icons.auto_delete,
              ),
              _buildListTile(
                title: 'Data Encryption',
                subtitle: 'AES-256 enabled',
                icon: Icons.lock,
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
              _buildListTile(
                title: 'Export Data',
                subtitle: 'Download all your data',
                icon: Icons.download,
                onTap: () => _showExportDialog(context),
              ),
            ],
          ),
          
          _buildSettingsSection(
            title: 'Glasses Configuration',
            icon: Icons.visibility,
            children: [
              _buildSwitchTile(
                title: 'Auto-connect',
                subtitle: 'Connect to glasses when in range',
                value: true,
                icon: Icons.bluetooth_connected,
              ),
              _buildSliderTile(
                title: 'HUD Brightness',
                subtitle: 'Display brightness level',
                value: 0.8,
                icon: Icons.brightness_6,
              ),
              _buildListTile(
                title: 'Display Mode',
                subtitle: 'Minimal',
                icon: Icons.dashboard_customize,
                onTap: () => _showDisplayModeDialog(context),
              ),
              _buildSwitchTile(
                title: 'Gesture Control',
                subtitle: 'Enable touch gestures on glasses',
                value: true,
                icon: Icons.gesture,
              ),
            ],
          ),
          
          _buildSettingsSection(
            title: 'App Preferences',
            icon: Icons.tune,
            children: [
              _buildListTile(
                title: 'Theme',
                subtitle: 'System default',
                icon: Icons.palette,
                onTap: () => _showThemeDialog(context),
              ),
              _buildListTile(
                title: 'Language',
                subtitle: 'English',
                icon: Icons.language,
                onTap: () => _showLanguageDialog(context),
              ),
              _buildSwitchTile(
                title: 'Notifications',
                subtitle: 'Receive app notifications',
                value: true,
                icon: Icons.notifications,
              ),
              _buildListTile(
                title: 'Storage',
                subtitle: '2.3 GB used',
                icon: Icons.storage,
                trailing: TextButton(
                  onPressed: () => _showStorageDialog(context),
                  child: const Text('Manage'),
                ),
              ),
            ],
          ),
          
          _buildSettingsSection(
            title: 'About',
            icon: Icons.info_outline,
            children: [
              _buildListTile(
                title: 'Version',
                subtitle: '1.0.0 (Build 42)',
                icon: Icons.info,
              ),
              _buildListTile(
                title: 'Terms of Service',
                subtitle: 'View terms and conditions',
                icon: Icons.description,
                onTap: () {},
              ),
              _buildListTile(
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                icon: Icons.privacy_tip,
                onTap: () {},
              ),
              _buildListTile(
                title: 'Send Feedback',
                subtitle: 'Help us improve',
                icon: Icons.feedback,
                onTap: () => _showFeedbackDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 80), // Space for bottom navigation
        ],
      ),
    );
  }

  Widget _buildSettingsSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          elevation: 1,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildListTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required IconData icon,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return ListTile(
          leading: Icon(icon, size: 24),
          title: Text(title),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: Switch(
            value: value,
            onChanged: (newValue) {
              setState(() {
                // In a real app, this would update the actual setting
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required IconData icon,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        return ListTile(
          leading: Icon(icon, size: 24),
          title: Text(title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle, style: const TextStyle(fontSize: 12)),
              Slider(
                value: value,
                onChanged: (newValue) {
                  setState(() {
                    // In a real app, this would update the actual setting
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAudioFormatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Audio Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('WAV (Lossless)'),
              leading: const Radio(value: 0, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('MP3 (Compressed)'),
              leading: const Radio(value: 1, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('AAC (Efficient)'),
              leading: const Radio(value: 2, groupValue: 0, onChanged: null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showModelSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select AI Model'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('GPT-4 Turbo'),
              subtitle: const Text('Most capable'),
              leading: const Radio(value: 0, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('GPT-3.5'),
              subtitle: const Text('Faster responses'),
              leading: const Radio(value: 1, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('Claude 3'),
              subtitle: const Text('Balanced performance'),
              leading: const Radio(value: 2, groupValue: 0, onChanged: null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showApiKeysDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('API Keys'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'OpenAI API Key',
                hintText: 'sk-...',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Anthropic API Key',
                hintText: 'sk-ant-...',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: const Text('Export all your conversation data and settings?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data export started')),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showDisplayModeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Minimal'),
              subtitle: const Text('Essential information only'),
              leading: const Radio(value: 0, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('Standard'),
              subtitle: const Text('Balanced information'),
              leading: const Radio(value: 1, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('Detailed'),
              subtitle: const Text('All available information'),
              leading: const Radio(value: 2, groupValue: 0, onChanged: null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('System'),
              leading: const Radio(value: 0, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('Light'),
              leading: const Radio(value: 1, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('Dark'),
              leading: const Radio(value: 2, groupValue: 0, onChanged: null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: const Radio(value: 0, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('Spanish'),
              leading: const Radio(value: 1, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('French'),
              leading: const Radio(value: 2, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('German'),
              leading: const Radio(value: 3, groupValue: 0, onChanged: null),
            ),
            ListTile(
              title: const Text('Chinese'),
              leading: const Radio(value: 4, groupValue: 0, onChanged: null),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showStorageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Storage Management'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Audio Recordings'),
              subtitle: const Text('1.8 GB'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Clear'),
              ),
            ),
            ListTile(
              title: const Text('Transcriptions'),
              subtitle: const Text('256 MB'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Clear'),
              ),
            ),
            ListTile(
              title: const Text('Cache'),
              subtitle: const Text('244 MB'),
              trailing: TextButton(
                onPressed: () {},
                child: const Text('Clear'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TextField(
              decoration: InputDecoration(
                labelText: 'Subject',
                hintText: 'Brief description',
              ),
            ),
            const SizedBox(height: 16),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Feedback',
                hintText: 'Your feedback helps us improve',
              ),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}