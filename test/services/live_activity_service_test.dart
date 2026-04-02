import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/live_activity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveActivityService', () {
    late StreamController<bool> recordingController;
    late StreamController<Duration> durationController;
    late StreamController<EngineStatus> statusController;
    late StreamController<ConversationMode> modeController;
    late StreamController<QuestionDetectionResult> questionController;
    late StreamController<String> answerController;
    late List<(String, dynamic)> methodCalls;
    late LiveActivityService service;

    setUp(() {
      recordingController = StreamController<bool>.broadcast();
      durationController = StreamController<Duration>.broadcast();
      statusController = StreamController<EngineStatus>.broadcast();
      modeController = StreamController<ConversationMode>.broadcast();
      questionController =
          StreamController<QuestionDetectionResult>.broadcast();
      answerController = StreamController<String>.broadcast();
      methodCalls = <(String, dynamic)>[];

      service = LiveActivityService.test(
        recordingStateStream: recordingController.stream,
        durationStream: durationController.stream,
        statusStream: statusController.stream,
        modeStream: modeController.stream,
        questionDetectionStream: questionController.stream,
        aiResponseStream: answerController.stream,
        invokeMethod: (method, [arguments]) async {
          methodCalls.add((method, arguments));
        },
      );
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

    test(
      'starts, updates, and stops the live activity for an active session',
      () async {
        modeController.add(ConversationMode.proactive);
        recordingController.add(true);
        statusController.add(EngineStatus.listening);
        durationController.add(const Duration(seconds: 5));
        questionController.add(
          QuestionDetectionResult(
            question: 'What is the rollout plan?',
            questionExcerpt: 'What is the rollout plan?',
            timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            askedBy: 'other',
          ),
        );
        answerController.add('The rollout starts next week.');
        statusController.add(EngineStatus.responding);
        await Future<void>.delayed(Duration.zero);

        expect(methodCalls.first.$1, 'startLiveActivity');
        expect(methodCalls.first.$2['mode'], 'proactive');

        final updateCalls = methodCalls
            .where((call) => call.$1 == 'updateLiveActivity')
            .toList();
        expect(updateCalls, isNotEmpty);
        expect(updateCalls.last.$2['question'], 'What is the rollout plan?');
        expect(updateCalls.last.$2['answer'], 'The rollout starts next week.');

        recordingController.add(false);
        await Future<void>.delayed(Duration.zero);
        expect(methodCalls.last.$1, 'stopLiveActivity');
      },
    );
  });
}
