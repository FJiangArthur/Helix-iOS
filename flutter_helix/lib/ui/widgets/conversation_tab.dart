// ABOUTME: Conversation tab widget for live transcription and conversation display
// ABOUTME: Shows real-time transcription, participant identification, and conversation controls

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';

class ConversationTab extends StatelessWidget {
  const ConversationTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversation'),
        actions: [
          Consumer<AppStateProvider>(
            builder: (context, appState, child) {
              return IconButton(
                icon: Icon(
                  appState.isRecording ? Icons.stop : Icons.play_arrow,
                  color: appState.isRecording ? Colors.red : null,
                ),
                onPressed: appState.readyForConversation
                    ? () => appState.toggleRecording()
                    : null,
              );
            },
          ),
        ],
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          if (!appState.readyForConversation) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing services...'),
                ],
              ),
            );
          }

          if (appState.currentConversation == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mic_none,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ready to start conversation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the microphone to begin recording',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => appState.startConversation(),
                    icon: const Icon(Icons.mic),
                    label: const Text('Start Recording'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Status indicator
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: appState.isRecording 
                    ? Colors.red.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      appState.isRecording ? Icons.fiber_manual_record : Icons.pause,
                      color: appState.isRecording ? Colors.red : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appState.isRecording ? 'Recording...' : 'Paused',
                      style: TextStyle(
                        color: appState.isRecording ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Conversation: ${appState.currentConversation!.title}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              
              // Conversation content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (appState.currentConversation!.segments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Listening for speech...',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                    else
                      ...appState.currentConversation!.segments.map(
                        (segment) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (segment.speakerId != null)
                                  Text(
                                    'Speaker ${segment.speakerId}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(segment.text),
                                const SizedBox(height: 4),
                                Text(
                                  '${segment.startTime.toString().substring(11, 19)} - ${segment.endTime.toString().substring(11, 19)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}