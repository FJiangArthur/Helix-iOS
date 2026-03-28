// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ble_transaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BleTransaction {

 String get id; Uint8List get command; String get target;// 'L', 'R', or 'BOTH'
 Duration get timeout; int? get retryCount;
/// Create a copy of BleTransaction
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BleTransactionCopyWith<BleTransaction> get copyWith => _$BleTransactionCopyWithImpl<BleTransaction>(this as BleTransaction, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BleTransaction&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.command, command)&&(identical(other.target, target) || other.target == target)&&(identical(other.timeout, timeout) || other.timeout == timeout)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(command),target,timeout,retryCount);

@override
String toString() {
  return 'BleTransaction(id: $id, command: $command, target: $target, timeout: $timeout, retryCount: $retryCount)';
}


}

/// @nodoc
abstract mixin class $BleTransactionCopyWith<$Res>  {
  factory $BleTransactionCopyWith(BleTransaction value, $Res Function(BleTransaction) _then) = _$BleTransactionCopyWithImpl;
@useResult
$Res call({
 String id, Uint8List command, String target, Duration timeout, int? retryCount
});




}
/// @nodoc
class _$BleTransactionCopyWithImpl<$Res>
    implements $BleTransactionCopyWith<$Res> {
  _$BleTransactionCopyWithImpl(this._self, this._then);

  final BleTransaction _self;
  final $Res Function(BleTransaction) _then;

/// Create a copy of BleTransaction
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? command = null,Object? target = null,Object? timeout = null,Object? retryCount = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as Uint8List,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,timeout: null == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as Duration,retryCount: freezed == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [BleTransaction].
extension BleTransactionPatterns on BleTransaction {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BleTransaction value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BleTransaction() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BleTransaction value)  $default,){
final _that = this;
switch (_that) {
case _BleTransaction():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BleTransaction value)?  $default,){
final _that = this;
switch (_that) {
case _BleTransaction() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  Uint8List command,  String target,  Duration timeout,  int? retryCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BleTransaction() when $default != null:
return $default(_that.id,_that.command,_that.target,_that.timeout,_that.retryCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  Uint8List command,  String target,  Duration timeout,  int? retryCount)  $default,) {final _that = this;
switch (_that) {
case _BleTransaction():
return $default(_that.id,_that.command,_that.target,_that.timeout,_that.retryCount);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  Uint8List command,  String target,  Duration timeout,  int? retryCount)?  $default,) {final _that = this;
switch (_that) {
case _BleTransaction() when $default != null:
return $default(_that.id,_that.command,_that.target,_that.timeout,_that.retryCount);case _:
  return null;

}
}

}

/// @nodoc


class _BleTransaction extends BleTransaction {
  const _BleTransaction({required this.id, required this.command, required this.target, this.timeout = const Duration(milliseconds: 1000), this.retryCount}): super._();
  

@override final  String id;
@override final  Uint8List command;
@override final  String target;
// 'L', 'R', or 'BOTH'
@override@JsonKey() final  Duration timeout;
@override final  int? retryCount;

/// Create a copy of BleTransaction
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BleTransactionCopyWith<_BleTransaction> get copyWith => __$BleTransactionCopyWithImpl<_BleTransaction>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BleTransaction&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.command, command)&&(identical(other.target, target) || other.target == target)&&(identical(other.timeout, timeout) || other.timeout == timeout)&&(identical(other.retryCount, retryCount) || other.retryCount == retryCount));
}


@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(command),target,timeout,retryCount);

@override
String toString() {
  return 'BleTransaction(id: $id, command: $command, target: $target, timeout: $timeout, retryCount: $retryCount)';
}


}

/// @nodoc
abstract mixin class _$BleTransactionCopyWith<$Res> implements $BleTransactionCopyWith<$Res> {
  factory _$BleTransactionCopyWith(_BleTransaction value, $Res Function(_BleTransaction) _then) = __$BleTransactionCopyWithImpl;
@override @useResult
$Res call({
 String id, Uint8List command, String target, Duration timeout, int? retryCount
});




}
/// @nodoc
class __$BleTransactionCopyWithImpl<$Res>
    implements _$BleTransactionCopyWith<$Res> {
  __$BleTransactionCopyWithImpl(this._self, this._then);

  final _BleTransaction _self;
  final $Res Function(_BleTransaction) _then;

/// Create a copy of BleTransaction
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? command = null,Object? target = null,Object? timeout = null,Object? retryCount = freezed,}) {
  return _then(_BleTransaction(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,command: null == command ? _self.command : command // ignore: cast_nullable_to_non_nullable
as Uint8List,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,timeout: null == timeout ? _self.timeout : timeout // ignore: cast_nullable_to_non_nullable
as Duration,retryCount: freezed == retryCount ? _self.retryCount : retryCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$BleTransactionResult {

 BleTransaction get transaction; Duration get duration;
/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BleTransactionResultCopyWith<BleTransactionResult> get copyWith => _$BleTransactionResultCopyWithImpl<BleTransactionResult>(this as BleTransactionResult, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BleTransactionResult&&(identical(other.transaction, transaction) || other.transaction == transaction)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,transaction,duration);

@override
String toString() {
  return 'BleTransactionResult(transaction: $transaction, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $BleTransactionResultCopyWith<$Res>  {
  factory $BleTransactionResultCopyWith(BleTransactionResult value, $Res Function(BleTransactionResult) _then) = _$BleTransactionResultCopyWithImpl;
@useResult
$Res call({
 BleTransaction transaction, Duration duration
});


$BleTransactionCopyWith<$Res> get transaction;

}
/// @nodoc
class _$BleTransactionResultCopyWithImpl<$Res>
    implements $BleTransactionResultCopyWith<$Res> {
  _$BleTransactionResultCopyWithImpl(this._self, this._then);

  final BleTransactionResult _self;
  final $Res Function(BleTransactionResult) _then;

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? transaction = null,Object? duration = null,}) {
  return _then(_self.copyWith(
transaction: null == transaction ? _self.transaction : transaction // ignore: cast_nullable_to_non_nullable
as BleTransaction,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}
/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BleTransactionCopyWith<$Res> get transaction {
  
  return $BleTransactionCopyWith<$Res>(_self.transaction, (value) {
    return _then(_self.copyWith(transaction: value));
  });
}
}


/// Adds pattern-matching-related methods to [BleTransactionResult].
extension BleTransactionResultPatterns on BleTransactionResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BleTransactionSuccess value)?  success,TResult Function( BleTransactionTimeout value)?  timeout,TResult Function( BleTransactionError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BleTransactionSuccess() when success != null:
return success(_that);case BleTransactionTimeout() when timeout != null:
return timeout(_that);case BleTransactionError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BleTransactionSuccess value)  success,required TResult Function( BleTransactionTimeout value)  timeout,required TResult Function( BleTransactionError value)  error,}){
final _that = this;
switch (_that) {
case BleTransactionSuccess():
return success(_that);case BleTransactionTimeout():
return timeout(_that);case BleTransactionError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BleTransactionSuccess value)?  success,TResult? Function( BleTransactionTimeout value)?  timeout,TResult? Function( BleTransactionError value)?  error,}){
final _that = this;
switch (_that) {
case BleTransactionSuccess() when success != null:
return success(_that);case BleTransactionTimeout() when timeout != null:
return timeout(_that);case BleTransactionError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BleTransaction transaction,  BleReceive response,  Duration duration)?  success,TResult Function( BleTransaction transaction,  Duration duration)?  timeout,TResult Function( BleTransaction transaction,  String error,  Duration duration)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BleTransactionSuccess() when success != null:
return success(_that.transaction,_that.response,_that.duration);case BleTransactionTimeout() when timeout != null:
return timeout(_that.transaction,_that.duration);case BleTransactionError() when error != null:
return error(_that.transaction,_that.error,_that.duration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BleTransaction transaction,  BleReceive response,  Duration duration)  success,required TResult Function( BleTransaction transaction,  Duration duration)  timeout,required TResult Function( BleTransaction transaction,  String error,  Duration duration)  error,}) {final _that = this;
switch (_that) {
case BleTransactionSuccess():
return success(_that.transaction,_that.response,_that.duration);case BleTransactionTimeout():
return timeout(_that.transaction,_that.duration);case BleTransactionError():
return error(_that.transaction,_that.error,_that.duration);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BleTransaction transaction,  BleReceive response,  Duration duration)?  success,TResult? Function( BleTransaction transaction,  Duration duration)?  timeout,TResult? Function( BleTransaction transaction,  String error,  Duration duration)?  error,}) {final _that = this;
switch (_that) {
case BleTransactionSuccess() when success != null:
return success(_that.transaction,_that.response,_that.duration);case BleTransactionTimeout() when timeout != null:
return timeout(_that.transaction,_that.duration);case BleTransactionError() when error != null:
return error(_that.transaction,_that.error,_that.duration);case _:
  return null;

}
}

}

/// @nodoc


class BleTransactionSuccess extends BleTransactionResult {
  const BleTransactionSuccess({required this.transaction, required this.response, required this.duration}): super._();
  

@override final  BleTransaction transaction;
 final  BleReceive response;
@override final  Duration duration;

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BleTransactionSuccessCopyWith<BleTransactionSuccess> get copyWith => _$BleTransactionSuccessCopyWithImpl<BleTransactionSuccess>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BleTransactionSuccess&&(identical(other.transaction, transaction) || other.transaction == transaction)&&(identical(other.response, response) || other.response == response)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,transaction,response,duration);

@override
String toString() {
  return 'BleTransactionResult.success(transaction: $transaction, response: $response, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $BleTransactionSuccessCopyWith<$Res> implements $BleTransactionResultCopyWith<$Res> {
  factory $BleTransactionSuccessCopyWith(BleTransactionSuccess value, $Res Function(BleTransactionSuccess) _then) = _$BleTransactionSuccessCopyWithImpl;
@override @useResult
$Res call({
 BleTransaction transaction, BleReceive response, Duration duration
});


@override $BleTransactionCopyWith<$Res> get transaction;

}
/// @nodoc
class _$BleTransactionSuccessCopyWithImpl<$Res>
    implements $BleTransactionSuccessCopyWith<$Res> {
  _$BleTransactionSuccessCopyWithImpl(this._self, this._then);

  final BleTransactionSuccess _self;
  final $Res Function(BleTransactionSuccess) _then;

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? transaction = null,Object? response = null,Object? duration = null,}) {
  return _then(BleTransactionSuccess(
transaction: null == transaction ? _self.transaction : transaction // ignore: cast_nullable_to_non_nullable
as BleTransaction,response: null == response ? _self.response : response // ignore: cast_nullable_to_non_nullable
as BleReceive,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BleTransactionCopyWith<$Res> get transaction {
  
  return $BleTransactionCopyWith<$Res>(_self.transaction, (value) {
    return _then(_self.copyWith(transaction: value));
  });
}
}

/// @nodoc


class BleTransactionTimeout extends BleTransactionResult {
  const BleTransactionTimeout({required this.transaction, required this.duration}): super._();
  

@override final  BleTransaction transaction;
@override final  Duration duration;

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BleTransactionTimeoutCopyWith<BleTransactionTimeout> get copyWith => _$BleTransactionTimeoutCopyWithImpl<BleTransactionTimeout>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BleTransactionTimeout&&(identical(other.transaction, transaction) || other.transaction == transaction)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,transaction,duration);

@override
String toString() {
  return 'BleTransactionResult.timeout(transaction: $transaction, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $BleTransactionTimeoutCopyWith<$Res> implements $BleTransactionResultCopyWith<$Res> {
  factory $BleTransactionTimeoutCopyWith(BleTransactionTimeout value, $Res Function(BleTransactionTimeout) _then) = _$BleTransactionTimeoutCopyWithImpl;
@override @useResult
$Res call({
 BleTransaction transaction, Duration duration
});


@override $BleTransactionCopyWith<$Res> get transaction;

}
/// @nodoc
class _$BleTransactionTimeoutCopyWithImpl<$Res>
    implements $BleTransactionTimeoutCopyWith<$Res> {
  _$BleTransactionTimeoutCopyWithImpl(this._self, this._then);

  final BleTransactionTimeout _self;
  final $Res Function(BleTransactionTimeout) _then;

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? transaction = null,Object? duration = null,}) {
  return _then(BleTransactionTimeout(
transaction: null == transaction ? _self.transaction : transaction // ignore: cast_nullable_to_non_nullable
as BleTransaction,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BleTransactionCopyWith<$Res> get transaction {
  
  return $BleTransactionCopyWith<$Res>(_self.transaction, (value) {
    return _then(_self.copyWith(transaction: value));
  });
}
}

/// @nodoc


class BleTransactionError extends BleTransactionResult {
  const BleTransactionError({required this.transaction, required this.error, required this.duration}): super._();
  

@override final  BleTransaction transaction;
 final  String error;
@override final  Duration duration;

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BleTransactionErrorCopyWith<BleTransactionError> get copyWith => _$BleTransactionErrorCopyWithImpl<BleTransactionError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BleTransactionError&&(identical(other.transaction, transaction) || other.transaction == transaction)&&(identical(other.error, error) || other.error == error)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode => Object.hash(runtimeType,transaction,error,duration);

@override
String toString() {
  return 'BleTransactionResult.error(transaction: $transaction, error: $error, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $BleTransactionErrorCopyWith<$Res> implements $BleTransactionResultCopyWith<$Res> {
  factory $BleTransactionErrorCopyWith(BleTransactionError value, $Res Function(BleTransactionError) _then) = _$BleTransactionErrorCopyWithImpl;
@override @useResult
$Res call({
 BleTransaction transaction, String error, Duration duration
});


@override $BleTransactionCopyWith<$Res> get transaction;

}
/// @nodoc
class _$BleTransactionErrorCopyWithImpl<$Res>
    implements $BleTransactionErrorCopyWith<$Res> {
  _$BleTransactionErrorCopyWithImpl(this._self, this._then);

  final BleTransactionError _self;
  final $Res Function(BleTransactionError) _then;

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? transaction = null,Object? error = null,Object? duration = null,}) {
  return _then(BleTransactionError(
transaction: null == transaction ? _self.transaction : transaction // ignore: cast_nullable_to_non_nullable
as BleTransaction,error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String,duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

/// Create a copy of BleTransactionResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BleTransactionCopyWith<$Res> get transaction {
  
  return $BleTransactionCopyWith<$Res>(_self.transaction, (value) {
    return _then(_self.copyWith(transaction: value));
  });
}
}

// dart format on
