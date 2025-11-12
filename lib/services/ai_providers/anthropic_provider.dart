// ABOUTME: Anthropic AI provider implementation for AI analysis and conversation intelligence  
// ABOUTME: Handles Anthropic API calls with streaming support and advanced reasoning capabilities

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'base_provider.dart';
import '../../models/analysis_result.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/logging_service.dart';

class AnthropicProvider extends BaseAIProvider {
  static const String _tag = 'AnthropicProvider';
  
  final LoggingService _logger;
  final Dio _dio;
  
  String? _apiKey;
  bool _isInitialized = false;
  
  // Model configuration
  String _model = 'anthropic-3-5-sonnet-20241022';
  
  // Usage tracking
  int _totalInputTokens = 0;
  int _totalOutputTokens = 0;
  double _totalCost = 0.0;
  
  AnthropicProvider({
    required LoggingService logger,
    Dio? dio,
  })  : _logger = logger,
        _dio = dio ?? Dio();
  
  @override
  String get name => 'Anthropic';
  
  @override
  bool get isAvailable => _isInitialized && _apiKey != null;
  
  @override
  Future<void> initialize(String apiKey) async {
    try {
      _logger.log(_tag, 'Initializing Anthropic provider', LogLevel.info);
      
      _apiKey = apiKey;
      
      // Configure Dio client
      _dio.options = BaseOptions(
        baseUrl: APIConstants.anthropicBaseURL,
        connectTimeout: APIConstants.apiTimeout,
        receiveTimeout: APIConstants.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
      );
      
      // Validate API key
      final isValid = await validateApiKey(apiKey);
      if (!isValid) {
        throw Exception('Invalid Anthropic API key');
      }
      
      _isInitialized = true;
      _logger.log(_tag, 'Anthropic provider initialized successfully', LogLevel.info);
    } catch (e) {
      _logger.log(_tag, 'Failed to initialize Anthropic provider: $e', LogLevel.error);
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
      throw Exception('Anthropic provider not initialized');
    }
    
    final messages = <Map<String, String>>[];
    messages.add({'role': 'user', 'content': prompt});
    
    try {
      final stopwatch = Stopwatch()..start();
      
      final requestData = {
        'model': _model,
        'max_tokens': maxTokens,
        'messages': messages,
        'temperature': temperature,
        ...?additionalParams,
      };
      
      if (systemPrompt != null) {
        requestData['system'] = systemPrompt;
      }
      
      final response = await _dio.post(
        APIConstants.anthropicMessagesEndpoint,
        data: requestData,
      );
      
      stopwatch.stop();
      
      final data = response.data;
      final content = data['content'][0]['text'] as String;
      final usage = data['usage'];
      
      // Track usage
      _totalInputTokens += usage['input_tokens'] as int;
      _totalOutputTokens += usage['output_tokens'] as int;
      _totalCost += estimateCost(
        usage['input_tokens'] as int,
        usage['output_tokens'] as int,
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
      throw Exception('Anthropic provider not initialized');
    }
    
    final messages = <Map<String, String>>[];
    messages.add({'role': 'user', 'content': prompt});
    
    try {
      final requestData = {
        'model': _model,
        'max_tokens': maxTokens,
        'messages': messages,
        'temperature': temperature,
        'stream': true,
        ...?additionalParams,
      };
      
      if (systemPrompt != null) {
        requestData['system'] = systemPrompt;
      }
      
      final response = await _dio.post(
        APIConstants.anthropicMessagesEndpoint,
        data: requestData,
        options: Options(
          responseType: ResponseType.stream,
        ),
      );
      
      final stream = response.data.stream;
      
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
              
              if (json['type'] == 'content_block_delta') {
                final delta = json['delta'];
                if (delta['text'] != null) {
                  final content = delta['text'] as String;
                  yield content;
                }
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
    final systemPrompt = '''
You are a factual verification specialist. Your role is to analyze claims and provide accurate verification based on reliable sources and current knowledge.

Guidelines:
- Be thorough but concise in your analysis
- Distinguish between verified facts, disputed claims, and uncertain information
- Provide specific sources when possible
- Consider the context and nuance of claims
- Rate confidence honestly based on evidence quality
''';
    
    final prompt = '''
Please verify the following factual claim:

CLAIM: "$claim"
${context != null ? '\nCONTEXT: $context' : ''}
${additionalContext != null ? '\nADDITIONAL CONTEXT:\n${additionalContext.join('\n')}' : ''}

Please analyze this claim and provide:
1. Verification status (verified/disputed/uncertain)
2. Confidence level (0.0-1.0) based on evidence quality
3. Supporting sources or reasoning for your determination
4. Brief explanation of your analysis

Respond with only valid JSON in this exact format:
{
  "status": "verified|disputed|uncertain",
  "confidence": 0.0-1.0,
  "sources": ["source1", "source2"],
  "explanation": "detailed explanation of analysis"
}
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: 0.1, // Very low temperature for factual accuracy
        maxTokens: 600,
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
        explanation: 'Failed to verify due to processing error: $e',
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
    final systemPrompt = '''
You are an expert conversation analyst. Your role is to create comprehensive yet concise summaries that capture the essence of discussions.

Guidelines:
- Focus on key information and outcomes
- Identify important decisions and action items
- Maintain the tone and context of the original conversation
- Be objective and accurate in your analysis
''';
    
    final prompt = '''
Please analyze and summarize the following conversation in approximately $maxWords words:

CONVERSATION:
$text

Provide a comprehensive analysis including:
1. Main summary of the conversation
${includeKeyPoints ? '2. Key discussion points and topics covered' : ''}
${includeActionItems ? '3. Decisions made and action items identified' : ''}
4. Questions raised or areas needing follow-up
5. Overall tone and atmosphere of the conversation
6. Primary topics and themes

Respond with only valid JSON in this format:
{
  "summary": "concise main summary text",
  "keyPoints": ["key point 1", "key point 2"],
  "decisions": ["decision 1", "decision 2"],
  "questions": ["question 1", "question 2"],
  "tone": "description of conversational tone",
  "topics": ["topic 1", "topic 2"]
}
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: 0.3,
        maxTokens: 1000,
      );
      
      final json = jsonDecode(response);
      
      return ConversationSummary(
        summary: json['summary'] ?? '',
        keyPoints: List<String>.from(json['keyPoints'] ?? []),
        decisions: List<String>.from(json['decisions'] ?? []),
        questions: List<String>.from(json['questions'] ?? []),
        tone: json['tone'],
        topics: List<String>.from(json['topics'] ?? []),
        confidence: 0.9, // Anthropic is generally very good at summarization
      );
    } catch (e) {
      _logger.log(_tag, 'Summary generation failed: $e', LogLevel.error);
      
      return ConversationSummary(
        summary: 'Failed to generate summary due to processing error',
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
    final systemPrompt = '''
You are an expert at identifying actionable tasks and commitments from conversations. Focus on specific, measurable actions that someone needs to take.

Guidelines:
- Identify clear, actionable tasks (not vague intentions)
- Determine who is responsible when explicitly mentioned
- Extract deadlines and timeframes when specified
- Assess priority based on context and urgency indicators
- Distinguish between firm commitments and casual mentions
''';
    
    final prompt = '''
Extract specific action items from the following conversation:

CONVERSATION:
$text

For each action item you identify, determine:
1. What specific action needs to be taken
2. Who is responsible (if explicitly mentioned)
${includeDeadlines ? '3. Any deadlines, timeframes, or due dates mentioned' : ''}
${includePriority ? '4. Priority level based on context (high/medium/low/urgent)' : ''}
5. Context or background for the action item

Focus only on concrete, actionable tasks. Exclude vague intentions or general discussion points.

Respond with only valid JSON array in this format:
[
  {
    "description": "specific action item description",
    "assignee": "person responsible or null if not specified",
    "dueDate": "ISO date string or null if no deadline",
    "priority": "high|medium|low|urgent",
    "context": "relevant context or background"
  }
]
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: 0.2,
        maxTokens: 800,
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
          confidence: 0.85,
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
    final systemPrompt = '''
You are an expert in sentiment analysis and emotional intelligence. Analyze text for emotional content, tone, and underlying sentiments with nuance and accuracy.

Guidelines:
- Consider context and subtlety in language
- Distinguish between explicit and implicit emotional content  
- Account for cultural and linguistic nuances
- Provide balanced analysis of complex emotional states
- Identify key phrases that drive sentiment conclusions
''';
    
    final prompt = '''
Analyze the sentiment and emotional content of the following text:

TEXT:
$text

Provide a comprehensive sentiment analysis including:
1. Overall sentiment classification (positive/negative/neutral/mixed)
2. Confidence level in your assessment (0.0-1.0)
${includeEmotions ? '3. Emotional breakdown across key emotions (each scored 0.0-1.0)' : ''}
4. Description of the overall tone
5. Key phrases or words that influenced your sentiment determination

Respond with only valid JSON in this format:
{
  "sentiment": "positive|negative|neutral|mixed",
  "confidence": 0.0-1.0,
  "emotions": {
    "joy": 0.0-1.0,
    "anger": 0.0-1.0,
    "sadness": 0.0-1.0,
    "fear": 0.0-1.0,
    "surprise": 0.0-1.0,
    "disgust": 0.0-1.0,
    "anticipation": 0.0-1.0,
    "trust": 0.0-1.0
  },
  "tone": "description of conversational tone",
  "keyPhrases": ["influential phrase 1", "influential phrase 2"]
}
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: 0.3,
        maxTokens: 500,
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
    final systemPrompt = '''
You are an expert fact-checker specializing in identifying verifiable factual claims. Focus on statements that can be objectively verified through evidence.

Guidelines:
- Distinguish facts from opinions, preferences, or subjective statements
- Identify specific, verifiable claims (dates, statistics, events, etc.)
- Exclude obvious common knowledge unless contextually significant
- Focus on claims with potential for verification through reliable sources
- Consider the confidence threshold for inclusion
''';
    
    final prompt = '''
Identify factual claims in the following text that can be objectively verified:

TEXT:
$text

Find claims that:
1. Are factual statements (not opinions or subjective assessments)
2. Can be verified through evidence, sources, or documentation
3. Have sufficient specificity to be checkable
4. Meet a confidence threshold of $confidenceThreshold for verifiability

Focus on substantial claims like:
- Specific statistics or numbers
- Historical facts or dates  
- Scientific claims
- Verifiable events or occurrences
- Measurable assertions

Exclude:
- Opinions or subjective assessments
- Obvious common knowledge
- Vague or unspecific statements
- Personal preferences or feelings

Respond with only a valid JSON array of claim strings:
["specific factual claim 1", "specific factual claim 2", "specific factual claim 3"]
''';
    
    try {
      final response = await sendCompletion(
        prompt: prompt,
        systemPrompt: systemPrompt,
        temperature: 0.2,
        maxTokens: 500,
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
      'totalInputTokens': _totalInputTokens,
      'totalOutputTokens': _totalOutputTokens,
      'totalTokens': _totalInputTokens + _totalOutputTokens,
      'estimatedCost': _totalCost,
      'isAvailable': isAvailable,
    };
  }
  
  @override
  Future<bool> validateApiKey(String apiKey) async {
    try {
      // Test with a minimal request to Anthropic
      final testDio = Dio();
      final response = await testDio.post(
        '${APIConstants.anthropicBaseURL}${APIConstants.anthropicMessagesEndpoint}',
        data: {
          'model': 'anthropic-3-haiku-20240307', // Use smallest model for testing
          'max_tokens': 10,
          'messages': [
            {'role': 'user', 'content': 'Hello'}
          ],
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
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
    // Anthropic 3.5 Sonnet pricing (as of 2024)
    const inputCostPer1k = 0.003; // $0.003 per 1K input tokens
    const outputCostPer1k = 0.015; // $0.015 per 1K output tokens
    
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
    'anthropic-3-5-sonnet-20241022',
    'anthropic-3-opus-20240229',
    'anthropic-3-sonnet-20240229',
    'anthropic-3-haiku-20240307',
  ];
}