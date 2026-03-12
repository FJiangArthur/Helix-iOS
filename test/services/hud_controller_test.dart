import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/hud_intent.dart';

void main() {
  group('HudController non-screen-pushing transitions', () {
    final controller = HudController.instance;

    test('beginQuickAsk publishes a quickAsk route without screen push', () async {
      final eventFuture = controller.intentStream.firstWhere(
        (route) => route.source == 'test.quickAsk',
      );

      await controller.beginQuickAsk(source: 'test.quickAsk');

      final route = await eventFuture;
      expect(route.intent, HudIntent.quickAsk);
      expect(route.pushesScreen, isFalse);
      expect(controller.currentIntent, HudIntent.quickAsk);
    });

    test('beginTextTransfer publishes textTransfer without screen push', () async {
      final eventFuture = controller.intentStream.firstWhere(
        (route) => route.source == 'test.textTransfer',
      );

      await controller.beginTextTransfer(source: 'test.textTransfer');

      final route = await eventFuture;
      expect(route.intent, HudIntent.textTransfer);
      expect(route.pushesScreen, isFalse);
      expect(controller.currentIntent, HudIntent.textTransfer);
    });

    test('resetToIdle clears the active intent when no screen hide is requested', () async {
      await controller.beginNotification(source: 'test.notification');
      final eventFuture = controller.intentStream.firstWhere(
        (route) => route.source == 'test.idle',
      );

      await controller.resetToIdle(source: 'test.idle');

      final route = await eventFuture;
      expect(route.intent, HudIntent.idle);
      expect(route.pushesScreen, isFalse);
      expect(controller.currentIntent, HudIntent.idle);
    });
  });
}
