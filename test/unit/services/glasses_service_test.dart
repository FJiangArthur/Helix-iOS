// ABOUTME: Unit tests for GlassesService implementation
// ABOUTME: Tests basic functionality and error handling for smart glasses service

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'package:flutter_helix/services/implementations/glasses_service_impl.dart';
import 'package:flutter_helix/services/glasses_service.dart';
import 'package:flutter_helix/models/glasses_connection_state.dart';
import 'package:flutter_helix/core/utils/logging_service.dart';

// Generate mocks for this test
@GenerateMocks([LoggingService])
import 'glasses_service_test.mocks.dart';

void main() {
  group('GlassesService', () {
    late GlassesServiceImpl glassesService;
    late MockLoggingService mockLogger;
    
    setUp(() {
      mockLogger = MockLoggingService();
      glassesService = GlassesServiceImpl(logger: mockLogger);
    });
    
    tearDown(() {
      glassesService.dispose();
    });
    
    group('Initialization', () {
      test('should initialize with disconnected state', () {
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
        expect(glassesService.isConnected, isFalse);
        expect(glassesService.connectedDevice, isNull);
      });
      
      test('should check Bluetooth availability', () async {
        final isAvailable = await glassesService.isBluetoothAvailable();
        expect(isAvailable, isA<bool>());
      });
      
      test('should request Bluetooth permission', () async {
        final hasPermission = await glassesService.requestBluetoothPermission();
        expect(hasPermission, isA<bool>());
      });
    });
    
    group('Error Handling', () {
      test('should handle service not initialized error', () async {
        expect(
          () async => await glassesService.startScanning(),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should handle firmware update when not connected', () async {
        expect(
          () async => await glassesService.updateFirmware(),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should handle HUD commands when not connected', () async {
        expect(
          () async => await glassesService.displayText('Test'),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should handle disconnection', () async {
        await glassesService.disconnect();
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
    });
    
    group('Streams', () {
      test('should provide connection state stream', () {
        expect(glassesService.connectionStateStream, isA<Stream<ConnectionStatus>>());
      });
      
      test('should provide discovered devices stream', () {
        expect(glassesService.discoveredDevicesStream, isA<Stream<List<GlassesDevice>>>());
      });
      
      test('should provide gesture stream', () {
        expect(glassesService.gestureStream, isA<Stream<TouchGesture>>());
      });
      
      test('should provide device status stream', () {
        expect(glassesService.deviceStatusStream, isA<Stream<GlassesDeviceStatus>>());
      });
    });
    
    group('Resource Management', () {
      test('should dispose resources properly', () async {
        await glassesService.dispose();
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
    });
  });
}