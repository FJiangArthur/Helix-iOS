# WS-J Fix Report — EvenAI listening indicator stabilization

**Tier-3** (demoted from initial Tier-1 by user during planning)
**Branch:** `helix-ws-j-listening-flash` → merged to `main`
**Commit:** `0324399`

**Note:** The fix agent crashed mid-run with API 529 (overloaded) AFTER completing the implementation + test file but BEFORE committing or writing the report. This report was completed by the orchestrator. The fix itself is the agent's work; only commit + gate run + report were completed by the orchestrator.

## RCA

EvenAI's "listening" indicator on the G1 HUD was flashing briefly during stream chunk delivery — a state-machine race in `HudController.transitionTo` where the `liveListening` intent was momentarily cleared and re-set as chunks arrived.

## Fix

`HudController.transitionTo` now latches any leave of `liveListening` within a 500ms stable window:
- New constant `liveListeningStableWindow = Duration(milliseconds: 500)`
- New state: `_liveListeningEnteredAt` (DateTime?), `_deferredLeaveTimer` (Timer?), `_pendingLeaveTransition` (`_DeferredTransition?`)
- On entering `liveListening`: timestamp is recorded, any pending deferred leave is cancelled (`_cancelDeferredLeave()`)
- On non-`liveListening` transition while `_currentIntent == liveListening` AND held duration < 500ms: deferred via Timer; most-recent-wins (replaces any prior pending leave)
- If a re-entry to `liveListening` arrives during the latch window, the deferred leave is cancelled entirely → indicator never flashes
- If no re-entry arrives, deferred leave fires after window expires → genuine intent changes still propagate
- `_cancelDeferredLeave()` helper cleans state and logs at debug
- `@visibleForTesting resetLiveListeningLatchForTest()` for unit test isolation
- `dispose()` cleans up the deferred timer

## Files

- `lib/services/hud_controller.dart` — +98 lines
- `test/services/hud_controller_listening_latch_test.dart` (NEW) — +134 lines, 4 tests

## Tests

All 4 pass:

1. `leave-then-reenter within 500ms window does not flash the indicator` — sends a leave, then re-entry within 50ms; asserts intent stays `liveListening`, `textTransfer` is never emitted
2. `leave without re-entry is applied after the 500ms stable window` — sends only a leave; waits 600ms; asserts deferred leave fires
3. `leave after the stable window is applied immediately` — waits 520ms in `liveListening` first; then leave fires immediately, no latch
4. `multiple rapid leave attempts keep coalescing — only the latest is queued` — three rapid leaves; asserts most recent wins after window expires

## Gate

- 536 passing / 4 failing (4 baseline-equivalent failures, same as post-hotfix HEAD 66352d6)
- Zero new failures introduced
- iOS sim build PASS
- Same 3 baseline FAIL categories (analyzer warnings 13>10, conversation_engine_analytics_test, coverage)

## HW Checklist (visual confirmation required on G1)

1. Pair G1 glasses, start a live listening session
2. Ask a multi-chunk question (e.g. "Tell me a story about robots in 5 sentences")
3. Watch the listening indicator on the HUD throughout the stream
4. **Acceptance:** indicator stays stable from start to end of stream — no momentary blank/flicker/flash
5. Repeat 5 times to confirm not intermittent
6. Test recovery: ask another question; assert the indicator handles the next session-start cleanly

## Coexistence with WS-D

WS-D's `EvenAI._flashFeedback` change (intent restoration via `restoreScreenIdForIntent`) lives in `evenai.dart`, not `hud_controller.dart`. They operate at different layers — no conflict. WS-J's latch sits in front of HudController's intent state machine; WS-D's flash-feedback restoration sits in EvenAI's per-screen feedback flow. Both are needed.
