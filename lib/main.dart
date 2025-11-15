import 'package:flutter/material.dart';

import 'app.dart';
import 'ble_manager.dart';
import 'services/analytics_service.dart';
import 'services/service_locator.dart';

Future<void> main() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services (AI, config, etc.)
  try {
    await setupServiceLocator();
    print('✅ Services initialized successfully');
  } catch (e) {
    print('❌ Service initialization failed: $e');
    // Continue anyway - app can run without AI features
  }

  // Initialize analytics
  _initializeAnalytics();

  // Initialize BLE manager globally
  _initializeBleManager();

  runApp(const HelixApp());
}

void _initializeAnalytics() {
  final analytics = AnalyticsService.instance;
  analytics.initialize();
  print('[Main] Analytics initialized');
}

void _initializeBleManager() {
  final bleManager = BleManager.get();
  bleManager.setMethodCallHandler();
  bleManager.startListening();
  print('[Main] BLE manager initialized');
}