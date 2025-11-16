/// AI Test Fixtures
///
/// Provides factory methods and fixtures for creating test AI data

/// Factory for creating mock AI analysis responses
class AIAnalysisFactory {
  /// Create a sentiment analysis response
  static Map<String, dynamic> createSentimentResponse({
    double score = 0.75,
    String label = 'positive',
    double confidence = 0.90,
  }) {
    return <String, dynamic>{
      'sentiment': <String, dynamic>{
        'score': score,
        'label': label,
        'confidence': confidence,
      },
    };
  }

  /// Create a fact-check response
  static Map<String, dynamic> createFactCheckResponse({
    List<Map<String, dynamic>>? claims,
    bool hasFactualIssues = false,
  }) {
    return <String, dynamic>{
      'factCheck': <String, dynamic>{
        'claims': claims ?? <Map<String, dynamic>>[],
        'hasFactualIssues': hasFactualIssues,
      },
    };
  }

  /// Create a claim detection response
  static Map<String, dynamic> createClaimDetectionResponse({
    List<Map<String, dynamic>>? claims,
  }) {
    return <String, dynamic>{
      'claims': claims ?? <Map<String, dynamic>>[
        <String, dynamic>{
          'text': 'The Earth is round',
          'confidence': 0.95,
          'type': 'factual',
        },
      ],
    };
  }

  /// Create a complete AI analysis response
  static Map<String, dynamic> createCompleteAnalysis({
    Map<String, dynamic>? sentiment,
    Map<String, dynamic>? factCheck,
    List<Map<String, dynamic>>? claims,
    String? summary,
  }) {
    return <String, dynamic>{
      'sentiment': sentiment ?? <String, dynamic>{
        'score': 0.75,
        'label': 'positive',
        'confidence': 0.90,
      },
      'factCheck': factCheck ?? <String, dynamic>{
        'claims': <Map<String, dynamic>>[],
        'hasFactualIssues': false,
      },
      'claims': claims ?? <Map<String, dynamic>>[],
      'summary': summary ?? 'AI analysis completed successfully',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Create an error response
  static Map<String, dynamic> createErrorResponse({
    String error = 'AI analysis failed',
    int? statusCode,
  }) {
    return <String, dynamic>{
      'error': error,
      if (statusCode != null) 'statusCode': statusCode,
    };
  }

  /// Create a rate limit response
  static Map<String, dynamic> createRateLimitResponse() {
    return <String, dynamic>{
      'error': 'Rate limit exceeded',
      'statusCode': 429,
      'retryAfter': 60,
    };
  }
}

/// Factory for creating mock AI provider configurations
class AIProviderConfigFactory {
  /// Create OpenAI provider config
  static Map<String, dynamic> createOpenAIConfig({
    String? apiKey,
    String model = 'gpt-3.5-turbo',
    double temperature = 0.7,
  }) {
    return <String, dynamic>{
      'provider': 'openai',
      'apiKey': apiKey ?? 'test-api-key',
      'model': model,
      'temperature': temperature,
    };
  }

  /// Create Anthropic provider config
  static Map<String, dynamic> createAnthropicConfig({
    String? apiKey,
    String model = 'claude-3-sonnet-20240229',
    double temperature = 0.7,
  }) {
    return <String, dynamic>{
      'provider': 'anthropic',
      'apiKey': apiKey ?? 'test-api-key',
      'model': model,
      'temperature': temperature,
    };
  }

  /// Create invalid config (for testing error handling)
  static Map<String, dynamic> createInvalidConfig() {
    return <String, dynamic>{
      'provider': 'unknown',
      'apiKey': '',
    };
  }
}

/// Test data for AI analysis
class AITestData {
  // Sample texts for analysis
  static const List<String> neutralTexts = <String>[
    'The meeting is scheduled for 3 PM.',
    'The report contains five sections.',
    'The temperature is 72 degrees.',
  ];

  static const List<String> positiveTexts = <String>[
    'This is an excellent product!',
    'I absolutely love this feature.',
    'Great work on the implementation!',
  ];

  static const List<String> negativeTexts = <String>[
    'This is terrible and doesn\'t work.',
    'I\'m very disappointed with this.',
    'The worst experience I\'ve ever had.',
  ];

  static const List<String> claimTexts = <String>[
    'Studies show that coffee improves productivity.',
    'The Earth revolves around the Sun.',
    'This product is 100% organic.',
  ];

  static const List<String> technicalTexts = <String>[
    'The API latency is under 100ms.',
    'Memory usage increased by 15%.',
    'CPU utilization peaked at 85%.',
  ];

  // Sentiment scores
  static const double stronglyPositive = 0.95;
  static const double positive = 0.75;
  static const double neutral = 0.50;
  static const double negative = 0.25;
  static const double stronglyNegative = 0.05;

  // Claim confidence thresholds
  static const double highConfidence = 0.90;
  static const double mediumConfidence = 0.70;
  static const double lowConfidence = 0.50;
}

/// Factory for creating mock conversation insights
class ConversationInsightsFactory {
  /// Create basic conversation insights
  static Map<String, dynamic> create({
    int messageCount = 10,
    int participantCount = 2,
    Duration? duration,
    Map<String, dynamic>? sentiment,
    List<String>? keywords,
  }) {
    return <String, dynamic>{
      'messageCount': messageCount,
      'participantCount': participantCount,
      'duration': (duration ?? const Duration(minutes: 5)).inSeconds,
      'sentiment': sentiment ?? <String, dynamic>{
        'overall': 'positive',
        'score': 0.75,
      },
      'keywords': keywords ?? <String>['test', 'conversation', 'sample'],
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Create insights for a long conversation
  static Map<String, dynamic> createLongConversation() {
    return create(
      messageCount: 500,
      participantCount: 5,
      duration: const Duration(hours: 2),
      keywords: <String>[
        'project',
        'deadline',
        'implementation',
        'testing',
        'deployment',
      ],
    );
  }

  /// Create insights for a short conversation
  static Map<String, dynamic> createShortConversation() {
    return create(
      messageCount: 3,
      participantCount: 2,
      duration: const Duration(minutes: 1),
      keywords: <String>['hello', 'quick', 'question'],
    );
  }
}
