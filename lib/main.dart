import 'package:flutter/material.dart';

import 'app.dart';
import 'ble_manager.dart';

void main() {
  // Initialize BLE manager globally
  WidgetsFlutterBinding.ensureInitialized();
  _initializeBleManager();
  runApp(const HelixApp());
}

void _initializeBleManager() {
  final bleManager = BleManager.get();
  bleManager.setMethodCallHandler();
  bleManager.startListening();
}