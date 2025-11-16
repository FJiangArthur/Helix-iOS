# AI Services API Documentation

## 🧠 LLM Service API

### Overview
The LLM Service provides a unified interface for multiple AI providers with automatic failover, health monitoring, and performance optimization.

### Initialization

```dart
final llmService = ServiceLocator.instance.get<LLMService>();

await llmService.initialize(
  openAIKey: 'sk-...',
  anthropicKey: 'sk-ant-...',
  preferredProvider: LLMProvider.openai,
);
```

### Core Methods

#### `analyzeConversation()`
Performs comprehensive AI analysis of conversation text.

```dart
Future<AnalysisResult> analyzeConversation(
  String conversationText, {
  AnalysisType type = AnalysisType.comprehensive,
  AnalysisPriority priority = AnalysisPriority.normal,
  LLMProvider? provider,
  Map<String, dynamic>? context,
})
```

**Parameters:**
- `conversationText`: The text to analyze
- `type`: Type of analysis (comprehensive, factCheck, summary, actionItems, sentiment, topics)
- `priority`: Processing priority (low, normal, high, urgent)
- `provider`: Specific provider to use (optional)
- `context`: Additional context for analysis

**Returns:** `AnalysisResult` with comprehensive analysis data

**Example:**
```dart
final result = await llmService.analyzeConversation(
  'We need to schedule a meeting next Friday to discuss the Q4 budget.',
  type: AnalysisType.comprehensive,
  priority: AnalysisPriority.high,
);

if (result.isCompleted) {
  print('Confidence: ${result.confidence}');
  print('Action Items: ${result.actionItems?.length ?? 0}');
  print('Sentiment: ${result.sentiment?.overallSentiment}');
}
```

#### `checkFacts()`
Verifies factual claims with confidence scoring.

```dart
Future<List<FactCheckResult>> checkFacts(List<String> claims)
```

**Example:**
```dart
final claims = ['The Earth is flat', 'Water boils at 100°C'];
final results = await llmService.checkFacts(claims);

for (final result in results) {
  print('${result.claim}: ${result.status} (${result.confidence})');
}
```

#### `generateSummary()`
Creates structured conversation summaries.

```dart
Future<ConversationSummary> generateSummary(
  ConversationModel conversation, {
  bool includeKeyPoints = true,
  bool includeActionItems = true,
  int maxWords = 200,
})
```

#### `extractActionItems()`
Identifies actionable tasks from conversation text.

```dart
Future<List<ActionItemResult>> extractActionItems(
  String conversationText, {
  bool includeDeadlines = true,
  bool includePriority = true,
})
```

#### `analyzeSentiment()`
Analyzes emotional content and tone.

```dart
Future<SentimentAnalysisResult> analyzeSentiment(String text)
```

### Configuration

#### `configureAnalysis()`
Updates analysis behavior and settings.

```dart
await llmService.configureAnalysis(AnalysisConfiguration(
  enableCaching: true,
  cacheTimeout: Duration(minutes: 15),
  maxRetries: 3,
  confidenceThreshold: 0.7,
  enableBatching: true,
  batchSize: 5,
));
```

### Provider Management

#### `setProvider()`
Switches to a specific AI provider.

```dart
await llmService.setProvider(LLMProvider.anthropic);
```

#### `getUsageStats()`
Retrieves service statistics and metrics.

```dart
final stats = await llmService.getUsageStats();
print('Current provider: ${stats['currentProvider']}');
print('Total requests: ${stats['providers']['openai']['totalRequests']}');
print('Average response time: ${stats['performanceStats']['anthropic']['averageResponseTime']}ms');
```

---

## 🔍 Fact Checking Service API

### Overview
Real-time fact verification service with claim detection and queue management.

### Initialization

```dart
final factChecker = ServiceLocator.instance.get<FactCheckingService>();
await factChecker.initialize();
```

### Core Methods

#### `processTranscription()`
Processes transcription segments for fact-checking.

```dart
Future<void> processTranscription(List<TranscriptionSegment> segments)
```

#### `processText()`
Immediately processes text for fact verification.

```dart
Future<void> processText(String text, {String? context})
```

#### `processHighPriorityText()`
Processes urgent text with immediate priority.

```dart
Future<void> processHighPriorityText(String text, {String? context})
```

### Result Handling

#### Listening to Results
```dart
factChecker.results.listen((FactCheckResult result) {
  switch (result.status) {
    case FactCheckStatus.verified:
      showVerificationCheck(result);
      break;
    case FactCheckStatus.disputed:
      showWarningIcon(result);
      break;
    case FactCheckStatus.uncertain:
      showQuestionMark(result);
      break;
    case FactCheckStatus.needsReview:
      showPendingIcon(result);
      break;
  }
});
```

#### Getting Specific Results
```dart
// Get result by ID
final result = factChecker.getResult('fact_12345');

// Get all results for text
final results = factChecker.getResultsForText('Climate change discussion');
```

### Configuration

```dart
factChecker.configure(
  enabled: true,
  confidenceThreshold: 0.8,
  maxConcurrentChecks: 5,
  batchDelay: Duration(seconds: 3),
  maxRequestsPerMinute: 30,
);
```

### Statistics

```dart
final stats = factChecker.getStatistics();
print('Pending requests: ${stats['pendingRequests']}');
print('Verified claims: ${stats['verifiedClaims']}');
print('Disputed claims: ${stats['disputedClaims']}');
```

---

## 💡 AI Insights Service API

### Overview
Generates real-time conversation intelligence and contextual suggestions.

### Initialization

```dart
final insights = ServiceLocator.instance.get<AIInsightsService>();
await insights.initialize();
```

### Core Methods

#### `processTranscription()`
Analyzes transcription for insights generation.

```dart
Future<void> processTranscription(List<TranscriptionSegment> segments)
```

#### `generateInsights()`
Manually triggers insight generation.

```dart
Future<void> generateInsights()
```

### Insight Types

Configure which types of insights to generate:

```dart
insights.configure(
  enabled: true,
  enabledTypes: InsightType.actionItems | 
                InsightType.sentiment | 
                InsightType.suggestions,
  confidenceThreshold: 0.6,
  analysisInterval: Duration(seconds: 15),
);
```

Available insight types:
- `InsightType.summary` - Conversation summaries
- `InsightType.actionItems` - Task extraction
- `InsightType.questions` - Unresolved questions
- `InsightType.sentiment` - Emotional analysis
- `InsightType.topics` - Key theme identification
- `InsightType.suggestions` - Contextual recommendations

### Listening to Insights

```dart
insights.insights.listen((ConversationInsight insight) {
  switch (insight.category) {
    case InsightCategory.actionItem:
      addToTaskList(insight);
      break;
    case InsightCategory.sentiment:
      updateMoodIndicator(insight);
      break;
    case InsightCategory.suggestion:
      showSuggestionToast(insight);
      break;
    case InsightCategory.warning:
      highlightConcern(insight);
      break;
  }
  
  // Check insight properties
  if (insight.isHighConfidence && insight.priority == InsightPriority.urgent) {
    showUrgentNotification(insight);
  }
});
```

### Querying Insights

```dart
// Get recent insights
final recent = insights.getRecentInsights(limit: 10);

// Get insights by category
final actionItems = insights.getInsightsByType(InsightCategory.actionItem);

// Get specific insight
final insight = insights.getInsight('insight_12345');
```

### Statistics

```dart
final stats = insights.getStatistics();
print('Total insights: ${stats['totalInsights']}');
print('Enabled types: ${stats['enabledTypes']}');
print('Buffer size: ${stats['bufferSize']}');
print('Insights by category: ${stats['insightsByCategory']}');
```

---

## 🔧 AI Provider API

### Overview
Pluggable AI provider interface for adding new LLM services.

### BaseAIProvider Interface

```dart
abstract class BaseAIProvider {
  String get name;
  bool get isAvailable;
  
  Future<void> initialize(String apiKey);
  Future<String> sendCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
    Map<String, dynamic>? additionalParams,
  });
  
  Stream<String> streamCompletion({...});
  Future<FactCheckResult> verifyFact({...});
  Future<ConversationSummary> generateSummary({...});
  Future<List<ActionItemResult>> extractActionItems({...});
  Future<SentimentAnalysisResult> analyzeSentiment({...});
  Future<List<String>> detectClaims({...});
}
```

### OpenAI Provider

```dart
final openAI = OpenAIProvider(logger: logger);
await openAI.initialize('sk-...');

// Set specific model
openAI.setModel('gpt-4-turbo-preview');

// Available models
final models = OpenAIProvider.availableModels;
// ['gpt-4-turbo-preview', 'gpt-4', 'gpt-3.5-turbo', 'gpt-3.5-turbo-16k']
```

### Anthropic Provider

```dart
final anthropic = AnthropicProvider(logger: logger);
await anthropic.initialize('sk-ant-...');

// Set specific model
anthropic.setModel('anthropic-3-5-sonnet-20241022');

// Available models
final models = AnthropicProvider.availableModels;
// ['anthropic-3-5-sonnet-20241022', 'anthropic-3-opus-20240229', ...]
```

### Provider Statistics

```dart
final stats = await provider.getUsageStats();
print('Provider: ${stats['provider']}');
print('Model: ${stats['model']}');
print('Total tokens: ${stats['totalTokens']}');
print('Estimated cost: \$${stats['estimatedCost']}');
```

### Cost Estimation

```dart
final cost = provider.estimateCost(1000, 500); // 1000 input, 500 output tokens
print('Estimated cost: \$${cost.toStringAsFixed(4)}');
```

---

## 📊 Data Models

### AnalysisResult

```dart
class AnalysisResult {
  final String id;
  final String conversationId;
  final AnalysisType type;
  final AnalysisStatus status;
  final DateTime startTime;
  final DateTime? completionTime;
  final String? provider;
  final double confidence;
  final List<FactCheckResult>? factChecks;
  final ConversationSummary? summary;
  final List<ActionItemResult>? actionItems;
  final SentimentAnalysisResult? sentiment;
  final List<TopicResult>? topics;
  final List<String> insights;
  final Map<String, dynamic> metadata;
  
  // Computed properties
  bool get isCompleted;
  bool get isFailed;
  bool get isInProgress;
  ConfidenceLevel get confidenceLevel;
  Duration? get processingDuration;
  int get verifiedFactsCount;
  int get disputedFactsCount;
  bool get hasCriticalFindings;
}
```

### FactCheckResult

```dart
class FactCheckResult {
  final String id;
  final String claim;
  final FactCheckStatus status;
  final double confidence;
  final List<String> sources;
  final String? explanation;
  final String? context;
  final int? startTimeMs;
  final int? endTimeMs;
  final String? speakerId;
  final String? category;
  final List<String> relatedClaims;
  
  // Computed properties
  bool get isVerified;
  bool get isDisputed;
  bool get isUncertain;
  bool get needsReview;
}
```

### ConversationInsight

```dart
class ConversationInsight {
  final String id;
  final InsightCategory category;
  final String title;
  final String content;
  final double confidence;
  final DateTime timestamp;
  final InsightPriority priority;
  final Map<String, dynamic> metadata;
  
  // Computed properties
  bool get isHighConfidence;
  bool get isRecent;
  Duration get age;
}
```

---

## 🚨 Error Handling

### LLM Service Exceptions

```dart
try {
  final result = await llmService.analyzeConversation(text);
} on LLMException catch (e) {
  switch (e.type) {
    case LLMErrorType.serviceNotReady:
      await initializeService();
      break;
    case LLMErrorType.invalidApiKey:
      await promptForValidKey();
      break;
    case LLMErrorType.quotaExceeded:
      await handleQuotaExceeded();
      break;
    case LLMErrorType.networkError:
      await retryWithBackoff();
      break;
    default:
      showGenericError(e.message);
  }
}
```

### Provider Health Monitoring

```dart
// Check provider health
final stats = await llmService.getUsageStats();
final failureStats = stats['failureStats'] as Map<String, int>;

for (final entry in failureStats.entries) {
  if (entry.value > 3) {
    print('Provider ${entry.key} has ${entry.value} failures');
  }
}
```

### Graceful Degradation

```dart
// Handle service unavailability
if (!llmService.isInitialized) {
  // Fallback to basic functionality
  showBasicTranscriptionOnly();
} else {
  // Full AI features available
  enableFullAnalysis();
}
```

---

## 🔧 Performance Optimization

### Caching Strategies

```dart
// Configure caching
await llmService.configureAnalysis(AnalysisConfiguration(
  enableCaching: true,
  cacheTimeout: Duration(minutes: 10),
));

// Clear cache when needed
await llmService.clearCache();
```

### Batch Processing

```dart
// Configure batching for efficiency
factChecker.configure(
  batchDelay: Duration(seconds: 2),
);

insights.configure(
  analysisInterval: Duration(seconds: 15),
);
```

### Rate Limiting

```dart
// Monitor and respect rate limits
final stats = factChecker.getStatistics();
if (stats['recentRequestsPerMinute'] > 25) {
  // Slow down requests
  factChecker.configure(maxRequestsPerMinute: 20);
}
```

---

*This API documentation covers all major interfaces and usage patterns for the Helix AI services. For implementation examples, see the Developer Guide and source code documentation.*