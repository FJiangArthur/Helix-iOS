// ABOUTME: Conversation data model for managing conversation sessions and history
// ABOUTME: Represents complete conversation threads with participants and metadata

import 'package:freezed_annotation/freezed_annotation.dart';

import 'transcription_segment.dart';

part 'conversation_model.freezed.dart';
part 'conversation_model.g.dart';

/// Participant in a conversation
@freezed
class ConversationParticipant with _$ConversationParticipant {
  const factory ConversationParticipant({
    /// Unique identifier for the participant
    required String id,
    
    /// Display name of the participant
    required String name,
    
    /// Color code for UI display
    @Default('#007AFF') String color,
    
    /// Avatar URL or initials
    String? avatar,
    
    /// Whether this is the device owner
    @Default(false) bool isOwner,
    
    /// Total speaking time in this conversation
    @Default(Duration.zero) Duration totalSpeakingTime,
    
    /// Number of segments spoken
    @Default(0) int segmentCount,
    
    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _ConversationParticipant;

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      _$ConversationParticipantFromJson(json);

  const ConversationParticipant._();

  /// Get initials for display
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Average segment duration
  Duration get averageSegmentDuration {
    return segmentCount > 0 
        ? Duration(milliseconds: totalSpeakingTime.inMilliseconds ~/ segmentCount)
        : Duration.zero;
  }
}

/// Status of a conversation
enum ConversationStatus {
  active,     // Currently ongoing
  paused,     // Temporarily paused
  completed,  // Finished conversation
  archived,   // Archived for storage
  deleted,    // Marked for deletion
}

/// Priority level for conversation
enum ConversationPriority {
  low,
  normal,
  high,
  urgent,
}

/// Main conversation model
@freezed
class ConversationModel with _$ConversationModel {
  const factory ConversationModel({
    /// Unique identifier for the conversation
    required String id,
    
    /// Human-readable title
    required String title,
    
    /// Conversation description or notes
    String? description,
    
    /// Current status
    @Default(ConversationStatus.active) ConversationStatus status,
    
    /// Priority level
    @Default(ConversationPriority.normal) ConversationPriority priority,
    
    /// List of participants
    required List<ConversationParticipant> participants,
    
    /// Transcription segments
    required List<TranscriptionSegment> segments,
    
    /// When the conversation started
    required DateTime startTime,
    
    /// When the conversation ended (if completed)
    DateTime? endTime,
    
    /// Last time the conversation was updated
    required DateTime lastUpdated,
    
    /// Location where conversation took place
    String? location,
    
    /// Tags for categorization
    @Default([]) List<String> tags,
    
    /// Language of the conversation
    @Default('en-US') String language,
    
    /// Whether the conversation has been analyzed by AI
    @Default(false) bool hasAIAnalysis,
    
    /// Whether the conversation is pinned
    @Default(false) bool isPinned,
    
    /// Whether the conversation is private
    @Default(false) bool isPrivate,
    
    /// Audio quality score (0.0 to 1.0)
    double? audioQuality,
    
    /// Transcription confidence score (0.0 to 1.0)
    double? transcriptionConfidence,
    
    /// Additional metadata
    @Default({}) Map<String, dynamic> metadata,
  }) = _ConversationModel;

  factory ConversationModel.fromJson(Map<String, dynamic> json) =>
      _$ConversationModelFromJson(json);

  const ConversationModel._();

  /// Total duration of the conversation
  Duration get duration {
    if (endTime != null) {
      return endTime!.difference(startTime);
    }
    if (segments.isNotEmpty) {
      final lastSegment = segments.last;
      return lastSegment.endTime.difference(startTime);
    }
    return DateTime.now().difference(startTime);
  }

  /// Whether the conversation is currently active
  bool get isActive => status == ConversationStatus.active;

  /// Whether the conversation is completed
  bool get isCompleted => status == ConversationStatus.completed;

  /// Get the full transcribed text
  String get fullTranscript => segments.map((s) => s.text).join(' ');

  /// Get word count
  int get wordCount => fullTranscript.split(' ').where((w) => w.isNotEmpty).length;

  /// Get speaking time for a specific participant
  Duration getSpeakingTimeForParticipant(String participantId) {
    return segments
        .where((s) => s.speakerId == participantId)
        .fold(Duration.zero, (total, segment) => total + segment.duration);
  }

  /// Get segments for a specific participant
  List<TranscriptionSegment> getSegmentsForParticipant(String participantId) {
    return segments.where((s) => s.speakerId == participantId).toList();
  }

  /// Get participant by ID
  ConversationParticipant? getParticipant(String participantId) {
    try {
      return participants.firstWhere((p) => p.id == participantId);
    } catch (e) {
      return null;
    }
  }

  /// Get most active participant (by speaking time)
  ConversationParticipant? get mostActiveParticipant {
    if (participants.isEmpty) return null;
    
    ConversationParticipant? mostActive;
    Duration longestTime = Duration.zero;
    
    for (final participant in participants) {
      final speakingTime = getSpeakingTimeForParticipant(participant.id);
      if (speakingTime > longestTime) {
        longestTime = speakingTime;
        mostActive = participant;
      }
    }
    
    return mostActive;
  }

  /// Get segments within a time range
  List<TranscriptionSegment> getSegmentsInTimeRange(
    Duration start, 
    Duration end,
  ) {
    final startTime = this.startTime.add(start);
    final endTime = this.startTime.add(end);
    
    return segments
        .where((s) => s.startTime.isAfter(startTime) && s.endTime.isBefore(endTime))
        .toList();
  }

  /// Get high-confidence segments only
  List<TranscriptionSegment> get highConfidenceSegments {
    return segments.where((s) => s.isHighConfidence).toList();
  }

  /// Get average transcription confidence
  double get averageConfidence {
    if (segments.isEmpty) return 0.0;
    
    final totalConfidence = segments
        .map((s) => s.confidence)
        .reduce((a, b) => a + b);
    
    return totalConfidence / segments.length;
  }

  /// Get speaking distribution as percentages
  Map<String, double> get speakingDistribution {
    if (participants.isEmpty || duration.inMilliseconds == 0) {
      return {};
    }
    
    final totalMs = duration.inMilliseconds;
    final distribution = <String, double>{};
    
    for (final participant in participants) {
      final speakingTime = getSpeakingTimeForParticipant(participant.id);
      final percentage = (speakingTime.inMilliseconds / totalMs) * 100;
      distribution[participant.name] = percentage;
    }
    
    return distribution;
  }

  /// Generate a summary title based on content
  String generateAutoTitle() {
    if (fullTranscript.isEmpty) {
      return 'Conversation ${startTime.toString().substring(0, 16)}';
    }
    
    final words = fullTranscript.split(' ').take(5).join(' ');
    return words.length > 30 ? '${words.substring(0, 30)}...' : words;
  }

  /// Check if conversation needs attention (low confidence, etc.)
  bool get needsAttention {
    return averageConfidence < 0.7 || 
           segments.any((s) => s.isLowConfidence) ||
           audioQuality != null && audioQuality! < 0.6;
  }

  /// Format duration as human readable string
  String get formattedDuration {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

/// Conversation search and filter criteria
@freezed
class ConversationFilter with _$ConversationFilter {
  const factory ConversationFilter({
    /// Search query for title/content
    String? query,
    
    /// Filter by status
    List<ConversationStatus>? statuses,
    
    /// Filter by priority
    List<ConversationPriority>? priorities,
    
    /// Filter by tags
    List<String>? tags,
    
    /// Filter by participants
    List<String>? participantIds,
    
    /// Date range filter
    DateTime? startDate,
    DateTime? endDate,
    
    /// Minimum duration filter
    Duration? minDuration,
    
    /// Maximum duration filter
    Duration? maxDuration,
    
    /// Filter by AI analysis availability
    bool? hasAIAnalysis,
    
    /// Filter by privacy setting
    bool? isPrivate,
    
    /// Minimum confidence threshold
    double? minConfidence,
  }) = _ConversationFilter;

  factory ConversationFilter.fromJson(Map<String, dynamic> json) =>
      _$ConversationFilterFromJson(json);
}