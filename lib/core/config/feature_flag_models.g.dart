// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feature_flag_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FeatureFlagMetadataImpl _$$FeatureFlagMetadataImplFromJson(
  Map<String, dynamic> json,
) => _$FeatureFlagMetadataImpl(
  category: json['category'] as String,
  requiresRestart: json['requiresRestart'] as bool? ?? false,
  addedDate: json['addedDate'] as String?,
  experimentEndDate: json['experimentEndDate'] as String?,
);

Map<String, dynamic> _$$FeatureFlagMetadataImplToJson(
  _$FeatureFlagMetadataImpl instance,
) => <String, dynamic>{
  'category': instance.category,
  'requiresRestart': instance.requiresRestart,
  'addedDate': instance.addedDate,
  'experimentEndDate': instance.experimentEndDate,
};

_$FeatureFlagVariantsImpl _$$FeatureFlagVariantsImplFromJson(
  Map<String, dynamic> json,
) => _$FeatureFlagVariantsImpl(
  development: json['development'] as bool? ?? false,
  staging: json['staging'] as bool? ?? false,
  production: json['production'] as bool? ?? false,
);

Map<String, dynamic> _$$FeatureFlagVariantsImplToJson(
  _$FeatureFlagVariantsImpl instance,
) => <String, dynamic>{
  'development': instance.development,
  'staging': instance.staging,
  'production': instance.production,
};

_$RolloutPercentageImpl _$$RolloutPercentageImplFromJson(
  Map<String, dynamic> json,
) => _$RolloutPercentageImpl(
  development: (json['development'] as num?)?.toInt() ?? 0,
  staging: (json['staging'] as num?)?.toInt() ?? 0,
  production: (json['production'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$$RolloutPercentageImplToJson(
  _$RolloutPercentageImpl instance,
) => <String, dynamic>{
  'development': instance.development,
  'staging': instance.staging,
  'production': instance.production,
};

_$FeatureFlagImpl _$$FeatureFlagImplFromJson(Map<String, dynamic> json) =>
    _$FeatureFlagImpl(
      key: json['key'] as String,
      enabled: json['enabled'] as bool,
      description: json['description'] as String,
      type: $enumDecode(_$FeatureFlagTypeEnumMap, json['type']),
      metadata: FeatureFlagMetadata.fromJson(
        json['metadata'] as Map<String, dynamic>,
      ),
      variants: FeatureFlagVariants.fromJson(
        json['variants'] as Map<String, dynamic>,
      ),
      rolloutPercentage: json['rolloutPercentage'] == null
          ? null
          : RolloutPercentage.fromJson(
              json['rolloutPercentage'] as Map<String, dynamic>,
            ),
      config: json['config'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$$FeatureFlagImplToJson(_$FeatureFlagImpl instance) =>
    <String, dynamic>{
      'key': instance.key,
      'enabled': instance.enabled,
      'description': instance.description,
      'type': _$FeatureFlagTypeEnumMap[instance.type]!,
      'metadata': instance.metadata,
      'variants': instance.variants,
      'rolloutPercentage': instance.rolloutPercentage,
      'config': instance.config,
    };

const _$FeatureFlagTypeEnumMap = {
  FeatureFlagType.feature: 'feature',
  FeatureFlagType.experiment: 'experiment',
  FeatureFlagType.debug: 'debug',
  FeatureFlagType.monitoring: 'monitoring',
};

_$EnvironmentConfigImpl _$$EnvironmentConfigImplFromJson(
  Map<String, dynamic> json,
) => _$EnvironmentConfigImpl(
  enabled: json['enabled'] as bool,
  description: json['description'] as String,
);

Map<String, dynamic> _$$EnvironmentConfigImplToJson(
  _$EnvironmentConfigImpl instance,
) => <String, dynamic>{
  'enabled': instance.enabled,
  'description': instance.description,
};

_$GlobalConfigImpl _$$GlobalConfigImplFromJson(
  Map<String, dynamic> json,
) => _$GlobalConfigImpl(
  defaultEnvironment:
      $enumDecodeNullable(_$EnvironmentEnumMap, json['defaultEnvironment']) ??
      Environment.development,
  allowEnvironmentOverride: json['allowEnvironmentOverride'] as bool? ?? true,
  cacheEnabled: json['cacheEnabled'] as bool? ?? true,
  cacheDuration: (json['cacheDuration'] as num?)?.toInt() ?? 300,
);

Map<String, dynamic> _$$GlobalConfigImplToJson(_$GlobalConfigImpl instance) =>
    <String, dynamic>{
      'defaultEnvironment': _$EnvironmentEnumMap[instance.defaultEnvironment]!,
      'allowEnvironmentOverride': instance.allowEnvironmentOverride,
      'cacheEnabled': instance.cacheEnabled,
      'cacheDuration': instance.cacheDuration,
    };

const _$EnvironmentEnumMap = {
  Environment.development: 'development',
  Environment.staging: 'staging',
  Environment.production: 'production',
};

_$FeatureFlagsConfigImpl _$$FeatureFlagsConfigImplFromJson(
  Map<String, dynamic> json,
) => _$FeatureFlagsConfigImpl(
  version: json['version'] as String,
  description: json['description'] as String,
  environments: (json['environments'] as Map<String, dynamic>).map(
    (k, e) =>
        MapEntry(k, EnvironmentConfig.fromJson(e as Map<String, dynamic>)),
  ),
  flags: (json['flags'] as Map<String, dynamic>).map(
    (k, e) => MapEntry(k, FeatureFlag.fromJson(e as Map<String, dynamic>)),
  ),
  globalConfig: GlobalConfig.fromJson(
    json['globalConfig'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$$FeatureFlagsConfigImplToJson(
  _$FeatureFlagsConfigImpl instance,
) => <String, dynamic>{
  'version': instance.version,
  'description': instance.description,
  'environments': instance.environments,
  'flags': instance.flags,
  'globalConfig': instance.globalConfig,
};
