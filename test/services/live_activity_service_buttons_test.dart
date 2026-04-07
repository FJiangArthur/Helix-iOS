import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/live_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveActivityService buttons & filters', () {
    late StreamController<bool> recordingController;
    late StreamController<Duration> durationController;
    late StreamController<EngineStatus> statusController;
    late StreamController<ConversationMode> modeController;
    late StreamController<QuestionDetectionResult> questionController;
    late StreamController<String> answerController;
    late List<(String, dynamic)> methodCalls;
    late LiveActivityService service;
    int askCount = 0;
    int pauseCount = 0;
    int resumeCount = 0;

    LiveActivityService make() {
      return LiveActivityService.test(
        recordingStateStream: recordingController.stream,
        durationStream: durationController.stream,
        statusStream: statusController.stream,
        modeStream: modeController.stream,
        questionDetectionStream: questionController.stream,
        aiResponseStream: answerController.stream,
        invokeMethod: (method, [arguments]) async {
          methodCalls.add((method, arguments));
        },
        onAskQuestion: () async => askCount++,
        onPause: () async => pauseCount++,
        onResume: () async => resumeCount++,
      );
    }

    setUp(() {
      recordingController = StreamController<bool>.broadcast();
      durationController = StreamController<Duration>.broadcast();
      statusController = StreamController<EngineStatus>.broadcast();
      modeController = StreamController<ConversationMode>.broadcast();
      questionController =
          StreamController<QuestionDetectionResult>.broadcast();
      answerController = StreamController<String>.broadcast();
      methodCalls = <(String, dynamic)>[];
      askCount = 0;
      pauseCount = 0;
      resumeCount = 0;
      service = make();
      service.initialize();
    });

    tearDown(() async {
      await service.debugDispose();
      await recordingController.close();
      await durationController.close();
      await statusController.close();
      await modeController.close();
      await questionController.close();
      await answerController.close();
    });

    test('auto-detected questions and their answers do not update activity',
        () async {
      recordingController.add(true);
      await Future<void>.delayed(Duration.zero);
      methodCalls.clear();

      questionController.add(
        QuestionDetectionResult(
          question: 'Auto question?',
          questionExcerpt: 'Auto question?',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          priority: QuestionPriority.autoDetected,
        ),
      );
      answerController.add('Auto answer');
      await Future<void>.delayed(Duration.zero);

      final updates =
          methodCalls.where((c) => c.$1 == 'updateLiveActivity').toList();
      expect(updates, isEmpty);
    });

    test('manual questions DO update activity', () async {
      recordingController.add(true);
      await Future<void>.delayed(Duration.zero);
      methodCalls.clear();

      questionController.add(
        QuestionDetectionResult(
          question: 'Manual question?',
          questionExcerpt: 'Manual question?',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000001),
          priority: QuestionPriority.manual,
        ),
      );
      answerController.add('Manual answer');
      await Future<void>.delayed(Duration.zero);

      final updates =
          methodCalls.where((c) => c.$1 == 'updateLiveActivity').toList();
      expect(updates, isNotEmpty);
      expect(updates.last.$2['question'], 'Manual question?');
      expect(updates.last.$2['answer'], 'Manual answer');
    });

    test('native button dispatch table', () async {
      service.debugDispatchNativeButton('askQuestion');
      service.debugDispatchNativeButton('pauseTranscription');
      service.debugDispatchNativeButton('resumeTranscription');
      await Future<void>.delayed(Duration.zero);

      expect(askCount, 1);
      expect(pauseCount, 1);
      expect(resumeCount, 1);
    });

    test('pause flips status to paused in payload', () async {
      recordingController.add(true);
      await Future<void>.delayed(Duration.zero);

      service.debugDispatchNativeButton('pauseTranscription');
      await Future<void>.delayed(Duration.zero);

      final pausedUpdate = methodCalls
          .where((c) => c.$1 == 'updateLiveActivity')
          .where((c) => (c.$2 as Map)['status'] == 'paused')
          .toList();
      expect(pausedUpdate, isNotEmpty);
    });

    test('no live activity calls when never recording', () async {
      modeController.add(ConversationMode.proactive);
      statusController.add(EngineStatus.listening);
      durationController.add(const Duration(seconds: 5));
      questionController.add(
        QuestionDetectionResult(
          question: 'Q?',
          questionExcerpt: 'Q?',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000002),
          priority: QuestionPriority.manual,
        ),
      );
      answerController.add('A');
      await Future<void>.delayed(Duration.zero);

      expect(methodCalls, isEmpty);
    });

    test('recording true→false produces exactly one start/stop pair',
        () async {
      recordingController.add(true);
      await Future<void>.delayed(Duration.zero);
      recordingController.add(false);
      await Future<void>.delayed(Duration.zero);

      final starts =
          methodCalls.where((c) => c.$1 == 'startLiveActivity').length;
      final stops =
          methodCalls.where((c) => c.$1 == 'stopLiveActivity').length;
      expect(starts, 1);
      expect(stops, 1);
    });

    test('mode change while recording restarts the activity', () async {
      modeController.add(ConversationMode.general);
      recordingController.add(true);
      await Future<void>.delayed(Duration.zero);
      methodCalls.clear();

      modeController.add(ConversationMode.interview);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final names = methodCalls.map((c) => c.$1).toList();
      expect(names.contains('stopLiveActivity'), isTrue);
      expect(names.contains('startLiveActivity'), isTrue);
      final start = methodCalls.firstWhere((c) => c.$1 == 'startLiveActivity');
      expect((start.$2 as Map)['mode'], 'interview');
    });
  });
}
