// ABOUTME: Comprehensive feature verification screen
// ABOUTME: Shows status of all features and allows testing each individually

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/audio_service.dart';
import '../services/implementations/audio_service_impl.dart';
import '../services/enhanced_ai_service.dart';
import '../services/analytics_service.dart';
import '../models/audio_configuration.dart';

class FeatureVerificationScreen extends StatefulWidget {
  const FeatureVerificationScreen({super.key});

  @override
  State<FeatureVerificationScreen> createState() =>
      _FeatureVerificationScreenState();
}

class _FeatureVerificationScreenState extends State<FeatureVerificationScreen> {
  final AnalyticsService _analytics = AnalyticsService.instance;

  // Feature status
  Map<String, FeatureStatus> _featureStatus = {};

  // Services
  AudioService? _audioService;
  EnhancedAIService? _aiService;

  // Test data
  String? _lastRecordingPath;
  String? _transcription;
  AIAnalysisResult? _analysisResult;

  // API Key
  String? _apiKey;
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('feature_verification');
    _initializeFeatureChecks();
  }

  Future<void> _initializeFeatureChecks() async {
    setState(() {
      _featureStatus = {
        'audio_recording': FeatureStatus(
          name: 'Audio Recording',
          status: TestStatus.pending,
          icon: Icons.mic,
        ),
        'audio_playback': FeatureStatus(
          name: 'Audio Playback',
          status: TestStatus.pending,
          icon: Icons.play_arrow,
        ),
        'whisper_transcription': FeatureStatus(
          name: 'Whisper Transcription',
          status: TestStatus.pending,
          icon: Icons.text_fields,
        ),
        'ai_analysis': FeatureStatus(
          name: 'AI Analysis',
          status: TestStatus.pending,
          icon: Icons.analytics,
        ),
        'fact_checking': FeatureStatus(
          name: 'Fact Checking',
          status: TestStatus.pending,
          icon: Icons.fact_check,
        ),
        'sentiment_analysis': FeatureStatus(
          name: 'Sentiment Analysis',
          status: TestStatus.pending,
          icon: Icons.mood,
        ),
        'action_items': FeatureStatus(
          name: 'Action Items Extraction',
          status: TestStatus.pending,
          icon: Icons.task_alt,
        ),
        'analytics_tracking': FeatureStatus(
          name: 'Analytics Tracking',
          status: TestStatus.pending,
          icon: Icons.track_changes,
        ),
      };
    });

    // Run initial checks
    await _checkAudioRecording();
    await _checkAnalytics();
  }

  Future<void> _checkAudioRecording() async {
    try {
      _audioService = AudioServiceImpl();
      final config = AudioConfiguration.speechRecognition();
      await _audioService!.initialize(config);

      final hasPermission = await _audioService!.requestPermission();

      _updateFeatureStatus(
        'audio_recording',
        hasPermission ? TestStatus.passed : TestStatus.failed,
        hasPermission
            ? 'Audio recording initialized and permission granted'
            : 'Microphone permission denied',
      );
    } catch (e) {
      _updateFeatureStatus(
        'audio_recording',
        TestStatus.failed,
        'Failed to initialize: $e',
      );
    }
  }

  Future<void> _checkAnalytics() async {
    try {
      _analytics.trackPerformance(
        metric: 'test_event',
        value: 1.0,
        unit: 'count',
      );

      final summary = _analytics.getSummary();

      _updateFeatureStatus(
        'analytics_tracking',
        TestStatus.passed,
        'Analytics working. ${summary['total_events']} events tracked',
      );
    } catch (e) {
      _updateFeatureStatus(
        'analytics_tracking',
        TestStatus.failed,
        'Analytics error: $e',
      );
    }
  }

  Future<void> _testRecording() async {
    if (_audioService == null) {
      _showError('Audio service not initialized');
      return;
    }

    try {
      _updateFeatureStatus('audio_recording', TestStatus.running, 'Recording 5 seconds of audio...');

      await _audioService!.startRecording();

      // Record for 5 seconds
      await Future.delayed(const Duration(seconds: 5));

      await _audioService!.stopRecording();
      _lastRecordingPath = _audioService!.currentRecordingPath;

      if (_lastRecordingPath != null) {
        _updateFeatureStatus(
          'audio_recording',
          TestStatus.passed,
          'Recording saved: $_lastRecordingPath',
        );
        _updateFeatureStatus(
          'audio_playback',
          TestStatus.passed,
          'Recording available for playback',
        );
      } else {
        _updateFeatureStatus(
          'audio_recording',
          TestStatus.failed,
          'Recording path is null',
        );
      }
    } catch (e) {
      _updateFeatureStatus(
        'audio_recording',
        TestStatus.failed,
        'Recording error: $e',
      );
    }
  }

  Future<void> _testTranscription() async {
    if (_apiKey == null) {
      _showError('Please set API key first');
      return;
    }

    if (_lastRecordingPath == null) {
      _showError('Please record audio first');
      return;
    }

    try {
      _aiService = EnhancedAIService(apiKey: _apiKey!);

      _updateFeatureStatus(
        'whisper_transcription',
        TestStatus.running,
        'Transcribing audio with Whisper API...',
      );

      final result = await _aiService!.transcribeAudio(_lastRecordingPath!);
      result.fold(
        (text) {
          _transcription = text;
          _updateFeatureStatus(
            'whisper_transcription',
            TestStatus.passed,
            'Transcribed: ${text.substring(0, text.length > 100 ? 100 : text.length)}...',
          );
        },
        (error) {
          _updateFeatureStatus(
            'whisper_transcription',
            TestStatus.failed,
            'Transcription failed: ${error.message}',
          );
        },
      );
    } catch (e) {
      _updateFeatureStatus(
        'whisper_transcription',
        TestStatus.failed,
        'Transcription error: $e',
      );
    }
  }

  Future<void> _testAIAnalysis() async {
    if (_aiService == null || _transcription == null) {
      _showError('Please transcribe audio first');
      return;
    }

    try {
      _updateFeatureStatus(
        'ai_analysis',
        TestStatus.running,
        'Running comprehensive AI analysis...',
      );

      _analysisResult = await _aiService!.analyzeConversation(_transcription!);

      if (_analysisResult!.success) {
        _updateFeatureStatus(
          'ai_analysis',
          TestStatus.passed,
          'Analysis completed in ${_analysisResult!.processingTime.inSeconds}s',
        );

        // Update individual feature statuses
        if (_analysisResult!.factChecks != null &&
            _analysisResult!.factChecks!.isNotEmpty) {
          _updateFeatureStatus(
            'fact_checking',
            TestStatus.passed,
            '${_analysisResult!.factChecks!.length} claims checked',
          );
        }

        if (_analysisResult!.sentiment != null) {
          _updateFeatureStatus(
            'sentiment_analysis',
            TestStatus.passed,
            'Sentiment: ${_analysisResult!.sentiment!.sentiment} (${_analysisResult!.sentiment!.score.toStringAsFixed(2)})',
          );
        }

        if (_analysisResult!.actionItems != null &&
            _analysisResult!.actionItems!.isNotEmpty) {
          _updateFeatureStatus(
            'action_items',
            TestStatus.passed,
            '${_analysisResult!.actionItems!.length} action items found',
          );
        }
      } else {
        _updateFeatureStatus(
          'ai_analysis',
          TestStatus.failed,
          _analysisResult!.error ?? 'Analysis failed',
        );
      }
    } catch (e) {
      _updateFeatureStatus(
        'ai_analysis',
        TestStatus.failed,
        'Analysis error: $e',
      );
    }
  }

  Future<void> _runAllTests() async {
    await _testRecording();
    if (_featureStatus['audio_recording']?.status == TestStatus.passed) {
      await _testTranscription();
      if (_featureStatus['whisper_transcription']?.status == TestStatus.passed) {
        await _testAIAnalysis();
      }
    }
  }

  void _updateFeatureStatus(String key, TestStatus status, String details) {
    setState(() {
      _featureStatus[key] = _featureStatus[key]!.copyWith(
        status: status,
        details: details,
        lastTested: DateTime.now(),
      );
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _setApiKey() {
    setState(() {
      _apiKey = _apiKeyController.text.trim();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API Key saved')),
    );
  }

  void _exportAnalytics() {
    final json = _analytics.exportEventsJSON();
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Analytics exported to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passedCount = _featureStatus.values.where((f) => f.status == TestStatus.passed).length;
    final failedCount = _featureStatus.values.where((f) => f.status == TestStatus.failed).length;
    final totalCount = _featureStatus.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Verification'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportAnalytics,
            tooltip: 'Export Analytics',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Test Summary',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildSummaryItem('Passed', passedCount, Colors.green),
                        _buildSummaryItem('Failed', failedCount, Colors.red),
                        _buildSummaryItem('Total', totalCount, Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(
                      value: passedCount / totalCount,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // API Key Input
            if (_apiKey == null) ...[
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.key, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'OpenAI API Key Required',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          hintText: 'sk-...',
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _setApiKey,
                        icon: const Icon(Icons.save),
                        label: const Text('Set API Key'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _runAllTests,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Run All Tests'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _initializeFeatureChecks,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Individual Test Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testRecording,
                    child: const Text('Test Recording'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testTranscription,
                    child: const Text('Test Transcription'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _testAIAnalysis,
                    child: const Text('Test AI'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Feature Status List
            const Text(
              'Feature Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._featureStatus.entries.map((entry) {
              return _buildFeatureCard(entry.key, entry.value);
            }).toList(),

            // Results Section
            if (_transcription != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Transcription Result',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_transcription!),
                ),
              ),
            ],

            if (_analysisResult != null && _analysisResult!.success) ...[
              const SizedBox(height: 24),
              _buildAnalysisResultsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  Widget _buildFeatureCard(String key, FeatureStatus feature) {
    Color statusColor;
    IconData statusIcon;

    switch (feature.status) {
      case TestStatus.passed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case TestStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case TestStatus.running:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case TestStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.radio_button_unchecked;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(feature.icon, color: statusColor),
        title: Text(feature.name),
        subtitle: feature.details != null ? Text(feature.details!) : null,
        trailing: Icon(statusIcon, color: statusColor),
      ),
    );
  }

  Widget _buildAnalysisResultsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Analysis Results',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (_analysisResult!.summary != null) ...[
              const Text('Summary:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(_analysisResult!.summary!),
              const SizedBox(height: 12),
            ],
            if (_analysisResult!.keyPoints != null) ...[
              const Text('Key Points:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._analysisResult!.keyPoints!.map((point) => Text('• $point')).toList(),
              const SizedBox(height: 12),
            ],
            if (_analysisResult!.actionItems != null) ...[
              const Text('Action Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._analysisResult!.actionItems!
                  .map((item) => Text('• [${item.priority.toUpperCase()}] ${item.task}'))
                  .toList(),
              const SizedBox(height: 12),
            ],
            if (_analysisResult!.sentiment != null) ...[
              const Text('Sentiment:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                  '${_analysisResult!.sentiment!.sentiment} (${_analysisResult!.sentiment!.score.toStringAsFixed(2)})'),
              if (_analysisResult!.sentiment!.emotions != null)
                Text('Emotions: ${_analysisResult!.sentiment!.emotions!.join(", ")}'),
              const SizedBox(height: 12),
            ],
            if (_analysisResult!.factChecks != null) ...[
              const Text('Fact Checks:', style: TextStyle(fontWeight: FontWeight.bold)),
              ..._analysisResult!.factChecks!.map((fact) {
                Color statusColor = fact.status == 'verified'
                    ? Colors.green
                    : fact.status == 'disputed'
                        ? Colors.red
                        : Colors.orange;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, size: 16, color: statusColor),
                          const SizedBox(width: 4),
                          Expanded(child: Text(fact.claim)),
                        ],
                      ),
                      Text(
                        '  ${fact.status.toUpperCase()} (${(fact.confidence * 100).toInt()}% confidence)',
                        style: TextStyle(fontSize: 12, color: statusColor),
                      ),
                      if (fact.explanation != null)
                        Text('  ${fact.explanation}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _audioService?.dispose();
    super.dispose();
  }
}

enum TestStatus { pending, running, passed, failed }

class FeatureStatus {
  final String name;
  final TestStatus status;
  final IconData icon;
  final String? details;
  final DateTime? lastTested;

  FeatureStatus({
    required this.name,
    required this.status,
    required this.icon,
    this.details,
    this.lastTested,
  });

  FeatureStatus copyWith({
    String? name,
    TestStatus? status,
    IconData? icon,
    String? details,
    DateTime? lastTested,
  }) {
    return FeatureStatus(
      name: name ?? this.name,
      status: status ?? this.status,
      icon: icon ?? this.icon,
      details: details ?? this.details,
      lastTested: lastTested ?? this.lastTested,
    );
  }
}
