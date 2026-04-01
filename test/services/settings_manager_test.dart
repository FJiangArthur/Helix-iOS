import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsManager resolved model defaults', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsManager.instance.initialize();
      SettingsManager.instance.activeProviderId = 'openai';
      SettingsManager.instance.lightModel = null;
      SettingsManager.instance.smartModel = null;
    });

    test('uses GPT-5.4 mini as the automatic OpenAI light model', () {
      expect(SettingsManager.instance.resolvedLightModel, 'gpt-5.4-mini');
    });

    test('uses GPT-5.4 as the automatic OpenAI smart model', () {
      expect(SettingsManager.instance.resolvedSmartModel, 'gpt-5.4');
    });

    test('preserves explicit model overrides', () {
      SettingsManager.instance.lightModel = 'gpt-5.4-nano';
      SettingsManager.instance.smartModel = 'gpt-4.1-mini';

      expect(SettingsManager.instance.resolvedLightModel, 'gpt-5.4-nano');
      expect(SettingsManager.instance.resolvedSmartModel, 'gpt-4.1-mini');
    });
  });
}
