import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/hud_controller.dart';
import 'package:flutter_helix/services/hud_intent.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:flutter_helix/services/provider_error_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationEngine quick ask error handling', () {
    late ConversationEngine engine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      SettingsManager.instance.assistantProfileId = 'professional';
      ConversationEngine.setLlmServiceGetter(
        () => throw StateError('missing llm provider'),
      );
      engine = ConversationEngine.instance;
      engine.clearHistory();
      await HudController.instance.resetToIdle(source: 'test.engine.setup');
    });

    test('emits a friendly missing-configuration error for quick ask', () async {
      final providerErrorFuture = engine.providerErrorStream.firstWhere(
        (state) => state != null,
      );
      final aiResponseFuture = engine.aiResponseStream.first;
      final statusEvents = <EngineStatus>[];
      final statusSub = engine.statusStream.listen(statusEvents.add);

      await engine.askQuestion('Why is the sky blue?');

      final providerError = await providerErrorFuture;
      final aiResponse = await aiResponseFuture;
      await statusSub.cancel();

      expect(providerError, isNotNull);
      expect(providerError!.kind, ProviderErrorKind.missingConfiguration);
      expect(aiResponse, contains('API key required'));
      expect(aiResponse, isNot(contains('HTTP 401')));
      expect(HudController.instance.currentIntent, HudIntent.quickAsk);
      expect(statusEvents, contains(EngineStatus.thinking));
      expect(statusEvents, contains(EngineStatus.idle));
      expect(engine.lastProviderError?.kind, ProviderErrorKind.missingConfiguration);
      expect(engine.history, isNotEmpty);
      expect(engine.history.first.assistantProfileId, 'professional');
    });
  });
}
