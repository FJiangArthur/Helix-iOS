import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/provider_error_state.dart';

void main() {
  group('ProviderErrorState', () {
    test('missingConfiguration creates a non-retryable settings action', () {
      final state = ProviderErrorState.missingConfiguration();

      expect(state.kind, ProviderErrorKind.missingConfiguration);
      expect(state.title, 'API key required');
      expect(state.actionLabel, 'Open Settings');
      expect(state.canRetry, isFalse);
    });

    test('maps authentication failures to friendly copy', () {
      final state = ProviderErrorState.fromException(
        Exception(
          'You didn\'t provide an API key in an Authorization header.',
        ),
      );

      expect(state.kind, ProviderErrorKind.authentication);
      expect(state.title, 'Authentication failed');
      expect(state.actionLabel, 'Open Settings');
      expect(state.canRetry, isFalse);
    });

    test('maps rate limit failures', () {
      final state = ProviderErrorState.fromException(
        Exception('429 rate limit exceeded'),
      );

      expect(state.kind, ProviderErrorKind.rateLimited);
      expect(state.message, contains('Try again in a moment'));
      expect(state.canRetry, isTrue);
    });

    test('maps network failures', () {
      final state = ProviderErrorState.fromException(
        Exception('SocketException: connection timed out'),
      );

      expect(state.kind, ProviderErrorKind.network);
      expect(state.message, contains('Check connectivity'));
    });

    test('maps provider unavailable failures', () {
      final state = ProviderErrorState.fromException(
        Exception('503 service unavailable'),
      );

      expect(state.kind, ProviderErrorKind.unavailable);
      expect(state.title, 'Provider unavailable');
    });

    test('falls back to unknown for unclassified failures', () {
      final state = ProviderErrorState.fromException(
        Exception('something unexpected happened'),
      );

      expect(state.kind, ProviderErrorKind.unknown);
      expect(state.userFacingMessage, contains('Assistant request failed'));
    });
  });
}
