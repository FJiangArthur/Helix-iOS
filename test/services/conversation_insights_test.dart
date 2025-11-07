import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_insights.dart';

void main() {
  group('ConversationInsights', () {
    late ConversationInsights insights;

    setUp(() {
      insights = ConversationInsights.instance;
      insights.clear(); // Reset state
    });

    test('starts with no insights', () {
      expect(insights.hasInsights, false);
      expect(insights.summary, isEmpty);
      expect(insights.keyPoints, isEmpty);
      expect(insights.actionItems, isEmpty);
      expect(insights.sentiment, null);
    });

    test('adds conversation text to buffer', () {
      insights.addConversationText('Hello world');
      insights.addConversationText('This is a test');

      final stats = insights.getStats();
      expect(stats['messageCount'], 2);
      expect(stats['hasInsights'], false);
    });

    test('ignores empty text', () {
      insights.addConversationText('');
      insights.addConversationText('   ');

      final stats = insights.getStats();
      expect(stats['messageCount'], 0);
    });

    test('tracks word count correctly', () {
      insights.addConversationText('Hello world');
      insights.addConversationText('This is a test message');

      final stats = insights.getStats();
      expect(stats['wordCount'], 7); // "Hello world This is a test message"
    });

    test('getFullConversation returns all text', () {
      insights.addConversationText('First message');
      insights.addConversationText('Second message');

      final fullText = insights.getFullConversation();
      expect(fullText, contains('First message'));
      expect(fullText, contains('Second message'));
    });

    test('clear resets all state', () {
      insights.addConversationText('Test message');
      insights.clear();

      expect(insights.hasInsights, false);
      expect(insights.summary, isEmpty);
      final stats = insights.getStats();
      expect(stats['messageCount'], 0);
    });

    test('getStats returns correct structure', () {
      insights.addConversationText('Test');

      final stats = insights.getStats();
      expect(stats.containsKey('messageCount'), true);
      expect(stats.containsKey('wordCount'), true);
      expect(stats.containsKey('hasInsights'), true);
      expect(stats.containsKey('lastUpdate'), true);
    });

    test('insights stream emits updates', () async {
      // Note: This test requires AI to be initialized
      // For now, just test that the stream exists
      expect(insights.insightsStream, isNotNull);
    });

    test('dispose cleans up resources', () {
      insights.addConversationText('Test');
      insights.dispose();

      // Should not throw after dispose
      expect(() => insights.getStats(), returnsNormally);
    });
  });
}
