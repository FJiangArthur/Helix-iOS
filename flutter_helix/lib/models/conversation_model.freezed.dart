// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ConversationParticipant _$ConversationParticipantFromJson(
  Map<String, dynamic> json,
) {
  return _ConversationParticipant.fromJson(json);
}

/// @nodoc
mixin _$ConversationParticipant {
  /// Unique identifier for the participant
  String get id => throw _privateConstructorUsedError;

  /// Display name of the participant
  String get name => throw _privateConstructorUsedError;

  /// Color code for UI display
  String get color => throw _privateConstructorUsedError;

  /// Avatar URL or initials
  String? get avatar => throw _privateConstructorUsedError;

  /// Whether this is the device owner
  bool get isOwner => throw _privateConstructorUsedError;

  /// Total speaking time in this conversation
  Duration get totalSpeakingTime => throw _privateConstructorUsedError;

  /// Number of segments spoken
  int get segmentCount => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Serializes this ConversationParticipant to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConversationParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationParticipantCopyWith<ConversationParticipant> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationParticipantCopyWith<$Res> {
  factory $ConversationParticipantCopyWith(
    ConversationParticipant value,
    $Res Function(ConversationParticipant) then,
  ) = _$ConversationParticipantCopyWithImpl<$Res, ConversationParticipant>;
  @useResult
  $Res call({
    String id,
    String name,
    String color,
    String? avatar,
    bool isOwner,
    Duration totalSpeakingTime,
    int segmentCount,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$ConversationParticipantCopyWithImpl<
  $Res,
  $Val extends ConversationParticipant
>
    implements $ConversationParticipantCopyWith<$Res> {
  _$ConversationParticipantCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? color = null,
    Object? avatar = freezed,
    Object? isOwner = null,
    Object? totalSpeakingTime = null,
    Object? segmentCount = null,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            name:
                null == name
                    ? _value.name
                    : name // ignore: cast_nullable_to_non_nullable
                        as String,
            color:
                null == color
                    ? _value.color
                    : color // ignore: cast_nullable_to_non_nullable
                        as String,
            avatar:
                freezed == avatar
                    ? _value.avatar
                    : avatar // ignore: cast_nullable_to_non_nullable
                        as String?,
            isOwner:
                null == isOwner
                    ? _value.isOwner
                    : isOwner // ignore: cast_nullable_to_non_nullable
                        as bool,
            totalSpeakingTime:
                null == totalSpeakingTime
                    ? _value.totalSpeakingTime
                    : totalSpeakingTime // ignore: cast_nullable_to_non_nullable
                        as Duration,
            segmentCount:
                null == segmentCount
                    ? _value.segmentCount
                    : segmentCount // ignore: cast_nullable_to_non_nullable
                        as int,
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
abstract class _$$ConversationParticipantImplCopyWith<$Res>
    implements $ConversationParticipantCopyWith<$Res> {
  factory _$$ConversationParticipantImplCopyWith(
    _$ConversationParticipantImpl value,
    $Res Function(_$ConversationParticipantImpl) then,
  ) = __$$ConversationParticipantImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String color,
    String? avatar,
    bool isOwner,
    Duration totalSpeakingTime,
    int segmentCount,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$ConversationParticipantImplCopyWithImpl<$Res>
    extends
        _$ConversationParticipantCopyWithImpl<
          $Res,
          _$ConversationParticipantImpl
        >
    implements _$$ConversationParticipantImplCopyWith<$Res> {
  __$$ConversationParticipantImplCopyWithImpl(
    _$ConversationParticipantImpl _value,
    $Res Function(_$ConversationParticipantImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationParticipant
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? color = null,
    Object? avatar = freezed,
    Object? isOwner = null,
    Object? totalSpeakingTime = null,
    Object? segmentCount = null,
    Object? metadata = null,
  }) {
    return _then(
      _$ConversationParticipantImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        name:
            null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                    as String,
        color:
            null == color
                ? _value.color
                : color // ignore: cast_nullable_to_non_nullable
                    as String,
        avatar:
            freezed == avatar
                ? _value.avatar
                : avatar // ignore: cast_nullable_to_non_nullable
                    as String?,
        isOwner:
            null == isOwner
                ? _value.isOwner
                : isOwner // ignore: cast_nullable_to_non_nullable
                    as bool,
        totalSpeakingTime:
            null == totalSpeakingTime
                ? _value.totalSpeakingTime
                : totalSpeakingTime // ignore: cast_nullable_to_non_nullable
                    as Duration,
        segmentCount:
            null == segmentCount
                ? _value.segmentCount
                : segmentCount // ignore: cast_nullable_to_non_nullable
                    as int,
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
class _$ConversationParticipantImpl extends _ConversationParticipant {
  const _$ConversationParticipantImpl({
    required this.id,
    required this.name,
    this.color = '#007AFF',
    this.avatar,
    this.isOwner = false,
    this.totalSpeakingTime = Duration.zero,
    this.segmentCount = 0,
    final Map<String, dynamic> metadata = const {},
  }) : _metadata = metadata,
       super._();

  factory _$ConversationParticipantImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversationParticipantImplFromJson(json);

  /// Unique identifier for the participant
  @override
  final String id;

  /// Display name of the participant
  @override
  final String name;

  /// Color code for UI display
  @override
  @JsonKey()
  final String color;

  /// Avatar URL or initials
  @override
  final String? avatar;

  /// Whether this is the device owner
  @override
  @JsonKey()
  final bool isOwner;

  /// Total speaking time in this conversation
  @override
  @JsonKey()
  final Duration totalSpeakingTime;

  /// Number of segments spoken
  @override
  @JsonKey()
  final int segmentCount;

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
    return 'ConversationParticipant(id: $id, name: $name, color: $color, avatar: $avatar, isOwner: $isOwner, totalSpeakingTime: $totalSpeakingTime, segmentCount: $segmentCount, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationParticipantImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.color, color) || other.color == color) &&
            (identical(other.avatar, avatar) || other.avatar == avatar) &&
            (identical(other.isOwner, isOwner) || other.isOwner == isOwner) &&
            (identical(other.totalSpeakingTime, totalSpeakingTime) ||
                other.totalSpeakingTime == totalSpeakingTime) &&
            (identical(other.segmentCount, segmentCount) ||
                other.segmentCount == segmentCount) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    color,
    avatar,
    isOwner,
    totalSpeakingTime,
    segmentCount,
    const DeepCollectionEquality().hash(_metadata),
  );

  /// Create a copy of ConversationParticipant
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationParticipantImplCopyWith<_$ConversationParticipantImpl>
  get copyWith => __$$ConversationParticipantImplCopyWithImpl<
    _$ConversationParticipantImpl
  >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversationParticipantImplToJson(this);
  }
}

abstract class _ConversationParticipant extends ConversationParticipant {
  const factory _ConversationParticipant({
    required final String id,
    required final String name,
    final String color,
    final String? avatar,
    final bool isOwner,
    final Duration totalSpeakingTime,
    final int segmentCount,
    final Map<String, dynamic> metadata,
  }) = _$ConversationParticipantImpl;
  const _ConversationParticipant._() : super._();

  factory _ConversationParticipant.fromJson(Map<String, dynamic> json) =
      _$ConversationParticipantImpl.fromJson;

  /// Unique identifier for the participant
  @override
  String get id;

  /// Display name of the participant
  @override
  String get name;

  /// Color code for UI display
  @override
  String get color;

  /// Avatar URL or initials
  @override
  String? get avatar;

  /// Whether this is the device owner
  @override
  bool get isOwner;

  /// Total speaking time in this conversation
  @override
  Duration get totalSpeakingTime;

  /// Number of segments spoken
  @override
  int get segmentCount;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of ConversationParticipant
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationParticipantImplCopyWith<_$ConversationParticipantImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ConversationModel _$ConversationModelFromJson(Map<String, dynamic> json) {
  return _ConversationModel.fromJson(json);
}

/// @nodoc
mixin _$ConversationModel {
  /// Unique identifier for the conversation
  String get id => throw _privateConstructorUsedError;

  /// Human-readable title
  String get title => throw _privateConstructorUsedError;

  /// Conversation description or notes
  String? get description => throw _privateConstructorUsedError;

  /// Current status
  ConversationStatus get status => throw _privateConstructorUsedError;

  /// Priority level
  ConversationPriority get priority => throw _privateConstructorUsedError;

  /// List of participants
  List<ConversationParticipant> get participants =>
      throw _privateConstructorUsedError;

  /// Transcription segments
  List<TranscriptionSegment> get segments => throw _privateConstructorUsedError;

  /// When the conversation started
  DateTime get startTime => throw _privateConstructorUsedError;

  /// When the conversation ended (if completed)
  DateTime? get endTime => throw _privateConstructorUsedError;

  /// Last time the conversation was updated
  DateTime get lastUpdated => throw _privateConstructorUsedError;

  /// Location where conversation took place
  String? get location => throw _privateConstructorUsedError;

  /// Tags for categorization
  List<String> get tags => throw _privateConstructorUsedError;

  /// Language of the conversation
  String get language => throw _privateConstructorUsedError;

  /// Whether the conversation has been analyzed by AI
  bool get hasAIAnalysis => throw _privateConstructorUsedError;

  /// Whether the conversation is pinned
  bool get isPinned => throw _privateConstructorUsedError;

  /// Whether the conversation is private
  bool get isPrivate => throw _privateConstructorUsedError;

  /// Audio quality score (0.0 to 1.0)
  double? get audioQuality => throw _privateConstructorUsedError;

  /// Transcription confidence score (0.0 to 1.0)
  double? get transcriptionConfidence => throw _privateConstructorUsedError;

  /// Additional metadata
  Map<String, dynamic> get metadata => throw _privateConstructorUsedError;

  /// Serializes this ConversationModel to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationModelCopyWith<ConversationModel> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationModelCopyWith<$Res> {
  factory $ConversationModelCopyWith(
    ConversationModel value,
    $Res Function(ConversationModel) then,
  ) = _$ConversationModelCopyWithImpl<$Res, ConversationModel>;
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    ConversationStatus status,
    ConversationPriority priority,
    List<ConversationParticipant> participants,
    List<TranscriptionSegment> segments,
    DateTime startTime,
    DateTime? endTime,
    DateTime lastUpdated,
    String? location,
    List<String> tags,
    String language,
    bool hasAIAnalysis,
    bool isPinned,
    bool isPrivate,
    double? audioQuality,
    double? transcriptionConfidence,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class _$ConversationModelCopyWithImpl<$Res, $Val extends ConversationModel>
    implements $ConversationModelCopyWith<$Res> {
  _$ConversationModelCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? status = null,
    Object? priority = null,
    Object? participants = null,
    Object? segments = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? lastUpdated = null,
    Object? location = freezed,
    Object? tags = null,
    Object? language = null,
    Object? hasAIAnalysis = null,
    Object? isPinned = null,
    Object? isPrivate = null,
    Object? audioQuality = freezed,
    Object? transcriptionConfidence = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _value.copyWith(
            id:
                null == id
                    ? _value.id
                    : id // ignore: cast_nullable_to_non_nullable
                        as String,
            title:
                null == title
                    ? _value.title
                    : title // ignore: cast_nullable_to_non_nullable
                        as String,
            description:
                freezed == description
                    ? _value.description
                    : description // ignore: cast_nullable_to_non_nullable
                        as String?,
            status:
                null == status
                    ? _value.status
                    : status // ignore: cast_nullable_to_non_nullable
                        as ConversationStatus,
            priority:
                null == priority
                    ? _value.priority
                    : priority // ignore: cast_nullable_to_non_nullable
                        as ConversationPriority,
            participants:
                null == participants
                    ? _value.participants
                    : participants // ignore: cast_nullable_to_non_nullable
                        as List<ConversationParticipant>,
            segments:
                null == segments
                    ? _value.segments
                    : segments // ignore: cast_nullable_to_non_nullable
                        as List<TranscriptionSegment>,
            startTime:
                null == startTime
                    ? _value.startTime
                    : startTime // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            endTime:
                freezed == endTime
                    ? _value.endTime
                    : endTime // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            lastUpdated:
                null == lastUpdated
                    ? _value.lastUpdated
                    : lastUpdated // ignore: cast_nullable_to_non_nullable
                        as DateTime,
            location:
                freezed == location
                    ? _value.location
                    : location // ignore: cast_nullable_to_non_nullable
                        as String?,
            tags:
                null == tags
                    ? _value.tags
                    : tags // ignore: cast_nullable_to_non_nullable
                        as List<String>,
            language:
                null == language
                    ? _value.language
                    : language // ignore: cast_nullable_to_non_nullable
                        as String,
            hasAIAnalysis:
                null == hasAIAnalysis
                    ? _value.hasAIAnalysis
                    : hasAIAnalysis // ignore: cast_nullable_to_non_nullable
                        as bool,
            isPinned:
                null == isPinned
                    ? _value.isPinned
                    : isPinned // ignore: cast_nullable_to_non_nullable
                        as bool,
            isPrivate:
                null == isPrivate
                    ? _value.isPrivate
                    : isPrivate // ignore: cast_nullable_to_non_nullable
                        as bool,
            audioQuality:
                freezed == audioQuality
                    ? _value.audioQuality
                    : audioQuality // ignore: cast_nullable_to_non_nullable
                        as double?,
            transcriptionConfidence:
                freezed == transcriptionConfidence
                    ? _value.transcriptionConfidence
                    : transcriptionConfidence // ignore: cast_nullable_to_non_nullable
                        as double?,
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
abstract class _$$ConversationModelImplCopyWith<$Res>
    implements $ConversationModelCopyWith<$Res> {
  factory _$$ConversationModelImplCopyWith(
    _$ConversationModelImpl value,
    $Res Function(_$ConversationModelImpl) then,
  ) = __$$ConversationModelImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String title,
    String? description,
    ConversationStatus status,
    ConversationPriority priority,
    List<ConversationParticipant> participants,
    List<TranscriptionSegment> segments,
    DateTime startTime,
    DateTime? endTime,
    DateTime lastUpdated,
    String? location,
    List<String> tags,
    String language,
    bool hasAIAnalysis,
    bool isPinned,
    bool isPrivate,
    double? audioQuality,
    double? transcriptionConfidence,
    Map<String, dynamic> metadata,
  });
}

/// @nodoc
class __$$ConversationModelImplCopyWithImpl<$Res>
    extends _$ConversationModelCopyWithImpl<$Res, _$ConversationModelImpl>
    implements _$$ConversationModelImplCopyWith<$Res> {
  __$$ConversationModelImplCopyWithImpl(
    _$ConversationModelImpl _value,
    $Res Function(_$ConversationModelImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? description = freezed,
    Object? status = null,
    Object? priority = null,
    Object? participants = null,
    Object? segments = null,
    Object? startTime = null,
    Object? endTime = freezed,
    Object? lastUpdated = null,
    Object? location = freezed,
    Object? tags = null,
    Object? language = null,
    Object? hasAIAnalysis = null,
    Object? isPinned = null,
    Object? isPrivate = null,
    Object? audioQuality = freezed,
    Object? transcriptionConfidence = freezed,
    Object? metadata = null,
  }) {
    return _then(
      _$ConversationModelImpl(
        id:
            null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                    as String,
        title:
            null == title
                ? _value.title
                : title // ignore: cast_nullable_to_non_nullable
                    as String,
        description:
            freezed == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                    as String?,
        status:
            null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                    as ConversationStatus,
        priority:
            null == priority
                ? _value.priority
                : priority // ignore: cast_nullable_to_non_nullable
                    as ConversationPriority,
        participants:
            null == participants
                ? _value._participants
                : participants // ignore: cast_nullable_to_non_nullable
                    as List<ConversationParticipant>,
        segments:
            null == segments
                ? _value._segments
                : segments // ignore: cast_nullable_to_non_nullable
                    as List<TranscriptionSegment>,
        startTime:
            null == startTime
                ? _value.startTime
                : startTime // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        endTime:
            freezed == endTime
                ? _value.endTime
                : endTime // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        lastUpdated:
            null == lastUpdated
                ? _value.lastUpdated
                : lastUpdated // ignore: cast_nullable_to_non_nullable
                    as DateTime,
        location:
            freezed == location
                ? _value.location
                : location // ignore: cast_nullable_to_non_nullable
                    as String?,
        tags:
            null == tags
                ? _value._tags
                : tags // ignore: cast_nullable_to_non_nullable
                    as List<String>,
        language:
            null == language
                ? _value.language
                : language // ignore: cast_nullable_to_non_nullable
                    as String,
        hasAIAnalysis:
            null == hasAIAnalysis
                ? _value.hasAIAnalysis
                : hasAIAnalysis // ignore: cast_nullable_to_non_nullable
                    as bool,
        isPinned:
            null == isPinned
                ? _value.isPinned
                : isPinned // ignore: cast_nullable_to_non_nullable
                    as bool,
        isPrivate:
            null == isPrivate
                ? _value.isPrivate
                : isPrivate // ignore: cast_nullable_to_non_nullable
                    as bool,
        audioQuality:
            freezed == audioQuality
                ? _value.audioQuality
                : audioQuality // ignore: cast_nullable_to_non_nullable
                    as double?,
        transcriptionConfidence:
            freezed == transcriptionConfidence
                ? _value.transcriptionConfidence
                : transcriptionConfidence // ignore: cast_nullable_to_non_nullable
                    as double?,
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
class _$ConversationModelImpl extends _ConversationModel {
  const _$ConversationModelImpl({
    required this.id,
    required this.title,
    this.description,
    this.status = ConversationStatus.active,
    this.priority = ConversationPriority.normal,
    required final List<ConversationParticipant> participants,
    required final List<TranscriptionSegment> segments,
    required this.startTime,
    this.endTime,
    required this.lastUpdated,
    this.location,
    final List<String> tags = const [],
    this.language = 'en-US',
    this.hasAIAnalysis = false,
    this.isPinned = false,
    this.isPrivate = false,
    this.audioQuality,
    this.transcriptionConfidence,
    final Map<String, dynamic> metadata = const {},
  }) : _participants = participants,
       _segments = segments,
       _tags = tags,
       _metadata = metadata,
       super._();

  factory _$ConversationModelImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversationModelImplFromJson(json);

  /// Unique identifier for the conversation
  @override
  final String id;

  /// Human-readable title
  @override
  final String title;

  /// Conversation description or notes
  @override
  final String? description;

  /// Current status
  @override
  @JsonKey()
  final ConversationStatus status;

  /// Priority level
  @override
  @JsonKey()
  final ConversationPriority priority;

  /// List of participants
  final List<ConversationParticipant> _participants;

  /// List of participants
  @override
  List<ConversationParticipant> get participants {
    if (_participants is EqualUnmodifiableListView) return _participants;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_participants);
  }

  /// Transcription segments
  final List<TranscriptionSegment> _segments;

  /// Transcription segments
  @override
  List<TranscriptionSegment> get segments {
    if (_segments is EqualUnmodifiableListView) return _segments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_segments);
  }

  /// When the conversation started
  @override
  final DateTime startTime;

  /// When the conversation ended (if completed)
  @override
  final DateTime? endTime;

  /// Last time the conversation was updated
  @override
  final DateTime lastUpdated;

  /// Location where conversation took place
  @override
  final String? location;

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

  /// Language of the conversation
  @override
  @JsonKey()
  final String language;

  /// Whether the conversation has been analyzed by AI
  @override
  @JsonKey()
  final bool hasAIAnalysis;

  /// Whether the conversation is pinned
  @override
  @JsonKey()
  final bool isPinned;

  /// Whether the conversation is private
  @override
  @JsonKey()
  final bool isPrivate;

  /// Audio quality score (0.0 to 1.0)
  @override
  final double? audioQuality;

  /// Transcription confidence score (0.0 to 1.0)
  @override
  final double? transcriptionConfidence;

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
    return 'ConversationModel(id: $id, title: $title, description: $description, status: $status, priority: $priority, participants: $participants, segments: $segments, startTime: $startTime, endTime: $endTime, lastUpdated: $lastUpdated, location: $location, tags: $tags, language: $language, hasAIAnalysis: $hasAIAnalysis, isPinned: $isPinned, isPrivate: $isPrivate, audioQuality: $audioQuality, transcriptionConfidence: $transcriptionConfidence, metadata: $metadata)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationModelImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            const DeepCollectionEquality().equals(
              other._participants,
              _participants,
            ) &&
            const DeepCollectionEquality().equals(other._segments, _segments) &&
            (identical(other.startTime, startTime) ||
                other.startTime == startTime) &&
            (identical(other.endTime, endTime) || other.endTime == endTime) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated) &&
            (identical(other.location, location) ||
                other.location == location) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.hasAIAnalysis, hasAIAnalysis) ||
                other.hasAIAnalysis == hasAIAnalysis) &&
            (identical(other.isPinned, isPinned) ||
                other.isPinned == isPinned) &&
            (identical(other.isPrivate, isPrivate) ||
                other.isPrivate == isPrivate) &&
            (identical(other.audioQuality, audioQuality) ||
                other.audioQuality == audioQuality) &&
            (identical(
                  other.transcriptionConfidence,
                  transcriptionConfidence,
                ) ||
                other.transcriptionConfidence == transcriptionConfidence) &&
            const DeepCollectionEquality().equals(other._metadata, _metadata));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
    runtimeType,
    id,
    title,
    description,
    status,
    priority,
    const DeepCollectionEquality().hash(_participants),
    const DeepCollectionEquality().hash(_segments),
    startTime,
    endTime,
    lastUpdated,
    location,
    const DeepCollectionEquality().hash(_tags),
    language,
    hasAIAnalysis,
    isPinned,
    isPrivate,
    audioQuality,
    transcriptionConfidence,
    const DeepCollectionEquality().hash(_metadata),
  ]);

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationModelImplCopyWith<_$ConversationModelImpl> get copyWith =>
      __$$ConversationModelImplCopyWithImpl<_$ConversationModelImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversationModelImplToJson(this);
  }
}

abstract class _ConversationModel extends ConversationModel {
  const factory _ConversationModel({
    required final String id,
    required final String title,
    final String? description,
    final ConversationStatus status,
    final ConversationPriority priority,
    required final List<ConversationParticipant> participants,
    required final List<TranscriptionSegment> segments,
    required final DateTime startTime,
    final DateTime? endTime,
    required final DateTime lastUpdated,
    final String? location,
    final List<String> tags,
    final String language,
    final bool hasAIAnalysis,
    final bool isPinned,
    final bool isPrivate,
    final double? audioQuality,
    final double? transcriptionConfidence,
    final Map<String, dynamic> metadata,
  }) = _$ConversationModelImpl;
  const _ConversationModel._() : super._();

  factory _ConversationModel.fromJson(Map<String, dynamic> json) =
      _$ConversationModelImpl.fromJson;

  /// Unique identifier for the conversation
  @override
  String get id;

  /// Human-readable title
  @override
  String get title;

  /// Conversation description or notes
  @override
  String? get description;

  /// Current status
  @override
  ConversationStatus get status;

  /// Priority level
  @override
  ConversationPriority get priority;

  /// List of participants
  @override
  List<ConversationParticipant> get participants;

  /// Transcription segments
  @override
  List<TranscriptionSegment> get segments;

  /// When the conversation started
  @override
  DateTime get startTime;

  /// When the conversation ended (if completed)
  @override
  DateTime? get endTime;

  /// Last time the conversation was updated
  @override
  DateTime get lastUpdated;

  /// Location where conversation took place
  @override
  String? get location;

  /// Tags for categorization
  @override
  List<String> get tags;

  /// Language of the conversation
  @override
  String get language;

  /// Whether the conversation has been analyzed by AI
  @override
  bool get hasAIAnalysis;

  /// Whether the conversation is pinned
  @override
  bool get isPinned;

  /// Whether the conversation is private
  @override
  bool get isPrivate;

  /// Audio quality score (0.0 to 1.0)
  @override
  double? get audioQuality;

  /// Transcription confidence score (0.0 to 1.0)
  @override
  double? get transcriptionConfidence;

  /// Additional metadata
  @override
  Map<String, dynamic> get metadata;

  /// Create a copy of ConversationModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationModelImplCopyWith<_$ConversationModelImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ConversationFilter _$ConversationFilterFromJson(Map<String, dynamic> json) {
  return _ConversationFilter.fromJson(json);
}

/// @nodoc
mixin _$ConversationFilter {
  /// Search query for title/content
  String? get query => throw _privateConstructorUsedError;

  /// Filter by status
  List<ConversationStatus>? get statuses => throw _privateConstructorUsedError;

  /// Filter by priority
  List<ConversationPriority>? get priorities =>
      throw _privateConstructorUsedError;

  /// Filter by tags
  List<String>? get tags => throw _privateConstructorUsedError;

  /// Filter by participants
  List<String>? get participantIds => throw _privateConstructorUsedError;

  /// Date range filter
  DateTime? get startDate => throw _privateConstructorUsedError;
  DateTime? get endDate => throw _privateConstructorUsedError;

  /// Minimum duration filter
  Duration? get minDuration => throw _privateConstructorUsedError;

  /// Maximum duration filter
  Duration? get maxDuration => throw _privateConstructorUsedError;

  /// Filter by AI analysis availability
  bool? get hasAIAnalysis => throw _privateConstructorUsedError;

  /// Filter by privacy setting
  bool? get isPrivate => throw _privateConstructorUsedError;

  /// Minimum confidence threshold
  double? get minConfidence => throw _privateConstructorUsedError;

  /// Serializes this ConversationFilter to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ConversationFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ConversationFilterCopyWith<ConversationFilter> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ConversationFilterCopyWith<$Res> {
  factory $ConversationFilterCopyWith(
    ConversationFilter value,
    $Res Function(ConversationFilter) then,
  ) = _$ConversationFilterCopyWithImpl<$Res, ConversationFilter>;
  @useResult
  $Res call({
    String? query,
    List<ConversationStatus>? statuses,
    List<ConversationPriority>? priorities,
    List<String>? tags,
    List<String>? participantIds,
    DateTime? startDate,
    DateTime? endDate,
    Duration? minDuration,
    Duration? maxDuration,
    bool? hasAIAnalysis,
    bool? isPrivate,
    double? minConfidence,
  });
}

/// @nodoc
class _$ConversationFilterCopyWithImpl<$Res, $Val extends ConversationFilter>
    implements $ConversationFilterCopyWith<$Res> {
  _$ConversationFilterCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ConversationFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = freezed,
    Object? statuses = freezed,
    Object? priorities = freezed,
    Object? tags = freezed,
    Object? participantIds = freezed,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? minDuration = freezed,
    Object? maxDuration = freezed,
    Object? hasAIAnalysis = freezed,
    Object? isPrivate = freezed,
    Object? minConfidence = freezed,
  }) {
    return _then(
      _value.copyWith(
            query:
                freezed == query
                    ? _value.query
                    : query // ignore: cast_nullable_to_non_nullable
                        as String?,
            statuses:
                freezed == statuses
                    ? _value.statuses
                    : statuses // ignore: cast_nullable_to_non_nullable
                        as List<ConversationStatus>?,
            priorities:
                freezed == priorities
                    ? _value.priorities
                    : priorities // ignore: cast_nullable_to_non_nullable
                        as List<ConversationPriority>?,
            tags:
                freezed == tags
                    ? _value.tags
                    : tags // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            participantIds:
                freezed == participantIds
                    ? _value.participantIds
                    : participantIds // ignore: cast_nullable_to_non_nullable
                        as List<String>?,
            startDate:
                freezed == startDate
                    ? _value.startDate
                    : startDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            endDate:
                freezed == endDate
                    ? _value.endDate
                    : endDate // ignore: cast_nullable_to_non_nullable
                        as DateTime?,
            minDuration:
                freezed == minDuration
                    ? _value.minDuration
                    : minDuration // ignore: cast_nullable_to_non_nullable
                        as Duration?,
            maxDuration:
                freezed == maxDuration
                    ? _value.maxDuration
                    : maxDuration // ignore: cast_nullable_to_non_nullable
                        as Duration?,
            hasAIAnalysis:
                freezed == hasAIAnalysis
                    ? _value.hasAIAnalysis
                    : hasAIAnalysis // ignore: cast_nullable_to_non_nullable
                        as bool?,
            isPrivate:
                freezed == isPrivate
                    ? _value.isPrivate
                    : isPrivate // ignore: cast_nullable_to_non_nullable
                        as bool?,
            minConfidence:
                freezed == minConfidence
                    ? _value.minConfidence
                    : minConfidence // ignore: cast_nullable_to_non_nullable
                        as double?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ConversationFilterImplCopyWith<$Res>
    implements $ConversationFilterCopyWith<$Res> {
  factory _$$ConversationFilterImplCopyWith(
    _$ConversationFilterImpl value,
    $Res Function(_$ConversationFilterImpl) then,
  ) = __$$ConversationFilterImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String? query,
    List<ConversationStatus>? statuses,
    List<ConversationPriority>? priorities,
    List<String>? tags,
    List<String>? participantIds,
    DateTime? startDate,
    DateTime? endDate,
    Duration? minDuration,
    Duration? maxDuration,
    bool? hasAIAnalysis,
    bool? isPrivate,
    double? minConfidence,
  });
}

/// @nodoc
class __$$ConversationFilterImplCopyWithImpl<$Res>
    extends _$ConversationFilterCopyWithImpl<$Res, _$ConversationFilterImpl>
    implements _$$ConversationFilterImplCopyWith<$Res> {
  __$$ConversationFilterImplCopyWithImpl(
    _$ConversationFilterImpl _value,
    $Res Function(_$ConversationFilterImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ConversationFilter
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? query = freezed,
    Object? statuses = freezed,
    Object? priorities = freezed,
    Object? tags = freezed,
    Object? participantIds = freezed,
    Object? startDate = freezed,
    Object? endDate = freezed,
    Object? minDuration = freezed,
    Object? maxDuration = freezed,
    Object? hasAIAnalysis = freezed,
    Object? isPrivate = freezed,
    Object? minConfidence = freezed,
  }) {
    return _then(
      _$ConversationFilterImpl(
        query:
            freezed == query
                ? _value.query
                : query // ignore: cast_nullable_to_non_nullable
                    as String?,
        statuses:
            freezed == statuses
                ? _value._statuses
                : statuses // ignore: cast_nullable_to_non_nullable
                    as List<ConversationStatus>?,
        priorities:
            freezed == priorities
                ? _value._priorities
                : priorities // ignore: cast_nullable_to_non_nullable
                    as List<ConversationPriority>?,
        tags:
            freezed == tags
                ? _value._tags
                : tags // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        participantIds:
            freezed == participantIds
                ? _value._participantIds
                : participantIds // ignore: cast_nullable_to_non_nullable
                    as List<String>?,
        startDate:
            freezed == startDate
                ? _value.startDate
                : startDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        endDate:
            freezed == endDate
                ? _value.endDate
                : endDate // ignore: cast_nullable_to_non_nullable
                    as DateTime?,
        minDuration:
            freezed == minDuration
                ? _value.minDuration
                : minDuration // ignore: cast_nullable_to_non_nullable
                    as Duration?,
        maxDuration:
            freezed == maxDuration
                ? _value.maxDuration
                : maxDuration // ignore: cast_nullable_to_non_nullable
                    as Duration?,
        hasAIAnalysis:
            freezed == hasAIAnalysis
                ? _value.hasAIAnalysis
                : hasAIAnalysis // ignore: cast_nullable_to_non_nullable
                    as bool?,
        isPrivate:
            freezed == isPrivate
                ? _value.isPrivate
                : isPrivate // ignore: cast_nullable_to_non_nullable
                    as bool?,
        minConfidence:
            freezed == minConfidence
                ? _value.minConfidence
                : minConfidence // ignore: cast_nullable_to_non_nullable
                    as double?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ConversationFilterImpl implements _ConversationFilter {
  const _$ConversationFilterImpl({
    this.query,
    final List<ConversationStatus>? statuses,
    final List<ConversationPriority>? priorities,
    final List<String>? tags,
    final List<String>? participantIds,
    this.startDate,
    this.endDate,
    this.minDuration,
    this.maxDuration,
    this.hasAIAnalysis,
    this.isPrivate,
    this.minConfidence,
  }) : _statuses = statuses,
       _priorities = priorities,
       _tags = tags,
       _participantIds = participantIds;

  factory _$ConversationFilterImpl.fromJson(Map<String, dynamic> json) =>
      _$$ConversationFilterImplFromJson(json);

  /// Search query for title/content
  @override
  final String? query;

  /// Filter by status
  final List<ConversationStatus>? _statuses;

  /// Filter by status
  @override
  List<ConversationStatus>? get statuses {
    final value = _statuses;
    if (value == null) return null;
    if (_statuses is EqualUnmodifiableListView) return _statuses;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Filter by priority
  final List<ConversationPriority>? _priorities;

  /// Filter by priority
  @override
  List<ConversationPriority>? get priorities {
    final value = _priorities;
    if (value == null) return null;
    if (_priorities is EqualUnmodifiableListView) return _priorities;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Filter by tags
  final List<String>? _tags;

  /// Filter by tags
  @override
  List<String>? get tags {
    final value = _tags;
    if (value == null) return null;
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Filter by participants
  final List<String>? _participantIds;

  /// Filter by participants
  @override
  List<String>? get participantIds {
    final value = _participantIds;
    if (value == null) return null;
    if (_participantIds is EqualUnmodifiableListView) return _participantIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Date range filter
  @override
  final DateTime? startDate;
  @override
  final DateTime? endDate;

  /// Minimum duration filter
  @override
  final Duration? minDuration;

  /// Maximum duration filter
  @override
  final Duration? maxDuration;

  /// Filter by AI analysis availability
  @override
  final bool? hasAIAnalysis;

  /// Filter by privacy setting
  @override
  final bool? isPrivate;

  /// Minimum confidence threshold
  @override
  final double? minConfidence;

  @override
  String toString() {
    return 'ConversationFilter(query: $query, statuses: $statuses, priorities: $priorities, tags: $tags, participantIds: $participantIds, startDate: $startDate, endDate: $endDate, minDuration: $minDuration, maxDuration: $maxDuration, hasAIAnalysis: $hasAIAnalysis, isPrivate: $isPrivate, minConfidence: $minConfidence)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ConversationFilterImpl &&
            (identical(other.query, query) || other.query == query) &&
            const DeepCollectionEquality().equals(other._statuses, _statuses) &&
            const DeepCollectionEquality().equals(
              other._priorities,
              _priorities,
            ) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            const DeepCollectionEquality().equals(
              other._participantIds,
              _participantIds,
            ) &&
            (identical(other.startDate, startDate) ||
                other.startDate == startDate) &&
            (identical(other.endDate, endDate) || other.endDate == endDate) &&
            (identical(other.minDuration, minDuration) ||
                other.minDuration == minDuration) &&
            (identical(other.maxDuration, maxDuration) ||
                other.maxDuration == maxDuration) &&
            (identical(other.hasAIAnalysis, hasAIAnalysis) ||
                other.hasAIAnalysis == hasAIAnalysis) &&
            (identical(other.isPrivate, isPrivate) ||
                other.isPrivate == isPrivate) &&
            (identical(other.minConfidence, minConfidence) ||
                other.minConfidence == minConfidence));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    query,
    const DeepCollectionEquality().hash(_statuses),
    const DeepCollectionEquality().hash(_priorities),
    const DeepCollectionEquality().hash(_tags),
    const DeepCollectionEquality().hash(_participantIds),
    startDate,
    endDate,
    minDuration,
    maxDuration,
    hasAIAnalysis,
    isPrivate,
    minConfidence,
  );

  /// Create a copy of ConversationFilter
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ConversationFilterImplCopyWith<_$ConversationFilterImpl> get copyWith =>
      __$$ConversationFilterImplCopyWithImpl<_$ConversationFilterImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ConversationFilterImplToJson(this);
  }
}

abstract class _ConversationFilter implements ConversationFilter {
  const factory _ConversationFilter({
    final String? query,
    final List<ConversationStatus>? statuses,
    final List<ConversationPriority>? priorities,
    final List<String>? tags,
    final List<String>? participantIds,
    final DateTime? startDate,
    final DateTime? endDate,
    final Duration? minDuration,
    final Duration? maxDuration,
    final bool? hasAIAnalysis,
    final bool? isPrivate,
    final double? minConfidence,
  }) = _$ConversationFilterImpl;

  factory _ConversationFilter.fromJson(Map<String, dynamic> json) =
      _$ConversationFilterImpl.fromJson;

  /// Search query for title/content
  @override
  String? get query;

  /// Filter by status
  @override
  List<ConversationStatus>? get statuses;

  /// Filter by priority
  @override
  List<ConversationPriority>? get priorities;

  /// Filter by tags
  @override
  List<String>? get tags;

  /// Filter by participants
  @override
  List<String>? get participantIds;

  /// Date range filter
  @override
  DateTime? get startDate;
  @override
  DateTime? get endDate;

  /// Minimum duration filter
  @override
  Duration? get minDuration;

  /// Maximum duration filter
  @override
  Duration? get maxDuration;

  /// Filter by AI analysis availability
  @override
  bool? get hasAIAnalysis;

  /// Filter by privacy setting
  @override
  bool? get isPrivate;

  /// Minimum confidence threshold
  @override
  double? get minConfidence;

  /// Create a copy of ConversationFilter
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ConversationFilterImplCopyWith<_$ConversationFilterImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
