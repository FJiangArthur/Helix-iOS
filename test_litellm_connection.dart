// Test script for LiteLLM provider connection
// Run with: dart test_litellm_connection.dart

import 'lib/services/ai/litellm_provider.dart';

void main() async {
  print('🚀 Testing LiteLLM Provider Connection...\n');

  // API key from environment
  const apiKey = 'REDACTED_API_KEY';

  final provider = LiteLLMProvider.instance;

  try {
    // Test 1: Initialize
    print('📡 Test 1: Initializing provider...');
    await provider.initialize(apiKey);
    print('✅ Provider initialized successfully\n');

    // Test 2: List available models
    print('📋 Test 2: Fetching available models...');
    final models = await provider.getAvailableModels();
    if (models.isNotEmpty) {
      print('✅ Available models (${models.length}):');
      for (final model in models.take(10)) {
        print('   - $model');
      }
      if (models.length > 10) {
        print('   ... and ${models.length - 10} more');
      }
    } else {
      print('⚠️  No models returned (may be expected)');
    }
    print('');

    // Test 3: Simple completion with gpt-4.1
    print('💬 Test 3: Simple completion with gpt-4.1...');
    provider.setModel('gpt-4.1');
    final response1 = await provider.complete(
      'Say "Hello from LiteLLM!" and nothing else.',
      temperature: 0.3,
      maxTokens: 50,
    );
    print('✅ Response: $response1');
    print('   Model: ${provider.currentModel}');
    print('   Total tokens used: ${provider.totalTokens}\n');

    // Test 4: Fact checking
    print('🔍 Test 4: Fact checking...');
    final factCheck = await provider.factCheck(
      'The Earth is flat',
      context: 'Testing fact-checking capability',
    );
    print('✅ Fact check result:');
    print('   Is true: ${factCheck['isTrue']}');
    print('   Confidence: ${factCheck['confidence']}');
    print('   Explanation: ${factCheck['explanation']}\n');

    // Test 5: Sentiment analysis
    print('😊 Test 5: Sentiment analysis...');
    final sentiment = await provider.analyzeSentiment(
      'I love using this AI assistant! It works great and helps me a lot.',
    );
    print('✅ Sentiment result:');
    print('   Sentiment: ${sentiment['sentiment']}');
    print('   Score: ${sentiment['score']}');
    if (sentiment['emotions'] != null) {
      print('   Emotions: ${sentiment['emotions']}');
    }
    print('');

    // Test 6: Summarization
    print('📝 Test 6: Summarization...');
    final summary = await provider.summarize(
      'The quick brown fox jumps over the lazy dog. This sentence contains every letter of the alphabet. '
      'It is often used for testing fonts and keyboards. The sentence has been used since the late 1800s.',
      maxWords: 20,
    );
    print('✅ Summary result:');
    print('   Summary: ${summary['summary']}');
    print('   Key points: ${summary['keyPoints']}\n');

    // Test 7: Try GPT-5 model
    print('🚀 Test 7: Testing GPT-5 model...');
    provider.setModel('gpt-5');
    final response2 = await provider.complete(
      'What is 2+2? Answer with just the number.',
      temperature: 0.1,
      maxTokens: 10,
    );
    print('✅ GPT-5 Response: $response2');
    print('   Model: ${provider.currentModel}\n');

    // Test 8: Try O3 reasoning model
    print('🧠 Test 8: Testing O3 reasoning model...');
    provider.setModel('o3');
    final response3 = await provider.complete(
      'If all bloops are razzles and all razzles are lazzles, are all bloops lazzles? Answer yes or no and explain briefly.',
      temperature: 0.2,
      maxTokens: 100,
    );
    print('✅ O3 Response: $response3');
    print('   Model: ${provider.currentModel}\n');

    // Final stats
    print('📊 Final Statistics:');
    print('   Total tokens used: ${provider.totalTokens}');
    print('   Provider available: ${provider.isAvailable}');
    print('   Current model: ${provider.currentModel}');

    print('\n✅ All tests completed successfully! 🎉');
  } catch (e, stackTrace) {
    print('❌ Error: $e');
    print('Stack trace:\n$stackTrace');
  } finally {
    provider.dispose();
  }
}
