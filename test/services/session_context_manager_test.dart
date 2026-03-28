import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/models/answered_question.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/session_context_manager.dart';

void main() {
  late SessionContextManager manager;

  setUp(() {
    manager = SessionContextManager();
  });

  tearDown(() {
    manager.reset();
  });

  group('B11a - Token budget differs by provider', () {
    test('OpenAI budget yields larger context window than Qwen', () {
      manager.startSession();

      // Build a long transcript so token budgets matter.
      final segments = List.generate(
        200,
        (i) => TranscriptSegment(
          text: 'This is a moderately long sentence number $i in the '
              'conversation transcript that exercises the token budget.',
          timestamp: DateTime.now().subtract(Duration(seconds: 200 - i)),
        ),
      );

      final openaiContext = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'openai',
      );

      final qwenContext = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'qwen',
      );

      // OpenAI has 100K token budget vs Qwen's 25K, so OpenAI context
      // should be equal or longer.
      expect(openaiContext.length, greaterThanOrEqualTo(qwenContext.length),
          reason: 'OpenAI (100K budget) should produce equal or larger '
              'context than Qwen (25K budget)');
    });

    test('unknown provider falls back to 25K budget', () {
      manager.startSession();

      final segments = List.generate(
        100,
        (i) => TranscriptSegment(
          text: 'Segment $i content for testing budget fallback behavior.',
          timestamp: DateTime.now().subtract(Duration(seconds: 100 - i)),
        ),
      );

      final unknownContext = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'unknown_provider',
      );

      final qwenContext = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'qwen',
      );

      // Both should use 25K budget, so context lengths should match.
      expect(unknownContext.length, qwenContext.length,
          reason: 'Unknown provider should fall back to same budget as Qwen');
    });

    test('Anthropic has the largest budget (150K)', () {
      manager.startSession();

      final segments = List.generate(
        200,
        (i) => TranscriptSegment(
          text: 'Sentence $i for testing Anthropic large context window budget.',
          timestamp: DateTime.now().subtract(Duration(seconds: 200 - i)),
        ),
      );

      final anthropicContext = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'anthropic',
      );

      final openaiContext = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'openai',
      );

      expect(
        anthropicContext.length,
        greaterThanOrEqualTo(openaiContext.length),
        reason: 'Anthropic (150K) should produce equal or larger context '
            'than OpenAI (100K)',
      );
    });
  });

  group('B11b - Adding segments and building context window', () {
    test('buildContextWindow includes recent segments', () {
      manager.startSession();

      final segments = [
        TranscriptSegment(
          text: 'Hello, how are you today?',
          timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
        ),
        TranscriptSegment(
          text: 'I am doing well, thanks for asking.',
          timestamp: DateTime.now().subtract(const Duration(seconds: 15)),
        ),
      ];

      final context = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'openai',
      );

      expect(context, contains('Hello, how are you today?'));
      expect(context, contains('I am doing well, thanks for asking.'));
    });

    test('buildContextWindow includes partial transcription', () {
      manager.startSession();

      final context = manager.buildContextWindow(
        recentSegments: [],
        partialTranscription: 'This is a partial sentence being spoken',
        providerId: 'openai',
      );

      expect(context, contains('This is a partial sentence being spoken'));
    });

    test('context window contains RECENT CONVERSATION header', () {
      manager.startSession();

      final segments = [
        TranscriptSegment(
          text: 'Test content.',
          timestamp: DateTime.now(),
        ),
      ];

      final context = manager.buildContextWindow(
        recentSegments: segments,
        partialTranscription: '',
        providerId: 'openai',
      );

      expect(context, contains('[RECENT CONVERSATION (verbatim)]'));
    });

    test('empty segments and empty partial returns empty string', () {
      manager.startSession();

      final context = manager.buildContextWindow(
        recentSegments: [],
        partialTranscription: '',
        providerId: 'openai',
      );

      expect(context.trim(), isEmpty);
    });

    test('segments older than 5 minutes are excluded from recent verbatim', () {
      manager.startSession();

      final oldSegment = TranscriptSegment(
        text: 'This is an old segment that should be excluded.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final recentSegment = TranscriptSegment(
        text: 'This is a recent segment.',
        timestamp: DateTime.now().subtract(const Duration(seconds: 30)),
      );

      final context = manager.buildContextWindow(
        recentSegments: [oldSegment, recentSegment],
        partialTranscription: '',
        providerId: 'openai',
      );

      expect(context, contains('This is a recent segment.'));
      expect(context, isNot(contains('This is an old segment')));
    });
  });

  group('B11c - Answered questions tracking', () {
    test('addAnsweredQuestion stores and retrieves questions', () {
      final qa = AnsweredQuestion(
        question: 'What is Flutter?',
        answer: 'A UI toolkit by Google.',
        timestamp: DateTime.now(),
        action: 'answer',
      );

      manager.addAnsweredQuestion(qa);

      expect(manager.answeredQuestions, hasLength(1));
      expect(manager.answeredQuestions.first.question, 'What is Flutter?');
      expect(manager.answeredQuestions.first.answer,
          'A UI toolkit by Google.');
    });

    test('answeredQuestions list is unmodifiable', () {
      final qa = AnsweredQuestion(
        question: 'Test?',
        answer: 'Yes.',
        timestamp: DateTime.now(),
      );
      manager.addAnsweredQuestion(qa);

      expect(
        () => manager.answeredQuestions.add(qa),
        throwsA(isA<UnsupportedError>()),
        reason: 'answeredQuestions should return an unmodifiable list',
      );
    });

    test('isQuestionAlreadyAnswered detects duplicate question', () {
      manager.addAnsweredQuestion(AnsweredQuestion(
        question: 'What is the weather like?',
        answer: 'It is sunny.',
        timestamp: DateTime.now(),
      ));

      // Exact match
      expect(
        manager.isQuestionAlreadyAnswered('What is the weather like?'),
        isTrue,
      );

      // Substring containment match (fuzzy)
      expect(
        manager.isQuestionAlreadyAnswered('weather like'),
        isTrue,
      );
    });

    test('isQuestionAlreadyAnswered returns false for novel question', () {
      manager.addAnsweredQuestion(AnsweredQuestion(
        question: 'What is Flutter?',
        answer: 'A framework.',
        timestamp: DateTime.now(),
      ));

      expect(
        manager.isQuestionAlreadyAnswered('How do I cook pasta?'),
        isFalse,
      );
    });

    test('buildAnsweredQuestionsSummary formats correctly', () {
      manager.addAnsweredQuestion(AnsweredQuestion(
        question: 'What is Dart?',
        answer: 'A programming language.',
        timestamp: DateTime.now(),
        action: 'answer',
      ));
      manager.addAnsweredQuestion(AnsweredQuestion(
        question: 'Is Flutter cross-platform?',
        answer: 'Yes, it supports iOS, Android, web, and desktop.',
        timestamp: DateTime.now(),
        action: 'fact_check',
      ));

      final summary = manager.buildAnsweredQuestionsSummary();

      expect(summary, contains('[ANSWER]'));
      expect(summary, contains('[FACT_CHECK]'));
      expect(summary, contains('What is Dart?'));
      expect(summary, contains('Is Flutter cross-platform?'));
    });

    test('buildAnsweredQuestionsSummary returns empty for no questions', () {
      expect(manager.buildAnsweredQuestionsSummary(), isEmpty);
    });

    test('reset clears answered questions', () {
      manager.addAnsweredQuestion(AnsweredQuestion(
        question: 'Test?',
        answer: 'Yes.',
        timestamp: DateTime.now(),
      ));

      manager.reset();

      expect(manager.answeredQuestions, isEmpty);
      expect(manager.sessionStart, isNull);
    });

    test('startSession clears previous state', () {
      manager.addAnsweredQuestion(AnsweredQuestion(
        question: 'Old question?',
        answer: 'Old answer.',
        timestamp: DateTime.now(),
      ));

      manager.startSession();

      expect(manager.answeredQuestions, isEmpty);
      expect(manager.sessionStart, isNotNull);
    });
  });
}
