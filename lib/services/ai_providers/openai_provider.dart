// ABOUTME: OpenAI provider implementation for GPT-4 and Whisper API integration
// ABOUTME: Handles all OpenAI-specific API calls with retry logic and error handling

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'base_provider.dart';
import '../../models/analysis_result.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/logging_service.dart';

class OpenAIProvider extends BaseAIProvider {
  static const String _tag = 'OpenAIProvider';
  
  final LoggingService _logger;
  final Dio _dio;
  
  String? _apiKey;
  bool _isInitialized = false;
  
  // Model configuration
  String _model = 'gpt-4-turbo-preview';
  
  // Usage tracking
  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;
  double _totalCost = 0.0;
  
  OpenAIProvider({
    required LoggingService logger,
    Dio? dio,
  })  : _logger = logger,
        _dio = dio ?? Dio();
  
  @override
  String get name => 'OpenAI';
  
  @override
  bool get isAvailable => _isInitialized && _apiKey != null;
  
  @override
  Future<void> initialize(String apiKey) async {
    try {
      _logger.log(_tag, 'Initializing OpenAI provider', LogLevel.info);
      
      _apiKey = apiKey;
      
      // Configure Dio client
      _dio.options = BaseOptions(
        baseUrl: APIConstants.openAIBaseURL,
        connectTimeout: APIConstants.apiTimeout,
        receiveTimeout: APIConstants.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
      );
      
      // Validate API key
      final isValid = await validateApiKey(apiKey);
      if (!isValid) {
        throw Exception('Invalid OpenAI API key');
      }
      
      _isInitialized = true;
      _logger.log(_tag, 'OpenAI provider initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize OpenAI provider: $e', LogLevel.error);
      rethrow;
    }
  }
  
  @override
  Future<String> sendCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
    Map<String, dynamic>? additionalParams,
  }) async {
    if (!isAvailable) {
      throw Exception('OpenAI provider not initialized');
    }
    
    final messages = <Map<String, String>>[];
    
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});
    
    try {
      final stopwatch = Stopwatch()..start();
      
      final response = await _dio.post(
        APIConstants.chatCompletionsEndpoint,
        data: {
          'model': _model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
          ...?additionalParams,
        },
      );
      
      stopwatch.stop();
      
      final data = response.data;
      final content = data['choices'][0]['message']['content'] as String;
      final usage = data['usage'];
      
      // Track usage
      _totalPromptTokens += usage['prompt_tokens'] as int;
      _totalCompletionTokens += usage['completion_tokens'] as int;
      _totalCost += estimateCost(
        usage['prompt_tokens'] as int,
        usage['completion_tokens'] as int,
      );
      
      _logger.log(
        _tag,
        'Completion received in ${stopwatch.elapsedMilliseconds}ms',
        LogLevel.debug,
      );
      
      return content;
    } catch (e) {
      _logger.log(_tag, 'Completion request failed: $e', LogLevel.error);
      
      if (e is DioException && e.response?.statusCode == 429) {
        // Rate limit - wait and retry
        await Future.delayed(const Duration(seconds: 5));
        return sendCompletion(
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
          maxTokens: maxTokens,
          additionalParams: additionalParams,
        );
      }
      
      rethrow;
    }
  }
  
  @override
  Stream<String> streamCompletion({
    required String prompt,
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
    Map<String, dynamic>? additionalParams,
  }) async* {
    if (!isAvailable) {
      throw Exception('OpenAI provider not initialized');
    }
    
    final messages = <Map<String, String>>[];
    
    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});
    
    try {
      final response = await _dio.post(
        APIConstants.chatCompletionsEndpoint,
        data: {
          'model': _model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
          ...?additionalParams,
        },
        options: Options(
          responseType: ResponseType.stream,
        ),
      );
      
      final stream = response.data.stream;
      final buffer = StringBuffer();
      
      await for (final chunk in stream) {
        final lines = utf8.decode(chunk).split('\n');
        
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            
            if (jsonStr == '[DONE]') {
              break;
            }
            
            try {
              final json = jsonDecode(jsonStr);
              final delta = json['choices'][0]['delta'];
              
              if (delta['content'] != null) {
                final content = delta['content'] as String;
                buffer.write(content);
                yield content;
              }
            } catch (e) {
              // Skip malformed JSON
              continue;
            }
          }
        }
      }
    } catch (e) {
      _logger.log(_tag, 'Stream completion failed: $e', LogLevel.error);
      rethrow;
    }
  }
  
  @override
  Future<FactCheckResult> verifyFact({
    required String claim,
    String? context,
    List<String>? additionalContext,
  }) async {
    final prompt = '''
Verify the following factual claim:

Claim: "$claim"
${context != null ? '\nContext: $context' : ''}
${additionalContext != null ? '\nAdditional Context:\n${additionalContext.join('\n')}' : ''}

Please provide:
1. Verification status (verified/disputed/uncertain)
2. Confidence level (0.0-1.0)
3. Supporting sources or reasoning
4. Brief explanation

Format your response as JSON:
{
  "status": "verified|disputed|uncertain",
  "confidence": 0.0-1.0,
  "sources": ["source1", "source2"],
  "explanation": "detailed explanation"
}
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        temperature: 0.1, // Low temperature for factual accuracy
        maxTokens: 500,
      );
      
      final json = jsonDecode(response);
      
      return FactCheckResult(
        id: 'fact_${DateTime.now().millisecondsSinceEpoch}',
        claim: claim,
        status: _parseFactCheckStatus(json['status']),
        confidence: (json['confidence'] as num).toDouble(),
        sources: List<String>.from(json['sources'] ?? []),
        explanation: json['explanation'],
        context: context,
      );
    } catch (e) {
      _logger.log(_tag, 'Fact verification failed: $e', LogLevel.error);
      
      return FactCheckResult(
        id: 'fact_${DateTime.now().millisecondsSinceEpoch}',
        claim: claim,
        status: FactCheckStatus.uncertain,
        confidence: 0.0,
        explanation: 'Failed to verify: $e',
      );
    }
  }
  
  @override
  Future<ConversationSummary> generateSummary({
    required String text,
    int maxWords = 200,
    bool includeKeyPoints = true,
    bool includeActionItems = true,
  }) async {
    final prompt = '''
Summarize the following conversation in approximately $maxWords words:

$text

Please provide:
1. A concise summary
${includeKeyPoints ? '2. Key discussion points (as a list)' : ''}
${includeActionItems ? '3. Any action items or decisions made' : ''}
4. Overall tone of the conversation
5. Main topics discussed

Format your response as JSON:
{
  "summary": "main summary text",
  "keyPoints": ["point1", "point2"],
  "decisions": ["decision1", "decision2"],
  "questions": ["question1", "question2"],
  "tone": "professional|casual|formal|etc",
  "topics": ["topic1", "topic2"]
}
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        temperature: 0.3,
        maxTokens: 800,
      );
      
      final json = jsonDecode(response);
      
      return ConversationSummary(
        summary: json['summary'] ?? '',
        keyPoints: List<String>.from(json['keyPoints'] ?? []),
        decisions: List<String>.from(json['decisions'] ?? []),
        questions: List<String>.from(json['questions'] ?? []),
        tone: json['tone'],
        topics: List<String>.from(json['topics'] ?? []),
        confidence: 0.85,
      );
    } catch (e) {
      _logger.log(_tag, 'Summary generation failed: $e', LogLevel.error);
      
      return ConversationSummary(
        summary: 'Failed to generate summary',
        confidence: 0.0,
      );
    }
  }
  
  @override
  Future<List<ActionItemResult>> extractActionItems({
    required String text,
    bool includeDeadlines = true,
    bool includePriority = true,
  }) async {
    final prompt = '''
Extract action items from the following conversation:

$text

For each action item, identify:
1. What needs to be done
2. Who is responsible (if mentioned)
${includeDeadlines ? '3. Any deadlines or timeframes' : ''}
${includePriority ? '4. Priority level (high/medium/low)' : ''}

Format your response as JSON array:
[
  {
    "description": "action item description",
    "assignee": "person responsible or null",
    "dueDate": "ISO date or null",
    "priority": "high|medium|low",
    "context": "where it was mentioned"
  }
]
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        temperature: 0.2,
        maxTokens: 600,
      );
      
      final jsonList = jsonDecode(response) as List;
      
      return jsonList.map((item) {
        return ActionItemResult(
          id: 'action_${DateTime.now().millisecondsSinceEpoch}_${jsonList.indexOf(item)}',
          description: item['description'] ?? '',
          assignee: item['assignee'],
          dueDate: item['dueDate'] != null 
              ? DateTime.tryParse(item['dueDate'])
              : null,
          priority: _parseActionPriority(item['priority']),
          context: item['context'],
          confidence: 0.8,
        );
      }).toList();
    } catch (e) {
      _logger.log(_tag, 'Action item extraction failed: $e', LogLevel.error);
      return [];
    }
  }
  
  @override
  Future<SentimentAnalysisResult> analyzeSentiment({
    required String text,
    bool includeEmotions = true,
  }) async {
    final prompt = '''
Analyze the sentiment of the following text:

$text

Provide:
1. Overall sentiment (positive/negative/neutral/mixed)
2. Confidence score (0.0-1.0)
${includeEmotions ? '3. Emotional breakdown (joy, anger, sadness, fear, surprise, disgust - each 0.0-1.0)' : ''}
4. Tone of the conversation
5. Key phrases that influenced the sentiment

Format as JSON:
{
  "sentiment": "positive|negative|neutral|mixed",
  "confidence": 0.0-1.0,
  "emotions": {
    "joy": 0.0-1.0,
    "anger": 0.0-1.0,
    "sadness": 0.0-1.0,
    "fear": 0.0-1.0,
    "surprise": 0.0-1.0,
    "disgust": 0.0-1.0
  },
  "tone": "description",
  "keyPhrases": ["phrase1", "phrase2"]
}
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        temperature: 0.3,
        maxTokens: 400,
      );
      
      final json = jsonDecode(response);
      
      return SentimentAnalysisResult(
        overallSentiment: _parseSentimentType(json['sentiment']),
        confidence: (json['confidence'] as num).toDouble(),
        emotions: Map<String, double>.from(
          json['emotions']?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {},
        ),
        tone: json['tone'],
        keyPhrases: List<String>.from(json['keyPhrases'] ?? []),
      );
    } catch (e) {
      _logger.log(_tag, 'Sentiment analysis failed: $e', LogLevel.error);
      
      return const SentimentAnalysisResult(
        overallSentiment: SentimentType.neutral,
        confidence: 0.0,
        emotions: {},
      );
    }
  }
  
  @override
  Future<List<String>> detectClaims({
    required String text,
    double confidenceThreshold = 0.7,
  }) async {
    final prompt = '''
Identify factual claims in the following text that can be verified:

$text

List only claims that:
1. Are factual statements (not opinions)
2. Can be verified through evidence
3. Have confidence above $confidenceThreshold

Format as JSON array of strings:
["claim1", "claim2", "claim3"]
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        temperature: 0.2,
        maxTokens: 400,
      );
      
      final claims = jsonDecode(response) as List;
      return List<String>.from(claims);
    } catch (e) {
      _logger.log(_tag, 'Claim detection failed: $e', LogLevel.error);
      return [];
    }
  }
  
  @override
  Future<Map<String, dynamic>> getUsageStats() async {
    return {
      'provider': name,
      'model': _model,
      'totalPromptTokens': _totalPromptTokens,
      'totalCompletionTokens': _totalCompletionTokens,
      'totalTokens': _totalPromptTokens + _totalCompletionTokens,
      'estimatedCost': _totalCost,
      'isAvailable': isAvailable,
    };
  }
  
  @override
  Future<bool> validateApiKey(String apiKey) async {
    try {
      // Test with a minimal request
      final testDio = Dio();
      final response = await testDio.get(
        '${APIConstants.openAIBaseURL}/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      _logger.log(_tag, 'API key validation failed: $e', LogLevel.error);
      return false;
    }
  }
  
  @override
  double estimateCost(int inputTokens, int outputTokens) {
    // GPT-4 Turbo pricing (as of 2024)
    const inputCostPer1k = 0.01; // $0.01 per 1K input tokens
    const outputCostPer1k = 0.03; // $0.03 per 1K output tokens
    
    final inputCost = (inputTokens / 1000) * inputCostPer1k;
    final outputCost = (outputTokens / 1000) * outputCostPer1k;
    
    return inputCost + outputCost;
  }
  
  @override
  Future<void> dispose() async {
    _dio.close();
    _isInitialized = false;
    _apiKey = null;
  }
  
  // Helper methods
  
  FactCheckStatus _parseFactCheckStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'verified':
        return FactCheckStatus.verified;
      case 'disputed':
        return FactCheckStatus.disputed;
      case 'uncertain':
        return FactCheckStatus.uncertain;
      default:
        return FactCheckStatus.needsReview;
    }
  }
  
  ActionItemPriority _parseActionPriority(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return ActionItemPriority.high;
      case 'medium':
        return ActionItemPriority.medium;
      case 'low':
        return ActionItemPriority.low;
      case 'urgent':
        return ActionItemPriority.urgent;
      default:
        return ActionItemPriority.medium;
    }
  }
  
  SentimentType _parseSentimentType(String? sentiment) {
    switch (sentiment?.toLowerCase()) {
      case 'positive':
        return SentimentType.positive;
      case 'negative':
        return SentimentType.negative;
      case 'neutral':
        return SentimentType.neutral;
      case 'mixed':
        return SentimentType.mixed;
      default:
        return SentimentType.neutral;
    }
  }
  
  /// Set the model to use for completions
  void setModel(String model) {
    _model = model;
    _logger.log(_tag, 'Model changed to: $model', LogLevel.info);
  }
  
  /// Get available models
  static List<String> get availableModels => [
    'gpt-4-turbo-preview',
    'gpt-4',
    'gpt-3.5-turbo',
    'gpt-3.5-turbo-16k',
  ];
}