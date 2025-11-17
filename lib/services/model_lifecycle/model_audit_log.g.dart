// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_audit_log.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AuditLogEntryImpl _$$AuditLogEntryImplFromJson(Map<String, dynamic> json) =>
    _$AuditLogEntryImpl(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      action: $enumDecode(_$AuditActionEnumMap, json['action']),
      modelId: json['modelId'] as String,
      version: json['version'] as String?,
      userId: json['userId'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      severity:
          $enumDecodeNullable(_$AuditSeverityEnumMap, json['severity']) ??
          AuditSeverity.info,
    );

Map<String, dynamic> _$$AuditLogEntryImplToJson(_$AuditLogEntryImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'timestamp': instance.timestamp.toIso8601String(),
      'action': _$AuditActionEnumMap[instance.action]!,
      'modelId': instance.modelId,
      'version': instance.version,
      'userId': instance.userId,
      'metadata': instance.metadata,
      'severity': _$AuditSeverityEnumMap[instance.severity]!,
    };

const _$AuditActionEnumMap = {
  AuditAction.versionRegistered: 'versionRegistered',
  AuditAction.versionActivated: 'versionActivated',
  AuditAction.versionDeactivated: 'versionDeactivated',
  AuditAction.versionDeprecated: 'versionDeprecated',
  AuditAction.versionRetired: 'versionRetired',
  AuditAction.versionRolledBack: 'versionRolledBack',
  AuditAction.metricsUpdated: 'metricsUpdated',
  AuditAction.performanceThresholdViolation: 'performanceThresholdViolation',
  AuditAction.qualityDegraded: 'qualityDegraded',
  AuditAction.configurationUpdated: 'configurationUpdated',
  AuditAction.thresholdsChanged: 'thresholdsChanged',
  AuditAction.modelDeployed: 'modelDeployed',
  AuditAction.modelUndeployed: 'modelUndeployed',
  AuditAction.canaryDeployment: 'canaryDeployment',
  AuditAction.canaryPromotion: 'canaryPromotion',
  AuditAction.deploymentFailed: 'deploymentFailed',
  AuditAction.evaluationFailed: 'evaluationFailed',
  AuditAction.apiError: 'apiError',
  AuditAction.auditLogCleared: 'auditLogCleared',
  AuditAction.registryInitialized: 'registryInitialized',
  AuditAction.backupCreated: 'backupCreated',
};

const _$AuditSeverityEnumMap = {
  AuditSeverity.debug: 'debug',
  AuditSeverity.info: 'info',
  AuditSeverity.warning: 'warning',
  AuditSeverity.error: 'error',
  AuditSeverity.critical: 'critical',
};
