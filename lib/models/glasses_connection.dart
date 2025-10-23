import 'package:freezed_annotation/freezed_annotation.dart';

part 'glasses_connection.freezed.dart';
part 'glasses_connection.g.dart';

/// Connection quality levels for BLE connection
enum ConnectionQuality {
  excellent,
  good,
  poor,
  disconnected,
}

/// Represents the current connection state with G1 glasses
@freezed
class GlassesConnection with _$GlassesConnection {
  const factory GlassesConnection({
    required bool isConnected,
    String? deviceName,
    String? leftGlassId,
    String? rightGlassId,
    @Default(0) int batteryLevel,
    @Default(ConnectionQuality.disconnected) ConnectionQuality quality,
    DateTime? connectedAt,
    DateTime? lastSeen,
  }) = _GlassesConnection;

  factory GlassesConnection.fromJson(Map<String, dynamic> json) =>
      _$GlassesConnectionFromJson(json);

  /// Factory for disconnected state
  factory GlassesConnection.disconnected() => const GlassesConnection(
        isConnected: false,
        quality: ConnectionQuality.disconnected,
      );

  /// Factory for connected state
  factory GlassesConnection.connected({
    required String deviceName,
    String? leftGlassId,
    String? rightGlassId,
  }) =>
      GlassesConnection(
        isConnected: true,
        deviceName: deviceName,
        leftGlassId: leftGlassId,
        rightGlassId: rightGlassId,
        quality: ConnectionQuality.excellent,
        connectedAt: DateTime.now(),
        lastSeen: DateTime.now(),
      );
}
