// ABOUTME: Settings tab widget for app configuration and preferences
// ABOUTME: Allows users to configure API keys, audio settings, and app preferences

import 'package:flutter/material.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Theme Settings
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            value: false, // TODO: Connect to settings service in Phase 2
            onChanged: (value) {
              // TODO: Implement theme switching
            },
          ),
          
          const Divider(),
          
          // About
          ListTile(
            title: const Text('About'),
            subtitle: const Text('Helix v1.0.0'),
            trailing: const Icon(Icons.info_outline),
            onTap: () {
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }
  
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Helix',
      applicationVersion: '1.0.0',
      applicationLegalese: 'AI-Powered Conversation Intelligence for smart glasses.',
    );
  }
}