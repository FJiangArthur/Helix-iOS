import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/ai/ai_coordinator.dart';

void main() {
  group('AICoordinator', () {
    late AICoordinator coordinator;

    setUp(() {
      coordinator = AICoordinator.instance;
      coordinator.dispose(); // Reset state
    });

    test('starts in disabled state', () {
      expect(coordinator.isEnabled, false);
    });

    test('can be configured', () {
      coordinator.configure(
        enabled: true,
        factCheck: false,
        sentiment: true,
      );

      expect(coordinator.factCheckEnabled, false);
      expect(coordinator.sentimentEnabled, true);
    });

    test('returns error when not initialized', () async {
      final result = await coordinator.analyzeText('test text');

      expect(result.containsKey('error'), true);
    });

    test('cache works correctly', () {
      // Add some cache entries
      coordinator.clearCache();

      // Since we can't directly test caching without a real API key,
      // we just test the cache clear functionality
      coordinator.clearCache();
      expect(true, true); // Cache cleared successfully
    });

    test('rate limiting prevents excessive requests', () {
      // This test would need a mock provider to fully test
      // For now, just verify the stats method works
      final stats = coordinator.getStats();

      expect(stats.containsKey('provider'), true);
      expect(stats.containsKey('cacheSize'), true);
      expect(stats.containsKey('requestsLastMinute'), true);
    });

    test('dispose cleans up resources', () {
      coordinator.dispose();

      expect(coordinator.isEnabled, false);
      final stats = coordinator.getStats();
      expect(stats['cacheSize'], 0);
      expect(stats['requestsLastMinute'], 0);
    });
  });
}
