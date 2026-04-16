// Phase 0 baseline-capture tool.
//
// Reads a `latency_markers.jsonl` file emitted by LatencyTracker (normally
// from $APPLICATION_DOCUMENTS_DIRECTORY on-device, but any path works here)
// and computes p50 / p95 / p99 of the (speechEndpoint → hudFirstPage)
// interval in milliseconds. Writes a baseline JSON the Phase 2 work compares
// against.
//
// Usage:
//   dart run tool/latency_baseline.dart \
//     --input <path-to-latency_markers.jsonl> \
//     --output <path-to-baseline.json>
//
// Exit codes:
//   0 — baseline written
//   1 — input missing / malformed
//   2 — no complete turns found (all turns missing either marker)

import 'dart:convert';
import 'dart:io';

const _usage = '''
Usage: dart run tool/latency_baseline.dart --input <jsonl> --output <json>

Options:
  --input  Path to latency_markers.jsonl produced by LatencyTracker.
  --output Path where baseline JSON will be written.
  --tag    Optional label stored in the output (e.g. "pre-phase-1").
  --help   Show this message.
''';

void main(List<String> args) {
  String? inputPath;
  String? outputPath;
  String tag = 'unlabeled';
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    switch (a) {
      case '--help':
      case '-h':
        stdout.writeln(_usage);
        exit(0);
      case '--input':
        inputPath = args[++i];
        break;
      case '--output':
        outputPath = args[++i];
        break;
      case '--tag':
        tag = args[++i];
        break;
      default:
        stderr.writeln('unknown flag: $a');
        stderr.writeln(_usage);
        exit(1);
    }
  }
  if (inputPath == null || outputPath == null) {
    stderr.writeln(_usage);
    exit(1);
  }

  final input = File(inputPath);
  if (!input.existsSync()) {
    stderr.writeln('input not found: $inputPath');
    exit(1);
  }

  // Read JSONL, build per-turn timestamp maps.
  final byTurn = <int, Map<String, int>>{};
  var malformed = 0;
  for (final line in input.readAsLinesSync()) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    try {
      final entry = jsonDecode(trimmed) as Map<String, Object?>;
      final turn = entry['turn'] as int?;
      final marker = entry['marker'] as String?;
      final ts = entry['ts'] as int?;
      if (turn == null || marker == null || ts == null) {
        malformed++;
        continue;
      }
      (byTurn[turn] ??= <String, int>{})[marker] = ts;
    } catch (_) {
      malformed++;
    }
  }

  if (byTurn.isEmpty) {
    stderr.writeln('no turns found in $inputPath');
    exit(2);
  }

  // End-to-end: speechEndpoint → hudFirstPage.
  final e2eMs = <int>[];
  // Sub-intervals for diagnostics: endpoint→detection, detection→llmSent,
  // llmSent→firstToken, firstToken→hudFirstPage.
  final endpointToDetection = <int>[];
  final detectionToLlmSent = <int>[];
  final llmSentToFirstToken = <int>[];
  final firstTokenToHud = <int>[];

  for (final markers in byTurn.values) {
    final endpoint = markers['speechEndpoint'];
    final detected = markers['questionDetected'];
    final sent = markers['llmRequestSent'];
    final firstTok = markers['llmFirstToken'];
    final hud = markers['hudFirstPage'];

    if (endpoint != null && hud != null) {
      e2eMs.add(hud - endpoint);
    }
    if (endpoint != null && detected != null) {
      endpointToDetection.add(detected - endpoint);
    }
    if (detected != null && sent != null) {
      detectionToLlmSent.add(sent - detected);
    }
    if (sent != null && firstTok != null) {
      llmSentToFirstToken.add(firstTok - sent);
    }
    if (firstTok != null && hud != null) {
      firstTokenToHud.add(hud - firstTok);
    }
  }

  if (e2eMs.isEmpty) {
    stderr.writeln(
      'no complete end-to-end turns '
      '(speechEndpoint→hudFirstPage) found in $inputPath',
    );
    exit(2);
  }

  Map<String, Object?> percentilesFor(List<int> samples) {
    if (samples.isEmpty) {
      return {'count': 0, 'p50': null, 'p95': null, 'p99': null};
    }
    final sorted = List<int>.from(samples)..sort();
    int pick(double q) {
      final idx = (q * (sorted.length - 1)).round();
      return sorted[idx.clamp(0, sorted.length - 1)];
    }

    return {
      'count': sorted.length,
      'p50': pick(0.50),
      'p95': pick(0.95),
      'p99': pick(0.99),
      'min': sorted.first,
      'max': sorted.last,
    };
  }

  final baseline = <String, Object?>{
    'tag': tag,
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'input': inputPath,
    'turns': byTurn.length,
    'malformed': malformed,
    'endToEndMs': percentilesFor(e2eMs),
    'stages': {
      'endpointToDetectionMs': percentilesFor(endpointToDetection),
      'detectionToLlmSentMs': percentilesFor(detectionToLlmSent),
      'llmSentToFirstTokenMs': percentilesFor(llmSentToFirstToken),
      'firstTokenToHudMs': percentilesFor(firstTokenToHud),
    },
  };

  final output = File(outputPath);
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(baseline));

  stdout.writeln('Wrote $outputPath');
  stdout.writeln('Turns with complete end-to-end: ${e2eMs.length}/${byTurn.length}');
  final e2e = baseline['endToEndMs'] as Map<String, Object?>;
  stdout.writeln('End-to-end ms — p50=${e2e['p50']} p95=${e2e['p95']} p99=${e2e['p99']}');
  if (malformed > 0) {
    stderr.writeln('note: $malformed malformed lines skipped');
  }
}
