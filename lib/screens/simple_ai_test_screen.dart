// ABOUTME: Simple test screen to verify OpenAI integration works
// ABOUTME: Record -> Transcribe -> Analyze - the simplest possible flow

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../services/audio_service.dart';
import '../services/implementations/audio_service_impl.dart';
import '../services/simple_openai_service.dart';
import '../services/analytics_service.dart';
import '../models/audio_configuration.dart';

class SimpleAITestScreen extends StatefulWidget {
  const SimpleAITestScreen({super.key});

  @override
  State<SimpleAITestScreen> createState() => _SimpleAITestScreenState();
}

class _SimpleAITestScreenState extends State<SimpleAITestScreen> {
  late AudioService _audioService;
  SimpleOpenAIService? _openAIService;
  final AnalyticsService _analytics = AnalyticsService.instance;

  bool _isRecording = false;
  bool _isTranscribing = false;
  bool _isAnalyzing = false;
  bool _isInitialized = false;

  String? _errorMessage;
  String? _transcription;
  String? _analysis;
  String? _lastRecordingPath;
  String? _currentRecordingId;

  Duration _recordingDuration = Duration.zero;
  StreamSubscription<Duration>? _durationSubscription;

  // TODO: Replace with actual API key from settings
  static const String _openAIApiKey = 'YOUR_OPENAI_API_KEY_HERE';

  @override
  void initState() {
    super.initState();
    _analytics.trackScreenView('simple_ai_test');
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize audio service
      _audioService = AudioServiceImpl();
      final config = AudioConfiguration.speechRecognition();
      await _audioService.initialize(config);

      final hasPermission = await _audioService.requestPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Microphone permission required';
        });
        return;
      }

      // Initialize OpenAI service
      if (_openAIApiKey != 'YOUR_OPENAI_API_KEY_HERE') {
        _openAIService = SimpleOpenAIService(apiKey: _openAIApiKey);

        // Validate API key
        final isValid = await _openAIService!.validateApiKey();
        if (!isValid) {
          setState(() {
            _errorMessage = 'Invalid OpenAI API key';
            _openAIService = null;
          });
          return;
        }
      }

      // Subscribe to recording duration
      _durationSubscription = _audioService.durationStream.listen(
        (duration) {
          if (mounted) {
            setState(() {
              _recordingDuration = duration;
            });
          }
        },
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized) return;

    try {
      if (_isRecording) {
        // Stop recording
        await _audioService.stopRecording();
        _lastRecordingPath = _audioService.currentRecordingPath;

        // Track recording stopped
        if (_currentRecordingId != null && _lastRecordingPath != null) {
          int? fileSize;
          try {
            final file = File(_lastRecordingPath!);
            fileSize = await file.length();
          } catch (e) {
            print('Could not get file size: $e');
          }

          _analytics.trackRecordingStopped(
            recordingId: _currentRecordingId!,
            duration: _recordingDuration,
            filePath: _lastRecordingPath!,
            fileSize: fileSize,
          );
        }

        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
        });

        // Auto-start transcription if API key is configured
        if (_openAIService != null && _lastRecordingPath != null) {
          await _transcribeRecording();
        } else if (_openAIService == null) {
          setState(() {
            _errorMessage = 'OpenAI API key not configured. Please add your API key to the code.';
          });
        }
      } else {
        // Start recording - clear previous results
        _currentRecordingId = DateTime.now().millisecondsSinceEpoch.toString();

        // Track recording started
        _analytics.trackRecordingStarted(recordingId: _currentRecordingId);

        setState(() {
          _transcription = null;
          _analysis = null;
          _errorMessage = null;
        });

        await _audioService.startRecording();
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      // Track error
      _analytics.trackRecordingError(error: e.toString());

      setState(() {
        _errorMessage = 'Recording error: $e';
      });
    }
  }

  Future<void> _transcribeRecording() async {
    if (_openAIService == null || _lastRecordingPath == null) return;

    setState(() {
      _isTranscribing = true;
      _errorMessage = null;
    });

    try {
      print('[Test] Starting transcription for: $_lastRecordingPath');
      final transcription = await _openAIService!.transcribeAudio(_lastRecordingPath!);

      setState(() {
        _transcription = transcription;
        _isTranscribing = false;
      });

      // Auto-start analysis
      await _analyzeTranscription();
    } catch (e) {
      setState(() {
        _errorMessage = 'Transcription failed: $e';
        _isTranscribing = false;
      });
    }
  }

  Future<void> _analyzeTranscription() async {
    if (_openAIService == null || _transcription == null) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      print('[Test] Starting analysis');
      final analysis = await _openAIService!.analyzeText(_transcription!);

      setState(() {
        _analysis = analysis;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Analysis failed: $e';
        _isAnalyzing = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simple AI Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      _isRecording ? Icons.mic : Icons.mic_none,
                      size: 48,
                      color: _isRecording ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecording ? 'Recording...' : 'Ready',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(_recordingDuration),
                      style: const TextStyle(fontSize: 32, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Record Button
            ElevatedButton.icon(
              onPressed: _isInitialized && !_isTranscribing && !_isAnalyzing
                  ? _toggleRecording
                  : null,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop Recording' : 'Start Recording'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isRecording ? Colors.red : Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),

            // Error Message
            if (_errorMessage != null) ...[
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Transcription Status
            if (_isTranscribing) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Transcribing with Whisper API...'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Transcription Result
            if (_transcription != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.text_fields, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Transcription',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        _transcription!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Analysis Status
            if (_isAnalyzing) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Analyzing with ChatGPT...'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Analysis Result
            if (_analysis != null) ...[
              Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'AI Analysis',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Text(
                        _analysis!,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // API Key Warning
            if (_openAIService == null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'OpenAI API Key Required',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please add your OpenAI API key in lib/screens/simple_ai_test_screen.dart line 24',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
