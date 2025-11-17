import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_ai_provider.dart';

/// LiteLLM provider for llm.art-ai.me backend
/// Supports GPT-4.1, GPT-5, O3, and other Azure OpenAI models
class LiteLLMProvider implements BaseAIProvider {
  static LiteLLMProvider? _instance;
  static LiteLLMProvider get instance => _instance ??= LiteLLMProvider._();

  LiteLLMProvider._();

  String? _apiKey;
  bool _isInitialized = false;

  // Configuration
  static const String _baseUrl = 'https://llm.art-ai.me/v1';
  static const String _defaultModel = 'gpt-4.1'; // Use gpt-4.1 as default
  static const Duration _timeout = Duration(seconds: 30);

  // Model selection preference
  String _currentModel = _defaultModel;

  // Usage tracking
  int _totalTokens = 0;

  @override
  String get name => 'LiteLLM';

  @override
  bool get isAvailable => _isInitialized && _apiKey != null;

  int get totalTokens => _totalTokens;

  String get currentModel => _currentModel;

  /// Set the model to use for requests
  /// Available models: gpt-4.1, gpt-4.1-mini, gpt-4.1-nano, gpt-5, gpt-5-mini, o3, o1
  void setModel(String model) {
    _currentModel = model;
  }

  @override
  Future<void> initialize(String apiKey) async {
    _apiKey = apiKey;

    // Validate API key by listing available models
    final isValid = await validateApiKey(apiKey);
    if (!isValid) {
      throw Exception('Invalid LiteLLM API key');
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
      throw Exception('LiteLLM provider not initialized');
    }

    final messages = <Map<String, String>>[];

    if (systemPrompt != null) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': prompt});

    // Fix temperature for GPT-5 models (they only support temperature=1)
    final adjustedTemp = _adjustTemperatureForModel(temperature);

    final response = await _sendRequest(
      endpoint: '/chat/completions',
      body: {
        'model': _currentModel,
        'messages': messages,
        'temperature': adjustedTemp,
        'max_tokens': maxTokens,
      },
    );

    final content = response['choices'][0]['message']['content'] as String;
    final usage = response['usage'] as Map<String, dynamic>?;
    if (usage != null) {
      _totalTokens += usage['total_tokens'] as int;
    }

    return content;
  }

  /// Adjust temperature based on model requirements
  /// GPT-5 and O-series models only support temperature=1
  double _adjustTemperatureForModel(double temperature) {
    if (_currentModel.startsWith('gpt-5') ||
        _currentModel.startsWith('o1') ||
        _currentModel.startsWith('o3') ||
        _currentModel.startsWith('o4')) {
      return 1.0; // These models require temperature=1
    }
    return temperature;
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
  Future<Map<String, dynamic>> detectClaim(String text) async {
    final systemPrompt = '''You are a claim detector. Determine if the text contains a factual claim worth fact-checking.

A factual claim is:
- A statement presented as fact (not opinion or question)
- Verifiable (can be checked for accuracy)
- Specific enough to evaluate

NOT a factual claim:
- Questions ("How are you?")
- Greetings ("Hello", "Thanks")
- Opinions ("I think...", "Maybe...")
- Commands ("Please do this")
- Vague statements ("Things are good")

Respond in JSON format with keys:
- isClaim (boolean): true if text contains a factual claim
- confidence (number 0-1): how confident you are
- extractedClaim (string): the specific claim if found, or empty string''';

    final prompt = 'Text: "$text"';

    final response = await complete(
      prompt,
      systemPrompt: systemPrompt,
      temperature: 0.2, // Low temperature for consistent detection
      maxTokens: 150, // Keep it fast
    );

    try {
      final json = jsonDecode(response);
      return {
        'isClaim': json['isClaim'] as bool,
        'confidence': (json['confidence'] as num).toDouble(),
        'extractedClaim': json['extractedClaim'] as String,
      };
    } catch (e) {
      // Fallback: conservative detection
      final lowerText = text.toLowerCase().trim();

      // Quick pattern matching for obvious non-claims
      final nonClaimPatterns = [
        r'^(hello|hi|hey|thanks|thank you)', // Greetings
        r'\?$', // Questions
        r'^(i think|maybe|perhaps|probably)', // Opinions
        r'^(please|can you|could you)', // Commands
      ];

      for (final pattern in nonClaimPatterns) {
        if (RegExp(pattern).hasMatch(lowerText)) {
          return {
            'isClaim': false,
            'confidence': 0.9,
            'extractedClaim': '',
          };
        }
      }

      // If unsure, assume it might be a claim (err on the side of checking)
      return {
        'isClaim': true,
        'confidence': 0.5,
        'extractedClaim': text,
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

  /// Send HTTP request to LiteLLM API
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
        'LiteLLM API error: ${response.statusCode} - ${response.body}',
      );
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Get list of available models (for debugging/testing)
  Future<List<String>> getAvailableModels() async {
    if (!isAvailable) {
      throw Exception('LiteLLM provider not initialized');
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {'Authorization': 'Bearer $_apiKey'},
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as List;
        return data.map((model) => model['id'] as String).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
