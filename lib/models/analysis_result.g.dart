// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'analysis_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AnalysisResultImpl _$$AnalysisResultImplFromJson(
  Map<String, dynamic> json,
) => _$AnalysisResultImpl(
  id: json['id'] as String,
  conversationId: json['conversationId'] as String,
  type: $enumDecode(_$AnalysisTypeEnumMap, json['type']),
  status: $enumDecode(_$AnalysisStatusEnumMap, json['status']),
  startTime: DateTime.parse(json['startTime'] as String),
  completionTime:
      json['completionTime'] == null
          ? null
          : DateTime.parse(json['completionTime'] as String),
  provider: json['provider'] as String?,
  confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  factChecks:
      (json['factChecks'] as List<dynamic>?)
          ?.map((e) => FactCheckResult.fromJson(e as Map<String, dynamic>))
          .toList(),
  summary:
      json['summary'] == null
          ? null
          : ConversationSummary.fromJson(
            json['summary'] as Map<String, dynamic>,
          ),
  actionItems:
      (json['actionItems'] as List<dynamic>?)
          ?.map((e) => ActionItemResult.fromJson(e as Map<String, dynamic>))
          .toList(),
  sentiment:
      json['sentiment'] == null
          ? null
          : SentimentAnalysisResult.fromJson(
            json['sentiment'] as Map<String, dynamic>,
          ),
  topics:
      (json['topics'] as List<dynamic>?)
          ?.map((e) => TopicResult.fromJson(e as Map<String, dynamic>))
          .toList(),
  insights:
      (json['insights'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  errors:
      (json['errors'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  processingTimeMs: (json['processingTimeMs'] as num?)?.toInt(),
  tokenUsage: (json['tokenUsage'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, (e as num).toInt()),
  ),
  metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
);

Map<String, dynamic> _$$AnalysisResultImplToJson(
  _$AnalysisResultImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'conversationId': instance.conversationId,
  'type': _$AnalysisTypeEnumMap[instance.type]!,
  'status': _$AnalysisStatusEnumMap[instance.status]!,
  'startTime': instance.startTime.toIso8601String(),
  'completionTime': instance.completionTime?.toIso8601String(),
  'provider': instance.provider,
  'confidence': instance.confidence,
  'factChecks': instance.factChecks,
  'summary': instance.summary,
  'actionItems': instance.actionItems,
  'sentiment': instance.sentiment,
  'topics': instance.topics,
  'insights': instance.insights,
  'errors': instance.errors,
  'processingTimeMs': instance.processingTimeMs,
  'tokenUsage': instance.tokenUsage,
  'metadata': instance.metadata,
};

const _$AnalysisTypeEnumMap = {
  AnalysisType.factCheck: 'factCheck',
  AnalysisType.summary: 'summary',
  AnalysisType.actionItems: 'actionItems',
  AnalysisType.sentiment: 'sentiment',
  AnalysisType.topics: 'topics',
  AnalysisType.comprehensive: 'comprehensive',
};

const _$AnalysisStatusEnumMap = {
  AnalysisStatus.pending: 'pending',
  AnalysisStatus.processing: 'processing',
  AnalysisStatus.completed: 'completed',
  AnalysisStatus.failed: 'failed',
  AnalysisStatus.partial: 'partial',
};

_$FactCheckResultImpl _$$FactCheckResultImplFromJson(
  Map<String, dynamic> json,
) => _$FactCheckResultImpl(
  id: json['id'] as String,
  claim: json['claim'] as String,
  status: $enumDecode(_$FactCheckStatusEnumMap, json['status']),
  confidence: (json['confidence'] as num).toDouble(),
  sources:
      (json['sources'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  explanation: json['explanation'] as String?,
  context: json['context'] as String?,
  startTimeMs: (json['startTimeMs'] as num?)?.toInt(),
  endTimeMs: (json['endTimeMs'] as num?)?.toInt(),
  speakerId: json['speakerId'] as String?,
  category: json['category'] as String?,
  relatedClaims:
      (json['relatedClaims'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$$FactCheckResultImplToJson(
  _$FactCheckResultImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'claim': instance.claim,
  'status': _$FactCheckStatusEnumMap[instance.status]!,
  'confidence': instance.confidence,
  'sources': instance.sources,
  'explanation': instance.explanation,
  'context': instance.context,
  'startTimeMs': instance.startTimeMs,
  'endTimeMs': instance.endTimeMs,
  'speakerId': instance.speakerId,
  'category': instance.category,
  'relatedClaims': instance.relatedClaims,
};

const _$FactCheckStatusEnumMap = {
  FactCheckStatus.verified: 'verified',
  FactCheckStatus.disputed: 'disputed',
  FactCheckStatus.uncertain: 'uncertain',
  FactCheckStatus.needsReview: 'needsReview',
};

_$ConversationSummaryImpl _$$ConversationSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$ConversationSummaryImpl(
  summary: json['summary'] as String,
  keyPoints:
      (json['keyPoints'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  decisions:
      (json['decisions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  questions:
      (json['questions'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  tone: json['tone'] as String?,
  topics:
      (json['topics'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  length:
      $enumDecodeNullable(_$SummaryLengthEnumMap, json['length']) ??
      SummaryLength.medium,
  estimatedReadTime:
      json['estimatedReadTime'] == null
          ? null
          : Duration(microseconds: (json['estimatedReadTime'] as num).toInt()),
  confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
);

Map<String, dynamic> _$$ConversationSummaryImplToJson(
  _$ConversationSummaryImpl instance,
) => <String, dynamic>{
  'summary': instance.summary,
  'keyPoints': instance.keyPoints,
  'decisions': instance.decisions,
  'questions': instance.questions,
  'tone': instance.tone,
  'topics': instance.topics,
  'length': _$SummaryLengthEnumMap[instance.length]!,
  'estimatedReadTime': instance.estimatedReadTime?.inMicroseconds,
  'confidence': instance.confidence,
};

const _$SummaryLengthEnumMap = {
  SummaryLength.brief: 'brief',
  SummaryLength.medium: 'medium',
  SummaryLength.detailed: 'detailed',
};

_$ActionItemResultImpl _$$ActionItemResultImplFromJson(
  Map<String, dynamic> json,
) => _$ActionItemResultImpl(
  id: json['id'] as String,
  description: json['description'] as String,
  assignee: json['assignee'] as String?,
  dueDate:
      json['dueDate'] == null
          ? null
          : DateTime.parse(json['dueDate'] as String),
  priority:
      $enumDecodeNullable(_$ActionItemPriorityEnumMap, json['priority']) ??
      ActionItemPriority.medium,
  context: json['context'] as String?,
  confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
  status:
      $enumDecodeNullable(_$ActionItemStatusEnumMap, json['status']) ??
      ActionItemStatus.pending,
  mentionedAtMs: (json['mentionedAtMs'] as num?)?.toInt(),
  speakerId: json['speakerId'] as String?,
  relatedItems:
      (json['relatedItems'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
);

Map<String, dynamic> _$$ActionItemResultImplToJson(
  _$ActionItemResultImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'description': instance.description,
  'assignee': instance.assignee,
  'dueDate': instance.dueDate?.toIso8601String(),
  'priority': _$ActionItemPriorityEnumMap[instance.priority]!,
  'context': instance.context,
  'confidence': instance.confidence,
  'status': _$ActionItemStatusEnumMap[instance.status]!,
  'mentionedAtMs': instance.mentionedAtMs,
  'speakerId': instance.speakerId,
  'relatedItems': instance.relatedItems,
  'tags': instance.tags,
};

const _$ActionItemPriorityEnumMap = {
  ActionItemPriority.low: 'low',
  ActionItemPriority.medium: 'medium',
  ActionItemPriority.high: 'high',
  ActionItemPriority.urgent: 'urgent',
};

const _$ActionItemStatusEnumMap = {
  ActionItemStatus.pending: 'pending',
  ActionItemStatus.inProgress: 'inProgress',
  ActionItemStatus.completed: 'completed',
  ActionItemStatus.cancelled: 'cancelled',
  ActionItemStatus.deferred: 'deferred',
};

_$SentimentAnalysisResultImpl _$$SentimentAnalysisResultImplFromJson(
  Map<String, dynamic> json,
) => _$SentimentAnalysisResultImpl(
  overallSentiment: $enumDecode(
    _$SentimentTypeEnumMap,
    json['overallSentiment'],
  ),
  confidence: (json['confidence'] as num).toDouble(),
  emotions: (json['emotions'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, (e as num).toDouble()),
  ),
  tone: json['tone'] as String?,
  progression:
      (json['progression'] as List<dynamic>?)
          ?.map((e) => SentimentTimePoint.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  participantSentiments:
      (json['participantSentiments'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, $enumDecode(_$SentimentTypeEnumMap, e)),
      ) ??
      const {},
  keyPhrases:
      (json['keyPhrases'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$$SentimentAnalysisResultImplToJson(
  _$SentimentAnalysisResultImpl instance,
) => <String, dynamic>{
  'overallSentiment': _$SentimentTypeEnumMap[instance.overallSentiment]!,
  'confidence': instance.confidence,
  'emotions': instance.emotions,
  'tone': instance.tone,
  'progression': instance.progression,
  'participantSentiments': instance.participantSentiments.map(
    (k, e) => MapEntry(k, _$SentimentTypeEnumMap[e]!),
  ),
  'keyPhrases': instance.keyPhrases,
};

const _$SentimentTypeEnumMap = {
  SentimentType.positive: 'positive',
  SentimentType.negative: 'negative',
  SentimentType.neutral: 'neutral',
  SentimentType.mixed: 'mixed',
};

_$SentimentTimePointImpl _$$SentimentTimePointImplFromJson(
  Map<String, dynamic> json,
) => _$SentimentTimePointImpl(
  timeMs: (json['timeMs'] as num).toInt(),
  sentiment: $enumDecode(_$SentimentTypeEnumMap, json['sentiment']),
  confidence: (json['confidence'] as num).toDouble(),
);

Map<String, dynamic> _$$SentimentTimePointImplToJson(
  _$SentimentTimePointImpl instance,
) => <String, dynamic>{
  'timeMs': instance.timeMs,
  'sentiment': _$SentimentTypeEnumMap[instance.sentiment]!,
  'confidence': instance.confidence,
};

_$TopicResultImpl _$$TopicResultImplFromJson(Map<String, dynamic> json) =>
    _$TopicResultImpl(
      name: json['name'] as String,
      relevance: (json['relevance'] as num).toDouble(),
      keywords:
          (json['keywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      category: json['category'] as String?,
      description: json['description'] as String?,
      timeRanges:
          (json['timeRanges'] as List<dynamic>?)
              ?.map((e) => TimeRange.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      participants:
          (json['participants'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      relatedTopics:
          (json['relatedTopics'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$$TopicResultImplToJson(_$TopicResultImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'relevance': instance.relevance,
      'keywords': instance.keywords,
      'category': instance.category,
      'description': instance.description,
      'timeRanges': instance.timeRanges,
      'participants': instance.participants,
      'relatedTopics': instance.relatedTopics,
      'confidence': instance.confidence,
    };

_$TimeRangeImpl _$$TimeRangeImplFromJson(Map<String, dynamic> json) =>
    _$TimeRangeImpl(
      startMs: (json['startMs'] as num).toInt(),
      endMs: (json['endMs'] as num).toInt(),
    );

Map<String, dynamic> _$$TimeRangeImplToJson(_$TimeRangeImpl instance) =>
    <String, dynamic>{'startMs': instance.startMs, 'endMs': instance.endMs};
