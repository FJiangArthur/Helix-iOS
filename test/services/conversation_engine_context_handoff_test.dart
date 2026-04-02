import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import '../helpers/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationEngine answer context handoff', () {
    late ConversationEngine engine;

    setUp(() async {
      installPlatformMocks();
      await initTestSettings(
        overrides: {
          'transcriptionBackend': 'openai',
          'autoDetectQuestions': true,
          'autoAnswerQuestions': true,
          'cloudProcessingEnabled': false,
        },
      );
      ConversationEngine.resetTestHooks();
      SettingsManager.instance.assistantProfileId = 'general';
      SettingsManager.instance.language = 'en';
      engine = ConversationEngine.instance;
      engine.clearHistory();
      engine.stop();
    });

    tearDown(() async {
      engine.clearHistory();
      removePlatformMocks();
    });

    test(
      'auto-answer includes recent transcript context with the detected question',
      () async {
        final provider = await configureFakeLlm(
          responses: const [
            '{"shouldRespond": false, "question": "", "questionExcerpt": "", "askedBy": "other"}',
            '{"shouldRespond": true, "question": "What is the rollout plan?", "questionExcerpt": "What is the rollout plan?", "askedBy": "other"}',
            '{"chips": ["Timeline?"], "factCheck": "null"}',
          ],
          streamResponses: const [
            FakeStreamResponse(['The rollout begins next week.']),
          ],
        );

        engine.start(source: TranscriptSource.phone);
        engine.onTranscriptionFinalized(
          'We are reviewing the beta launch timeline for the product.',
        );
        engine.onTranscriptionFinalized('What is the rollout plan?');
        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(provider.capturedMessages.length, greaterThanOrEqualTo(2));
        final answerMessages = provider.capturedMessages[1];

        expect(
          answerMessages.any(
            (message) => message.content.contains('beta launch timeline'),
          ),
          isTrue,
        );
        expect(
          answerMessages.any(
            (message) => message.content.contains('What is the rollout plan?'),
          ),
          isTrue,
        );
      },
    );
  });
}
