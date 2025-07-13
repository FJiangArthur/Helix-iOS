// ABOUTME: Analysis tab widget for displaying AI-powered conversation insights
// ABOUTME: Shows fact-checking results, summaries, and analysis from LLM services

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state_provider.dart';

class AnalysisTab extends StatelessWidget {
  const AnalysisTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis'),
      ),
      body: Consumer<AppStateProvider>(
        builder: (context, appState, child) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text(
                  'Analysis Coming Soon',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'AI-powered conversation insights',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}