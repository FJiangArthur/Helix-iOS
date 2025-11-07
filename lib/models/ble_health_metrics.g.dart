// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ble_health_metrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BleHealthMetricsImpl _$$BleHealthMetricsImplFromJson(
  Map<String, dynamic> json,
) => _$BleHealthMetricsImpl(
  successCount: (json['successCount'] as num?)?.toInt() ?? 0,
  timeoutCount: (json['timeoutCount'] as num?)?.toInt() ?? 0,
  retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
  errorCount: (json['errorCount'] as num?)?.toInt() ?? 0,
  avgLatency: json['avgLatency'] == null
      ? Duration.zero
      : Duration(microseconds: (json['avgLatency'] as num).toInt()),
  totalLatency: json['totalLatency'] == null
      ? Duration.zero
      : Duration(microseconds: (json['totalLatency'] as num).toInt()),
);

Map<String, dynamic> _$$BleHealthMetricsImplToJson(
  _$BleHealthMetricsImpl instance,
) => <String, dynamic>{
  'successCount': instance.successCount,
  'timeoutCount': instance.timeoutCount,
  'retryCount': instance.retryCount,
  'errorCount': instance.errorCount,
  'avgLatency': instance.avgLatency.inMicroseconds,
  'totalLatency': instance.totalLatency.inMicroseconds,
};
