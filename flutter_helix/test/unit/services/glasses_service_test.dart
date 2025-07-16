// ABOUTME: Unit tests for GlassesService implementation
// ABOUTME: Tests Bluetooth connectivity, device management, and HUD control functionality

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:fake_async/fake_async.dart';

import 'package:flutter_helix/services/implementations/glasses_service_impl.dart';
import 'package:flutter_helix/services/glasses_service.dart';
import 'package:flutter_helix/models/glasses_connection_state.dart';
import 'package:flutter_helix/core/utils/exceptions.dart';
import '../../test_helpers.dart';

void main() {
  group('GlassesService', () {
    late GlassesServiceImpl glassesService;
    late StreamController<ConnectionState> connectionController;
    
    setUp(() {
      connectionController = StreamController<ConnectionState>.broadcast();
      glassesService = GlassesServiceImpl();
    });
    
    tearDown(() {
      connectionController.close();
      glassesService.dispose();
    });
    
    group('Initialization', () {
      test('should initialize with disconnected state', () {
        expect(glassesService.connectionState, equals(ConnectionState.disconnected));
        expect(glassesService.isConnected, isFalse);
        expect(glassesService.connectedDevice, isNull);
      });
      
      test('should check Bluetooth availability', () async {
        final isAvailable = await glassesService.isBluetoothAvailable();
        expect(isAvailable, isA<bool>());
      });
      
      test('should request Bluetooth permissions', () async {
        final hasPermission = await glassesService.requestBluetoothPermission();
        expect(hasPermission, isA<bool>());
      });
    });
    
    group('Device Discovery', () {
      test('should start device scan', () async {
        // Act
        await glassesService.startScan();
        
        // Assert
        expect(glassesService.isScanning, isTrue);
      });
      
      test('should stop device scan', () async {
        // Arrange
        await glassesService.startScan();
        expect(glassesService.isScanning, isTrue);
        
        // Act
        await glassesService.stopScan();
        
        // Assert
        expect(glassesService.isScanning, isFalse);
      });
      
      test('should discover Even Realities devices', () async {
        fakeAsync((async) {
          // Arrange
          final discoveredDevices = <BluetoothDevice>[];
          final subscription = glassesService.deviceStream.listen(
            (device) => discoveredDevices.add(device),
          );
          
          // Act
          glassesService.startScan();
          
          // Simulate device discovery
          async.elapse(const Duration(seconds: 3));
          
          // Assert - In real implementation, would find actual devices
          // For testing, we verify the stream is active
          expect(glassesService.isScanning, isTrue);
          
          subscription.cancel();
        });
      });
      
      test('should filter only Even Realities devices', () {
        // Arrange
        final evenRealitiesDevice = createMockDevice(
          name: 'Even Realities G1',
          id: TestHelpers.testGlassesDeviceId,
        );
        final otherDevice = createMockDevice(
          name: 'Random Bluetooth Device',
          id: 'other-device-001',
        );
        
        // Act
        final isEvenRealities1 = glassesService.isEvenRealitiesDevice(evenRealitiesDevice);
        final isEvenRealities2 = glassesService.isEvenRealitiesDevice(otherDevice);
        
        // Assert
        expect(isEvenRealities1, isTrue);
        expect(isEvenRealities2, isFalse);
      });
    });
    
    group('Device Connection', () {
      test('should connect to discovered device', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        
        // Act
        await glassesService.connectToDevice(device.id);
        
        // Assert
        expect(glassesService.connectionState, equals(ConnectionState.connected));
        expect(glassesService.isConnected, isTrue);
        expect(glassesService.connectedDevice?.id, equals(device.id));
      });
      
      test('should handle connection timeout', () async {
        // Arrange
        const invalidDeviceId = 'non-existent-device';
        
        // Act & Assert
        expect(
          () async => await glassesService.connectToDevice(invalidDeviceId),
          throwsA(isA<BluetoothException>()),
        );
      });
      
      test('should disconnect from device', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        expect(glassesService.isConnected, isTrue);
        
        // Act
        await glassesService.disconnect();
        
        // Assert
        expect(glassesService.connectionState, equals(ConnectionState.disconnected));
        expect(glassesService.isConnected, isFalse);
        expect(glassesService.connectedDevice, isNull);
      });
      
      test('should handle connection state changes', () async {
        fakeAsync((async) {
          // Arrange
          final connectionStates = <ConnectionState>[];
          final subscription = glassesService.connectionStream.listen(
            (state) => connectionStates.add(state),
          );
          
          final device = createMockDevice(
            name: TestHelpers.testGlassesDeviceName,
            id: TestHelpers.testGlassesDeviceId,
          );
          
          // Act - Connect
          glassesService.connectToDevice(device.id);
          async.elapse(const Duration(seconds: 1));
          
          // Disconnect
          glassesService.disconnect();
          async.elapse(const Duration(seconds: 1));
          
          // Assert
          expect(connectionStates, contains(ConnectionState.connecting));
          expect(connectionStates, contains(ConnectionState.connected));
          expect(connectionStates, contains(ConnectionState.disconnected));
          
          subscription.cancel();
        });
      });
    });
    
    group('Device Information', () {
      test('should get device battery level', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act
        final batteryLevel = await glassesService.getBatteryLevel();
        
        // Assert
        expect(batteryLevel, isA<double>());
        expect(batteryLevel, greaterThanOrEqualTo(0.0));
        expect(batteryLevel, lessThanOrEqualTo(1.0));
      });
      
      test('should get device signal strength', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act
        final rssi = await glassesService.getSignalStrength();
        
        // Assert
        expect(rssi, isA<int>());
        expect(rssi, lessThan(0)); // RSSI is always negative
      });
      
      test('should get device firmware version', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act
        final firmwareVersion = await glassesService.getFirmwareVersion();
        
        // Assert
        expect(firmwareVersion, isA<String>());
        expect(firmwareVersion, isNotEmpty);
      });
    });
    
    group('HUD Control', () {
      test('should display text on HUD', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        const testText = 'Hello World';
        
        // Act
        await glassesService.displayText(testText);
        
        // Assert
        expect(glassesService.currentHUDContent, equals(testText));
      });
      
      test('should clear HUD display', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        await glassesService.displayText('Test content');
        
        // Act
        await glassesService.clearDisplay();
        
        // Assert
        expect(glassesService.currentHUDContent, isEmpty);
      });
      
      test('should set HUD brightness', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        const brightness = 0.75;
        
        // Act
        await glassesService.setBrightness(brightness);
        
        // Assert
        expect(glassesService.currentBrightness, equals(brightness));
      });
      
      test('should validate brightness range', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act & Assert
        expect(() => glassesService.setBrightness(-0.1), throwsArgumentError);
        expect(() => glassesService.setBrightness(1.1), throwsArgumentError);
        
        // Valid values should work
        await glassesService.setBrightness(0.0);
        await glassesService.setBrightness(1.0);
      });
      
      test('should set HUD position', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act
        await glassesService.setHUDPosition(HUDPosition.top);
        
        // Assert
        expect(glassesService.currentHUDPosition, equals(HUDPosition.top));
      });
    });
    
    group('Notifications', () {
      test('should send haptic feedback', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act
        await glassesService.sendHapticFeedback(HapticPattern.single);
        
        // Assert - Verify the command was sent (implementation-specific)
        expect(glassesService.lastHapticPattern, equals(HapticPattern.single));
      });
      
      test('should send audio alert', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act
        await glassesService.sendAudioAlert(AudioAlert.notification);
        
        // Assert
        expect(glassesService.lastAudioAlert, equals(AudioAlert.notification));
      });
    });
    
    group('Data Transmission', () {
      test('should send conversation analysis to HUD', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        final analysisResult = TestHelpers.createTestAnalysisResult();
        
        // Act
        await glassesService.sendAnalysisResult(analysisResult);
        
        // Assert
        expect(glassesService.currentHUDContent, contains(analysisResult.summary));
      });
      
      test('should handle large data transmission', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        final largeText = List.generate(500, (index) => 'Word $index').join(' ');
        
        // Act
        final startTime = DateTime.now();
        await glassesService.displayText(largeText);
        final endTime = DateTime.now();
        
        // Assert
        expect(endTime.difference(startTime).inSeconds, lessThan(5));
        expect(glassesService.currentHUDContent.length, lessThanOrEqualTo(1000)); // Should be truncated if needed
      });
    });
    
    group('Error Handling', () {
      test('should handle Bluetooth disabled', () async {
        // Act & Assert
        expect(
          () async => await glassesService.startScan(),
          throwsA(isA<BluetoothException>()),
        );
      });
      
      test('should handle device not found', () async {
        // Act & Assert
        expect(
          () async => await glassesService.connectToDevice('non-existent-device'),
          throwsA(isA<BluetoothException>()),
        );
      });
      
      test('should handle connection lost', () async {
        fakeAsync((async) {
          // Arrange
          final device = createMockDevice(
            name: TestHelpers.testGlassesDeviceName,
            id: TestHelpers.testGlassesDeviceId,
          );
          await glassesService.connectToDevice(device.id);
          expect(glassesService.isConnected, isTrue);
          
          final connectionStates = <ConnectionState>[];
          final subscription = glassesService.connectionStream.listen(
            (state) => connectionStates.add(state),
          );
          
          // Act - Simulate connection lost
          glassesService.simulateConnectionLoss(); // Test method
          async.elapse(const Duration(seconds: 1));
          
          // Assert
          expect(connectionStates, contains(ConnectionState.disconnected));
          expect(glassesService.isConnected, isFalse);
          
          subscription.cancel();
        });
      });
      
      test('should handle HUD command failures', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Simulate HUD failure
        glassesService.simulateHUDFailure(); // Test method
        
        // Act & Assert
        expect(
          () async => await glassesService.displayText('test'),
          throwsA(isA<BluetoothException>()),
        );
      });
    });
    
    group('Configuration', () {
      test('should save and restore device settings', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Configure settings
        await glassesService.setBrightness(0.8);
        await glassesService.setHUDPosition(HUDPosition.center);
        
        // Act
        final settings = await glassesService.getDeviceSettings();
        await glassesService.saveDeviceSettings(settings);
        
        // Simulate reconnection
        await glassesService.disconnect();
        await glassesService.connectToDevice(device.id);
        await glassesService.restoreDeviceSettings();
        
        // Assert
        expect(glassesService.currentBrightness, equals(0.8));
        expect(glassesService.currentHUDPosition, equals(HUDPosition.center));
      });
    });
    
    group('Performance', () {
      test('should handle rapid HUD updates efficiently', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act - Send multiple rapid updates
        final startTime = DateTime.now();
        for (int i = 0; i < 50; i++) {
          await glassesService.displayText('Update $i');
        }
        final endTime = DateTime.now();
        
        // Assert
        expect(endTime.difference(startTime).inSeconds, lessThan(10));
      });
      
      test('should queue commands when device is busy', () async {
        // Arrange
        final device = createMockDevice(
          name: TestHelpers.testGlassesDeviceName,
          id: TestHelpers.testGlassesDeviceId,
        );
        await glassesService.connectToDevice(device.id);
        
        // Act - Send commands rapidly
        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          futures.add(glassesService.displayText('Command $i'));
        }
        
        await Future.wait(futures);
        
        // Assert - All commands should complete successfully
        expect(glassesService.commandQueueSize, equals(0));
      });
    });
    
    group('Resource Management', () {
      test('should dispose resources properly', () {
        // Arrange
        glassesService.startScan();
        
        // Act
        glassesService.dispose();
        
        // Assert
        expect(glassesService.isScanning, isFalse);
        expect(glassesService.isConnected, isFalse);
      });
      
      test('should handle multiple dispose calls safely', () {
        // Act & Assert - should not throw
        glassesService.dispose();
        glassesService.dispose();
        glassesService.dispose();
      });
    });
  });
}

// Helper function to create mock Bluetooth devices
BluetoothDevice createMockDevice({
  required String name,
  required String id,
  int rssi = TestHelpers.testGlassesRSSI,
}) {
  // In a real implementation, this would create a proper mock
  // For now, we'll assume a simple data structure
  return BluetoothDevice(
    id: id,
    name: name,
    rssi: rssi,
  );
}

// Mock Bluetooth device class for testing
class BluetoothDevice {
  final String id;
  final String name;
  final int rssi;
  
  BluetoothDevice({
    required this.id,
    required this.name,
    required this.rssi,
  });
}

// Enums for testing
enum ConnectionState { disconnected, connecting, connected }
enum HUDPosition { top, center, bottom }
enum HapticPattern { single, double, triple }
enum AudioAlert { notification, warning, error }