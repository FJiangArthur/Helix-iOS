// ABOUTME: Simple model class for voice notes with optional transcript and summary.
// ABOUTME: Not using Freezed — matches project convention of plain Dart classes.

/// Represents a captured voice note with optional transcript and summary.
class VoiceNoteModel {
  final String id;
  final DateTime createdAt;
  final int durationMs;
  final String? transcript;
  final String? summary;
  final List<String> tags;

  const VoiceNoteModel({
    required this.id,
    required this.createdAt,
    this.durationMs = 0,
    this.transcript,
    this.summary,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'durationMs': durationMs,
        if (transcript != null) 'transcript': transcript,
        if (summary != null) 'summary': summary,
        'tags': tags,
      };

  factory VoiceNoteModel.fromJson(Map<String, dynamic> json) => VoiceNoteModel(
        id: json['id'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        durationMs: json['durationMs'] as int? ?? 0,
        transcript: json['transcript'] as String?,
        summary: json['summary'] as String?,
        tags:
            (json['tags'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}
