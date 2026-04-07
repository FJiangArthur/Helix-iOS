# Line-by-Line HUD Streaming Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce BLE write rate during LLM streaming by gating flushes on visual-line completion instead of per-token, while extracting the existing streaming HUD state off `ConversationEngine` into a dedicated `HudStreamSession` class with proper test coverage.

**Architecture:** Absorb the existing `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex` fields on `ConversationEngine` into a new `HudStreamSession` class. Change the flush trigger from the current per-token debounce (75ms / 14 chars) to per-completed-visual-line, using `TextPaginator.splitIntoLines` on the unsent tail. The wire format and per-page screen code logic already landed in checkpoint `10905f7` — nothing changes there.

**Tech Stack:** Flutter 3.35+, Dart, iOS 26 deployment target

**Scope note:** The per-page screen codes, correct `current_page_num`, and 400ms inter-side delay are ALREADY LANDED in checkpoint `10905f7`. Do not re-implement them. See spec §1 "What the in-flight work already fixes."

**Depends on:** Spec A (Priority Pipeline) for `HudStreamSession.cancel()` preemption hook.

**Source spec:** `docs/superpowers/specs/2026-04-06-hud-line-streaming-design.md` (reconciled commit `dfb2001`, audited against branch checkpoint `10905f7`).

---

## File structure

**New files:**
- `lib/services/hud_stream_session.dart` — `HudPacketSink` interface, `ProtoHudPacketSink` production binding, `HudStreamSession` state machine.
- `test/services/hud_stream_session_test.dart` — unit tests with `RecordingHudPacketSink` and `ManualHudPacketSink`.

**Modified files:**
- `lib/services/conversation_engine.dart` — Phase 2: route `_streamToGlasses` (~line 2413) through `HudStreamSession` behind a flag. Phase 3 (cleanup): delete the three streaming HUD fields at lines 98-100 and the dead branch in `_sendToGlasses` (~lines 2363-2411).
- `lib/services/settings_manager.dart` — add `hudLineStreamingEnabled` flag backed by SharedPreferences key `hud.lineStreaming`.

**Unchanged (verified — in-flight checkpoint `10905f7` already fixes these):**
- `lib/services/proto.dart` — `sendEvenAIData` + 400ms inter-side delay (lines 166-168). **No edits.**
- `lib/services/glasses_protocol.dart` — `aiFrameForPage` + `textPageForIndex`. **No edits.**
- `lib/services/text_paginator.dart` — `splitIntoLines` (lines 100-126), `linesPerPage = 5`. **No edits.**

---

## Phase 1 — HudStreamSession + HudPacketSink with full unit coverage (no wiring)

### Task 1.1 — Skeleton + failing empty-stream test

- [ ] Create `lib/services/hud_stream_session.dart`:
  ```dart
  import 'dart:async';
  import 'package:helix/services/proto.dart';
  import 'package:helix/services/text_paginator.dart';

  abstract class HudPacketSink {
    Future<void> send({
      required int screenStatus,
      required int pageIndex,
      required int totalPages,
      required String pageText,
    });
  }

  class HudStreamSession {
    HudStreamSession({required this.sink});
    final HudPacketSink sink;
  }
  ```
- [ ] Create `test/services/hud_stream_session_test.dart` with:
  ```dart
  class RecordingHudPacketSink implements HudPacketSink {
    final List<({int screenStatus, int pageIndex, int totalPages, String pageText})> calls = [];
    @override
    Future<void> send({required int screenStatus, required int pageIndex, required int totalPages, required String pageText}) async {
      calls.add((screenStatus: screenStatus, pageIndex: pageIndex, totalPages: totalPages, pageText: pageText));
    }
  }

  void main() {
    test('empty stream finish sends one 0x40 with empty body', () async {
      final sink = RecordingHudPacketSink();
      final session = HudStreamSession(sink: sink);
      await session.finish();
      expect(sink.calls, hasLength(1));
      expect(sink.calls.single.screenStatus, 0x40);
      expect(sink.calls.single.pageText, '');
    });
  }
  ```
- [ ] Run `flutter test test/services/hud_stream_session_test.dart` — **expect FAIL** (`finish` undefined).
- [ ] Commit: `test: failing HudStreamSession skeleton`.

### Task 1.2 — Minimal appendDelta / finish / cancel

- [ ] In `hud_stream_session.dart`, add private state per spec §4:
  ```dart
  int _pageIndex = 0;
  final List<String> _lines = [];
  String _pendingTail = '';
  bool _firstFrameSent = false;
  bool _cancelled = false;
  Future<void> _inFlight = Future.value();
  ```
- [ ] Add stub methods `appendDelta(String delta)`, `finish()`, `cancel()`. `finish()` should await `_inFlight`, then if `!_cancelled` call `sink.send(screenStatus: 0x40, pageIndex: 0, totalPages: 1, pageText: '')`.
- [ ] Run `flutter test test/services/hud_stream_session_test.dart` — **expect PASS**.
- [ ] Run `flutter analyze` — expect 0 errors.
- [ ] Commit: `feat: HudStreamSession skeleton with empty-stream finish`.

### Task 1.3 — Line detection + monotonic flush (core test case)

- [ ] Add test (asserts spec §9 items 1 and 2):
  ```dart
  test('3-line response produces 3 streaming emits + final 0x40, monotonic growth', () async {
    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    // Pick input whose splitIntoLines yields exactly 3 lines at 488px / 21pt.
    const input = 'The quick brown fox jumps over the lazy dog. '
        'Pack my box with five dozen liquor jugs. '
        'How vexingly quick daft zebras jump today.';
    // Feed token-by-token (one char at a time) to prove per-token flushing is gone.
    for (final ch in input.split('')) {
      await session.appendDelta(ch);
    }
    await session.finish();

    expect(sink.calls.length, 4, reason: 'exactly 3 streaming + 1 final');
    expect(sink.calls[0].screenStatus, 0x01 | 0x30);
    expect(sink.calls[1].screenStatus, 0x30);
    expect(sink.calls[2].screenStatus, 0x30);
    expect(sink.calls[3].screenStatus, 0x40);

    // Monotonic prefix growth.
    for (var i = 1; i < 3; i++) {
      expect(sink.calls[i].pageText.startsWith(sink.calls[i - 1].pageText), isTrue);
    }
  });
  ```
- [ ] Run — **expect FAIL**.
- [ ] Implement `appendDelta`:
  1. Early-return if `_cancelled` or `delta.isEmpty`.
  2. For each character, handle literal `\n`: split `_pendingTail` on `\n`, promoting each non-final segment to a completed line via `_commitLine(segment)`; keep the remainder as the new `_pendingTail`.
  3. Append non-newline text to `_pendingTail`.
  4. Run `final wrapped = TextPaginator.instance.splitIntoLines(_pendingTail);`.
  5. If `wrapped.length >= 2`, for each all-but-last entry call `_commitLine(entry)`; set `_pendingTail = wrapped.last`; emit once via `_emitStreaming()`.
- [ ] Implement `_commitLine(String line)`:
  - `_lines.add(line);`
  - If `_lines.length == TextPaginator.linesPerPage` — defer page-boundary handling to Task 1.5.
- [ ] Implement `_emitStreaming()`:
  - Serialize through `_inFlight`:
    ```dart
    final prev = _inFlight;
    final completer = Completer<void>();
    _inFlight = completer.future;
    await prev;
    if (_cancelled) { completer.complete(); return; }
    final int status = _firstFrameSent ? 0x30 : (0x01 | 0x30);
    _firstFrameSent = true;
    final pageText = _pageTextSnapshot();
    try {
      await sink.send(
        screenStatus: status,
        pageIndex: _pageIndex,
        totalPages: _pageIndex + 1,
        pageText: pageText,
      );
    } finally {
      completer.complete();
    }
    ```
- [ ] Implement `String _pageTextSnapshot() => [..._lines, if (_pendingTail.isNotEmpty) _pendingTail].join('\n');`
- [ ] Implement `finish()`:
  - Await `_inFlight`.
  - If `_cancelled`, return.
  - If `_pendingTail.isNotEmpty` or `_lines.isNotEmpty`, issue one more streaming emit so the last in-progress line lands with `0x30`.
  - Then issue a final emit with `screenStatus: 0x40, pageIndex: _pageIndex, totalPages: _pageIndex + 1, pageText: _pageTextSnapshot()`, serialized through `_inFlight`.
- [ ] Run — **expect PASS**.
- [ ] Run `flutter analyze` — 0 errors.
- [ ] Commit: `feat: HudStreamSession line-gated flush via splitIntoLines`.

### Task 1.4 — Final-page agreement drift guard (spec §9 item 3)

- [ ] Add test:
  ```dart
  test('last streaming emit pageText equals TextPaginator last page', () async {
    final sink = RecordingHudPacketSink();
    final session = HudStreamSession(sink: sink);
    const input = 'Some multi-line answer text that wraps across several visual rows '
        'at 488 pixels by 21 point and finishes on a partial line.';
    for (final ch in input.split('')) {
      await session.appendDelta(ch);
    }
    await session.finish();
    final pages = TextPaginator.instance.paginateText(input);
    final lastStreaming = sink.calls.lastWhere((c) => c.screenStatus != 0x40);
    expect(lastStreaming.pageText, pages.last);
  });
  ```
- [ ] Run — expect PASS (or fix join separator if it drifts from the paginator's internal newline).
- [ ] Commit: `test: HudStreamSession final page matches TextPaginator`.

### Task 1.5 — Page boundary (spec §9 item 4)

- [ ] Add test: feed enough characters to produce 7 wrapped lines, then `finish()`. Assert:
  - 5 emits with `pageIndex == 0` (first has `0x01|0x30`, rest `0x30`), the 5th containing the full 5-line page.
  - 2 emits with `pageIndex == 1` (first `0x01|0x30`, second `0x30`).
  - Final `0x40` on `pageIndex == 1`, `totalPages == 2`.
- [ ] Run — **expect FAIL**.
- [ ] In `_commitLine`, when `_lines.length == TextPaginator.linesPerPage`:
  1. Call `_emitStreaming()` to push the now-full page one last time (still `0x30` since first frame already sent).
  2. Await that emit.
  3. `_pageIndex++; _lines.clear(); _firstFrameSent = false;` — next emit will send `0x01|0x30` on the new page.
- [ ] Ensure `_emitStreaming`'s `totalPages` calculation uses `_pageIndex + 1` so page 1 frames correctly report `totalPages: 2`.
- [ ] Run — **expect PASS**.
- [ ] Commit: `feat: HudStreamSession page boundary handling`.

### Task 1.6 — Cancel mid-stream (spec §9 item 5)

- [ ] Add test: feed ~2 lines, call `cancel()`, then `appendDelta('more')` and `finish()`. Assert no `0x40` emitted after cancel and no further emits from post-cancel calls.
- [ ] Implement `cancel()`:
  ```dart
  Future<void> cancel() async {
    _cancelled = true;
    _lines.clear();
    _pendingTail = '';
    await _inFlight;
  }
  ```
  `appendDelta` and `finish` already early-return on `_cancelled`.
- [ ] Run — **expect PASS**.
- [ ] Commit: `feat: HudStreamSession cancel preemption`.

### Task 1.7 — Long-token + backpressure + production sink

- [ ] **Long token test (spec §9 item 6):** feed one `appendDelta` with a 100-char unbroken run (no spaces). Assert test completes <1s, and that the oversized line is held in `_pendingTail` (no streaming emit yet because `wrapped.length == 1`), then `finish()` produces one streaming emit containing the run followed by `0x40`.
- [ ] **Backpressure test (spec §9 item 7):** add `ManualHudPacketSink`:
  ```dart
  class ManualHudPacketSink implements HudPacketSink {
    final List<Completer<void>> pending = [];
    final List<({int screenStatus, int pageIndex, int totalPages, String pageText})> calls = [];
    @override
    Future<void> send({required int screenStatus, required int pageIndex, required int totalPages, required String pageText}) {
      calls.add((screenStatus: screenStatus, pageIndex: pageIndex, totalPages: totalPages, pageText: pageText));
      final c = Completer<void>();
      pending.add(c);
      return c.future;
    }
  }
  ```
  Feed 30 one-char tokens fast without awaiting, then drain `pending` in order. Assert:
  - No two sends are ever in flight simultaneously (each new call arrives only after the previous completer resolved).
  - The final committed `pageText` contains every character fed.
  - `finish()` lands with `0x40`.
- [ ] **Production sink binding:** in `hud_stream_session.dart` add
  ```dart
  class ProtoHudPacketSink implements HudPacketSink {
    @override
    Future<void> send({required int screenStatus, required int pageIndex, required int totalPages, required String pageText}) {
      return Proto.sendEvenAIData(
        pageText,
        newScreen: screenStatus,
        pos: 0,
        current_page_num: pageIndex + 1,
        max_page_num: totalPages,
      );
    }
  }
  ```
  Verify the argument names against the actual `Proto.sendEvenAIData` signature in `lib/services/proto.dart:121` and fix any naming mismatch — do **not** change `proto.dart`. Add a compile-level smoke test: `expect(ProtoHudPacketSink(), isA<HudPacketSink>());`.
- [ ] Run `flutter test test/services/hud_stream_session_test.dart` — all green.
- [ ] Run `flutter analyze` — 0 errors.
- [ ] Commit: `feat: HudStreamSession long-token, backpressure, ProtoHudPacketSink`.

---

## Phase 2 — Wire into ConversationEngine behind a flag (default off)

### Task 2.1 — SettingsManager flag

- [ ] In `lib/services/settings_manager.dart`, add:
  ```dart
  static const _kHudLineStreaming = 'hud.lineStreaming';
  bool get hudLineStreamingEnabled => _prefs.getBool(_kHudLineStreaming) ?? false;
  set hudLineStreamingEnabled(bool v) => _prefs.setBool(_kHudLineStreaming, v);
  ```
  (Match the surrounding style in that file — use secure storage or plain prefs consistently with other bool flags.)
- [ ] Run `flutter analyze` — 0 errors.
- [ ] Commit: `feat: add hud.lineStreaming settings flag (default off)`.

### Task 2.2 — Route `_streamToGlasses` through HudStreamSession

- [ ] Read `lib/services/conversation_engine.dart:94-100` (existing `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex`) and `_sendToGlasses` at 2363-2411 and `_streamToGlasses` at 2413, plus all `_streamToGlasses(..., isStreaming: true)` call sites (expected around lines 692, 959, 1986, 2078 per reconciled spec §1).
- [ ] Add private fields to `ConversationEngine`:
  ```dart
  HudStreamSession? _hudStreamSession;
  String _hudStreamAccumulated = '';
  HudPacketSink Function()? _hudPacketSinkFactoryForTest; // test seam
  ```
- [ ] Modify `_streamToGlasses(String text, {required bool isStreaming})`:
  - If `!SettingsManager.instance.hudLineStreamingEnabled`: unchanged — fall through to the existing `_sendToGlasses` code path.
  - Else if `isStreaming`:
    - If `_hudStreamSession == null`:
      - `final sink = (_hudPacketSinkFactoryForTest ?? () => ProtoHudPacketSink())();`
      - `_hudStreamSession = HudStreamSession(sink: sink);`
      - `_hudStreamAccumulated = '';`
    - Compute `final delta = text.substring(_hudStreamAccumulated.length);` (guard against non-prefix updates — if `!text.startsWith(_hudStreamAccumulated)`, cancel and restart the session).
    - `_hudStreamAccumulated = text;`
    - `await _hudStreamSession!.appendDelta(delta);`
    - Return without calling `_sendToGlasses`.
  - Else (final frame): `await _hudStreamSession?.finish(); _hudStreamSession = null; _hudStreamAccumulated = '';` then return. Do **not** call `_sendToGlasses` on the final when the flag is on — `finish()` owns the `0x40` write.
- [ ] New-response preemption: locate where the existing `_isFirstStreamFrame = true` reset fires (Grep for `_isFirstStreamFrame = true` and the "new response starting" site). Alongside that reset, when the flag is on, add:
  ```dart
  if (SettingsManager.instance.hudLineStreamingEnabled) {
    final old = _hudStreamSession;
    _hudStreamSession = null;
    _hudStreamAccumulated = '';
    unawaited(old?.cancel());
  }
  ```
- [ ] Run `flutter analyze` — 0 errors.
- [ ] Run `flutter test test/` — all pass (flag default false, existing tests untouched).
- [ ] Run `bash scripts/run_gate.sh` — MANDATORY (touching `conversation_engine.dart`).
- [ ] Commit: `feat: route streaming HUD through HudStreamSession behind flag`.

### Task 2.3 — Integration test with flag on

- [ ] In `test/services/conversation_engine_test.dart` (or a new `conversation_engine_hud_stream_test.dart` if the existing file does not already build an engine under test), add a test that:
  1. Sets `SettingsManager.instance.hudLineStreamingEnabled = true`.
  2. Injects a `RecordingHudPacketSink` via `engine._hudPacketSinkFactoryForTest = () => sink;` (or a public test seam equivalent — add one if none exists).
  3. Drives `_streamToGlasses` with a sequence of incrementally-growing strings mimicking LLM token arrival (e.g., feed each substring `text.substring(0, n)` for `n` in `1..text.length`).
  4. Asserts emit count roughly equals `splitIntoLines(text).length + 1` (not `text.length`), confirming per-token flushing is gone.
  5. Cleans up by resetting the flag to `false` in `tearDown`.
- [ ] Run `flutter test test/services/conversation_engine_test.dart`.
- [ ] Run `bash scripts/run_gate.sh`.
- [ ] Commit: `test: conversation_engine line-streaming integration`.

---

## Phase 3 — Cleanup dead state (after one release with flag on by default)

> This phase lands after hardware QA and a release where the flag default flips to `true` via a trivial edit in `settings_manager.dart`. That flag flip is intentionally **not** a separate task here — it is a one-line change owned by release management, not by this plan.

### Task 3.1 — Delete dead streaming HUD fields

- [ ] In `lib/services/conversation_engine.dart` lines 94-100, delete:
  - `int _lastStreamedByteLength = 0;`
  - `bool _isFirstStreamFrame = true;`
  - `int _lastStreamedPageIndex = 0;`
- [ ] In `_sendToGlasses` (lines 2363-2411), delete the branch that reads/writes those three fields. The method should now handle only the non-streaming / text-HUD final-frame path, delegating streaming entirely to `HudStreamSession`. Any remaining call site that passed `isStreaming: true` into `_sendToGlasses` must be routed through `_streamToGlasses` instead.
- [ ] Grep the repo for the deleted identifiers to confirm zero references remain.
- [ ] Delete the `!hudLineStreamingEnabled` fallback branch in `_streamToGlasses` from Task 2.2 — streaming always goes through `HudStreamSession` now.
- [ ] Consider deleting the `SettingsManager.hudLineStreamingEnabled` flag entirely, or downgrading it to a kill-switch that stays in place for one more release — flag this as a judgment call in the commit message.
- [ ] Run `flutter analyze` — 0 errors.
- [ ] Run `flutter test test/`.
- [ ] Run `bash scripts/run_gate.sh`.
- [ ] Run `flutter build ios --simulator --no-codesign` — must succeed.
- [ ] Commit: `refactor: drop dead streaming HUD state from ConversationEngine`.

---

## Spec §9 test coverage mapping

| Spec requirement | Task |
|---|---|
| 1. Flush rate — 3-line → 4 total emits | Task 1.3 |
| 2. Monotonic prefix growth within a page | Task 1.3 |
| 3. Final page matches `paginateText(input).last` | Task 1.4 |
| 4. Page boundary — 7 lines → expected sequence | Task 1.5 |
| 5. Cancel mid-stream — no further emits, no 0x40 | Task 1.6 |
| 6. Long token — one oversized line, no loop | Task 1.7 |
| 7. Backpressure — manual Completer, 30 tokens, no loss | Task 1.7 |

## Self-review checklist

- Wire format unchanged: cmd `0x4E`, `pos = 0`, status in {`0x01|0x30`, `0x30`, `0x40`}. `proto.dart` and `glasses_protocol.dart` are untouched.
- Per-page screen codes, correct `current_page_num`, and 400ms inter-side delay are NOT re-implemented — they live in checkpoint `10905f7` already.
- `HudStreamSession` absorbs the three fields currently at `conversation_engine.dart:94-100`. It does not introduce parallel state.
- The `_pageByteLength` / append-offset field from the original Spec B draft is deliberately absent (see reconciled spec §4).
- Every §9 test requirement maps to a concrete task above.
- Every code-touching task ends with `flutter analyze` and, for `conversation_engine.dart` edits, `bash scripts/run_gate.sh` (CLAUDE.md mandatory full-gate list).
- Edge cases (empty delta, literal `\n`, long token, cancel, final on page boundary, empty answer) covered by Tasks 1.3, 1.5, 1.6, 1.7.
- Flag-gated rollout: default `false` in Phase 2, flipped by release management before Phase 3 cleanup lands.
