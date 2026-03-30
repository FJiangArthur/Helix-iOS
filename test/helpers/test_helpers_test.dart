import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('installPlatformMocks', () {
    tearDown(removePlatformMocks);

    test('stubs path provider document lookups', () async {
      installPlatformMocks();

      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final path = await channel.invokeMethod<String>(
        'getApplicationDocumentsDirectory',
      );

      expect(path, isNotNull);
      expect(path, isNotEmpty);
    });
  });
}
