import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_helix/services/conversation_engine.dart';
import 'package:flutter_helix/services/factcheck/cited_fact_check_result.dart';
import 'package:flutter_helix/services/factcheck/web_search_provider.dart';
import 'package:flutter_helix/services/settings_manager.dart';

import '../../helpers/test_helpers.dart';

class _FakeWebSearchProvider implements WebSearchProvider {
  _FakeWebSearchProvider(this.results);
  final List<WebSearchResult> results;
  int calls = 0;

  @override
  Future<List<WebSearchResult>> search(
    String query, {
    int maxResults = 3,
  }) async {
    calls += 1;
    return results;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => installPlatformMocks());
  tearDownAll(() => removePlatformMocks());

  group('ConversationEngine active fact-check', () {
    late ConversationEngine engine;

    tearDown(() {
      engine.webSearchProviderOverride = null;
      teardownTestEngine(engine);
    });

    test('no emission when flag is off', () async {
      final setup = await setupTestEngine(responses: const []);
      engine = setup.engine;
      SettingsManager.instance.activeFactCheckEnabled = false;

      final fake = _FakeWebSearchProvider([
        const WebSearchResult(
          url: 'https://example.com/x',
          title: 'X',
          snippet: 'x',
        ),
      ]);
      engine.webSearchProviderOverride = fake;

      var emitted = 0;
      final sub = engine.citedFactCheckStream.listen((_) => emitted += 1);

      await engine.activeFactCheckForTest(
        'What year did the iPhone launch?',
        'The first iPhone launched in 2007, announced by Steve Jobs.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(emitted, 0);
      expect(fake.calls, 0);
    });

    test('emits supported verdict with sources when flag on', () async {
      final setup = await setupTestEngine(
        responses: const [
          '{"verdict":"supported","correction":null,"citedIndices":[1]}',
        ],
      );
      engine = setup.engine;
      SettingsManager.instance.activeFactCheckEnabled = true;
      // Tavily key must be non-null even though override is injected —
      // the pipeline short-circuits to the override before reading it,
      // but set it anyway to make the test robust to refactors.
      await SettingsManager.instance.setTavilyApiKey('tvly-test');

      final fake = _FakeWebSearchProvider([
        const WebSearchResult(
          url: 'https://apple.com/iphone/2007',
          title: 'iPhone launch 2007',
          snippet: 'Apple announced the iPhone on January 9, 2007.',
        ),
        const WebSearchResult(
          url: 'https://example.com/other',
          title: 'Other source',
          snippet: 'Context',
        ),
      ]);
      engine.webSearchProviderOverride = fake;

      final future = engine.citedFactCheckStream.first;
      await engine.activeFactCheckForTest(
        'What year did the iPhone launch?',
        'The first iPhone launched in 2007, announced by Steve Jobs.',
      );
      final result = await future.timeout(const Duration(seconds: 3));

      expect(fake.calls, 1);
      expect(result.verdict, FactCheckVerdict.supported);
      expect(result.correction, isNull);
      expect(result.sources, hasLength(1));
      expect(result.sources.first.url, 'https://apple.com/iphone/2007');
    });

    test('emits contradicted with correction', () async {
      final setup = await setupTestEngine(
        responses: const [
          '{"verdict":"contradicted","correction":"The iPhone launched in 2007, not 2006.","citedIndices":[1,2]}',
        ],
      );
      engine = setup.engine;
      SettingsManager.instance.activeFactCheckEnabled = true;
      await SettingsManager.instance.setTavilyApiKey('tvly-test');

      final fake = _FakeWebSearchProvider([
        const WebSearchResult(
          url: 'https://apple.com/iphone/2007',
          title: 'iPhone launch 2007',
          snippet: 'iPhone shipped June 29, 2007.',
        ),
        const WebSearchResult(
          url: 'https://wiki.example/iphone',
          title: 'iPhone history',
          snippet: 'Announced January 2007.',
        ),
      ]);
      engine.webSearchProviderOverride = fake;

      final future = engine.citedFactCheckStream.first;
      await engine.activeFactCheckForTest(
        'When did the iPhone launch?',
        'The first iPhone launched in 2006, a very long sentence to pass length gate.',
      );
      final result = await future.timeout(const Duration(seconds: 3));

      expect(result.verdict, FactCheckVerdict.contradicted);
      expect(result.correction, contains('2007'));
      expect(result.sources, hasLength(2));
    });

    test('no emission when search returns empty', () async {
      final setup = await setupTestEngine(responses: const []);
      engine = setup.engine;
      SettingsManager.instance.activeFactCheckEnabled = true;
      await SettingsManager.instance.setTavilyApiKey('tvly-test');

      engine.webSearchProviderOverride = _FakeWebSearchProvider(const []);

      var emitted = 0;
      final sub = engine.citedFactCheckStream.listen((_) => emitted += 1);

      await engine.activeFactCheckForTest(
        'anything',
        'A long enough response to satisfy the minimum length gate check.',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(emitted, 0);
    });
  });
}
