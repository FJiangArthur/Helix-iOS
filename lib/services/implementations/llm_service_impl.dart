// ABOUTME: LLM service implementation for AI-powered conversation analysis
// ABOUTME: Integrates with OpenAI GPT and Anthropic APIs for fact-checking, summarization, and insights

import 'dart:async';

import 'package:dio/dio.dart';

import '../llm_service.dart';
import '../../models/analysis_result.dart';
import '../../models/conversation_model.dart';
import '../../core/utils/logging_service.dart';
import '../../core/utils/constants.dart';

class LLMServiceImpl implements LLMService {
  static const String _tag = 'LLMServiceImpl';

  final LoggingService _logger;
  final Dio _dio;

  // Service state
  bool _isInitialized = false;
  LLMProvider _currentProvider = LLMProvider.openai;
  String? _openAIKey;
  String? _anthropicKey;

  // Configuration
  AnalysisConfiguration _analysisConfig = const AnalysisConfiguration();
  Map<String, dynamic> _analysisCache = {};

  LLMServiceImpl({
    required LoggingService logger,
    Dio? dio,
  })  : _logger = logger,
        _dio = dio ?? Dio();

  @override
  bool get isInitialized => _isInitialized;

  @override
  LLMProvider get currentProvider => _currentProvider;

  @override
  Future<void> initialize({
    String? openAIKey,
    String? anthropicKey,
    LLMProvider? preferredProvider,
  }) async {
    try {
      _logger.log(_tag, 'Initializing LLM service', LogLevel.info);

      _openAIKey = openAIKey;
      _anthropicKey = anthropicKey;

      if (preferredProvider != null) {
        _currentProvider = preferredProvider;
      }

      // Configure HTTP client
      _dio.options.connectTimeout = APIConstants.apiTimeout;
      _dio.options.receiveTimeout = APIConstants.apiTimeout;
      _dio.options.headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'Helix/1.0.0',
      };

      // Validate API keys
      await _validateProvider(_currentProvider);

      _isInitialized = true;
      _logger.log(_tag, 'LLM service initialized with provider: ${_currentProvider.name}', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize LLM service: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> setProvider(LLMProvider provider) async {
    try {
      await _validateProvider(provider);
      _currentProvider = provider;
      _logger.log(_tag, 'Provider changed to: ${provider.name}', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to set provider: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<AnalysisResult> analyzeConversation(
    String conversationText, {
    AnalysisType type = AnalysisType.comprehensive,
    AnalysisPriority priority = AnalysisPriority.normal,
    LLMProvider? provider,
    Map<String, dynamic>? context,
  }) async {
    try {
      if (!_isInitialized) {
        throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
      }

      final analysisProvider = provider ?? _currentProvider;
      final cacheKey = _generateCacheKey(conversationText, type, analysisProvider);

      // Check cache for recent analysis
      if (_analysisCache.containsKey(cacheKey)) {
        final cached = _analysisCache[cacheKey];
        if (DateTime.now().difference(cached['timestamp']).inMinutes < 10) {
          _logger.log(_tag, 'Returning cached analysis result', LogLevel.debug);
          return AnalysisResult.fromJson(cached['result']);
        }
      }

      _logger.log(_tag, 'Starting conversation analysis with ${analysisProvider.name}', LogLevel.info);

      final analysisResult = await _performAnalysis(
        conversationText,
        type,
        analysisProvider,
        context ?? {},
      );

      // Cache the result
      _analysisCache[cacheKey] = {
        'result': analysisResult.toJson(),
        'timestamp': DateTime.now(),
      };

      _logger.log(_tag, 'Analysis completed successfully', LogLevel.info);
      return analysisResult;
    } catch (e) {
      _logger.log(_tag, 'Analysis failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<List<FactCheckResult>> checkFacts(List<String> claims) async {
    try {
      if (!_isInitialized) {
        throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
      }

      _logger.log(_tag, 'Fact-checking ${claims.length} claims', LogLevel.info);

      final verifications = <FactCheckResult>[];

      for (final claim in claims) {
        final prompt = _buildFactCheckPrompt(claim);
        final response = await _sendRequest(prompt, _currentProvider);
        final verification = _parseFactCheckResponse(claim, response);
        verifications.add(verification);
      }

      return verifications;
    } catch (e) {
      _logger.log(_tag, 'Fact-checking failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<ConversationSummary> generateSummary(
    ConversationModel conversation, {
    bool includeKeyPoints = true,
    bool includeActionItems = true,
    int maxWords = 200,
  }) async {
    try {
      if (!_isInitialized) {
        throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
      }

      final conversationText = conversation.segments.map((s) => s.text).join(' ');
      final prompt = _buildSummaryPrompt(conversationText, maxWords, includeKeyPoints, includeActionItems);

      _logger.log(_tag, 'Generating conversation summary', LogLevel.info);

      final response = await _sendRequest(prompt, _currentProvider);
      final summary = _parseSummaryResponse(response, conversation.id);

      return summary;
    } catch (e) {
      _logger.log(_tag, 'Summary generation failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<List<ActionItemResult>> extractActionItems(
    String conversationText, {
    bool includeDeadlines = true,
    bool includePriority = true,
  }) async {
    try {
      if (!_isInitialized) {
        throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
      }

      final prompt = _buildActionItemPrompt(conversationText, includeDeadlines, includePriority);

      _logger.log(_tag, 'Extracting action items', LogLevel.info);

      final response = await _sendRequest(prompt, _currentProvider);
      final actionItems = _parseActionItemsResponse(response);

      return actionItems;
    } catch (e) {
      _logger.log(_tag, 'Action item extraction failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<SentimentAnalysisResult> analyzeSentiment(String text) async {
    try {
      if (!_isInitialized) {
        throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
      }

      final prompt = _buildSentimentPrompt(text);
      final response = await _sendRequest(prompt, _currentProvider);
      final sentiment = _parseSentimentResponse(response);

      return sentiment;
    } catch (e) {
      _logger.log(_tag, 'Sentiment analysis failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<String> askQuestion(
    String question,
    String context, {
    LLMProvider? provider,
  }) async {
    try {
      if (!_isInitialized) {
        throw LLMException('Service not initialized', LLMErrorType.serviceNotReady);
      }

      final prompt = _buildQuestionPrompt(question, context);
      final analysisProvider = provider ?? _currentProvider;

      _logger.log(_tag, 'Processing question with context', LogLevel.info);

      final response = await _sendRequest(prompt, analysisProvider);
      return _parseQuestionResponse(response);
    } catch (e) {
      _logger.log(_tag, 'Question processing failed: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> configureAnalysis(AnalysisConfiguration config) async {
    try {
      _analysisConfig = config;
      _logger.log(_tag, 'Analysis configuration updated', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to configure analysis: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      _analysisCache.clear();
      _logger.log(_tag, 'Analysis cache cleared', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to clear cache: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      // In a real implementation, this would track API usage, costs, etc.
      return {
        'provider': _currentProvider.name,
        'cache_size': _analysisCache.length,
        'initialized': _isInitialized,
        'analysis_config': _analysisConfig.toJson(),
      };
    } catch (e) {
      _logger.log(_tag, 'Failed to get usage stats: $e', LogLevel.error);
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await clearCache();
      _dio.close();
      _isInitialized = false;
      _logger.log(_tag, 'LLM service disposed', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Error disposing LLM service: $e', LogLevel.error);
    }
  }

  // Private methods

  Future<void> _validateProvider(LLMProvider provider) async {
    switch (provider) {
      case LLMProvider.openai:
        if (_openAIKey == null || _openAIKey!.isEmpty) {
          throw LLMException('OpenAI API key required', LLMErrorType.invalidApiKey);
        }
        break;
      case LLMProvider.anthropic:
        if (_anthropicKey == null || _anthropicKey!.isEmpty) {
          throw LLMException('Anthropic API key required', LLMErrorType.invalidApiKey);
        }
        break;
      case LLMProvider.local:
        // Local models don't require API keys
        break;
    }
  }

  Future<AnalysisResult> _performAnalysis(
    String conversationText,
    AnalysisType type,
    LLMProvider provider,
    Map<String, dynamic> context,
  ) async {
    final prompt = _buildAnalysisPrompt(conversationText, type, context);
    final response = await _sendRequest(prompt, provider);
    return _parseAnalysisResponse(response, conversationText);
  }

  Future<String> _sendRequest(String prompt, LLMProvider provider) async {
    switch (provider) {
      case LLMProvider.openai:
        return _sendOpenAIRequest(prompt);
      case LLMProvider.anthropic:
        return _sendAnthropicRequest(prompt);
      case LLMProvider.local:
        throw LLMException('Local provider not implemented yet', LLMErrorType.serviceNotReady);
    }
  }

  Future<String> _sendOpenAIRequest(String prompt) async {
    try {
      final response = await _dio.post(
        '${APIConstants.openAIBaseURL}${APIConstants.chatCompletionsEndpoint}',
        data: {
          'model': APIConstants.defaultOpenAIModel,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 1000,
          'temperature': 0.1,
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openAIKey',
          },
        ),
      );

      return response.data['choices'][0]['message']['content'];
    } catch (e) {
      if (e is DioException) {
        throw LLMException(
          'OpenAI API error: ${e.message}',
          LLMErrorType.apiError,
          originalError: e,
        );
      }
      rethrow;
    }
  }

  Future<String> _sendAnthropicRequest(String prompt) async {
    try {
      final response = await _dio.post(
        '${APIConstants.anthropicBaseURL}${APIConstants.anthropicMessagesEndpoint}',
        data: {
          'model': APIConstants.defaultAnthropicModel,
          'max_tokens': 1000,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
        },
        options: Options(
          headers: {
            'x-api-key': _anthropicKey,
            'anthropic-version': '2023-06-01',
          },
        ),
      );

      return response.data['content'][0]['text'];
    } catch (e) {
      if (e is DioException) {
        throw LLMException(
          'Anthropic API error: ${e.message}',
          LLMErrorType.apiError,
          originalError: e,
        );
      }
      rethrow;
    }
  }

  String _buildAnalysisPrompt(
    String conversationText,
    AnalysisType type,
    Map<String, dynamic> context,
  ) {
    switch (type) {
      case AnalysisType.factCheck:
        return AnalysisConstants.factCheckPromptTemplate.replaceAll(
          '{conversation_text}',
          conversationText,
        );
      case AnalysisType.summary:
        return AnalysisConstants.summaryPromptTemplate.replaceAll(
          '{conversation_text}',
          conversationText,
        );
      case AnalysisType.comprehensive:
        return '''
Analyze the following conversation comprehensively:

$conversationText

Provide:
1. Key topics and themes
2. Factual claims that can be verified
3. Action items and follow-ups
4. Overall sentiment and tone
5. Summary of main points

Format your response as structured JSON.
''';
      case AnalysisType.actionItems:
      case AnalysisType.sentiment:
      case AnalysisType.topics:
        return '''
Analyze the following conversation for ${type.name}:

$conversationText

Provide structured analysis results.
''';
    }
  }

  String _buildFactCheckPrompt(String claim) {
    return '''
Fact-check the following claim:

"$claim"

Provide verification status, confidence level, and sources if possible.
Format as JSON with fields: status, confidence, sources, explanation.
''';
  }

  String _buildSummaryPrompt(
    String conversationText,
    int maxWords,
    bool includeKeyPoints,
    bool includeActionItems,
  ) {
    return '''
Summarize the following conversation in approximately $maxWords words:

$conversationText

${includeKeyPoints ? 'Include key points discussed.' : ''}
${includeActionItems ? 'Include any action items or follow-ups.' : ''}

Provide a clear, concise summary.
''';
  }

  String _buildActionItemPrompt(
    String conversationText,
    bool includeDeadlines,
    bool includePriority,
  ) {
    return '''
Extract action items from the following conversation:

$conversationText

For each action item, identify:
- What needs to be done
- Who is responsible (if mentioned)
${includeDeadlines ? '- Any deadlines or timeframes' : ''}
${includePriority ? '- Priority level (high/medium/low)' : ''}

Format as JSON array.
''';
  }

  String _buildSentimentPrompt(String text) {
    return '''
Analyze the sentiment of the following text:

$text

Provide:
- Overall sentiment (positive/negative/neutral)
- Confidence score (0-1)
- Emotional tone (if applicable)
- Key sentiment indicators

Format as JSON.
''';
  }

  String _buildQuestionPrompt(String question, String context) {
    return '''
Based on the following context:

$context

Answer this question: $question

Provide a clear, accurate answer based only on the given context.
''';
  }

  AnalysisResult _parseAnalysisResponse(String response, String originalText) {
    // In a real implementation, this would parse the JSON response
    // For now, return a basic result
    return AnalysisResult(
      id: 'analysis_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: 'conv_${DateTime.now().millisecondsSinceEpoch}',
      type: AnalysisType.comprehensive,
      status: AnalysisStatus.completed,
      startTime: DateTime.now().subtract(const Duration(seconds: 5)),
      completionTime: DateTime.now(),
      provider: _currentProvider.name,
      confidence: 0.8,
    );
  }

  FactCheckResult _parseFactCheckResponse(String claim, String response) {
    return FactCheckResult(
      id: 'fact_${DateTime.now().millisecondsSinceEpoch}',
      claim: claim,
      status: FactCheckStatus.uncertain,
      confidence: 0.5,
      sources: [],
      explanation: response,
    );
  }

  ConversationSummary _parseSummaryResponse(String response, String conversationId) {
    return ConversationSummary(
      summary: response,
      keyPoints: [],
      decisions: [],
      questions: [],
      topics: [],
      confidence: 0.8,
    );
  }

  List<ActionItemResult> _parseActionItemsResponse(String response) {
    // Basic implementation - would parse JSON in real version
    return [];
  }

  SentimentAnalysisResult _parseSentimentResponse(String response) {
    return SentimentAnalysisResult(
      overallSentiment: SentimentType.neutral,
      confidence: 0.5,
      emotions: {},
    );
  }

  String _parseQuestionResponse(String response) {
    return response.trim();
  }

  String _generateCacheKey(String text, AnalysisType type, LLMProvider provider) {
    final hash = text.hashCode.toString();
    return '${provider.name}_${type.name}_$hash';
  }
}