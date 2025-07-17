// ABOUTME: Enhanced conversation tab with real-time transcription display
// ABOUTME: Features recording controls, live transcription, speaker identification, and audio levels

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';

import '../../services/audio_service.dart';
import '../../services/service_locator.dart';
import '../../models/audio_configuration.dart';

class ConversationTab extends StatefulWidget {
  const ConversationTab({super.key});

  @override
  State<ConversationTab> createState() => _ConversationTabState();
}

class _ConversationTabState extends State<ConversationTab> with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  double _audioLevel = 0.0;
  late AnimationController _waveController;
  late AnimationController _pulseController;
  
  // AudioService integration
  late AudioService _audioService;
  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<bool>? _voiceActivitySubscription;
  
  // Recording timer
  Stopwatch _recordingStopwatch = Stopwatch();
  Timer? _timerUpdateTimer;
  Duration _recordingDuration = Duration.zero;
  
  final List<TranscriptionSegment> _transcriptSegments = [
    TranscriptionSegment(
      speaker: 'You',
      text: 'Welcome to Helix! This is a demo of real-time conversation transcription.',
      timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
      confidence: 0.95,
    ),
    TranscriptionSegment(
      speaker: 'Speaker 2',
      text: 'The AI analysis features look impressive. How accurate is the fact-checking?',
      timestamp: DateTime.now().subtract(const Duration(seconds: 15)),
      confidence: 0.88,
    ),
    TranscriptionSegment(
      speaker: 'You',
      text: 'Our fact-checking uses multiple AI providers for high accuracy and confidence scoring.',
      timestamp: DateTime.now().subtract(const Duration(seconds: 5)),
      confidence: 0.92,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _initializeAudioService();
  }
  
  Future<void> _initializeAudioService() async {
    try {
      _audioService = ServiceLocator.instance.get<AudioService>();
      
      // Initialize with default configuration
      final config = AudioConfiguration(
        sampleRate: 16000,
        channels: 1,
        quality: AudioQuality.medium,
      );
      
      await _audioService.initialize(config);
      
      // Subscribe to audio level stream
      _audioLevelSubscription = _audioService.audioLevelStream.listen((level) {
        if (mounted) {
          setState(() {
            _audioLevel = level;
          });
        }
      });
      
    } catch (e) {
      debugPrint('Failed to initialize AudioService: $e');
    }
  }

  @override
  void dispose() {
    _audioLevelSubscription?.cancel();
    _voiceActivitySubscription?.cancel();
    _timerUpdateTimer?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _simulateAudioLevels() {
    // Simulate varying audio levels for demo purposes
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_isRecording && mounted) {
        setState(() {
          _audioLevel = (0.3 + (0.7 * (DateTime.now().millisecondsSinceEpoch % 1000) / 1000));
        });
        _simulateAudioLevels();
      }
    });
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        // Stop recording
        await _audioService.stopRecording();
        _recordingStopwatch.stop();
        _timerUpdateTimer?.cancel();
        _pulseController.stop();
        
        setState(() {
          _isRecording = false;
          _isPaused = false;
          _audioLevel = 0.0;
        });
      } else {
        // Request permission first
        if (!_audioService.hasPermission) {
          final granted = await _audioService.requestPermission();
          if (!granted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission required for recording')),
            );
            return;
          }
        }
        
        // Start recording
        await _audioService.startRecording();
        _recordingStopwatch.reset();
        _recordingStopwatch.start();
        _startTimerUpdates();
        _pulseController.repeat();
        
        setState(() {
          _isRecording = true;
          _isPaused = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording error: $e')),
      );
    }
  }
  
  void _startTimerUpdates() {
    _timerUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted && _isRecording) {
        setState(() {
          _recordingDuration = _recordingStopwatch.elapsed;
        });
      }
    });
  }
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    
    if (_isPaused) {
      _pulseController.stop();
    } else {
      _pulseController.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Conversation'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // TODO: Open recording settings
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              // TODO: Share transcript
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Modern Recording Status Bar
          Container(
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isRecording 
                ? theme.colorScheme.errorContainer.withOpacity(0.1)
                : theme.colorScheme.surface,
              border: _isRecording 
                ? Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.error.withOpacity(0.3),
                      width: 1,
                    ),
                  )
                : null,
            ),
            child: Row(
              children: [
                // Recording Status
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording 
                          ? Colors.red.withOpacity(0.8 + 0.2 * _pulseController.value)
                          : theme.colorScheme.outline,
                      ),
                      child: Icon(
                        _isRecording 
                          ? (_isPaused ? Icons.pause : Icons.mic)
                          : Icons.mic_off,
                        color: Colors.white,
                        size: 24,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                
                // Audio Level Bars
                Expanded(
                  child: _isRecording ? AudioLevelBars(level: _audioLevel) : Container(),
                ),
                
                // Duration
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _formatDuration(_recordingDuration),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Transcription Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: _transcriptSegments.isEmpty
                ? _buildEmptyState(theme)
                : _buildTranscriptList(theme),
            ),
          ),
          
          // Control Panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Secondary Actions
                  IconButton(
                    onPressed: () {
                      // TODO: Open conversation history
                    },
                    icon: const Icon(Icons.history),
                    iconSize: 28,
                  ),
                  
                  // Pause/Resume (only when recording)
                  if (_isRecording)
                    IconButton(
                      onPressed: _togglePause,
                      icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                      iconSize: 32,
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.secondaryContainer,
                        foregroundColor: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                  
                  // Modern Record Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleRecording,
                      borderRadius: BorderRadius.circular(36),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isRecording 
                            ? theme.colorScheme.error 
                            : theme.colorScheme.primary,
                          boxShadow: _isRecording ? [
                            BoxShadow(
                              color: theme.colorScheme.error.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ] : null,
                        ),
                        child: Icon(
                          _isRecording ? Icons.stop : Icons.mic,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  
                  // AI Analysis Toggle
                  IconButton(
                    onPressed: () {
                      // TODO: Toggle AI analysis
                    },
                    icon: const Icon(Icons.psychology),
                    iconSize: 28,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.graphic_eq,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            'Ready to Record',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the microphone to start live transcription',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptList(ThemeData theme) {
    return ListView.builder(
      itemCount: _transcriptSegments.length,
      itemBuilder: (context, index) {
        final segment = _transcriptSegments[index];
        final isCurrentUser = segment.speaker == 'You';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Speaker Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: isCurrentUser 
                  ? theme.colorScheme.primary 
                  : theme.colorScheme.secondary,
                child: Text(
                  segment.speaker[0],
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Message Bubble
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          segment.speaker,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(segment.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        ConfidenceBadge(confidence: segment.confidence),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrentUser
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        segment.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isCurrentUser
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Helper Models
class TranscriptionSegment {
  final String speaker;
  final String text;
  final DateTime timestamp;
  final double confidence;

  TranscriptionSegment({
    required this.speaker,
    required this.text,
    required this.timestamp,
    required this.confidence,
  });
}

// Custom Widgets
class AudioLevelBars extends StatelessWidget {
  final double level;

  const AudioLevelBars({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(20, (index) {
        final barHeight = 4.0 + (level * 20 * (index / 20));
        return Container(
          width: 3,
          height: barHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.7 + 0.3 * (level)),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class ConfidenceBadge extends StatelessWidget {
  final double confidence;

  const ConfidenceBadge({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final confidencePercent = (confidence * 100).round();
    
    Color badgeColor;
    if (confidence >= 0.9) {
      badgeColor = Colors.green;
    } else if (confidence >= 0.7) {
      badgeColor = Colors.orange;
    } else {
      badgeColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        '$confidencePercent%',
        style: theme.textTheme.labelSmall?.copyWith(
          color: badgeColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}