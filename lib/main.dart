// ABOUTME: Main entry point for the Helix Flutter application
// ABOUTME: Initializes services, sets up dependency injection, and launches the app

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/service_locator.dart';
import 'core/utils/logging_service.dart';

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    logger.error('Flutter', 'Unhandled Flutter error', details.exception, details.stack);
  };

  // Set up dependency injection
  try {
    await setupServiceLocator();
    logger.info('Main', 'Service locator initialized successfully');
  } catch (error, stackTrace) {
    logger.critical('Main', 'Failed to initialize service locator', error, stackTrace);
    // Continue with app launch even if some services fail
  }

  // Configure system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Launch the app
  runApp(const HelixApp());
}