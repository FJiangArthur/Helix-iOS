// ABOUTME: Settings tab widget for app configuration and preferences
// ABOUTME: Allows users to configure API keys, audio settings, and app preferences

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return ListView(
            children: [
              // Theme Settings
              SwitchListTile(
                title: const Text('Dark Mode'),
                subtitle: const Text('Use dark theme'),
                value: appState.darkMode,
                onChanged: (value) {
                  appState.updateSettings(darkMode: value);
                },
              ),
              
              const Divider(),
              
              // Audio Settings
              ListTile(
                title: const Text('Audio Sensitivity'),
                subtitle: Text('Current: ${(appState.audioSensitivity * 100).round()}%'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showAudioSensitivityDialog(context, appState);
                },
              ),
              
              const Divider(),
              
              // Service Status
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Service Status',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildServiceStatusItem('Audio Service', appState.audioServiceReady),
              _buildServiceStatusItem('Transcription Service', appState.transcriptionServiceReady),
              _buildServiceStatusItem('LLM Service', appState.llmServiceReady),
              _buildServiceStatusItem('Glasses Service', appState.glassesServiceReady),
              _buildServiceStatusItem('Settings Service', appState.settingsServiceReady),
              
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
          );
        },
      ),
    );
  }
  
  Widget _buildServiceStatusItem(String title, bool isReady) {
    return ListTile(
      title: Text(title),
      trailing: Icon(
        isReady ? Icons.check_circle : Icons.error,
        color: isReady ? Colors.green : Colors.red,
      ),
    );
  }
  
  void _showAudioSensitivityDialog(BuildContext context, AppStateProvider appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio Sensitivity'),
        content: StatefulBuilder(
          builder: (context, setState) {
            double sensitivity = appState.audioSensitivity;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Sensitivity: ${(sensitivity * 100).round()}%'),
                Slider(
                  value: sensitivity,
                  onChanged: (value) {
                    setState(() {
                      sensitivity = value;
                    });
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Update sensitivity
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
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
      applicationLegalese: '© 2024 Even Realities',
      children: [
        const Text('AI-Powered Conversation Intelligence for smart glasses.'),
      ],
    );
  }
}