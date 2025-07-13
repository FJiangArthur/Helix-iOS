// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transcription_segment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TranscriptionSegmentImpl _$$TranscriptionSegmentImplFromJson(
  Map<String, dynamic> json,
) => _$TranscriptionSegmentImpl(
  id: json['id'] as String,
  text: json['text'] as String,
  startTimeMs: (json['startTimeMs'] as num).toInt(),
  endTimeMs: (json['endTimeMs'] as num).toInt(),
  confidence: (json['confidence'] as num).toDouble(),
  speakerId: json['speakerId'] as String?,
  speakerName: json['speakerName'] as String?,
  language: json['language'] as String? ?? 'en-US',
  isFinal: json['isFinal'] as bool? ?? true,
  backend: json['backend'] as String?,
  processingTimeMs: (json['processingTimeMs'] as num?)?.toInt(),
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$$TranscriptionSegmentImplToJson(
  _$TranscriptionSegmentImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'text': instance.text,
  'startTimeMs': instance.startTimeMs,
  'endTimeMs': instance.endTimeMs,
  'confidence': instance.confidence,
  'speakerId': instance.speakerId,
  'speakerName': instance.speakerName,
  'language': instance.language,
  'isFinal': instance.isFinal,
  'backend': instance.backend,
  'processingTimeMs': instance.processingTimeMs,
  'metadata': instance.metadata,
  'timestamp': instance.timestamp.toIso8601String(),
};

_$TranscriptionResultImpl _$$TranscriptionResultImplFromJson(
  Map<String, dynamic> json,
) => _$TranscriptionResultImpl(
  id: json['id'] as String,
  segments:
      (json['segments'] as List<dynamic>)
          .map((e) => TranscriptionSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
  overallConfidence: (json['overallConfidence'] as num).toDouble(),
  totalDuration: Duration(microseconds: (json['totalDuration'] as num).toInt()),
  language: json['language'] as String? ?? 'en-US',
  backend: json['backend'] as String?,
  processingTime:
      json['processingTime'] == null
          ? null
          : Duration(microseconds: (json['processingTime'] as num).toInt()),
  speakerCount: (json['speakerCount'] as num?)?.toInt() ?? 1,
  hasSpeakerDiarization: json['hasSpeakerDiarization'] as bool? ?? false,
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
  timestamp: DateTime.parse(json['timestamp'] as String),
);

Map<String, dynamic> _$$TranscriptionResultImplToJson(
  _$TranscriptionResultImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'segments': instance.segments,
  'overallConfidence': instance.overallConfidence,
  'totalDuration': instance.totalDuration.inMicroseconds,
  'language': instance.language,
  'backend': instance.backend,
  'processingTime': instance.processingTime?.inMicroseconds,
  'speakerCount': instance.speakerCount,
  'hasSpeakerDiarization': instance.hasSpeakerDiarization,
  'metadata': instance.metadata,
  'timestamp': instance.timestamp.toIso8601String(),
};
