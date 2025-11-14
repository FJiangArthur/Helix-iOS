import 'package:flutter/material.dart';

import 'app.dart';
import 'ble_manager.dart';
import 'services/analytics_service.dart';

void main() {
  // Initialize Flutter binding
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize analytics
  _initializeAnalytics();

  // Initialize BLE manager
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