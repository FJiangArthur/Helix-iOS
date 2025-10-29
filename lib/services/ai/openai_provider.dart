import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_ai_provider.dart';

/// OpenAI provider implementation for GPT-4 integration
/// Uses simple HTTP client for API calls
class OpenAIProvider implements BaseAIProvider {
  static OpenAIProvider? _instance;
  static OpenAIProvider get instance => _instance ??= OpenAIProvider._();

  OpenAIProvider._();

  String? _apiKey;
  bool _isInitialized = false;

  // Configuration
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _model = 'gpt-4-turbo-preview';
  static const Duration _timeout = Duration(seconds: 30);

  // Usage tracking
  int _totalTokens = 0;

  @override
  String get name => 'OpenAI';

  @override
  bool get isAvailable => _isInitialized && _apiKey != null;

  int get totalTokens => _totalTokens;

  @override
  Future<void> initialize(String apiKey) async {
    _apiKey = apiKey;

    // Validate API key
    final isValid = await validateApiKey(apiKey);
    if (!isValid) {
      throw Exception('Invalid OpenAI API key');
    }

    _isInitialized = true;
  }

  @override
  Future<String> complete(
    String prompt, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async {
    if (!isAvailable) {
      throw Exception('OpenAI provider not initialized');
    }

    final messages = <Map<String, String>>[];

    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    final response = await _sendRequest(
      endpoint: '/chat/completions',
      body: {
        'model': _model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      },
    );

    final content = response['choices'][0]['message']['content'] as String;
    final usage = response['usage'] as Map<String, dynamic>;
    _totalTokens += usage['total_tokens'] as int;

    return content;
  }

  @override
  Future<Map<String, dynamic>> factCheck(
    String claim, {
    String? context,
  }) async {
    final prompt = context != null
        ? 'Context: $context\n\nClaim: "$claim"\n\nIs this claim true? Provide a yes/no answer, confidence score (0-1), and brief explanation.'
        : 'Claim: "$claim"\n\nIs this claim true? Provide a yes/no answer, confidence score (0-1), and brief explanation.';

    final systemPrompt =
        'You are a fact-checker. Respond in JSON format with keys: isTrue (boolean), confidence (number 0-1), explanation (string).';

    final response = await complete(
      prompt,
      systemPrompt: systemPrompt,
      temperature: 0.3,
      maxTokens: 300,
    );

    try {
      // Parse JSON response
      final json = jsonDecode(response);
      return {
        'isTrue': json['isTrue'] as bool,
        'confidence': (json['confidence'] as num).toDouble(),
        'explanation': json['explanation'] as String,
      };
    } catch (e) {
      // Fallback parsing if JSON is malformed
      return {
        'isTrue': response.toLowerCase().contains('true'),
        'confidence': 0.5,
        'explanation': response,
      };
    }
  }

  @override
  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    final systemPrompt =
        'You are a sentiment analyzer. Respond in JSON format with keys: sentiment (positive/neutral/negative), score (number -1 to 1), emotions (object with emotion names and scores 0-1).';

    final prompt = 'Analyze the sentiment of: "$text"';

    final response = await complete(
      prompt,
      systemPrompt: systemPrompt,
      temperature: 0.3,
      maxTokens: 200,
    );

    try {
      final json = jsonDecode(response);
      return {
        'sentiment': json['sentiment'] as String,
        'score': (json['score'] as num).toDouble(),
        'emotions': json['emotions'] as Map<String, dynamic>?,
      };
    } catch (e) {
      return {
        'sentiment': 'neutral',
        'score': 0.0,
        'emotions': null,
      };
    }
  }

  @override
  Future<List<Map<String, dynamic>>> extractActionItems(String text) async {
    final systemPrompt =
        'You are an action item extractor. Respond in JSON format as an array of objects with keys: task (string), priority (high/medium/low), deadline (string or null).';

    final prompt = 'Extract action items from: "$text"';

    final response = await complete(
      prompt,
      systemPrompt: systemPrompt,
      temperature: 0.3,
      maxTokens: 500,
    );

    try {
      final json = jsonDecode(response);
      return (json as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>> summarize(
    String text, {
    int maxWords = 200,
  }) async {
    final systemPrompt =
        'You are a summarizer. Respond in JSON format with keys: summary (string), keyPoints (array of strings).';

    final prompt = 'Summarize in $maxWords words or less: "$text"';

    final response = await complete(
      prompt,
      systemPrompt: systemPrompt,
      temperature: 0.5,
      maxTokens: maxWords * 2,
    );

    try {
      final json = jsonDecode(response);
      return {
        'summary': json['summary'] as String,
        'keyPoints': (json['keyPoints'] as List).cast<String>(),
      };
    } catch (e) {
      return {
        'summary': response,
        'keyPoints': <String>[],
      };
    }
  }

  @override
  Future<bool> validateApiKey(String apiKey) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(_timeout);

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    _apiKey = null;
    _isInitialized = false;
    _totalTokens = 0;
  }

  /// Send HTTP request to OpenAI API
  Future<Map<String, dynamic>> _sendRequest({
    required String endpoint,
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse('$_baseUrl$endpoint');

    final response = await http
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error: ${response.statusCode} - ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
