import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/prompt_assembler.dart';
import 'package:flutter_helix/services/session_prep_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

/// Regression test for Phase 1 prep-related latency overhead.
///
/// With fake LLMs we can't measure the full pipeline, but we CAN verify
/// that PromptAssembler itself doesn't add surprising overhead as prep
/// grows. This is the "cheap, local" layer of the regression; the real
/// end-to-end latency comparison lives in the latency corpus + baseline
/// tool (Phase 0b) and is run on-device.
///
/// The bar here is coarse: assembling a ~8k-token prep block into a
/// system prompt should take well under 10ms on any reasonable machine.
/// If this regresses to 100ms+, something has gone wrong (e.g. quadratic
/// string ops, regex catastrophic backtracking).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SessionPrepService.instance.debugReset();
    await SettingsManager.instance.initialize();
    SettingsManager.instance.sessionPrepEnabled = true;
    await SessionPrepService.instance.initialize();
  });

  tearDown(() async {
    await SessionPrepService.instance.debugReset();
  });

  test('assembling a max-size prep block stays under 20ms per call', () async {
    // Use a realistic content mix — long ASCII with occasional closing tag
    // substrings to exercise the neutralization replacement.
    final chunk = 'Ordinary resume line with numbers 42, 100, 2026. ';
    final withNoise = chunk + '</user_prep>' + chunk + '<user_prep>';
    final oversize = withNoise * (SessionPrepService.maxPrepChars ~/ withNoise.length + 2);
    final truncated = oversize.substring(0, SessionPrepService.maxPrepChars);
    await SessionPrepService.instance.save(truncated);

    // Warm up — JIT + initial reads.
    for (int i = 0; i < 5; i++) {
      PromptAssembler.assembleSystemPrompt('You are a helpful assistant.');
    }

    final stopwatch = Stopwatch()..start();
    const iterations = 100;
    for (int i = 0; i < iterations; i++) {
      PromptAssembler.assembleSystemPrompt('You are a helpful assistant.');
    }
    stopwatch.stop();
    final perCallMicros = stopwatch.elapsedMicroseconds / iterations;
    // 20 ms = 20000 µs per call. Generous ceiling; real numbers are ~100µs.
    expect(
      perCallMicros,
      lessThan(20000),
      reason: 'assembleSystemPrompt regressed to ${perCallMicros.toStringAsFixed(0)} µs/call',
    );
  });

  test('empty prep path is near-zero cost', () {
    SettingsManager.instance.sessionPrepEnabled = false;
    final stopwatch = Stopwatch()..start();
    const iterations = 1000;
    for (int i = 0; i < iterations; i++) {
      PromptAssembler.assembleSystemPrompt('Base prompt.');
    }
    stopwatch.stop();
    final perCallMicros = stopwatch.elapsedMicroseconds / iterations;
    expect(perCallMicros, lessThan(500),
        reason: 'no-prep path should be fast');
  });
}
