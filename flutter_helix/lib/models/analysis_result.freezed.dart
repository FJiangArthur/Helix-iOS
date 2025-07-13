// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analysis_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AnalysisResult _$AnalysisResultFromJson(Map<String, dynamic> json) {
  return _AnalysisResult.fromJson(json);
}

/// @nodoc
mixin _$AnalysisResult {
  /// Unique identifier for this analysis
  String get id => throw _privateConstructorUsedError;

  /// ID of the conversation being analyzed
  String get conversationId => throw _privateConstructorUsedError;

  /// Type of analysis performed
  AnalysisType get type => throw _privateConstructorUsedError;

  /// Current status of the analysis
  AnalysisStatus get status => throw _privateConstructorUsedError;

  /// When the analysis started
  DateTime get startTime => throw _privateConstructorUsedError;

  /// When the analysis completed
  DateTime? get completionTime => throw _privateConstructorUsedError;

  /// AI provider used for analysis
  String? get provider => throw _privateConstructorUsedError;

  /// Overall confidence score
  double get confidence => throw _privateConstructorUsedError;

  /// Fact-checking results
  List<FactCheckResult>? get factChecks => throw _privateConstructorUsedError;

  /// Conversation summary
  ConversationSummary? get summary => throw _privateConstructorUsedError;

  /// Extracted action items
  List<ActionItemResult>? get actionItems => throw _privateConstructorUsedError;

  /// Sentiment analysis
  SentimentAnalysisResult? get sentiment => throw _privateConstructorUsedError;

  /// Identified topics
  List<TopicResult>? get topics => throw _privateConstructorUsedError;

  /// Key insights and findings
  List<String> get insights => throw _privateConstructorUsedError;

  /// Processing errors or warnings
  List<String> get errors => throw _privateConstructorUsedError;

  /// Processing time in milliseconds
  int? get processingTimeMs => throw _privateConstructorUsedError;

  /// Token usage for AI processing
  Map<String, int>? get tokenUsage => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Serializes this AnalysisResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalysisResultCopyWith<AnalysisResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalysisResultCopyWith<$Res> {
  factory $AnalysisResultCopyWith(
    AnalysisResult value,
    $Res Function(AnalysisResult) then,
  ) = _$AnalysisResultCopyWithImpl<$Res, AnalysisResult>;
  @useResult
  $Res call({
    String id,
    String conversationId,
    AnalysisType type,
    AnalysisStatus status,
    DateTime startTime,
    DateTime? completionTime,
    String? provider,
    double confidence,
    List<FactCheckResult>? factChecks,
    ConversationSummary? summary,
    List<ActionItemResult>? actionItems,
    SentimentAnalysisResult? sentiment,
    List<TopicResult>? topics,
    List<String> insights,
    List<String> errors,
    int? processingTimeMs,
    Map<String, int>? tokenUsage,
    Map<String, dynamic> metadata,
  });

  $ConversationSummaryCopyWith<$Res>? get summary;
  $SentimentAnalysisResultCopyWith<$Res>? get sentiment;
}

/// @nodoc
class _$AnalysisResultCopyWithImpl<$Res, $Val extends AnalysisResult>
    implements $AnalysisResultCopyWith<$Res> {
  _$AnalysisResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? conversationId = null,
    Object? type = null,
    Object? status = null,
    Object? startTime = null,
    Object? completionTime = freezed,
    Object? provider = freezed,
    Object? confidence = null,
    Object? factChecks = freezed,
    Object? summary = freezed,
    Object? actionItems = freezed,
    Object? sentiment = freezed,
    Object? topics = freezed,
    Object? insights = null,
    Object? errors = null,
    Object? processingTimeMs = freezed,
    Object? tokenUsage = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            conversationId:
                null == conversationId
                    ? _value.conversationId
                    : conversationId // ignore: cast_nullable_to_non_nullable
                        as String,
            type:
                null == type
                    ? _value.type
                    : type // ignore: cast_nullable_to_non_nullable
                        as AnalysisType,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as AnalysisStatus,
            startTime:
                null == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            completionTime:
                freezed == completionTime
                    ? _value.completionTime
                    : completionTime // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            provider:
                freezed == provider
                    ? _value.provider
                    : provider // ignore: cast_nullable_to_non_nullable
                        as String?,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
            factChecks:
                freezed == factChecks
                    ? _value.factChecks
                    : factChecks // ignore: cast_nullable_to_non_nullable
                        as List<FactCheckResult>?,
            summary:
                freezed == summary
                    ? _value.summary
                    : summary // ignore: cast_nullable_to_non_nullable
                        as ConversationSummary?,
            actionItems:
                freezed == actionItems
                    ? _value.actionItems
                    : actionItems // ignore: cast_nullable_to_non_nullable
                        as List<ActionItemResult>?,
            sentiment:
                freezed == sentiment
                    ? _value.sentiment
                    : sentiment // ignore: cast_nullable_to_non_nullable
                        as SentimentAnalysisResult?,
            topics:
                freezed == topics
                    ? _value.topics
                    : topics // ignore: cast_nullable_to_non_nullable
                        as List<TopicResult>?,
            insights:
                null == insights
                    ? _value.insights
                    : insights // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            errors:
                null == errors
                    ? _value.errors
                    : errors // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            processingTimeMs:
                freezed == processingTimeMs
                    ? _value.processingTimeMs
                    : processingTimeMs // ignore: cast_nullable_to_non_nullable
                        as int?,
            tokenUsage:
                freezed == tokenUsage
                    ? _value.tokenUsage
                    : tokenUsage // ignore: cast_nullable_to_non_nullable
                        as Map<String, int>?,
            metadata:
                null == metadata
                    ? _value.metadata
                    : metadata // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
          )
          as $Val,
    );
  }

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ConversationSummaryCopyWith<$Res>? get summary {
    if (_value.summary == null) {
      return null;
    }

    return $ConversationSummaryCopyWith<$Res>(_value.summary!, (value) {
      return _then(_value.copyWith(summary: value) as $Val);
    });
  }

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SentimentAnalysisResultCopyWith<$Res>? get sentiment {
    if (_value.sentiment == null) {
      return null;
    }

    return $SentimentAnalysisResultCopyWith<$Res>(_value.sentiment!, (value) {
      return _then(_value.copyWith(sentiment: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AnalysisResultImplCopyWith<$Res>
    implements $AnalysisResultCopyWith<$Res> {
  factory _$$AnalysisResultImplCopyWith(
    _$AnalysisResultImpl value,
    $Res Function(_$AnalysisResultImpl) then,
  ) = __$$AnalysisResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String conversationId,
    AnalysisType type,
    AnalysisStatus status,
    DateTime startTime,
    DateTime? completionTime,
    String? provider,
    double confidence,
    List<FactCheckResult>? factChecks,
    ConversationSummary? summary,
    List<ActionItemResult>? actionItems,
    SentimentAnalysisResult? sentiment,
    List<TopicResult>? topics,
    List<String> insights,
    List<String> errors,
    int? processingTimeMs,
    Map<String, int>? tokenUsage,
    Map<String, dynamic> metadata,
  });

  @override
  $ConversationSummaryCopyWith<$Res>? get summary;
  @override
  $SentimentAnalysisResultCopyWith<$Res>? get sentiment;
}

/// @nodoc
class __$$AnalysisResultImplCopyWithImpl<$Res>
    extends _$AnalysisResultCopyWithImpl<$Res, _$AnalysisResultImpl>
    implements _$$AnalysisResultImplCopyWith<$Res> {
  __$$AnalysisResultImplCopyWithImpl(
    _$AnalysisResultImpl _value,
    $Res Function(_$AnalysisResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? conversationId = null,
    Object? type = null,
    Object? status = null,
    Object? startTime = null,
    Object? completionTime = freezed,
    Object? provider = freezed,
    Object? confidence = null,
    Object? factChecks = freezed,
    Object? summary = freezed,
    Object? actionItems = freezed,
    Object? sentiment = freezed,
    Object? topics = freezed,
    Object? insights = null,
    Object? errors = null,
    Object? processingTimeMs = freezed,
    Object? tokenUsage = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$AnalysisResultImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        conversationId:
            null == conversationId
                ? _value.conversationId
                : conversationId // ignore: cast_nullable_to_non_nullable
                    as String,
        type:
            null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                    as AnalysisType,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as AnalysisStatus,
        startTime:
            null == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        completionTime:
            freezed == completionTime
                ? _value.completionTime
                : completionTime // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        provider:
            freezed == provider
                ? _value.provider
                : provider // ignore: cast_nullable_to_non_nullable
                    as String?,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
        factChecks:
            freezed == factChecks
                ? _value._factChecks
                : factChecks // ignore: cast_nullable_to_non_nullable
                    as List<FactCheckResult>?,
        summary:
            freezed == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                    as ConversationSummary?,
        actionItems:
            freezed == actionItems
                ? _value._actionItems
                : actionItems // ignore: cast_nullable_to_non_nullable
                    as List<ActionItemResult>?,
        sentiment:
            freezed == sentiment
                ? _value.sentiment
                : sentiment // ignore: cast_nullable_to_non_nullable
                    as SentimentAnalysisResult?,
        topics:
            freezed == topics
                ? _value._topics
                : topics // ignore: cast_nullable_to_non_nullable
                    as List<TopicResult>?,
        insights:
            null == insights
                ? _value._insights
                : insights // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        errors:
            null == errors
                ? _value._errors
                : errors // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        processingTimeMs:
            freezed == processingTimeMs
                ? _value.processingTimeMs
                : processingTimeMs // ignore: cast_nullable_to_non_nullable
                    as int?,
        tokenUsage:
            freezed == tokenUsage
                ? _value._tokenUsage
                : tokenUsage // ignore: cast_nullable_to_non_nullable
                    as Map<String, int>?,
        metadata:
            null == metadata
                ? _value._metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AnalysisResultImpl extends _AnalysisResult {
  const _$AnalysisResultImpl({
    required this.id,
    required this.conversationId,
    required this.type,
    required this.status,
    required this.startTime,
    this.completionTime,
    this.provider,
    this.confidence = 0.0,
    final List<FactCheckResult>? factChecks,
    this.summary,
    final List<ActionItemResult>? actionItems,
    this.sentiment,
    final List<TopicResult>? topics,
    final List<String> insights = const [],
    final List<String> errors = const [],
    this.processingTimeMs,
    final Map<String, int>? tokenUsage,
    final Map<String, dynamic> metadata = const {},
  }) : _factChecks = factChecks,
       _actionItems = actionItems,
       _topics = topics,
       _insights = insights,
       _errors = errors,
       _tokenUsage = tokenUsage,
       _metadata = metadata,
       super._();

  factory _$AnalysisResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnalysisResultImplFromJson(json);

  /// Unique identifier for this analysis
  @override
  final String id;

  /// ID of the conversation being analyzed
  @override
  final String conversationId;

  /// Type of analysis performed
  @override
  final AnalysisType type;

  /// Current status of the analysis
  @override
  final AnalysisStatus status;

  /// When the analysis started
  @override
  final DateTime startTime;

  /// When the analysis completed
  @override
  final DateTime? completionTime;

  /// AI provider used for analysis
  @override
  final String? provider;

  /// Overall confidence score
  @override
  @JsonKey()
  final double confidence;

  /// Fact-checking results
  final List<FactCheckResult>? _factChecks;

  /// Fact-checking results
  @override
  List<FactCheckResult>? get factChecks {
    final value = _factChecks;
    if (value == null) return null;
    if (_factChecks is EqualUnmodifiableListView) return _factChecks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Conversation summary
  @override
  final ConversationSummary? summary;

  /// Extracted action items
  final List<ActionItemResult>? _actionItems;

  /// Extracted action items
  @override
  List<ActionItemResult>? get actionItems {
    final value = _actionItems;
    if (value == null) return null;
    if (_actionItems is EqualUnmodifiableListView) return _actionItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Sentiment analysis
  @override
  final SentimentAnalysisResult? sentiment;

  /// Identified topics
  final List<TopicResult>? _topics;

  /// Identified topics
  @override
  List<TopicResult>? get topics {
    final value = _topics;
    if (value == null) return null;
    if (_topics is EqualUnmodifiableListView) return _topics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Key insights and findings
  final List<String> _insights;

  /// Key insights and findings
  @override
  @JsonKey()
  List<String> get insights {
    if (_insights is EqualUnmodifiableListView) return _insights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_insights);
  }

  /// Processing errors or warnings
  final List<String> _errors;

  /// Processing errors or warnings
  @override
  @JsonKey()
  List<String> get errors {
    if (_errors is EqualUnmodifiableListView) return _errors;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_errors);
  }

  /// Processing time in milliseconds
  @override
  final int? processingTimeMs;

  /// Token usage for AI processing
  final Map<String, int>? _tokenUsage;

  /// Token usage for AI processing
  @override
  Map<String, int>? get tokenUsage {
    final value = _tokenUsage;
    if (value == null) return null;
    if (_tokenUsage is EqualUnmodifiableMapView) return _tokenUsage;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  /// Additional metadata
  final Map<String, dynamic> _metadata;

  /// Additional metadata
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  @override
  String toString() {
    return 'AnalysisResult(id: $id, conversationId: $conversationId, type: $type, status: $status, startTime: $startTime, completionTime: $completionTime, provider: $provider, confidence: $confidence, factChecks: $factChecks, summary: $summary, actionItems: $actionItems, sentiment: $sentiment, topics: $topics, insights: $insights, errors: $errors, processingTimeMs: $processingTimeMs, tokenUsage: $tokenUsage, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalysisResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.conversationId, conversationId) ||
                other.conversationId == conversationId) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.completionTime, completionTime) ||
                other.completionTime == completionTime) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            const DeepCollectionEquality().equals(
              other._factChecks,
              _factChecks,
            ) &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(
              other._actionItems,
              _actionItems,
            ) &&
            (identical(other.sentiment, sentiment) ||
                other.sentiment == sentiment) &&
            const DeepCollectionEquality().equals(other._topics, _topics) &&
            const DeepCollectionEquality().equals(other._insights, _insights) &&
            const DeepCollectionEquality().equals(other._errors, _errors) &&
            (identical(other.processingTimeMs, processingTimeMs) ||
                other.processingTimeMs == processingTimeMs) &&
            const DeepCollectionEquality().equals(
              other._tokenUsage,
              _tokenUsage,
            ) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    conversationId,
    type,
    status,
    startTime,
    completionTime,
    provider,
    confidence,
    const DeepCollectionEquality().hash(_factChecks),
    summary,
    const DeepCollectionEquality().hash(_actionItems),
    sentiment,
    const DeepCollectionEquality().hash(_topics),
    const DeepCollectionEquality().hash(_insights),
    const DeepCollectionEquality().hash(_errors),
    processingTimeMs,
    const DeepCollectionEquality().hash(_tokenUsage),
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalysisResultImplCopyWith<_$AnalysisResultImpl> get copyWith =>
      __$$AnalysisResultImplCopyWithImpl<_$AnalysisResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AnalysisResultImplToJson(this);
  }
}

abstract class _AnalysisResult extends AnalysisResult {
  const factory _AnalysisResult({
    required final String id,
    required final String conversationId,
    required final AnalysisType type,
    required final AnalysisStatus status,
    required final DateTime startTime,
    final DateTime? completionTime,
    final String? provider,
    final double confidence,
    final List<FactCheckResult>? factChecks,
    final ConversationSummary? summary,
    final List<ActionItemResult>? actionItems,
    final SentimentAnalysisResult? sentiment,
    final List<TopicResult>? topics,
    final List<String> insights,
    final List<String> errors,
    final int? processingTimeMs,
    final Map<String, int>? tokenUsage,
    final Map<String, dynamic> metadata,
  }) = _$AnalysisResultImpl;
  const _AnalysisResult._() : super._();

  factory _AnalysisResult.fromJson(Map<String, dynamic> json) =
      _$AnalysisResultImpl.fromJson;

  /// Unique identifier for this analysis
  @override
  String get id;

  /// ID of the conversation being analyzed
  @override
  String get conversationId;

  /// Type of analysis performed
  @override
  AnalysisType get type;

  /// Current status of the analysis
  @override
  AnalysisStatus get status;

  /// When the analysis started
  @override
  DateTime get startTime;

  /// When the analysis completed
  @override
  DateTime? get completionTime;

  /// AI provider used for analysis
  @override
  String? get provider;

  /// Overall confidence score
  @override
  double get confidence;

  /// Fact-checking results
  @override
  List<FactCheckResult>? get factChecks;

  /// Conversation summary
  @override
  ConversationSummary? get summary;

  /// Extracted action items
  @override
  List<ActionItemResult>? get actionItems;

  /// Sentiment analysis
  @override
  SentimentAnalysisResult? get sentiment;

  /// Identified topics
  @override
  List<TopicResult>? get topics;

  /// Key insights and findings
  @override
  List<String> get insights;

  /// Processing errors or warnings
  @override
  List<String> get errors;

  /// Processing time in milliseconds
  @override
  int? get processingTimeMs;

  /// Token usage for AI processing
  @override
  Map<String, int>? get tokenUsage;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of AnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalysisResultImplCopyWith<_$AnalysisResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FactCheckResult _$FactCheckResultFromJson(Map<String, dynamic> json) {
  return _FactCheckResult.fromJson(json);
}

/// @nodoc
mixin _$FactCheckResult {
  /// Unique identifier
  String get id => throw _privateConstructorUsedError;

  /// The claim being fact-checked
  String get claim => throw _privateConstructorUsedError;

  /// Verification result
  FactCheckStatus get status => throw _privateConstructorUsedError;

  /// Confidence in the verification
  double get confidence => throw _privateConstructorUsedError;

  /// Supporting sources
  List<String> get sources => throw _privateConstructorUsedError;

  /// Detailed explanation
  String? get explanation => throw _privateConstructorUsedError;

  /// Context within the conversation
  String? get context => throw _privateConstructorUsedError;

  /// Timestamp range where claim appears
  int? get startTimeMs => throw _privateConstructorUsedError;
  int? get endTimeMs => throw _privateConstructorUsedError;

  /// Speaker who made the claim
  String? get speakerId => throw _privateConstructorUsedError;

  /// Category of the claim
  String? get category => throw _privateConstructorUsedError;

  /// Related claims
  List<String> get relatedClaims => throw _privateConstructorUsedError;

  /// Serializes this FactCheckResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FactCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FactCheckResultCopyWith<FactCheckResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FactCheckResultCopyWith<$Res> {
  factory $FactCheckResultCopyWith(
    FactCheckResult value,
    $Res Function(FactCheckResult) then,
  ) = _$FactCheckResultCopyWithImpl<$Res, FactCheckResult>;
  @useResult
  $Res call({
    String id,
    String claim,
    FactCheckStatus status,
    double confidence,
    List<String> sources,
    String? explanation,
    String? context,
    int? startTimeMs,
    int? endTimeMs,
    String? speakerId,
    String? category,
    List<String> relatedClaims,
  });
}

/// @nodoc
class _$FactCheckResultCopyWithImpl<$Res, $Val extends FactCheckResult>
    implements $FactCheckResultCopyWith<$Res> {
  _$FactCheckResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FactCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? claim = null,
    Object? status = null,
    Object? confidence = null,
    Object? sources = null,
    Object? explanation = freezed,
    Object? context = freezed,
    Object? startTimeMs = freezed,
    Object? endTimeMs = freezed,
    Object? speakerId = freezed,
    Object? category = freezed,
    Object? relatedClaims = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            claim:
                null == claim
                    ? _value.claim
                    : claim // ignore: cast_nullable_to_non_nullable
                        as String,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as FactCheckStatus,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
            sources:
                null == sources
                    ? _value.sources
                    : sources // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            explanation:
                freezed == explanation
                    ? _value.explanation
                    : explanation // ignore: cast_nullable_to_non_nullable
                        as String?,
            context:
                freezed == context
                    ? _value.context
                    : context // ignore: cast_nullable_to_non_nullable
                        as String?,
            startTimeMs:
                freezed == startTimeMs
                    ? _value.startTimeMs
                    : startTimeMs // ignore: cast_nullable_to_non_nullable
                        as int?,
            endTimeMs:
                freezed == endTimeMs
                    ? _value.endTimeMs
                    : endTimeMs // ignore: cast_nullable_to_non_nullable
                        as int?,
            speakerId:
                freezed == speakerId
                    ? _value.speakerId
                    : speakerId // ignore: cast_nullable_to_non_nullable
                        as String?,
            category:
                freezed == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as String?,
            relatedClaims:
                null == relatedClaims
                    ? _value.relatedClaims
                    : relatedClaims // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FactCheckResultImplCopyWith<$Res>
    implements $FactCheckResultCopyWith<$Res> {
  factory _$$FactCheckResultImplCopyWith(
    _$FactCheckResultImpl value,
    $Res Function(_$FactCheckResultImpl) then,
  ) = __$$FactCheckResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String claim,
    FactCheckStatus status,
    double confidence,
    List<String> sources,
    String? explanation,
    String? context,
    int? startTimeMs,
    int? endTimeMs,
    String? speakerId,
    String? category,
    List<String> relatedClaims,
  });
}

/// @nodoc
class __$$FactCheckResultImplCopyWithImpl<$Res>
    extends _$FactCheckResultCopyWithImpl<$Res, _$FactCheckResultImpl>
    implements _$$FactCheckResultImplCopyWith<$Res> {
  __$$FactCheckResultImplCopyWithImpl(
    _$FactCheckResultImpl _value,
    $Res Function(_$FactCheckResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FactCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? claim = null,
    Object? status = null,
    Object? confidence = null,
    Object? sources = null,
    Object? explanation = freezed,
    Object? context = freezed,
    Object? startTimeMs = freezed,
    Object? endTimeMs = freezed,
    Object? speakerId = freezed,
    Object? category = freezed,
    Object? relatedClaims = null,
  }) {
    return _then(
      _$FactCheckResultImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        claim:
            null == claim
                ? _value.claim
                : claim // ignore: cast_nullable_to_non_nullable
                    as String,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as FactCheckStatus,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
        sources:
            null == sources
                ? _value._sources
                : sources // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        explanation:
            freezed == explanation
                ? _value.explanation
                : explanation // ignore: cast_nullable_to_non_nullable
                    as String?,
        context:
            freezed == context
                ? _value.context
                : context // ignore: cast_nullable_to_non_nullable
                    as String?,
        startTimeMs:
            freezed == startTimeMs
                ? _value.startTimeMs
                : startTimeMs // ignore: cast_nullable_to_non_nullable
                    as int?,
        endTimeMs:
            freezed == endTimeMs
                ? _value.endTimeMs
                : endTimeMs // ignore: cast_nullable_to_non_nullable
                    as int?,
        speakerId:
            freezed == speakerId
                ? _value.speakerId
                : speakerId // ignore: cast_nullable_to_non_nullable
                    as String?,
        category:
            freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as String?,
        relatedClaims:
            null == relatedClaims
                ? _value._relatedClaims
                : relatedClaims // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FactCheckResultImpl extends _FactCheckResult {
  const _$FactCheckResultImpl({
    required this.id,
    required this.claim,
    required this.status,
    required this.confidence,
    final List<String> sources = const [],
    this.explanation,
    this.context,
    this.startTimeMs,
    this.endTimeMs,
    this.speakerId,
    this.category,
    final List<String> relatedClaims = const [],
  }) : _sources = sources,
       _relatedClaims = relatedClaims,
       super._();

  factory _$FactCheckResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$FactCheckResultImplFromJson(json);

  /// Unique identifier
  @override
  final String id;

  /// The claim being fact-checked
  @override
  final String claim;

  /// Verification result
  @override
  final FactCheckStatus status;

  /// Confidence in the verification
  @override
  final double confidence;

  /// Supporting sources
  final List<String> _sources;

  /// Supporting sources
  @override
  @JsonKey()
  List<String> get sources {
    if (_sources is EqualUnmodifiableListView) return _sources;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sources);
  }

  /// Detailed explanation
  @override
  final String? explanation;

  /// Context within the conversation
  @override
  final String? context;

  /// Timestamp range where claim appears
  @override
  final int? startTimeMs;
  @override
  final int? endTimeMs;

  /// Speaker who made the claim
  @override
  final String? speakerId;

  /// Category of the claim
  @override
  final String? category;

  /// Related claims
  final List<String> _relatedClaims;

  /// Related claims
  @override
  @JsonKey()
  List<String> get relatedClaims {
    if (_relatedClaims is EqualUnmodifiableListView) return _relatedClaims;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_relatedClaims);
  }

  @override
  String toString() {
    return 'FactCheckResult(id: $id, claim: $claim, status: $status, confidence: $confidence, sources: $sources, explanation: $explanation, context: $context, startTimeMs: $startTimeMs, endTimeMs: $endTimeMs, speakerId: $speakerId, category: $category, relatedClaims: $relatedClaims)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FactCheckResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.claim, claim) || other.claim == claim) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            const DeepCollectionEquality().equals(other._sources, _sources) &&
            (identical(other.explanation, explanation) ||
                other.explanation == explanation) &&
            (identical(other.context, context) || other.context == context) &&
            (identical(other.startTimeMs, startTimeMs) ||
                other.startTimeMs == startTimeMs) &&
            (identical(other.endTimeMs, endTimeMs) ||
                other.endTimeMs == endTimeMs) &&
            (identical(other.speakerId, speakerId) ||
                other.speakerId == speakerId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            const DeepCollectionEquality().equals(
              other._relatedClaims,
              _relatedClaims,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    claim,
    status,
    confidence,
    const DeepCollectionEquality().hash(_sources),
    explanation,
    context,
    startTimeMs,
    endTimeMs,
    speakerId,
    category,
    const DeepCollectionEquality().hash(_relatedClaims),
  );

  /// Create a copy of FactCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FactCheckResultImplCopyWith<_$FactCheckResultImpl> get copyWith =>
      __$$FactCheckResultImplCopyWithImpl<_$FactCheckResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FactCheckResultImplToJson(this);
  }
}

abstract class _FactCheckResult extends FactCheckResult {
  const factory _FactCheckResult({
    required final String id,
    required final String claim,
    required final FactCheckStatus status,
    required final double confidence,
    final List<String> sources,
    final String? explanation,
    final String? context,
    final int? startTimeMs,
    final int? endTimeMs,
    final String? speakerId,
    final String? category,
    final List<String> relatedClaims,
  }) = _$FactCheckResultImpl;
  const _FactCheckResult._() : super._();

  factory _FactCheckResult.fromJson(Map<String, dynamic> json) =
      _$FactCheckResultImpl.fromJson;

  /// Unique identifier
  @override
  String get id;

  /// The claim being fact-checked
  @override
  String get claim;

  /// Verification result
  @override
  FactCheckStatus get status;

  /// Confidence in the verification
  @override
  double get confidence;

  /// Supporting sources
  @override
  List<String> get sources;

  /// Detailed explanation
  @override
  String? get explanation;

  /// Context within the conversation
  @override
  String? get context;

  /// Timestamp range where claim appears
  @override
  int? get startTimeMs;
  @override
  int? get endTimeMs;

  /// Speaker who made the claim
  @override
  String? get speakerId;

  /// Category of the claim
  @override
  String? get category;

  /// Related claims
  @override
  List<String> get relatedClaims;

  /// Create a copy of FactCheckResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FactCheckResultImplCopyWith<_$FactCheckResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConversationSummary _$ConversationSummaryFromJson(Map<String, dynamic> json) {
  return _ConversationSummary.fromJson(json);
}

/// @nodoc
mixin _$ConversationSummary {
  /// Main summary text
  String get summary => throw _privateConstructorUsedError;

  /// Key discussion points
  List<String> get keyPoints => throw _privateConstructorUsedError;

  /// Important decisions made
  List<String> get decisions => throw _privateConstructorUsedError;

  /// Questions raised
  List<String> get questions => throw _privateConstructorUsedError;

  /// Overall tone of conversation
  String? get tone => throw _privateConstructorUsedError;

  /// Main topics discussed
  List<String> get topics => throw _privateConstructorUsedError;

  /// Summary length category
  SummaryLength get length => throw _privateConstructorUsedError;

  /// Estimated reading time
  Duration? get estimatedReadTime => throw _privateConstructorUsedError;

  /// Confidence in summary accuracy
  double get confidence => throw _privateConstructorUsedError;

  /// Serializes this ConversationSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConversationSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationSummaryCopyWith<ConversationSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationSummaryCopyWith<$Res> {
  factory $ConversationSummaryCopyWith(
    ConversationSummary value,
    $Res Function(ConversationSummary) then,
  ) = _$ConversationSummaryCopyWithImpl<$Res, ConversationSummary>;
  @useResult
  $Res call({
    String summary,
    List<String> keyPoints,
    List<String> decisions,
    List<String> questions,
    String? tone,
    List<String> topics,
    SummaryLength length,
    Duration? estimatedReadTime,
    double confidence,
  });
}

/// @nodoc
class _$ConversationSummaryCopyWithImpl<$Res, $Val extends ConversationSummary>
    implements $ConversationSummaryCopyWith<$Res> {
  _$ConversationSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = null,
    Object? keyPoints = null,
    Object? decisions = null,
    Object? questions = null,
    Object? tone = freezed,
    Object? topics = null,
    Object? length = null,
    Object? estimatedReadTime = freezed,
    Object? confidence = null,
  }) {
    return _then(
      _value.copyWith(
            summary:
                null == summary
                    ? _value.summary
                    : summary // ignore: cast_nullable_to_non_nullable
                        as String,
            keyPoints:
                null == keyPoints
                    ? _value.keyPoints
                    : keyPoints // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            decisions:
                null == decisions
                    ? _value.decisions
                    : decisions // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            questions:
                null == questions
                    ? _value.questions
                    : questions // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            tone:
                freezed == tone
                    ? _value.tone
                    : tone // ignore: cast_nullable_to_non_nullable
                        as String?,
            topics:
                null == topics
                    ? _value.topics
                    : topics // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            length:
                null == length
                    ? _value.length
                    : length // ignore: cast_nullable_to_non_nullable
                        as SummaryLength,
            estimatedReadTime:
                freezed == estimatedReadTime
                    ? _value.estimatedReadTime
                    : estimatedReadTime // ignore: cast_nullable_to_non_nullable
                        as Duration?,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConversationSummaryImplCopyWith<$Res>
    implements $ConversationSummaryCopyWith<$Res> {
  factory _$$ConversationSummaryImplCopyWith(
    _$ConversationSummaryImpl value,
    $Res Function(_$ConversationSummaryImpl) then,
  ) = __$$ConversationSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String summary,
    List<String> keyPoints,
    List<String> decisions,
    List<String> questions,
    String? tone,
    List<String> topics,
    SummaryLength length,
    Duration? estimatedReadTime,
    double confidence,
  });
}

/// @nodoc
class __$$ConversationSummaryImplCopyWithImpl<$Res>
    extends _$ConversationSummaryCopyWithImpl<$Res, _$ConversationSummaryImpl>
    implements _$$ConversationSummaryImplCopyWith<$Res> {
  __$$ConversationSummaryImplCopyWithImpl(
    _$ConversationSummaryImpl _value,
    $Res Function(_$ConversationSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? summary = null,
    Object? keyPoints = null,
    Object? decisions = null,
    Object? questions = null,
    Object? tone = freezed,
    Object? topics = null,
    Object? length = null,
    Object? estimatedReadTime = freezed,
    Object? confidence = null,
  }) {
    return _then(
      _$ConversationSummaryImpl(
        summary:
            null == summary
                ? _value.summary
                : summary // ignore: cast_nullable_to_non_nullable
                    as String,
        keyPoints:
            null == keyPoints
                ? _value._keyPoints
                : keyPoints // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        decisions:
            null == decisions
                ? _value._decisions
                : decisions // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        questions:
            null == questions
                ? _value._questions
                : questions // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        tone:
            freezed == tone
                ? _value.tone
                : tone // ignore: cast_nullable_to_non_nullable
                    as String?,
        topics:
            null == topics
                ? _value._topics
                : topics // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        length:
            null == length
                ? _value.length
                : length // ignore: cast_nullable_to_non_nullable
                    as SummaryLength,
        estimatedReadTime:
            freezed == estimatedReadTime
                ? _value.estimatedReadTime
                : estimatedReadTime // ignore: cast_nullable_to_non_nullable
                    as Duration?,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConversationSummaryImpl extends _ConversationSummary {
  const _$ConversationSummaryImpl({
    required this.summary,
    final List<String> keyPoints = const [],
    final List<String> decisions = const [],
    final List<String> questions = const [],
    this.tone,
    final List<String> topics = const [],
    this.length = SummaryLength.medium,
    this.estimatedReadTime,
    this.confidence = 0.0,
  }) : _keyPoints = keyPoints,
       _decisions = decisions,
       _questions = questions,
       _topics = topics,
       super._();

  factory _$ConversationSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversationSummaryImplFromJson(json);

  /// Main summary text
  @override
  final String summary;

  /// Key discussion points
  final List<String> _keyPoints;

  /// Key discussion points
  @override
  @JsonKey()
  List<String> get keyPoints {
    if (_keyPoints is EqualUnmodifiableListView) return _keyPoints;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_keyPoints);
  }

  /// Important decisions made
  final List<String> _decisions;

  /// Important decisions made
  @override
  @JsonKey()
  List<String> get decisions {
    if (_decisions is EqualUnmodifiableListView) return _decisions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_decisions);
  }

  /// Questions raised
  final List<String> _questions;

  /// Questions raised
  @override
  @JsonKey()
  List<String> get questions {
    if (_questions is EqualUnmodifiableListView) return _questions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_questions);
  }

  /// Overall tone of conversation
  @override
  final String? tone;

  /// Main topics discussed
  final List<String> _topics;

  /// Main topics discussed
  @override
  @JsonKey()
  List<String> get topics {
    if (_topics is EqualUnmodifiableListView) return _topics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_topics);
  }

  /// Summary length category
  @override
  @JsonKey()
  final SummaryLength length;

  /// Estimated reading time
  @override
  final Duration? estimatedReadTime;

  /// Confidence in summary accuracy
  @override
  @JsonKey()
  final double confidence;

  @override
  String toString() {
    return 'ConversationSummary(summary: $summary, keyPoints: $keyPoints, decisions: $decisions, questions: $questions, tone: $tone, topics: $topics, length: $length, estimatedReadTime: $estimatedReadTime, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationSummaryImpl &&
            (identical(other.summary, summary) || other.summary == summary) &&
            const DeepCollectionEquality().equals(
              other._keyPoints,
              _keyPoints,
            ) &&
            const DeepCollectionEquality().equals(
              other._decisions,
              _decisions,
            ) &&
            const DeepCollectionEquality().equals(
              other._questions,
              _questions,
            ) &&
            (identical(other.tone, tone) || other.tone == tone) &&
            const DeepCollectionEquality().equals(other._topics, _topics) &&
            (identical(other.length, length) || other.length == length) &&
            (identical(other.estimatedReadTime, estimatedReadTime) ||
                other.estimatedReadTime == estimatedReadTime) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    summary,
    const DeepCollectionEquality().hash(_keyPoints),
    const DeepCollectionEquality().hash(_decisions),
    const DeepCollectionEquality().hash(_questions),
    tone,
    const DeepCollectionEquality().hash(_topics),
    length,
    estimatedReadTime,
    confidence,
  );

  /// Create a copy of ConversationSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationSummaryImplCopyWith<_$ConversationSummaryImpl> get copyWith =>
      __$$ConversationSummaryImplCopyWithImpl<_$ConversationSummaryImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversationSummaryImplToJson(this);
  }
}

abstract class _ConversationSummary extends ConversationSummary {
  const factory _ConversationSummary({
    required final String summary,
    final List<String> keyPoints,
    final List<String> decisions,
    final List<String> questions,
    final String? tone,
    final List<String> topics,
    final SummaryLength length,
    final Duration? estimatedReadTime,
    final double confidence,
  }) = _$ConversationSummaryImpl;
  const _ConversationSummary._() : super._();

  factory _ConversationSummary.fromJson(Map<String, dynamic> json) =
      _$ConversationSummaryImpl.fromJson;

  /// Main summary text
  @override
  String get summary;

  /// Key discussion points
  @override
  List<String> get keyPoints;

  /// Important decisions made
  @override
  List<String> get decisions;

  /// Questions raised
  @override
  List<String> get questions;

  /// Overall tone of conversation
  @override
  String? get tone;

  /// Main topics discussed
  @override
  List<String> get topics;

  /// Summary length category
  @override
  SummaryLength get length;

  /// Estimated reading time
  @override
  Duration? get estimatedReadTime;

  /// Confidence in summary accuracy
  @override
  double get confidence;

  /// Create a copy of ConversationSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationSummaryImplCopyWith<_$ConversationSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ActionItemResult _$ActionItemResultFromJson(Map<String, dynamic> json) {
  return _ActionItemResult.fromJson(json);
}

/// @nodoc
mixin _$ActionItemResult {
  /// Unique identifier
  String get id => throw _privateConstructorUsedError;

  /// Description of the action
  String get description => throw _privateConstructorUsedError;

  /// Assigned person (if mentioned)
  String? get assignee => throw _privateConstructorUsedError;

  /// Due date (if mentioned)
  DateTime? get dueDate => throw _privateConstructorUsedError;

  /// Priority level
  ActionItemPriority get priority => throw _privateConstructorUsedError;

  /// Context where it was mentioned
  String? get context => throw _privateConstructorUsedError;

  /// Confidence in extraction accuracy
  double get confidence => throw _privateConstructorUsedError;

  /// Status of the action item
  ActionItemStatus get status => throw _privateConstructorUsedError;

  /// Timestamp where mentioned
  int? get mentionedAtMs => throw _privateConstructorUsedError;

  /// Speaker who mentioned it
  String? get speakerId => throw _privateConstructorUsedError;

  /// Related action items
  List<String> get relatedItems => throw _privateConstructorUsedError;

  /// Categories or tags
  List<String> get tags => throw _privateConstructorUsedError;

  /// Serializes this ActionItemResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ActionItemResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ActionItemResultCopyWith<ActionItemResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ActionItemResultCopyWith<$Res> {
  factory $ActionItemResultCopyWith(
    ActionItemResult value,
    $Res Function(ActionItemResult) then,
  ) = _$ActionItemResultCopyWithImpl<$Res, ActionItemResult>;
  @useResult
  $Res call({
    String id,
    String description,
    String? assignee,
    DateTime? dueDate,
    ActionItemPriority priority,
    String? context,
    double confidence,
    ActionItemStatus status,
    int? mentionedAtMs,
    String? speakerId,
    List<String> relatedItems,
    List<String> tags,
  });
}

/// @nodoc
class _$ActionItemResultCopyWithImpl<$Res, $Val extends ActionItemResult>
    implements $ActionItemResultCopyWith<$Res> {
  _$ActionItemResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ActionItemResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? description = null,
    Object? assignee = freezed,
    Object? dueDate = freezed,
    Object? priority = null,
    Object? context = freezed,
    Object? confidence = null,
    Object? status = null,
    Object? mentionedAtMs = freezed,
    Object? speakerId = freezed,
    Object? relatedItems = null,
    Object? tags = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                null == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String,
            assignee:
                freezed == assignee
                    ? _value.assignee
                    : assignee // ignore: cast_nullable_to_non_nullable
                        as String?,
            dueDate:
                freezed == dueDate
                    ? _value.dueDate
                    : dueDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            priority:
                null == priority
                    ? _value.priority
                    : priority // ignore: cast_nullable_to_non_nullable
                        as ActionItemPriority,
            context:
                freezed == context
                    ? _value.context
                    : context // ignore: cast_nullable_to_non_nullable
                        as String?,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as ActionItemStatus,
            mentionedAtMs:
                freezed == mentionedAtMs
                    ? _value.mentionedAtMs
                    : mentionedAtMs // ignore: cast_nullable_to_non_nullable
                        as int?,
            speakerId:
                freezed == speakerId
                    ? _value.speakerId
                    : speakerId // ignore: cast_nullable_to_non_nullable
                        as String?,
            relatedItems:
                null == relatedItems
                    ? _value.relatedItems
                    : relatedItems // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            tags:
                null == tags
                    ? _value.tags
                    : tags // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ActionItemResultImplCopyWith<$Res>
    implements $ActionItemResultCopyWith<$Res> {
  factory _$$ActionItemResultImplCopyWith(
    _$ActionItemResultImpl value,
    $Res Function(_$ActionItemResultImpl) then,
  ) = __$$ActionItemResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String description,
    String? assignee,
    DateTime? dueDate,
    ActionItemPriority priority,
    String? context,
    double confidence,
    ActionItemStatus status,
    int? mentionedAtMs,
    String? speakerId,
    List<String> relatedItems,
    List<String> tags,
  });
}

/// @nodoc
class __$$ActionItemResultImplCopyWithImpl<$Res>
    extends _$ActionItemResultCopyWithImpl<$Res, _$ActionItemResultImpl>
    implements _$$ActionItemResultImplCopyWith<$Res> {
  __$$ActionItemResultImplCopyWithImpl(
    _$ActionItemResultImpl _value,
    $Res Function(_$ActionItemResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ActionItemResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? description = null,
    Object? assignee = freezed,
    Object? dueDate = freezed,
    Object? priority = null,
    Object? context = freezed,
    Object? confidence = null,
    Object? status = null,
    Object? mentionedAtMs = freezed,
    Object? speakerId = freezed,
    Object? relatedItems = null,
    Object? tags = null,
  }) {
    return _then(
      _$ActionItemResultImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String,
        assignee:
            freezed == assignee
                ? _value.assignee
                : assignee // ignore: cast_nullable_to_non_nullable
                    as String?,
        dueDate:
            freezed == dueDate
                ? _value.dueDate
                : dueDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        priority:
            null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                    as ActionItemPriority,
        context:
            freezed == context
                ? _value.context
                : context // ignore: cast_nullable_to_non_nullable
                    as String?,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as ActionItemStatus,
        mentionedAtMs:
            freezed == mentionedAtMs
                ? _value.mentionedAtMs
                : mentionedAtMs // ignore: cast_nullable_to_non_nullable
                    as int?,
        speakerId:
            freezed == speakerId
                ? _value.speakerId
                : speakerId // ignore: cast_nullable_to_non_nullable
                    as String?,
        relatedItems:
            null == relatedItems
                ? _value._relatedItems
                : relatedItems // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        tags:
            null == tags
                ? _value._tags
                : tags // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ActionItemResultImpl extends _ActionItemResult {
  const _$ActionItemResultImpl({
    required this.id,
    required this.description,
    this.assignee,
    this.dueDate,
    this.priority = ActionItemPriority.medium,
    this.context,
    this.confidence = 0.0,
    this.status = ActionItemStatus.pending,
    this.mentionedAtMs,
    this.speakerId,
    final List<String> relatedItems = const [],
    final List<String> tags = const [],
  }) : _relatedItems = relatedItems,
       _tags = tags,
       super._();

  factory _$ActionItemResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$ActionItemResultImplFromJson(json);

  /// Unique identifier
  @override
  final String id;

  /// Description of the action
  @override
  final String description;

  /// Assigned person (if mentioned)
  @override
  final String? assignee;

  /// Due date (if mentioned)
  @override
  final DateTime? dueDate;

  /// Priority level
  @override
  @JsonKey()
  final ActionItemPriority priority;

  /// Context where it was mentioned
  @override
  final String? context;

  /// Confidence in extraction accuracy
  @override
  @JsonKey()
  final double confidence;

  /// Status of the action item
  @override
  @JsonKey()
  final ActionItemStatus status;

  /// Timestamp where mentioned
  @override
  final int? mentionedAtMs;

  /// Speaker who mentioned it
  @override
  final String? speakerId;

  /// Related action items
  final List<String> _relatedItems;

  /// Related action items
  @override
  @JsonKey()
  List<String> get relatedItems {
    if (_relatedItems is EqualUnmodifiableListView) return _relatedItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_relatedItems);
  }

  /// Categories or tags
  final List<String> _tags;

  /// Categories or tags
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  String toString() {
    return 'ActionItemResult(id: $id, description: $description, assignee: $assignee, dueDate: $dueDate, priority: $priority, context: $context, confidence: $confidence, status: $status, mentionedAtMs: $mentionedAtMs, speakerId: $speakerId, relatedItems: $relatedItems, tags: $tags)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ActionItemResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.assignee, assignee) ||
                other.assignee == assignee) &&
            (identical(other.dueDate, dueDate) || other.dueDate == dueDate) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.context, context) || other.context == context) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.mentionedAtMs, mentionedAtMs) ||
                other.mentionedAtMs == mentionedAtMs) &&
            (identical(other.speakerId, speakerId) ||
                other.speakerId == speakerId) &&
            const DeepCollectionEquality().equals(
              other._relatedItems,
              _relatedItems,
            ) &&
            const DeepCollectionEquality().equals(other._tags, _tags));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    description,
    assignee,
    dueDate,
    priority,
    context,
    confidence,
    status,
    mentionedAtMs,
    speakerId,
    const DeepCollectionEquality().hash(_relatedItems),
    const DeepCollectionEquality().hash(_tags),
  );

  /// Create a copy of ActionItemResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ActionItemResultImplCopyWith<_$ActionItemResultImpl> get copyWith =>
      __$$ActionItemResultImplCopyWithImpl<_$ActionItemResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ActionItemResultImplToJson(this);
  }
}

abstract class _ActionItemResult extends ActionItemResult {
  const factory _ActionItemResult({
    required final String id,
    required final String description,
    final String? assignee,
    final DateTime? dueDate,
    final ActionItemPriority priority,
    final String? context,
    final double confidence,
    final ActionItemStatus status,
    final int? mentionedAtMs,
    final String? speakerId,
    final List<String> relatedItems,
    final List<String> tags,
  }) = _$ActionItemResultImpl;
  const _ActionItemResult._() : super._();

  factory _ActionItemResult.fromJson(Map<String, dynamic> json) =
      _$ActionItemResultImpl.fromJson;

  /// Unique identifier
  @override
  String get id;

  /// Description of the action
  @override
  String get description;

  /// Assigned person (if mentioned)
  @override
  String? get assignee;

  /// Due date (if mentioned)
  @override
  DateTime? get dueDate;

  /// Priority level
  @override
  ActionItemPriority get priority;

  /// Context where it was mentioned
  @override
  String? get context;

  /// Confidence in extraction accuracy
  @override
  double get confidence;

  /// Status of the action item
  @override
  ActionItemStatus get status;

  /// Timestamp where mentioned
  @override
  int? get mentionedAtMs;

  /// Speaker who mentioned it
  @override
  String? get speakerId;

  /// Related action items
  @override
  List<String> get relatedItems;

  /// Categories or tags
  @override
  List<String> get tags;

  /// Create a copy of ActionItemResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ActionItemResultImplCopyWith<_$ActionItemResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

SentimentAnalysisResult _$SentimentAnalysisResultFromJson(
  Map<String, dynamic> json,
) {
  return _SentimentAnalysisResult.fromJson(json);
}

/// @nodoc
mixin _$SentimentAnalysisResult {
  /// Overall sentiment
  SentimentType get overallSentiment => throw _privateConstructorUsedError;

  /// Confidence in sentiment analysis
  double get confidence => throw _privateConstructorUsedError;

  /// Detailed emotion breakdown
  Map<String, double> get emotions => throw _privateConstructorUsedError;

  /// Conversation tone
  String? get tone => throw _privateConstructorUsedError;

  /// Sentiment progression over time
  List<SentimentTimePoint> get progression =>
      throw _privateConstructorUsedError;

  /// Participant-specific sentiment
  Map<String, SentimentType> get participantSentiments =>
      throw _privateConstructorUsedError;

  /// Key phrases that influenced sentiment
  List<String> get keyPhrases => throw _privateConstructorUsedError;

  /// Serializes this SentimentAnalysisResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SentimentAnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SentimentAnalysisResultCopyWith<SentimentAnalysisResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SentimentAnalysisResultCopyWith<$Res> {
  factory $SentimentAnalysisResultCopyWith(
    SentimentAnalysisResult value,
    $Res Function(SentimentAnalysisResult) then,
  ) = _$SentimentAnalysisResultCopyWithImpl<$Res, SentimentAnalysisResult>;
  @useResult
  $Res call({
    SentimentType overallSentiment,
    double confidence,
    Map<String, double> emotions,
    String? tone,
    List<SentimentTimePoint> progression,
    Map<String, SentimentType> participantSentiments,
    List<String> keyPhrases,
  });
}

/// @nodoc
class _$SentimentAnalysisResultCopyWithImpl<
  $Res,
  $Val extends SentimentAnalysisResult
>
    implements $SentimentAnalysisResultCopyWith<$Res> {
  _$SentimentAnalysisResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SentimentAnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? overallSentiment = null,
    Object? confidence = null,
    Object? emotions = null,
    Object? tone = freezed,
    Object? progression = null,
    Object? participantSentiments = null,
    Object? keyPhrases = null,
  }) {
    return _then(
      _value.copyWith(
            overallSentiment:
                null == overallSentiment
                    ? _value.overallSentiment
                    : overallSentiment // ignore: cast_nullable_to_non_nullable
                        as SentimentType,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
            emotions:
                null == emotions
                    ? _value.emotions
                    : emotions // ignore: cast_nullable_to_non_nullable
                        as Map<String, double>,
            tone:
                freezed == tone
                    ? _value.tone
                    : tone // ignore: cast_nullable_to_non_nullable
                        as String?,
            progression:
                null == progression
                    ? _value.progression
                    : progression // ignore: cast_nullable_to_non_nullable
                        as List<SentimentTimePoint>,
            participantSentiments:
                null == participantSentiments
                    ? _value.participantSentiments
                    : participantSentiments // ignore: cast_nullable_to_non_nullable
                        as Map<String, SentimentType>,
            keyPhrases:
                null == keyPhrases
                    ? _value.keyPhrases
                    : keyPhrases // ignore: cast_nullable_to_non_nullable
                        as List<String>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SentimentAnalysisResultImplCopyWith<$Res>
    implements $SentimentAnalysisResultCopyWith<$Res> {
  factory _$$SentimentAnalysisResultImplCopyWith(
    _$SentimentAnalysisResultImpl value,
    $Res Function(_$SentimentAnalysisResultImpl) then,
  ) = __$$SentimentAnalysisResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    SentimentType overallSentiment,
    double confidence,
    Map<String, double> emotions,
    String? tone,
    List<SentimentTimePoint> progression,
    Map<String, SentimentType> participantSentiments,
    List<String> keyPhrases,
  });
}

/// @nodoc
class __$$SentimentAnalysisResultImplCopyWithImpl<$Res>
    extends
        _$SentimentAnalysisResultCopyWithImpl<
          $Res,
          _$SentimentAnalysisResultImpl
        >
    implements _$$SentimentAnalysisResultImplCopyWith<$Res> {
  __$$SentimentAnalysisResultImplCopyWithImpl(
    _$SentimentAnalysisResultImpl _value,
    $Res Function(_$SentimentAnalysisResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SentimentAnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? overallSentiment = null,
    Object? confidence = null,
    Object? emotions = null,
    Object? tone = freezed,
    Object? progression = null,
    Object? participantSentiments = null,
    Object? keyPhrases = null,
  }) {
    return _then(
      _$SentimentAnalysisResultImpl(
        overallSentiment:
            null == overallSentiment
                ? _value.overallSentiment
                : overallSentiment // ignore: cast_nullable_to_non_nullable
                    as SentimentType,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
        emotions:
            null == emotions
                ? _value._emotions
                : emotions // ignore: cast_nullable_to_non_nullable
                    as Map<String, double>,
        tone:
            freezed == tone
                ? _value.tone
                : tone // ignore: cast_nullable_to_non_nullable
                    as String?,
        progression:
            null == progression
                ? _value._progression
                : progression // ignore: cast_nullable_to_non_nullable
                    as List<SentimentTimePoint>,
        participantSentiments:
            null == participantSentiments
                ? _value._participantSentiments
                : participantSentiments // ignore: cast_nullable_to_non_nullable
                    as Map<String, SentimentType>,
        keyPhrases:
            null == keyPhrases
                ? _value._keyPhrases
                : keyPhrases // ignore: cast_nullable_to_non_nullable
                    as List<String>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SentimentAnalysisResultImpl extends _SentimentAnalysisResult {
  const _$SentimentAnalysisResultImpl({
    required this.overallSentiment,
    required this.confidence,
    required final Map<String, double> emotions,
    this.tone,
    final List<SentimentTimePoint> progression = const [],
    final Map<String, SentimentType> participantSentiments = const {},
    final List<String> keyPhrases = const [],
  }) : _emotions = emotions,
       _progression = progression,
       _participantSentiments = participantSentiments,
       _keyPhrases = keyPhrases,
       super._();

  factory _$SentimentAnalysisResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$SentimentAnalysisResultImplFromJson(json);

  /// Overall sentiment
  @override
  final SentimentType overallSentiment;

  /// Confidence in sentiment analysis
  @override
  final double confidence;

  /// Detailed emotion breakdown
  final Map<String, double> _emotions;

  /// Detailed emotion breakdown
  @override
  Map<String, double> get emotions {
    if (_emotions is EqualUnmodifiableMapView) return _emotions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_emotions);
  }

  /// Conversation tone
  @override
  final String? tone;

  /// Sentiment progression over time
  final List<SentimentTimePoint> _progression;

  /// Sentiment progression over time
  @override
  @JsonKey()
  List<SentimentTimePoint> get progression {
    if (_progression is EqualUnmodifiableListView) return _progression;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_progression);
  }

  /// Participant-specific sentiment
  final Map<String, SentimentType> _participantSentiments;

  /// Participant-specific sentiment
  @override
  @JsonKey()
  Map<String, SentimentType> get participantSentiments {
    if (_participantSentiments is EqualUnmodifiableMapView)
      return _participantSentiments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_participantSentiments);
  }

  /// Key phrases that influenced sentiment
  final List<String> _keyPhrases;

  /// Key phrases that influenced sentiment
  @override
  @JsonKey()
  List<String> get keyPhrases {
    if (_keyPhrases is EqualUnmodifiableListView) return _keyPhrases;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_keyPhrases);
  }

  @override
  String toString() {
    return 'SentimentAnalysisResult(overallSentiment: $overallSentiment, confidence: $confidence, emotions: $emotions, tone: $tone, progression: $progression, participantSentiments: $participantSentiments, keyPhrases: $keyPhrases)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SentimentAnalysisResultImpl &&
            (identical(other.overallSentiment, overallSentiment) ||
                other.overallSentiment == overallSentiment) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            const DeepCollectionEquality().equals(other._emotions, _emotions) &&
            (identical(other.tone, tone) || other.tone == tone) &&
            const DeepCollectionEquality().equals(
              other._progression,
              _progression,
            ) &&
            const DeepCollectionEquality().equals(
              other._participantSentiments,
              _participantSentiments,
            ) &&
            const DeepCollectionEquality().equals(
              other._keyPhrases,
              _keyPhrases,
            ));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    overallSentiment,
    confidence,
    const DeepCollectionEquality().hash(_emotions),
    tone,
    const DeepCollectionEquality().hash(_progression),
    const DeepCollectionEquality().hash(_participantSentiments),
    const DeepCollectionEquality().hash(_keyPhrases),
  );

  /// Create a copy of SentimentAnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SentimentAnalysisResultImplCopyWith<_$SentimentAnalysisResultImpl>
  get copyWith => __$$SentimentAnalysisResultImplCopyWithImpl<
    _$SentimentAnalysisResultImpl
  >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SentimentAnalysisResultImplToJson(this);
  }
}

abstract class _SentimentAnalysisResult extends SentimentAnalysisResult {
  const factory _SentimentAnalysisResult({
    required final SentimentType overallSentiment,
    required final double confidence,
    required final Map<String, double> emotions,
    final String? tone,
    final List<SentimentTimePoint> progression,
    final Map<String, SentimentType> participantSentiments,
    final List<String> keyPhrases,
  }) = _$SentimentAnalysisResultImpl;
  const _SentimentAnalysisResult._() : super._();

  factory _SentimentAnalysisResult.fromJson(Map<String, dynamic> json) =
      _$SentimentAnalysisResultImpl.fromJson;

  /// Overall sentiment
  @override
  SentimentType get overallSentiment;

  /// Confidence in sentiment analysis
  @override
  double get confidence;

  /// Detailed emotion breakdown
  @override
  Map<String, double> get emotions;

  /// Conversation tone
  @override
  String? get tone;

  /// Sentiment progression over time
  @override
  List<SentimentTimePoint> get progression;

  /// Participant-specific sentiment
  @override
  Map<String, SentimentType> get participantSentiments;

  /// Key phrases that influenced sentiment
  @override
  List<String> get keyPhrases;

  /// Create a copy of SentimentAnalysisResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SentimentAnalysisResultImplCopyWith<_$SentimentAnalysisResultImpl>
  get copyWith => throw _privateConstructorUsedError;
}

SentimentTimePoint _$SentimentTimePointFromJson(Map<String, dynamic> json) {
  return _SentimentTimePoint.fromJson(json);
}

/// @nodoc
mixin _$SentimentTimePoint {
  int get timeMs => throw _privateConstructorUsedError;
  SentimentType get sentiment => throw _privateConstructorUsedError;
  double get confidence => throw _privateConstructorUsedError;

  /// Serializes this SentimentTimePoint to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SentimentTimePoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SentimentTimePointCopyWith<SentimentTimePoint> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SentimentTimePointCopyWith<$Res> {
  factory $SentimentTimePointCopyWith(
    SentimentTimePoint value,
    $Res Function(SentimentTimePoint) then,
  ) = _$SentimentTimePointCopyWithImpl<$Res, SentimentTimePoint>;
  @useResult
  $Res call({int timeMs, SentimentType sentiment, double confidence});
}

/// @nodoc
class _$SentimentTimePointCopyWithImpl<$Res, $Val extends SentimentTimePoint>
    implements $SentimentTimePointCopyWith<$Res> {
  _$SentimentTimePointCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SentimentTimePoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timeMs = null,
    Object? sentiment = null,
    Object? confidence = null,
  }) {
    return _then(
      _value.copyWith(
            timeMs:
                null == timeMs
                    ? _value.timeMs
                    : timeMs // ignore: cast_nullable_to_non_nullable
                        as int,
            sentiment:
                null == sentiment
                    ? _value.sentiment
                    : sentiment // ignore: cast_nullable_to_non_nullable
                        as SentimentType,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$SentimentTimePointImplCopyWith<$Res>
    implements $SentimentTimePointCopyWith<$Res> {
  factory _$$SentimentTimePointImplCopyWith(
    _$SentimentTimePointImpl value,
    $Res Function(_$SentimentTimePointImpl) then,
  ) = __$$SentimentTimePointImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int timeMs, SentimentType sentiment, double confidence});
}

/// @nodoc
class __$$SentimentTimePointImplCopyWithImpl<$Res>
    extends _$SentimentTimePointCopyWithImpl<$Res, _$SentimentTimePointImpl>
    implements _$$SentimentTimePointImplCopyWith<$Res> {
  __$$SentimentTimePointImplCopyWithImpl(
    _$SentimentTimePointImpl _value,
    $Res Function(_$SentimentTimePointImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of SentimentTimePoint
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? timeMs = null,
    Object? sentiment = null,
    Object? confidence = null,
  }) {
    return _then(
      _$SentimentTimePointImpl(
        timeMs:
            null == timeMs
                ? _value.timeMs
                : timeMs // ignore: cast_nullable_to_non_nullable
                    as int,
        sentiment:
            null == sentiment
                ? _value.sentiment
                : sentiment // ignore: cast_nullable_to_non_nullable
                    as SentimentType,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$SentimentTimePointImpl implements _SentimentTimePoint {
  const _$SentimentTimePointImpl({
    required this.timeMs,
    required this.sentiment,
    required this.confidence,
  });

  factory _$SentimentTimePointImpl.fromJson(Map<String, dynamic> json) =>
      _$$SentimentTimePointImplFromJson(json);

  @override
  final int timeMs;
  @override
  final SentimentType sentiment;
  @override
  final double confidence;

  @override
  String toString() {
    return 'SentimentTimePoint(timeMs: $timeMs, sentiment: $sentiment, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SentimentTimePointImpl &&
            (identical(other.timeMs, timeMs) || other.timeMs == timeMs) &&
            (identical(other.sentiment, sentiment) ||
                other.sentiment == sentiment) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, timeMs, sentiment, confidence);

  /// Create a copy of SentimentTimePoint
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SentimentTimePointImplCopyWith<_$SentimentTimePointImpl> get copyWith =>
      __$$SentimentTimePointImplCopyWithImpl<_$SentimentTimePointImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$SentimentTimePointImplToJson(this);
  }
}

abstract class _SentimentTimePoint implements SentimentTimePoint {
  const factory _SentimentTimePoint({
    required final int timeMs,
    required final SentimentType sentiment,
    required final double confidence,
  }) = _$SentimentTimePointImpl;

  factory _SentimentTimePoint.fromJson(Map<String, dynamic> json) =
      _$SentimentTimePointImpl.fromJson;

  @override
  int get timeMs;
  @override
  SentimentType get sentiment;
  @override
  double get confidence;

  /// Create a copy of SentimentTimePoint
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SentimentTimePointImplCopyWith<_$SentimentTimePointImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TopicResult _$TopicResultFromJson(Map<String, dynamic> json) {
  return _TopicResult.fromJson(json);
}

/// @nodoc
mixin _$TopicResult {
  /// Topic name or title
  String get name => throw _privateConstructorUsedError;

  /// Relevance score (0.0 to 1.0)
  double get relevance => throw _privateConstructorUsedError;

  /// Keywords associated with topic
  List<String> get keywords => throw _privateConstructorUsedError;

  /// Category of the topic
  String? get category => throw _privateConstructorUsedError;

  /// Description of the topic
  String? get description => throw _privateConstructorUsedError;

  /// Time ranges where topic was discussed
  List<TimeRange> get timeRanges => throw _privateConstructorUsedError;

  /// Participants who discussed this topic
  List<String> get participants => throw _privateConstructorUsedError;

  /// Related topics
  List<String> get relatedTopics => throw _privateConstructorUsedError;

  /// Confidence in topic identification
  double get confidence => throw _privateConstructorUsedError;

  /// Serializes this TopicResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TopicResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TopicResultCopyWith<TopicResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TopicResultCopyWith<$Res> {
  factory $TopicResultCopyWith(
    TopicResult value,
    $Res Function(TopicResult) then,
  ) = _$TopicResultCopyWithImpl<$Res, TopicResult>;
  @useResult
  $Res call({
    String name,
    double relevance,
    List<String> keywords,
    String? category,
    String? description,
    List<TimeRange> timeRanges,
    List<String> participants,
    List<String> relatedTopics,
    double confidence,
  });
}

/// @nodoc
class _$TopicResultCopyWithImpl<$Res, $Val extends TopicResult>
    implements $TopicResultCopyWith<$Res> {
  _$TopicResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TopicResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? relevance = null,
    Object? keywords = null,
    Object? category = freezed,
    Object? description = freezed,
    Object? timeRanges = null,
    Object? participants = null,
    Object? relatedTopics = null,
    Object? confidence = null,
  }) {
    return _then(
      _value.copyWith(
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            relevance:
                null == relevance
                    ? _value.relevance
                    : relevance // ignore: cast_nullable_to_non_nullable
                        as double,
            keywords:
                null == keywords
                    ? _value.keywords
                    : keywords // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            category:
                freezed == category
                    ? _value.category
                    : category // ignore: cast_nullable_to_non_nullable
                        as String?,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            timeRanges:
                null == timeRanges
                    ? _value.timeRanges
                    : timeRanges // ignore: cast_nullable_to_non_nullable
                        as List<TimeRange>,
            participants:
                null == participants
                    ? _value.participants
                    : participants // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            relatedTopics:
                null == relatedTopics
                    ? _value.relatedTopics
                    : relatedTopics // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TopicResultImplCopyWith<$Res>
    implements $TopicResultCopyWith<$Res> {
  factory _$$TopicResultImplCopyWith(
    _$TopicResultImpl value,
    $Res Function(_$TopicResultImpl) then,
  ) = __$$TopicResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String name,
    double relevance,
    List<String> keywords,
    String? category,
    String? description,
    List<TimeRange> timeRanges,
    List<String> participants,
    List<String> relatedTopics,
    double confidence,
  });
}

/// @nodoc
class __$$TopicResultImplCopyWithImpl<$Res>
    extends _$TopicResultCopyWithImpl<$Res, _$TopicResultImpl>
    implements _$$TopicResultImplCopyWith<$Res> {
  __$$TopicResultImplCopyWithImpl(
    _$TopicResultImpl _value,
    $Res Function(_$TopicResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TopicResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? relevance = null,
    Object? keywords = null,
    Object? category = freezed,
    Object? description = freezed,
    Object? timeRanges = null,
    Object? participants = null,
    Object? relatedTopics = null,
    Object? confidence = null,
  }) {
    return _then(
      _$TopicResultImpl(
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        relevance:
            null == relevance
                ? _value.relevance
                : relevance // ignore: cast_nullable_to_non_nullable
                    as double,
        keywords:
            null == keywords
                ? _value._keywords
                : keywords // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        category:
            freezed == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                    as String?,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        timeRanges:
            null == timeRanges
                ? _value._timeRanges
                : timeRanges // ignore: cast_nullable_to_non_nullable
                    as List<TimeRange>,
        participants:
            null == participants
                ? _value._participants
                : participants // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        relatedTopics:
            null == relatedTopics
                ? _value._relatedTopics
                : relatedTopics // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TopicResultImpl extends _TopicResult {
  const _$TopicResultImpl({
    required this.name,
    required this.relevance,
    final List<String> keywords = const [],
    this.category,
    this.description,
    final List<TimeRange> timeRanges = const [],
    final List<String> participants = const [],
    final List<String> relatedTopics = const [],
    this.confidence = 0.0,
  }) : _keywords = keywords,
       _timeRanges = timeRanges,
       _participants = participants,
       _relatedTopics = relatedTopics,
       super._();

  factory _$TopicResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$TopicResultImplFromJson(json);

  /// Topic name or title
  @override
  final String name;

  /// Relevance score (0.0 to 1.0)
  @override
  final double relevance;

  /// Keywords associated with topic
  final List<String> _keywords;

  /// Keywords associated with topic
  @override
  @JsonKey()
  List<String> get keywords {
    if (_keywords is EqualUnmodifiableListView) return _keywords;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_keywords);
  }

  /// Category of the topic
  @override
  final String? category;

  /// Description of the topic
  @override
  final String? description;

  /// Time ranges where topic was discussed
  final List<TimeRange> _timeRanges;

  /// Time ranges where topic was discussed
  @override
  @JsonKey()
  List<TimeRange> get timeRanges {
    if (_timeRanges is EqualUnmodifiableListView) return _timeRanges;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_timeRanges);
  }

  /// Participants who discussed this topic
  final List<String> _participants;

  /// Participants who discussed this topic
  @override
  @JsonKey()
  List<String> get participants {
    if (_participants is EqualUnmodifiableListView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participants);
  }

  /// Related topics
  final List<String> _relatedTopics;

  /// Related topics
  @override
  @JsonKey()
  List<String> get relatedTopics {
    if (_relatedTopics is EqualUnmodifiableListView) return _relatedTopics;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_relatedTopics);
  }

  /// Confidence in topic identification
  @override
  @JsonKey()
  final double confidence;

  @override
  String toString() {
    return 'TopicResult(name: $name, relevance: $relevance, keywords: $keywords, category: $category, description: $description, timeRanges: $timeRanges, participants: $participants, relatedTopics: $relatedTopics, confidence: $confidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TopicResultImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.relevance, relevance) ||
                other.relevance == relevance) &&
            const DeepCollectionEquality().equals(other._keywords, _keywords) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(
              other._timeRanges,
              _timeRanges,
            ) &&
            const DeepCollectionEquality().equals(
              other._participants,
              _participants,
            ) &&
            const DeepCollectionEquality().equals(
              other._relatedTopics,
              _relatedTopics,
            ) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    name,
    relevance,
    const DeepCollectionEquality().hash(_keywords),
    category,
    description,
    const DeepCollectionEquality().hash(_timeRanges),
    const DeepCollectionEquality().hash(_participants),
    const DeepCollectionEquality().hash(_relatedTopics),
    confidence,
  );

  /// Create a copy of TopicResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TopicResultImplCopyWith<_$TopicResultImpl> get copyWith =>
      __$$TopicResultImplCopyWithImpl<_$TopicResultImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TopicResultImplToJson(this);
  }
}

abstract class _TopicResult extends TopicResult {
  const factory _TopicResult({
    required final String name,
    required final double relevance,
    final List<String> keywords,
    final String? category,
    final String? description,
    final List<TimeRange> timeRanges,
    final List<String> participants,
    final List<String> relatedTopics,
    final double confidence,
  }) = _$TopicResultImpl;
  const _TopicResult._() : super._();

  factory _TopicResult.fromJson(Map<String, dynamic> json) =
      _$TopicResultImpl.fromJson;

  /// Topic name or title
  @override
  String get name;

  /// Relevance score (0.0 to 1.0)
  @override
  double get relevance;

  /// Keywords associated with topic
  @override
  List<String> get keywords;

  /// Category of the topic
  @override
  String? get category;

  /// Description of the topic
  @override
  String? get description;

  /// Time ranges where topic was discussed
  @override
  List<TimeRange> get timeRanges;

  /// Participants who discussed this topic
  @override
  List<String> get participants;

  /// Related topics
  @override
  List<String> get relatedTopics;

  /// Confidence in topic identification
  @override
  double get confidence;

  /// Create a copy of TopicResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TopicResultImplCopyWith<_$TopicResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

TimeRange _$TimeRangeFromJson(Map<String, dynamic> json) {
  return _TimeRange.fromJson(json);
}

/// @nodoc
mixin _$TimeRange {
  int get startMs => throw _privateConstructorUsedError;
  int get endMs => throw _privateConstructorUsedError;

  /// Serializes this TimeRange to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TimeRange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TimeRangeCopyWith<TimeRange> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TimeRangeCopyWith<$Res> {
  factory $TimeRangeCopyWith(TimeRange value, $Res Function(TimeRange) then) =
      _$TimeRangeCopyWithImpl<$Res, TimeRange>;
  @useResult
  $Res call({int startMs, int endMs});
}

/// @nodoc
class _$TimeRangeCopyWithImpl<$Res, $Val extends TimeRange>
    implements $TimeRangeCopyWith<$Res> {
  _$TimeRangeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TimeRange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? startMs = null, Object? endMs = null}) {
    return _then(
      _value.copyWith(
            startMs:
                null == startMs
                    ? _value.startMs
                    : startMs // ignore: cast_nullable_to_non_nullable
                        as int,
            endMs:
                null == endMs
                    ? _value.endMs
                    : endMs // ignore: cast_nullable_to_non_nullable
                        as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TimeRangeImplCopyWith<$Res>
    implements $TimeRangeCopyWith<$Res> {
  factory _$$TimeRangeImplCopyWith(
    _$TimeRangeImpl value,
    $Res Function(_$TimeRangeImpl) then,
  ) = __$$TimeRangeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int startMs, int endMs});
}

/// @nodoc
class __$$TimeRangeImplCopyWithImpl<$Res>
    extends _$TimeRangeCopyWithImpl<$Res, _$TimeRangeImpl>
    implements _$$TimeRangeImplCopyWith<$Res> {
  __$$TimeRangeImplCopyWithImpl(
    _$TimeRangeImpl _value,
    $Res Function(_$TimeRangeImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TimeRange
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? startMs = null, Object? endMs = null}) {
    return _then(
      _$TimeRangeImpl(
        startMs:
            null == startMs
                ? _value.startMs
                : startMs // ignore: cast_nullable_to_non_nullable
                    as int,
        endMs:
            null == endMs
                ? _value.endMs
                : endMs // ignore: cast_nullable_to_non_nullable
                    as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TimeRangeImpl extends _TimeRange {
  const _$TimeRangeImpl({required this.startMs, required this.endMs})
    : super._();

  factory _$TimeRangeImpl.fromJson(Map<String, dynamic> json) =>
      _$$TimeRangeImplFromJson(json);

  @override
  final int startMs;
  @override
  final int endMs;

  @override
  String toString() {
    return 'TimeRange(startMs: $startMs, endMs: $endMs)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TimeRangeImpl &&
            (identical(other.startMs, startMs) || other.startMs == startMs) &&
            (identical(other.endMs, endMs) || other.endMs == endMs));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, startMs, endMs);

  /// Create a copy of TimeRange
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TimeRangeImplCopyWith<_$TimeRangeImpl> get copyWith =>
      __$$TimeRangeImplCopyWithImpl<_$TimeRangeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$TimeRangeImplToJson(this);
  }
}

abstract class _TimeRange extends TimeRange {
  const factory _TimeRange({
    required final int startMs,
    required final int endMs,
  }) = _$TimeRangeImpl;
  const _TimeRange._() : super._();

  factory _TimeRange.fromJson(Map<String, dynamic> json) =
      _$TimeRangeImpl.fromJson;

  @override
  int get startMs;
  @override
  int get endMs;

  /// Create a copy of TimeRange
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TimeRangeImplCopyWith<_$TimeRangeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
