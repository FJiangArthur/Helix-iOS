// ABOUTME: Glasses tab widget for managing Even Realities smart glasses connection
// ABOUTME: Shows connection status, device info, and HUD controls

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';

class GlassesTab extends StatelessWidget {
  const GlassesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Glasses'),
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(
                          Icons.glasses,
                          size: 48,
                          color: appState.glassesConnected 
                              ? Colors.green 
                              : Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          appState.glassesConnected 
                              ? 'Connected' 
                              : 'Disconnected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: appState.glassesConnected 
                                ? Colors.green 
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!appState.glassesConnected)
                          ElevatedButton(
                            onPressed: () => appState.connectToGlasses(),
                            child: const Text('Connect to Glasses'),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => appState.disconnectFromGlasses(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            child: const Text('Disconnect'),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Advanced glasses features coming soon',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}