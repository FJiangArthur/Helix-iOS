// Real-API eval suite for Session Prep.
//
// Phase 1 success depends on the model actually grounding on the injected
// prep material. Unit tests can verify the prompt is *structured* correctly,
// but only real calls can verify the model respects the instruction.
//
// This test is SKIPPED by default. To run it:
//
//   export OPENAI_API_KEY=sk-...
//   flutter test test/eval/session_prep_eval_test.dart \
//     --dart-define=OPENAI_API_KEY=$OPENAI_API_KEY
//
// Daily budget cap: refuses to run if >10 runs in the last 24 hours.
// Tracked in ~/.gstack/evals/session-prep-budget.json. At gpt-4.1-mini
// pricing, 10 runs × 5 scenarios × ~8k input + ~200 output tokens lands
// around $1.20/day.
//
// Pass threshold: 4 of 5 scenarios must surface the expected prep fact.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/llm/llm_provider.dart';
import 'package:flutter_helix/services/llm/openai_provider.dart';
import 'package:flutter_helix/services/prompt_assembler.dart';
import 'package:flutter_helix/services/session_prep_service.dart';
import 'package:flutter_helix/services/settings_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_helpers.dart';

/// OPENAI_API_KEY is supplied via `--dart-define=OPENAI_API_KEY=...`.
const String _apiKey = String.fromEnvironment('OPENAI_API_KEY');

/// Model used for eval. gpt-4.1-mini is the same model Phase 2 uses for
/// intent classification — same tier, predictable cost, fast.
const String _evalModel = 'gpt-4.1-mini';

/// Daily cap on eval runs (per device). One "run" = one full 5-scenario
/// sweep, so this caps at 10 full sweeps per 24h.
const int _dailyRunCap = 10;

class _Scenario {
  const _Scenario({
    required this.id,
    required this.prep,
    required this.question,
    required this.expectedKeywords,
  });
  final String id;
  final String prep;
  final String question;
  final List<String> expectedKeywords;
}

const List<_Scenario> _scenarios = [
  _Scenario(
    id: 'rust-jd',
    prep:
        'Job description for Senior Backend Engineer at Foobar Corp. '
        'Required skills: 5+ years Rust experience, distributed systems, '
        'Kubernetes. Nice-to-have: GraphQL, Tokio async runtime.',
    question: 'What programming languages and skills does the role require?',
    expectedKeywords: ['Rust'],
  ),
  _Scenario(
    id: 'resume-company',
    prep:
        'RESUME — Alice Johnson\n'
        'Experience:\n'
        '• 2023-present: Senior Platform Engineer at ZephyrCloud (Seattle)\n'
        '• 2020-2023: Infrastructure Engineer at ZephyrCloud\n'
        '• 2018-2020: SRE at CobaltMetrics',
    question: 'Where does Alice currently work?',
    expectedKeywords: ['ZephyrCloud'],
  ),
  _Scenario(
    id: 'meeting-metric',
    prep:
        'Q3 Board Review Agenda\n'
        '- Revenue up 47% YoY to \$8.2M ARR\n'
        '- Churn down to 1.4% monthly\n'
        '- Two net-new enterprise logos: Acme Industries and Globex',
    question: 'How did revenue grow this quarter?',
    expectedKeywords: ['47'],
  ),
  _Scenario(
    id: 'crm-sensitivity',
    prep:
        'Customer Brief — Nova Holdings\n'
        'Primary contact: Maria Chen, VP Procurement\n'
        'Context: Price-sensitive. Rejected two prior proposals over '
        'discount terms. Responds well to volume-tier pricing.',
    question: 'What should I know about Nova Holdings before the sales call?',
    expectedKeywords: ['price-sensitive', 'volume'],
  ),
  _Scenario(
    id: 'appointment-note',
    prep:
        'Personal medical note (for user reference):\n'
        '- Severe peanut allergy — carry EpiPen\n'
        '- Blood type O+\n'
        '- Currently on lisinopril 10mg daily',
    question: 'Is there anything important I should mention about my health?',
    expectedKeywords: ['peanut'],
  ),
];

/// Path to the budget-tracking JSON. Lives under ~/.gstack/evals/ per the
/// design doc.
File _budgetFile() {
  final home = Platform.environment['HOME'] ?? '';
  return File('$home/.gstack/evals/session-prep-budget.json');
}

/// Returns true if we can run another eval within the daily cap.
bool _canRunEval() {
  final f = _budgetFile();
  if (!f.existsSync()) return true;
  try {
    final data = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
    final runs = (data['runs'] as List?)?.cast<String>() ?? const [];
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 24));
    final recent = runs.where((iso) {
      final dt = DateTime.tryParse(iso);
      return dt != null && dt.isAfter(cutoff);
    }).length;
    return recent < _dailyRunCap;
  } catch (_) {
    return true;
  }
}

void _recordEvalRun() {
  final f = _budgetFile();
  f.parent.createSync(recursive: true);
  List<String> runs = const [];
  if (f.existsSync()) {
    try {
      final data = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      runs = (data['runs'] as List?)?.cast<String>() ?? const [];
    } catch (_) {
      // reset on malformed
    }
  }
  final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 48));
  final kept = runs.where((iso) {
    final dt = DateTime.tryParse(iso);
    return dt != null && dt.isAfter(cutoff);
  }).toList();
  kept.add(DateTime.now().toUtc().toIso8601String());
  f.writeAsStringSync(jsonEncode({'runs': kept}));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    installPlatformMocks();
  });
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

  test('real-API eval: session prep surfaces specific facts in ≥4/5 scenarios',
      () async {
    if (_apiKey.isEmpty) {
      markTestSkipped(
        'OPENAI_API_KEY not provided (set via --dart-define=OPENAI_API_KEY=...)',
      );
      return;
    }
    if (!_canRunEval()) {
      markTestSkipped(
        'Daily eval cap reached ($_dailyRunCap runs / 24h). '
        'Edit ~/.gstack/evals/session-prep-budget.json to override.',
      );
      return;
    }

    final provider = OpenAiProvider();
    provider.updateApiKey(_apiKey);

    int passes = 0;
    final details = <String>[];

    for (final scenario in _scenarios) {
      await SessionPrepService.instance.save(scenario.prep);
      final systemPrompt = PromptAssembler.assembleSystemPrompt(
        'You are a helpful assistant. Be concise.',
      );
      final messages = [
        ChatMessage(role: 'user', content: scenario.question),
      ];
      final response = await provider.getResponse(
        systemPrompt: systemPrompt,
        messages: messages,
        model: _evalModel,
        temperature: 0.1,
      );

      final lower = response.toLowerCase();
      final matched = scenario.expectedKeywords.any(
        (kw) => lower.contains(kw.toLowerCase()),
      );
      if (matched) {
        passes++;
        details.add('PASS ${scenario.id}: matched expected keyword');
      } else {
        details.add(
          'FAIL ${scenario.id}: expected one of '
          '${scenario.expectedKeywords} in response: '
          '${response.substring(0, response.length.clamp(0, 160))}...',
        );
      }
    }

    _recordEvalRun();

    // Log the detail block so CI runs capture it.
    for (final line in details) {
      print('[SessionPrepEval] $line');
    }
    print('[SessionPrepEval] $passes/${_scenarios.length} scenarios passed');

    expect(
      passes,
      greaterThanOrEqualTo(4),
      reason:
          'Phase 1 success requires ≥4/5 scenarios to surface the expected '
          'prep fact. Got $passes. Details above.',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
