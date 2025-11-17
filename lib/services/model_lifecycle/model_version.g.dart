// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_version.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ModelVersionImpl _$$ModelVersionImplFromJson(Map<String, dynamic> json) =>
    _$ModelVersionImpl(
      version: json['version'] as String,
      modelId: json['modelId'] as String,
      provider: json['provider'] as String,
      displayName: json['displayName'] as String,
      description: json['description'] as String?,
      releaseDate: DateTime.parse(json['releaseDate'] as String),
      status:
          $enumDecodeNullable(_$ModelStatusEnumMap, json['status']) ??
          ModelStatus.inactive,
      capabilities: ModelCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
      metrics: json['metrics'] == null
          ? null
          : ModelPerformanceMetrics.fromJson(
              json['metrics'] as Map<String, dynamic>,
            ),
      costInfo: ModelCostInfo.fromJson(
        json['costInfo'] as Map<String, dynamic>,
      ),
      deprecation: json['deprecation'] == null
          ? null
          : ModelDeprecationInfo.fromJson(
              json['deprecation'] as Map<String, dynamic>,
            ),
      configuration: json['configuration'] as Map<String, dynamic>? ?? const {},
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      releaseNotes: json['releaseNotes'] as String?,
      minConfidenceThreshold:
          (json['minConfidenceThreshold'] as num?)?.toDouble() ?? 0.7,
      maxLatencyMs: (json['maxLatencyMs'] as num?)?.toInt(),
      successRateThreshold:
          (json['successRateThreshold'] as num?)?.toDouble() ?? 0.95,
    );

Map<String, dynamic> _$$ModelVersionImplToJson(_$ModelVersionImpl instance) =>
    <String, dynamic>{
      'version': instance.version,
      'modelId': instance.modelId,
      'provider': instance.provider,
      'displayName': instance.displayName,
      'description': instance.description,
      'releaseDate': instance.releaseDate.toIso8601String(),
      'status': _$ModelStatusEnumMap[instance.status]!,
      'capabilities': instance.capabilities,
      'metrics': instance.metrics,
      'costInfo': instance.costInfo,
      'deprecation': instance.deprecation,
      'configuration': instance.configuration,
      'tags': instance.tags,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'releaseNotes': instance.releaseNotes,
      'minConfidenceThreshold': instance.minConfidenceThreshold,
      'maxLatencyMs': instance.maxLatencyMs,
      'successRateThreshold': instance.successRateThreshold,
    };

const _$ModelStatusEnumMap = {
  ModelStatus.inactive: 'inactive',
  ModelStatus.testing: 'testing',
  ModelStatus.canary: 'canary',
  ModelStatus.active: 'active',
  ModelStatus.deprecated: 'deprecated',
  ModelStatus.retired: 'retired',
};

_$ModelCapabilitiesImpl _$$ModelCapabilitiesImplFromJson(
  Map<String, dynamic> json,
) => _$ModelCapabilitiesImpl(
  supportsStreaming: json['supportsStreaming'] as bool? ?? false,
  supportsFunctionCalling: json['supportsFunctionCalling'] as bool? ?? false,
  supportsVision: json['supportsVision'] as bool? ?? false,
  supportsAudioTranscription:
      json['supportsAudioTranscription'] as bool? ?? false,
  maxContextTokens: (json['maxContextTokens'] as num).toInt(),
  maxOutputTokens: (json['maxOutputTokens'] as num).toInt(),
  supportedLanguages:
      (json['supportedLanguages'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const ['en'],
  supportedAnalysisTypes:
      (json['supportedAnalysisTypes'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
);

Map<String, dynamic> _$$ModelCapabilitiesImplToJson(
  _$ModelCapabilitiesImpl instance,
) => <String, dynamic>{
  'supportsStreaming': instance.supportsStreaming,
  'supportsFunctionCalling': instance.supportsFunctionCalling,
  'supportsVision': instance.supportsVision,
  'supportsAudioTranscription': instance.supportsAudioTranscription,
  'maxContextTokens': instance.maxContextTokens,
  'maxOutputTokens': instance.maxOutputTokens,
  'supportedLanguages': instance.supportedLanguages,
  'supportedAnalysisTypes': instance.supportedAnalysisTypes,
};

_$ModelPerformanceMetricsImpl _$$ModelPerformanceMetricsImplFromJson(
  Map<String, dynamic> json,
) => _$ModelPerformanceMetricsImpl(
  avgLatencyMs: (json['avgLatencyMs'] as num).toDouble(),
  p95LatencyMs: (json['p95LatencyMs'] as num).toDouble(),
  p99LatencyMs: (json['p99LatencyMs'] as num).toDouble(),
  successRate: (json['successRate'] as num).toDouble(),
  errorRate: (json['errorRate'] as num).toDouble(),
  avgConfidence: (json['avgConfidence'] as num).toDouble(),
  totalRequests: (json['totalRequests'] as num?)?.toInt() ?? 0,
  successfulRequests: (json['successfulRequests'] as num?)?.toInt() ?? 0,
  failedRequests: (json['failedRequests'] as num?)?.toInt() ?? 0,
  avgTokensPerRequest: (json['avgTokensPerRequest'] as num?)?.toDouble(),
  costPer1kRequests: (json['costPer1kRequests'] as num?)?.toDouble(),
  lastUpdated: DateTime.parse(json['lastUpdated'] as String),
  evaluationScores:
      (json['evaluationScores'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toDouble()),
      ) ??
      const {},
);

Map<String, dynamic> _$$ModelPerformanceMetricsImplToJson(
  _$ModelPerformanceMetricsImpl instance,
) => <String, dynamic>{
  'avgLatencyMs': instance.avgLatencyMs,
  'p95LatencyMs': instance.p95LatencyMs,
  'p99LatencyMs': instance.p99LatencyMs,
  'successRate': instance.successRate,
  'errorRate': instance.errorRate,
  'avgConfidence': instance.avgConfidence,
  'totalRequests': instance.totalRequests,
  'successfulRequests': instance.successfulRequests,
  'failedRequests': instance.failedRequests,
  'avgTokensPerRequest': instance.avgTokensPerRequest,
  'costPer1kRequests': instance.costPer1kRequests,
  'lastUpdated': instance.lastUpdated.toIso8601String(),
  'evaluationScores': instance.evaluationScores,
};

_$ModelCostInfoImpl _$$ModelCostInfoImplFromJson(Map<String, dynamic> json) =>
    _$ModelCostInfoImpl(
      inputCostPer1k: (json['inputCostPer1k'] as num).toDouble(),
      outputCostPer1k: (json['outputCostPer1k'] as num).toDouble(),
      tier:
          $enumDecodeNullable(_$CostTierEnumMap, json['tier']) ??
          CostTier.standard,
      estimatedMonthlyCost: (json['estimatedMonthlyCost'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'USD',
    );

Map<String, dynamic> _$$ModelCostInfoImplToJson(_$ModelCostInfoImpl instance) =>
    <String, dynamic>{
      'inputCostPer1k': instance.inputCostPer1k,
      'outputCostPer1k': instance.outputCostPer1k,
      'tier': _$CostTierEnumMap[instance.tier]!,
      'estimatedMonthlyCost': instance.estimatedMonthlyCost,
      'currency': instance.currency,
    };

const _$CostTierEnumMap = {
  CostTier.economy: 'economy',
  CostTier.standard: 'standard',
  CostTier.premium: 'premium',
  CostTier.enterprise: 'enterprise',
};

_$ModelDeprecationInfoImpl _$$ModelDeprecationInfoImplFromJson(
  Map<String, dynamic> json,
) => _$ModelDeprecationInfoImpl(
  announcedAt: DateTime.parse(json['announcedAt'] as String),
  endOfLifeDate: DateTime.parse(json['endOfLifeDate'] as String),
  replacementVersion: json['replacementVersion'] as String?,
  reason: json['reason'] as String,
  migrationGuideUrl: json['migrationGuideUrl'] as String?,
  gracePeriodDays: (json['gracePeriodDays'] as num?)?.toInt() ?? 90,
  allowNewDeployments: json['allowNewDeployments'] as bool? ?? false,
);

Map<String, dynamic> _$$ModelDeprecationInfoImplToJson(
  _$ModelDeprecationInfoImpl instance,
) => <String, dynamic>{
  'announcedAt': instance.announcedAt.toIso8601String(),
  'endOfLifeDate': instance.endOfLifeDate.toIso8601String(),
  'replacementVersion': instance.replacementVersion,
  'reason': instance.reason,
  'migrationGuideUrl': instance.migrationGuideUrl,
  'gracePeriodDays': instance.gracePeriodDays,
  'allowNewDeployments': instance.allowNewDeployments,
};
