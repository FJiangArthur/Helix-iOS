#!/usr/bin/env dart

/// Quick API integration test to verify custom LLM endpoint works
/// Run with: dart run test_api_integration.dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🧪 Testing Custom LLM API Integration');
  print('=' * 60);

  // Load config
  final configFile = File('llm_config.local.json');
  if (!await configFile.exists()) {
    print('❌ Error: llm_config.local.json not found!');
    print('   Create it from llm_config.local.json.template');
    exit(1);
  }

  final configJson = jsonDecode(await configFile.readAsString());
  final endpoint = configJson['llmEndpoint'] as String;
  final apiKey = configJson['llmApiKey'] as String;
  final model = configJson['llmModel'] as String;

  print('📍 Endpoint: $endpoint');
  print('🔑 API Key: ${apiKey.substring(0, 10)}...');
  print('🤖 Model: $model');
  print('');

  // Test 1: Basic Completion
  print('Test 1: Basic Chat Completion');
  print('-' * 60);
  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a helpful assistant for the Helix app.'
          },
          {
            'role': 'user',
            'content': 'Say "Helix AI ready!" in exactly 3 words.'
          }
        ],
        'temperature': 0.7,
        'max_tokens': 50,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final tokens = data['usage']['total_tokens'];
      print('✅ SUCCESS');
      print('Response: $content');
      print('Tokens: $tokens');
    } else {
      print('❌ FAILED');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      return;
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
    return;
  }

  print('');

  // Test 2: Conversation Analysis
  print('Test 2: Conversation Analysis');
  print('-' * 60);
  try {
    final conversationText = '''
User: I recorded some audio yesterday.
Assistant: Great! Did the transcription work?
User: Yes, it converted my speech to text perfectly.
Assistant: Excellent. Now we need to add AI analysis.
''';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {
            'role': 'system',
            'content':
                'You analyze conversations and provide summaries in JSON format.'
          },
          {
            'role': 'user',
            'content': '''Analyze this conversation:

$conversationText

Respond in JSON format:
{
  "summary": "brief 1-sentence summary",
  "actionItems": ["item1", "item2"],
  "topics": ["topic1", "topic2"]
}'''
          }
        ],
        'temperature': 0.3,
        'max_tokens': 200,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      print('✅ SUCCESS');
      print('Analysis:');

      // Try to parse JSON response
      try {
        final analysis = jsonDecode(content);
        print('  Summary: ${analysis['summary']}');
        print('  Topics: ${analysis['topics']}');
        print('  Action Items: ${analysis['actionItems']}');
      } catch (e) {
        print('  Raw: $content');
      }
      print('Tokens: ${data['usage']['total_tokens']}');
    } else {
      print('❌ FAILED');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');
      return;
    }
  } catch (e) {
    print('❌ EXCEPTION: $e');
    return;
  }

  print('');

  // Test 3: Model Selection
  print('Test 3: Testing Different Models');
  print('-' * 60);
  final models = configJson['llmModels'] as Map<String, dynamic>;
  print('Available models:');
  models.forEach((key, value) {
    print('  $key: $value');
  });

  // Test fast model
  print('');
  print('Testing fast model (${models['fast']})...');
  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': models['fast'],
        'messages': [
          {
            'role': 'user',
            'content': 'Reply with just the word "OK"'
          }
        ],
        'max_tokens': 10,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      print('✅ Fast model works: $content');
    } else {
      print('❌ Fast model failed: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Fast model exception: $e');
  }

  print('');
  print('=' * 60);
  print('🎉 All API integration tests completed!');
  print('');
  print('Next steps:');
  print('1. Run: flutter run -d <device-id>');
  print('2. Test recording → transcription → AI analysis');
  print('3. Check console for config loading messages');
}
