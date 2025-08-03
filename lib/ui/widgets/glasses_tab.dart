// ABOUTME: Enhanced glasses tab with connection management and HUD controls
// ABOUTME: Manages Even Realities smart glasses connection, battery, and display controls

import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math';

import '../../services/glasses_service.dart' as service;
import '../../services/implementations/even_realities_glasses_service.dart';
import '../../services/service_locator.dart';
import '../../core/utils/logging_service.dart';
import '../../models/glasses_connection_state.dart';

class GlassesTab extends StatefulWidget {
  const GlassesTab({super.key});

  @override
  State<GlassesTab> createState() => _GlassesTabState();
}

class _GlassesTabState extends State<GlassesTab> with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  
  // Even Realities glasses service
  late EvenRealitiesGlassesService _glassesService;
  
  GlassesConnectionStatus _connectionStatus = GlassesConnectionStatus.disconnected;
  bool _isScanning = false;
  double _batteryLevel = 0.85;
  double _brightness = 0.7;
  bool _isHUDEnabled = true;
  
  // Testing controls
  final TextEditingController _testTextController = TextEditingController();
  
  final List<DiscoveredDevice> _discoveredDevices = [
    DiscoveredDevice(
      id: 'even_realities_001',
      name: 'Even Realities G1',
      rssi: -45,
      batteryLevel: 0.85,
    ),
    DiscoveredDevice(
      id: 'even_realities_002', 
      name: 'Even Realities G1 Pro',
      rssi: -62,
      batteryLevel: 0.92,
    ),
  ];
  
  String? _connectedDeviceId;
  String _lastSyncTime = '2 minutes ago';
  
  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Initialize Even Realities glasses service
    _initializeGlassesService();
    
    // Set initial test text
    _testTextController.text = 'Hello Even Realities!';
  }

  Future<void> _initializeGlassesService() async {
    try {
      final logger = ServiceLocator.instance.get<LoggingService>();
      _glassesService = EvenRealitiesGlassesService(logger: logger);
      await _glassesService.initialize();
      
      // Listen to connection state changes
      _glassesService.connectionStateStream.listen((status) {
        if (mounted) {
          setState(() {
            _connectionStatus = _mapConnectionStatus(status);
          });
        }
      });
      
      // Listen to discovered devices
      _glassesService.discoveredDevicesStream.listen((devices) {
        if (mounted) {
          setState(() {
            _discoveredDevices.clear();
            for (final device in devices) {
              _discoveredDevices.add(DiscoveredDevice(
                id: device.id,
                name: device.name,
                rssi: device.signalStrength,
                batteryLevel: 0.85, // Default battery level
              ));
            }
          });
        }
      });
      
    } catch (e) {
      debugPrint('Failed to initialize glasses service: $e');
    }
  }
  
  GlassesConnectionStatus _mapConnectionStatus(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return GlassesConnectionStatus.connected;
      case ConnectionStatus.connecting:
        return GlassesConnectionStatus.connecting;
      case ConnectionStatus.disconnected:
        return GlassesConnectionStatus.disconnected;
      default:
        return GlassesConnectionStatus.disconnected;
    }
  }
  
  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _testTextController.dispose();
    _glassesService.dispose();
    super.dispose();
  }

  // Even Realities Testing Methods
  Future<void> _displayDeviceInfo() async {
    try {
      final connectedDevice = _discoveredDevices.firstWhere(
        (device) => device.id == _connectedDeviceId,
        orElse: () => _discoveredDevices.first,
      );
      
      final infoText = 'Device: ${connectedDevice.name}\nBattery: ${(_batteryLevel * 100).round()}%\nSignal: ${connectedDevice.rssi} dBm';
      await _glassesService.displayText(infoText);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device info displayed on glasses')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to display info: $e')),
      );
    }
  }

  Future<void> _clearDisplay() async {
    try {
      await _glassesService.clearDisplay();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear display: $e')),
      );
    }
  }

  Future<void> _showTestAlert() async {
    try {
      await _glassesService.displayNotification(
        'Test Alert',
        'This is a test notification on your Even Realities glasses!',
        priority: service.NotificationPriority.normal,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test alert sent to glasses')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to show alert: $e')),
      );
    }
  }

  Future<void> _displayCustomText() async {
    if (_testTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text to display')),
      );
      return;
    }

    try {
      await _glassesService.displayText(_testTextController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Custom text displayed on glasses')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to display text: $e')),
      );
    }
  }

  Future<void> _displayTestBitmap() async {
    try {
      // Create a simple test bitmap (64x32 pixels)
      final bitmap = _generateTestBitmap();
      await _glassesService.displayBitmap(bitmap);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test image displayed on glasses')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to display image: $e')),
      );
    }
  }

  Future<void> _displayProgressAnimation() async {
    try {
      for (int i = 0; i <= 10; i++) {
        final progressText = 'Progress: ${'█' * i}${'░' * (10 - i)} ${i * 10}%';
        await _glassesService.displayText(progressText);
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress animation completed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Animation failed: $e')),
      );
    }
  }

  Uint8List _generateTestBitmap() {
    // Generate a simple test pattern - checkered pattern
    const width = 64;
    const height = 32;
    final bitmap = Uint8List(width * height ~/ 8); // 1 bit per pixel
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixelIndex = y * width + x;
        final byteIndex = pixelIndex ~/ 8;
        final bitIndex = pixelIndex % 8;
        
        // Create checkerboard pattern
        if ((x ~/ 8 + y ~/ 8) % 2 == 0) {
          bitmap[byteIndex] |= (1 << (7 - bitIndex));
        }
      }
    }
    
    return bitmap;
  }
  
  Future<void> _startScanning() async {
    setState(() {
      _isScanning = true;
    });
    _scanController.repeat();
    
    try {
      await _glassesService.startScanning(timeout: const Duration(seconds: 30));
      
      // Stop scanning after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (mounted && _isScanning) {
          _stopScanning();
        }
      });
    } catch (e) {
      debugPrint('Failed to start scanning: $e');
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
        _scanController.stop();
      }
    }
  }
  
  Future<void> _stopScanning() async {
    try {
      await _glassesService.stopScanning();
    } catch (e) {
      debugPrint('Failed to stop scanning: $e');
    }
    
    if (mounted) {
      setState(() {
        _isScanning = false;
      });
      _scanController.stop();
    }
  }
  
  Future<void> _connectToDevice(DiscoveredDevice device) async {
    setState(() {
      _connectionStatus = GlassesConnectionStatus.connecting;
    });
    
    _pulseController.repeat();
    
    try {
      await _glassesService.connectToDevice(device.id);
      _connectedDeviceId = device.id;
      _batteryLevel = device.batteryLevel;
      _pulseController.stop();
    } catch (e) {
      debugPrint('Failed to connect to device: $e');
      if (mounted) {
        setState(() {
          _connectionStatus = GlassesConnectionStatus.disconnected;
        });
        _pulseController.stop();
      }
    }
  }
  
  Future<void> _disconnect() async {
    try {
      await _glassesService.disconnect();
      _connectedDeviceId = null;
    } catch (e) {
      debugPrint('Failed to disconnect: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Glasses'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog(context);
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'calibrate':
                  _showCalibrationDialog(context);
                  break;
                case 'reset':
                  _showResetDialog(context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'calibrate',
                child: Row(
                  children: [
                    Icon(Icons.tune),
                    SizedBox(width: 8),
                    Text('Calibrate Display'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Reset Connection'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionCard(theme),
            const SizedBox(height: 16),
            if (_connectionStatus == GlassesConnectionStatus.connected) ...[
              _buildHUDControlCard(theme),
              const SizedBox(height: 16),
              _buildDeviceInfoCard(theme),
              const SizedBox(height: 16),
            ],
            if (_connectionStatus == GlassesConnectionStatus.disconnected)
              _buildDeviceDiscoveryCard(theme),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionCard(ThemeData theme) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusSubtitle;
    
    switch (_connectionStatus) {
      case GlassesConnectionStatus.connected:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Connected';
        statusSubtitle = 'Even Realities G1 • Last sync: $_lastSyncTime';
        break;
      case GlassesConnectionStatus.connecting:
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
        statusText = 'Connecting...';
        statusSubtitle = 'Establishing secure connection';
        break;
      case GlassesConnectionStatus.disconnected:
        statusColor = Colors.grey;
        statusIcon = Icons.bluetooth_disabled;
        statusText = 'Disconnected';
        statusSubtitle = 'No glasses connected';
        break;
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _connectionStatus == GlassesConnectionStatus.connecting 
                    ? _pulseController : const AlwaysStoppedAnimation(0),
                  builder: (context, child) {
                    return Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: statusColor.withOpacity(
                          _connectionStatus == GlassesConnectionStatus.connecting
                            ? 0.3 + 0.4 * _pulseController.value
                            : 0.1
                        ),
                      ),
                      child: Icon(
                        statusIcon,
                        size: 32,
                        color: statusColor,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusText,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_connectionStatus == GlassesConnectionStatus.connected)
                  Column(
                    children: [
                      Icon(
                        Icons.battery_std,
                        color: _batteryLevel > 0.2 ? Colors.green : Colors.red,
                      ),
                      Text(
                        '${(_batteryLevel * 100).round()}%',
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
              ],
            ),
            if (_connectionStatus == GlassesConnectionStatus.connected) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _disconnect,
                      icon: const Icon(Icons.bluetooth_disabled),
                      label: const Text('Disconnect'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Test HUD display
                      },
                      icon: const Icon(Icons.visibility),
                      label: const Text('Test Display'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildHUDControlCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.display_settings, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'HUD Controls',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // HUD Enable/Disable
            SwitchListTile(
              title: const Text('Enable HUD Display'),
              subtitle: const Text('Show information on glasses display'),
              value: _isHUDEnabled,
              onChanged: (value) {
                setState(() {
                  _isHUDEnabled = value;
                });
              },
            ),
            
            const Divider(),
            
            // Brightness Control
            ListTile(
              title: const Text('Display Brightness'),
              subtitle: Slider(
                value: _brightness,
                onChanged: _isHUDEnabled ? (value) {
                  setState(() {
                    _brightness = value;
                  });
                } : null,
                divisions: 10,
                label: '${(_brightness * 100).round()}%',
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Quick Actions
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.info, size: 16),
                  label: const Text('Show Info'),
                  onPressed: _isHUDEnabled && _connectionStatus == GlassesConnectionStatus.connected 
                    ? _displayDeviceInfo : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Display'),
                  onPressed: _isHUDEnabled && _connectionStatus == GlassesConnectionStatus.connected 
                    ? _clearDisplay : null,
                ),
                ActionChip(
                  avatar: const Icon(Icons.notifications, size: 16),
                  label: const Text('Test Alert'),
                  onPressed: _isHUDEnabled && _connectionStatus == GlassesConnectionStatus.connected 
                    ? _showTestAlert : null,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Advanced Testing Section
            if (_connectionStatus == GlassesConnectionStatus.connected) ...[
              const Divider(),
              Text(
                'Even Realities Testing',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              // Custom Text Input
              TextField(
                controller: _testTextController,
                decoration: const InputDecoration(
                  labelText: 'Custom Text',
                  hintText: 'Enter text to display on glasses',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              
              // Text Display Actions
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _displayCustomText,
                    icon: const Icon(Icons.text_fields, size: 16),
                    label: const Text('Display Text'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _displayTestBitmap,
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text('Test Image'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _displayProgressAnimation,
                    icon: const Icon(Icons.animation, size: 16),
                    label: const Text('Animation'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildDeviceInfoCard(ThemeData theme) {
    final connectedDevice = _discoveredDevices.firstWhere(
      (device) => device.id == _connectedDeviceId,
      orElse: () => _discoveredDevices.first,
    );
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Device Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildInfoRow('Device Name', connectedDevice.name),
            _buildInfoRow('Device ID', connectedDevice.id),
            _buildInfoRow('Signal Strength', '${connectedDevice.rssi} dBm'),
            _buildInfoRow('Battery Level', '${(connectedDevice.batteryLevel * 100).round()}%'),
            _buildInfoRow('Firmware Version', '1.2.3'),
            _buildInfoRow('Connection Type', 'Bluetooth Low Energy'),
            _buildInfoRow('Last Sync', _lastSyncTime),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDeviceDiscoveryCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth_searching, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Available Devices',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_isScanning)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _startScanning,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Scan for devices',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_discoveredDevices.isEmpty && !_isScanning)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 48,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Devices Found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make sure your glasses are in pairing mode',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _startScanning,
                      icon: const Icon(Icons.search),
                      label: const Text('Scan for Devices'),
                    ),
                  ],
                ),
              )
            else
              ...(_discoveredDevices.map((device) => DeviceListTile(
                device: device,
                onConnect: () => _connectToDevice(device),
              ))),
          ],
        ),
      ),
    );
  }
  
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Glasses Help'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Make sure your glasses are charged'),
            Text('• Enable Bluetooth on your device'),
            Text('• Place glasses in pairing mode'),
            Text('• Keep glasses within 10 feet'),
            SizedBox(height: 16),
            Text('Troubleshooting:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Restart Bluetooth if connection fails'),
            Text('• Reset glasses if problems persist'),
            Text('• Check for firmware updates'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showCalibrationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibrate Display'),
        content: const Text(
          'This will guide you through calibrating the HUD display position and brightness for optimal viewing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Start calibration process
            },
            child: const Text('Start Calibration'),
          ),
        ],
      ),
    );
  }
  
  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Connection'),
        content: const Text(
          'This will disconnect and clear all saved connection data for your glasses. You will need to pair them again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _disconnect();
              // TODO: Clear saved connection data
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

// Helper Models
class DiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final double batteryLevel;
  
  DiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.batteryLevel,
  });
}

enum GlassesConnectionStatus {
  disconnected,
  connecting,
  connected,
}

// Custom Widgets
class DeviceListTile extends StatelessWidget {
  final DiscoveredDevice device;
  final VoidCallback onConnect;
  
  const DeviceListTile({
    super.key,
    required this.device,
    required this.onConnect,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.remove_red_eye,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          device.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signal: ${device.rssi} dBm'),
            Row(
              children: [
                Icon(
                  Icons.battery_std,
                  size: 16,
                  color: device.batteryLevel > 0.2 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text('${(device.batteryLevel * 100).round()}%'),
              ],
            ),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: onConnect,
          child: const Text('Connect'),
        ),
        isThreeLine: true,
      ),
    );
  }
}