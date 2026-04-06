# Line-by-Line HUD Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce BLE write rate to the G1 glasses by ~6-7x during LLM streaming responses by gating flushes on visual-line completion instead of per-token.

**Architecture:** Introduce a `HudStreamSession` class that owns per-stream HUD state (currently 3 fields on `ConversationEngine` at `lib/services/conversation_engine.dart:98-100`). It buffers tokens, runs the existing `TextPaginator.splitIntoLines` on the unsent tail to detect line completion, and only emits to BLE on line boundaries. The wire format and `Proto.sendEvenAIData` API are unchanged — only the flush trigger moves. A `HudPacketSink` interface is injected so unit tests can run without BLE.

**Tech Stack:** Flutter 3.35+, Dart, iOS 26 deployment target

**Depends on:** Spec A (Priority Pipeline) for the `HudStreamSession.cancel()` preemption hook.

**Source spec:** `docs/superpowers/specs/2026-04-06-hud-line-streaming-design.md` (commit 293baac, corrected for G1 protocol findings — no append semantics, wire format unchanged).

---

## File structure

**New files:**
- `lib/services/hud_stream_session.dart` — `HudPacketSink` abstract interface, `ProtoHudPacketSink` production binding, `HudStreamSession` state machine.
- `test/services/hud_stream_session_test.dart` — unit tests with `RecordingHudPacketSink`.

**Modified files:**
- `lib/services/conversation_engine.dart` — Phase 2: route streaming through `HudStreamSession` behind a flag in `_streamToGlasses` (line ~2413). Phase 4: delete `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex` (lines 98-100) and dead branches in `_sendToGlasses` (lines ~2383-2398).
- `lib/services/settings_manager.dart` — add `bool get hudLineStreamingEnabled` backed by SharedPreferences key `hud.lineStreaming`, default `false` (Phase 2), default `true` (Phase 3 flip).

**Unchanged (verified):**
- `lib/services/proto.dart` (`sendEvenAIData` at line 121): no signature change.
- `lib/services/glasses_protocol.dart`: `HudDisplayState` unchanged.
- `lib/services/text_paginator.dart`: `splitIntoLines` at line 100, `linesPerPage = 5` at line 13.

---

## Phase 1 — HudStreamSession with unit coverage (no wiring)

### Task 1.1 — Create skeleton file and failing interface test

- [ ] Create `lib/services/hud_stream_session.dart` with:
  - `abstract class HudPacketSink` declaring `Future<void> send({required int screenStatus, required int pageIndex, required int totalPages, required String pageText})`.
  - Empty `class HudStreamSession { HudStreamSession({required this.sink}); final HudPacketSink sink; }`.
- [ ] Create `test/services/hud_stream_session_test.dart` with a `RecordingHudPacketSink implements HudPacketSink` that records every `send` call into a public `List<({int screenStatus, int pageIndex, int totalPages, String pageText})> calls`.
- [ ] Add a first test: `test('empty stream finish sends single 0x40 with empty body', ...)` that constructs a `HudStreamSession`, calls `await session.finish()`, and expects exactly one emitted frame with `screenStatus == 0x40` and `pageText == ''`.
- [ ] Run: `flutter test test/services/hud_stream_session_test.dart` — **expect FAIL** (method `finish` not implemented).
- [ ] Commit: `test: add failing HudStreamSession skeleton test`.

### Task 1.2 — Minimal appendDelta/finish/cancel methods

- [ ] In `hud_stream_session.dart`, add private fields per spec §4: `int _pageIndex = 0`, `final List<String> _lines = []`, `String _pendingTail = ''`, `bool _firstFrameSent = false`, `bool _cancelled = false`, `Completer<void>? _inFlight`.
- [ ] Implement `Future<void> appendDelta(String delta)`, `Future<void> finish()`, `Future<void> cancel()` as stubs that satisfy the empty-stream test: `finish()` awaits `_drainInFlight()` then calls `sink.send(screenStatus: 0x40, pageIndex: 0, totalPages: 1, pageText: '')` when cancelled==false.
- [ ] Run: `flutter test test/services/hud_stream_session_test.dart` — **expect PASS**.
- [ ] Run: `flutter analyze` — expect 0 errors.
- [ ] Commit: `feat: HudStreamSession skeleton with empty-stream finish`.

### Task 1.3 — Line detection via splitIntoLines on unsent tail

- [ ] Add test `test('3-line response produces 3 streaming + 1 final emit', ...)`: feed a long enough string in one `appendDelta` that `TextPaginator.instance.splitIntoLines(input)` returns exactly 3 lines, then `finish()`. Assert:
  - `calls.length == 4`
  - `calls[0].screenStatus == (0x01 | 0x30)` (first frame)
  - `calls[1].screenStatus == 0x30`, `calls[2].screenStatus == 0x30`
  - `calls[3].screenStatus == 0x40`
  - Each streaming `pageText` is a prefix-extension of the previous (monotonic growth).
- [ ] Run — **expect FAIL**.
- [ ] Implement in `appendDelta`:
  1. If `_cancelled` return.
  2. If `delta.isEmpty` return.
  3. `_pendingTail += delta`.
  4. Handle literal `\n` in `_pendingTail` by splitting on `\n` and promoting all-but-last segments as forced line breaks (append each to `_lines` directly).
  5. Compute `candidate = _pendingTail` (the active line — `_lines` already hold sent text, so the unsent tail alone is what gets re-wrapped).
  6. `final wrapped = TextPaginator.instance.splitIntoLines(candidate);`
  7. If `wrapped.length >= 2`: move all but the last into `_lines`, set `_pendingTail = wrapped.last`, call `_emit(streaming: true)`.
  8. If `_lines.length >= TextPaginator.linesPerPage` (5): handle page boundary per Task 1.5.
- [ ] Implement `_emit({required bool streaming})`:
  - `final pageText = [..._lines, if (_pendingTail.isNotEmpty) _pendingTail].join('\n');`
  - `int status;`
  - If `streaming && !_firstFrameSent` → `status = 0x01 | 0x30; _firstFrameSent = true;`
  - Else if `streaming` → `status = 0x30;`
  - Else → `status = 0x40;`
  - Serialize on `_inFlight` completer: await previous, then await `sink.send(...)`, then complete.
  - `totalPages` is `_pageIndex + 1` (monotonic — grows when a new page starts).
- [ ] Implement `finish()` to flush a trailing non-empty `_pendingTail` as one more streaming emit, then emit `0x40` with the full current page.
- [ ] Run — **expect PASS**.
- [ ] Run: `flutter analyze` — 0 errors.
- [ ] Commit: `feat: HudStreamSession line-gated flush via splitIntoLines`.

### Task 1.4 — Final-page agreement (drift guard)

- [ ] Add test `test('final streaming emit matches TextPaginator last page', ...)`: feed a multi-line input, `finish()`, assert the last streaming emit's `pageText` equals `TextPaginator.instance.paginateText(input).last` (using the paginator's exposed last-page accessor — verify the public surface in `text_paginator.dart` and adjust the call if needed).
- [ ] Run — expect PASS if implementation is correct; if not, fix by ensuring `_lines` + `_pendingTail` join uses the same `\n` separator the paginator uses internally.
- [ ] Commit: `test: HudStreamSession final page matches TextPaginator`.

### Task 1.5 — Page boundary (5-line overflow)

- [ ] Add test `test('7 lines produces page 0 full then page 1 partial then 0x40', ...)`: feed enough text for 7 wrapped lines in small deltas. Assert the emit sequence per spec §6:
  - Emits 1-4: page 0, `screenStatus == 0x30` (or 0x01|0x30 for the first), `pageIndex == 0`, `totalPages == 1`.
  - Emit 5: page 0 full with 5 lines, `screenStatus == 0x30`, `pageIndex == 0`, `totalPages == 1`.
  - Emit 6: page 1 first frame, `screenStatus == (0x01 | 0x30)`, `pageIndex == 1`, `totalPages == 2`.
  - Emit 7: page 1 second line, `screenStatus == 0x30`, `pageIndex == 1`.
  - Final: `0x40` on page 1.
- [ ] Run — **expect FAIL**.
- [ ] In `appendDelta`, after promoting a completed line: if `_lines.length == TextPaginator.linesPerPage`, call `_emit(streaming: true)` (page N full frame), then `_pageIndex++`, `_lines.clear()`, reset `_firstFrameSent = false` so the next emit sends `0x01 | 0x30`.
- [ ] Run — **expect PASS**.
- [ ] Commit: `feat: HudStreamSession page boundary handling`.

### Task 1.6 — Cancel mid-stream

- [ ] Add test `test('cancel mid-stream drops buffer and sends no 0x40', ...)`: feed 2 lines worth of deltas, call `cancel()`, then try further `appendDelta` and `finish()`. Assert no `0x40` ever emitted and calls after `cancel()` are no-ops.
- [ ] Run — expect current pass/fail; implement: `cancel()` sets `_cancelled = true`, clears `_lines` and `_pendingTail`, awaits `_inFlight` but issues no new send. `finish()` and `appendDelta` early-return when `_cancelled`.
- [ ] Run — **expect PASS**.
- [ ] Commit: `feat: HudStreamSession cancel preemption`.

### Task 1.7 — Long token (100-char unbroken run)

- [ ] Add test `test('100-char unbroken token emits one oversized line, no loop', ...)`: feed a single `appendDelta` with a 100-character string containing no spaces. Assert:
  - Test completes in <1s (no infinite loop).
  - At most one streaming emit before `finish()`, plus the final `0x40`.
  - The single line in the emit equals the 100-char input verbatim.
- [ ] Run — if implementation already handles this (since `splitIntoLines` returns `[input]` as a single oversized line with length 1), expect PASS. If not, guard `wrapped.length >= 2` check — single-line output leaves it in `_pendingTail` until `finish()`.
- [ ] Commit: `test: HudStreamSession long-token acceptance`.

### Task 1.8 — Backpressure coalescing

- [ ] Add test `test('slow sink coalesces rapid tokens without losing lines', ...)`: use a `ManualHudPacketSink` whose `send` returns a `Completer<void>.future` captured by the test. Feed 30 tokens fast (each one character), then complete the first in-flight emit. Assert:
  - No dropped lines: final committed `pageText` contains every character fed.
  - No emit was ever called while a previous emit was pending.
  - After all completers resolve and `finish()` awaits, last frame is `0x40`.
- [ ] Run — may fail if `_inFlight` serialization wasn't wired correctly in Task 1.3. Fix by ensuring every `_emit` awaits `_inFlight?.future` before calling `sink.send`, and installs a new completer it resolves after.
- [ ] Run — **expect PASS**.
- [ ] Run: `flutter analyze` — 0 errors.
- [ ] Commit: `feat: HudStreamSession single-slot backpressure queue`.

### Task 1.9 — Production sink binding

- [ ] In `hud_stream_session.dart`, add `class ProtoHudPacketSink implements HudPacketSink` whose `send` calls `Proto.sendEvenAIData(pageText, newScreen: screenStatus, pos: 0, current_page_num: pageIndex + 1, max_page_num: totalPages)`.
- [ ] Add a smoke test that constructs `ProtoHudPacketSink` and asserts it is a `HudPacketSink` (compile-level check only — do not invoke BLE).
- [ ] Run: `flutter analyze` — 0 errors.
- [ ] Run: `flutter test test/services/hud_stream_session_test.dart` — all green.
- [ ] Commit: `feat: ProtoHudPacketSink production binding`.

---

## Phase 2 — Wire into ConversationEngine behind a flag

### Task 2.1 — Add SettingsManager flag

- [ ] In `lib/services/settings_manager.dart`, add:
  - Private key constant `static const _kHudLineStreaming = 'hud.lineStreaming';`
  - `bool get hudLineStreamingEnabled => _prefs.getBool(_kHudLineStreaming) ?? false;`
  - `set hudLineStreamingEnabled(bool v) => _prefs.setBool(_kHudLineStreaming, v);`
- [ ] Add test in `test/services/settings_manager_test.dart` (or nearest equivalent) asserting default is `false` and setter persists.
- [ ] Run: `flutter test test/services/settings_manager_test.dart && flutter analyze`.
- [ ] Commit: `feat: add hud.lineStreaming settings flag (default off)`.

### Task 2.2 — Route streaming through HudStreamSession in ConversationEngine

- [ ] Read `lib/services/conversation_engine.dart:2413-2415` (`_streamToGlasses`) and the streaming buffer flush site (per CLAUDE.md ~line 1994, 2136) to confirm call sites that pass `isStreaming: true`.
- [ ] Add `HudStreamSession? _hudStreamSession;` as a private field on `ConversationEngine`.
- [ ] Modify `_streamToGlasses(String text, {required bool isStreaming})`:
  - If `!SettingsManager.instance.hudLineStreamingEnabled` → unchanged (call `_glassesSender`).
  - Else if `isStreaming`:
    - If `_hudStreamSession == null`, create one with a `ProtoHudPacketSink`.
    - Compute `delta` as the new suffix of `text` versus a tracked `_hudStreamAccumulated` field; call `_hudStreamSession!.appendDelta(delta)`.
  - Else (final frame): `await _hudStreamSession?.finish(); _hudStreamSession = null; _hudStreamAccumulated = '';`.
- [ ] Add a hook used by Spec A / new response start: when `_startNewResponse` (or equivalent; locate by grepping for where `_isFirstStreamFrame = true` is reset) fires, call `_hudStreamSession?.cancel(); _hudStreamSession = null; _hudStreamAccumulated = '';`.
- [ ] Expose a test seam: allow tests to inject a `HudPacketSink` factory to replace `ProtoHudPacketSink` in tests that exercise the flag path.
- [ ] Run: `flutter analyze` — 0 errors.
- [ ] Run: `flutter test test/` — all pass (flag default false means existing tests unaffected).
- [ ] Run: `bash scripts/run_gate.sh` (required — `conversation_engine.dart` is on the FULL gate list).
- [ ] Commit: `feat: route streaming HUD through HudStreamSession behind flag`.

### Task 2.3 — Integration test with flag on

- [ ] In `test/services/conversation_engine_test.dart` (or a new file), add a test that flips `hudLineStreamingEnabled = true`, injects a `RecordingHudPacketSink`, feeds a fake LLM stream of three paragraphs worth of tokens through the engine, and asserts flush count is roughly 1 per visual line (not 1 per token).
- [ ] Run: `flutter test && flutter analyze`.
- [ ] Run: `bash scripts/run_gate.sh`.
- [ ] Commit: `test: conversation_engine line-streaming integration`.

---

## Phase 3 — Hardware QA and flag flip

### Task 3.1 — Hardware QA on a real G1 pair

- [ ] Manual test plan (not automated):
  1. Pair a real G1 L+R pair with a debug build. Set `hudLineStreamingEnabled = true` via a temporary debug toggle in settings or via shared_preferences direct write.
  2. Ask a question that elicits a ~3-paragraph streaming answer from the default LLM provider.
  3. Observe: streaming cadence should advance roughly one visual line at a time (~2 Hz), not token-by-token. Flicker from full-page re-pushes should be noticeably reduced.
  4. Repeat with a 2-page answer to verify page-boundary transition is clean (page 0 fills, page 1 starts with a `0x01|0x30` frame, final `0x40` lands on the correct page).
  5. Mid-stream, trigger a cancellation (new question) and verify no stale `0x40` lands and the new response starts cleanly.
  6. Verify touchpad paging on the final multi-page answer still works (unchanged protocol).
- [ ] Capture notes in `docs/learning.md` under a new "HUD line streaming QA 2026-04-06" entry.
- [ ] Commit: `docs: HUD line-streaming hardware QA notes`.

### Task 3.2 — Flip flag default to true

- [ ] In `lib/services/settings_manager.dart`, change `hudLineStreamingEnabled` default from `false` to `true`.
- [ ] Update the settings_manager test expectations for the new default.
- [ ] Run: `flutter test && flutter analyze`.
- [ ] Run: `bash scripts/run_gate.sh`.
- [ ] Commit: `feat: enable HUD line streaming by default`.

---

## Phase 4 — Cleanup dead state

### Task 4.1 — Remove dead streaming HUD fields from ConversationEngine

- [ ] In `lib/services/conversation_engine.dart`, delete lines 98-100:
  - `int _lastStreamedByteLength = 0;`
  - `bool _isFirstStreamFrame = true;`
  - `int _lastStreamedPageIndex = 0;`
- [ ] In `_sendToGlasses` (line ~2363), delete the dead streaming branch (the `_isFirstStreamFrame` / `0x31` / `_lastStreamedByteLength` logic at lines ~2383-2398). The method should now only handle the non-streaming final-frame / text HUD path, simplifying to a single `Proto.sendEvenAIData` call with `screenCode` derived from `HudDisplayState.aiFrameForPage(isStreaming: false, ...)`.
- [ ] Verify nothing else reads those fields (grep across the repo).
- [ ] Run: `flutter analyze` — 0 errors.
- [ ] Run: `flutter test test/` — all pass.
- [ ] Run: `bash scripts/run_gate.sh`.
- [ ] Commit: `refactor: drop dead streaming HUD state from ConversationEngine`.

### Task 4.2 — Final validation sweep

- [ ] Run the full validation gate: `bash scripts/run_gate.sh`.
- [ ] Run: `flutter build ios --simulator --no-codesign` — must succeed.
- [ ] Confirm all 7 test assertions from spec §9 are covered (see mapping below).
- [ ] Commit: `chore: final validation for HUD line streaming`.

---

## Spec §9 test coverage mapping

| Spec requirement | Task |
|---|---|
| 1. Flush rate: 3-line → 4 total emits | Task 1.3 |
| 2. Page text monotonic prefix growth | Task 1.3 |
| 3. Final-page agreement with `paginateText(input).last` | Task 1.4 |
| 4. Page boundary: 7 lines → expected sequence | Task 1.5 |
| 5. Cancel mid-stream: no further emits, no 0x40 | Task 1.6 |
| 6. Long token: one oversized emit, no loop | Task 1.7 |
| 7. Backpressure: manual Completer, 30 tokens, no loss | Task 1.8 |

## Self-review checklist

- Wire format: cmd `0x4E`, `new_char_pos = 0`, `screen_status` from {`0x01|0x30`, `0x30`, `0x40`}. No new `Proto.sendEvenAIData` parameter. Confirmed in Task 1.9 and Task 2.2.
- No append semantics on `pos` — every emit ships the full current-page text. Confirmed in `_emit` design in Task 1.3.
- No new screen code. Only status-byte values already recognized by the firmware.
- `HudStreamSession` owns all per-stream HUD state; `ConversationEngine` fields at lines 98-100 are deleted in Phase 4.
- Flag-gated rollout with hardware QA before default flip.
- Every code-touching task lists exact file + line range and ends with `flutter analyze` and (for `conversation_engine.dart`) `bash scripts/run_gate.sh`.
- Edge cases from spec §7 covered: empty delta (Task 1.3 early return), literal `\n` (Task 1.3 forced break), long token (Task 1.7), cancel (Task 1.6), final page boundary (Task 1.5 plus finish behavior in Task 1.3).
