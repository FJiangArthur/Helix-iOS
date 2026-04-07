# Priority Pipeline + Transcription Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce an explicit priority arbiter and a continuous light-model loop for Q&A on the glasses HUD, split `conversation_engine.dart` into focused units under `lib/services/answers/`, and guarantee that pressing the Q&A button never gaps live transcription.

**Architecture:** A new `AnswerArbiter` becomes the single writer of the glasses HUD answer slot and the home-screen UI answer slot, enforcing a `userQA > factCorrection > autoAnswer` priority and a generation-counter cancellation model. A new `LightLoop` continuously calls the resolved light model with a single JSON contract returning `{question, answer, factCorrection}`; a new `SmartAnswerPipeline` runs only on Q&A press, streaming via the user's configured provider. A new `QAButtonController` debounces Q&A press events from BLE/Live Activity and calls the arbiter. The transcription gap is first diagnosed via instrumentation (Phase 0), then fixed via either audio-pipeline isolation (Fix A) or async-path isolation (Fix B).

**Tech Stack:** Flutter 3.35+, Dart, Swift 5+, iOS 26 deployment target, Drift (SQLite), GetX

**Source spec:** `/Users/artjiang/develop/Helix-iOS/docs/superpowers/specs/2026-04-06-priority-pipeline-design.md`

---

## File structure

### Files to be created

| Path | Responsibility |
|------|----------------|
| `lib/services/answers/answer_arbiter.dart` | Single writer of glasses HUD and UI answer slots; enforces priority + generation cancellation. |
| `lib/services/answers/answer_slot.dart` | Pure data: `AnswerPriority` enum, `AnswerSlot`, `QARequest`. |
| `lib/services/answers/smart_answer_pipeline.dart` | Wraps `LlmService` smart-model streaming for one Q&A request; emits generation-tagged chunks. |
| `lib/services/answers/light_loop.dart` | Continuous light-model loop driven by transcript snapshots; coalesces, backs off, hands `LightModelResult` to arbiter. |
| `lib/services/answers/light_model_contract.dart` | Pure prompt builder + JSON parser + `LightModelResult` data class. No I/O. |
| `lib/services/answers/qa_button_controller.dart` | Receives Q&A press events (BLE notifyIndex 24, Live Activity channel), 1 s debounce, calls arbiter. |
| `lib/services/answers/audio_session_coordinator.dart` (Phase 1c-A only) | Single point of `AVAudioSession` mutation gate; refuses changes while session active. Dart-side facade calling a method channel; Swift wrapper class on the iOS side. |
| `test/services/answers/answer_arbiter_test.dart` | Unit tests for every row of the §4.2 preemption table. |
| `test/services/answers/light_model_contract_test.dart` | Unit tests for prompt rendering + JSON parser. |
| `test/services/answers/qa_button_controller_test.dart` | Debounce unit tests with `FakeAsync`. |
| `test/services/answers/light_loop_test.dart` | Coalescing, backoff, token-bump cancellation. |
| `test/services/answers/smart_answer_pipeline_test.dart` | Generation tagging + cancellation drop. |
| `test/services/answers/transcription_no_gap_test.dart` | Regression test asserting no Dart-side gap > 120 ms across a Q&A press. |
| `docs/research/2026-04-06-transcription-gap-diagnosis.md` | Phase 0 deliverable: captured logs + one-line conclusion naming Fix A or Fix B. |

### Files to be modified

| Path | Change |
|------|--------|
| `lib/services/conversation_engine.dart` (2999 LOC) | Remove `_scheduleTranscriptAnalysis` (1367-1422), `_analyzeRecentTranscriptWindow` (1424-end of method), `_postResponseAnalysis` (1256-1330), `_backgroundFactCheck` (1221-1254), `_followUpChipsController` + `_factCheckAlertController` (129-166, 2526, 2763-2766), `_responseToken` machinery (59-60, 2559-2567), and the smart-response dispatch path that calls `_postResponseAnalysis` at line 2108. Engine becomes a coordinator that exposes a `Stream<TranscriptSnapshot>` consumed by `LightLoop`, and forwards Q&A press to `QAButtonController`. Target post-split LOC ≤ 1800. |
| `lib/services/conversation_listening_session.dart` (388 LOC) | Add Phase 0 instrumentation (microsecond timestamps for every speech event); no behavior change. Phase 1c-B: hoist `_engine.onTranscriptionUpdate` invocation into a microtask if profiling shows blocking. |
| `lib/services/llm/llm_service.dart` | No interface change. Verify per-request model override path is wired through `SmartAnswerPipeline` and `LightLoop`. |
| `lib/services/evenai.dart` | Replace direct calls to engine smart-response path on `notifyIndex == 24` (right touchpad / Q&A) with a call to `QAButtonController.onPress()`. |
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | Subscribe to `AnswerArbiter.hudSlot` instead of being called from inside `conversation_engine.dart`. |
| `lib/main.dart` | Wire-up: instantiate `AnswerArbiter`, `SmartAnswerPipeline`, `LightLoop`, `QAButtonController` after `ConversationEngine`. Pass dependencies. |
| `ios/Runner/SpeechStreamRecognizer.swift` (1494 LOC) | Phase 0: add `kDebugTranscriptionTiming` mach-time logging at install-tap callbacks (lines 555, 663, 1103), `pauseRecognition` / `resumeRecognition` (998, 1003), and `emitTranscript` (1162). Phase 1c-A only: route every `setCategory`/`setActive`/`installTap`/`removeTap` through the new `AudioSessionCoordinator`. |
| `ios/Runner/OpenAIRealtimeTranscriber.swift` | Phase 0 only: instrument session lifecycle. Phase 1c-A: route audio session mutations through coordinator. |
| `ios/Runner/AppDelegate.swift` | Phase 0: log mach-time on `notifyIndex == 24` and Live Activity Q&A method-channel receipt. |
| `scripts/run_gate.sh` (or its trigger list in `CLAUDE.md` / `VALIDATION.md`) | Add `lib/services/answers/**` to the FULL-gate trigger list. |

Each file has exactly one responsibility per the spec §3.1.

---

## Phase 0 — Diagnose transcription gap (instrumentation only)

Purpose: produce `docs/research/2026-04-06-transcription-gap-diagnosis.md` with timeline data proving whether Phase 1c-A (audio) or Phase 1c-B (async) is the right fix. **No production behavior changes in this phase.** All instrumentation lives behind compile-time / runtime debug flags.

### Task 0.1 — Add `kDebugTranscriptionTiming` Dart flag

**Files**
- Create: `lib/services/answers/_debug_timing.dart`
- Test: none (pure constant)

Steps:

- [ ] Create file `lib/services/answers/_debug_timing.dart` with content:
      ```dart
      /// Compile-time gate for transcription-gap diagnostic logging.
      /// Set to true locally during Phase 0 capture; must be false in committed code
      /// shipped to release builds.
      const bool kDebugTranscriptionTiming = bool.fromEnvironment(
        'HELIX_DEBUG_TRANSCRIPTION_TIMING',
        defaultValue: false,
      );
      ```
- [ ] Run `flutter analyze lib/services/answers/_debug_timing.dart` and confirm output ends with `No issues found!`.
- [ ] `git add lib/services/answers/_debug_timing.dart && git commit -m "feat(diag): add kDebugTranscriptionTiming compile-time flag"`

### Task 0.2 — Native: log mach-time on Q&A button receipt

**Files**
- Modify: `ios/Runner/AppDelegate.swift` (method-channel handler for `method.bluetooth` + Live Activity Q&A entry point)

Steps:

- [ ] In `ios/Runner/AppDelegate.swift`, add a top-of-file private helper:
      ```swift
      #if DEBUG
      private func helixDiagLog(_ tag: String, _ msg: String) {
          let t = mach_absolute_time()
          NSLog("[helix-diag] %@ mach=%llu %@", tag, t, msg)
      }
      #else
      @inline(__always) private func helixDiagLog(_ tag: String, _ msg: String) {}
      #endif
      ```
- [ ] In every method-channel handler that receives a Q&A trigger from BLE (`notifyIndex == 24` evenaiRecordOver) and from `LiveActivityManager`, add the first line `helixDiagLog("qa-press", "src=<ble|la>")`.
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add ios/Runner/AppDelegate.swift && git commit -m "feat(diag): log mach-time on Q&A press receipt"`

### Task 0.3 — Native: log mach-time on audio tap callbacks

**Files**
- Modify: `ios/Runner/SpeechStreamRecognizer.swift` lines 555, 663, 1103 (the three `installTap` callbacks); lines 998 (`pauseRecognition`), 1003 (`resumeRecognition`); line 1162 (`emitTranscript`).

Steps:

- [ ] At the start of each `installTap` callback closure (3 sites), add:
      ```swift
      #if DEBUG
      NSLog("[helix-diag] tap mach=%llu frames=%d", mach_absolute_time(), buffer.frameLength)
      #endif
      ```
- [ ] At the top of `pauseRecognition()` and `resumeRecognition()`, add `NSLog("[helix-diag] %@ mach=%llu", #function, mach_absolute_time())` inside `#if DEBUG`.
- [ ] At the top of `emitTranscript(_ text: String, isFinal: Bool)`, add:
      ```swift
      #if DEBUG
      NSLog("[helix-diag] emit mach=%llu final=%d len=%d", mach_absolute_time(), isFinal ? 1 : 0, text.count)
      #endif
      ```
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add ios/Runner/SpeechStreamRecognizer.swift && git commit -m "feat(diag): mach-time logs on tap, pause/resume, emit"`

### Task 0.4 — Dart: timestamp every speech event in `ConversationListeningSession`

**Files**
- Modify: `lib/services/conversation_listening_session.dart` (the EventChannel `listen` callback that fans out to `_engine.onTranscriptionUpdate` / `onTranscriptionFinalized`).

Steps:

- [ ] Import `_debug_timing.dart` at top: `import 'package:flutter_helix/services/answers/_debug_timing.dart';`
- [ ] In the EventChannel listener, immediately after the event is decoded, add:
      ```dart
      if (kDebugTranscriptionTiming) {
        // ignore: avoid_print
        print('[helix-diag] dart-event us=${DateTime.now().microsecondsSinceEpoch} '
              'kind=${event['type'] ?? 'unknown'}');
      }
      ```
- [ ] Run `flutter analyze lib/services/conversation_listening_session.dart` and confirm `No issues found!`.
- [ ] Run `flutter test test/services/ble_transport_policy_test.dart` and confirm all tests pass (no behavior change).
- [ ] `git add lib/services/conversation_listening_session.dart && git commit -m "feat(diag): timestamp dart speech-event arrivals"`

### Task 0.5 — Wire G1DebugService into diagnostic harness

Purpose: correlate firmware-side 0xF4 debug frames against phone-side timing so the Phase 0 capture can distinguish "gap downstream of BLE" from "gap in Dart / platform-channel / audio". Uses the pre-existing singleton at `lib/services/g1_debug_service.dart` — do NOT rewrite it.

**Files**
- Read (do not modify): `lib/services/g1_debug_service.dart`
- Modify: `lib/services/conversation_listening_session.dart` (the same listener touched in Task 0.4 — this is where Dart-side `[helix-diag] dart-event ...` logs are emitted, so firmware frames land in the same log stream with comparable timestamps).

Steps:

- [ ] Instrumentation check (replaces a failing test — the diagnostic harness has no unit test surface). Before making changes, `flutter run -d <sim-id> --dart-define=HELIX_DEBUG_TRANSCRIPTION_TIMING=true`, speak for 5 s, and confirm `grep '\[helix-diag\] firmware' <captured.log>` returns ZERO lines. This proves the wiring is absent.
- [ ] In `lib/services/conversation_listening_session.dart`, add imports at the top:
      ```dart
      import 'package:flutter_helix/services/g1_debug_service.dart';
      import 'package:flutter_helix/services/answers/_debug_timing.dart';
      ```
      (The second import may already exist from Task 0.4 — do not duplicate.)
- [ ] Add a private field and subscription handle to the session class:
      ```dart
      StreamSubscription<String>? _g1DebugDiagSub;
      ```
- [ ] In the method that starts a listening session (the same method whose EventChannel listener was instrumented in Task 0.4), immediately after the EventChannel subscription is wired, add:
      ```dart
      if (kDebugTranscriptionTiming) {
        // Phase 0 diagnostic: correlate firmware-side 0xF4 debug frames with
        // phone-side speech events. G1DebugService.enable() sends the
        // 0x23 0x6C 0x00 firmware debug-enable command and parses incoming
        // 0xF4 frames as null-terminated ASCII on its debugMessages stream.
        unawaited(G1DebugService.instance.enable());
        _g1DebugDiagSub = G1DebugService.instance.debugMessages.listen((line) {
          // Monotonic microsecond timestamp aligned with the dart-event logs
          // emitted in Task 0.4 so both streams sort into one timeline.
          // ignore: avoid_print
          print('[helix-diag] firmware us=${DateTime.now().microsecondsSinceEpoch} '
                'line=$line');
        });
      }
      ```
      If `dart:async` is not already imported for `unawaited`, add `import 'dart:async';`.
- [ ] In the method that stops / disposes the listening session, add the matching cleanup BEFORE any existing teardown that tears down the BLE stack (G1DebugService listens on `BleManager.get().eventBleReceive`, so it must disable while BLE is still up):
      ```dart
      if (_g1DebugDiagSub != null) {
        await _g1DebugDiagSub!.cancel();
        _g1DebugDiagSub = null;
        // Turn firmware debug logging back off so release users are never
        // left with 0xF4 traffic on the BLE link.
        await G1DebugService.instance.disable();
      }
      ```
- [ ] Run `flutter analyze lib/services/conversation_listening_session.dart` and confirm output ends with `No issues found!`.
- [ ] Run `flutter test test/services/ble_transport_policy_test.dart` and confirm all tests pass (the wiring is gated on `kDebugTranscriptionTiming` so production behavior is unchanged).
- [ ] Re-run the instrumentation check from the first step: `flutter run -d <sim-id> --dart-define=HELIX_DEBUG_TRANSCRIPTION_TIMING=true`, speak for 5 s while connected to glasses, and confirm `grep '\[helix-diag\] firmware' <captured.log>` now returns one or more lines interleaved with `[helix-diag] dart-event` lines. Expected sample line: `[helix-diag] firmware us=1712345678901234 line=[12:34:56.789] <firmware message>`.
- [ ] `git add lib/services/conversation_listening_session.dart && git commit -m "feat(diag): wire G1DebugService into phase 0 timing harness"`

### Task 0.6 — Capture diagnostic logs and write conclusion doc

**Files**
- Create: `docs/research/2026-04-06-transcription-gap-diagnosis.md`

Steps:

- [ ] Boot a dedicated Helix simulator (per `CLAUDE.md`) and `flutter run -d <sim-id> --dart-define=HELIX_DEBUG_TRANSCRIPTION_TIMING=true`.
- [ ] Start a session, speak continuously for 30 s, press Q&A at the 15 s mark, continue speaking for another 15 s. Capture stdout to a local file.
- [ ] Create `docs/research/2026-04-06-transcription-gap-diagnosis.md` containing: (a) the captured raw log block in a fenced code block, (b) a small table of derived gap measurements (max gap in tap timestamps, max gap in dart-event timestamps, time from press to first observed gap), (c) a one-line conclusion of the form `Conclusion: implement Fix A` OR `Conclusion: implement Fix B` OR `Conclusion: implement both`.
- [ ] `git add docs/research/2026-04-06-transcription-gap-diagnosis.md && git commit -m "docs(diag): phase 0 transcription gap diagnosis"`

### Task 0.7 — Phase 0 gate

Steps:

- [ ] Run `bash scripts/run_gate.sh` and confirm exit code 0.
- [ ] `git commit --allow-empty -m "checkpoint: phase 0 transcription gap diagnosis complete"`

---

## Phase 1a — Pure refactor: split `conversation_engine.dart`

Purpose: extract the new files under `lib/services/answers/` from the existing engine, **with zero behavior change**. Every existing test must pass before and after every commit. The arbiter is wired in trivially as a forwarder (it just calls the same methods the engine used to call) so the surface area moves but the semantics don't.

### Task 1a.1 — Create `answer_slot.dart` (pure data)

**Files**
- Create: `lib/services/answers/answer_slot.dart`
- Test: implicit (used by all later tests)

Steps:

- [ ] Create `lib/services/answers/answer_slot.dart`:
      ```dart
      /// Priority order for the answer arbiter. Lowest to highest.
      enum AnswerPriority { autoAnswer, factCorrection, userQA }

      /// One published state of the HUD or UI answer slot.
      class AnswerSlot {
        const AnswerSlot({
          required this.priority,
          required this.contentSoFar,
          required this.isStreaming,
          required this.isPrefetch,
          required this.generation,
        });

        final AnswerPriority priority;
        final String contentSoFar;
        final bool isStreaming;
        final bool isPrefetch;
        final int generation;

        static const empty = AnswerSlot(
          priority: AnswerPriority.userQA,
          contentSoFar: '',
          isStreaming: false,
          isPrefetch: false,
          generation: 0,
        );
      }

      /// One Q&A press, frozen at the moment the controller accepted it.
      class QARequest {
        const QARequest({
          required this.triggeredAt,
          required this.transcriptSnapshot,
          required this.systemPrompt,
          required this.smartModelId,
          required this.maxResponseSentences,
        });

        final DateTime triggeredAt;
        final String transcriptSnapshot;
        final String systemPrompt;
        final String smartModelId;
        final int maxResponseSentences;
      }
      ```
- [ ] Run `flutter analyze lib/services/answers/answer_slot.dart` and confirm `No issues found!`.
- [ ] `git add lib/services/answers/answer_slot.dart && git commit -m "refactor: extract AnswerSlot/QARequest data"`

### Task 1a.2 — Extract `light_model_contract.dart`

**Files**
- Create: `lib/services/answers/light_model_contract.dart`
- Read: `lib/services/conversation_engine.dart` lines 1256-1330 (`_postResponseAnalysis`), 1907-end of `_stripMarkdownCodeFence`

Steps:

- [ ] Create `lib/services/answers/light_model_contract.dart` with three public symbols:
      ```dart
      class LightModelResult {
        const LightModelResult({
          required this.question,
          required this.answer,
          required this.factCorrection,
          required this.observedAt,
        });
        final String? question;
        final String? answer;
        final String? factCorrection;
        final DateTime observedAt;
      }

      class LightModelContract {
        const LightModelContract();

        String buildPrompt({
          required String transcript,
          required String? previousAssistantAnswer,
          required int maxResponseSentences,
          required String languageCode, // 'en' or 'zh'
        }) {
          final n = maxResponseSentences;
          final prev = previousAssistantAnswer == null || previousAssistantAnswer.isEmpty
              ? 'none'
              : previousAssistantAnswer;
          final body = StringBuffer()
            ..writeln('You are a low-latency conversation assistant.')
            ..writeln('Return ONE JSON object, no prose, no code fences:')
            ..writeln('{"question": ..., "answer": ..., "factCorrection": ...}')
            ..writeln('Rules:')
            ..writeln('- "question" = the most recent question worth answering, or null.')
            ..writeln('- If "question" is set, "answer" is a direct reply in at most $n sentence(s). Never say "you could say".')
            ..writeln('- "factCorrection" = one-sentence correction if previous_assistant_answer has a factual error, else null. Do not correct style.')
            ..writeln('- All three fields may be null. Output ONLY the JSON object.')
            ..writeln()
            ..writeln('transcript:')
            ..writeln(transcript)
            ..writeln()
            ..writeln('previous_assistant_answer:')
            ..writeln(prev);
          return body.toString();
        }

        LightModelResult? parse(String raw, {DateTime? now}) {
          final stripped = _stripFences(raw).trim();
          if (stripped.isEmpty) return null;
          dynamic decoded;
          try {
            decoded = jsonDecode(stripped);
          } catch (_) {
            return null;
          }
          if (decoded is! Map) return null;
          final q = decoded['question'];
          final a = decoded['answer'];
          final f = decoded['factCorrection'];
          if (q != null && q is! String) return null;
          if (a != null && a is! String) return null;
          if (f != null && f is! String) return null;
          return LightModelResult(
            question: q as String?,
            answer: a as String?,
            factCorrection: f as String?,
            observedAt: now ?? DateTime.now(),
          );
        }

        static String _stripFences(String value) {
          var v = value.trim();
          if (v.startsWith('```')) {
            final firstNl = v.indexOf('\n');
            if (firstNl >= 0) v = v.substring(firstNl + 1);
            if (v.endsWith('```')) v = v.substring(0, v.length - 3);
          }
          return v.trim();
        }
      }
      ```
      Add `import 'dart:convert';` at the top.
- [ ] Run `flutter analyze lib/services/answers/light_model_contract.dart` and confirm `No issues found!`.
- [ ] Create `test/services/answers/light_model_contract_test.dart`:
      ```dart
      import 'package:flutter_test/flutter_test.dart';
      import 'package:flutter_helix/services/answers/light_model_contract.dart';

      void main() {
        const c = LightModelContract();
        group('buildPrompt', () {
          test('contains transcript and N=3 cap', () {
            final p = c.buildPrompt(
              transcript: 'hello world',
              previousAssistantAnswer: null,
              maxResponseSentences: 3,
              languageCode: 'en',
            );
            expect(p, contains('at most 3 sentence'));
            expect(p, contains('hello world'));
            expect(p, contains('previous_assistant_answer:\nnone'));
          });
        });
        group('parse', () {
          test('all-null is valid', () {
            final r = c.parse('{"question":null,"answer":null,"factCorrection":null}');
            expect(r, isNotNull);
            expect(r!.question, isNull);
          });
          test('question + answer', () {
            final r = c.parse('{"question":"q","answer":"a","factCorrection":null}');
            expect(r!.question, 'q');
            expect(r.answer, 'a');
          });
          test('strips ```json fence', () {
            final r = c.parse('```json\n{"question":null,"answer":null,"factCorrection":null}\n```');
            expect(r, isNotNull);
          });
          test('schema mismatch returns null', () {
            expect(c.parse('{"question":1,"answer":null,"factCorrection":null}'), isNull);
          });
          test('garbage returns null', () {
            expect(c.parse('not json at all'), isNull);
          });
          test('prose with embedded json returns null', () {
            expect(c.parse('here you go: {"question":null,"answer":null,"factCorrection":null}'), isNull);
          });
        });
      }
      ```
- [ ] Run `flutter test test/services/answers/light_model_contract_test.dart` and confirm all 6 tests pass.
- [ ] `git add lib/services/answers/light_model_contract.dart test/services/answers/light_model_contract_test.dart && git commit -m "refactor: extract LightModelContract with unit tests"`

### Task 1a.3 — Extract `qa_button_controller.dart` (no debounce yet, just the seam)

**Files**
- Create: `lib/services/answers/qa_button_controller.dart`
- Test: `test/services/answers/qa_button_controller_test.dart` (debounce tests in Phase 1b — here just a smoke test)

Steps:

- [ ] Create `lib/services/answers/qa_button_controller.dart`:
      ```dart
      import 'answer_slot.dart';

      typedef QASink = Future<void> Function(QARequest);

      /// Phase 1a stub: forwards every press through. Debounce added in Phase 1b.
      class QAButtonController {
        QAButtonController({required this.requestQA});
        final QASink requestQA;

        Future<void> onPress(QARequest req) => requestQA(req);
      }
      ```
- [ ] Run `flutter analyze lib/services/answers/qa_button_controller.dart` and confirm `No issues found!`.
- [ ] `git add lib/services/answers/qa_button_controller.dart && git commit -m "refactor: introduce QAButtonController seam"`

### Task 1a.4 — Extract `smart_answer_pipeline.dart` shell

**Files**
- Create: `lib/services/answers/smart_answer_pipeline.dart`
- Read: existing smart-response dispatch path in `conversation_engine.dart` (the path that ends at line 2108 calling `_postResponseAnalysis`)

Steps:

- [ ] Create `lib/services/answers/smart_answer_pipeline.dart`:
      ```dart
      import 'dart:async';
      import 'package:flutter_helix/services/llm/llm_service.dart';
      import 'answer_slot.dart';

      class SmartChunk {
        const SmartChunk({required this.generation, required this.delta, required this.isLast});
        final int generation;
        final String delta;
        final bool isLast;
      }

      class SmartAnswerPipeline {
        SmartAnswerPipeline(this._llm);
        final LlmService _llm;

        /// Streams chunks tagged with [generation]. Caller (arbiter) decides whether
        /// to forward each chunk based on its current generation counter.
        Stream<SmartChunk> run(QARequest req, int generation) async* {
          final stream = _llm.streamChat(
            systemPrompt: req.systemPrompt,
            userMessage: req.transcriptSnapshot,
            modelOverride: req.smartModelId,
          );
          await for (final delta in stream) {
            yield SmartChunk(generation: generation, delta: delta, isLast: false);
          }
          yield SmartChunk(generation: generation, delta: '', isLast: true);
        }
      }
      ```
      (If the actual `LlmService` streaming method has a different name, update this call to match the real signature; verify by reading `lib/services/llm/llm_service.dart` first and use the existing streaming entry point.)
- [ ] Run `flutter analyze lib/services/answers/smart_answer_pipeline.dart` and confirm `No issues found!`.
- [ ] `git add lib/services/answers/smart_answer_pipeline.dart && git commit -m "refactor: extract SmartAnswerPipeline shell"`

### Task 1a.5 — Extract `light_loop.dart` shell

**Files**
- Create: `lib/services/answers/light_loop.dart`

Steps:

- [ ] Create `lib/services/answers/light_loop.dart`:
      ```dart
      import 'dart:async';
      import 'package:flutter_helix/services/llm/llm_service.dart';
      import 'package:flutter_helix/services/settings_manager.dart';
      import 'light_model_contract.dart';

      class LightLoop {
        LightLoop({
          required LlmService llm,
          required SettingsManager settings,
          LightModelContract contract = const LightModelContract(),
        })  : _llm = llm,
              _settings = settings,
              _contract = contract;

        final LlmService _llm;
        final SettingsManager _settings;
        final LightModelContract _contract;

        final _resultsController = StreamController<LightModelResult>.broadcast();
        Stream<LightModelResult> get results => _resultsController.stream;

        int _token = 0;
        bool _inFlight = false;
        bool _rerunPending = false;
        Duration _backoff = Duration.zero;

        void start() { _token++; }
        void stop()  { _token++; _inFlight = false; _rerunPending = false; }

        /// Trigger a light call against [transcript]. Coalesces.
        Future<void> triggerOnFinalized(String transcript, String? previousAnswer) async {
          if (_inFlight) { _rerunPending = true; return; }
          _inFlight = true;
          final myToken = _token;
          try {
            if (_backoff > Duration.zero) await Future<void>.delayed(_backoff);
            final prompt = _contract.buildPrompt(
              transcript: transcript,
              previousAssistantAnswer: previousAnswer,
              maxResponseSentences: _settings.maxResponseSentences,
              languageCode: _settings.languageCode,
            );
            final raw = await _llm.getResponse(
              systemPrompt: prompt,
              userMessage: '',
              modelOverride: _settings.resolvedLightModel,
            );
            if (myToken != _token) return;
            final parsed = _contract.parse(raw);
            if (parsed != null) {
              _backoff = Duration.zero;
              _resultsController.add(parsed);
            }
          } catch (_) {
            _backoff = _backoff == Duration.zero
                ? const Duration(seconds: 1)
                : Duration(milliseconds: (_backoff.inMilliseconds * 2).clamp(1000, 30000));
          } finally {
            _inFlight = false;
            if (_rerunPending) {
              _rerunPending = false;
              unawaited(triggerOnFinalized(transcript, previousAnswer));
            }
          }
        }

        Future<void> dispose() => _resultsController.close();
      }
      ```
      (Adjust `_llm.getResponse` and `_settings.languageCode` / `_settings.resolvedLightModel` / `_settings.maxResponseSentences` getter names to match the real `LlmService` and `SettingsManager` API; read those files first to confirm.)
- [ ] Run `flutter analyze lib/services/answers/light_loop.dart` and confirm `No issues found!`.
- [ ] `git add lib/services/answers/light_loop.dart && git commit -m "refactor: extract LightLoop shell"`

### Task 1a.6 — Extract `answer_arbiter.dart` skeleton

**Files**
- Create: `lib/services/answers/answer_arbiter.dart`

Steps:

- [ ] Create `lib/services/answers/answer_arbiter.dart`:
      ```dart
      import 'dart:async';
      import 'answer_slot.dart';
      import 'light_model_contract.dart';
      import 'smart_answer_pipeline.dart';

      class AnswerArbiter {
        AnswerArbiter({required SmartAnswerPipeline smartPipeline})
            : _pipeline = smartPipeline;

        final SmartAnswerPipeline _pipeline;

        final _hudController = StreamController<AnswerSlot>.broadcast();
        final _uiController  = StreamController<AnswerSlot>.broadcast();
        final _factController = StreamController<String>.broadcast();

        Stream<AnswerSlot> get hudSlot => _hudController.stream;
        Stream<AnswerSlot> get uiSlot  => _uiController.stream;
        Stream<String>     get factAlerts => _factController.stream;

        int _qaGeneration = 0;
        LightModelResult? _latestLight;
        StreamSubscription<SmartChunk>? _activeStream;

        Future<void> requestQA(QARequest req) async {
          // Filled in Phase 1b.
          throw UnimplementedError('Phase 1a stub');
        }

        void onLightResult(LightModelResult r) {
          _latestLight = r;
          // Phase 1b fills in routing to ui/fact.
        }

        Future<void> dispose() async {
          await _activeStream?.cancel();
          await _hudController.close();
          await _uiController.close();
          await _factController.close();
        }
      }
      ```
- [ ] Run `flutter analyze lib/services/answers/answer_arbiter.dart` and confirm `No issues found!`.
- [ ] `git add lib/services/answers/answer_arbiter.dart && git commit -m "refactor: extract AnswerArbiter skeleton"`

### Task 1a.7 — Move `_followUpChipsController` and `_factCheckAlertController` out of engine

**Files**
- Modify: `lib/services/conversation_engine.dart` lines 129, 134, 161, 166, 2526, 2763-2766
- Modify: `lib/services/answers/answer_arbiter.dart` (the controllers conceptually move here as `_uiController`/`_factController` already exist; engine should now expose them via the arbiter)

Steps:

- [ ] Read `lib/services/conversation_engine.dart` lines 125-170, 2520-2530, and 2760-2770 to confirm exact content of the controllers and their stream getters.
- [ ] Add a forwarding constructor parameter to `ConversationEngine` so it accepts an optional `AnswerArbiter? arbiter`. When non-null, `followUpChipsStream` returns an empty stream and `factCheckAlertStream` returns `arbiter.factAlerts`. (Phase 1a keeps the legacy fields alive in parallel for non-arbiter wiring; Phase 1b removes them.)
- [ ] Run `flutter analyze lib/services/conversation_engine.dart` and confirm `No issues found!`.
- [ ] Run `flutter test test/services/dashboard_service_test.dart test/services/ble_transport_policy_test.dart` and confirm all pass.
- [ ] `git add lib/services/conversation_engine.dart lib/services/answers/answer_arbiter.dart && git commit -m "refactor: route fact alerts through arbiter when wired"`

### Task 1a.8 — Wire arbiter, light loop, smart pipeline, QA controller in `main.dart`

**Files**
- Modify: `lib/main.dart`

Steps:

- [ ] Read `lib/main.dart` and find the existing init block where `ConversationEngine` is constructed.
- [ ] Right after `ConversationEngine` construction, add:
      ```dart
      final smartPipeline = SmartAnswerPipeline(LlmService.instance);
      final arbiter = AnswerArbiter(smartPipeline: smartPipeline);
      final lightLoop = LightLoop(
        llm: LlmService.instance,
        settings: SettingsManager.instance,
      );
      lightLoop.results.listen(arbiter.onLightResult);
      final qaController = QAButtonController(requestQA: arbiter.requestQA);
      // Phase 1a: nothing else calls qaController yet — wired in Phase 1b.
      ```
- [ ] Add the matching imports.
- [ ] Run `flutter analyze` (whole project) and confirm `0 errors`. Warnings about unused locals are acceptable in Phase 1a but suppress with `// ignore: unused_local_variable` if `flutter analyze` flags them as errors.
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add lib/main.dart && git commit -m "refactor: wire arbiter/light loop/smart pipeline/QA controller in main"`

### Task 1a.9 — Phase 1a full gate

Steps:

- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all tests pass (no behavior change expected).
- [ ] Run `bash scripts/run_gate.sh` and confirm exit code 0.
- [ ] `git commit --allow-empty -m "checkpoint: phase 1a engine split complete"`

---

## Phase 1b — Wire priority arbiter, light contract, prefetch, debounce

Purpose: implement the actual preemption rules from spec §4.2, the 1 s Q&A debounce, the prefetch / refine flow, and the light loop's cadence rules. Behavior changes start landing here, gated by tests.

### Task 1b.1 — TDD: arbiter preemption — empty HUD + Q&A press kicks pipeline

**Files**
- Create: `test/services/answers/answer_arbiter_test.dart`
- Modify: `lib/services/answers/answer_arbiter.dart`

Steps:

- [ ] Create `test/services/answers/answer_arbiter_test.dart` with a `FakeSmartPipeline` that records `run()` calls and returns a controllable `StreamController<SmartChunk>`. First test:
      ```dart
      test('Q&A press on empty HUD publishes empty prefetch then streams smart', () async {
        final fake = FakeSmartPipeline();
        final arb = AnswerArbiter(smartPipeline: fake);
        final hudSlots = <AnswerSlot>[];
        arb.hudSlot.listen(hudSlots.add);
        await arb.requestQA(_req('what is 2+2'));
        await Future.delayed(Duration.zero);
        expect(hudSlots.first.isPrefetch, isTrue);
        expect(hudSlots.first.contentSoFar, '');
        fake.emit('4');
        fake.complete();
        await Future.delayed(Duration.zero);
        expect(hudSlots.last.contentSoFar, '4');
        expect(hudSlots.last.isPrefetch, isFalse);
      });
      ```
- [ ] Run the test, confirm it FAILS with `UnimplementedError: Phase 1a stub`.
- [ ] Implement `AnswerArbiter.requestQA` to: (a) bump `_qaGeneration`, (b) cancel `_activeStream`, (c) publish prefetch slot from `_latestLight?.answer` if observedAt within 8 s, else empty, (d) subscribe to `_pipeline.run(req, generation)`, forward chunks tagged with current generation to `_hudController` setting `isPrefetch=false`, drop chunks whose generation doesn't match.
- [ ] Run the test and confirm it passes.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] `git add test/services/answers/answer_arbiter_test.dart lib/services/answers/answer_arbiter.dart && git commit -m "feat(arbiter): Q&A press publishes prefetch then streams smart"`

### Task 1b.2 — TDD: stale chunks discarded across generations

Steps:

- [ ] Append to `answer_arbiter_test.dart`:
      ```dart
      test('chunks for stale generation are discarded', () async {
        final fake = FakeSmartPipeline();
        final arb = AnswerArbiter(smartPipeline: fake);
        final slots = <AnswerSlot>[];
        arb.hudSlot.listen(slots.add);
        await arb.requestQA(_req('first'));
        final firstStream = fake.lastStream;
        await arb.requestQA(_req('second'));
        firstStream.emit('STALE');
        await Future.delayed(Duration.zero);
        expect(slots.where((s) => s.contentSoFar == 'STALE'), isEmpty);
      });
      ```
- [ ] Run, confirm fail (slots will currently include STALE because generation guard isn't enforced).
- [ ] Add the generation guard in the chunk forwarder: `if (chunk.generation != _qaGeneration) return;`.
- [ ] Run, confirm pass. `flutter analyze` 0 errors.
- [ ] `git add test/services/answers/answer_arbiter_test.dart lib/services/answers/answer_arbiter.dart && git commit -m "feat(arbiter): drop stale-generation smart chunks"`

### Task 1b.3 — TDD: prefetch staleness window (8 s)

Steps:

- [ ] Append a test that injects a `LightModelResult` with `observedAt` 9 s before the press; expect the prefetch slot's `contentSoFar` to be empty.
- [ ] Append a second test with a 5 s old result; expect the prefetch slot's `contentSoFar` to equal `r.answer`.
- [ ] Run, confirm fail.
- [ ] Implement the 8 s staleness check in `requestQA` using an injected `Clock`-style `DateTime Function() now` (default `DateTime.now`). Add a constructor parameter `DateTime Function()? clock`.
- [ ] Run, confirm pass. `flutter analyze` 0 errors.
- [ ] `git add test/services/answers/answer_arbiter_test.dart lib/services/answers/answer_arbiter.dart && git commit -m "feat(arbiter): 8s prefetch staleness window"`

### Task 1b.4 — TDD: auto-answer routes to UI only, never HUD

Steps:

- [ ] Append:
      ```dart
      test('light auto-answer with no Q&A press never reaches HUD', () async {
        final fake = FakeSmartPipeline();
        final arb = AnswerArbiter(smartPipeline: fake);
        final hud = <AnswerSlot>[]; final ui = <AnswerSlot>[];
        arb.hudSlot.listen(hud.add);
        arb.uiSlot.listen(ui.add);
        arb.onLightResult(LightModelResult(
          question: 'q', answer: 'a', factCorrection: null,
          observedAt: DateTime.now()));
        await Future.delayed(Duration.zero);
        expect(hud, isEmpty);
        expect(ui.last.contentSoFar, 'a');
        expect(ui.last.priority, AnswerPriority.autoAnswer);
      });
      ```
- [ ] Run, confirm fail.
- [ ] Implement: in `onLightResult`, if `r.answer != null`, publish to `_uiController` only. If `r.factCorrection != null`, publish to `_factController` only.
- [ ] Run, confirm pass. `flutter analyze` 0 errors.
- [ ] `git add test/services/answers/answer_arbiter_test.dart lib/services/answers/answer_arbiter.dart && git commit -m "feat(arbiter): auto-answers UI-only, fact corrections to alerts"`

### Task 1b.5 — TDD: fact correction overrides current auto-answer in UI

Steps:

- [ ] Append a test: emit auto-answer light result; then 100 ms later emit fact correction; assert `ui.last` contains the correction text and `factAlerts` saw one event.
- [ ] Run, confirm fail.
- [ ] Implement: when `factCorrection != null`, publish a new `AnswerSlot(priority: AnswerPriority.factCorrection, contentSoFar: r.factCorrection!, isStreaming: false, isPrefetch: false, generation: _qaGeneration)` to `_uiController` AND `_factController.add(r.factCorrection!)`.
- [ ] Run, confirm pass.
- [ ] `git add test/services/answers/answer_arbiter_test.dart lib/services/answers/answer_arbiter.dart && git commit -m "feat(arbiter): fact correction overrides auto-answer in UI"`

### Task 1b.6 — TDD: smart streaming + light result during stream

Steps:

- [ ] Append a test: kick a Q&A press, while smart stream is in flight call `onLightResult` with both an answer and a fact correction. Assert HUD did not receive the light answer; UI received the auto-answer; `factAlerts` received the correction.
- [ ] Run, confirm pass (should pass with the previous implementation since `onLightResult` already does not touch HUD).
- [ ] `git add test/services/answers/answer_arbiter_test.dart && git commit -m "test(arbiter): light result during smart stream stays off HUD"`

### Task 1b.7 — TDD: smart error before any chunk preserves prefetch

Steps:

- [ ] Append a test: pre-seed `_latestLight` 2 s ago with answer "warm"; press Q&A; have `FakeSmartPipeline` error immediately. Assert `hud.last.contentSoFar == 'warm'`, `factAlerts` received the "answer may be incomplete" message.
- [ ] Run, confirm fail.
- [ ] Implement: catch errors from the pipeline subscription's `onError`, leave the prefetch slot unchanged, emit `_factController.add('answer may be incomplete')`.
- [ ] Run, confirm pass. `flutter analyze` 0 errors.
- [ ] `git add test/services/answers/answer_arbiter_test.dart lib/services/answers/answer_arbiter.dart && git commit -m "feat(arbiter): preserve prefetch on smart error"`

### Task 1b.8 — TDD: 1 s debounce in `QAButtonController`

**Files**
- Create: `test/services/answers/qa_button_controller_test.dart`
- Modify: `lib/services/answers/qa_button_controller.dart`

Steps:

- [ ] Create `test/services/answers/qa_button_controller_test.dart`:
      ```dart
      import 'package:fake_async/fake_async.dart';
      import 'package:flutter_test/flutter_test.dart';
      import 'package:flutter_helix/services/answers/qa_button_controller.dart';
      import 'package:flutter_helix/services/answers/answer_slot.dart';

      void main() {
        test('10 presses in 1s = 1 accepted', () {
          fakeAsync((async) {
            int n = 0;
            final qa = QAButtonController(
              requestQA: (_) async { n++; },
              clock: () => DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
            );
            for (var i = 0; i < 10; i++) {
              qa.onPress(_req());
              async.elapse(const Duration(milliseconds: 100));
            }
            expect(n, 1);
          });
        });
        test('press at 0 and 1.1s both accepted', () {
          fakeAsync((async) {
            int n = 0;
            final qa = QAButtonController(
              requestQA: (_) async { n++; },
              clock: () => DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
            );
            qa.onPress(_req());
            async.elapse(const Duration(milliseconds: 1100));
            qa.onPress(_req());
            expect(n, 2);
          });
        });
        test('press at 0 and 0.9s = 1 accepted', () {
          fakeAsync((async) {
            int n = 0;
            final qa = QAButtonController(
              requestQA: (_) async { n++; },
              clock: () => DateTime.fromMillisecondsSinceEpoch(async.elapsed.inMilliseconds),
            );
            qa.onPress(_req());
            async.elapse(const Duration(milliseconds: 900));
            qa.onPress(_req());
            expect(n, 1);
          });
        });
      }

      QARequest _req() => QARequest(
            triggeredAt: DateTime.now(),
            transcriptSnapshot: '',
            systemPrompt: '',
            smartModelId: 'm',
            maxResponseSentences: 3,
          );
      ```
- [ ] Run the test, confirm it FAILS to compile (controller has no `clock` param yet).
- [ ] Update `qa_button_controller.dart`:
      ```dart
      class QAButtonController {
        QAButtonController({required this.requestQA, DateTime Function()? clock})
            : _clock = clock ?? DateTime.now;
        final QASink requestQA;
        final DateTime Function() _clock;
        DateTime? _lastAccepted;

        Future<void> onPress(QARequest req) async {
          final now = _clock();
          if (_lastAccepted != null &&
              now.difference(_lastAccepted!) < const Duration(seconds: 1)) {
            return;
          }
          _lastAccepted = now;
          await requestQA(req);
        }
      }
      ```
- [ ] Run the test, confirm all 3 cases pass.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] `git add test/services/answers/qa_button_controller_test.dart lib/services/answers/qa_button_controller.dart && git commit -m "feat(qa): 1s debounce with injectable clock"`

### Task 1b.9 — Wire `QAButtonController` to BLE notifyIndex 24 and Live Activity

**Files**
- Modify: `lib/services/evenai.dart`
- Modify: `lib/main.dart` (pass the controller)

Steps:

- [ ] Read `lib/services/evenai.dart` to find the existing handler for the right-touchpad / Q&A trigger (the path that previously kicked the smart-response dispatch in the engine).
- [ ] Replace the direct engine call with `qaController.onPress(QARequest(...))`, building the request from the current transcript snapshot, system prompt, resolved smart model, and `SettingsManager.maxResponseSentences`. Read all settings BEFORE calling `onPress` to honor Phase 1c-B (no I/O inside the press path).
- [ ] If a Live Activity Q&A method-channel handler exists in `lib/services/live_activity_*.dart`, route it through the same `qaController.onPress`.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all pass.
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add lib/services/evenai.dart lib/main.dart && git commit -m "feat(qa): route BLE+Live Activity Q&A presses through controller"`

### Task 1b.10 — Light loop cadence: trigger on finalize + 3 s partial timer + coalesce

**Files**
- Modify: `lib/services/answers/light_loop.dart`
- Modify: `lib/services/conversation_engine.dart` (delete old `_scheduleTranscriptAnalysis` 1367-1422 and `_analyzeRecentTranscriptWindow`; replace call sites at 521 and 654 with `lightLoop.triggerOnFinalized(...)`)
- Create: `test/services/answers/light_loop_test.dart`

Steps:

- [ ] Read `conversation_engine.dart` lines 1367-1500 and 515-660 to confirm exact removal targets.
- [ ] Write `test/services/answers/light_loop_test.dart` with a `FakeLlmService` that records calls. Test 1: two `triggerOnFinalized` calls in immediate succession produce exactly 1 in-flight call followed by 1 coalesced rerun (total 2 LLM calls, never 3).
- [ ] Test 2: an LLM throw schedules backoff so that the next call delays by 1 s; a second throw doubles to 2 s; success resets to 0.
- [ ] Run tests, confirm fail (or pass if shell already does this — verify).
- [ ] Adjust `light_loop.dart` to satisfy the tests (existing shell already implements the logic; tighten as needed).
- [ ] In `conversation_engine.dart`, delete the now-orphaned methods and replace the two call sites with `widget.lightLoop.triggerOnFinalized(currentTranscriptText, _latestAssistantAnswer)`. Pass `lightLoop` into the engine as a constructor parameter.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all pass.
- [ ] `git add lib/services/answers/light_loop.dart lib/services/conversation_engine.dart test/services/answers/light_loop_test.dart && git commit -m "refactor: replace _scheduleTranscriptAnalysis with LightLoop"`

### Task 1b.11 — Delete `_postResponseAnalysis` and `_backgroundFactCheck`

**Files**
- Modify: `lib/services/conversation_engine.dart` (remove 1221-1330 and the call at 2108)

Steps:

- [ ] Confirm via grep that no other file imports those methods.
- [ ] Delete `_postResponseAnalysis` (1256-1330), `_backgroundFactCheck` (1221-1254), and the `unawaited(_postResponseAnalysis(...))` call at line 2108. The arbiter + light loop now handle this end-to-end.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all pass. If any test depended on the old paths, update it to assert through `arbiter.factAlerts` / `arbiter.uiSlot` instead.
- [ ] `git add lib/services/conversation_engine.dart && git commit -m "refactor: drop _postResponseAnalysis and _backgroundFactCheck"`

### Task 1b.12 — Delete legacy `_responseToken` machinery

**Files**
- Modify: `lib/services/conversation_engine.dart` (lines 60, 2559-2567)

Steps:

- [ ] Confirm no other call sites of `_responseToken`/`_isResponseCurrent` remain.
- [ ] Remove the field, `_isResponseCurrent`, and the increment helpers.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all pass.
- [ ] `git add lib/services/conversation_engine.dart && git commit -m "refactor: drop legacy _responseToken (now in arbiter)"`

### Task 1b.13 — `BitmapHudService` subscribes to `arbiter.hudSlot`

**Files**
- Modify: `lib/services/bitmap_hud/bitmap_hud_service.dart`

Steps:

- [ ] Read the existing entry point that the engine called for answer rendering. Replace the engine-side caller with a constructor `subscribe(Stream<AnswerSlot>)` invoked by `main.dart`.
- [ ] In `main.dart`: `bitmapHudService.subscribe(arbiter.hudSlot);`
- [ ] On every `AnswerSlot` event: render `slot.contentSoFar`. When `slot.isPrefetch` flips from true to false within the same generation, clear and re-render fresh (per spec §4.3 step 3).
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add lib/services/bitmap_hud/bitmap_hud_service.dart lib/main.dart && git commit -m "feat(hud): bitmap HUD subscribes to arbiter.hudSlot"`

### Task 1b.14 — Phase 1b full gate

Steps:

- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all tests pass.
- [ ] Run `bash scripts/run_gate.sh` and confirm exit code 0.
- [ ] `git commit --allow-empty -m "checkpoint: phase 1b priority arbiter wired"`

---

## Phase 1c — Apply transcription isolation fix (chosen by Phase 0)

The executor MUST read `docs/research/2026-04-06-transcription-gap-diagnosis.md` and pick exactly one of the sub-phases below — or both if Phase 0 says "implement both". Skip the unselected sub-phase entirely.

### Phase 1c-A — Audio pipeline isolation

#### Task 1c-A.1 — Audit and list every audio-session mutation

**Files**
- Read: `ios/Runner/SpeechStreamRecognizer.swift` (especially 273, 280, 543, 550, 651, 658, 1103, 1339, 1355)
- Read: `ios/Runner/OpenAIRealtimeTranscriber.swift`

Steps:

- [ ] Grep `SpeechStreamRecognizer.swift` and `OpenAIRealtimeTranscriber.swift` for `setActive`, `setCategory`, `installTap`, `removeTap`. Produce an inline list (as a comment block in `audio_session_coordinator.swift`) of every site, file:line, and the lifecycle event that should own it.
- [ ] `git commit --allow-empty -m "audit: audio session mutation sites enumerated"`

#### Task 1c-A.2 — Create `AudioSessionCoordinator` (Swift)

**Files**
- Create: `ios/Runner/AudioSessionCoordinator.swift`

Steps:

- [ ] Create `ios/Runner/AudioSessionCoordinator.swift`:
      ```swift
      import AVFoundation

      /// Single owner of AVAudioSession mutations during a recording session.
      /// Refuses category/active changes while a session is active so that
      /// downstream code (LLM HTTP, voice assistant) cannot drop the input tap.
      final class AudioSessionCoordinator {
          static let shared = AudioSessionCoordinator()
          private(set) var isSessionActive = false
          private let queue = DispatchQueue(label: "helix.audio.coord")

          func beginSession(category: AVAudioSession.Category, options: AVAudioSession.CategoryOptions) throws {
              try queue.sync {
                  let s = AVAudioSession.sharedInstance()
                  try s.setCategory(category, options: options)
                  try s.setActive(true, options: .notifyOthersOnDeactivation)
                  isSessionActive = true
              }
          }

          func endSession() {
              queue.sync {
                  guard isSessionActive else { return }
                  try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                  isSessionActive = false
              }
          }

          /// Reject mid-session mutations from any other site.
          func mutateGuarded(_ block: () throws -> Void) rethrows {
              try queue.sync {
                  guard !isSessionActive else {
                      NSLog("[helix-audio] mutation rejected: session active")
                      return
                  }
                  try block()
              }
          }
      }
      ```
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add ios/Runner/AudioSessionCoordinator.swift && git commit -m "feat(audio): introduce AudioSessionCoordinator"`

#### Task 1c-A.3 — Route SpeechStreamRecognizer through coordinator

**Files**
- Modify: `ios/Runner/SpeechStreamRecognizer.swift` lines 273-281, 543-551, 651-659, 1339

Steps:

- [ ] Replace each `try audioSession.setCategory(...); try audioSession.setActive(true, ...)` pair with `try AudioSessionCoordinator.shared.beginSession(category: ..., options: ...)`.
- [ ] Replace `try AVAudioSession.sharedInstance().setActive(false, ...)` near line 1339 with `AudioSessionCoordinator.shared.endSession()`.
- [ ] Ensure `installTap` calls happen INSIDE the same lifecycle (begin → installTap → tap callbacks → removeTap → end). Do not relocate; just confirm.
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add ios/Runner/SpeechStreamRecognizer.swift && git commit -m "feat(audio): route Speech recognizer through coordinator"`

#### Task 1c-A.4 — Route OpenAIRealtimeTranscriber through coordinator

**Files**
- Modify: `ios/Runner/OpenAIRealtimeTranscriber.swift`

Steps:

- [ ] Replace any `setActive`/`setCategory` calls with `AudioSessionCoordinator.shared.mutateGuarded { ... }` or `beginSession` if it owns the lifecycle.
- [ ] Run `flutter build ios --simulator --no-codesign` and confirm `BUILD SUCCEEDED`.
- [ ] `git add ios/Runner/OpenAIRealtimeTranscriber.swift && git commit -m "feat(audio): route OpenAI realtime through coordinator"`

#### Task 1c-A.5 — Validate Fix A on simulator with Phase 0 instrumentation

Steps:

- [ ] Boot a dedicated Helix simulator. `flutter run -d <sim-id> --dart-define=HELIX_DEBUG_TRANSCRIPTION_TIMING=true`.
- [ ] Re-run the §7.1 protocol: 30 s speech with Q&A press at 15 s. Capture stdout.
- [ ] Append the captured logs and a "Post-Fix-A measurements" section to `docs/research/2026-04-06-transcription-gap-diagnosis.md`. Confirm max tap-callback gap < 100 ms. If not, the fix is incomplete — investigate before proceeding.
- [ ] `git add docs/research/2026-04-06-transcription-gap-diagnosis.md && git commit -m "docs(diag): post-Fix-A validation captures"`

### Phase 1c-B — Async path isolation

#### Task 1c-B.1 — Make press path strictly synchronous and pre-snapshotted

**Files**
- Modify: `lib/services/answers/qa_button_controller.dart`
- Modify: `lib/services/answers/answer_arbiter.dart`
- Modify: `lib/services/evenai.dart` (Q&A entry point)

Steps:

- [ ] Audit `QAButtonController.onPress`: confirm it does only the debounce check + `requestQA` call. No `await`s on settings, no I/O. Already enforced in Task 1b.8 — confirm.
- [ ] Audit `AnswerArbiter.requestQA`: ensure it returns immediately after publishing the prefetch slot. The smart pipeline subscription is started via `unawaited(...)`. The HTTP call inside `_pipeline.run` must already be on a microtask boundary (via `Stream` semantics).
- [ ] In `evenai.dart` Q&A handler: read `SettingsManager.maxResponseSentences`, resolved smart model, system prompt, and the current transcript snapshot BEFORE calling `qaController.onPress`. Pre-build the `QARequest` so the press path does no settings reads.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all pass.
- [ ] `git add lib/services/answers/qa_button_controller.dart lib/services/answers/answer_arbiter.dart lib/services/evenai.dart && git commit -m "perf(qa): press path is sync, fully pre-snapshotted"`

#### Task 1c-B.2 — Hoist `_engine.onTranscriptionUpdate` into a microtask if blocking

**Files**
- Modify: `lib/services/conversation_listening_session.dart` lines 109-183

Steps:

- [ ] Read lines 109-183 to find the EventChannel listener body that calls `_engine.onTranscriptionUpdate(...)`.
- [ ] If the engine method is non-trivial (after Phase 1a it should be a small store-and-emit), wrap the call in `scheduleMicrotask(() => _engine.onTranscriptionUpdate(...))` so the EventChannel handler returns immediately.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all pass.
- [ ] `git add lib/services/conversation_listening_session.dart && git commit -m "perf(session): drain speech events to microtask"`

#### Task 1c-B.3 — Validate Fix B on simulator with Phase 0 instrumentation

Steps:

- [ ] Re-run the §7.1 protocol with `--dart-define=HELIX_DEBUG_TRANSCRIPTION_TIMING=true` on a dedicated simulator. Capture stdout.
- [ ] Append a "Post-Fix-B measurements" section to `docs/research/2026-04-06-transcription-gap-diagnosis.md` with measured gaps. Confirm max Dart-side speech-event gap < 100 ms (above baseline jitter).
- [ ] `git add docs/research/2026-04-06-transcription-gap-diagnosis.md && git commit -m "docs(diag): post-Fix-B validation captures"`

### Task 1c.X — Phase 1c full gate

Steps:

- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all pass.
- [ ] Run `bash scripts/run_gate.sh` and confirm exit code 0.
- [ ] `git commit --allow-empty -m "checkpoint: phase 1c transcription isolation applied"`

---

## Phase 2 — Regression test: synthetic stream + Q&A press, no >100 ms gap

### Task 2.1 — Write the regression test

**Files**
- Create: `test/services/answers/transcription_no_gap_test.dart`

Steps:

- [ ] Read `lib/services/conversation_listening_session.dart` lines 30-60 to confirm the `.test()` factory signature.
- [ ] Read `test/helpers/test_helpers.dart` to identify available helpers (`FakeJsonProvider`, `FakeStreamResponse`).
- [ ] Create `test/services/answers/transcription_no_gap_test.dart`:
      ```dart
      import 'dart:async';
      import 'package:flutter_test/flutter_test.dart';
      import 'package:flutter_helix/services/conversation_engine.dart';
      import 'package:flutter_helix/services/conversation_listening_session.dart';
      import 'package:flutter_helix/services/answers/answer_arbiter.dart';
      import 'package:flutter_helix/services/answers/qa_button_controller.dart';
      import 'package:flutter_helix/services/answers/smart_answer_pipeline.dart';
      import 'package:flutter_helix/services/answers/answer_slot.dart';

      void main() {
        test('Q&A press never gaps transcription >120 ms', () async {
          final eventCtl = StreamController<dynamic>();
          final session = ConversationListeningSession.test(eventStream: eventCtl.stream);
          final engine = await buildTestEngine(session: session);

          final slowPipe = _SlowPipeline(firstChunkAfter: const Duration(milliseconds: 800));
          final arb = AnswerArbiter(smartPipeline: slowPipe);
          final qa = QAButtonController(requestQA: arb.requestQA);

          final updateTimes = <DateTime>[];
          engine.onUpdateForTest = (_) => updateTimes.add(DateTime.now());

          // Pump 50 ms partials for 2 s.
          final pumpTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
            eventCtl.add({'type': 'partial', 'text': 'p${t.tick}'});
          });
          await Future.delayed(const Duration(milliseconds: 1000));
          unawaited(qa.onPress(_req()));
          await Future.delayed(const Duration(milliseconds: 1000));
          pumpTimer.cancel();

          for (var i = 1; i < updateTimes.length; i++) {
            final gap = updateTimes[i].difference(updateTimes[i - 1]).inMilliseconds;
            expect(gap, lessThan(120), reason: 'gap $gap ms at index $i');
          }
        });
      }

      class _SlowPipeline implements SmartAnswerPipeline {
        _SlowPipeline({required this.firstChunkAfter});
        final Duration firstChunkAfter;
        @override
        Stream<SmartChunk> run(QARequest req, int generation) async* {
          await Future.delayed(firstChunkAfter);
          yield SmartChunk(generation: generation, delta: 'ok', isLast: true);
        }
      }

      QARequest _req() => QARequest(
            triggeredAt: DateTime.now(),
            transcriptSnapshot: '',
            systemPrompt: '',
            smartModelId: 'm',
            maxResponseSentences: 3,
          );
      ```
      (If `buildTestEngine` doesn't exist in `test/helpers/test_helpers.dart`, add a helper there that constructs a `ConversationEngine` with all required dependencies pre-faked. If `engine.onUpdateForTest` doesn't exist, add a test-only setter on the engine that records every transcription update.)
- [ ] Run the test, confirm it passes. If it fails because of a real gap, that's a Phase 1c regression — investigate before declaring done.
- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] `git add test/services/answers/transcription_no_gap_test.dart test/helpers/test_helpers.dart && git commit -m "test: Q&A press never gaps transcription regression"`

### Task 2.2 — Add `lib/services/answers/**` to FULL-gate trigger list

**Files**
- Modify: `CLAUDE.md` (the "After modifying these files, run the FULL gate" list) and/or `VALIDATION.md` and/or `scripts/run_gate.sh` if it has a file glob

Steps:

- [ ] Read `CLAUDE.md` "After modifying these files, run the FULL gate" section.
- [ ] Add the bullet `- Any file under \`lib/services/answers/\``.
- [ ] If `scripts/run_gate.sh` has a literal file list, add `lib/services/answers/` glob to it.
- [ ] `git add CLAUDE.md scripts/run_gate.sh && git commit -m "docs: add lib/services/answers to full-gate triggers"`

### Task 2.3 — Phase 2 final gate

Steps:

- [ ] Run `flutter analyze` and confirm `0 errors`.
- [ ] Run `flutter test test/` and confirm all tests pass.
- [ ] Run `bash scripts/run_gate.sh` and confirm exit code 0.
- [ ] `git commit --allow-empty -m "checkpoint: priority pipeline + transcription isolation complete"`

---

## Self-review notes

- Spec §3.1 file split → Phase 1a tasks 1a.1-1a.8 create every listed file with the matching responsibility.
- Spec §4.2 preemption table → Phase 1b tasks 1b.1, 1b.2, 1b.4, 1b.5, 1b.6, 1b.7 cover every row that mutates HUD or UI. Rows that say "do nothing" are covered by negative-assertion tests in 1b.4 and 1b.6.
- Spec §4.3 prefetch → 1b.1 + 1b.3 + 1b.7.
- Spec §4.4 debounce → 1b.8.
- Spec §5 light contract → 1a.2 (parser + prompt) and 1b.10 (cadence + coalesce + backoff).
- Spec §6 cancellation → 1b.2 (generation discard) + 1b.10 (light token bump on stop/start).
- Spec §7.1 diagnosis → Phase 0 (seven tasks).
- Spec §7.2 Fix A → Phase 1c-A; Fix B → Phase 1c-B; both planned in parallel, executor picks per Phase 0 conclusion.
- Spec §8 error matrix → 1b.7 (smart error) + 1a.2/1b.10 (light parse and network errors).
- Spec §9 testing → arbiter (1b.1-1b.7), light contract (1a.2), debounce (1b.8), regression (2.1).
- Spec §10 sequencing → phase order matches.
- Naming consistency: `arbiter.requestQA`, `arbiter.onLightResult`, `arbiter.hudSlot`, `arbiter.uiSlot`, `arbiter.factAlerts`, `pipeline.run(req, generation)`, `qa.onPress(req)`, `lightLoop.triggerOnFinalized`, `_qaGeneration`. Used identically throughout.
- No placeholder strings ("TBD", "implement later", etc.) appear in any task body.
