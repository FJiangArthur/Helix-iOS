enum ProviderErrorKind {
  missingConfiguration,
  authentication,
  rateLimited,
  network,
  unavailable,
  unknown,
}

class ProviderErrorState {
  const ProviderErrorState({
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.canRetry = true,
  });

  final ProviderErrorKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final bool canRetry;

  factory ProviderErrorState.missingConfiguration() {
    return const ProviderErrorState(
      kind: ProviderErrorKind.missingConfiguration,
      title: 'API key required',
      message: 'Add an API key in Settings to enable assistant responses.',
      actionLabel: 'Open Settings',
      canRetry: false,
    );
  }

  factory ProviderErrorState.fromException(Object error) {
    final raw = error.toString();
    final normalized = raw.toLowerCase();

    if (normalized.contains("didn't provide an api key") ||
        normalized.contains('invalid_api_key') ||
        normalized.contains('incorrect api key') ||
        normalized.contains('authorization header')) {
      return const ProviderErrorState(
        kind: ProviderErrorKind.authentication,
        title: 'Authentication failed',
        message: 'Check the active provider API key in Settings and try again.',
        actionLabel: 'Open Settings',
        canRetry: false,
      );
    }

    if (normalized.contains('rate limit') ||
        normalized.contains('quota') ||
        normalized.contains('too many requests') ||
        normalized.contains('429')) {
      return const ProviderErrorState(
        kind: ProviderErrorKind.rateLimited,
        title: 'Rate limit reached',
        message: 'The provider is throttling requests right now. Try again in a moment.',
      );
    }

    if (normalized.contains('socket') ||
        normalized.contains('network') ||
        normalized.contains('timed out') ||
        normalized.contains('connection') ||
        normalized.contains('dns')) {
      return const ProviderErrorState(
        kind: ProviderErrorKind.network,
        title: 'Network issue',
        message: 'The request could not reach the provider. Check connectivity and retry.',
      );
    }

    if (normalized.contains('502') ||
        normalized.contains('503') ||
        normalized.contains('504') ||
        normalized.contains('temporarily unavailable') ||
        normalized.contains('service unavailable')) {
      return const ProviderErrorState(
        kind: ProviderErrorKind.unavailable,
        title: 'Provider unavailable',
        message: 'The provider is temporarily unavailable. Retry shortly.',
      );
    }

    return const ProviderErrorState(
      kind: ProviderErrorKind.unknown,
      title: 'Assistant request failed',
      message: 'The response could not be generated. Please try again.',
    );
  }

  String get userFacingMessage => '$title\n$message';
}
