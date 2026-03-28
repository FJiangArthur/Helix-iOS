// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_chunk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AudioChunk {

 Uint8List get data; DateTime get timestamp; int get sampleRate; int get channels; int get bitsPerSample;
/// Create a copy of AudioChunk
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioChunkCopyWith<AudioChunk> get copyWith => _$AudioChunkCopyWithImpl<AudioChunk>(this as AudioChunk, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioChunk&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.bitsPerSample, bitsPerSample) || other.bitsPerSample == bitsPerSample));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),timestamp,sampleRate,channels,bitsPerSample);

@override
String toString() {
  return 'AudioChunk(data: $data, timestamp: $timestamp, sampleRate: $sampleRate, channels: $channels, bitsPerSample: $bitsPerSample)';
}


}

/// @nodoc
abstract mixin class $AudioChunkCopyWith<$Res>  {
  factory $AudioChunkCopyWith(AudioChunk value, $Res Function(AudioChunk) _then) = _$AudioChunkCopyWithImpl;
@useResult
$Res call({
 Uint8List data, DateTime timestamp, int sampleRate, int channels, int bitsPerSample
});




}
/// @nodoc
class _$AudioChunkCopyWithImpl<$Res>
    implements $AudioChunkCopyWith<$Res> {
  _$AudioChunkCopyWithImpl(this._self, this._then);

  final AudioChunk _self;
  final $Res Function(AudioChunk) _then;

/// Create a copy of AudioChunk
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,Object? timestamp = null,Object? sampleRate = null,Object? channels = null,Object? bitsPerSample = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Uint8List,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,bitsPerSample: null == bitsPerSample ? _self.bitsPerSample : bitsPerSample // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioChunk].
extension AudioChunkPatterns on AudioChunk {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioChunk value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioChunk() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioChunk value)  $default,){
final _that = this;
switch (_that) {
case _AudioChunk():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioChunk value)?  $default,){
final _that = this;
switch (_that) {
case _AudioChunk() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Uint8List data,  DateTime timestamp,  int sampleRate,  int channels,  int bitsPerSample)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioChunk() when $default != null:
return $default(_that.data,_that.timestamp,_that.sampleRate,_that.channels,_that.bitsPerSample);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Uint8List data,  DateTime timestamp,  int sampleRate,  int channels,  int bitsPerSample)  $default,) {final _that = this;
switch (_that) {
case _AudioChunk():
return $default(_that.data,_that.timestamp,_that.sampleRate,_that.channels,_that.bitsPerSample);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Uint8List data,  DateTime timestamp,  int sampleRate,  int channels,  int bitsPerSample)?  $default,) {final _that = this;
switch (_that) {
case _AudioChunk() when $default != null:
return $default(_that.data,_that.timestamp,_that.sampleRate,_that.channels,_that.bitsPerSample);case _:
  return null;

}
}

}

/// @nodoc


class _AudioChunk implements AudioChunk {
  const _AudioChunk({required this.data, required this.timestamp, this.sampleRate = 16000, this.channels = 1, this.bitsPerSample = 16});
  

@override final  Uint8List data;
@override final  DateTime timestamp;
@override@JsonKey() final  int sampleRate;
@override@JsonKey() final  int channels;
@override@JsonKey() final  int bitsPerSample;

/// Create a copy of AudioChunk
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioChunkCopyWith<_AudioChunk> get copyWith => __$AudioChunkCopyWithImpl<_AudioChunk>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioChunk&&const DeepCollectionEquality().equals(other.data, data)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.sampleRate, sampleRate) || other.sampleRate == sampleRate)&&(identical(other.channels, channels) || other.channels == channels)&&(identical(other.bitsPerSample, bitsPerSample) || other.bitsPerSample == bitsPerSample));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data),timestamp,sampleRate,channels,bitsPerSample);

@override
String toString() {
  return 'AudioChunk(data: $data, timestamp: $timestamp, sampleRate: $sampleRate, channels: $channels, bitsPerSample: $bitsPerSample)';
}


}

/// @nodoc
abstract mixin class _$AudioChunkCopyWith<$Res> implements $AudioChunkCopyWith<$Res> {
  factory _$AudioChunkCopyWith(_AudioChunk value, $Res Function(_AudioChunk) _then) = __$AudioChunkCopyWithImpl;
@override @useResult
$Res call({
 Uint8List data, DateTime timestamp, int sampleRate, int channels, int bitsPerSample
});




}
/// @nodoc
class __$AudioChunkCopyWithImpl<$Res>
    implements _$AudioChunkCopyWith<$Res> {
  __$AudioChunkCopyWithImpl(this._self, this._then);

  final _AudioChunk _self;
  final $Res Function(_AudioChunk) _then;

/// Create a copy of AudioChunk
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,Object? timestamp = null,Object? sampleRate = null,Object? channels = null,Object? bitsPerSample = null,}) {
  return _then(_AudioChunk(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as Uint8List,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,sampleRate: null == sampleRate ? _self.sampleRate : sampleRate // ignore: cast_nullable_to_non_nullable
as int,channels: null == channels ? _self.channels : channels // ignore: cast_nullable_to_non_nullable
as int,bitsPerSample: null == bitsPerSample ? _self.bitsPerSample : bitsPerSample // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
