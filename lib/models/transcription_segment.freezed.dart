// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'transcription_segment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

TranscriptionSegment _$TranscriptionSegmentFromJson(Map<String, dynamic> json) {
  return _TranscriptionSegment.fromJson(json);
}

/// @nodoc
mixin _$TranscriptionSegment {
  /// Transcribed text content
  String get text => throw _privateConstructorUsedError;

  /// Start time of the segment
  DateTime get startTime => throw _privateConstructorUsedError;

  /// End time of the segment
  DateTime get endTime => throw _privateConstructorUsedError;

  /// Confidence score for the transcription (0.0 to 1.0)
  double get confidence => throw _privateConstructorUsedError;

  /// Speaker information (if available)
  String? get speakerId => throw _privateConstructorUsedError;

  /// Speaker name (if known)
  String? get speakerName => throw _privateConstructorUsedError;

  /// Language code for the transcribed text
  String get language => throw _privateConstructorUsedError;

  /// Whether this is a final transcription or interim result
  bool get isFinal => throw _privateConstructorUsedError;

  /// Unique identifier for this segment
  String? get segmentId => throw _privateConstructorUsedError;

  /// Transcription backend used
  @JsonKey(fromJson: _backendFromJson, toJson: _backendToJson)
  TranscriptionBackend? get backend => throw _privateConstructorUsedError;

  /// Processing time in milliseconds
  int? get processingTimeMs => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Serializes this TranscriptionSegment to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TranscriptionSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranscriptionSegmentCopyWith<TranscriptionSegment> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptionSegmentCopyWith<$Res> {
  factory $TranscriptionSegmentCopyWith(
    TranscriptionSegment value,
    $Res Function(TranscriptionSegment) then,
  ) = _$TranscriptionSegmentCopyWithImpl<$Res, TranscriptionSegment>;
  @useResult
  $Res call({
    String text,
    DateTime startTime,
    DateTime endTime,
    double confidence,
    String? speakerId,
    String? speakerName,
    String language,
    bool isFinal,
    String? segmentId,
    @JsonKey(fromJson: _backendFromJson, toJson: _backendToJson)
    TranscriptionBackend? backend,
    int? processingTimeMs,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$TranscriptionSegmentCopyWithImpl<
  $Res,
  $Val extends TranscriptionSegment
>
    implements $TranscriptionSegmentCopyWith<$Res> {
  _$TranscriptionSegmentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranscriptionSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? confidence = null,
    Object? speakerId = freezed,
    Object? speakerName = freezed,
    Object? language = null,
    Object? isFinal = null,
    Object? segmentId = freezed,
    Object? backend = freezed,
    Object? processingTimeMs = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            text:
                null == text
                    ? _value.text
                    : text // ignore: cast_nullable_to_non_nullable
                        as String,
            startTime:
                null == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            endTime:
                null == endTime
                    ? _value.endTime
                    : endTime // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            confidence:
                null == confidence
                    ? _value.confidence
                    : confidence // ignore: cast_nullable_to_non_nullable
                        as double,
            speakerId:
                freezed == speakerId
                    ? _value.speakerId
                    : speakerId // ignore: cast_nullable_to_non_nullable
                        as String?,
            speakerName:
                freezed == speakerName
                    ? _value.speakerName
                    : speakerName // ignore: cast_nullable_to_non_nullable
                        as String?,
            language:
                null == language
                    ? _value.language
                    : language // ignore: cast_nullable_to_non_nullable
                        as String,
            isFinal:
                null == isFinal
                    ? _value.isFinal
                    : isFinal // ignore: cast_nullable_to_non_nullable
                        as bool,
            segmentId:
                freezed == segmentId
                    ? _value.segmentId
                    : segmentId // ignore: cast_nullable_to_non_nullable
                        as String?,
            backend:
                freezed == backend
                    ? _value.backend
                    : backend // ignore: cast_nullable_to_non_nullable
                        as TranscriptionBackend?,
            processingTimeMs:
                freezed == processingTimeMs
                    ? _value.processingTimeMs
                    : processingTimeMs // ignore: cast_nullable_to_non_nullable
                        as int?,
            metadata:
                null == metadata
                    ? _value.metadata
                    : metadata // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TranscriptionSegmentImplCopyWith<$Res>
    implements $TranscriptionSegmentCopyWith<$Res> {
  factory _$$TranscriptionSegmentImplCopyWith(
    _$TranscriptionSegmentImpl value,
    $Res Function(_$TranscriptionSegmentImpl) then,
  ) = __$$TranscriptionSegmentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String text,
    DateTime startTime,
    DateTime endTime,
    double confidence,
    String? speakerId,
    String? speakerName,
    String language,
    bool isFinal,
    String? segmentId,
    @JsonKey(fromJson: _backendFromJson, toJson: _backendToJson)
    TranscriptionBackend? backend,
    int? processingTimeMs,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$TranscriptionSegmentImplCopyWithImpl<$Res>
    extends _$TranscriptionSegmentCopyWithImpl<$Res, _$TranscriptionSegmentImpl>
    implements _$$TranscriptionSegmentImplCopyWith<$Res> {
  __$$TranscriptionSegmentImplCopyWithImpl(
    _$TranscriptionSegmentImpl _value,
    $Res Function(_$TranscriptionSegmentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TranscriptionSegment
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? text = null,
    Object? startTime = null,
    Object? endTime = null,
    Object? confidence = null,
    Object? speakerId = freezed,
    Object? speakerName = freezed,
    Object? language = null,
    Object? isFinal = null,
    Object? segmentId = freezed,
    Object? backend = freezed,
    Object? processingTimeMs = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$TranscriptionSegmentImpl(
        text:
            null == text
                ? _value.text
                : text // ignore: cast_nullable_to_non_nullable
                    as String,
        startTime:
            null == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        endTime:
            null == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        confidence:
            null == confidence
                ? _value.confidence
                : confidence // ignore: cast_nullable_to_non_nullable
                    as double,
        speakerId:
            freezed == speakerId
                ? _value.speakerId
                : speakerId // ignore: cast_nullable_to_non_nullable
                    as String?,
        speakerName:
            freezed == speakerName
                ? _value.speakerName
                : speakerName // ignore: cast_nullable_to_non_nullable
                    as String?,
        language:
            null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                    as String,
        isFinal:
            null == isFinal
                ? _value.isFinal
                : isFinal // ignore: cast_nullable_to_non_nullable
                    as bool,
        segmentId:
            freezed == segmentId
                ? _value.segmentId
                : segmentId // ignore: cast_nullable_to_non_nullable
                    as String?,
        backend:
            freezed == backend
                ? _value.backend
                : backend // ignore: cast_nullable_to_non_nullable
                    as TranscriptionBackend?,
        processingTimeMs:
            freezed == processingTimeMs
                ? _value.processingTimeMs
                : processingTimeMs // ignore: cast_nullable_to_non_nullable
                    as int?,
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
class _$TranscriptionSegmentImpl extends _TranscriptionSegment {
  const _$TranscriptionSegmentImpl({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.confidence,
    this.speakerId,
    this.speakerName,
    this.language = 'en-US',
    this.isFinal = true,
    this.segmentId,
    @JsonKey(fromJson: _backendFromJson, toJson: _backendToJson) this.backend,
    this.processingTimeMs,
    final Map<String, dynamic> metadata = const {},
  }) : _metadata = metadata,
       super._();

  factory _$TranscriptionSegmentImpl.fromJson(Map<String, dynamic> json) =>
      _$$TranscriptionSegmentImplFromJson(json);

  /// Transcribed text content
  @override
  final String text;

  /// Start time of the segment
  @override
  final DateTime startTime;

  /// End time of the segment
  @override
  final DateTime endTime;

  /// Confidence score for the transcription (0.0 to 1.0)
  @override
  final double confidence;

  /// Speaker information (if available)
  @override
  final String? speakerId;

  /// Speaker name (if known)
  @override
  final String? speakerName;

  /// Language code for the transcribed text
  @override
  @JsonKey()
  final String language;

  /// Whether this is a final transcription or interim result
  @override
  @JsonKey()
  final bool isFinal;

  /// Unique identifier for this segment
  @override
  final String? segmentId;

  /// Transcription backend used
  @override
  @JsonKey(fromJson: _backendFromJson, toJson: _backendToJson)
  final TranscriptionBackend? backend;

  /// Processing time in milliseconds
  @override
  final int? processingTimeMs;

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
    return 'TranscriptionSegment(text: $text, startTime: $startTime, endTime: $endTime, confidence: $confidence, speakerId: $speakerId, speakerName: $speakerName, language: $language, isFinal: $isFinal, segmentId: $segmentId, backend: $backend, processingTimeMs: $processingTimeMs, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptionSegmentImpl &&
            (identical(other.text, text) || other.text == text) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.confidence, confidence) ||
                other.confidence == confidence) &&
            (identical(other.speakerId, speakerId) ||
                other.speakerId == speakerId) &&
            (identical(other.speakerName, speakerName) ||
                other.speakerName == speakerName) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.isFinal, isFinal) || other.isFinal == isFinal) &&
            (identical(other.segmentId, segmentId) ||
                other.segmentId == segmentId) &&
            (identical(other.backend, backend) || other.backend == backend) &&
            (identical(other.processingTimeMs, processingTimeMs) ||
                other.processingTimeMs == processingTimeMs) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    text,
    startTime,
    endTime,
    confidence,
    speakerId,
    speakerName,
    language,
    isFinal,
    segmentId,
    backend,
    processingTimeMs,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of TranscriptionSegment
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptionSegmentImplCopyWith<_$TranscriptionSegmentImpl>
  get copyWith =>
      __$$TranscriptionSegmentImplCopyWithImpl<_$TranscriptionSegmentImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TranscriptionSegmentImplToJson(this);
  }
}

abstract class _TranscriptionSegment extends TranscriptionSegment {
  const factory _TranscriptionSegment({
    required final String text,
    required final DateTime startTime,
    required final DateTime endTime,
    required final double confidence,
    final String? speakerId,
    final String? speakerName,
    final String language,
    final bool isFinal,
    final String? segmentId,
    @JsonKey(fromJson: _backendFromJson, toJson: _backendToJson)
    final TranscriptionBackend? backend,
    final int? processingTimeMs,
    final Map<String, dynamic> metadata,
  }) = _$TranscriptionSegmentImpl;
  const _TranscriptionSegment._() : super._();

  factory _TranscriptionSegment.fromJson(Map<String, dynamic> json) =
      _$TranscriptionSegmentImpl.fromJson;

  /// Transcribed text content
  @override
  String get text;

  /// Start time of the segment
  @override
  DateTime get startTime;

  /// End time of the segment
  @override
  DateTime get endTime;

  /// Confidence score for the transcription (0.0 to 1.0)
  @override
  double get confidence;

  /// Speaker information (if available)
  @override
  String? get speakerId;

  /// Speaker name (if known)
  @override
  String? get speakerName;

  /// Language code for the transcribed text
  @override
  String get language;

  /// Whether this is a final transcription or interim result
  @override
  bool get isFinal;

  /// Unique identifier for this segment
  @override
  String? get segmentId;

  /// Transcription backend used
  @override
  @JsonKey(fromJson: _backendFromJson, toJson: _backendToJson)
  TranscriptionBackend? get backend;

  /// Processing time in milliseconds
  @override
  int? get processingTimeMs;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of TranscriptionSegment
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranscriptionSegmentImplCopyWith<_$TranscriptionSegmentImpl>
  get copyWith => throw _privateConstructorUsedError;
}

TranscriptionResult _$TranscriptionResultFromJson(Map<String, dynamic> json) {
  return _TranscriptionResult.fromJson(json);
}

/// @nodoc
mixin _$TranscriptionResult {
  /// Unique identifier for this transcription result
  String get id => throw _privateConstructorUsedError;

  /// List of transcription segments
  List<TranscriptionSegment> get segments => throw _privateConstructorUsedError;

  /// Overall confidence score for the entire transcription
  double get overallConfidence => throw _privateConstructorUsedError;

  /// Total duration of the transcription
  Duration get totalDuration => throw _privateConstructorUsedError;

  /// Language code for the transcription
  String get language => throw _privateConstructorUsedError;

  /// Transcription backend used
  String? get backend => throw _privateConstructorUsedError;

  /// Total processing time
  Duration? get processingTime => throw _privateConstructorUsedError;

  /// Number of speakers detected
  int get speakerCount => throw _privateConstructorUsedError;

  /// Whether speaker diarization was performed
  bool get hasSpeakerDiarization => throw _privateConstructorUsedError;

  /// Additional metadata for the entire transcription
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Timestamp when this result was created
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Serializes this TranscriptionResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of TranscriptionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TranscriptionResultCopyWith<TranscriptionResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TranscriptionResultCopyWith<$Res> {
  factory $TranscriptionResultCopyWith(
    TranscriptionResult value,
    $Res Function(TranscriptionResult) then,
  ) = _$TranscriptionResultCopyWithImpl<$Res, TranscriptionResult>;
  @useResult
  $Res call({
    String id,
    List<TranscriptionSegment> segments,
    double overallConfidence,
    Duration totalDuration,
    String language,
    String? backend,
    Duration? processingTime,
    int speakerCount,
    bool hasSpeakerDiarization,
    Map<String, dynamic> metadata,
    DateTime timestamp,
  });
}

/// @nodoc
class _$TranscriptionResultCopyWithImpl<$Res, $Val extends TranscriptionResult>
    implements $TranscriptionResultCopyWith<$Res> {
  _$TranscriptionResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TranscriptionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? segments = null,
    Object? overallConfidence = null,
    Object? totalDuration = null,
    Object? language = null,
    Object? backend = freezed,
    Object? processingTime = freezed,
    Object? speakerCount = null,
    Object? hasSpeakerDiarization = null,
    Object? metadata = null,
    Object? timestamp = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            segments:
                null == segments
                    ? _value.segments
                    : segments // ignore: cast_nullable_to_non_nullable
                        as List<TranscriptionSegment>,
            overallConfidence:
                null == overallConfidence
                    ? _value.overallConfidence
                    : overallConfidence // ignore: cast_nullable_to_non_nullable
                        as double,
            totalDuration:
                null == totalDuration
                    ? _value.totalDuration
                    : totalDuration // ignore: cast_nullable_to_non_nullable
                        as Duration,
            language:
                null == language
                    ? _value.language
                    : language // ignore: cast_nullable_to_non_nullable
                        as String,
            backend:
                freezed == backend
                    ? _value.backend
                    : backend // ignore: cast_nullable_to_non_nullable
                        as String?,
            processingTime:
                freezed == processingTime
                    ? _value.processingTime
                    : processingTime // ignore: cast_nullable_to_non_nullable
                        as Duration?,
            speakerCount:
                null == speakerCount
                    ? _value.speakerCount
                    : speakerCount // ignore: cast_nullable_to_non_nullable
                        as int,
            hasSpeakerDiarization:
                null == hasSpeakerDiarization
                    ? _value.hasSpeakerDiarization
                    : hasSpeakerDiarization // ignore: cast_nullable_to_non_nullable
                        as bool,
            metadata:
                null == metadata
                    ? _value.metadata
                    : metadata // ignore: cast_nullable_to_non_nullable
                        as Map<String, dynamic>,
            timestamp:
                null == timestamp
                    ? _value.timestamp
                    : timestamp // ignore: cast_nullable_to_non_nullable
                        as DateTime,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$TranscriptionResultImplCopyWith<$Res>
    implements $TranscriptionResultCopyWith<$Res> {
  factory _$$TranscriptionResultImplCopyWith(
    _$TranscriptionResultImpl value,
    $Res Function(_$TranscriptionResultImpl) then,
  ) = __$$TranscriptionResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    List<TranscriptionSegment> segments,
    double overallConfidence,
    Duration totalDuration,
    String language,
    String? backend,
    Duration? processingTime,
    int speakerCount,
    bool hasSpeakerDiarization,
    Map<String, dynamic> metadata,
    DateTime timestamp,
  });
}

/// @nodoc
class __$$TranscriptionResultImplCopyWithImpl<$Res>
    extends _$TranscriptionResultCopyWithImpl<$Res, _$TranscriptionResultImpl>
    implements _$$TranscriptionResultImplCopyWith<$Res> {
  __$$TranscriptionResultImplCopyWithImpl(
    _$TranscriptionResultImpl _value,
    $Res Function(_$TranscriptionResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of TranscriptionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? segments = null,
    Object? overallConfidence = null,
    Object? totalDuration = null,
    Object? language = null,
    Object? backend = freezed,
    Object? processingTime = freezed,
    Object? speakerCount = null,
    Object? hasSpeakerDiarization = null,
    Object? metadata = null,
    Object? timestamp = null,
  }) {
    return _then(
      _$TranscriptionResultImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        segments:
            null == segments
                ? _value._segments
                : segments // ignore: cast_nullable_to_non_nullable
                    as List<TranscriptionSegment>,
        overallConfidence:
            null == overallConfidence
                ? _value.overallConfidence
                : overallConfidence // ignore: cast_nullable_to_non_nullable
                    as double,
        totalDuration:
            null == totalDuration
                ? _value.totalDuration
                : totalDuration // ignore: cast_nullable_to_non_nullable
                    as Duration,
        language:
            null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                    as String,
        backend:
            freezed == backend
                ? _value.backend
                : backend // ignore: cast_nullable_to_non_nullable
                    as String?,
        processingTime:
            freezed == processingTime
                ? _value.processingTime
                : processingTime // ignore: cast_nullable_to_non_nullable
                    as Duration?,
        speakerCount:
            null == speakerCount
                ? _value.speakerCount
                : speakerCount // ignore: cast_nullable_to_non_nullable
                    as int,
        hasSpeakerDiarization:
            null == hasSpeakerDiarization
                ? _value.hasSpeakerDiarization
                : hasSpeakerDiarization // ignore: cast_nullable_to_non_nullable
                    as bool,
        metadata:
            null == metadata
                ? _value._metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                    as Map<String, dynamic>,
        timestamp:
            null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                    as DateTime,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$TranscriptionResultImpl extends _TranscriptionResult {
  const _$TranscriptionResultImpl({
    required this.id,
    required final List<TranscriptionSegment> segments,
    required this.overallConfidence,
    required this.totalDuration,
    this.language = 'en-US',
    this.backend,
    this.processingTime,
    this.speakerCount = 1,
    this.hasSpeakerDiarization = false,
    final Map<String, dynamic> metadata = const {},
    required this.timestamp,
  }) : _segments = segments,
       _metadata = metadata,
       super._();

  factory _$TranscriptionResultImpl.fromJson(Map<String, dynamic> json) =>
      _$$TranscriptionResultImplFromJson(json);

  /// Unique identifier for this transcription result
  @override
  final String id;

  /// List of transcription segments
  final List<TranscriptionSegment> _segments;

  /// List of transcription segments
  @override
  List<TranscriptionSegment> get segments {
    if (_segments is EqualUnmodifiableListView) return _segments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_segments);
  }

  /// Overall confidence score for the entire transcription
  @override
  final double overallConfidence;

  /// Total duration of the transcription
  @override
  final Duration totalDuration;

  /// Language code for the transcription
  @override
  @JsonKey()
  final String language;

  /// Transcription backend used
  @override
  final String? backend;

  /// Total processing time
  @override
  final Duration? processingTime;

  /// Number of speakers detected
  @override
  @JsonKey()
  final int speakerCount;

  /// Whether speaker diarization was performed
  @override
  @JsonKey()
  final bool hasSpeakerDiarization;

  /// Additional metadata for the entire transcription
  final Map<String, dynamic> _metadata;

  /// Additional metadata for the entire transcription
  @override
  @JsonKey()
  Map<String, dynamic> get metadata {
    if (_metadata is EqualUnmodifiableMapView) return _metadata;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_metadata);
  }

  /// Timestamp when this result was created
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'TranscriptionResult(id: $id, segments: $segments, overallConfidence: $overallConfidence, totalDuration: $totalDuration, language: $language, backend: $backend, processingTime: $processingTime, speakerCount: $speakerCount, hasSpeakerDiarization: $hasSpeakerDiarization, metadata: $metadata, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TranscriptionResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality().equals(other._segments, _segments) &&
            (identical(other.overallConfidence, overallConfidence) ||
                other.overallConfidence == overallConfidence) &&
            (identical(other.totalDuration, totalDuration) ||
                other.totalDuration == totalDuration) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.backend, backend) || other.backend == backend) &&
            (identical(other.processingTime, processingTime) ||
                other.processingTime == processingTime) &&
            (identical(other.speakerCount, speakerCount) ||
                other.speakerCount == speakerCount) &&
            (identical(other.hasSpeakerDiarization, hasSpeakerDiarization) ||
                other.hasSpeakerDiarization == hasSpeakerDiarization) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    const DeepCollectionEquality().hash(_segments),
    overallConfidence,
    totalDuration,
    language,
    backend,
    processingTime,
    speakerCount,
    hasSpeakerDiarization,
    const DeepCollectionEquality().hash(_metadata),
    timestamp,
  );

  /// Create a copy of TranscriptionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TranscriptionResultImplCopyWith<_$TranscriptionResultImpl> get copyWith =>
      __$$TranscriptionResultImplCopyWithImpl<_$TranscriptionResultImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$TranscriptionResultImplToJson(this);
  }
}

abstract class _TranscriptionResult extends TranscriptionResult {
  const factory _TranscriptionResult({
    required final String id,
    required final List<TranscriptionSegment> segments,
    required final double overallConfidence,
    required final Duration totalDuration,
    final String language,
    final String? backend,
    final Duration? processingTime,
    final int speakerCount,
    final bool hasSpeakerDiarization,
    final Map<String, dynamic> metadata,
    required final DateTime timestamp,
  }) = _$TranscriptionResultImpl;
  const _TranscriptionResult._() : super._();

  factory _TranscriptionResult.fromJson(Map<String, dynamic> json) =
      _$TranscriptionResultImpl.fromJson;

  /// Unique identifier for this transcription result
  @override
  String get id;

  /// List of transcription segments
  @override
  List<TranscriptionSegment> get segments;

  /// Overall confidence score for the entire transcription
  @override
  double get overallConfidence;

  /// Total duration of the transcription
  @override
  Duration get totalDuration;

  /// Language code for the transcription
  @override
  String get language;

  /// Transcription backend used
  @override
  String? get backend;

  /// Total processing time
  @override
  Duration? get processingTime;

  /// Number of speakers detected
  @override
  int get speakerCount;

  /// Whether speaker diarization was performed
  @override
  bool get hasSpeakerDiarization;

  /// Additional metadata for the entire transcription
  @override
  Map<String, dynamic> get metadata;

  /// Timestamp when this result was created
  @override
  DateTime get timestamp;

  /// Create a copy of TranscriptionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TranscriptionResultImplCopyWith<_$TranscriptionResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
