import 'package:flutter/material.dart';

import 'app.dart';
import 'ble_manager.dart';
import 'services/analytics_service.dart';
import 'services/service_locator.dart';
import 'utils/app_logger.dart';

Future<void> main() async {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services (AI, config, etc.)
  try {
    await setupServiceLocator();
    appLogger.i('✅ Services initialized successfully');
  } catch (e) {
    appLogger.e('❌ Service initialization failed', error: e);
    // Continue anyway - app can run without AI features
  }

  // Initialize analytics
  _initializeAnalytics();

  // Initialize BLE manager globally
  _initializeBleManager();

  runApp(const HelixApp());
}

void _initializeAnalytics() {
  final AnalyticsService analytics = AnalyticsService.instance;
  analytics.initialize();
  appLogger.i('[Main] Analytics initialized');
}

void _initializeBleManager() {
  final BleManager bleManager = BleManager.get();
  bleManager.setMethodCallHandler();
  bleManager.startListening();
  appLogger.i('[Main] BLE manager initialized');
}