// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ble_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$BleTransaction {
  String get id => throw _privateConstructorUsedError;
  Uint8List get command => throw _privateConstructorUsedError;
  String get target =>
      throw _privateConstructorUsedError; // 'L', 'R', or 'BOTH'
  Duration get timeout => throw _privateConstructorUsedError;
  int? get retryCount => throw _privateConstructorUsedError;

  /// Create a copy of BleTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BleTransactionCopyWith<BleTransaction> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BleTransactionCopyWith<$Res> {
  factory $BleTransactionCopyWith(
    BleTransaction value,
    $Res Function(BleTransaction) then,
  ) = _$BleTransactionCopyWithImpl<$Res, BleTransaction>;
  @useResult
  $Res call({
    String id,
    Uint8List command,
    String target,
    Duration timeout,
    int? retryCount,
  });
}

/// @nodoc
class _$BleTransactionCopyWithImpl<$Res, $Val extends BleTransaction>
    implements $BleTransactionCopyWith<$Res> {
  _$BleTransactionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BleTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? command = null,
    Object? target = null,
    Object? timeout = null,
    Object? retryCount = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            command: null == command
                ? _value.command
                : command // ignore: cast_nullable_to_non_nullable
                      as Uint8List,
            target: null == target
                ? _value.target
                : target // ignore: cast_nullable_to_non_nullable
                      as String,
            timeout: null == timeout
                ? _value.timeout
                : timeout // ignore: cast_nullable_to_non_nullable
                      as Duration,
            retryCount: freezed == retryCount
                ? _value.retryCount
                : retryCount // ignore: cast_nullable_to_non_nullable
                      as int?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$BleTransactionImplCopyWith<$Res>
    implements $BleTransactionCopyWith<$Res> {
  factory _$$BleTransactionImplCopyWith(
    _$BleTransactionImpl value,
    $Res Function(_$BleTransactionImpl) then,
  ) = __$$BleTransactionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    Uint8List command,
    String target,
    Duration timeout,
    int? retryCount,
  });
}

/// @nodoc
class __$$BleTransactionImplCopyWithImpl<$Res>
    extends _$BleTransactionCopyWithImpl<$Res, _$BleTransactionImpl>
    implements _$$BleTransactionImplCopyWith<$Res> {
  __$$BleTransactionImplCopyWithImpl(
    _$BleTransactionImpl _value,
    $Res Function(_$BleTransactionImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BleTransaction
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? command = null,
    Object? target = null,
    Object? timeout = null,
    Object? retryCount = freezed,
  }) {
    return _then(
      _$BleTransactionImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        command: null == command
            ? _value.command
            : command // ignore: cast_nullable_to_non_nullable
                  as Uint8List,
        target: null == target
            ? _value.target
            : target // ignore: cast_nullable_to_non_nullable
                  as String,
        timeout: null == timeout
            ? _value.timeout
            : timeout // ignore: cast_nullable_to_non_nullable
                  as Duration,
        retryCount: freezed == retryCount
            ? _value.retryCount
            : retryCount // ignore: cast_nullable_to_non_nullable
                  as int?,
      ),
    );
  }
}

/// @nodoc

class _$BleTransactionImpl extends _BleTransaction {
  const _$BleTransactionImpl({
    required this.id,
    required this.command,
    required this.target,
    this.timeout = const Duration(milliseconds: 1000),
    this.retryCount,
  }) : super._();

  @override
  final String id;
  @override
  final Uint8List command;
  @override
  final String target;
  // 'L', 'R', or 'BOTH'
  @override
  @JsonKey()
  final Duration timeout;
  @override
  final int? retryCount;

  @override
  String toString() {
    return 'BleTransaction(id: $id, command: $command, target: $target, timeout: $timeout, retryCount: $retryCount)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BleTransactionImpl &&
            (identical(other.id, id) || other.id == id) &&
            const DeepCollectionEquality().equals(other.command, command) &&
            (identical(other.target, target) || other.target == target) &&
            (identical(other.timeout, timeout) || other.timeout == timeout) &&
            (identical(other.retryCount, retryCount) ||
                other.retryCount == retryCount));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    const DeepCollectionEquality().hash(command),
    target,
    timeout,
    retryCount,
  );

  /// Create a copy of BleTransaction
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BleTransactionImplCopyWith<_$BleTransactionImpl> get copyWith =>
      __$$BleTransactionImplCopyWithImpl<_$BleTransactionImpl>(
        this,
        _$identity,
      );
}

abstract class _BleTransaction extends BleTransaction {
  const factory _BleTransaction({
    required final String id,
    required final Uint8List command,
    required final String target,
    final Duration timeout,
    final int? retryCount,
  }) = _$BleTransactionImpl;
  const _BleTransaction._() : super._();

  @override
  String get id;
  @override
  Uint8List get command;
  @override
  String get target; // 'L', 'R', or 'BOTH'
  @override
  Duration get timeout;
  @override
  int? get retryCount;

  /// Create a copy of BleTransaction
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BleTransactionImplCopyWith<_$BleTransactionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$BleTransactionResult {
  BleTransaction get transaction => throw _privateConstructorUsedError;
  Duration get duration => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )
    success,
    required TResult Function(BleTransaction transaction, Duration duration)
    timeout,
    required TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )
    error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult? Function(BleTransaction transaction, Duration duration)? timeout,
    TResult? Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult Function(BleTransaction transaction, Duration duration)? timeout,
    TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BleTransactionSuccess value) success,
    required TResult Function(BleTransactionTimeout value) timeout,
    required TResult Function(BleTransactionError value) error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BleTransactionSuccess value)? success,
    TResult? Function(BleTransactionTimeout value)? timeout,
    TResult? Function(BleTransactionError value)? error,
  }) => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BleTransactionSuccess value)? success,
    TResult Function(BleTransactionTimeout value)? timeout,
    TResult Function(BleTransactionError value)? error,
    required TResult orElse(),
  }) => throw _privateConstructorUsedError;

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BleTransactionResultCopyWith<BleTransactionResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BleTransactionResultCopyWith<$Res> {
  factory $BleTransactionResultCopyWith(
    BleTransactionResult value,
    $Res Function(BleTransactionResult) then,
  ) = _$BleTransactionResultCopyWithImpl<$Res, BleTransactionResult>;
  @useResult
  $Res call({BleTransaction transaction, Duration duration});

  $BleTransactionCopyWith<$Res> get transaction;
}

/// @nodoc
class _$BleTransactionResultCopyWithImpl<
  $Res,
  $Val extends BleTransactionResult
>
    implements $BleTransactionResultCopyWith<$Res> {
  _$BleTransactionResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? transaction = null, Object? duration = null}) {
    return _then(
      _value.copyWith(
            transaction: null == transaction
                ? _value.transaction
                : transaction // ignore: cast_nullable_to_non_nullable
                      as BleTransaction,
            duration: null == duration
                ? _value.duration
                : duration // ignore: cast_nullable_to_non_nullable
                      as Duration,
          )
          as $Val,
    );
  }

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BleTransactionCopyWith<$Res> get transaction {
    return $BleTransactionCopyWith<$Res>(_value.transaction, (value) {
      return _then(_value.copyWith(transaction: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BleTransactionSuccessImplCopyWith<$Res>
    implements $BleTransactionResultCopyWith<$Res> {
  factory _$$BleTransactionSuccessImplCopyWith(
    _$BleTransactionSuccessImpl value,
    $Res Function(_$BleTransactionSuccessImpl) then,
  ) = __$$BleTransactionSuccessImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    BleTransaction transaction,
    BleReceive response,
    Duration duration,
  });

  @override
  $BleTransactionCopyWith<$Res> get transaction;
}

/// @nodoc
class __$$BleTransactionSuccessImplCopyWithImpl<$Res>
    extends
        _$BleTransactionResultCopyWithImpl<$Res, _$BleTransactionSuccessImpl>
    implements _$$BleTransactionSuccessImplCopyWith<$Res> {
  __$$BleTransactionSuccessImplCopyWithImpl(
    _$BleTransactionSuccessImpl _value,
    $Res Function(_$BleTransactionSuccessImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transaction = null,
    Object? response = null,
    Object? duration = null,
  }) {
    return _then(
      _$BleTransactionSuccessImpl(
        transaction: null == transaction
            ? _value.transaction
            : transaction // ignore: cast_nullable_to_non_nullable
                  as BleTransaction,
        response: null == response
            ? _value.response
            : response // ignore: cast_nullable_to_non_nullable
                  as BleReceive,
        duration: null == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as Duration,
      ),
    );
  }
}

/// @nodoc

class _$BleTransactionSuccessImpl extends BleTransactionSuccess {
  const _$BleTransactionSuccessImpl({
    required this.transaction,
    required this.response,
    required this.duration,
  }) : super._();

  @override
  final BleTransaction transaction;
  @override
  final BleReceive response;
  @override
  final Duration duration;

  @override
  String toString() {
    return 'BleTransactionResult.success(transaction: $transaction, response: $response, duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BleTransactionSuccessImpl &&
            (identical(other.transaction, transaction) ||
                other.transaction == transaction) &&
            (identical(other.response, response) ||
                other.response == response) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, transaction, response, duration);

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BleTransactionSuccessImplCopyWith<_$BleTransactionSuccessImpl>
  get copyWith =>
      __$$BleTransactionSuccessImplCopyWithImpl<_$BleTransactionSuccessImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )
    success,
    required TResult Function(BleTransaction transaction, Duration duration)
    timeout,
    required TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )
    error,
  }) {
    return success(transaction, response, duration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult? Function(BleTransaction transaction, Duration duration)? timeout,
    TResult? Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
  }) {
    return success?.call(transaction, response, duration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult Function(BleTransaction transaction, Duration duration)? timeout,
    TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(transaction, response, duration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BleTransactionSuccess value) success,
    required TResult Function(BleTransactionTimeout value) timeout,
    required TResult Function(BleTransactionError value) error,
  }) {
    return success(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BleTransactionSuccess value)? success,
    TResult? Function(BleTransactionTimeout value)? timeout,
    TResult? Function(BleTransactionError value)? error,
  }) {
    return success?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BleTransactionSuccess value)? success,
    TResult Function(BleTransactionTimeout value)? timeout,
    TResult Function(BleTransactionError value)? error,
    required TResult orElse(),
  }) {
    if (success != null) {
      return success(this);
    }
    return orElse();
  }
}

abstract class BleTransactionSuccess extends BleTransactionResult {
  const factory BleTransactionSuccess({
    required final BleTransaction transaction,
    required final BleReceive response,
    required final Duration duration,
  }) = _$BleTransactionSuccessImpl;
  const BleTransactionSuccess._() : super._();

  @override
  BleTransaction get transaction;
  BleReceive get response;
  @override
  Duration get duration;

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BleTransactionSuccessImplCopyWith<_$BleTransactionSuccessImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BleTransactionTimeoutImplCopyWith<$Res>
    implements $BleTransactionResultCopyWith<$Res> {
  factory _$$BleTransactionTimeoutImplCopyWith(
    _$BleTransactionTimeoutImpl value,
    $Res Function(_$BleTransactionTimeoutImpl) then,
  ) = __$$BleTransactionTimeoutImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({BleTransaction transaction, Duration duration});

  @override
  $BleTransactionCopyWith<$Res> get transaction;
}

/// @nodoc
class __$$BleTransactionTimeoutImplCopyWithImpl<$Res>
    extends
        _$BleTransactionResultCopyWithImpl<$Res, _$BleTransactionTimeoutImpl>
    implements _$$BleTransactionTimeoutImplCopyWith<$Res> {
  __$$BleTransactionTimeoutImplCopyWithImpl(
    _$BleTransactionTimeoutImpl _value,
    $Res Function(_$BleTransactionTimeoutImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({Object? transaction = null, Object? duration = null}) {
    return _then(
      _$BleTransactionTimeoutImpl(
        transaction: null == transaction
            ? _value.transaction
            : transaction // ignore: cast_nullable_to_non_nullable
                  as BleTransaction,
        duration: null == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as Duration,
      ),
    );
  }
}

/// @nodoc

class _$BleTransactionTimeoutImpl extends BleTransactionTimeout {
  const _$BleTransactionTimeoutImpl({
    required this.transaction,
    required this.duration,
  }) : super._();

  @override
  final BleTransaction transaction;
  @override
  final Duration duration;

  @override
  String toString() {
    return 'BleTransactionResult.timeout(transaction: $transaction, duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BleTransactionTimeoutImpl &&
            (identical(other.transaction, transaction) ||
                other.transaction == transaction) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, transaction, duration);

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BleTransactionTimeoutImplCopyWith<_$BleTransactionTimeoutImpl>
  get copyWith =>
      __$$BleTransactionTimeoutImplCopyWithImpl<_$BleTransactionTimeoutImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )
    success,
    required TResult Function(BleTransaction transaction, Duration duration)
    timeout,
    required TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )
    error,
  }) {
    return timeout(transaction, duration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult? Function(BleTransaction transaction, Duration duration)? timeout,
    TResult? Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
  }) {
    return timeout?.call(transaction, duration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult Function(BleTransaction transaction, Duration duration)? timeout,
    TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
    required TResult orElse(),
  }) {
    if (timeout != null) {
      return timeout(transaction, duration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BleTransactionSuccess value) success,
    required TResult Function(BleTransactionTimeout value) timeout,
    required TResult Function(BleTransactionError value) error,
  }) {
    return timeout(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BleTransactionSuccess value)? success,
    TResult? Function(BleTransactionTimeout value)? timeout,
    TResult? Function(BleTransactionError value)? error,
  }) {
    return timeout?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BleTransactionSuccess value)? success,
    TResult Function(BleTransactionTimeout value)? timeout,
    TResult Function(BleTransactionError value)? error,
    required TResult orElse(),
  }) {
    if (timeout != null) {
      return timeout(this);
    }
    return orElse();
  }
}

abstract class BleTransactionTimeout extends BleTransactionResult {
  const factory BleTransactionTimeout({
    required final BleTransaction transaction,
    required final Duration duration,
  }) = _$BleTransactionTimeoutImpl;
  const BleTransactionTimeout._() : super._();

  @override
  BleTransaction get transaction;
  @override
  Duration get duration;

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BleTransactionTimeoutImplCopyWith<_$BleTransactionTimeoutImpl>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$BleTransactionErrorImplCopyWith<$Res>
    implements $BleTransactionResultCopyWith<$Res> {
  factory _$$BleTransactionErrorImplCopyWith(
    _$BleTransactionErrorImpl value,
    $Res Function(_$BleTransactionErrorImpl) then,
  ) = __$$BleTransactionErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({BleTransaction transaction, String error, Duration duration});

  @override
  $BleTransactionCopyWith<$Res> get transaction;
}

/// @nodoc
class __$$BleTransactionErrorImplCopyWithImpl<$Res>
    extends _$BleTransactionResultCopyWithImpl<$Res, _$BleTransactionErrorImpl>
    implements _$$BleTransactionErrorImplCopyWith<$Res> {
  __$$BleTransactionErrorImplCopyWithImpl(
    _$BleTransactionErrorImpl _value,
    $Res Function(_$BleTransactionErrorImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? transaction = null,
    Object? error = null,
    Object? duration = null,
  }) {
    return _then(
      _$BleTransactionErrorImpl(
        transaction: null == transaction
            ? _value.transaction
            : transaction // ignore: cast_nullable_to_non_nullable
                  as BleTransaction,
        error: null == error
            ? _value.error
            : error // ignore: cast_nullable_to_non_nullable
                  as String,
        duration: null == duration
            ? _value.duration
            : duration // ignore: cast_nullable_to_non_nullable
                  as Duration,
      ),
    );
  }
}

/// @nodoc

class _$BleTransactionErrorImpl extends BleTransactionError {
  const _$BleTransactionErrorImpl({
    required this.transaction,
    required this.error,
    required this.duration,
  }) : super._();

  @override
  final BleTransaction transaction;
  @override
  final String error;
  @override
  final Duration duration;

  @override
  String toString() {
    return 'BleTransactionResult.error(transaction: $transaction, error: $error, duration: $duration)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BleTransactionErrorImpl &&
            (identical(other.transaction, transaction) ||
                other.transaction == transaction) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.duration, duration) ||
                other.duration == duration));
  }

  @override
  int get hashCode => Object.hash(runtimeType, transaction, error, duration);

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BleTransactionErrorImplCopyWith<_$BleTransactionErrorImpl> get copyWith =>
      __$$BleTransactionErrorImplCopyWithImpl<_$BleTransactionErrorImpl>(
        this,
        _$identity,
      );

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )
    success,
    required TResult Function(BleTransaction transaction, Duration duration)
    timeout,
    required TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )
    error,
  }) {
    return error(transaction, this.error, duration);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult? Function(BleTransaction transaction, Duration duration)? timeout,
    TResult? Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
  }) {
    return error?.call(transaction, this.error, duration);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(
      BleTransaction transaction,
      BleReceive response,
      Duration duration,
    )?
    success,
    TResult Function(BleTransaction transaction, Duration duration)? timeout,
    TResult Function(
      BleTransaction transaction,
      String error,
      Duration duration,
    )?
    error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(transaction, this.error, duration);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BleTransactionSuccess value) success,
    required TResult Function(BleTransactionTimeout value) timeout,
    required TResult Function(BleTransactionError value) error,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BleTransactionSuccess value)? success,
    TResult? Function(BleTransactionTimeout value)? timeout,
    TResult? Function(BleTransactionError value)? error,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BleTransactionSuccess value)? success,
    TResult Function(BleTransactionTimeout value)? timeout,
    TResult Function(BleTransactionError value)? error,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class BleTransactionError extends BleTransactionResult {
  const factory BleTransactionError({
    required final BleTransaction transaction,
    required final String error,
    required final Duration duration,
  }) = _$BleTransactionErrorImpl;
  const BleTransactionError._() : super._();

  @override
  BleTransaction get transaction;
  String get error;
  @override
  Duration get duration;

  /// Create a copy of BleTransactionResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BleTransactionErrorImplCopyWith<_$BleTransactionErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
