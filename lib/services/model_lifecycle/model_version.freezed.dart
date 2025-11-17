// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'model_version.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ModelVersion _$ModelVersionFromJson(Map<String, dynamic> json) {
  return _ModelVersion.fromJson(json);
}

/// @nodoc
mixin _$ModelVersion {
  /// Unique version identifier (semantic versioning: major.minor.patch)
  String get version => throw _privateConstructorUsedError;

  /// Model identifier (e.g., 'gpt-4-turbo', 'gpt-4.1-mini')
  String get modelId => throw _privateConstructorUsedError;

  /// Provider name (OpenAI, Anthropic, etc.)
  String get provider => throw _privateConstructorUsedError;

  /// Model display name
  String get displayName => throw _privateConstructorUsedError;

  /// Model description
  String? get description => throw _privateConstructorUsedError;

  /// Release date
  DateTime get releaseDate => throw _privateConstructorUsedError;

  /// Current deployment status
  ModelStatus get status => throw _privateConstructorUsedError;

  /// Model capabilities
  ModelCapabilities get capabilities => throw _privateConstructorUsedError;

  /// Performance metrics
  ModelPerformanceMetrics? get metrics => throw _privateConstructorUsedError;

  /// Cost information
  ModelCostInfo get costInfo => throw _privateConstructorUsedError;

  /// Deprecation information
  ModelDeprecationInfo? get deprecation => throw _privateConstructorUsedError;

  /// Configuration overrides
  Map<String, dynamic> get configuration => throw _privateConstructorUsedError;

  /// Tags for categorization
  List<String> get tags => throw _privateConstructorUsedError;

  /// Created timestamp
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Last updated timestamp
  DateTime get updatedAt => throw _privateConstructorUsedError;

  /// Version notes/changelog
  String? get releaseNotes => throw _privateConstructorUsedError;

  /// Minimum required confidence threshold
  double get minConfidenceThreshold => throw _privateConstructorUsedError;

  /// Maximum allowed latency (milliseconds)
  int? get maxLatencyMs => throw _privateConstructorUsedError;

  /// Success rate threshold (0.0-1.0)
  double get successRateThreshold => throw _privateConstructorUsedError;

  /// Serializes this ModelVersion to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModelVersionCopyWith<ModelVersion> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelVersionCopyWith<$Res> {
  factory $ModelVersionCopyWith(
    ModelVersion value,
    $Res Function(ModelVersion) then,
  ) = _$ModelVersionCopyWithImpl<$Res, ModelVersion>;
  @useResult
  $Res call({
    String version,
    String modelId,
    String provider,
    String displayName,
    String? description,
    DateTime releaseDate,
    ModelStatus status,
    ModelCapabilities capabilities,
    ModelPerformanceMetrics? metrics,
    ModelCostInfo costInfo,
    ModelDeprecationInfo? deprecation,
    Map<String, dynamic> configuration,
    List<String> tags,
    DateTime createdAt,
    DateTime updatedAt,
    String? releaseNotes,
    double minConfidenceThreshold,
    int? maxLatencyMs,
    double successRateThreshold,
  });

  $ModelCapabilitiesCopyWith<$Res> get capabilities;
  $ModelPerformanceMetricsCopyWith<$Res>? get metrics;
  $ModelCostInfoCopyWith<$Res> get costInfo;
  $ModelDeprecationInfoCopyWith<$Res>? get deprecation;
}

/// @nodoc
class _$ModelVersionCopyWithImpl<$Res, $Val extends ModelVersion>
    implements $ModelVersionCopyWith<$Res> {
  _$ModelVersionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? modelId = null,
    Object? provider = null,
    Object? displayName = null,
    Object? description = freezed,
    Object? releaseDate = null,
    Object? status = null,
    Object? capabilities = null,
    Object? metrics = freezed,
    Object? costInfo = null,
    Object? deprecation = freezed,
    Object? configuration = null,
    Object? tags = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? releaseNotes = freezed,
    Object? minConfidenceThreshold = null,
    Object? maxLatencyMs = freezed,
    Object? successRateThreshold = null,
  }) {
    return _then(
      _value.copyWith(
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as String,
            modelId: null == modelId
                ? _value.modelId
                : modelId // ignore: cast_nullable_to_non_nullable
                      as String,
            provider: null == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                      as String,
            displayName: null == displayName
                ? _value.displayName
                : displayName // ignore: cast_nullable_to_non_nullable
                      as String,
            description: freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String?,
            releaseDate: null == releaseDate
                ? _value.releaseDate
                : releaseDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as ModelStatus,
            capabilities: null == capabilities
                ? _value.capabilities
                : capabilities // ignore: cast_nullable_to_non_nullable
                      as ModelCapabilities,
            metrics: freezed == metrics
                ? _value.metrics
                : metrics // ignore: cast_nullable_to_non_nullable
                      as ModelPerformanceMetrics?,
            costInfo: null == costInfo
                ? _value.costInfo
                : costInfo // ignore: cast_nullable_to_non_nullable
                      as ModelCostInfo,
            deprecation: freezed == deprecation
                ? _value.deprecation
                : deprecation // ignore: cast_nullable_to_non_nullable
                      as ModelDeprecationInfo?,
            configuration: null == configuration
                ? _value.configuration
                : configuration // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
            tags: null == tags
                ? _value.tags
                : tags // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            createdAt: null == createdAt
                ? _value.createdAt
                : createdAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            updatedAt: null == updatedAt
                ? _value.updatedAt
                : updatedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            releaseNotes: freezed == releaseNotes
                ? _value.releaseNotes
                : releaseNotes // ignore: cast_nullable_to_non_nullable
                      as String?,
            minConfidenceThreshold: null == minConfidenceThreshold
                ? _value.minConfidenceThreshold
                : minConfidenceThreshold // ignore: cast_nullable_to_non_nullable
                      as double,
            maxLatencyMs: freezed == maxLatencyMs
                ? _value.maxLatencyMs
                : maxLatencyMs // ignore: cast_nullable_to_non_nullable
                      as int?,
            successRateThreshold: null == successRateThreshold
                ? _value.successRateThreshold
                : successRateThreshold // ignore: cast_nullable_to_non_nullable
                      as double,
          )
          as $Val,
    );
  }

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ModelCapabilitiesCopyWith<$Res> get capabilities {
    return $ModelCapabilitiesCopyWith<$Res>(_value.capabilities, (value) {
      return _then(_value.copyWith(capabilities: value) as $Val);
    });
  }

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ModelPerformanceMetricsCopyWith<$Res>? get metrics {
    if (_value.metrics == null) {
      return null;
    }

    return $ModelPerformanceMetricsCopyWith<$Res>(_value.metrics!, (value) {
      return _then(_value.copyWith(metrics: value) as $Val);
    });
  }

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ModelCostInfoCopyWith<$Res> get costInfo {
    return $ModelCostInfoCopyWith<$Res>(_value.costInfo, (value) {
      return _then(_value.copyWith(costInfo: value) as $Val);
    });
  }

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ModelDeprecationInfoCopyWith<$Res>? get deprecation {
    if (_value.deprecation == null) {
      return null;
    }

    return $ModelDeprecationInfoCopyWith<$Res>(_value.deprecation!, (value) {
      return _then(_value.copyWith(deprecation: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ModelVersionImplCopyWith<$Res>
    implements $ModelVersionCopyWith<$Res> {
  factory _$$ModelVersionImplCopyWith(
    _$ModelVersionImpl value,
    $Res Function(_$ModelVersionImpl) then,
  ) = __$$ModelVersionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String version,
    String modelId,
    String provider,
    String displayName,
    String? description,
    DateTime releaseDate,
    ModelStatus status,
    ModelCapabilities capabilities,
    ModelPerformanceMetrics? metrics,
    ModelCostInfo costInfo,
    ModelDeprecationInfo? deprecation,
    Map<String, dynamic> configuration,
    List<String> tags,
    DateTime createdAt,
    DateTime updatedAt,
    String? releaseNotes,
    double minConfidenceThreshold,
    int? maxLatencyMs,
    double successRateThreshold,
  });

  @override
  $ModelCapabilitiesCopyWith<$Res> get capabilities;
  @override
  $ModelPerformanceMetricsCopyWith<$Res>? get metrics;
  @override
  $ModelCostInfoCopyWith<$Res> get costInfo;
  @override
  $ModelDeprecationInfoCopyWith<$Res>? get deprecation;
}

/// @nodoc
class __$$ModelVersionImplCopyWithImpl<$Res>
    extends _$ModelVersionCopyWithImpl<$Res, _$ModelVersionImpl>
    implements _$$ModelVersionImplCopyWith<$Res> {
  __$$ModelVersionImplCopyWithImpl(
    _$ModelVersionImpl _value,
    $Res Function(_$ModelVersionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? modelId = null,
    Object? provider = null,
    Object? displayName = null,
    Object? description = freezed,
    Object? releaseDate = null,
    Object? status = null,
    Object? capabilities = null,
    Object? metrics = freezed,
    Object? costInfo = null,
    Object? deprecation = freezed,
    Object? configuration = null,
    Object? tags = null,
    Object? createdAt = null,
    Object? updatedAt = null,
    Object? releaseNotes = freezed,
    Object? minConfidenceThreshold = null,
    Object? maxLatencyMs = freezed,
    Object? successRateThreshold = null,
  }) {
    return _then(
      _$ModelVersionImpl(
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as String,
        modelId: null == modelId
            ? _value.modelId
            : modelId // ignore: cast_nullable_to_non_nullable
                  as String,
        provider: null == provider
            ? _value.provider
            : provider // ignore: cast_nullable_to_non_nullable
                  as String,
        displayName: null == displayName
            ? _value.displayName
            : displayName // ignore: cast_nullable_to_non_nullable
                  as String,
        description: freezed == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String?,
        releaseDate: null == releaseDate
            ? _value.releaseDate
            : releaseDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as ModelStatus,
        capabilities: null == capabilities
            ? _value.capabilities
            : capabilities // ignore: cast_nullable_to_non_nullable
                  as ModelCapabilities,
        metrics: freezed == metrics
            ? _value.metrics
            : metrics // ignore: cast_nullable_to_non_nullable
                  as ModelPerformanceMetrics?,
        costInfo: null == costInfo
            ? _value.costInfo
            : costInfo // ignore: cast_nullable_to_non_nullable
                  as ModelCostInfo,
        deprecation: freezed == deprecation
            ? _value.deprecation
            : deprecation // ignore: cast_nullable_to_non_nullable
                  as ModelDeprecationInfo?,
        configuration: null == configuration
            ? _value._configuration
            : configuration // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
        tags: null == tags
            ? _value._tags
            : tags // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        createdAt: null == createdAt
            ? _value.createdAt
            : createdAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        updatedAt: null == updatedAt
            ? _value.updatedAt
            : updatedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        releaseNotes: freezed == releaseNotes
            ? _value.releaseNotes
            : releaseNotes // ignore: cast_nullable_to_non_nullable
                  as String?,
        minConfidenceThreshold: null == minConfidenceThreshold
            ? _value.minConfidenceThreshold
            : minConfidenceThreshold // ignore: cast_nullable_to_non_nullable
                  as double,
        maxLatencyMs: freezed == maxLatencyMs
            ? _value.maxLatencyMs
            : maxLatencyMs // ignore: cast_nullable_to_non_nullable
                  as int?,
        successRateThreshold: null == successRateThreshold
            ? _value.successRateThreshold
            : successRateThreshold // ignore: cast_nullable_to_non_nullable
                  as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModelVersionImpl implements _ModelVersion {
  const _$ModelVersionImpl({
    required this.version,
    required this.modelId,
    required this.provider,
    required this.displayName,
    this.description,
    required this.releaseDate,
    this.status = ModelStatus.inactive,
    required this.capabilities,
    this.metrics,
    required this.costInfo,
    this.deprecation,
    final Map<String, dynamic> configuration = const {},
    final List<String> tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.releaseNotes,
    this.minConfidenceThreshold = 0.7,
    this.maxLatencyMs,
    this.successRateThreshold = 0.95,
  }) : _configuration = configuration,
       _tags = tags;

  factory _$ModelVersionImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModelVersionImplFromJson(json);

  /// Unique version identifier (semantic versioning: major.minor.patch)
  @override
  final String version;

  /// Model identifier (e.g., 'gpt-4-turbo', 'gpt-4.1-mini')
  @override
  final String modelId;

  /// Provider name (OpenAI, Anthropic, etc.)
  @override
  final String provider;

  /// Model display name
  @override
  final String displayName;

  /// Model description
  @override
  final String? description;

  /// Release date
  @override
  final DateTime releaseDate;

  /// Current deployment status
  @override
  @JsonKey()
  final ModelStatus status;

  /// Model capabilities
  @override
  final ModelCapabilities capabilities;

  /// Performance metrics
  @override
  final ModelPerformanceMetrics? metrics;

  /// Cost information
  @override
  final ModelCostInfo costInfo;

  /// Deprecation information
  @override
  final ModelDeprecationInfo? deprecation;

  /// Configuration overrides
  final Map<String, dynamic> _configuration;

  /// Configuration overrides
  @override
  @JsonKey()
  Map<String, dynamic> get configuration {
    if (_configuration is EqualUnmodifiableMapView) return _configuration;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_configuration);
  }

  /// Tags for categorization
  final List<String> _tags;

  /// Tags for categorization
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  /// Created timestamp
  @override
  final DateTime createdAt;

  /// Last updated timestamp
  @override
  final DateTime updatedAt;

  /// Version notes/changelog
  @override
  final String? releaseNotes;

  /// Minimum required confidence threshold
  @override
  @JsonKey()
  final double minConfidenceThreshold;

  /// Maximum allowed latency (milliseconds)
  @override
  final int? maxLatencyMs;

  /// Success rate threshold (0.0-1.0)
  @override
  @JsonKey()
  final double successRateThreshold;

  @override
  String toString() {
    return 'ModelVersion(version: $version, modelId: $modelId, provider: $provider, displayName: $displayName, description: $description, releaseDate: $releaseDate, status: $status, capabilities: $capabilities, metrics: $metrics, costInfo: $costInfo, deprecation: $deprecation, configuration: $configuration, tags: $tags, createdAt: $createdAt, updatedAt: $updatedAt, releaseNotes: $releaseNotes, minConfidenceThreshold: $minConfidenceThreshold, maxLatencyMs: $maxLatencyMs, successRateThreshold: $successRateThreshold)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelVersionImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.modelId, modelId) || other.modelId == modelId) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.releaseDate, releaseDate) ||
                other.releaseDate == releaseDate) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.capabilities, capabilities) ||
                other.capabilities == capabilities) &&
            (identical(other.metrics, metrics) || other.metrics == metrics) &&
            (identical(other.costInfo, costInfo) ||
                other.costInfo == costInfo) &&
            (identical(other.deprecation, deprecation) ||
                other.deprecation == deprecation) &&
            const DeepCollectionEquality().equals(
              other._configuration,
              _configuration,
            ) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.releaseNotes, releaseNotes) ||
                other.releaseNotes == releaseNotes) &&
            (identical(other.minConfidenceThreshold, minConfidenceThreshold) ||
                other.minConfidenceThreshold == minConfidenceThreshold) &&
            (identical(other.maxLatencyMs, maxLatencyMs) ||
                other.maxLatencyMs == maxLatencyMs) &&
            (identical(other.successRateThreshold, successRateThreshold) ||
                other.successRateThreshold == successRateThreshold));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    version,
    modelId,
    provider,
    displayName,
    description,
    releaseDate,
    status,
    capabilities,
    metrics,
    costInfo,
    deprecation,
    const DeepCollectionEquality().hash(_configuration),
    const DeepCollectionEquality().hash(_tags),
    createdAt,
    updatedAt,
    releaseNotes,
    minConfidenceThreshold,
    maxLatencyMs,
    successRateThreshold,
  ]);

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelVersionImplCopyWith<_$ModelVersionImpl> get copyWith =>
      __$$ModelVersionImplCopyWithImpl<_$ModelVersionImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ModelVersionImplToJson(this);
  }
}

abstract class _ModelVersion implements ModelVersion {
  const factory _ModelVersion({
    required final String version,
    required final String modelId,
    required final String provider,
    required final String displayName,
    final String? description,
    required final DateTime releaseDate,
    final ModelStatus status,
    required final ModelCapabilities capabilities,
    final ModelPerformanceMetrics? metrics,
    required final ModelCostInfo costInfo,
    final ModelDeprecationInfo? deprecation,
    final Map<String, dynamic> configuration,
    final List<String> tags,
    required final DateTime createdAt,
    required final DateTime updatedAt,
    final String? releaseNotes,
    final double minConfidenceThreshold,
    final int? maxLatencyMs,
    final double successRateThreshold,
  }) = _$ModelVersionImpl;

  factory _ModelVersion.fromJson(Map<String, dynamic> json) =
      _$ModelVersionImpl.fromJson;

  /// Unique version identifier (semantic versioning: major.minor.patch)
  @override
  String get version;

  /// Model identifier (e.g., 'gpt-4-turbo', 'gpt-4.1-mini')
  @override
  String get modelId;

  /// Provider name (OpenAI, Anthropic, etc.)
  @override
  String get provider;

  /// Model display name
  @override
  String get displayName;

  /// Model description
  @override
  String? get description;

  /// Release date
  @override
  DateTime get releaseDate;

  /// Current deployment status
  @override
  ModelStatus get status;

  /// Model capabilities
  @override
  ModelCapabilities get capabilities;

  /// Performance metrics
  @override
  ModelPerformanceMetrics? get metrics;

  /// Cost information
  @override
  ModelCostInfo get costInfo;

  /// Deprecation information
  @override
  ModelDeprecationInfo? get deprecation;

  /// Configuration overrides
  @override
  Map<String, dynamic> get configuration;

  /// Tags for categorization
  @override
  List<String> get tags;

  /// Created timestamp
  @override
  DateTime get createdAt;

  /// Last updated timestamp
  @override
  DateTime get updatedAt;

  /// Version notes/changelog
  @override
  String? get releaseNotes;

  /// Minimum required confidence threshold
  @override
  double get minConfidenceThreshold;

  /// Maximum allowed latency (milliseconds)
  @override
  int? get maxLatencyMs;

  /// Success rate threshold (0.0-1.0)
  @override
  double get successRateThreshold;

  /// Create a copy of ModelVersion
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModelVersionImplCopyWith<_$ModelVersionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ModelCapabilities _$ModelCapabilitiesFromJson(Map<String, dynamic> json) {
  return _ModelCapabilities.fromJson(json);
}

/// @nodoc
mixin _$ModelCapabilities {
  /// Supports streaming responses
  bool get supportsStreaming => throw _privateConstructorUsedError;

  /// Supports function/tool calling
  bool get supportsFunctionCalling => throw _privateConstructorUsedError;

  /// Supports vision/image inputs
  bool get supportsVision => throw _privateConstructorUsedError;

  /// Supports audio transcription
  bool get supportsAudioTranscription => throw _privateConstructorUsedError;

  /// Maximum context window (tokens)
  int get maxContextTokens => throw _privateConstructorUsedError;

  /// Maximum output tokens
  int get maxOutputTokens => throw _privateConstructorUsedError;

  /// Supported languages
  List<String> get supportedLanguages => throw _privateConstructorUsedError;

  /// Supported analysis types
  List<String> get supportedAnalysisTypes => throw _privateConstructorUsedError;

  /// Serializes this ModelCapabilities to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ModelCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModelCapabilitiesCopyWith<ModelCapabilities> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelCapabilitiesCopyWith<$Res> {
  factory $ModelCapabilitiesCopyWith(
    ModelCapabilities value,
    $Res Function(ModelCapabilities) then,
  ) = _$ModelCapabilitiesCopyWithImpl<$Res, ModelCapabilities>;
  @useResult
  $Res call({
    bool supportsStreaming,
    bool supportsFunctionCalling,
    bool supportsVision,
    bool supportsAudioTranscription,
    int maxContextTokens,
    int maxOutputTokens,
    List<String> supportedLanguages,
    List<String> supportedAnalysisTypes,
  });
}

/// @nodoc
class _$ModelCapabilitiesCopyWithImpl<$Res, $Val extends ModelCapabilities>
    implements $ModelCapabilitiesCopyWith<$Res> {
  _$ModelCapabilitiesCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModelCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supportsStreaming = null,
    Object? supportsFunctionCalling = null,
    Object? supportsVision = null,
    Object? supportsAudioTranscription = null,
    Object? maxContextTokens = null,
    Object? maxOutputTokens = null,
    Object? supportedLanguages = null,
    Object? supportedAnalysisTypes = null,
  }) {
    return _then(
      _value.copyWith(
            supportsStreaming: null == supportsStreaming
                ? _value.supportsStreaming
                : supportsStreaming // ignore: cast_nullable_to_non_nullable
                      as bool,
            supportsFunctionCalling: null == supportsFunctionCalling
                ? _value.supportsFunctionCalling
                : supportsFunctionCalling // ignore: cast_nullable_to_non_nullable
                      as bool,
            supportsVision: null == supportsVision
                ? _value.supportsVision
                : supportsVision // ignore: cast_nullable_to_non_nullable
                      as bool,
            supportsAudioTranscription: null == supportsAudioTranscription
                ? _value.supportsAudioTranscription
                : supportsAudioTranscription // ignore: cast_nullable_to_non_nullable
                      as bool,
            maxContextTokens: null == maxContextTokens
                ? _value.maxContextTokens
                : maxContextTokens // ignore: cast_nullable_to_non_nullable
                      as int,
            maxOutputTokens: null == maxOutputTokens
                ? _value.maxOutputTokens
                : maxOutputTokens // ignore: cast_nullable_to_non_nullable
                      as int,
            supportedLanguages: null == supportedLanguages
                ? _value.supportedLanguages
                : supportedLanguages // ignore: cast_nullable_to_non_nullable
                      as List<String>,
            supportedAnalysisTypes: null == supportedAnalysisTypes
                ? _value.supportedAnalysisTypes
                : supportedAnalysisTypes // ignore: cast_nullable_to_non_nullable
                      as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModelCapabilitiesImplCopyWith<$Res>
    implements $ModelCapabilitiesCopyWith<$Res> {
  factory _$$ModelCapabilitiesImplCopyWith(
    _$ModelCapabilitiesImpl value,
    $Res Function(_$ModelCapabilitiesImpl) then,
  ) = __$$ModelCapabilitiesImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    bool supportsStreaming,
    bool supportsFunctionCalling,
    bool supportsVision,
    bool supportsAudioTranscription,
    int maxContextTokens,
    int maxOutputTokens,
    List<String> supportedLanguages,
    List<String> supportedAnalysisTypes,
  });
}

/// @nodoc
class __$$ModelCapabilitiesImplCopyWithImpl<$Res>
    extends _$ModelCapabilitiesCopyWithImpl<$Res, _$ModelCapabilitiesImpl>
    implements _$$ModelCapabilitiesImplCopyWith<$Res> {
  __$$ModelCapabilitiesImplCopyWithImpl(
    _$ModelCapabilitiesImpl _value,
    $Res Function(_$ModelCapabilitiesImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModelCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? supportsStreaming = null,
    Object? supportsFunctionCalling = null,
    Object? supportsVision = null,
    Object? supportsAudioTranscription = null,
    Object? maxContextTokens = null,
    Object? maxOutputTokens = null,
    Object? supportedLanguages = null,
    Object? supportedAnalysisTypes = null,
  }) {
    return _then(
      _$ModelCapabilitiesImpl(
        supportsStreaming: null == supportsStreaming
            ? _value.supportsStreaming
            : supportsStreaming // ignore: cast_nullable_to_non_nullable
                  as bool,
        supportsFunctionCalling: null == supportsFunctionCalling
            ? _value.supportsFunctionCalling
            : supportsFunctionCalling // ignore: cast_nullable_to_non_nullable
                  as bool,
        supportsVision: null == supportsVision
            ? _value.supportsVision
            : supportsVision // ignore: cast_nullable_to_non_nullable
                  as bool,
        supportsAudioTranscription: null == supportsAudioTranscription
            ? _value.supportsAudioTranscription
            : supportsAudioTranscription // ignore: cast_nullable_to_non_nullable
                  as bool,
        maxContextTokens: null == maxContextTokens
            ? _value.maxContextTokens
            : maxContextTokens // ignore: cast_nullable_to_non_nullable
                  as int,
        maxOutputTokens: null == maxOutputTokens
            ? _value.maxOutputTokens
            : maxOutputTokens // ignore: cast_nullable_to_non_nullable
                  as int,
        supportedLanguages: null == supportedLanguages
            ? _value._supportedLanguages
            : supportedLanguages // ignore: cast_nullable_to_non_nullable
                  as List<String>,
        supportedAnalysisTypes: null == supportedAnalysisTypes
            ? _value._supportedAnalysisTypes
            : supportedAnalysisTypes // ignore: cast_nullable_to_non_nullable
                  as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModelCapabilitiesImpl implements _ModelCapabilities {
  const _$ModelCapabilitiesImpl({
    this.supportsStreaming = false,
    this.supportsFunctionCalling = false,
    this.supportsVision = false,
    this.supportsAudioTranscription = false,
    required this.maxContextTokens,
    required this.maxOutputTokens,
    final List<String> supportedLanguages = const ['en'],
    final List<String> supportedAnalysisTypes = const [],
  }) : _supportedLanguages = supportedLanguages,
       _supportedAnalysisTypes = supportedAnalysisTypes;

  factory _$ModelCapabilitiesImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModelCapabilitiesImplFromJson(json);

  /// Supports streaming responses
  @override
  @JsonKey()
  final bool supportsStreaming;

  /// Supports function/tool calling
  @override
  @JsonKey()
  final bool supportsFunctionCalling;

  /// Supports vision/image inputs
  @override
  @JsonKey()
  final bool supportsVision;

  /// Supports audio transcription
  @override
  @JsonKey()
  final bool supportsAudioTranscription;

  /// Maximum context window (tokens)
  @override
  final int maxContextTokens;

  /// Maximum output tokens
  @override
  final int maxOutputTokens;

  /// Supported languages
  final List<String> _supportedLanguages;

  /// Supported languages
  @override
  @JsonKey()
  List<String> get supportedLanguages {
    if (_supportedLanguages is EqualUnmodifiableListView)
      return _supportedLanguages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supportedLanguages);
  }

  /// Supported analysis types
  final List<String> _supportedAnalysisTypes;

  /// Supported analysis types
  @override
  @JsonKey()
  List<String> get supportedAnalysisTypes {
    if (_supportedAnalysisTypes is EqualUnmodifiableListView)
      return _supportedAnalysisTypes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_supportedAnalysisTypes);
  }

  @override
  String toString() {
    return 'ModelCapabilities(supportsStreaming: $supportsStreaming, supportsFunctionCalling: $supportsFunctionCalling, supportsVision: $supportsVision, supportsAudioTranscription: $supportsAudioTranscription, maxContextTokens: $maxContextTokens, maxOutputTokens: $maxOutputTokens, supportedLanguages: $supportedLanguages, supportedAnalysisTypes: $supportedAnalysisTypes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelCapabilitiesImpl &&
            (identical(other.supportsStreaming, supportsStreaming) ||
                other.supportsStreaming == supportsStreaming) &&
            (identical(
                  other.supportsFunctionCalling,
                  supportsFunctionCalling,
                ) ||
                other.supportsFunctionCalling == supportsFunctionCalling) &&
            (identical(other.supportsVision, supportsVision) ||
                other.supportsVision == supportsVision) &&
            (identical(
                  other.supportsAudioTranscription,
                  supportsAudioTranscription,
                ) ||
                other.supportsAudioTranscription ==
                    supportsAudioTranscription) &&
            (identical(other.maxContextTokens, maxContextTokens) ||
                other.maxContextTokens == maxContextTokens) &&
            (identical(other.maxOutputTokens, maxOutputTokens) ||
                other.maxOutputTokens == maxOutputTokens) &&
            const DeepCollectionEquality().equals(
              other._supportedLanguages,
              _supportedLanguages,
            ) &&
            const DeepCollectionEquality().equals(
              other._supportedAnalysisTypes,
              _supportedAnalysisTypes,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    supportsStreaming,
    supportsFunctionCalling,
    supportsVision,
    supportsAudioTranscription,
    maxContextTokens,
    maxOutputTokens,
    const DeepCollectionEquality().hash(_supportedLanguages),
    const DeepCollectionEquality().hash(_supportedAnalysisTypes),
  );

  /// Create a copy of ModelCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelCapabilitiesImplCopyWith<_$ModelCapabilitiesImpl> get copyWith =>
      __$$ModelCapabilitiesImplCopyWithImpl<_$ModelCapabilitiesImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ModelCapabilitiesImplToJson(this);
  }
}

abstract class _ModelCapabilities implements ModelCapabilities {
  const factory _ModelCapabilities({
    final bool supportsStreaming,
    final bool supportsFunctionCalling,
    final bool supportsVision,
    final bool supportsAudioTranscription,
    required final int maxContextTokens,
    required final int maxOutputTokens,
    final List<String> supportedLanguages,
    final List<String> supportedAnalysisTypes,
  }) = _$ModelCapabilitiesImpl;

  factory _ModelCapabilities.fromJson(Map<String, dynamic> json) =
      _$ModelCapabilitiesImpl.fromJson;

  /// Supports streaming responses
  @override
  bool get supportsStreaming;

  /// Supports function/tool calling
  @override
  bool get supportsFunctionCalling;

  /// Supports vision/image inputs
  @override
  bool get supportsVision;

  /// Supports audio transcription
  @override
  bool get supportsAudioTranscription;

  /// Maximum context window (tokens)
  @override
  int get maxContextTokens;

  /// Maximum output tokens
  @override
  int get maxOutputTokens;

  /// Supported languages
  @override
  List<String> get supportedLanguages;

  /// Supported analysis types
  @override
  List<String> get supportedAnalysisTypes;

  /// Create a copy of ModelCapabilities
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModelCapabilitiesImplCopyWith<_$ModelCapabilitiesImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ModelPerformanceMetrics _$ModelPerformanceMetricsFromJson(
  Map<String, dynamic> json,
) {
  return _ModelPerformanceMetrics.fromJson(json);
}

/// @nodoc
mixin _$ModelPerformanceMetrics {
  /// Average response latency (milliseconds)
  double get avgLatencyMs => throw _privateConstructorUsedError;

  /// P95 latency (milliseconds)
  double get p95LatencyMs => throw _privateConstructorUsedError;

  /// P99 latency (milliseconds)
  double get p99LatencyMs => throw _privateConstructorUsedError;

  /// Success rate (0.0-1.0)
  double get successRate => throw _privateConstructorUsedError;

  /// Error rate (0.0-1.0)
  double get errorRate => throw _privateConstructorUsedError;

  /// Average confidence score
  double get avgConfidence => throw _privateConstructorUsedError;

  /// Total requests processed
  int get totalRequests => throw _privateConstructorUsedError;

  /// Total successful requests
  int get successfulRequests => throw _privateConstructorUsedError;

  /// Total failed requests
  int get failedRequests => throw _privateConstructorUsedError;

  /// Average tokens per request
  double? get avgTokensPerRequest => throw _privateConstructorUsedError;

  /// Cost per 1000 requests
  double? get costPer1kRequests => throw _privateConstructorUsedError;

  /// Last updated timestamp
  DateTime get lastUpdated => throw _privateConstructorUsedError;

  /// Evaluation scores by category
  Map<String, double> get evaluationScores =>
      throw _privateConstructorUsedError;

  /// Serializes this ModelPerformanceMetrics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ModelPerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModelPerformanceMetricsCopyWith<ModelPerformanceMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelPerformanceMetricsCopyWith<$Res> {
  factory $ModelPerformanceMetricsCopyWith(
    ModelPerformanceMetrics value,
    $Res Function(ModelPerformanceMetrics) then,
  ) = _$ModelPerformanceMetricsCopyWithImpl<$Res, ModelPerformanceMetrics>;
  @useResult
  $Res call({
    double avgLatencyMs,
    double p95LatencyMs,
    double p99LatencyMs,
    double successRate,
    double errorRate,
    double avgConfidence,
    int totalRequests,
    int successfulRequests,
    int failedRequests,
    double? avgTokensPerRequest,
    double? costPer1kRequests,
    DateTime lastUpdated,
    Map<String, double> evaluationScores,
  });
}

/// @nodoc
class _$ModelPerformanceMetricsCopyWithImpl<
  $Res,
  $Val extends ModelPerformanceMetrics
>
    implements $ModelPerformanceMetricsCopyWith<$Res> {
  _$ModelPerformanceMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModelPerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? avgLatencyMs = null,
    Object? p95LatencyMs = null,
    Object? p99LatencyMs = null,
    Object? successRate = null,
    Object? errorRate = null,
    Object? avgConfidence = null,
    Object? totalRequests = null,
    Object? successfulRequests = null,
    Object? failedRequests = null,
    Object? avgTokensPerRequest = freezed,
    Object? costPer1kRequests = freezed,
    Object? lastUpdated = null,
    Object? evaluationScores = null,
  }) {
    return _then(
      _value.copyWith(
            avgLatencyMs: null == avgLatencyMs
                ? _value.avgLatencyMs
                : avgLatencyMs // ignore: cast_nullable_to_non_nullable
                      as double,
            p95LatencyMs: null == p95LatencyMs
                ? _value.p95LatencyMs
                : p95LatencyMs // ignore: cast_nullable_to_non_nullable
                      as double,
            p99LatencyMs: null == p99LatencyMs
                ? _value.p99LatencyMs
                : p99LatencyMs // ignore: cast_nullable_to_non_nullable
                      as double,
            successRate: null == successRate
                ? _value.successRate
                : successRate // ignore: cast_nullable_to_non_nullable
                      as double,
            errorRate: null == errorRate
                ? _value.errorRate
                : errorRate // ignore: cast_nullable_to_non_nullable
                      as double,
            avgConfidence: null == avgConfidence
                ? _value.avgConfidence
                : avgConfidence // ignore: cast_nullable_to_non_nullable
                      as double,
            totalRequests: null == totalRequests
                ? _value.totalRequests
                : totalRequests // ignore: cast_nullable_to_non_nullable
                      as int,
            successfulRequests: null == successfulRequests
                ? _value.successfulRequests
                : successfulRequests // ignore: cast_nullable_to_non_nullable
                      as int,
            failedRequests: null == failedRequests
                ? _value.failedRequests
                : failedRequests // ignore: cast_nullable_to_non_nullable
                      as int,
            avgTokensPerRequest: freezed == avgTokensPerRequest
                ? _value.avgTokensPerRequest
                : avgTokensPerRequest // ignore: cast_nullable_to_non_nullable
                      as double?,
            costPer1kRequests: freezed == costPer1kRequests
                ? _value.costPer1kRequests
                : costPer1kRequests // ignore: cast_nullable_to_non_nullable
                      as double?,
            lastUpdated: null == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            evaluationScores: null == evaluationScores
                ? _value.evaluationScores
                : evaluationScores // ignore: cast_nullable_to_non_nullable
                      as Map<String, double>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModelPerformanceMetricsImplCopyWith<$Res>
    implements $ModelPerformanceMetricsCopyWith<$Res> {
  factory _$$ModelPerformanceMetricsImplCopyWith(
    _$ModelPerformanceMetricsImpl value,
    $Res Function(_$ModelPerformanceMetricsImpl) then,
  ) = __$$ModelPerformanceMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double avgLatencyMs,
    double p95LatencyMs,
    double p99LatencyMs,
    double successRate,
    double errorRate,
    double avgConfidence,
    int totalRequests,
    int successfulRequests,
    int failedRequests,
    double? avgTokensPerRequest,
    double? costPer1kRequests,
    DateTime lastUpdated,
    Map<String, double> evaluationScores,
  });
}

/// @nodoc
class __$$ModelPerformanceMetricsImplCopyWithImpl<$Res>
    extends
        _$ModelPerformanceMetricsCopyWithImpl<
          $Res,
          _$ModelPerformanceMetricsImpl
        >
    implements _$$ModelPerformanceMetricsImplCopyWith<$Res> {
  __$$ModelPerformanceMetricsImplCopyWithImpl(
    _$ModelPerformanceMetricsImpl _value,
    $Res Function(_$ModelPerformanceMetricsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModelPerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? avgLatencyMs = null,
    Object? p95LatencyMs = null,
    Object? p99LatencyMs = null,
    Object? successRate = null,
    Object? errorRate = null,
    Object? avgConfidence = null,
    Object? totalRequests = null,
    Object? successfulRequests = null,
    Object? failedRequests = null,
    Object? avgTokensPerRequest = freezed,
    Object? costPer1kRequests = freezed,
    Object? lastUpdated = null,
    Object? evaluationScores = null,
  }) {
    return _then(
      _$ModelPerformanceMetricsImpl(
        avgLatencyMs: null == avgLatencyMs
            ? _value.avgLatencyMs
            : avgLatencyMs // ignore: cast_nullable_to_non_nullable
                  as double,
        p95LatencyMs: null == p95LatencyMs
            ? _value.p95LatencyMs
            : p95LatencyMs // ignore: cast_nullable_to_non_nullable
                  as double,
        p99LatencyMs: null == p99LatencyMs
            ? _value.p99LatencyMs
            : p99LatencyMs // ignore: cast_nullable_to_non_nullable
                  as double,
        successRate: null == successRate
            ? _value.successRate
            : successRate // ignore: cast_nullable_to_non_nullable
                  as double,
        errorRate: null == errorRate
            ? _value.errorRate
            : errorRate // ignore: cast_nullable_to_non_nullable
                  as double,
        avgConfidence: null == avgConfidence
            ? _value.avgConfidence
            : avgConfidence // ignore: cast_nullable_to_non_nullable
                  as double,
        totalRequests: null == totalRequests
            ? _value.totalRequests
            : totalRequests // ignore: cast_nullable_to_non_nullable
                  as int,
        successfulRequests: null == successfulRequests
            ? _value.successfulRequests
            : successfulRequests // ignore: cast_nullable_to_non_nullable
                  as int,
        failedRequests: null == failedRequests
            ? _value.failedRequests
            : failedRequests // ignore: cast_nullable_to_non_nullable
                  as int,
        avgTokensPerRequest: freezed == avgTokensPerRequest
            ? _value.avgTokensPerRequest
            : avgTokensPerRequest // ignore: cast_nullable_to_non_nullable
                  as double?,
        costPer1kRequests: freezed == costPer1kRequests
            ? _value.costPer1kRequests
            : costPer1kRequests // ignore: cast_nullable_to_non_nullable
                  as double?,
        lastUpdated: null == lastUpdated
            ? _value.lastUpdated
            : lastUpdated // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        evaluationScores: null == evaluationScores
            ? _value._evaluationScores
            : evaluationScores // ignore: cast_nullable_to_non_nullable
                  as Map<String, double>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModelPerformanceMetricsImpl implements _ModelPerformanceMetrics {
  const _$ModelPerformanceMetricsImpl({
    required this.avgLatencyMs,
    required this.p95LatencyMs,
    required this.p99LatencyMs,
    required this.successRate,
    required this.errorRate,
    required this.avgConfidence,
    this.totalRequests = 0,
    this.successfulRequests = 0,
    this.failedRequests = 0,
    this.avgTokensPerRequest,
    this.costPer1kRequests,
    required this.lastUpdated,
    final Map<String, double> evaluationScores = const {},
  }) : _evaluationScores = evaluationScores;

  factory _$ModelPerformanceMetricsImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModelPerformanceMetricsImplFromJson(json);

  /// Average response latency (milliseconds)
  @override
  final double avgLatencyMs;

  /// P95 latency (milliseconds)
  @override
  final double p95LatencyMs;

  /// P99 latency (milliseconds)
  @override
  final double p99LatencyMs;

  /// Success rate (0.0-1.0)
  @override
  final double successRate;

  /// Error rate (0.0-1.0)
  @override
  final double errorRate;

  /// Average confidence score
  @override
  final double avgConfidence;

  /// Total requests processed
  @override
  @JsonKey()
  final int totalRequests;

  /// Total successful requests
  @override
  @JsonKey()
  final int successfulRequests;

  /// Total failed requests
  @override
  @JsonKey()
  final int failedRequests;

  /// Average tokens per request
  @override
  final double? avgTokensPerRequest;

  /// Cost per 1000 requests
  @override
  final double? costPer1kRequests;

  /// Last updated timestamp
  @override
  final DateTime lastUpdated;

  /// Evaluation scores by category
  final Map<String, double> _evaluationScores;

  /// Evaluation scores by category
  @override
  @JsonKey()
  Map<String, double> get evaluationScores {
    if (_evaluationScores is EqualUnmodifiableMapView) return _evaluationScores;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_evaluationScores);
  }

  @override
  String toString() {
    return 'ModelPerformanceMetrics(avgLatencyMs: $avgLatencyMs, p95LatencyMs: $p95LatencyMs, p99LatencyMs: $p99LatencyMs, successRate: $successRate, errorRate: $errorRate, avgConfidence: $avgConfidence, totalRequests: $totalRequests, successfulRequests: $successfulRequests, failedRequests: $failedRequests, avgTokensPerRequest: $avgTokensPerRequest, costPer1kRequests: $costPer1kRequests, lastUpdated: $lastUpdated, evaluationScores: $evaluationScores)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelPerformanceMetricsImpl &&
            (identical(other.avgLatencyMs, avgLatencyMs) ||
                other.avgLatencyMs == avgLatencyMs) &&
            (identical(other.p95LatencyMs, p95LatencyMs) ||
                other.p95LatencyMs == p95LatencyMs) &&
            (identical(other.p99LatencyMs, p99LatencyMs) ||
                other.p99LatencyMs == p99LatencyMs) &&
            (identical(other.successRate, successRate) ||
                other.successRate == successRate) &&
            (identical(other.errorRate, errorRate) ||
                other.errorRate == errorRate) &&
            (identical(other.avgConfidence, avgConfidence) ||
                other.avgConfidence == avgConfidence) &&
            (identical(other.totalRequests, totalRequests) ||
                other.totalRequests == totalRequests) &&
            (identical(other.successfulRequests, successfulRequests) ||
                other.successfulRequests == successfulRequests) &&
            (identical(other.failedRequests, failedRequests) ||
                other.failedRequests == failedRequests) &&
            (identical(other.avgTokensPerRequest, avgTokensPerRequest) ||
                other.avgTokensPerRequest == avgTokensPerRequest) &&
            (identical(other.costPer1kRequests, costPer1kRequests) ||
                other.costPer1kRequests == costPer1kRequests) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated) &&
            const DeepCollectionEquality().equals(
              other._evaluationScores,
              _evaluationScores,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    avgLatencyMs,
    p95LatencyMs,
    p99LatencyMs,
    successRate,
    errorRate,
    avgConfidence,
    totalRequests,
    successfulRequests,
    failedRequests,
    avgTokensPerRequest,
    costPer1kRequests,
    lastUpdated,
    const DeepCollectionEquality().hash(_evaluationScores),
  );

  /// Create a copy of ModelPerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelPerformanceMetricsImplCopyWith<_$ModelPerformanceMetricsImpl>
  get copyWith =>
      __$$ModelPerformanceMetricsImplCopyWithImpl<
        _$ModelPerformanceMetricsImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ModelPerformanceMetricsImplToJson(this);
  }
}

abstract class _ModelPerformanceMetrics implements ModelPerformanceMetrics {
  const factory _ModelPerformanceMetrics({
    required final double avgLatencyMs,
    required final double p95LatencyMs,
    required final double p99LatencyMs,
    required final double successRate,
    required final double errorRate,
    required final double avgConfidence,
    final int totalRequests,
    final int successfulRequests,
    final int failedRequests,
    final double? avgTokensPerRequest,
    final double? costPer1kRequests,
    required final DateTime lastUpdated,
    final Map<String, double> evaluationScores,
  }) = _$ModelPerformanceMetricsImpl;

  factory _ModelPerformanceMetrics.fromJson(Map<String, dynamic> json) =
      _$ModelPerformanceMetricsImpl.fromJson;

  /// Average response latency (milliseconds)
  @override
  double get avgLatencyMs;

  /// P95 latency (milliseconds)
  @override
  double get p95LatencyMs;

  /// P99 latency (milliseconds)
  @override
  double get p99LatencyMs;

  /// Success rate (0.0-1.0)
  @override
  double get successRate;

  /// Error rate (0.0-1.0)
  @override
  double get errorRate;

  /// Average confidence score
  @override
  double get avgConfidence;

  /// Total requests processed
  @override
  int get totalRequests;

  /// Total successful requests
  @override
  int get successfulRequests;

  /// Total failed requests
  @override
  int get failedRequests;

  /// Average tokens per request
  @override
  double? get avgTokensPerRequest;

  /// Cost per 1000 requests
  @override
  double? get costPer1kRequests;

  /// Last updated timestamp
  @override
  DateTime get lastUpdated;

  /// Evaluation scores by category
  @override
  Map<String, double> get evaluationScores;

  /// Create a copy of ModelPerformanceMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModelPerformanceMetricsImplCopyWith<_$ModelPerformanceMetricsImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ModelCostInfo _$ModelCostInfoFromJson(Map<String, dynamic> json) {
  return _ModelCostInfo.fromJson(json);
}

/// @nodoc
mixin _$ModelCostInfo {
  /// Cost per 1K input tokens (USD)
  double get inputCostPer1k => throw _privateConstructorUsedError;

  /// Cost per 1K output tokens (USD)
  double get outputCostPer1k => throw _privateConstructorUsedError;

  /// Cost tier (economy, standard, premium)
  CostTier get tier => throw _privateConstructorUsedError;

  /// Estimated monthly cost at current usage
  double? get estimatedMonthlyCost => throw _privateConstructorUsedError;

  /// Currency code
  String get currency => throw _privateConstructorUsedError;

  /// Serializes this ModelCostInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ModelCostInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModelCostInfoCopyWith<ModelCostInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelCostInfoCopyWith<$Res> {
  factory $ModelCostInfoCopyWith(
    ModelCostInfo value,
    $Res Function(ModelCostInfo) then,
  ) = _$ModelCostInfoCopyWithImpl<$Res, ModelCostInfo>;
  @useResult
  $Res call({
    double inputCostPer1k,
    double outputCostPer1k,
    CostTier tier,
    double? estimatedMonthlyCost,
    String currency,
  });
}

/// @nodoc
class _$ModelCostInfoCopyWithImpl<$Res, $Val extends ModelCostInfo>
    implements $ModelCostInfoCopyWith<$Res> {
  _$ModelCostInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModelCostInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputCostPer1k = null,
    Object? outputCostPer1k = null,
    Object? tier = null,
    Object? estimatedMonthlyCost = freezed,
    Object? currency = null,
  }) {
    return _then(
      _value.copyWith(
            inputCostPer1k: null == inputCostPer1k
                ? _value.inputCostPer1k
                : inputCostPer1k // ignore: cast_nullable_to_non_nullable
                      as double,
            outputCostPer1k: null == outputCostPer1k
                ? _value.outputCostPer1k
                : outputCostPer1k // ignore: cast_nullable_to_non_nullable
                      as double,
            tier: null == tier
                ? _value.tier
                : tier // ignore: cast_nullable_to_non_nullable
                      as CostTier,
            estimatedMonthlyCost: freezed == estimatedMonthlyCost
                ? _value.estimatedMonthlyCost
                : estimatedMonthlyCost // ignore: cast_nullable_to_non_nullable
                      as double?,
            currency: null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModelCostInfoImplCopyWith<$Res>
    implements $ModelCostInfoCopyWith<$Res> {
  factory _$$ModelCostInfoImplCopyWith(
    _$ModelCostInfoImpl value,
    $Res Function(_$ModelCostInfoImpl) then,
  ) = __$$ModelCostInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double inputCostPer1k,
    double outputCostPer1k,
    CostTier tier,
    double? estimatedMonthlyCost,
    String currency,
  });
}

/// @nodoc
class __$$ModelCostInfoImplCopyWithImpl<$Res>
    extends _$ModelCostInfoCopyWithImpl<$Res, _$ModelCostInfoImpl>
    implements _$$ModelCostInfoImplCopyWith<$Res> {
  __$$ModelCostInfoImplCopyWithImpl(
    _$ModelCostInfoImpl _value,
    $Res Function(_$ModelCostInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModelCostInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? inputCostPer1k = null,
    Object? outputCostPer1k = null,
    Object? tier = null,
    Object? estimatedMonthlyCost = freezed,
    Object? currency = null,
  }) {
    return _then(
      _$ModelCostInfoImpl(
        inputCostPer1k: null == inputCostPer1k
            ? _value.inputCostPer1k
            : inputCostPer1k // ignore: cast_nullable_to_non_nullable
                  as double,
        outputCostPer1k: null == outputCostPer1k
            ? _value.outputCostPer1k
            : outputCostPer1k // ignore: cast_nullable_to_non_nullable
                  as double,
        tier: null == tier
            ? _value.tier
            : tier // ignore: cast_nullable_to_non_nullable
                  as CostTier,
        estimatedMonthlyCost: freezed == estimatedMonthlyCost
            ? _value.estimatedMonthlyCost
            : estimatedMonthlyCost // ignore: cast_nullable_to_non_nullable
                  as double?,
        currency: null == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModelCostInfoImpl implements _ModelCostInfo {
  const _$ModelCostInfoImpl({
    required this.inputCostPer1k,
    required this.outputCostPer1k,
    this.tier = CostTier.standard,
    this.estimatedMonthlyCost,
    this.currency = 'USD',
  });

  factory _$ModelCostInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModelCostInfoImplFromJson(json);

  /// Cost per 1K input tokens (USD)
  @override
  final double inputCostPer1k;

  /// Cost per 1K output tokens (USD)
  @override
  final double outputCostPer1k;

  /// Cost tier (economy, standard, premium)
  @override
  @JsonKey()
  final CostTier tier;

  /// Estimated monthly cost at current usage
  @override
  final double? estimatedMonthlyCost;

  /// Currency code
  @override
  @JsonKey()
  final String currency;

  @override
  String toString() {
    return 'ModelCostInfo(inputCostPer1k: $inputCostPer1k, outputCostPer1k: $outputCostPer1k, tier: $tier, estimatedMonthlyCost: $estimatedMonthlyCost, currency: $currency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelCostInfoImpl &&
            (identical(other.inputCostPer1k, inputCostPer1k) ||
                other.inputCostPer1k == inputCostPer1k) &&
            (identical(other.outputCostPer1k, outputCostPer1k) ||
                other.outputCostPer1k == outputCostPer1k) &&
            (identical(other.tier, tier) || other.tier == tier) &&
            (identical(other.estimatedMonthlyCost, estimatedMonthlyCost) ||
                other.estimatedMonthlyCost == estimatedMonthlyCost) &&
            (identical(other.currency, currency) ||
                other.currency == currency));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    inputCostPer1k,
    outputCostPer1k,
    tier,
    estimatedMonthlyCost,
    currency,
  );

  /// Create a copy of ModelCostInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelCostInfoImplCopyWith<_$ModelCostInfoImpl> get copyWith =>
      __$$ModelCostInfoImplCopyWithImpl<_$ModelCostInfoImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ModelCostInfoImplToJson(this);
  }
}

abstract class _ModelCostInfo implements ModelCostInfo {
  const factory _ModelCostInfo({
    required final double inputCostPer1k,
    required final double outputCostPer1k,
    final CostTier tier,
    final double? estimatedMonthlyCost,
    final String currency,
  }) = _$ModelCostInfoImpl;

  factory _ModelCostInfo.fromJson(Map<String, dynamic> json) =
      _$ModelCostInfoImpl.fromJson;

  /// Cost per 1K input tokens (USD)
  @override
  double get inputCostPer1k;

  /// Cost per 1K output tokens (USD)
  @override
  double get outputCostPer1k;

  /// Cost tier (economy, standard, premium)
  @override
  CostTier get tier;

  /// Estimated monthly cost at current usage
  @override
  double? get estimatedMonthlyCost;

  /// Currency code
  @override
  String get currency;

  /// Create a copy of ModelCostInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModelCostInfoImplCopyWith<_$ModelCostInfoImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ModelDeprecationInfo _$ModelDeprecationInfoFromJson(Map<String, dynamic> json) {
  return _ModelDeprecationInfo.fromJson(json);
}

/// @nodoc
mixin _$ModelDeprecationInfo {
  /// Deprecation announcement date
  DateTime get announcedAt => throw _privateConstructorUsedError;

  /// Planned end-of-life date
  DateTime get endOfLifeDate => throw _privateConstructorUsedError;

  /// Recommended replacement model version
  String? get replacementVersion => throw _privateConstructorUsedError;

  /// Deprecation reason
  String get reason => throw _privateConstructorUsedError;

  /// Migration guide URL
  String? get migrationGuideUrl => throw _privateConstructorUsedError;

  /// Grace period (days)
  int get gracePeriodDays => throw _privateConstructorUsedError;

  /// Whether to allow new deployments
  bool get allowNewDeployments => throw _privateConstructorUsedError;

  /// Serializes this ModelDeprecationInfo to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ModelDeprecationInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ModelDeprecationInfoCopyWith<ModelDeprecationInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ModelDeprecationInfoCopyWith<$Res> {
  factory $ModelDeprecationInfoCopyWith(
    ModelDeprecationInfo value,
    $Res Function(ModelDeprecationInfo) then,
  ) = _$ModelDeprecationInfoCopyWithImpl<$Res, ModelDeprecationInfo>;
  @useResult
  $Res call({
    DateTime announcedAt,
    DateTime endOfLifeDate,
    String? replacementVersion,
    String reason,
    String? migrationGuideUrl,
    int gracePeriodDays,
    bool allowNewDeployments,
  });
}

/// @nodoc
class _$ModelDeprecationInfoCopyWithImpl<
  $Res,
  $Val extends ModelDeprecationInfo
>
    implements $ModelDeprecationInfoCopyWith<$Res> {
  _$ModelDeprecationInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ModelDeprecationInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? announcedAt = null,
    Object? endOfLifeDate = null,
    Object? replacementVersion = freezed,
    Object? reason = null,
    Object? migrationGuideUrl = freezed,
    Object? gracePeriodDays = null,
    Object? allowNewDeployments = null,
  }) {
    return _then(
      _value.copyWith(
            announcedAt: null == announcedAt
                ? _value.announcedAt
                : announcedAt // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            endOfLifeDate: null == endOfLifeDate
                ? _value.endOfLifeDate
                : endOfLifeDate // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            replacementVersion: freezed == replacementVersion
                ? _value.replacementVersion
                : replacementVersion // ignore: cast_nullable_to_non_nullable
                      as String?,
            reason: null == reason
                ? _value.reason
                : reason // ignore: cast_nullable_to_non_nullable
                      as String,
            migrationGuideUrl: freezed == migrationGuideUrl
                ? _value.migrationGuideUrl
                : migrationGuideUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            gracePeriodDays: null == gracePeriodDays
                ? _value.gracePeriodDays
                : gracePeriodDays // ignore: cast_nullable_to_non_nullable
                      as int,
            allowNewDeployments: null == allowNewDeployments
                ? _value.allowNewDeployments
                : allowNewDeployments // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ModelDeprecationInfoImplCopyWith<$Res>
    implements $ModelDeprecationInfoCopyWith<$Res> {
  factory _$$ModelDeprecationInfoImplCopyWith(
    _$ModelDeprecationInfoImpl value,
    $Res Function(_$ModelDeprecationInfoImpl) then,
  ) = __$$ModelDeprecationInfoImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    DateTime announcedAt,
    DateTime endOfLifeDate,
    String? replacementVersion,
    String reason,
    String? migrationGuideUrl,
    int gracePeriodDays,
    bool allowNewDeployments,
  });
}

/// @nodoc
class __$$ModelDeprecationInfoImplCopyWithImpl<$Res>
    extends _$ModelDeprecationInfoCopyWithImpl<$Res, _$ModelDeprecationInfoImpl>
    implements _$$ModelDeprecationInfoImplCopyWith<$Res> {
  __$$ModelDeprecationInfoImplCopyWithImpl(
    _$ModelDeprecationInfoImpl _value,
    $Res Function(_$ModelDeprecationInfoImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ModelDeprecationInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? announcedAt = null,
    Object? endOfLifeDate = null,
    Object? replacementVersion = freezed,
    Object? reason = null,
    Object? migrationGuideUrl = freezed,
    Object? gracePeriodDays = null,
    Object? allowNewDeployments = null,
  }) {
    return _then(
      _$ModelDeprecationInfoImpl(
        announcedAt: null == announcedAt
            ? _value.announcedAt
            : announcedAt // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        endOfLifeDate: null == endOfLifeDate
            ? _value.endOfLifeDate
            : endOfLifeDate // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        replacementVersion: freezed == replacementVersion
            ? _value.replacementVersion
            : replacementVersion // ignore: cast_nullable_to_non_nullable
                  as String?,
        reason: null == reason
            ? _value.reason
            : reason // ignore: cast_nullable_to_non_nullable
                  as String,
        migrationGuideUrl: freezed == migrationGuideUrl
            ? _value.migrationGuideUrl
            : migrationGuideUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        gracePeriodDays: null == gracePeriodDays
            ? _value.gracePeriodDays
            : gracePeriodDays // ignore: cast_nullable_to_non_nullable
                  as int,
        allowNewDeployments: null == allowNewDeployments
            ? _value.allowNewDeployments
            : allowNewDeployments // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ModelDeprecationInfoImpl implements _ModelDeprecationInfo {
  const _$ModelDeprecationInfoImpl({
    required this.announcedAt,
    required this.endOfLifeDate,
    this.replacementVersion,
    required this.reason,
    this.migrationGuideUrl,
    this.gracePeriodDays = 90,
    this.allowNewDeployments = false,
  });

  factory _$ModelDeprecationInfoImpl.fromJson(Map<String, dynamic> json) =>
      _$$ModelDeprecationInfoImplFromJson(json);

  /// Deprecation announcement date
  @override
  final DateTime announcedAt;

  /// Planned end-of-life date
  @override
  final DateTime endOfLifeDate;

  /// Recommended replacement model version
  @override
  final String? replacementVersion;

  /// Deprecation reason
  @override
  final String reason;

  /// Migration guide URL
  @override
  final String? migrationGuideUrl;

  /// Grace period (days)
  @override
  @JsonKey()
  final int gracePeriodDays;

  /// Whether to allow new deployments
  @override
  @JsonKey()
  final bool allowNewDeployments;

  @override
  String toString() {
    return 'ModelDeprecationInfo(announcedAt: $announcedAt, endOfLifeDate: $endOfLifeDate, replacementVersion: $replacementVersion, reason: $reason, migrationGuideUrl: $migrationGuideUrl, gracePeriodDays: $gracePeriodDays, allowNewDeployments: $allowNewDeployments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ModelDeprecationInfoImpl &&
            (identical(other.announcedAt, announcedAt) ||
                other.announcedAt == announcedAt) &&
            (identical(other.endOfLifeDate, endOfLifeDate) ||
                other.endOfLifeDate == endOfLifeDate) &&
            (identical(other.replacementVersion, replacementVersion) ||
                other.replacementVersion == replacementVersion) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.migrationGuideUrl, migrationGuideUrl) ||
                other.migrationGuideUrl == migrationGuideUrl) &&
            (identical(other.gracePeriodDays, gracePeriodDays) ||
                other.gracePeriodDays == gracePeriodDays) &&
            (identical(other.allowNewDeployments, allowNewDeployments) ||
                other.allowNewDeployments == allowNewDeployments));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    announcedAt,
    endOfLifeDate,
    replacementVersion,
    reason,
    migrationGuideUrl,
    gracePeriodDays,
    allowNewDeployments,
  );

  /// Create a copy of ModelDeprecationInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ModelDeprecationInfoImplCopyWith<_$ModelDeprecationInfoImpl>
  get copyWith =>
      __$$ModelDeprecationInfoImplCopyWithImpl<_$ModelDeprecationInfoImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ModelDeprecationInfoImplToJson(this);
  }
}

abstract class _ModelDeprecationInfo implements ModelDeprecationInfo {
  const factory _ModelDeprecationInfo({
    required final DateTime announcedAt,
    required final DateTime endOfLifeDate,
    final String? replacementVersion,
    required final String reason,
    final String? migrationGuideUrl,
    final int gracePeriodDays,
    final bool allowNewDeployments,
  }) = _$ModelDeprecationInfoImpl;

  factory _ModelDeprecationInfo.fromJson(Map<String, dynamic> json) =
      _$ModelDeprecationInfoImpl.fromJson;

  /// Deprecation announcement date
  @override
  DateTime get announcedAt;

  /// Planned end-of-life date
  @override
  DateTime get endOfLifeDate;

  /// Recommended replacement model version
  @override
  String? get replacementVersion;

  /// Deprecation reason
  @override
  String get reason;

  /// Migration guide URL
  @override
  String? get migrationGuideUrl;

  /// Grace period (days)
  @override
  int get gracePeriodDays;

  /// Whether to allow new deployments
  @override
  bool get allowNewDeployments;

  /// Create a copy of ModelDeprecationInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ModelDeprecationInfoImplCopyWith<_$ModelDeprecationInfoImpl>
  get copyWith => throw _privateConstructorUsedError;
}
