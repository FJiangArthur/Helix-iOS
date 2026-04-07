# Priority Pipeline + Transcription Isolation

**Date**: 2026-04-06
**Status**: Design spec (Spec A)
**Scope**: `lib/services/conversation_engine.dart`, `lib/services/conversation_listening_session.dart`, `lib/services/llm/llm_service.dart`, `ios/Runner/SpeechStreamRecognizer.swift`, `ios/Runner/AppDelegate.swift`, glasses HUD path via `lib/services/bitmap_hud/bitmap_hud_service.dart` and `lib/services/evenai.dart`.

---

## Open Questions (resolve during implementation, not spec)

1. **Light-model cadence**: every N seconds, on every finalized segment, or on a debounce after partials? Recommended default in this spec is "on finalize OR every 3s while partials are flowing", but the right number wants telemetry from Phase 0.
2. **Prefetch staleness**: how old can the most-recent light-model answer be before we treat it as "no prefetch available" and just show a spinner? Recommended: 8 seconds.
3. **Smart-model cancellation propagation**: do current LLM providers (`OpenAiCompatibleProvider`, `AnthropicProvider`) honor an external cancel token mid-SSE? Needs a one-hour audit; if not, implementation must wrap them in a stream consumer that drops post-cancel chunks (cheap, correct, but wastes tokens).
4. **Live Activity Q&A button**: confirm whether the LA button funnels through `BluetoothManager` notifyIndex emission or uses its own platform channel. Affects where debounce lives.
5. **Phase 0 finding contingency**: this spec proposes both candidate fixes, but the chosen one is contingent on diagnostic data. If both audio-pipeline and async-path show issues, both fixes ship.

---

## 1. Background and Problem

Today, `ConversationEngine` (~3000 LOC) owns transcription intake, question detection, LLM dispatch, fact-check, follow-up chip generation, HUD presentation coordination, and proactive-mode context. There is no separation between:

- **High-priority, user-initiated** answers (Q&A button press, expected to feel instant on the glasses HUD).
- **Low-priority, background** answers (auto-detected questions while the user is just talking).
- **Mid-priority corrections** (fact-check that should override a wrong auto-answer).

The existing implementation already has the right primitives — `_responseToken` / `_analysisToken` cancellation counters (engine.dart:59-60, 2559-2567), a merged JSON `_postResponseAnalysis` that returns `{chips, factCheck}` in one call (engine.dart:1256-1330), and `resolvedLightModel` / `resolvedSmartModel` settings — but the policy that ties them together is implicit and entangled with everything else in the engine.

Two concrete user-visible failures result:

- **F1 — No priority hierarchy.** A background auto-answer can be on the HUD when the user presses the Q&A button; the user expects their press to win immediately and it does not, reliably.
- **F2 — Transcription gaps on Q&A press.** Pressing Q&A causes transcription partials to stall and recovery is slow. Root cause is unknown; this spec includes a diagnostic phase before prescribing a fix.

This spec does not redesign transcription or LLM providers. It introduces one new component (the arbiter), splits responsibilities out of `conversation_engine.dart`, defines the light-model contract, and lays out a diagnose-then-fix plan for transcription isolation.

---

## 2. Locked Decisions (recap)

These are inputs to the design, not subject to revisit during implementation:

1. **Two LLM tiers.** Smart model = user's configured provider/model, only invoked on explicit Q&A press, capped at `maxResponseSentences`, streams first token ASAP. Light model = `resolvedLightModel`, runs continuously, single call returns one JSON object covering question detection, auto-answer, and fact correction.
2. **Priority hierarchy** (high → low): user Q&A (smart) > fact-check correction (light) > auto-answer (light, **UI only**, never glasses, never Live Activity).
3. **Q&A button**: 1 s debounce dropping repeats; a press after 1 s cancels any in-flight smart response and starts a new one. Q&A press **must never disrupt transcription** — this is the system's load-bearing guarantee.
4. **Speculative prefetch**: on Q&A press, immediately push the light model's most recent answer to the HUD as a placeholder, then replace with the smart model's stream when its first token arrives. Target press → first pixel < 200 ms; press → smart-model first token < 1 s (network bound).
5. **Transcription isolation**: Phase 0 diagnoses the gap, Phase 1 fixes it. Both candidate fixes specced so implementation can branch on data without re-spec.

---

## 3. Architecture

### 3.1 Components (after split)

`conversation_engine.dart` is too large (2999 LOC) to host this work cleanly. The split below is the **minimum** refactoring required to land Spec A; nothing else is touched.

| New / existing file                                                  | Owns                                                                                                                                                                  | LOC budget |
| -------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| `lib/services/conversation_engine.dart` (existing, **shrunk**)       | Transcript intake, segment store, mode state, public stream surface. Becomes a coordinator that delegates to the new components. Target after split: ≤ 1800 LOC.     | —          |
| `lib/services/answers/answer_arbiter.dart` (**new**)                 | Single source of truth for "what is currently shown on the glasses HUD" and "what auto-answer is currently shown in the UI". Enforces preemption. Independent of LLM. | ≤ 350      |
| `lib/services/answers/smart_answer_pipeline.dart` (**new**)          | Owns the smart-model request lifecycle: build prompt, call `LlmService`, stream tokens, honor cancellation. One method: `run(QARequest) → Stream<SmartChunk>`.        | ≤ 250      |
| `lib/services/answers/light_loop.dart` (**new**)                     | Owns the continuous light-model loop: schedules calls, builds the rolling-window prompt, parses JSON, emits `LightModelResult` to the arbiter. Replaces and absorbs `_scheduleTranscriptAnalysis`, `_analyzeRecentTranscriptWindow`, and `_postResponseAnalysis`. | ≤ 400      |
| `lib/services/answers/light_model_contract.dart` (**new**)           | Pure data: prompt template, JSON schema, parser, validation, error types. No I/O, fully unit-testable.                                                                | ≤ 200      |
| `lib/services/answers/qa_button_controller.dart` (**new**)           | Receives Q&A button events from `evenai.dart` (BLE notifyIndex) and `LiveActivityManager` channel; enforces 1 s debounce; calls into the arbiter.                     | ≤ 120      |

Existing files referenced unchanged in interface (only call-site updates):

- `lib/services/llm/llm_service.dart` — already supports per-request model override.
- `lib/services/bitmap_hud/bitmap_hud_service.dart` and `lib/services/evenai.dart` — receive HUD writes from the arbiter via existing methods.
- `lib/services/conversation_listening_session.dart` — unchanged in this spec; stays as the platform-channel bridge.

### 3.2 Boundaries (who calls whom)

```
                                  +-------------------------------+
   BLE notifyIndex (24, etc.) --> |                               |
                                  |    QAButtonController         |
   LiveActivity QA channel    --> |    (debounce, cancel-prev)    |
                                  +---------------+---------------+
                                                  | QARequest
                                                  v
+--------------------+    LightModelResult  +-----+----------+   SmartChunk stream
| LightLoop          |--------------------> | AnswerArbiter  |<------------------+
| (continuous,       |                      |                |                   |
|  reads transcript) |  cancel/preempt      | owns HUD &     |                   |
+---------+----------+ <------------------- | UI answer slot |   QARequest       |
          ^                                 +---+---------+--+ ----------------+ |
          | TranscriptSnapshot                  |         |                   v |
          |                                     |         |          +--------+-+
+---------+----------+    HUD write (bitmap)    |         |          | SmartAnswer
| ConversationEngine |<--------------------------+         |          | Pipeline    |
| (transcript only)  |    UI answer write                 |          +-------------+
+--------------------+ <-----------------------------------+
                                                   v
                                            (Home screen state)
```

Key rules captured by the diagram:

- **Only the arbiter writes to the HUD.** No other component calls `BitmapHudService` for answer content. (Status pings and battery indicators are unrelated and stay where they are.)
- **`SmartAnswerPipeline` does not know about the HUD.** It returns a stream of chunks. The arbiter decides whether each chunk is current and should be rendered.
- **`LightLoop` does not know about the HUD either.** It emits `LightModelResult` to the arbiter, which decides routing per the priority rules.
- **`QAButtonController` does not call the LLM.** It calls `arbiter.requestQA(QARequest)`. The arbiter then asks `SmartAnswerPipeline` to start a stream.
- **`ConversationEngine` no longer owns answer routing.** It owns transcript state and emits a `TranscriptSnapshot` stream that `LightLoop` consumes. This is the main thing that lets the engine shrink.

### 3.3 What stays in `ConversationEngine`

- Transcript segment store (`_finalizedSegments`, `_partialTranscription`).
- `onTranscriptionUpdate` / `onTranscriptionFinalized` / `onTranscriptionUsage` entry points called by `ConversationListeningSession`.
- Mode state (general / interview / passive) and `systemPrompt` resolution.
- The public `Stream<TranscriptSnapshot>` and `Stream<String>` (full transcript) used by the home screen.
- Lifecycle: `start()`, `stop()`, `dispose()`.

What moves out: `_scheduleTranscriptAnalysis`, `_analyzeRecentTranscriptWindow`, `_postResponseAnalysis`, `_backgroundFactCheck`, `_followUpChipsController`, `_factCheckAlertController`, the smart-response dispatch path, and the `_responseToken` / `_analysisToken` machinery (re-homed in their new owners).

---

## 4. AnswerArbiter — interface and behavior

The arbiter is the single small unit that the rest of the spec hinges on. It **must** stay small (≤ 350 LOC) and **must** be independently unit-testable with fake LLM streams and a fake HUD sink.

### 4.1 Interface sketch

```dart
enum AnswerPriority { autoAnswer, factCorrection, userQA } // ordered low → high

class AnswerSlot {
  final AnswerPriority priority;
  final String contentSoFar;
  final bool isStreaming;
  final bool isPrefetch; // true while we're showing a light-model placeholder
                         // for an in-flight smart answer
  final int generation;  // monotonic; bumped on every preemption
}

abstract class AnswerArbiter {
  // Inputs
  Future<void> requestQA(QARequest req);            // from QAButtonController
  void onLightResult(LightModelResult r);           // from LightLoop
  void onSmartChunk(int generation, String delta);  // from SmartAnswerPipeline
  void onSmartDone(int generation);                 // success
  void onSmartError(int generation, Object e);      // failure → fall back to prefetch

  // Outputs
  Stream<AnswerSlot> get hudSlot;       // glasses HUD sink subscribes here
  Stream<AnswerSlot> get uiSlot;        // home screen subscribes here
  Stream<String>     get factAlerts;    // toast/banner sink
}
```

### 4.2 Preemption rules (exhaustive)

| Currently in `hudSlot`     | New event arrives                  | Action                                                                                                          |
| -------------------------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| nothing                    | Q&A press                          | Bump generation, push prefetch from latest light answer (or empty), kick `SmartAnswerPipeline`.                 |
| nothing                    | light auto-answer                  | **Do nothing on HUD.** Auto-answers are UI-only. Push to `uiSlot` only.                                         |
| nothing                    | fact correction                    | Push as one-shot toast via `factAlerts`. HUD not touched (matches today's behavior).                            |
| smart streaming (gen N)    | Q&A press                          | Cancel gen N (token bump), bump generation to N+1, replay prefetch placeholder, kick new pipeline.              |
| smart streaming (gen N)    | light result                       | Ignore on HUD. Update `uiSlot` if priority is `autoAnswer`. Forward fact corrections to `factAlerts` only.      |
| smart prefetch (gen N)     | smart chunk for gen N              | Replace prefetch with smart content. Set `isPrefetch=false`. Continue streaming.                                |
| smart prefetch (gen N)     | smart chunk for gen ≠ N            | Drop (stale).                                                                                                   |
| auto-answer in `uiSlot`    | fact correction (within 30 s)      | Push correction text into `uiSlot` replacing the auto-answer; emit one-shot via `factAlerts`.                   |
| auto-answer in `uiSlot`    | Q&A press                          | Auto-answer in UI is independent of HUD path. Leave `uiSlot` alone unless the smart answer completes; then home screen swaps to smart answer. |

The arbiter only ever cares about the **current generation** for the HUD. Stale chunks/results/errors are discarded by generation number — same pattern as today's `_responseToken`, just hoisted out of the engine.

### 4.3 Prefetch / refine semantics

When `requestQA` fires:

1. The arbiter immediately publishes an `AnswerSlot` with `priority=userQA`, `isPrefetch=true`, and `contentSoFar` = the most recent `LightModelResult.answer` if it exists and is < 8 s old, else empty.
2. The HUD sink renders this exactly like a normal answer (same bitmap layout, same font). **No "preview" badge, no shimmer, no upgrade animation.** Recommended approach: silent replace. The user does not need to know an upgrade happened; the second render just shows better content. This matches how the glasses HUD already handles AI streaming updates and avoids inventing new screen codes.
3. When the first smart chunk arrives, the arbiter emits a new `AnswerSlot` with `isPrefetch=false` and `contentSoFar=delta`. The HUD sink, on seeing `isPrefetch` flip false, **clears the slot and starts fresh** rather than trying to diff. Cheaper, simpler, no flicker risk if we hit the new content within ~300 ms (which we should — the only delay is provider TTFB).
4. If smart errors before any chunk: the arbiter keeps the prefetch on screen and emits `factAlerts` with a small "(answer may be incomplete)" note. Avoids the worst case of pressing the button and getting nothing.
5. If there is no usable prefetch (no light answer, or stale), the arbiter publishes an empty `AnswerSlot` with `isStreaming=true` so the HUD can show its existing "thinking…" state. Same code path as today.

### 4.4 The 1 s Q&A debounce

Lives in `QAButtonController`, **Dart side**, not native. Reasoning: testable with fake clocks, and native already has enough state to worry about for transcription isolation (Phase 1).

```dart
class QAButtonController {
  DateTime? _lastAccepted;
  void onPress() {
    final now = DateTime.now();
    if (_lastAccepted != null && now.difference(_lastAccepted!) < const Duration(seconds: 1)) {
      return; // drop
    }
    _lastAccepted = now;
    _arbiter.requestQA(QARequest(triggeredAt: now));
  }
}
```

`AppDelegate.swift` and `LiveActivityManager.swift` both already forward button events into Dart; this controller just becomes the single Dart-side sink. No native changes for the debounce.

---

## 5. LightLoop and the JSON contract

### 5.1 Contract

The light model returns exactly one JSON object per call. No markdown fences (parser strips them defensively, same as today's `_stripMarkdownCodeFence`).

```json
{
  "question": "string or null — verbatim or paraphrased question detected in the recent window, else null",
  "answer":   "string or null — short direct answer if question is set, else null. Capped at maxResponseSentences.",
  "factCorrection": "string or null — single-sentence correction if the most recent assistant answer (passed in prompt) contains a factual error, else null"
}
```

Rules:

- All three fields are independently nullable. No question → `question` and `answer` both null.
- `answer` is only present when `question` is present.
- `factCorrection` is null unless we passed a recent assistant answer in the prompt **and** it has a verifiable error. The light model must not nitpick style.
- Output is plain JSON. The parser tolerates leading/trailing whitespace and stripped markdown fences only; anything else is treated as a parse failure.

### 5.2 Prompt sketch (English; mirror in Chinese)

```
You are a low-latency conversation assistant. You will receive (a) a rolling transcript of a live conversation and (b) optionally the most recent assistant answer that was shown to the user.

Return ONE JSON object, no prose, no code fences:
{"question": ..., "answer": ..., "factCorrection": ...}

Rules:
- Set "question" to the most recent question the speaker would want answered. If there is no clear question, set it to null.
- If "question" is set, write a direct answer in at most {N} sentence(s) and put it in "answer". Never say "you could say" or "here's a suggestion" — answer directly.
- If a "previous_assistant_answer" is provided AND it contains a factual error, write a one-sentence correction in "factCorrection". Otherwise null. Do not correct style or wording.
- All three fields may be null. Output only the JSON object.

transcript:
<rolling window, last ~2000 chars, with [Ns pause] markers>

previous_assistant_answer:
<text or "none">
```

`{N}` = `SettingsManager.maxResponseSentences`. The prompt is built by `light_model_contract.dart` so it's pure and unit-testable.

### 5.3 Parsing & error handling

- Invalid JSON → log at debug, drop the result, do **not** retry on the same window. The next light call (next finalized segment or next 3 s tick) will try again with fresh content.
- JSON valid but schema wrong (e.g. `question` is a number) → treat as parse failure. Same drop-and-wait behavior.
- Three consecutive parse failures → emit a single `factAlerts` event with a short diagnostic, then continue. Avoids spamming the user but surfaces a real misconfiguration.
- Light model network error → exponential backoff capped at 30 s. The loop never stops itself; only `engine.stop()` stops it.

### 5.4 Cadence

Default rule:

- Run on every `onTranscriptionFinalized`.
- Additionally, run every 3 s while there is a non-empty partial that hasn't been analyzed yet (covers long single utterances).
- Coalesce: if a call is in flight and a new trigger arrives, mark "rerun pending" and fire one new call immediately on completion. Never queue more than one.
- Bump `_lightToken` on `engine.start()` and on every preemption from the arbiter. In-flight calls whose token doesn't match on completion are dropped.

This replaces the existing 1.5 s debounce timer (`engine.dart:1379-1395`) with explicit finalization-driven scheduling, which both reduces redundant calls and gives the arbiter fresher prefetch data.

---

## 6. Cancellation semantics

We do not invent a new cancellation system. We extend the existing token pattern (`_responseToken` / `_analysisToken` in `engine.dart:59-60`) and re-home the counters.

| Token              | Owner                  | Bumped on                                                                                          | Checked at                                                     |
| ------------------ | ---------------------- | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `_qaGeneration`    | `AnswerArbiter`        | every accepted `requestQA`                                                                         | every `onSmartChunk` / `onSmartDone` / `onSmartError`          |
| `_lightToken`      | `LightLoop`            | `engine.start()`, `engine.stop()`, on Q&A press (so light won't overwrite the new HUD slot)        | on light-call completion, before publishing to arbiter         |

`SmartAnswerPipeline` does not own a token. The arbiter passes the current `_qaGeneration` into `pipeline.run(req, generation)`, and the pipeline tags every emitted chunk with that generation. The arbiter discards chunks whose generation doesn't match the current value. The provider HTTP/SSE call itself is also signaled to cancel (close the stream subscription) when the arbiter bumps generation, so we don't pay for tokens we'll never show. If the underlying provider doesn't honor mid-SSE cancellation cleanly, we still drop chunks at the arbiter — correctness is preserved, only token cost is wasted (see Open Question 3).

---

## 7. Transcription Isolation

### 7.1 Phase 0 — Diagnose (BEFORE any fix)

Goal: produce a timeline log of one full Q&A press and prove which subsystem (audio engine vs Dart consumer vs platform channel) introduces the gap. Without this we are guessing.

Instrumentation to add (all behind a `kDebugTranscriptionTiming` build flag, off in release):

1. **Native — `SpeechStreamRecognizer.swift`, `installTap` callback** (lines 555, 663, 1103):
   - Log first byte and last byte timestamp of every audio buffer delivered to the tap (mach time, not Date).
   - Log every transition into/out of `pauseRecognition` / `resumeRecognition` (lines 998-1005).
   - Log the timestamp at which each `script` event is sent over the EventChannel sink.
2. **Native — `AppDelegate.swift` platform-channel handlers**:
   - On every `notifyIndex == 24` (evenaiRecordOver — current Q&A trigger) and every Q&A method call from the LiveActivity channel, log mach time of receipt and mach time of dispatch into Dart.
3. **Dart — `ConversationListeningSession`**:
   - Log every speech event arrival timestamp (`DateTime.now().microsecondsSinceEpoch`) keyed by `segmentId`.
   - Log the gap between consecutive partials. Anything > 100 ms in the steady state is suspicious.
4. **Dart — `QAButtonController` (new)**:
   - Log press receipt time, debounce decision, and time of `arbiter.requestQA` return.
5. **Dart — `AnswerArbiter`**:
   - Log press → first prefetch publish, prefetch publish → first smart chunk, first smart chunk → first HUD bitmap commit.
6. **Firmware-side — `G1DebugService`** (`lib/services/g1_debug_service.dart`, pre-existing, committed in checkpoint `10905f7` — **do not rewrite as part of Phase 0, just wire it in**):
   - During the diagnostic window, call `G1DebugService.instance.enable()`. This sends `0x23 0x6C 0x00` to the glasses to activate firmware debug logging; incoming `0xF4` frames are parsed (null-terminated ASCII) and emitted on `G1DebugService.instance.debugMessages` with HH:mm:ss.SSS timestamps.
   - Log every message from that stream alongside the phone-side timeline. Timestamps are wall-clock but arrival time at the Dart side is what we compare against native tap timestamps.
   - **Correlation rule:** a gap in firmware debug output during the Q&A press window is strong evidence the problem is downstream of the BLE command channel (i.e. the glasses firmware itself is stalled or blocked on something we sent). A gap that appears **only** on the phone side, with firmware debug output continuing normally, points upstream into the Dart / platform-channel / audio-engine path and rules out the glasses as a cause. No gap on either side + perceived lag → the issue is LLM TTFB or HUD render, not transcription (matches the "no gap anywhere" row of the interpretation guide below).
   - Remember to call `G1DebugService.instance.disable()` after the diagnostic run; leaving firmware logging on in production adds BLE noise.

Diagnostic test protocol:

- Boot a dedicated Helix simulator instance (per CLAUDE.md).
- Start a session, speak continuously for 30 s, press Q&A at the 15 s mark, continue speaking for another 15 s.
- Capture logs.

Gap-pattern interpretation guide (this is the load-bearing output of Phase 0):

| Observed pattern                                                                                                | Most likely cause                                                                                | Fix branch          |
| --------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ | ------------------- |
| Audio tap timestamps continue with no gap, but Dart speech-event arrival gaps spike around the press.          | Dart isolate or platform-channel backpressure during smart-model dispatch.                       | **Fix B (async)**   |
| Audio tap timestamps themselves show a > 100 ms gap starting at the press.                                     | The audio session is being interrupted (likely by us re-configuring it or by AVAudioSession losing the tap during a category change for a side effect of LLM/network setup). | **Fix A (audio)**   |
| Both gaps appear simultaneously.                                                                               | Audio is the upstream cause; Dart gap is downstream consequence.                                 | **Fix A** primary, B secondary |
| No gap anywhere but user still perceives lag.                                                                  | The lag is in HUD render or LLM TTFB, not transcription. Spec A still fixes perceived lag via prefetch. | none for transcription |

Phase 0 deliverable: a short doc under `docs/research/2026-04-06-transcription-gap-diagnosis.md` with the captured logs and a one-line conclusion naming the fix branch.

### 7.2 Phase 1 — Fix (conditional on Phase 0)

#### Fix A — Audio pipeline isolation

Hypothesis: something on the Q&A path (HTTP client init, AVAudioSession reconfiguration, voice-assistant playback prep) touches the shared audio session or the input node and causes the tap to drop briefly.

Actions:

1. Audit `SpeechStreamRecognizer.swift` for every `audioEngine.stop()` / `installTap` / `removeTap` (lines 1103, 1326, 1355) and every `AVAudioSession.sharedInstance().setCategory` / `setActive` call. List which code paths can hit them outside of explicit start/stop.
2. Audit `VoiceAssistantService` and `OpenAIRealtimeTranscriber` for any lazy `setActive(true)` that might collide with the input tap when the smart model fires.
3. Guarantee the input tap is **never reinstalled and never removed** during a Q&A press. The audio engine and tap should have a strict lifecycle owned only by `startSession` / `stopSession`. Any other code that wants to touch the audio session must go through a single `AudioSessionCoordinator` (small new wrapper, < 80 LOC) that refuses changes while a session is active.
4. Move LLM HTTP client init off the main thread and out of the press path (if profiling shows it touches anything audio-adjacent — usually it doesn't, but worth confirming).

Acceptance: with Phase 0 instrumentation still on, repeat the diagnostic test. No tap-callback gap > 100 ms beyond baseline jitter (~30 ms) at any point during or after the Q&A press.

#### Fix B — Async path isolation

Hypothesis: pressing Q&A schedules a burst of synchronous Dart work (prompt building, settings reads, provider construction) on the main isolate that starves the speech-event consumer.

Actions:

1. Make `QAButtonController.onPress` do **only** debounce check + `arbiter.requestQA` + return. No I/O, no settings reads.
2. `AnswerArbiter.requestQA` must return synchronously after publishing the prefetch slot. The smart pipeline is started via `unawaited(...)` and the HTTP call happens on a microtask, not inline.
3. `SmartAnswerPipeline.run` must not read `SettingsManager` or `LlmService` config inside the press path. All required state is captured into `QARequest` at construction time by the arbiter from a pre-read snapshot.
4. Ensure the EventChannel speech subscription handler in `ConversationListeningSession` (lines 109-183) does not block on `_engine.onTranscriptionUpdate`. If profiling shows the engine method does heavy work synchronously, hoist the heavy parts into a microtask. (After the engine split in §3, this is much easier — the engine method becomes a small store-and-emit.)

Acceptance: same as Fix A — no Dart-side speech-event gap > 100 ms beyond baseline during/after the press.

#### Hard requirement (both branches)

> During a Q&A press, transcription partials must continue arriving with no gap > 100 ms beyond the steady-state baseline measured immediately before the press.

This requirement is enforceable as a regression test (§9).

---

## 8. Error Handling Matrix

| Failure                                          | Behavior                                                                                                                                |
| ------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| Light model returns invalid JSON                 | Drop result, no UI change. Three consecutive failures → one `factAlerts` diagnostic message, then keep trying.                          |
| Light model network error                       | Backoff 1 s, 2 s, 4 s, … capped at 30 s. Loop never dies. No UI change.                                                                 |
| Smart model 5xx / network drop before any chunk | Arbiter keeps prefetch on HUD; emits `factAlerts("answer may be incomplete")`. Generation stays current so next press is unaffected.    |
| Smart model drops mid-stream                    | Arbiter holds whatever was streamed so far; emits same `factAlerts` note. Does not retry automatically (user can press again).         |
| Q&A pressed while smart already streaming       | Always honored if outside the 1 s debounce. Generation bumps, old stream cancelled, new prefetch shown immediately.                     |
| Q&A pressed while transcription session is down | `QAButtonController` checks `ListeningSession.isRunning`; if false, forwards to existing "ask AI" text query path instead of arbiter.   |
| Provider not configured                          | Existing `ProviderErrorState.missingConfiguration()` path stays — surfaced once via the error stream, not per press.                   |

---

## 9. Testing Strategy

### 9.1 Unit tests — arbiter

Goal: prove every cell in the §4.2 preemption table without touching real LLMs or HUD.

- Test fixture: `FakeSmartPipeline` (returns a `Stream<SmartChunk>` from a queue), `FakeHudSink` (records every `AnswerSlot` it sees), `FakeClock`.
- One test per row of the preemption table. Each test asserts the sequence of `AnswerSlot`s the HUD sink saw.
- Tests for generation discard: feed a stale chunk after a press, assert it never reaches the sink.
- Tests for prefetch staleness: feed a `LightModelResult` 9 s before the press, assert the prefetch slot is empty.

Target: ≥ 95 % line coverage on `answer_arbiter.dart`. The arbiter is small enough that this is cheap.

### 9.2 Unit tests — light contract

- `light_model_contract.dart` is pure: prompt builder + JSON parser. Tests cover (a) prompt rendering with N=1/3/10 sentence caps and Chinese vs English, (b) parsing valid JSON with all combinations of nullable fields, (c) parsing markdown-fenced JSON, (d) parsing schema-mismatched JSON, (e) parsing prose-with-JSON-substring (should fail).

### 9.3 Unit tests — debounce

- `QAButtonController` with `FakeClock`: 10 presses at 100 ms intervals → 1 accepted; press at 0 s + press at 1.1 s → both accepted; press at 0 s + press at 0.9 s → 1 accepted.

### 9.4 Regression test — "Q&A press never gaps transcription"

This is the load-bearing test for §7's hard requirement.

Approach:

- Use `ConversationListeningSession.test()` factory (already exists, line 34) with a synthetic `Stream<dynamic>` of speech events emitting one partial every 50 ms.
- Wire a real `ConversationEngine` + `AnswerArbiter` + `QAButtonController` + a fake `SmartAnswerPipeline` whose `run()` returns a `Stream` that yields its first chunk after 800 ms.
- Inject a Q&A press mid-test.
- Assert: the gap between any two consecutive `onTranscriptionUpdate` calls observed by the engine **never exceeds 120 ms** across the press window. (50 ms cadence + 100 ms tolerance + small safety margin.)
- Assert: the arbiter published a prefetch slot within 50 ms of the press.

This test cannot catch native-side audio gaps (Phase 1 Fix A territory), but it does pin the Dart-side guarantee permanently.

### 9.5 Manual / device validation

- Run the Phase 0 diagnostic protocol after Phase 1 ships, confirm zero > 100 ms tap gaps in real audio.
- Subjective: press Q&A repeatedly during continuous speech; transcription should keep flowing with no visible stutter on the home screen.

### 9.6 Validation gate

All work in this spec touches files on the `bash scripts/run_gate.sh` trigger list (`conversation_engine.dart`, new files under `lib/services/answers/` which will be added to the trigger list as part of Phase 1, plus `SpeechStreamRecognizer.swift` for the iOS instrumentation). Full gate runs before every commit.

---

## 10. Sequencing

1. **Phase 0** — Add instrumentation (§7.1), capture diagnostic logs, write the one-page conclusion doc. No production behavior change. Ships behind a debug flag.
2. **Phase 1a** — Engine split (§3.1). Pure refactor: extract arbiter, smart pipeline, light loop, light contract, QA controller. No behavior change beyond moving code. Full test suite passes unchanged. This is a big diff but a mechanical one.
3. **Phase 1b** — Wire the priority rules in the arbiter. New unit tests (§9.1, §9.2, §9.3, §9.4). At this point user-visible behavior changes: prefetch on press, fact-check overrides auto-answer in UI, auto-answers no longer hit the HUD.
4. **Phase 1c** — Apply the chosen transcription isolation fix (Fix A or Fix B or both) per Phase 0's conclusion. Re-run the diagnostic protocol; attach results to the PR.
5. Phase 0 instrumentation can stay in tree behind the debug flag indefinitely — it will be useful next time something regresses here.

Each phase is independently revertible. Phase 1a is the biggest risk and should land on its own PR with the full validation gate green.
