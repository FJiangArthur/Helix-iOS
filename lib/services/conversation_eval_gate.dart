import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'audio_experiment_harness.dart';
import 'conversation_engine.dart';
import 'database/helix_database.dart';
import 'database/project_dao.dart';
import 'llm/llm_provider.dart';
import 'llm/llm_service.dart';
import 'passive_listening_service.dart';
import 'projects/active_project_controller.dart';
import 'projects/embedding_math.dart';
import 'projects/openai_embeddings_client.dart';
import 'projects/project_rag_service.dart';
import 'settings_manager.dart';
import 'tools/tool_executor.dart';

const bool kHelixEvalGateEnabled = bool.fromEnvironment('HELIX_EVAL_GATE');
const String kHelixEvalOpenAiKey = String.fromEnvironment(
  'HELIX_TEST_OPENAI_KEY',
);
const String kHelixEvalGitSha = String.fromEnvironment(
  'HELIX_EVAL_GIT_SHA',
  defaultValue: 'unknown',
);
const String kHelixEvalSimulatorUdid = String.fromEnvironment(
  'HELIX_EVAL_SIMULATOR_UDID',
  defaultValue: '',
);

class ConversationEvalCheck {
  const ConversationEvalCheck({
    required this.id,
    required this.area,
    required this.status,
    required this.latencyMs,
    required this.expected,
    required this.actual,
    required this.details,
    this.reportOnly = false,
    this.latencyReportOnly = false,
  });

  final String id;
  final String area;
  final String status;
  final int latencyMs;
  final String expected;
  final String actual;
  final String details;
  final bool reportOnly;
  final bool latencyReportOnly;

  bool get failed => status == 'FAIL' && !reportOnly;

  Map<String, Object?> toJson() => {
    'id': id,
    'area': area,
    'status': status,
    'latencyMs': latencyMs,
    'expected': expected,
    'actual': actual,
    'details': details,
    if (reportOnly) 'reportOnly': true,
    if (latencyReportOnly) 'latencyReportOnly': true,
  };
}

class ConversationEvalReport {
  ConversationEvalReport({
    required this.startedAt,
    required this.gitSha,
    required this.simulatorUdid,
    required this.checks,
  });

  final DateTime startedAt;
  final String gitSha;
  final String simulatorUdid;
  final List<ConversationEvalCheck> checks;

  String get overall => checks.any((c) => c.failed) ? 'FAIL' : 'PASS';

  Map<String, Object?> get latencySummary {
    final hardSamples =
        checks
            .where(
              (c) =>
                  !c.reportOnly && !c.latencyReportOnly && c.status == 'PASS',
            )
            .map((c) => c.latencyMs)
            .where((v) => v >= 0)
            .toList()
          ..sort();
    int? percentile(double q) {
      if (hardSamples.isEmpty) return null;
      final index = (q * (hardSamples.length - 1)).round();
      return hardSamples[index.clamp(0, hardSamples.length - 1)];
    }

    return {
      'count': hardSamples.length,
      'p50Ms': percentile(0.50),
      'p95Ms': percentile(0.95),
      'maxMs': hardSamples.isEmpty ? null : hardSamples.last,
      'hardThresholdMs': 1000,
    };
  }

  Map<String, Object?> toJson() => {
    'overall': overall,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'gitSha': gitSha,
    'simulatorUdid': simulatorUdid,
    'latencySummary': latencySummary,
    'checks': checks.map((c) => c.toJson()).toList(),
  };

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Helix Conversation Eval Gate')
      ..writeln()
      ..writeln('- Overall: $overall')
      ..writeln('- Started: ${startedAt.toUtc().toIso8601String()}')
      ..writeln('- Git SHA: $gitSha')
      ..writeln(
        '- Simulator: ${simulatorUdid.isEmpty ? "(none)" : simulatorUdid}',
      )
      ..writeln()
      ..writeln('| ID | Area | Status | Latency | Expected | Actual |')
      ..writeln('|---|---|---:|---:|---|---|');
    for (final check in checks) {
      buffer.writeln(
        '| ${check.id} | ${check.area} | ${check.status}'
        '${check.reportOnly
            ? " (report)"
            : check.latencyReportOnly
            ? " (latency report)"
            : ""} | ${check.latencyMs}ms | '
        '${_md(check.expected)} | ${_md(check.actual)} |',
      );
    }
    return buffer.toString();
  }

  static String _md(String value) =>
      value.replaceAll('|', r'\|').replaceAll('\n', '<br>');
}

class ConversationEvalGate {
  ConversationEvalGate({
    String apiKey = kHelixEvalOpenAiKey,
    String gitSha = kHelixEvalGitSha,
    String simulatorUdid = kHelixEvalSimulatorUdid,
    AudioExperimentHarness? audioHarness,
  }) : _apiKey = apiKey,
       _gitSha = gitSha,
       _simulatorUdid = simulatorUdid,
       _audioHarness = audioHarness ?? AudioExperimentHarness();

  final String _apiKey;
  final String _gitSha;
  final String _simulatorUdid;
  final AudioExperimentHarness _audioHarness;

  Future<ConversationEvalReport> run() async {
    final checks = <ConversationEvalCheck>[];
    await ActiveProjectController.load();
    checks.add(await _runPassiveCorrectionCheck());
    checks.add(await _runPassiveNoCorrectionCheck());
    checks.add(await _runQuestionDetectionCheck());
    checks.add(await _runStatementNoAnswerCheck());
    checks.add(await _runActiveAnswerCheck());
    checks.add(await _runRagCheck());
    checks.add(await _runDeterministicWebSearchCheck());
    checks.add(await _runGptAudioTranscriptionCheck());
    return ConversationEvalReport(
      startedAt: DateTime.now(),
      gitSha: _gitSha,
      simulatorUdid: _simulatorUdid,
      checks: checks,
    );
  }

  Future<File> runAndWriteReport() async {
    final report = await run();
    final dir = await getApplicationDocumentsDirectory();
    final jsonFile = File(p.join(dir.path, 'helix_eval_report.json'));
    final mdFile = File(p.join(dir.path, 'helix_eval_report.md'));
    await jsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report.toJson()),
    );
    await mdFile.writeAsString(report.toMarkdown());
    return jsonFile;
  }

  Future<ConversationEvalCheck> _runPassiveCorrectionCheck() async {
    final started = DateTime.now();
    try {
      PassiveListeningService.resetInstance();
      final service = PassiveListeningService.instance;
      final future = service.correctionStream.first.timeout(
        const Duration(seconds: 1),
      );
      service.onTranscriptForTest({
        'script': 'The first iPhone launched in 2006.',
        'isFinal': true,
        'timestampMs': DateTime.now().millisecondsSinceEpoch,
        'language': 'en',
      });
      final alert = await future;
      final pass = alert.reminder.contains('2007') && alert.latencyMs < 1000;
      return _check(
        id: 'P1',
        area: 'passive',
        status: pass ? 'PASS' : 'FAIL',
        started: started,
        expected: 'Reminder emitted under 1s with 2007 correction',
        actual: '${alert.latencyMs}ms: ${alert.reminder}',
        details: alert.toJson().toString(),
      );
    } catch (e) {
      return _failed('P1', 'passive', started, 'Passive reminder', '$e');
    }
  }

  Future<ConversationEvalCheck> _runPassiveNoCorrectionCheck() async {
    final started = DateTime.now();
    try {
      PassiveListeningService.resetInstance();
      final service = PassiveListeningService.instance;
      var emitted = false;
      final sub = service.correctionStream.listen((_) => emitted = true);
      service.onTranscriptForTest({
        'script': 'The first iPhone launched in 2007.',
        'isFinal': true,
        'timestampMs': DateTime.now().millisecondsSinceEpoch,
        'language': 'en',
      });
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await sub.cancel();
      return _check(
        id: 'P2',
        area: 'passive',
        status: emitted ? 'FAIL' : 'PASS',
        started: started,
        expected: 'No reminder for a correct statement',
        actual: emitted ? 'correction emitted' : 'no correction emitted',
        details: 'Correct statement stays quiet',
      );
    } catch (e) {
      return _failed('P2', 'passive', started, 'No passive reminder', '$e');
    }
  }

  Future<ConversationEvalCheck> _runQuestionDetectionCheck() async {
    final started = DateTime.now();
    final engine = ConversationEngine.instance;
    try {
      final provider = _installEvalProvider(
        responses: const [
          '{"shouldRespond":true,"question":"What is Kubernetes used for?",'
              '"questionExcerpt":"What is Kubernetes used for?",'
              '"askedBy":"other"}',
          '{"chips":[],"factCheck":null}',
        ],
        streams: const [
          ['Kubernetes automates deploying and scaling containers.'],
        ],
      );
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      SettingsManager.instance.webSearchEnabled = false;
      engine.stop();
      engine.clearHistory(force: true);
      engine.start(
        mode: ConversationMode.general,
        source: TranscriptSource.phone,
      );
      final detectionFuture = engine.questionDetectionStream.first.timeout(
        const Duration(seconds: 2),
      );
      final answerFuture = engine.aiResponseStream
          .firstWhere((text) => text.contains('Kubernetes'))
          .timeout(const Duration(seconds: 2));
      engine.onTranscriptionFinalized('What is Kubernetes used for?');
      final detection = await detectionFuture;
      final answer = await answerFuture;
      final pass =
          detection.question == 'What is Kubernetes used for?' &&
          provider.streamCallCount == 1 &&
          answer.contains('containers');
      return _check(
        id: 'Q1',
        area: 'question-detection',
        status: pass ? 'PASS' : 'FAIL',
        started: started,
        expected: 'One detected question and one generated answer',
        actual: '${detection.question}; streams=${provider.streamCallCount}',
        details: answer,
      );
    } catch (e) {
      return _failed(
        'Q1',
        'question-detection',
        started,
        'Question detection + answer',
        '$e',
      );
    } finally {
      engine.stop();
    }
  }

  Future<ConversationEvalCheck> _runStatementNoAnswerCheck() async {
    final started = DateTime.now();
    final engine = ConversationEngine.instance;
    try {
      final provider = _installEvalProvider(
        responses: const [
          '{"shouldRespond":false,"question":"","questionExcerpt":""}',
        ],
      );
      SettingsManager.instance.autoDetectQuestions = true;
      SettingsManager.instance.answerAll = true;
      engine.stop();
      engine.clearHistory(force: true);
      engine.start(
        mode: ConversationMode.general,
        source: TranscriptSource.phone,
      );
      var detections = 0;
      final sub = engine.questionDetectionStream.listen((_) => detections++);
      engine.onTranscriptionFinalized('Kubernetes schedules containers.');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await sub.cancel();
      final pass = detections == 0 && provider.streamCallCount == 0;
      return _check(
        id: 'Q2',
        area: 'question-detection',
        status: pass ? 'PASS' : 'FAIL',
        started: started,
        expected: 'Statement does not trigger answer generation',
        actual: 'detections=$detections streams=${provider.streamCallCount}',
        details: 'Non-question transcript stayed quiet',
      );
    } catch (e) {
      return _failed('Q2', 'question-detection', started, 'No answer', '$e');
    } finally {
      engine.stop();
    }
  }

  Future<ConversationEvalCheck> _runActiveAnswerCheck() async {
    final started = DateTime.now();
    final engine = ConversationEngine.instance;
    try {
      _installEvalProvider(
        responses: const ['{"chips":[],"factCheck":null}'],
        streams: const [
          ['A vector database indexes embeddings for semantic retrieval.'],
        ],
      );
      SettingsManager.instance.webSearchEnabled = false;
      final answerFuture = engine.aiResponseStream
          .firstWhere((text) => text.contains('semantic retrieval'))
          .timeout(const Duration(seconds: 2));
      await engine.askQuestion('What is a vector database?');
      final answer = await answerFuture;
      final lower = answer.toLowerCase();
      final pass =
          lower.contains('embeddings') &&
          !lower.contains('you could say') &&
          !lower.contains('here is a suggestion');
      return _check(
        id: 'A1',
        area: 'active-answer',
        status: pass ? 'PASS' : 'FAIL',
        started: started,
        expected: 'Precise direct answer without meta phrasing',
        actual: answer,
        details: 'Manual active answer path',
      );
    } catch (e) {
      return _failed('A1', 'active-answer', started, 'Active answer', '$e');
    }
  }

  Future<ConversationEvalCheck> _runRagCheck() async {
    final started = DateTime.now();
    final engine = ConversationEngine.instance;
    try {
      final db = HelixDatabase.instance;
      ProjectRagService.initialize(
        db: db,
        embeddingClient: _StaticEmbeddings(Float32List.fromList([1, 0, 0])),
      );
      await ActiveProjectController.load();
      final project = await db.projectDao.createProject(
        name: 'Helix Eval Project',
      );
      final doc = await db.projectDao.insertDocument(
        projectId: project.id,
        filename: 'eval-q3.pdf',
        contentType: 'pdf',
        byteSize: 1024,
      );
      const chunk = 'Revenue was \$4.2M in Q3 for the Helix eval project.';
      await db.projectDao.saveChunksAndVectors(
        documentId: doc.id,
        projectId: project.id,
        chunks: const [
          ChunkToPersist(chunkIndex: 0, text: chunk, tokenCount: 12),
        ],
        vectors: [
          EmbeddingMath.encodeVector(Float32List.fromList([1, 0, 0])),
        ],
        embeddingModel: 'eval-static',
      );
      await db.projectDao.updateDocumentStatus(doc.id, status: 'ready');
      await ActiveProjectController.instance.setActive(project.id);

      final provider = _installEvalProvider(
        responses: const ['{"chips":[],"factCheck":null}'],
        streams: const [
          ['Q3 revenue was \$4.2M [1].'],
        ],
      );
      SettingsManager.instance.webSearchEnabled = false;
      final answerFuture = engine.aiResponseStream
          .firstWhere((text) => text.contains('\$4.2M'))
          .timeout(const Duration(seconds: 2));
      await engine.askQuestion('What was Q3 revenue?');
      final answer = await answerFuture;
      final promptHadContext = provider.capturedSystemPrompts.any(
        (prompt) =>
            prompt.contains('PROJECT CONTEXT') && prompt.contains(chunk),
      );
      final pass = promptHadContext && answer.contains('\$4.2M');
      return _check(
        id: 'R1',
        area: 'rag',
        status: pass ? 'PASS' : 'FAIL',
        started: started,
        expected: 'PROJECT CONTEXT injected and answer cites \$4.2M',
        actual: 'promptHadContext=$promptHadContext answer=$answer',
        details: 'Project ${project.id}',
        latencyReportOnly: true,
      );
    } catch (e) {
      return _failed(
        'R1',
        'rag',
        started,
        'RAG answer from project context',
        '$e',
      );
    } finally {
      await ActiveProjectController.instance.setActive(null);
    }
  }

  Future<ConversationEvalCheck> _runDeterministicWebSearchCheck() async {
    final started = DateTime.now();
    final engine = ConversationEngine.instance;
    try {
      ToolExecutor.overrideForTesting = (toolName, arguments) async {
        if (toolName != 'web_search') return 'unexpected tool';
        return 'Summary: Helix Eval Search Result confirms GPT-4.1 mini.';
      };
      _installEvalProvider(
        responses: const ['{"chips":[],"factCheck":null}'],
        toolStreams: [
          [
            ToolCallRequest(
              id: 'call_eval_search',
              name: 'web_search',
              arguments: {'query': 'GPT-4.1 mini'},
            ),
          ],
          [TextDelta('Helix Eval Search Result confirms GPT-4.1 mini.')],
        ],
      );
      SettingsManager.instance.webSearchEnabled = true;
      final answerFuture = engine.aiResponseStream
          .firstWhere((text) => text.contains('Eval Search Result'))
          .timeout(const Duration(seconds: 2));
      await engine.askQuestion(
        'What does current search say about GPT-4.1 mini?',
      );
      final answer = await answerFuture;
      return _check(
        id: 'W1',
        area: 'web-search',
        status: answer.contains('Eval Search Result') ? 'PASS' : 'FAIL',
        started: started,
        expected: 'Tool call result is synthesized into answer',
        actual: answer,
        details: 'Deterministic ToolExecutor override',
      );
    } catch (e) {
      return _failed(
        'W1',
        'web-search',
        started,
        'Deterministic tool call',
        '$e',
      );
    } finally {
      ToolExecutor.overrideForTesting = null;
      SettingsManager.instance.webSearchEnabled = false;
    }
  }

  Future<ConversationEvalCheck> _runGptAudioTranscriptionCheck() async {
    final started = DateTime.now();
    try {
      final audio = await _findEvalAudioFile();
      if (audio == null) {
        return _check(
          id: 'T1',
          area: 'transcription',
          status: 'FAIL',
          started: started,
          expected: 'At least one WAV copied into app Documents/eval_audio',
          actual: 'no WAV file found',
          details: 'Run scripts/setup_youtube_eval_audio.sh or copy a fixture',
          reportOnly: true,
        );
      }
      final result = await _audioHarness.runGptFileTranscriptionExperiment(
        filePath: audio.path,
        apiKey: await _resolvedApiKey(),
      );
      final hasEnoughText = result.wordCount >= 4;
      return _check(
        id: 'T1',
        area: 'transcription',
        status: result.status == 'PASS' && hasEnoughText ? 'PASS' : 'FAIL',
        started: started,
        expected: 'OpenAI audio transcription returns non-empty transcript',
        actual: '${result.wordCount} words from ${p.basename(audio.path)}',
        details: result.failureReason ?? result.finalTranscript,
        reportOnly: true,
      );
    } catch (e) {
      return _failed(
        'T1',
        'transcription',
        started,
        'OpenAI audio transcription',
        '$e',
        reportOnly: true,
      );
    }
  }

  Future<File?> _findEvalAudioFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory(p.join(dir.path, 'eval_audio'));
    final root = audioDir.existsSync() ? audioDir : dir;
    final wavs =
        root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.wav'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return wavs.isEmpty ? null : wavs.first;
  }

  Future<String> _resolvedApiKey() async {
    if (_apiKey.trim().isNotEmpty) return _apiKey.trim();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final config = File(p.join(dir.path, 'helix_eval_config.json'));
      if (!config.existsSync()) return '';
      final decoded = jsonDecode(await config.readAsString());
      if (decoded is Map) {
        return (decoded['apiKey'] as String? ?? '').trim();
      }
    } catch (_) {}
    return '';
  }

  _EvalProvider _installEvalProvider({
    List<String> responses = const [],
    List<List<String>> streams = const [],
    List<List<LlmResponseEvent>> toolStreams = const [],
  }) {
    final provider = _EvalProvider(
      responses: responses,
      streams: streams,
      toolStreams: toolStreams,
    );
    final llm = LlmService.instance;
    llm.registerProvider(provider);
    llm.setActiveProvider(provider.id);
    ConversationEngine.setLlmServiceGetter(() => llm);
    return provider;
  }

  ConversationEvalCheck _check({
    required String id,
    required String area,
    required String status,
    required DateTime started,
    required String expected,
    required String actual,
    required String details,
    bool reportOnly = false,
    bool latencyReportOnly = false,
  }) {
    final elapsed = DateTime.now().difference(started).inMilliseconds;
    final latencyFailed =
        !reportOnly &&
        !latencyReportOnly &&
        status == 'PASS' &&
        elapsed >= 1000;
    return ConversationEvalCheck(
      id: id,
      area: area,
      status: latencyFailed ? 'FAIL' : status,
      latencyMs: elapsed,
      expected: expected,
      actual: actual,
      details: latencyFailed
          ? 'Latency ${elapsed}ms exceeded 1000ms. $details'
          : details,
      reportOnly: reportOnly,
      latencyReportOnly: latencyReportOnly,
    );
  }

  ConversationEvalCheck _failed(
    String id,
    String area,
    DateTime started,
    String expected,
    String actual, {
    bool reportOnly = false,
  }) => _check(
    id: id,
    area: area,
    status: 'FAIL',
    started: started,
    expected: expected,
    actual: actual,
    details: actual,
    reportOnly: reportOnly,
  );
}

class _StaticEmbeddings implements EmbeddingClient {
  _StaticEmbeddings(this.vector);
  final Float32List vector;

  @override
  Future<Float32List> embed(String input) async => vector;

  @override
  Future<EmbeddingBatchResult> embedBatch(List<String> inputs) async =>
      EmbeddingBatchResult(
        vectors: List.filled(inputs.length, vector),
        promptTokens: 0,
      );
}

class _EvalProvider implements LlmProvider {
  _EvalProvider({
    List<String> responses = const [],
    List<List<String>> streams = const [],
    List<List<LlmResponseEvent>> toolStreams = const [],
  }) : _responses = Queue<String>.from(responses),
       _streams = Queue<List<String>>.from(streams),
       _toolStreams = Queue<List<LlmResponseEvent>>.from(toolStreams);

  final Queue<String> _responses;
  final Queue<List<String>> _streams;
  final Queue<List<LlmResponseEvent>> _toolStreams;
  int streamCallCount = 0;
  final List<String> capturedSystemPrompts = [];

  @override
  List<String> get availableModels => const ['helix-eval-model'];

  @override
  String get defaultModel => 'helix-eval-model';

  @override
  String get id => 'helix_eval';

  @override
  String get name => 'Helix Eval';

  @override
  Future<String> getResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async {
    capturedSystemPrompts.add(systemPrompt);
    if (_responses.isEmpty) {
      return '{"shouldRespond":false,"question":"","questionExcerpt":""}';
    }
    return _responses.removeFirst();
  }

  @override
  Stream<String> streamResponse({
    required String systemPrompt,
    required List<ChatMessage> messages,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    streamCallCount++;
    capturedSystemPrompts.add(systemPrompt);
    final chunks = _streams.isEmpty
        ? const ['eval answer']
        : _streams.removeFirst();
    for (final chunk in chunks) {
      yield chunk;
    }
  }

  @override
  Stream<LlmResponseEvent> streamWithTools({
    required String systemPrompt,
    required List<ChatMessage> messages,
    List<ToolDefinition>? tools,
    String? model,
    double temperature = 0.7,
    LlmRequestOptions? requestOptions,
    void Function(LlmResponseMetadata metadata)? onMetadata,
  }) async* {
    streamCallCount++;
    capturedSystemPrompts.add(systemPrompt);
    if (_toolStreams.isNotEmpty) {
      for (final event in _toolStreams.removeFirst()) {
        yield event;
      }
      return;
    }
    final chunks = _streams.isEmpty
        ? const ['eval answer']
        : _streams.removeFirst();
    for (final chunk in chunks) {
      yield TextDelta(chunk);
    }
  }

  @override
  Future<List<String>> queryAvailableModels({bool refresh = false}) async =>
      availableModels;

  @override
  bool supportsRealtimeModel(String model) => false;

  @override
  Future<bool> testConnection(String apiKey) async => true;

  @override
  void updateApiKey(String apiKey) {}
}
