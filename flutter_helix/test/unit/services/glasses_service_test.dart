// ABOUTME: Unit tests for GlassesService implementation
// ABOUTME: Tests basic functionality and error handling for smart glasses service

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:flutter_helix/services/implementations/glasses_service_impl.dart';
import 'package:flutter_helix/services/glasses_service.dart';
import 'package:flutter_helix/models/glasses_connection_state.dart';
import 'package:flutter_helix/core/utils/logging_service.dart';
import '../../test_helpers.dart';

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
    
    group('Device Discovery', () {
      test('should initialize before scanning', () async {
        await glassesService.initialize();
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
      
      test('should handle scanning timeout', () async {
        await glassesService.initialize();
        
        // Start scanning with short timeout
        await glassesService.startScanning(timeout: Duration(seconds: 1));
        
        // Should eventually return to disconnected state
        await Future.delayed(Duration(seconds: 2));
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
      
      test('should stop scanning', () async {
        await glassesService.initialize();
        await glassesService.startScanning();
        
        await glassesService.stopScanning();
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
    });
    
    group('Connection Management', () {
      test('should handle connection to non-existent device', () async {
        await glassesService.initialize();
        
        expect(
          () async => await glassesService.connectToDevice('non-existent-device'),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should handle disconnection', () async {
        await glassesService.disconnect();
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
      
      test('should provide connection state stream', () {
        expect(glassesService.connectionStateStream, isA<Stream<ConnectionStatus>>());
      });
      
      test('should provide discovered devices stream', () {
        expect(glassesService.discoveredDevicesStream, isA<Stream<List<GlassesDevice>>>());
      });
    });
    
    group('HUD Control', () {
      test('should reject HUD commands when not connected', () async {
        expect(
          () async => await glassesService.displayText('Test'),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should reject brightness setting when not connected', () async {
        expect(
          () async => await glassesService.setBrightness(0.5),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should reject clear display when not connected', () async {
        expect(
          () async => await glassesService.clearDisplay(),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should reject notifications when not connected', () async {
        expect(
          () async => await glassesService.displayNotification('Title', 'Message'),
          throwsA(isA<Exception>()),
        );
      });
    });
    
    group('Device Information', () {
      test('should reject device info requests when not connected', () async {
        expect(
          () async => await glassesService.getDeviceInfo(),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should reject battery level requests when not connected', () async {
        expect(
          () async => await glassesService.getBatteryLevel(),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should reject health check when not connected', () async {
        expect(
          () async => await glassesService.checkDeviceHealth(),
          throwsA(isA<Exception>()),
        );
      });
    });
    
    group('Error Handling', () {
      test('should handle service not initialized error', () async {
        expect(
          () async => await glassesService.startScanning(),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should handle firmware update not implemented', () async {
        expect(
          () async => await glassesService.updateFirmware(),
          throwsA(isA<UnimplementedError>()),
        );
      });
      
      test('should handle gesture configuration when not connected', () async {
        expect(
          () async => await glassesService.configureGestures(),
          throwsA(isA<Exception>()),
        );
      });
      
      test('should handle custom commands when not connected', () async {
        expect(
          () async => await glassesService.sendCommand('test'),
          throwsA(isA<Exception>()),
        );
      });
    });
    
    group('Resource Management', () {
      test('should dispose resources properly', () async {
        await glassesService.initialize();
        await glassesService.dispose();
        
        // After disposal, service should be in disconnected state
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
      
      test('should handle multiple dispose calls safely', () async {
        await glassesService.dispose();
        await glassesService.dispose();
        
        // Should not throw exception
        expect(glassesService.connectionState, equals(ConnectionStatus.disconnected));
      });
    });
    
    group('Streams', () {
      test('should provide gesture stream', () {
        expect(glassesService.gestureStream, isA<Stream<TouchGesture>>());
      });
      
      test('should provide device status stream', () {
        expect(glassesService.deviceStatusStream, isA<Stream<GlassesDeviceStatus>>());
      });
    });
  });
}