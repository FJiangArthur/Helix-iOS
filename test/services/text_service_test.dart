import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/handoff_memory.dart';
import 'package:flutter_helix/services/hud_intent.dart';
import 'package:flutter_helix/services/text_service.dart';

void main() {
  group('TextService state reset', () {
    final controller = HudController.instance;

    setUp(() async {
      TextService.isRunning = true;
      TextService.list = ['page one', 'page two'];
      TextService.sendReplys = ['reply'];
      HandoffMemory.instance.startTransfer('page one', source: 'test.text');
      await controller.beginTextTransfer(source: 'test.setup');
    });

    test('stopTextSendingByOS clears state and returns HUD to idle', () async {
      final eventFuture = controller.intentStream.firstWhere(
        (route) => route.source == 'TextService.stopTextSendingByOS',
      );

      await TextService.get.stopTextSendingByOS();

      final route = await eventFuture;
      expect(TextService.isRunning, isFalse);
      expect(TextService.list, isEmpty);
      expect(TextService.sendReplys, isEmpty);
      expect(route.intent, HudIntent.idle);
      expect(controller.currentIntent, HudIntent.idle);
      expect(HandoffMemory.instance.current?.status, HandoffStatus.failed);
      expect(
        HandoffMemory.instance.current?.note,
        contains('interrupted'),
      );
    });
  });
}
