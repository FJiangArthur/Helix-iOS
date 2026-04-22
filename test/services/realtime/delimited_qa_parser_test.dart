import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/realtime/delimited_qa_parser.dart';

void main() {
  group('DelimitedQaParser', () {
    late _ParserHarness h;

    setUp(() {
      h = _ParserHarness();
    });

    test('happy path: full markers in one delta', () {
      h.parser.addDelta(
        '§Q§\nWhat is the capital of France?\n§A§\nParis.\n§END§',
      );
      h.parser.finish();

      expect(h.question, 'What is the capital of France?');
      expect(h.answer, 'Paris.');
      expect(h.drifted, isFalse);
    });

    test('answer deltas stream token-by-token', () {
      // Each call simulates one response.output_text.delta event.
      h.parser.addDelta('§Q§\n');
      h.parser.addDelta('Hi\n§A§\n');
      h.parser.addDelta('Par');
      h.parser.addDelta('is');
      h.parser.addDelta(' is ');
      h.parser.addDelta('the capital.');
      h.parser.addDelta('\n§END§');
      h.parser.finish();

      expect(h.question, 'Hi');
      expect(h.answer, 'Paris is the capital.');
      // We expect multiple answer deltas — verify we didn't buffer everything.
      expect(h.answerDeltas.length, greaterThanOrEqualTo(3));
    });

    test('marker split across delta boundary is reassembled', () {
      h.parser.addDelta('§Q§\nWhy?\n§');
      h.parser.addDelta('A');
      h.parser.addDelta('§\nBecause.\n§END');
      h.parser.addDelta('§');
      h.parser.finish();

      expect(h.question, 'Why?');
      expect(h.answer, 'Because.');
    });

    test('NONE question and NONE answer', () {
      h.parser.addDelta('§Q§\nNONE\n§A§\nNONE\n§END§');
      h.parser.finish();

      expect(h.question, isNull);
      expect(h.answer, isNull);
      expect(h.drifted, isFalse);
    });

    test('empty stream', () {
      h.parser.finish();

      // Both complete callbacks fire with null so downstream knows the turn
      // produced nothing.
      expect(h.questionCompleteFired, isTrue);
      expect(h.answerCompleteFired, isTrue);
      expect(h.question, isNull);
      expect(h.answer, isNull);
    });

    test('drift fallback: model forgets markers and dumps plain text', () {
      // No §Q§ at all — first non-whitespace char is a letter → drift.
      h.parser.addDelta('Paris is the capital of France.');
      h.parser.finish();

      expect(h.drifted, isTrue);
      expect(h.question, isNull);
      expect(h.answer, 'Paris is the capital of France.');
    });

    test('leading whitespace before §Q§ is tolerated', () {
      h.parser.addDelta('\n  \n§Q§\nQ?\n§A§\nA.\n§END§');
      h.parser.finish();

      expect(h.question, 'Q?');
      expect(h.answer, 'A.');
      expect(h.drifted, isFalse);
    });

    test('stream cut off mid-answer still reports partial answer', () {
      h.parser.addDelta('§Q§\nWhat time?\n§A§\nIt is ');
      h.parser.finish();

      expect(h.question, 'What time?');
      expect(h.answer, 'It is');
    });

    test('stream cut off mid-question reports question with no answer', () {
      h.parser.addDelta('§Q§\nWhat time is');
      h.parser.finish();

      expect(h.question, 'What time is');
      expect(h.answer, isNull);
    });

    test('multiple reset cycles do not leak state', () {
      h.parser.addDelta('§Q§\nQ1?\n§A§\nA1.\n§END§');
      h.parser.finish();
      expect(h.question, 'Q1?');
      expect(h.answer, 'A1.');

      h.reset();
      h.parser.reset();
      h.parser.addDelta('§Q§\nQ2?\n§A§\nA2.\n§END§');
      h.parser.finish();

      expect(h.question, 'Q2?');
      expect(h.answer, 'A2.');
    });

    test('one-char-at-a-time feed is correct', () {
      const full = '§Q§\nHi?\n§A§\nYes.\n§END§';
      for (final ch in full.runes) {
        h.parser.addDelta(String.fromCharCode(ch));
      }
      h.parser.finish();

      expect(h.question, 'Hi?');
      expect(h.answer, 'Yes.');
    });
  });
}

class _ParserHarness {
  _ParserHarness() {
    parser = DelimitedQaParser(
      onQuestionDelta: (d) => questionDeltas.add(d),
      onQuestionComplete: (q) {
        questionCompleteFired = true;
        question = q;
      },
      onAnswerDelta: (d) => answerDeltas.add(d),
      onAnswerComplete: (a) {
        answerCompleteFired = true;
        answer = a;
      },
      onDrift: () => drifted = true,
    );
  }

  late final DelimitedQaParser parser;
  final List<String> questionDeltas = [];
  final List<String> answerDeltas = [];
  String? question;
  String? answer;
  bool questionCompleteFired = false;
  bool answerCompleteFired = false;
  bool drifted = false;

  void reset() {
    questionDeltas.clear();
    answerDeltas.clear();
    question = null;
    answer = null;
    questionCompleteFired = false;
    answerCompleteFired = false;
    drifted = false;
  }
}
