// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audio_chunk.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AudioChunk {
  Uint8List get data => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;
  int get sampleRate => throw _privateConstructorUsedError;
  int get channels => throw _privateConstructorUsedError;
  int get bitsPerSample => throw _privateConstructorUsedError;

  /// Create a copy of AudioChunk
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AudioChunkCopyWith<AudioChunk> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AudioChunkCopyWith<$Res> {
  factory $AudioChunkCopyWith(
    AudioChunk value,
    $Res Function(AudioChunk) then,
  ) = _$AudioChunkCopyWithImpl<$Res, AudioChunk>;
  @useResult
  $Res call({
    Uint8List data,
    DateTime timestamp,
    int sampleRate,
    int channels,
    int bitsPerSample,
  });
}

/// @nodoc
class _$AudioChunkCopyWithImpl<$Res, $Val extends AudioChunk>
    implements $AudioChunkCopyWith<$Res> {
  _$AudioChunkCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AudioChunk
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? timestamp = null,
    Object? sampleRate = null,
    Object? channels = null,
    Object? bitsPerSample = null,
  }) {
    return _then(
      _value.copyWith(
            data: null == data
                ? _value.data
                : data // ignore: cast_nullable_to_non_nullable
                      as Uint8List,
            timestamp: null == timestamp
                ? _value.timestamp
                : timestamp // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            sampleRate: null == sampleRate
                ? _value.sampleRate
                : sampleRate // ignore: cast_nullable_to_non_nullable
                      as int,
            channels: null == channels
                ? _value.channels
                : channels // ignore: cast_nullable_to_non_nullable
                      as int,
            bitsPerSample: null == bitsPerSample
                ? _value.bitsPerSample
                : bitsPerSample // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AudioChunkImplCopyWith<$Res>
    implements $AudioChunkCopyWith<$Res> {
  factory _$$AudioChunkImplCopyWith(
    _$AudioChunkImpl value,
    $Res Function(_$AudioChunkImpl) then,
  ) = __$$AudioChunkImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    Uint8List data,
    DateTime timestamp,
    int sampleRate,
    int channels,
    int bitsPerSample,
  });
}

/// @nodoc
class __$$AudioChunkImplCopyWithImpl<$Res>
    extends _$AudioChunkCopyWithImpl<$Res, _$AudioChunkImpl>
    implements _$$AudioChunkImplCopyWith<$Res> {
  __$$AudioChunkImplCopyWithImpl(
    _$AudioChunkImpl _value,
    $Res Function(_$AudioChunkImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AudioChunk
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? data = null,
    Object? timestamp = null,
    Object? sampleRate = null,
    Object? channels = null,
    Object? bitsPerSample = null,
  }) {
    return _then(
      _$AudioChunkImpl(
        data: null == data
            ? _value.data
            : data // ignore: cast_nullable_to_non_nullable
                  as Uint8List,
        timestamp: null == timestamp
            ? _value.timestamp
            : timestamp // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        sampleRate: null == sampleRate
            ? _value.sampleRate
            : sampleRate // ignore: cast_nullable_to_non_nullable
                  as int,
        channels: null == channels
            ? _value.channels
            : channels // ignore: cast_nullable_to_non_nullable
                  as int,
        bitsPerSample: null == bitsPerSample
            ? _value.bitsPerSample
            : bitsPerSample // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$AudioChunkImpl implements _AudioChunk {
  const _$AudioChunkImpl({
    required this.data,
    required this.timestamp,
    this.sampleRate = 16000,
    this.channels = 1,
    this.bitsPerSample = 16,
  });

  @override
  final Uint8List data;
  @override
  final DateTime timestamp;
  @override
  @JsonKey()
  final int sampleRate;
  @override
  @JsonKey()
  final int channels;
  @override
  @JsonKey()
  final int bitsPerSample;

  @override
  String toString() {
    return 'AudioChunk(data: $data, timestamp: $timestamp, sampleRate: $sampleRate, channels: $channels, bitsPerSample: $bitsPerSample)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AudioChunkImpl &&
            const DeepCollectionEquality().equals(other.data, data) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.sampleRate, sampleRate) ||
                other.sampleRate == sampleRate) &&
            (identical(other.channels, channels) ||
                other.channels == channels) &&
            (identical(other.bitsPerSample, bitsPerSample) ||
                other.bitsPerSample == bitsPerSample));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(data),
    timestamp,
    sampleRate,
    channels,
    bitsPerSample,
  );

  /// Create a copy of AudioChunk
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AudioChunkImplCopyWith<_$AudioChunkImpl> get copyWith =>
      __$$AudioChunkImplCopyWithImpl<_$AudioChunkImpl>(this, _$identity);
}

abstract class _AudioChunk implements AudioChunk {
  const factory _AudioChunk({
    required final Uint8List data,
    required final DateTime timestamp,
    final int sampleRate,
    final int channels,
    final int bitsPerSample,
  }) = _$AudioChunkImpl;

  @override
  Uint8List get data;
  @override
  DateTime get timestamp;
  @override
  int get sampleRate;
  @override
  int get channels;
  @override
  int get bitsPerSample;

  /// Create a copy of AudioChunk
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AudioChunkImplCopyWith<_$AudioChunkImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
