import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import '../services/audio_service.dart';
import '../services/implementations/audio_service_impl.dart';
import '../services/analytics_service.dart';
import '../models/audio_configuration.dart';
import 'file_management_screen.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  late AudioService _audioService;
  final AnalyticsService _analytics = AnalyticsService.instance;

  bool _isRecording = false;
  bool _isInitialized = false;
  String? _errorMessage;
  String? _currentRecordingId;
  DateTime? _recordingStartTime;
  Duration _recordingDuration = Duration.zero;
  double _audioLevel = 0.0;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<double>? _audioLevelSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAudioService();
  }

  Future<void> _initializeAudioService() async {
    try {
      _audioService = AudioServiceImpl();
      
      // Initialize with speech recognition configuration
      final config = AudioConfiguration.speechRecognition();
      await _audioService.initialize(config);
      
      // Request microphone permission
      final hasPermission = await _audioService.requestPermission();
      if (!hasPermission) {
        setState(() {
          _errorMessage = 'Microphone permission is required to record audio';
        });
        return;
      }
      
      // Subscribe to recording duration updates
      _durationSubscription = _audioService.durationStream.listen(
        (duration) {
          setState(() {
            _recordingDuration = duration;
          });
        },
      );
      
      // Subscribe to audio level updates
      _audioLevelSubscription = _audioService.audioLevelStream.listen(
        (level) {
          setState(() {
            _audioLevel = level;
          });
        },
      );
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize audio service: $e';
      });
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isInitialized) return;

    try {
      if (_isRecording) {
        // Stop recording
        await _audioService.stopRecording();

        final filePath = _audioService.currentRecordingPath;
        final duration = _recordingDuration;

        // Get file size if available
        int? fileSize;
        if (filePath != null) {
          try {
            final file = File(filePath);
            fileSize = await file.length();
          } catch (e) {
            print('Could not get file size: $e');
          }
        }

        // Track recording stopped
        if (_currentRecordingId != null && filePath != null) {
          _analytics.trackRecordingStopped(
            recordingId: _currentRecordingId!,
            duration: duration,
            filePath: filePath,
            fileSize: fileSize,
          );
        }

        setState(() {
          _isRecording = false;
          _recordingDuration = Duration.zero;
          _audioLevel = 0.0;
          _currentRecordingId = null;
          _recordingStartTime = null;
        });

        // Show success message with file path
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Recording saved: ${filePath ?? 'Unknown path'}'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Start recording
        _currentRecordingId = DateTime.now().millisecondsSinceEpoch.toString();
        _recordingStartTime = DateTime.now();

        // Track recording started
        _analytics.trackRecordingStarted(recordingId: _currentRecordingId);

        await _audioService.startRecording();
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      // Track recording error
      _analytics.trackRecordingError(error: e.toString());

      setState(() {
        _errorMessage = 'Recording failed: $e';
        _isRecording = false;
      });
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Color _getAudioLevelColor(double level) {
    if (level < 0.2) {
      return Colors.green.shade400;
    } else if (level < 0.6) {
      return Colors.orange.shade400;
    } else {
      return Colors.red.shade400;
    }
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _audioLevelSubscription?.cancel();
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_errorMessage != null) ...[
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Status Text
            Text(
              _isRecording 
                ? 'Recording...' 
                : _isInitialized 
                  ? 'Ready to Record' 
                  : 'Initializing...',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            
            // Recording Timer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _isRecording ? Colors.red.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isRecording ? Colors.red.shade300 : Colors.grey.shade300,
                ),
              ),
              child: Text(
                _formatDuration(_recordingDuration),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: _isRecording ? Colors.red.shade700 : Colors.grey.shade600,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Audio Level Indicator
            if (_isRecording) ...[
              const Text(
                'Audio Level',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: 200,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Background
                    Container(
                      width: 200,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    // Audio level fill
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: (200 * _audioLevel).clamp(0.0, 200.0),
                      height: 60,
                      decoration: BoxDecoration(
                        color: _getAudioLevelColor(_audioLevel),
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    // Center indicator
                    Positioned(
                      left: 95,
                      top: 10,
                      child: Container(
                        width: 10,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_audioLevel * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
            ] else
              const SizedBox(height: 48),
            
            // Record Button
            FloatingActionButton.large(
              onPressed: _isInitialized ? _toggleRecording : null,
              backgroundColor: _isRecording ? Colors.red : Colors.blue,
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            
            // Button Label
            Text(
              _isRecording ? 'Tap to Stop' : 'Tap to Record',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            // View Recordings Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FileManagementScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.folder),
              label: const Text('View Recordings'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
  }
}