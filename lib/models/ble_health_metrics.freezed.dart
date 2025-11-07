// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ble_health_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

BleHealthMetrics _$BleHealthMetricsFromJson(Map<String, dynamic> json) {
  return _BleHealthMetrics.fromJson(json);
}

/// @nodoc
mixin _$BleHealthMetrics {
  int get successCount => throw _privateConstructorUsedError;
  int get timeoutCount => throw _privateConstructorUsedError;
  int get retryCount => throw _privateConstructorUsedError;
  int get errorCount => throw _privateConstructorUsedError;
  Duration get avgLatency => throw _privateConstructorUsedError;
  Duration get totalLatency => throw _privateConstructorUsedError;

  /// Serializes this BleHealthMetrics to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of BleHealthMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BleHealthMetricsCopyWith<BleHealthMetrics> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BleHealthMetricsCopyWith<$Res> {
  factory $BleHealthMetricsCopyWith(
    BleHealthMetrics value,
    $Res Function(BleHealthMetrics) then,
  ) = _$BleHealthMetricsCopyWithImpl<$Res, BleHealthMetrics>;
  @useResult
  $Res call({
    int successCount,
    int timeoutCount,
    int retryCount,
    int errorCount,
    Duration avgLatency,
    Duration totalLatency,
  });
}

/// @nodoc
class _$BleHealthMetricsCopyWithImpl<$Res, $Val extends BleHealthMetrics>
    implements $BleHealthMetricsCopyWith<$Res> {
  _$BleHealthMetricsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BleHealthMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? successCount = null,
    Object? timeoutCount = null,
    Object? retryCount = null,
    Object? errorCount = null,
    Object? avgLatency = null,
    Object? totalLatency = null,
  }) {
    return _then(
      _value.copyWith(
            successCount: null == successCount
                ? _value.successCount
                : successCount // ignore: cast_nullable_to_non_nullable
                      as int,
            timeoutCount: null == timeoutCount
                ? _value.timeoutCount
                : timeoutCount // ignore: cast_nullable_to_non_nullable
                      as int,
            retryCount: null == retryCount
                ? _value.retryCount
                : retryCount // ignore: cast_nullable_to_non_nullable
                      as int,
            errorCount: null == errorCount
                ? _value.errorCount
                : errorCount // ignore: cast_nullable_to_non_nullable
                      as int,
            avgLatency: null == avgLatency
                ? _value.avgLatency
                : avgLatency // ignore: cast_nullable_to_non_nullable
                      as Duration,
            totalLatency: null == totalLatency
                ? _value.totalLatency
                : totalLatency // ignore: cast_nullable_to_non_nullable
                      as Duration,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BleHealthMetricsImplCopyWith<$Res>
    implements $BleHealthMetricsCopyWith<$Res> {
  factory _$$BleHealthMetricsImplCopyWith(
    _$BleHealthMetricsImpl value,
    $Res Function(_$BleHealthMetricsImpl) then,
  ) = __$$BleHealthMetricsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int successCount,
    int timeoutCount,
    int retryCount,
    int errorCount,
    Duration avgLatency,
    Duration totalLatency,
  });
}

/// @nodoc
class __$$BleHealthMetricsImplCopyWithImpl<$Res>
    extends _$BleHealthMetricsCopyWithImpl<$Res, _$BleHealthMetricsImpl>
    implements _$$BleHealthMetricsImplCopyWith<$Res> {
  __$$BleHealthMetricsImplCopyWithImpl(
    _$BleHealthMetricsImpl _value,
    $Res Function(_$BleHealthMetricsImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BleHealthMetrics
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? successCount = null,
    Object? timeoutCount = null,
    Object? retryCount = null,
    Object? errorCount = null,
    Object? avgLatency = null,
    Object? totalLatency = null,
  }) {
    return _then(
      _$BleHealthMetricsImpl(
        successCount: null == successCount
            ? _value.successCount
            : successCount // ignore: cast_nullable_to_non_nullable
                  as int,
        timeoutCount: null == timeoutCount
            ? _value.timeoutCount
            : timeoutCount // ignore: cast_nullable_to_non_nullable
                  as int,
        retryCount: null == retryCount
            ? _value.retryCount
            : retryCount // ignore: cast_nullable_to_non_nullable
                  as int,
        errorCount: null == errorCount
            ? _value.errorCount
            : errorCount // ignore: cast_nullable_to_non_nullable
                  as int,
        avgLatency: null == avgLatency
            ? _value.avgLatency
            : avgLatency // ignore: cast_nullable_to_non_nullable
                  as Duration,
        totalLatency: null == totalLatency
            ? _value.totalLatency
            : totalLatency // ignore: cast_nullable_to_non_nullable
                  as Duration,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$BleHealthMetricsImpl extends _BleHealthMetrics {
  const _$BleHealthMetricsImpl({
    this.successCount = 0,
    this.timeoutCount = 0,
    this.retryCount = 0,
    this.errorCount = 0,
    this.avgLatency = Duration.zero,
    this.totalLatency = Duration.zero,
  }) : super._();

  factory _$BleHealthMetricsImpl.fromJson(Map<String, dynamic> json) =>
      _$$BleHealthMetricsImplFromJson(json);

  @override
  @JsonKey()
  final int successCount;
  @override
  @JsonKey()
  final int timeoutCount;
  @override
  @JsonKey()
  final int retryCount;
  @override
  @JsonKey()
  final int errorCount;
  @override
  @JsonKey()
  final Duration avgLatency;
  @override
  @JsonKey()
  final Duration totalLatency;

  @override
  String toString() {
    return 'BleHealthMetrics(successCount: $successCount, timeoutCount: $timeoutCount, retryCount: $retryCount, errorCount: $errorCount, avgLatency: $avgLatency, totalLatency: $totalLatency)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BleHealthMetricsImpl &&
            (identical(other.successCount, successCount) ||
                other.successCount == successCount) &&
            (identical(other.timeoutCount, timeoutCount) ||
                other.timeoutCount == timeoutCount) &&
            (identical(other.retryCount, retryCount) ||
                other.retryCount == retryCount) &&
            (identical(other.errorCount, errorCount) ||
                other.errorCount == errorCount) &&
            (identical(other.avgLatency, avgLatency) ||
                other.avgLatency == avgLatency) &&
            (identical(other.totalLatency, totalLatency) ||
                other.totalLatency == totalLatency));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    successCount,
    timeoutCount,
    retryCount,
    errorCount,
    avgLatency,
    totalLatency,
  );

  /// Create a copy of BleHealthMetrics
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BleHealthMetricsImplCopyWith<_$BleHealthMetricsImpl> get copyWith =>
      __$$BleHealthMetricsImplCopyWithImpl<_$BleHealthMetricsImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$BleHealthMetricsImplToJson(this);
  }
}

abstract class _BleHealthMetrics extends BleHealthMetrics {
  const factory _BleHealthMetrics({
    final int successCount,
    final int timeoutCount,
    final int retryCount,
    final int errorCount,
    final Duration avgLatency,
    final Duration totalLatency,
  }) = _$BleHealthMetricsImpl;
  const _BleHealthMetrics._() : super._();

  factory _BleHealthMetrics.fromJson(Map<String, dynamic> json) =
      _$BleHealthMetricsImpl.fromJson;

  @override
  int get successCount;
  @override
  int get timeoutCount;
  @override
  int get retryCount;
  @override
  int get errorCount;
  @override
  Duration get avgLatency;
  @override
  Duration get totalLatency;

  /// Create a copy of BleHealthMetrics
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BleHealthMetricsImplCopyWith<_$BleHealthMetricsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
