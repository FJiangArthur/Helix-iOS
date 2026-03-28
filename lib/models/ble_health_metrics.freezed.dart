// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ble_health_metrics.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BleHealthMetrics {

 int get successCount; int get timeoutCount; int get retryCount; int get errorCount; Duration get avgLatency; Duration get totalLatency;
/// Create a copy of BleHealthMetrics
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BleHealthMetricsCopyWith<BleHealthMetrics> get copyWith => _$BleHealthMetricsCopyWithImpl<BleHealthMetrics>(this as BleHealthMetrics, _$identity);

  /// Serializes this BleHealthMetrics to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BleHealthMetrics&&(identical(other.successCount, successCount) || other.successCount == successCount)&&(identical(other.timeoutCount, timeoutCount) || other.timeoutCount == timeoutCount)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount)&&(identical(other.errorCount, errorCount) || other.errorCount == errorCount)&&(identical(other.avgLatency, avgLatency) || other.avgLatency == avgLatency)&&(identical(other.totalLatency, totalLatency) || other.totalLatency == totalLatency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,successCount,timeoutCount,retryCount,errorCount,avgLatency,totalLatency);

@override
String toString() {
  return 'BleHealthMetrics(successCount: $successCount, timeoutCount: $timeoutCount, retryCount: $retryCount, errorCount: $errorCount, avgLatency: $avgLatency, totalLatency: $totalLatency)';
}


}

/// @nodoc
abstract mixin class $BleHealthMetricsCopyWith<$Res>  {
  factory $BleHealthMetricsCopyWith(BleHealthMetrics value, $Res Function(BleHealthMetrics) _then) = _$BleHealthMetricsCopyWithImpl;
@useResult
$Res call({
 int successCount, int timeoutCount, int retryCount, int errorCount, Duration avgLatency, Duration totalLatency
});




}
/// @nodoc
class _$BleHealthMetricsCopyWithImpl<$Res>
    implements $BleHealthMetricsCopyWith<$Res> {
  _$BleHealthMetricsCopyWithImpl(this._self, this._then);

  final BleHealthMetrics _self;
  final $Res Function(BleHealthMetrics) _then;

/// Create a copy of BleHealthMetrics
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? successCount = null,Object? timeoutCount = null,Object? retryCount = null,Object? errorCount = null,Object? avgLatency = null,Object? totalLatency = null,}) {
  return _then(_self.copyWith(
successCount: null == successCount ? _self.successCount : successCount // ignore: cast_nullable_to_non_nullable
as int,timeoutCount: null == timeoutCount ? _self.timeoutCount : timeoutCount // ignore: cast_nullable_to_non_nullable
as int,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,errorCount: null == errorCount ? _self.errorCount : errorCount // ignore: cast_nullable_to_non_nullable
as int,avgLatency: null == avgLatency ? _self.avgLatency : avgLatency // ignore: cast_nullable_to_non_nullable
as Duration,totalLatency: null == totalLatency ? _self.totalLatency : totalLatency // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [BleHealthMetrics].
extension BleHealthMetricsPatterns on BleHealthMetrics {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BleHealthMetrics value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BleHealthMetrics() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BleHealthMetrics value)  $default,){
final _that = this;
switch (_that) {
case _BleHealthMetrics():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BleHealthMetrics value)?  $default,){
final _that = this;
switch (_that) {
case _BleHealthMetrics() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int successCount,  int timeoutCount,  int retryCount,  int errorCount,  Duration avgLatency,  Duration totalLatency)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BleHealthMetrics() when $default != null:
return $default(_that.successCount,_that.timeoutCount,_that.retryCount,_that.errorCount,_that.avgLatency,_that.totalLatency);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int successCount,  int timeoutCount,  int retryCount,  int errorCount,  Duration avgLatency,  Duration totalLatency)  $default,) {final _that = this;
switch (_that) {
case _BleHealthMetrics():
return $default(_that.successCount,_that.timeoutCount,_that.retryCount,_that.errorCount,_that.avgLatency,_that.totalLatency);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int successCount,  int timeoutCount,  int retryCount,  int errorCount,  Duration avgLatency,  Duration totalLatency)?  $default,) {final _that = this;
switch (_that) {
case _BleHealthMetrics() when $default != null:
return $default(_that.successCount,_that.timeoutCount,_that.retryCount,_that.errorCount,_that.avgLatency,_that.totalLatency);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BleHealthMetrics extends BleHealthMetrics {
  const _BleHealthMetrics({this.successCount = 0, this.timeoutCount = 0, this.retryCount = 0, this.errorCount = 0, this.avgLatency = Duration.zero, this.totalLatency = Duration.zero}): super._();
  factory _BleHealthMetrics.fromJson(Map<String, dynamic> json) => _$BleHealthMetricsFromJson(json);

@override@JsonKey() final  int successCount;
@override@JsonKey() final  int timeoutCount;
@override@JsonKey() final  int retryCount;
@override@JsonKey() final  int errorCount;
@override@JsonKey() final  Duration avgLatency;
@override@JsonKey() final  Duration totalLatency;

/// Create a copy of BleHealthMetrics
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BleHealthMetricsCopyWith<_BleHealthMetrics> get copyWith => __$BleHealthMetricsCopyWithImpl<_BleHealthMetrics>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BleHealthMetricsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BleHealthMetrics&&(identical(other.successCount, successCount) || other.successCount == successCount)&&(identical(other.timeoutCount, timeoutCount) || other.timeoutCount == timeoutCount)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount)&&(identical(other.errorCount, errorCount) || other.errorCount == errorCount)&&(identical(other.avgLatency, avgLatency) || other.avgLatency == avgLatency)&&(identical(other.totalLatency, totalLatency) || other.totalLatency == totalLatency));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,successCount,timeoutCount,retryCount,errorCount,avgLatency,totalLatency);

@override
String toString() {
  return 'BleHealthMetrics(successCount: $successCount, timeoutCount: $timeoutCount, retryCount: $retryCount, errorCount: $errorCount, avgLatency: $avgLatency, totalLatency: $totalLatency)';
}


}

/// @nodoc
abstract mixin class _$BleHealthMetricsCopyWith<$Res> implements $BleHealthMetricsCopyWith<$Res> {
  factory _$BleHealthMetricsCopyWith(_BleHealthMetrics value, $Res Function(_BleHealthMetrics) _then) = __$BleHealthMetricsCopyWithImpl;
@override @useResult
$Res call({
 int successCount, int timeoutCount, int retryCount, int errorCount, Duration avgLatency, Duration totalLatency
});




}
/// @nodoc
class __$BleHealthMetricsCopyWithImpl<$Res>
    implements _$BleHealthMetricsCopyWith<$Res> {
  __$BleHealthMetricsCopyWithImpl(this._self, this._then);

  final _BleHealthMetrics _self;
  final $Res Function(_BleHealthMetrics) _then;

/// Create a copy of BleHealthMetrics
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? successCount = null,Object? timeoutCount = null,Object? retryCount = null,Object? errorCount = null,Object? avgLatency = null,Object? totalLatency = null,}) {
  return _then(_BleHealthMetrics(
successCount: null == successCount ? _self.successCount : successCount // ignore: cast_nullable_to_non_nullable
as int,timeoutCount: null == timeoutCount ? _self.timeoutCount : timeoutCount // ignore: cast_nullable_to_non_nullable
as int,retryCount: null == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int,errorCount: null == errorCount ? _self.errorCount : errorCount // ignore: cast_nullable_to_non_nullable
as int,avgLatency: null == avgLatency ? _self.avgLatency : avgLatency // ignore: cast_nullable_to_non_nullable
as Duration,totalLatency: null == totalLatency ? _self.totalLatency : totalLatency // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

// dart format on
