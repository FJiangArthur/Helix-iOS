/// Base interface for AI providers (OpenAI, Anthropic, etc.)
/// Provides a simple, lightweight abstraction for LLM operations
abstract class BaseAIProvider {
  /// Provider name for identification
  String get name;

  /// Whether the provider is available and configured
  bool get isAvailable;

  /// Initialize the provider with API key
  Future<void> initialize(String apiKey);

  /// Send a completion request
  /// Returns the AI-generated response text
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
  });

  /// Perform fact-checking on a claim
  /// Returns a map with: isTrue (bool), confidence (double), explanation (String)
  Future<Map<String, dynamic>> factCheck(String claim, {String? context});

  /// Analyze sentiment of text
  /// Returns a map with: sentiment (String), score (double), emotions (Map<String, double>)
  Future<Map<String, dynamic>> analyzeSentiment(String text);

  /// Extract action items from text
  /// Returns a list of maps with: task (String), priority (String), deadline (String?)
  Future<List<Map<String, dynamic>>> extractActionItems(String text);

  /// Generate a summary of text
  /// Returns a map with: summary (String), keyPoints (List<String>)
  Future<Map<String, dynamic>> summarize(String text, {int maxWords = 200});

  /// Validate the API key
  Future<bool> validateApiKey(String apiKey);

  /// Clean up resources
  void dispose();
}
