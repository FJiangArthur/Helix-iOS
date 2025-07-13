// ABOUTME: Conversation tab widget for live transcription and conversation display
// ABOUTME: Shows real-time transcription, participant identification, and conversation controls

import 'package:flutter/material.dart';

class ConversationTab extends StatelessWidget {
  const ConversationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              // TODO: Connect to recording service in Phase 2
            },
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Conversation Feature',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coming in Phase 2 - Service Implementation',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}