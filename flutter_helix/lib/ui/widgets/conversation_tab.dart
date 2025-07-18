// ABOUTME: Enhanced conversation tab with real-time transcription display
// ABOUTME: Features recording controls, live transcription, speaker identification, and audio levels

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

import '../../services/audio_service.dart';
import '../../services/implementations/audio_service_impl.dart';
import '../../services/conversation_storage_service.dart';
import '../../services/service_locator.dart';
import '../../models/audio_configuration.dart';
import '../../models/conversation_model.dart';
import '../../models/transcription_segment.dart';
import '../../services/transcription_service.dart';
import 'package:permission_handler/permission_handler.dart';

class ConversationTab extends StatefulWidget {
  final VoidCallback? onHistoryTap;
  
  const ConversationTab({super.key, this.onHistoryTap});

  @override
  State<ConversationTab> createState() => _ConversationTabState();
}

class _ConversationTabState extends State<ConversationTab> with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  bool _isProcessingRecordingToggle = false;
  double _audioLevel = 0.0;
  late AnimationController _waveController;
  late AnimationController _pulseController;
  
  // Service integration
  late AudioService _audioService;
  late ConversationStorageService _storageService;
  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<bool>? _voiceActivitySubscription;
  StreamSubscription<Duration>? _recordingDurationSubscription;
  
  // Current conversation state
  String? _currentConversationId;
  
  // Recording timer
  Timer? _timerUpdateTimer;
  Duration _recordingDuration = Duration.zero;
  
  final List<TranscriptionSegment> _transcriptSegments = [
    TranscriptionSegment(
      text: 'Welcome to Helix! This is a demo of real-time conversation transcription.',
      startTime: DateTime.now().subtract(const Duration(seconds: 30)),
      endTime: DateTime.now().subtract(const Duration(seconds: 27)),
      confidence: 0.95,
      speakerId: 'user_1',
      speakerName: 'You',
      language: 'en-US',
      backend: TranscriptionBackend.device,
      segmentId: 'demo_1',
    ),
    TranscriptionSegment(
      text: 'The AI analysis features look impressive. How accurate is the fact-checking?',
      startTime: DateTime.now().subtract(const Duration(seconds: 15)),
      endTime: DateTime.now().subtract(const Duration(seconds: 12)),
      confidence: 0.88,
      speakerId: 'speaker_2',
      speakerName: 'Speaker 2',
      language: 'en-US',
      backend: TranscriptionBackend.device,
      segmentId: 'demo_2',
    ),
    TranscriptionSegment(
      text: 'Our fact-checking uses multiple AI providers for high accuracy and confidence scoring.',
      startTime: DateTime.now().subtract(const Duration(seconds: 5)),
      endTime: DateTime.now().subtract(const Duration(seconds: 2)),
      confidence: 0.92,
      speakerId: 'user_1',
      speakerName: 'You',
      language: 'en-US',
      backend: TranscriptionBackend.device,
      segmentId: 'demo_3',
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
      _storageService = ServiceLocator.instance.get<ConversationStorageService>();
      
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
      
      // Subscribe to recording duration stream
      _recordingDurationSubscription = _audioService.recordingDurationStream.listen((duration) {
        if (mounted) {
          setState(() {
            _recordingDuration = duration;
          });
        }
      });
      
      // Check initial permission status
      _checkInitialPermissionStatus();
      
    } catch (e) {
      debugPrint('Failed to initialize AudioService: $e');
    }
  }
  
  Future<void> _checkInitialPermissionStatus() async {
    try {
      final audioServiceImpl = _audioService as AudioServiceImpl;
      final status = await audioServiceImpl.checkPermissionStatus();
      
      debugPrint('Initial microphone permission status: ${status.name}');
      
      // Update UI based on permission status if needed
      if (mounted) {
        setState(() {
          // Permission status is already updated in the service
        });
      }
    } catch (e) {
      debugPrint('Failed to check initial permission status: $e');
    }
  }

  @override
  void dispose() {
    _audioLevelSubscription?.cancel();
    _voiceActivitySubscription?.cancel();
    _recordingDurationSubscription?.cancel();
    _timerUpdateTimer?.cancel();
    _waveController.dispose();
    _pulseController.dispose();
    super.dispose();
  }


  String _generateConversationId() {
    // Simple UUID-like ID generator
    final random = math.Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(999999);
    return 'conv_${timestamp}_$randomPart';
  }

  Future<void> _toggleRecording() async {
    // Prevent multiple simultaneous calls
    if (_isProcessingRecordingToggle) return;
    _isProcessingRecordingToggle = true;
    
    try {
      if (_isRecording) {
        debugPrint('Stopping recording...');
        
        try {
          await _audioService.stopRecording();
          _pulseController.stop();
          
          // Create and save conversation
          await _saveCurrentConversation();
          
          setState(() {
            _isRecording = false;
            _isPaused = false;
            _audioLevel = 0.0;
          });
          
          // Clear current conversation state
          _currentConversationId = null;
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recording stopped and saved'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error stopping recording: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to stop recording: $e')),
            );
          }
        }
      } else {
        debugPrint('Starting recording...');
        
        // Request permission first
        if (!_audioService.hasPermission) {
          final granted = await _audioService.requestPermission();
          if (!granted) {
            if (mounted) {
              // Check if permission was permanently denied
              final audioServiceImpl = _audioService as AudioServiceImpl;
              final status = await audioServiceImpl.checkPermissionStatus();
              
              debugPrint('Permission request failed with status: ${status.name}');
              
              if (status == PermissionStatus.permanentlyDenied) {
                // Show dialog to guide user to settings
                _showPermissionPermanentlyDeniedDialog();
              } else {
                String message = 'Microphone permission required for recording';
                if (status == PermissionStatus.restricted) {
                  message = 'Microphone access is restricted (parental controls)';
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            }
            return;
          } else {
            debugPrint('Microphone permission granted successfully');
          }
        }
        
        try {
          // Generate conversation ID and start recording
          _currentConversationId = _generateConversationId();
          await _audioService.startConversationRecording(_currentConversationId!);
          _pulseController.repeat();
          
          setState(() {
            _isRecording = true;
            _isPaused = false;
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recording started'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error starting recording: $e');
          _currentConversationId = null;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to start recording: $e')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Unexpected error in recording toggle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    } finally {
      _isProcessingRecordingToggle = false;
    }
  }

  Future<void> _saveCurrentConversation() async {
    if (_currentConversationId == null) {
      debugPrint('Cannot save conversation: No conversation ID');
      return;
    }
    
    try {
      debugPrint('Saving conversation: $_currentConversationId');
      
      // Create conversation from current transcription segments
      final conversation = ConversationModel(
        id: _currentConversationId!,
        title: 'Conversation ${DateTime.now().toLocal().toString().split(' ')[0]}',
        startTime: DateTime.now().subtract(_recordingDuration),
        endTime: DateTime.now(),
        lastUpdated: DateTime.now(),
        participants: [
          const ConversationParticipant(
            id: 'user_1',
            name: 'You',
            isOwner: true,
          ),
          const ConversationParticipant(
            id: 'speaker_2',
            name: 'Speaker 2',
            isOwner: false,
          ),
        ],
        segments: _transcriptSegments,
      );
      
      await _storageService.saveConversation(conversation);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation saved')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save conversation: $e')),
      );
    }
  }
  
  
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
  
  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Microphone Permission Required'),
          content: const Text(
            'Recording requires microphone access. Since permission was permanently denied, '
            'please enable microphone access in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final audioServiceImpl = _audioService as AudioServiceImpl;
                await audioServiceImpl.openPermissionSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
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
                    onPressed: widget.onHistoryTap,
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
        final isCurrentUser = segment.speakerId == 'user_1';
        final speakerName = segment.speakerName ?? 'Unknown';
        
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
                  speakerName[0],
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
                          speakerName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(segment.startTime),
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


// Custom Widgets
class AudioLevelBars extends StatelessWidget {
  final double level;

  const AudioLevelBars({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(20, (index) {
        // Create a more realistic waveform by varying bar heights based on position
        final normalizedIndex = index / 20.0;
        final baseHeight = 4.0;
        final maxHeight = 28.0;
        
        // Create a wave-like pattern that responds to audio level
        final waveMultiplier = (0.5 + 0.5 * (1.0 - (normalizedIndex - 0.5).abs() * 2)).clamp(0.0, 1.0);
        final barHeight = baseHeight + (level * maxHeight * waveMultiplier);
        
        // Add some randomness for more realistic appearance
        final randomVariation = (index % 3) * 0.1;
        final finalHeight = (barHeight + randomVariation).clamp(baseHeight, maxHeight);
        
        return Container(
          width: 3,
          height: finalHeight,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: level > 0.1 
              ? Colors.green.withOpacity(0.7 + 0.3 * level)
              : Colors.grey.withOpacity(0.3),
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