/// End-to-End Test Driver
///
/// This file serves as the driver for running E2E tests with performance profiling.

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (Map<String, dynamic>? data) async {
    if (data != null) {
      // Process performance data, timeline, etc.
      print('Test completed with data: ${data.keys}');
    }
  },
);
