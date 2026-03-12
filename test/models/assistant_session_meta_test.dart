import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/assistant_profile.dart';
import 'package:flutter_helix/models/assistant_session_meta.dart';
import 'package:flutter_helix/services/conversation_engine.dart';

void main() {
  group('AssistantSessionMeta', () {
    test('derives summary, action items, verification candidates, and profile', () {
      final turns = [
        ConversationTurn(
          role: 'user',
          content:
              'We should review the Q2 plan, send the follow-up deck tomorrow, and confirm the budget is 120000.',
          timestamp: DateTime(2026, 3, 11, 9, 0),
          mode: 'general',
          assistantProfileId: 'professional',
        ),
        ConversationTurn(
          role: 'assistant',
          content:
              'Next steps: review the roadmap, draft the deck, and verify whether the 120000 budget figure is still current according to finance.',
          timestamp: DateTime(2026, 3, 11, 9, 2),
          mode: 'general',
          assistantProfileId: 'professional',
        ),
      ];

      final meta = AssistantSessionMeta.fromTurns(
        turns,
        profiles: AssistantProfile.defaults,
      );

      expect(meta.profileId, 'professional');
      expect(meta.profileLabel, 'Professional');
      expect(meta.modeLabel, 'General');
      expect(meta.turnCount, 2);
      expect(meta.assistantCount, 1);
      expect(meta.summaryTitle, isNotEmpty);
      expect(meta.summaryBody, contains('Even AI'));
      expect(meta.actionItems, isNotEmpty);
      expect(meta.actionItems.join(' '), contains('review'));
      expect(meta.verificationCandidates, isNotEmpty);
      expect(meta.hasActionItems, isTrue);
      expect(meta.hasFactCheckFlags, isTrue);
      expect(meta.fullTranscript, contains('You:'));
      expect(meta.searchableText, contains('budget'));
    });

    test('copyWith preserves derived content while toggling favorite', () {
      final turns = [
        ConversationTurn(
          role: 'user',
          content: 'Help me prepare for the interview.',
          timestamp: DateTime(2026, 3, 11, 10, 0),
          mode: 'interview',
          assistantProfileId: 'interview',
        ),
      ];

      final original = AssistantSessionMeta.fromTurns(turns);
      final updated = original.copyWith(isFavorite: true);

      expect(original.isFavorite, isFalse);
      expect(updated.isFavorite, isTrue);
      expect(updated.summaryTitle, original.summaryTitle);
      expect(updated.profileId, original.profileId);
      expect(updated.fullTranscript, original.fullTranscript);
    });
  });
}
