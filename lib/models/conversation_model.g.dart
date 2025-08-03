// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConversationParticipantImpl _$$ConversationParticipantImplFromJson(
  Map<String, dynamic> json,
) => _$ConversationParticipantImpl(
  id: json['id'] as String,
  name: json['name'] as String,
  color: json['color'] as String? ?? '#007AFF',
  avatar: json['avatar'] as String?,
  isOwner: json['isOwner'] as bool? ?? false,
  totalSpeakingTime:
      json['totalSpeakingTime'] == null
          ? Duration.zero
          : Duration(microseconds: (json['totalSpeakingTime'] as num).toInt()),
  segmentCount: (json['segmentCount'] as num?)?.toInt() ?? 0,
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$$ConversationParticipantImplToJson(
  _$ConversationParticipantImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'color': instance.color,
  'avatar': instance.avatar,
  'isOwner': instance.isOwner,
  'totalSpeakingTime': instance.totalSpeakingTime.inMicroseconds,
  'segmentCount': instance.segmentCount,
  'metadata': instance.metadata,
};

_$ConversationModelImpl _$$ConversationModelImplFromJson(
  Map<String, dynamic> json,
) => _$ConversationModelImpl(
  id: json['id'] as String,
  title: json['title'] as String,
  description: json['description'] as String?,
  status:
      $enumDecodeNullable(_$ConversationStatusEnumMap, json['status']) ??
      ConversationStatus.active,
  priority:
      $enumDecodeNullable(_$ConversationPriorityEnumMap, json['priority']) ??
      ConversationPriority.normal,
  participants:
      (json['participants'] as List<dynamic>)
          .map(
            (e) => ConversationParticipant.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
  segments:
      (json['segments'] as List<dynamic>)
          .map((e) => TranscriptionSegment.fromJson(e as Map<String, dynamic>))
          .toList(),
  startTime: DateTime.parse(json['startTime'] as String),
  endTime:
      json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
  lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  location: json['location'] as String?,
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  language: json['language'] as String? ?? 'en-US',
  hasAIAnalysis: json['hasAIAnalysis'] as bool? ?? false,
  isPinned: json['isPinned'] as bool? ?? false,
  isPrivate: json['isPrivate'] as bool? ?? false,
  audioQuality: (json['audioQuality'] as num?)?.toDouble(),
  transcriptionConfidence:
      (json['transcriptionConfidence'] as num?)?.toDouble(),
  audioFilePath: json['audioFilePath'] as String?,
  audioFormat: json['audioFormat'] as String?,
  audioFileSize: (json['audioFileSize'] as num?)?.toInt(),
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$$ConversationModelImplToJson(
  _$ConversationModelImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'description': instance.description,
  'status': _$ConversationStatusEnumMap[instance.status]!,
  'priority': _$ConversationPriorityEnumMap[instance.priority]!,
  'participants': instance.participants,
  'segments': instance.segments,
  'startTime': instance.startTime.toIso8601String(),
  'endTime': instance.endTime?.toIso8601String(),
  'lastUpdated': instance.lastUpdated.toIso8601String(),
  'location': instance.location,
  'tags': instance.tags,
  'language': instance.language,
  'hasAIAnalysis': instance.hasAIAnalysis,
  'isPinned': instance.isPinned,
  'isPrivate': instance.isPrivate,
  'audioQuality': instance.audioQuality,
  'transcriptionConfidence': instance.transcriptionConfidence,
  'audioFilePath': instance.audioFilePath,
  'audioFormat': instance.audioFormat,
  'audioFileSize': instance.audioFileSize,
  'metadata': instance.metadata,
};

const _$ConversationStatusEnumMap = {
  ConversationStatus.active: 'active',
  ConversationStatus.paused: 'paused',
  ConversationStatus.completed: 'completed',
  ConversationStatus.archived: 'archived',
  ConversationStatus.deleted: 'deleted',
};

const _$ConversationPriorityEnumMap = {
  ConversationPriority.low: 'low',
  ConversationPriority.normal: 'normal',
  ConversationPriority.high: 'high',
  ConversationPriority.urgent: 'urgent',
};

_$ConversationFilterImpl _$$ConversationFilterImplFromJson(
  Map<String, dynamic> json,
) => _$ConversationFilterImpl(
  query: json['query'] as String?,
  statuses:
      (json['statuses'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$ConversationStatusEnumMap, e))
          .toList(),
  priorities:
      (json['priorities'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$ConversationPriorityEnumMap, e))
          .toList(),
  tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
  participantIds:
      (json['participantIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
  startDate:
      json['startDate'] == null
          ? null
          : DateTime.parse(json['startDate'] as String),
  endDate:
      json['endDate'] == null
          ? null
          : DateTime.parse(json['endDate'] as String),
  minDuration:
      json['minDuration'] == null
          ? null
          : Duration(microseconds: (json['minDuration'] as num).toInt()),
  maxDuration:
      json['maxDuration'] == null
          ? null
          : Duration(microseconds: (json['maxDuration'] as num).toInt()),
  hasAIAnalysis: json['hasAIAnalysis'] as bool?,
  isPrivate: json['isPrivate'] as bool?,
  minConfidence: (json['minConfidence'] as num?)?.toDouble(),
);

Map<String, dynamic> _$$ConversationFilterImplToJson(
  _$ConversationFilterImpl instance,
) => <String, dynamic>{
  'query': instance.query,
  'statuses':
      instance.statuses?.map((e) => _$ConversationStatusEnumMap[e]!).toList(),
  'priorities':
      instance.priorities
          ?.map((e) => _$ConversationPriorityEnumMap[e]!)
          .toList(),
  'tags': instance.tags,
  'participantIds': instance.participantIds,
  'startDate': instance.startDate?.toIso8601String(),
  'endDate': instance.endDate?.toIso8601String(),
  'minDuration': instance.minDuration?.inMicroseconds,
  'maxDuration': instance.maxDuration?.inMicroseconds,
  'hasAIAnalysis': instance.hasAIAnalysis,
  'isPrivate': instance.isPrivate,
  'minConfidence': instance.minConfidence,
};
