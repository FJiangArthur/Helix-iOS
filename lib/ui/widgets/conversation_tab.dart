// ABOUTME: Enhanced conversation tab with real-time transcription display
// ABOUTME: Features recording controls, live transcription, speaker identification, and audio levels

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import '../../services/audio_service.dart';
import '../../services/implementations/audio_service_impl.dart';
import '../../services/conversation_storage_service.dart';
import '../../services/service_locator.dart';
import '../../models/audio_configuration.dart';
import '../../models/conversation_model.dart';
import '../../models/transcription_segment.dart';
import '../../services/transcription_service.dart';
import '../../services/real_time_transcription_service.dart';
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
  final List<double> _audioLevelHistory = [];
  late AnimationController _waveController;
  late AnimationController _pulseController;
  
  // Service integration
  late AudioService _audioService;
  late ConversationStorageService _storageService;
  late RealTimeTranscriptionService _transcriptionPipelineService;
  StreamSubscription<double>? _audioLevelSubscription;
  StreamSubscription<bool>? _voiceActivitySubscription;
  StreamSubscription<Duration>? _recordingDurationSubscription;
  StreamSubscription<TranscriptionSegment>? _transcriptionSubscription;
  StreamSubscription<TranscriptionSegment>? _partialTranscriptionSubscription;
  
  // Current conversation state
  String? _currentConversationId;
  
  // Recording timer
  Timer? _timerUpdateTimer;
  Duration _recordingDuration = Duration.zero;
  
  // Dynamic transcription segments populated by real-time transcription
  final List<TranscriptionSegment> _transcriptSegments = [];
  TranscriptionSegment? _currentPartialSegment;

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
      _transcriptionPipelineService = ServiceLocator.instance.get<RealTimeTranscriptionService>();
      
      final audioConfig = AudioConfiguration.speechRecognition().copyWith(
        enableRealTimeStreaming: true,
        vadThreshold: 0.01,
        chunkDurationMs: 100, // Optimized for real-time transcription
      );
      
      await _audioService.initialize(audioConfig);
      
      // Initialize transcription pipeline
      const transcriptionConfig = TranscriptionPipelineConfig(
        audioChunkDurationMs: 100,
        targetLatencyMs: 200, // Target 200ms for word-by-word updates
        enablePartialResults: true,
        maxBufferedSegments: 500,
      );
      await _transcriptionPipelineService.initialize(transcriptionConfig);
      
      await _checkInitialPermissionStatus();
      
      // Set up audio level subscription for real-time waveform
      _audioLevelSubscription = _audioService.audioLevelStream.listen(
        (level) {
          if (mounted && _isRecording) {
            setState(() {
              _audioLevel = level;
              // Keep history for smoother waveform
              _audioLevelHistory.add(level);
              if (_audioLevelHistory.length > 50) {
                _audioLevelHistory.removeAt(0);
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Audio level stream error: $error');
        },
      );
      
      // Set up voice activity subscription
      _voiceActivitySubscription = _audioService.voiceActivityStream.listen(
        (isActive) {
          if (mounted && _isRecording) {
            // Could add voice activity indicator here
            debugPrint('Voice activity: $isActive');
          }
        },
      );
      
      // Set up recording duration subscription
      _recordingDurationSubscription = _audioService.recordingDurationStream.listen(
        (duration) {
          if (mounted && _isRecording) {
            setState(() {
              _recordingDuration = duration;
            });
          }
        },
      );
      
      // Set up real-time transcription subscriptions
      _transcriptionSubscription = _transcriptionPipelineService.transcriptionStream.listen(
        (segment) {
          if (mounted) {
            setState(() {
              // Add final transcription segments to the list
              if (segment.isFinal) {
                _transcriptSegments.add(segment);
                _currentPartialSegment = null; // Clear partial segment
                
                // Keep list manageable (last 100 segments)
                if (_transcriptSegments.length > 100) {
                  _transcriptSegments.removeAt(0);
                }
              }
            });
          }
        },
        onError: (error) {
          debugPrint('Transcription stream error: $error');
        },
      );
      
      _partialTranscriptionSubscription = _transcriptionPipelineService.partialTranscriptionStream.listen(
        (segment) {
          if (mounted) {
            setState(() {
              // Update current partial segment for immediate UI feedback
              _currentPartialSegment = segment;
            });
          }
        },
        onError: (error) {
          debugPrint('Partial transcription stream error: $error');
        },
      );
      
      debugPrint('AudioService and transcription pipeline initialized successfully');
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
    _transcriptionSubscription?.cancel();
    _partialTranscriptionSubscription?.cancel();
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
      // Ensure AudioService is initialized
      if (_audioService == null) {
        debugPrint('AudioService not initialized, initializing now...');
        await _initializeAudioService();
        if (_audioService == null) {
          throw Exception('Failed to initialize AudioService');
        }
      }
      if (_isRecording) {
        debugPrint('Stopping recording...');
        
        try {
          // Stop transcription pipeline first
          await _transcriptionPipelineService.stopTranscription();
          _pulseController.stop();
          
          // Create and save conversation
          await _saveCurrentConversation();
          
          setState(() {
            _isRecording = false;
            _isPaused = false;
            _audioLevel = 0.0;
            _currentPartialSegment = null;
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
        
        // Always check current permission status first
        final audioServiceImpl = _audioService as AudioServiceImpl;
        final currentStatus = await audioServiceImpl.checkPermissionStatus();
        debugPrint('Current permission status: ${currentStatus.name}');
        
        if (currentStatus != PermissionStatus.granted && 
            currentStatus != PermissionStatus.limited && 
            currentStatus != PermissionStatus.provisional) {
                // Only skip requesting if permanently denied - go straight to settings
          if (currentStatus == PermissionStatus.permanentlyDenied) {
            debugPrint('Permission permanently denied, showing settings dialog');
            _showPermissionPermanentlyDeniedDialog();
            return;
          }
          
          debugPrint('Requesting microphone permission...');
          final granted = await _audioService.requestPermission();
          debugPrint('Permission request result: $granted');
          
          if (!granted) {
            if (mounted) {
              // Re-check status after request
              final newStatus = await audioServiceImpl.checkPermissionStatus();
              debugPrint('Permission request failed with final status: ${newStatus.name}');
              
              if (newStatus == PermissionStatus.permanentlyDenied || newStatus == PermissionStatus.denied) {
                // Show dialog to guide user to settings
                _showPermissionPermanentlyDeniedDialog();
              } else {
                String message = 'Microphone permission required for recording';
                if (newStatus == PermissionStatus.restricted) {
                  message = 'Microphone access is restricted (parental controls)';
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Retry',
                      onPressed: () => _toggleRecording(),
                    ),
                  ),
                );
              }
            }
            return;
          } else {
            debugPrint('Microphone permission granted successfully');
          }
        } else {
          debugPrint('Microphone permission already available: ${currentStatus.name}');
        }
        
        try {
          // Generate conversation ID and start recording with transcription
          _currentConversationId = _generateConversationId();
          
          // Start the real-time transcription pipeline
          await _transcriptionPipelineService.startTranscription(
            language: 'en-US',
            preferredBackend: TranscriptionBackend.device,
          );
          
          _pulseController.repeat();
          
          setState(() {
            _isRecording = true;
            _isPaused = false;
            // Clear previous transcription data
            _transcriptSegments.clear();
            _currentPartialSegment = null;
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
      
      // Get the audio file path from the AudioService
      String? audioFilePath;
      String? audioFormat;
      int? audioFileSize;
      
      // Get the actual recording file path from AudioService
      audioFilePath = _audioService.currentRecordingPath;
      if (audioFilePath != null) {
        audioFormat = audioFilePath.split('.').last;
        // Try to get actual file size
        try {
          final file = File(audioFilePath);
          if (await file.exists()) {
            audioFileSize = await file.length();
          }
        } catch (e) {
          debugPrint('Could not get file size: $e');
          audioFileSize = null;
        }
      }
      
      // Create conversation from current transcription segments
      final conversation = ConversationModel(
        id: _currentConversationId!,
        title: 'Conversation ${DateTime.now().toLocal().toString().split(' ')[0]}',
        startTime: DateTime.now().subtract(_recordingDuration),
        endTime: DateTime.now(),
        lastUpdated: DateTime.now(),
        status: ConversationStatus.completed,
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
        audioFilePath: audioFilePath,
        audioFormat: audioFormat,
        audioFileSize: audioFileSize,
        audioQuality: 0.8, // Placeholder quality score
        transcriptionConfidence: 0.85, // Placeholder confidence
      );
      
      await _storageService.saveConversation(conversation);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conversation and audio saved')),
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
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Helix needs microphone access to record conversations. Please enable it in Settings:',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                '1. Tap "Open Settings" below\n'
                '2. Find "Flutter Helix" in the list\n'
                '3. Toggle ON "Microphone"\n'
                '4. Return to the app and try recording again',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
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
                  child: _isRecording 
                    ? ReactiveWaveform(
                        level: _audioLevel, 
                        levelHistory: _audioLevelHistory,
                        isRecording: _isRecording,
                      ) 
                    : Container(),
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
    // Combine final segments with current partial segment for display
    final displaySegments = List<TranscriptionSegment>.from(_transcriptSegments);
    if (_currentPartialSegment != null) {
      displaySegments.add(_currentPartialSegment!);
    }
    
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: displaySegments.length,
      separatorBuilder: (context, index) => Divider(
        height: 1,
        color: theme.colorScheme.outline.withOpacity(0.1),
      ),
      itemBuilder: (context, index) {
        final segment = displaySegments[index];
        final isCurrentUser = segment.speakerId == 'user_1' || segment.speakerId == 'speaker_1';
        final isPartial = !segment.isFinal;
        final speakerName = segment.speakerName ?? (isCurrentUser ? 'You' : 'Speaker');
        final duration = segment.endTime.difference(segment.startTime);
        
        return AnimatedContainer(
          duration: Duration(milliseconds: isPartial ? 100 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: isPartial ? BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact header with speaker info and metadata
              Row(
                children: [
                  // Speaker indicator
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrentUser 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.secondary,
                    ),
                    child: isPartial ? Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ) : null,
                  ),
                  const SizedBox(width: 8),
                  
                  // Speaker name
                  Text(
                    speakerName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isCurrentUser 
                        ? theme.colorScheme.primary 
                        : theme.colorScheme.secondary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Timestamp
                  Text(
                    _formatTimestamp(segment.startTime),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Duration
                  Text(
                    '${duration.inSeconds}s',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // Confidence indicator or partial indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPartial 
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : _getConfidenceColor(segment.confidence).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isPartial 
                        ? 'LIVE'
                        : '${(segment.confidence * 100).round()}%',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isPartial 
                          ? theme.colorScheme.primary
                          : _getConfidenceColor(segment.confidence),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              
              // Transcript text - compact formatting
              Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text(
                  segment.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.3, // Slightly tighter line height for density
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
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
class ReactiveWaveform extends StatefulWidget {
  final double level;
  final List<double> levelHistory;
  final bool isRecording;

  const ReactiveWaveform({
    super.key, 
    required this.level, 
    required this.levelHistory,
    required this.isRecording,
  });

  @override
  State<ReactiveWaveform> createState() => _ReactiveWaveformState();
}

class _ReactiveWaveformState extends State<ReactiveWaveform> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _animationController.repeat();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barCount = 30;
    const baseHeight = 4.0;
    const maxHeight = 32.0;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(barCount, (index) {
            // Use history for smoother animation
            final historyIndex = (widget.levelHistory.length * index / barCount).floor();
            final historicalLevel = historyIndex < widget.levelHistory.length 
                ? widget.levelHistory[historyIndex] 
                : 0.0;
            
            // Create wave pattern
            final normalizedIndex = index / barCount;
            final centerDistance = (normalizedIndex - 0.5).abs() * 2; // 0 at center, 1 at edges
            final waveMultiplier = (1.0 - centerDistance * 0.6).clamp(0.2, 1.0);
            
            // Combine current level with historical data for smoother visualization
            final combinedLevel = (widget.level * 0.7 + historicalLevel * 0.3).clamp(0.0, 1.0);
            
            // Add subtle animation for more dynamic feel
            final animationOffset = (1.0 + 0.1 * math.sin(
              _animationController.value * 2 * math.pi + index * 0.3
            ));
            
            // Calculate final height
            final barHeight = baseHeight + 
                (combinedLevel * maxHeight * waveMultiplier * animationOffset);
            
            // Dynamic color based on audio level
            Color barColor;
            if (combinedLevel < 0.1) {
              barColor = Colors.grey.withOpacity(0.3);
            } else if (combinedLevel < 0.3) {
              barColor = Colors.blue.withOpacity(0.6 + 0.4 * combinedLevel);
            } else if (combinedLevel < 0.7) {
              barColor = Colors.green.withOpacity(0.7 + 0.3 * combinedLevel);
            } else {
              barColor = Colors.orange.withOpacity(0.8 + 0.2 * combinedLevel);
            }
            
            return Container(
              width: 2.5,
              height: barHeight.clamp(baseHeight, maxHeight),
              margin: const EdgeInsets.symmetric(horizontal: 0.5),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(1.25),
                boxShadow: widget.isRecording && combinedLevel > 0.5 ? [
                  BoxShadow(
                    color: barColor.withOpacity(0.5),
                    blurRadius: 2,
                    spreadRadius: 0.5,
                  ),
                ] : null,
              ),
            );
          }),
        );
      },
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