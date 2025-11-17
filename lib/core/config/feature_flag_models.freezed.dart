// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'feature_flag_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

FeatureFlagMetadata _$FeatureFlagMetadataFromJson(Map<String, dynamic> json) {
  return _FeatureFlagMetadata.fromJson(json);
}

/// @nodoc
mixin _$FeatureFlagMetadata {
  String get category => throw _privateConstructorUsedError;
  bool get requiresRestart => throw _privateConstructorUsedError;
  String? get addedDate => throw _privateConstructorUsedError;
  String? get experimentEndDate => throw _privateConstructorUsedError;

  /// Serializes this FeatureFlagMetadata to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeatureFlagMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeatureFlagMetadataCopyWith<FeatureFlagMetadata> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeatureFlagMetadataCopyWith<$Res> {
  factory $FeatureFlagMetadataCopyWith(
    FeatureFlagMetadata value,
    $Res Function(FeatureFlagMetadata) then,
  ) = _$FeatureFlagMetadataCopyWithImpl<$Res, FeatureFlagMetadata>;
  @useResult
  $Res call({
    String category,
    bool requiresRestart,
    String? addedDate,
    String? experimentEndDate,
  });
}

/// @nodoc
class _$FeatureFlagMetadataCopyWithImpl<$Res, $Val extends FeatureFlagMetadata>
    implements $FeatureFlagMetadataCopyWith<$Res> {
  _$FeatureFlagMetadataCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeatureFlagMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? requiresRestart = null,
    Object? addedDate = freezed,
    Object? experimentEndDate = freezed,
  }) {
    return _then(
      _value.copyWith(
            category: null == category
                ? _value.category
                : category // ignore: cast_nullable_to_non_nullable
                      as String,
            requiresRestart: null == requiresRestart
                ? _value.requiresRestart
                : requiresRestart // ignore: cast_nullable_to_non_nullable
                      as bool,
            addedDate: freezed == addedDate
                ? _value.addedDate
                : addedDate // ignore: cast_nullable_to_non_nullable
                      as String?,
            experimentEndDate: freezed == experimentEndDate
                ? _value.experimentEndDate
                : experimentEndDate // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeatureFlagMetadataImplCopyWith<$Res>
    implements $FeatureFlagMetadataCopyWith<$Res> {
  factory _$$FeatureFlagMetadataImplCopyWith(
    _$FeatureFlagMetadataImpl value,
    $Res Function(_$FeatureFlagMetadataImpl) then,
  ) = __$$FeatureFlagMetadataImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String category,
    bool requiresRestart,
    String? addedDate,
    String? experimentEndDate,
  });
}

/// @nodoc
class __$$FeatureFlagMetadataImplCopyWithImpl<$Res>
    extends _$FeatureFlagMetadataCopyWithImpl<$Res, _$FeatureFlagMetadataImpl>
    implements _$$FeatureFlagMetadataImplCopyWith<$Res> {
  __$$FeatureFlagMetadataImplCopyWithImpl(
    _$FeatureFlagMetadataImpl _value,
    $Res Function(_$FeatureFlagMetadataImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeatureFlagMetadata
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? category = null,
    Object? requiresRestart = null,
    Object? addedDate = freezed,
    Object? experimentEndDate = freezed,
  }) {
    return _then(
      _$FeatureFlagMetadataImpl(
        category: null == category
            ? _value.category
            : category // ignore: cast_nullable_to_non_nullable
                  as String,
        requiresRestart: null == requiresRestart
            ? _value.requiresRestart
            : requiresRestart // ignore: cast_nullable_to_non_nullable
                  as bool,
        addedDate: freezed == addedDate
            ? _value.addedDate
            : addedDate // ignore: cast_nullable_to_non_nullable
                  as String?,
        experimentEndDate: freezed == experimentEndDate
            ? _value.experimentEndDate
            : experimentEndDate // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeatureFlagMetadataImpl implements _FeatureFlagMetadata {
  const _$FeatureFlagMetadataImpl({
    required this.category,
    this.requiresRestart = false,
    this.addedDate,
    this.experimentEndDate,
  });

  factory _$FeatureFlagMetadataImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeatureFlagMetadataImplFromJson(json);

  @override
  final String category;
  @override
  @JsonKey()
  final bool requiresRestart;
  @override
  final String? addedDate;
  @override
  final String? experimentEndDate;

  @override
  String toString() {
    return 'FeatureFlagMetadata(category: $category, requiresRestart: $requiresRestart, addedDate: $addedDate, experimentEndDate: $experimentEndDate)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeatureFlagMetadataImpl &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.requiresRestart, requiresRestart) ||
                other.requiresRestart == requiresRestart) &&
            (identical(other.addedDate, addedDate) ||
                other.addedDate == addedDate) &&
            (identical(other.experimentEndDate, experimentEndDate) ||
                other.experimentEndDate == experimentEndDate));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    category,
    requiresRestart,
    addedDate,
    experimentEndDate,
  );

  /// Create a copy of FeatureFlagMetadata
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeatureFlagMetadataImplCopyWith<_$FeatureFlagMetadataImpl> get copyWith =>
      __$$FeatureFlagMetadataImplCopyWithImpl<_$FeatureFlagMetadataImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FeatureFlagMetadataImplToJson(this);
  }
}

abstract class _FeatureFlagMetadata implements FeatureFlagMetadata {
  const factory _FeatureFlagMetadata({
    required final String category,
    final bool requiresRestart,
    final String? addedDate,
    final String? experimentEndDate,
  }) = _$FeatureFlagMetadataImpl;

  factory _FeatureFlagMetadata.fromJson(Map<String, dynamic> json) =
      _$FeatureFlagMetadataImpl.fromJson;

  @override
  String get category;
  @override
  bool get requiresRestart;
  @override
  String? get addedDate;
  @override
  String? get experimentEndDate;

  /// Create a copy of FeatureFlagMetadata
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeatureFlagMetadataImplCopyWith<_$FeatureFlagMetadataImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeatureFlagVariants _$FeatureFlagVariantsFromJson(Map<String, dynamic> json) {
  return _FeatureFlagVariants.fromJson(json);
}

/// @nodoc
mixin _$FeatureFlagVariants {
  bool get development => throw _privateConstructorUsedError;
  bool get staging => throw _privateConstructorUsedError;
  bool get production => throw _privateConstructorUsedError;

  /// Serializes this FeatureFlagVariants to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeatureFlagVariants
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeatureFlagVariantsCopyWith<FeatureFlagVariants> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeatureFlagVariantsCopyWith<$Res> {
  factory $FeatureFlagVariantsCopyWith(
    FeatureFlagVariants value,
    $Res Function(FeatureFlagVariants) then,
  ) = _$FeatureFlagVariantsCopyWithImpl<$Res, FeatureFlagVariants>;
  @useResult
  $Res call({bool development, bool staging, bool production});
}

/// @nodoc
class _$FeatureFlagVariantsCopyWithImpl<$Res, $Val extends FeatureFlagVariants>
    implements $FeatureFlagVariantsCopyWith<$Res> {
  _$FeatureFlagVariantsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeatureFlagVariants
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? development = null,
    Object? staging = null,
    Object? production = null,
  }) {
    return _then(
      _value.copyWith(
            development: null == development
                ? _value.development
                : development // ignore: cast_nullable_to_non_nullable
                      as bool,
            staging: null == staging
                ? _value.staging
                : staging // ignore: cast_nullable_to_non_nullable
                      as bool,
            production: null == production
                ? _value.production
                : production // ignore: cast_nullable_to_non_nullable
                      as bool,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$FeatureFlagVariantsImplCopyWith<$Res>
    implements $FeatureFlagVariantsCopyWith<$Res> {
  factory _$$FeatureFlagVariantsImplCopyWith(
    _$FeatureFlagVariantsImpl value,
    $Res Function(_$FeatureFlagVariantsImpl) then,
  ) = __$$FeatureFlagVariantsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool development, bool staging, bool production});
}

/// @nodoc
class __$$FeatureFlagVariantsImplCopyWithImpl<$Res>
    extends _$FeatureFlagVariantsCopyWithImpl<$Res, _$FeatureFlagVariantsImpl>
    implements _$$FeatureFlagVariantsImplCopyWith<$Res> {
  __$$FeatureFlagVariantsImplCopyWithImpl(
    _$FeatureFlagVariantsImpl _value,
    $Res Function(_$FeatureFlagVariantsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeatureFlagVariants
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? development = null,
    Object? staging = null,
    Object? production = null,
  }) {
    return _then(
      _$FeatureFlagVariantsImpl(
        development: null == development
            ? _value.development
            : development // ignore: cast_nullable_to_non_nullable
                  as bool,
        staging: null == staging
            ? _value.staging
            : staging // ignore: cast_nullable_to_non_nullable
                  as bool,
        production: null == production
            ? _value.production
            : production // ignore: cast_nullable_to_non_nullable
                  as bool,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeatureFlagVariantsImpl implements _FeatureFlagVariants {
  const _$FeatureFlagVariantsImpl({
    this.development = false,
    this.staging = false,
    this.production = false,
  });

  factory _$FeatureFlagVariantsImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeatureFlagVariantsImplFromJson(json);

  @override
  @JsonKey()
  final bool development;
  @override
  @JsonKey()
  final bool staging;
  @override
  @JsonKey()
  final bool production;

  @override
  String toString() {
    return 'FeatureFlagVariants(development: $development, staging: $staging, production: $production)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeatureFlagVariantsImpl &&
            (identical(other.development, development) ||
                other.development == development) &&
            (identical(other.staging, staging) || other.staging == staging) &&
            (identical(other.production, production) ||
                other.production == production));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, development, staging, production);

  /// Create a copy of FeatureFlagVariants
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeatureFlagVariantsImplCopyWith<_$FeatureFlagVariantsImpl> get copyWith =>
      __$$FeatureFlagVariantsImplCopyWithImpl<_$FeatureFlagVariantsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FeatureFlagVariantsImplToJson(this);
  }
}

abstract class _FeatureFlagVariants implements FeatureFlagVariants {
  const factory _FeatureFlagVariants({
    final bool development,
    final bool staging,
    final bool production,
  }) = _$FeatureFlagVariantsImpl;

  factory _FeatureFlagVariants.fromJson(Map<String, dynamic> json) =
      _$FeatureFlagVariantsImpl.fromJson;

  @override
  bool get development;
  @override
  bool get staging;
  @override
  bool get production;

  /// Create a copy of FeatureFlagVariants
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeatureFlagVariantsImplCopyWith<_$FeatureFlagVariantsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

RolloutPercentage _$RolloutPercentageFromJson(Map<String, dynamic> json) {
  return _RolloutPercentage.fromJson(json);
}

/// @nodoc
mixin _$RolloutPercentage {
  int get development => throw _privateConstructorUsedError;
  int get staging => throw _privateConstructorUsedError;
  int get production => throw _privateConstructorUsedError;

  /// Serializes this RolloutPercentage to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of RolloutPercentage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $RolloutPercentageCopyWith<RolloutPercentage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RolloutPercentageCopyWith<$Res> {
  factory $RolloutPercentageCopyWith(
    RolloutPercentage value,
    $Res Function(RolloutPercentage) then,
  ) = _$RolloutPercentageCopyWithImpl<$Res, RolloutPercentage>;
  @useResult
  $Res call({int development, int staging, int production});
}

/// @nodoc
class _$RolloutPercentageCopyWithImpl<$Res, $Val extends RolloutPercentage>
    implements $RolloutPercentageCopyWith<$Res> {
  _$RolloutPercentageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of RolloutPercentage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? development = null,
    Object? staging = null,
    Object? production = null,
  }) {
    return _then(
      _value.copyWith(
            development: null == development
                ? _value.development
                : development // ignore: cast_nullable_to_non_nullable
                      as int,
            staging: null == staging
                ? _value.staging
                : staging // ignore: cast_nullable_to_non_nullable
                      as int,
            production: null == production
                ? _value.production
                : production // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$RolloutPercentageImplCopyWith<$Res>
    implements $RolloutPercentageCopyWith<$Res> {
  factory _$$RolloutPercentageImplCopyWith(
    _$RolloutPercentageImpl value,
    $Res Function(_$RolloutPercentageImpl) then,
  ) = __$$RolloutPercentageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int development, int staging, int production});
}

/// @nodoc
class __$$RolloutPercentageImplCopyWithImpl<$Res>
    extends _$RolloutPercentageCopyWithImpl<$Res, _$RolloutPercentageImpl>
    implements _$$RolloutPercentageImplCopyWith<$Res> {
  __$$RolloutPercentageImplCopyWithImpl(
    _$RolloutPercentageImpl _value,
    $Res Function(_$RolloutPercentageImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of RolloutPercentage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? development = null,
    Object? staging = null,
    Object? production = null,
  }) {
    return _then(
      _$RolloutPercentageImpl(
        development: null == development
            ? _value.development
            : development // ignore: cast_nullable_to_non_nullable
                  as int,
        staging: null == staging
            ? _value.staging
            : staging // ignore: cast_nullable_to_non_nullable
                  as int,
        production: null == production
            ? _value.production
            : production // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$RolloutPercentageImpl implements _RolloutPercentage {
  const _$RolloutPercentageImpl({
    this.development = 0,
    this.staging = 0,
    this.production = 0,
  });

  factory _$RolloutPercentageImpl.fromJson(Map<String, dynamic> json) =>
      _$$RolloutPercentageImplFromJson(json);

  @override
  @JsonKey()
  final int development;
  @override
  @JsonKey()
  final int staging;
  @override
  @JsonKey()
  final int production;

  @override
  String toString() {
    return 'RolloutPercentage(development: $development, staging: $staging, production: $production)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$RolloutPercentageImpl &&
            (identical(other.development, development) ||
                other.development == development) &&
            (identical(other.staging, staging) || other.staging == staging) &&
            (identical(other.production, production) ||
                other.production == production));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, development, staging, production);

  /// Create a copy of RolloutPercentage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$RolloutPercentageImplCopyWith<_$RolloutPercentageImpl> get copyWith =>
      __$$RolloutPercentageImplCopyWithImpl<_$RolloutPercentageImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$RolloutPercentageImplToJson(this);
  }
}

abstract class _RolloutPercentage implements RolloutPercentage {
  const factory _RolloutPercentage({
    final int development,
    final int staging,
    final int production,
  }) = _$RolloutPercentageImpl;

  factory _RolloutPercentage.fromJson(Map<String, dynamic> json) =
      _$RolloutPercentageImpl.fromJson;

  @override
  int get development;
  @override
  int get staging;
  @override
  int get production;

  /// Create a copy of RolloutPercentage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$RolloutPercentageImplCopyWith<_$RolloutPercentageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeatureFlag _$FeatureFlagFromJson(Map<String, dynamic> json) {
  return _FeatureFlag.fromJson(json);
}

/// @nodoc
mixin _$FeatureFlag {
  String get key => throw _privateConstructorUsedError;
  bool get enabled => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  FeatureFlagType get type => throw _privateConstructorUsedError;
  FeatureFlagMetadata get metadata => throw _privateConstructorUsedError;
  FeatureFlagVariants get variants => throw _privateConstructorUsedError;
  RolloutPercentage? get rolloutPercentage =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> get config => throw _privateConstructorUsedError;

  /// Serializes this FeatureFlag to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeatureFlagCopyWith<FeatureFlag> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeatureFlagCopyWith<$Res> {
  factory $FeatureFlagCopyWith(
    FeatureFlag value,
    $Res Function(FeatureFlag) then,
  ) = _$FeatureFlagCopyWithImpl<$Res, FeatureFlag>;
  @useResult
  $Res call({
    String key,
    bool enabled,
    String description,
    FeatureFlagType type,
    FeatureFlagMetadata metadata,
    FeatureFlagVariants variants,
    RolloutPercentage? rolloutPercentage,
    Map<String, dynamic> config,
  });

  $FeatureFlagMetadataCopyWith<$Res> get metadata;
  $FeatureFlagVariantsCopyWith<$Res> get variants;
  $RolloutPercentageCopyWith<$Res>? get rolloutPercentage;
}

/// @nodoc
class _$FeatureFlagCopyWithImpl<$Res, $Val extends FeatureFlag>
    implements $FeatureFlagCopyWith<$Res> {
  _$FeatureFlagCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? enabled = null,
    Object? description = null,
    Object? type = null,
    Object? metadata = null,
    Object? variants = null,
    Object? rolloutPercentage = freezed,
    Object? config = null,
  }) {
    return _then(
      _value.copyWith(
            key: null == key
                ? _value.key
                : key // ignore: cast_nullable_to_non_nullable
                      as String,
            enabled: null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            type: null == type
                ? _value.type
                : type // ignore: cast_nullable_to_non_nullable
                      as FeatureFlagType,
            metadata: null == metadata
                ? _value.metadata
                : metadata // ignore: cast_nullable_to_non_nullable
                      as FeatureFlagMetadata,
            variants: null == variants
                ? _value.variants
                : variants // ignore: cast_nullable_to_non_nullable
                      as FeatureFlagVariants,
            rolloutPercentage: freezed == rolloutPercentage
                ? _value.rolloutPercentage
                : rolloutPercentage // ignore: cast_nullable_to_non_nullable
                      as RolloutPercentage?,
            config: null == config
                ? _value.config
                : config // ignore: cast_nullable_to_non_nullable
                      as Map<String, dynamic>,
          )
          as $Val,
    );
  }

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeatureFlagMetadataCopyWith<$Res> get metadata {
    return $FeatureFlagMetadataCopyWith<$Res>(_value.metadata, (value) {
      return _then(_value.copyWith(metadata: value) as $Val);
    });
  }

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeatureFlagVariantsCopyWith<$Res> get variants {
    return $FeatureFlagVariantsCopyWith<$Res>(_value.variants, (value) {
      return _then(_value.copyWith(variants: value) as $Val);
    });
  }

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $RolloutPercentageCopyWith<$Res>? get rolloutPercentage {
    if (_value.rolloutPercentage == null) {
      return null;
    }

    return $RolloutPercentageCopyWith<$Res>(_value.rolloutPercentage!, (value) {
      return _then(_value.copyWith(rolloutPercentage: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FeatureFlagImplCopyWith<$Res>
    implements $FeatureFlagCopyWith<$Res> {
  factory _$$FeatureFlagImplCopyWith(
    _$FeatureFlagImpl value,
    $Res Function(_$FeatureFlagImpl) then,
  ) = __$$FeatureFlagImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String key,
    bool enabled,
    String description,
    FeatureFlagType type,
    FeatureFlagMetadata metadata,
    FeatureFlagVariants variants,
    RolloutPercentage? rolloutPercentage,
    Map<String, dynamic> config,
  });

  @override
  $FeatureFlagMetadataCopyWith<$Res> get metadata;
  @override
  $FeatureFlagVariantsCopyWith<$Res> get variants;
  @override
  $RolloutPercentageCopyWith<$Res>? get rolloutPercentage;
}

/// @nodoc
class __$$FeatureFlagImplCopyWithImpl<$Res>
    extends _$FeatureFlagCopyWithImpl<$Res, _$FeatureFlagImpl>
    implements _$$FeatureFlagImplCopyWith<$Res> {
  __$$FeatureFlagImplCopyWithImpl(
    _$FeatureFlagImpl _value,
    $Res Function(_$FeatureFlagImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? enabled = null,
    Object? description = null,
    Object? type = null,
    Object? metadata = null,
    Object? variants = null,
    Object? rolloutPercentage = freezed,
    Object? config = null,
  }) {
    return _then(
      _$FeatureFlagImpl(
        key: null == key
            ? _value.key
            : key // ignore: cast_nullable_to_non_nullable
                  as String,
        enabled: null == enabled
            ? _value.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        type: null == type
            ? _value.type
            : type // ignore: cast_nullable_to_non_nullable
                  as FeatureFlagType,
        metadata: null == metadata
            ? _value.metadata
            : metadata // ignore: cast_nullable_to_non_nullable
                  as FeatureFlagMetadata,
        variants: null == variants
            ? _value.variants
            : variants // ignore: cast_nullable_to_non_nullable
                  as FeatureFlagVariants,
        rolloutPercentage: freezed == rolloutPercentage
            ? _value.rolloutPercentage
            : rolloutPercentage // ignore: cast_nullable_to_non_nullable
                  as RolloutPercentage?,
        config: null == config
            ? _value._config
            : config // ignore: cast_nullable_to_non_nullable
                  as Map<String, dynamic>,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeatureFlagImpl implements _FeatureFlag {
  const _$FeatureFlagImpl({
    required this.key,
    required this.enabled,
    required this.description,
    required this.type,
    required this.metadata,
    required this.variants,
    this.rolloutPercentage,
    final Map<String, dynamic> config = const {},
  }) : _config = config;

  factory _$FeatureFlagImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeatureFlagImplFromJson(json);

  @override
  final String key;
  @override
  final bool enabled;
  @override
  final String description;
  @override
  final FeatureFlagType type;
  @override
  final FeatureFlagMetadata metadata;
  @override
  final FeatureFlagVariants variants;
  @override
  final RolloutPercentage? rolloutPercentage;
  final Map<String, dynamic> _config;
  @override
  @JsonKey()
  Map<String, dynamic> get config {
    if (_config is EqualUnmodifiableMapView) return _config;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_config);
  }

  @override
  String toString() {
    return 'FeatureFlag(key: $key, enabled: $enabled, description: $description, type: $type, metadata: $metadata, variants: $variants, rolloutPercentage: $rolloutPercentage, config: $config)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeatureFlagImpl &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.metadata, metadata) ||
                other.metadata == metadata) &&
            (identical(other.variants, variants) ||
                other.variants == variants) &&
            (identical(other.rolloutPercentage, rolloutPercentage) ||
                other.rolloutPercentage == rolloutPercentage) &&
            const DeepCollectionEquality().equals(other._config, _config));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    key,
    enabled,
    description,
    type,
    metadata,
    variants,
    rolloutPercentage,
    const DeepCollectionEquality().hash(_config),
  );

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeatureFlagImplCopyWith<_$FeatureFlagImpl> get copyWith =>
      __$$FeatureFlagImplCopyWithImpl<_$FeatureFlagImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FeatureFlagImplToJson(this);
  }
}

abstract class _FeatureFlag implements FeatureFlag {
  const factory _FeatureFlag({
    required final String key,
    required final bool enabled,
    required final String description,
    required final FeatureFlagType type,
    required final FeatureFlagMetadata metadata,
    required final FeatureFlagVariants variants,
    final RolloutPercentage? rolloutPercentage,
    final Map<String, dynamic> config,
  }) = _$FeatureFlagImpl;

  factory _FeatureFlag.fromJson(Map<String, dynamic> json) =
      _$FeatureFlagImpl.fromJson;

  @override
  String get key;
  @override
  bool get enabled;
  @override
  String get description;
  @override
  FeatureFlagType get type;
  @override
  FeatureFlagMetadata get metadata;
  @override
  FeatureFlagVariants get variants;
  @override
  RolloutPercentage? get rolloutPercentage;
  @override
  Map<String, dynamic> get config;

  /// Create a copy of FeatureFlag
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeatureFlagImplCopyWith<_$FeatureFlagImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

EnvironmentConfig _$EnvironmentConfigFromJson(Map<String, dynamic> json) {
  return _EnvironmentConfig.fromJson(json);
}

/// @nodoc
mixin _$EnvironmentConfig {
  bool get enabled => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;

  /// Serializes this EnvironmentConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of EnvironmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EnvironmentConfigCopyWith<EnvironmentConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EnvironmentConfigCopyWith<$Res> {
  factory $EnvironmentConfigCopyWith(
    EnvironmentConfig value,
    $Res Function(EnvironmentConfig) then,
  ) = _$EnvironmentConfigCopyWithImpl<$Res, EnvironmentConfig>;
  @useResult
  $Res call({bool enabled, String description});
}

/// @nodoc
class _$EnvironmentConfigCopyWithImpl<$Res, $Val extends EnvironmentConfig>
    implements $EnvironmentConfigCopyWith<$Res> {
  _$EnvironmentConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of EnvironmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? enabled = null, Object? description = null}) {
    return _then(
      _value.copyWith(
            enabled: null == enabled
                ? _value.enabled
                : enabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$EnvironmentConfigImplCopyWith<$Res>
    implements $EnvironmentConfigCopyWith<$Res> {
  factory _$$EnvironmentConfigImplCopyWith(
    _$EnvironmentConfigImpl value,
    $Res Function(_$EnvironmentConfigImpl) then,
  ) = __$$EnvironmentConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({bool enabled, String description});
}

/// @nodoc
class __$$EnvironmentConfigImplCopyWithImpl<$Res>
    extends _$EnvironmentConfigCopyWithImpl<$Res, _$EnvironmentConfigImpl>
    implements _$$EnvironmentConfigImplCopyWith<$Res> {
  __$$EnvironmentConfigImplCopyWithImpl(
    _$EnvironmentConfigImpl _value,
    $Res Function(_$EnvironmentConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of EnvironmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? enabled = null, Object? description = null}) {
    return _then(
      _$EnvironmentConfigImpl(
        enabled: null == enabled
            ? _value.enabled
            : enabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$EnvironmentConfigImpl implements _EnvironmentConfig {
  const _$EnvironmentConfigImpl({
    required this.enabled,
    required this.description,
  });

  factory _$EnvironmentConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$EnvironmentConfigImplFromJson(json);

  @override
  final bool enabled;
  @override
  final String description;

  @override
  String toString() {
    return 'EnvironmentConfig(enabled: $enabled, description: $description)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EnvironmentConfigImpl &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, enabled, description);

  /// Create a copy of EnvironmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EnvironmentConfigImplCopyWith<_$EnvironmentConfigImpl> get copyWith =>
      __$$EnvironmentConfigImplCopyWithImpl<_$EnvironmentConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$EnvironmentConfigImplToJson(this);
  }
}

abstract class _EnvironmentConfig implements EnvironmentConfig {
  const factory _EnvironmentConfig({
    required final bool enabled,
    required final String description,
  }) = _$EnvironmentConfigImpl;

  factory _EnvironmentConfig.fromJson(Map<String, dynamic> json) =
      _$EnvironmentConfigImpl.fromJson;

  @override
  bool get enabled;
  @override
  String get description;

  /// Create a copy of EnvironmentConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EnvironmentConfigImplCopyWith<_$EnvironmentConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

GlobalConfig _$GlobalConfigFromJson(Map<String, dynamic> json) {
  return _GlobalConfig.fromJson(json);
}

/// @nodoc
mixin _$GlobalConfig {
  Environment get defaultEnvironment => throw _privateConstructorUsedError;
  bool get allowEnvironmentOverride => throw _privateConstructorUsedError;
  bool get cacheEnabled => throw _privateConstructorUsedError;
  int get cacheDuration => throw _privateConstructorUsedError;

  /// Serializes this GlobalConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of GlobalConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GlobalConfigCopyWith<GlobalConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GlobalConfigCopyWith<$Res> {
  factory $GlobalConfigCopyWith(
    GlobalConfig value,
    $Res Function(GlobalConfig) then,
  ) = _$GlobalConfigCopyWithImpl<$Res, GlobalConfig>;
  @useResult
  $Res call({
    Environment defaultEnvironment,
    bool allowEnvironmentOverride,
    bool cacheEnabled,
    int cacheDuration,
  });
}

/// @nodoc
class _$GlobalConfigCopyWithImpl<$Res, $Val extends GlobalConfig>
    implements $GlobalConfigCopyWith<$Res> {
  _$GlobalConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GlobalConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? defaultEnvironment = null,
    Object? allowEnvironmentOverride = null,
    Object? cacheEnabled = null,
    Object? cacheDuration = null,
  }) {
    return _then(
      _value.copyWith(
            defaultEnvironment: null == defaultEnvironment
                ? _value.defaultEnvironment
                : defaultEnvironment // ignore: cast_nullable_to_non_nullable
                      as Environment,
            allowEnvironmentOverride: null == allowEnvironmentOverride
                ? _value.allowEnvironmentOverride
                : allowEnvironmentOverride // ignore: cast_nullable_to_non_nullable
                      as bool,
            cacheEnabled: null == cacheEnabled
                ? _value.cacheEnabled
                : cacheEnabled // ignore: cast_nullable_to_non_nullable
                      as bool,
            cacheDuration: null == cacheDuration
                ? _value.cacheDuration
                : cacheDuration // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$GlobalConfigImplCopyWith<$Res>
    implements $GlobalConfigCopyWith<$Res> {
  factory _$$GlobalConfigImplCopyWith(
    _$GlobalConfigImpl value,
    $Res Function(_$GlobalConfigImpl) then,
  ) = __$$GlobalConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Environment defaultEnvironment,
    bool allowEnvironmentOverride,
    bool cacheEnabled,
    int cacheDuration,
  });
}

/// @nodoc
class __$$GlobalConfigImplCopyWithImpl<$Res>
    extends _$GlobalConfigCopyWithImpl<$Res, _$GlobalConfigImpl>
    implements _$$GlobalConfigImplCopyWith<$Res> {
  __$$GlobalConfigImplCopyWithImpl(
    _$GlobalConfigImpl _value,
    $Res Function(_$GlobalConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of GlobalConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? defaultEnvironment = null,
    Object? allowEnvironmentOverride = null,
    Object? cacheEnabled = null,
    Object? cacheDuration = null,
  }) {
    return _then(
      _$GlobalConfigImpl(
        defaultEnvironment: null == defaultEnvironment
            ? _value.defaultEnvironment
            : defaultEnvironment // ignore: cast_nullable_to_non_nullable
                  as Environment,
        allowEnvironmentOverride: null == allowEnvironmentOverride
            ? _value.allowEnvironmentOverride
            : allowEnvironmentOverride // ignore: cast_nullable_to_non_nullable
                  as bool,
        cacheEnabled: null == cacheEnabled
            ? _value.cacheEnabled
            : cacheEnabled // ignore: cast_nullable_to_non_nullable
                  as bool,
        cacheDuration: null == cacheDuration
            ? _value.cacheDuration
            : cacheDuration // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$GlobalConfigImpl implements _GlobalConfig {
  const _$GlobalConfigImpl({
    this.defaultEnvironment = Environment.development,
    this.allowEnvironmentOverride = true,
    this.cacheEnabled = true,
    this.cacheDuration = 300,
  });

  factory _$GlobalConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$GlobalConfigImplFromJson(json);

  @override
  @JsonKey()
  final Environment defaultEnvironment;
  @override
  @JsonKey()
  final bool allowEnvironmentOverride;
  @override
  @JsonKey()
  final bool cacheEnabled;
  @override
  @JsonKey()
  final int cacheDuration;

  @override
  String toString() {
    return 'GlobalConfig(defaultEnvironment: $defaultEnvironment, allowEnvironmentOverride: $allowEnvironmentOverride, cacheEnabled: $cacheEnabled, cacheDuration: $cacheDuration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GlobalConfigImpl &&
            (identical(other.defaultEnvironment, defaultEnvironment) ||
                other.defaultEnvironment == defaultEnvironment) &&
            (identical(
                  other.allowEnvironmentOverride,
                  allowEnvironmentOverride,
                ) ||
                other.allowEnvironmentOverride == allowEnvironmentOverride) &&
            (identical(other.cacheEnabled, cacheEnabled) ||
                other.cacheEnabled == cacheEnabled) &&
            (identical(other.cacheDuration, cacheDuration) ||
                other.cacheDuration == cacheDuration));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    defaultEnvironment,
    allowEnvironmentOverride,
    cacheEnabled,
    cacheDuration,
  );

  /// Create a copy of GlobalConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GlobalConfigImplCopyWith<_$GlobalConfigImpl> get copyWith =>
      __$$GlobalConfigImplCopyWithImpl<_$GlobalConfigImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$GlobalConfigImplToJson(this);
  }
}

abstract class _GlobalConfig implements GlobalConfig {
  const factory _GlobalConfig({
    final Environment defaultEnvironment,
    final bool allowEnvironmentOverride,
    final bool cacheEnabled,
    final int cacheDuration,
  }) = _$GlobalConfigImpl;

  factory _GlobalConfig.fromJson(Map<String, dynamic> json) =
      _$GlobalConfigImpl.fromJson;

  @override
  Environment get defaultEnvironment;
  @override
  bool get allowEnvironmentOverride;
  @override
  bool get cacheEnabled;
  @override
  int get cacheDuration;

  /// Create a copy of GlobalConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GlobalConfigImplCopyWith<_$GlobalConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

FeatureFlagsConfig _$FeatureFlagsConfigFromJson(Map<String, dynamic> json) {
  return _FeatureFlagsConfig.fromJson(json);
}

/// @nodoc
mixin _$FeatureFlagsConfig {
  String get version => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  Map<String, EnvironmentConfig> get environments =>
      throw _privateConstructorUsedError;
  Map<String, FeatureFlag> get flags => throw _privateConstructorUsedError;
  GlobalConfig get globalConfig => throw _privateConstructorUsedError;

  /// Serializes this FeatureFlagsConfig to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FeatureFlagsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FeatureFlagsConfigCopyWith<FeatureFlagsConfig> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FeatureFlagsConfigCopyWith<$Res> {
  factory $FeatureFlagsConfigCopyWith(
    FeatureFlagsConfig value,
    $Res Function(FeatureFlagsConfig) then,
  ) = _$FeatureFlagsConfigCopyWithImpl<$Res, FeatureFlagsConfig>;
  @useResult
  $Res call({
    String version,
    String description,
    Map<String, EnvironmentConfig> environments,
    Map<String, FeatureFlag> flags,
    GlobalConfig globalConfig,
  });

  $GlobalConfigCopyWith<$Res> get globalConfig;
}

/// @nodoc
class _$FeatureFlagsConfigCopyWithImpl<$Res, $Val extends FeatureFlagsConfig>
    implements $FeatureFlagsConfigCopyWith<$Res> {
  _$FeatureFlagsConfigCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FeatureFlagsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? description = null,
    Object? environments = null,
    Object? flags = null,
    Object? globalConfig = null,
  }) {
    return _then(
      _value.copyWith(
            version: null == version
                ? _value.version
                : version // ignore: cast_nullable_to_non_nullable
                      as String,
            description: null == description
                ? _value.description
                : description // ignore: cast_nullable_to_non_nullable
                      as String,
            environments: null == environments
                ? _value.environments
                : environments // ignore: cast_nullable_to_non_nullable
                      as Map<String, EnvironmentConfig>,
            flags: null == flags
                ? _value.flags
                : flags // ignore: cast_nullable_to_non_nullable
                      as Map<String, FeatureFlag>,
            globalConfig: null == globalConfig
                ? _value.globalConfig
                : globalConfig // ignore: cast_nullable_to_non_nullable
                      as GlobalConfig,
          )
          as $Val,
    );
  }

  /// Create a copy of FeatureFlagsConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GlobalConfigCopyWith<$Res> get globalConfig {
    return $GlobalConfigCopyWith<$Res>(_value.globalConfig, (value) {
      return _then(_value.copyWith(globalConfig: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FeatureFlagsConfigImplCopyWith<$Res>
    implements $FeatureFlagsConfigCopyWith<$Res> {
  factory _$$FeatureFlagsConfigImplCopyWith(
    _$FeatureFlagsConfigImpl value,
    $Res Function(_$FeatureFlagsConfigImpl) then,
  ) = __$$FeatureFlagsConfigImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String version,
    String description,
    Map<String, EnvironmentConfig> environments,
    Map<String, FeatureFlag> flags,
    GlobalConfig globalConfig,
  });

  @override
  $GlobalConfigCopyWith<$Res> get globalConfig;
}

/// @nodoc
class __$$FeatureFlagsConfigImplCopyWithImpl<$Res>
    extends _$FeatureFlagsConfigCopyWithImpl<$Res, _$FeatureFlagsConfigImpl>
    implements _$$FeatureFlagsConfigImplCopyWith<$Res> {
  __$$FeatureFlagsConfigImplCopyWithImpl(
    _$FeatureFlagsConfigImpl _value,
    $Res Function(_$FeatureFlagsConfigImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of FeatureFlagsConfig
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? version = null,
    Object? description = null,
    Object? environments = null,
    Object? flags = null,
    Object? globalConfig = null,
  }) {
    return _then(
      _$FeatureFlagsConfigImpl(
        version: null == version
            ? _value.version
            : version // ignore: cast_nullable_to_non_nullable
                  as String,
        description: null == description
            ? _value.description
            : description // ignore: cast_nullable_to_non_nullable
                  as String,
        environments: null == environments
            ? _value._environments
            : environments // ignore: cast_nullable_to_non_nullable
                  as Map<String, EnvironmentConfig>,
        flags: null == flags
            ? _value._flags
            : flags // ignore: cast_nullable_to_non_nullable
                  as Map<String, FeatureFlag>,
        globalConfig: null == globalConfig
            ? _value.globalConfig
            : globalConfig // ignore: cast_nullable_to_non_nullable
                  as GlobalConfig,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$FeatureFlagsConfigImpl implements _FeatureFlagsConfig {
  const _$FeatureFlagsConfigImpl({
    required this.version,
    required this.description,
    required final Map<String, EnvironmentConfig> environments,
    required final Map<String, FeatureFlag> flags,
    required this.globalConfig,
  }) : _environments = environments,
       _flags = flags;

  factory _$FeatureFlagsConfigImpl.fromJson(Map<String, dynamic> json) =>
      _$$FeatureFlagsConfigImplFromJson(json);

  @override
  final String version;
  @override
  final String description;
  final Map<String, EnvironmentConfig> _environments;
  @override
  Map<String, EnvironmentConfig> get environments {
    if (_environments is EqualUnmodifiableMapView) return _environments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_environments);
  }

  final Map<String, FeatureFlag> _flags;
  @override
  Map<String, FeatureFlag> get flags {
    if (_flags is EqualUnmodifiableMapView) return _flags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_flags);
  }

  @override
  final GlobalConfig globalConfig;

  @override
  String toString() {
    return 'FeatureFlagsConfig(version: $version, description: $description, environments: $environments, flags: $flags, globalConfig: $globalConfig)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FeatureFlagsConfigImpl &&
            (identical(other.version, version) || other.version == version) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(
              other._environments,
              _environments,
            ) &&
            const DeepCollectionEquality().equals(other._flags, _flags) &&
            (identical(other.globalConfig, globalConfig) ||
                other.globalConfig == globalConfig));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    version,
    description,
    const DeepCollectionEquality().hash(_environments),
    const DeepCollectionEquality().hash(_flags),
    globalConfig,
  );

  /// Create a copy of FeatureFlagsConfig
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FeatureFlagsConfigImplCopyWith<_$FeatureFlagsConfigImpl> get copyWith =>
      __$$FeatureFlagsConfigImplCopyWithImpl<_$FeatureFlagsConfigImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$FeatureFlagsConfigImplToJson(this);
  }
}

abstract class _FeatureFlagsConfig implements FeatureFlagsConfig {
  const factory _FeatureFlagsConfig({
    required final String version,
    required final String description,
    required final Map<String, EnvironmentConfig> environments,
    required final Map<String, FeatureFlag> flags,
    required final GlobalConfig globalConfig,
  }) = _$FeatureFlagsConfigImpl;

  factory _FeatureFlagsConfig.fromJson(Map<String, dynamic> json) =
      _$FeatureFlagsConfigImpl.fromJson;

  @override
  String get version;
  @override
  String get description;
  @override
  Map<String, EnvironmentConfig> get environments;
  @override
  Map<String, FeatureFlag> get flags;
  @override
  GlobalConfig get globalConfig;

  /// Create a copy of FeatureFlagsConfig
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FeatureFlagsConfigImplCopyWith<_$FeatureFlagsConfigImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
