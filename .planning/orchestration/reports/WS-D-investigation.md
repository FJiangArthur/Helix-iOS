# WS-D Investigation — HUD factory-default reset after session start

**Bug:** "HUD occasionally resets to factory default after session start (may correlate with thermal throttling)." (Tier-1 #5)
**Acceptance for later fix:** RCA documented; fix verified by 10 sequential session-starts with no factory reset.
**Mode:** Read-only investigation. No code changes.
**Investigator:** WS-D agent, run from /Users/artjiang/develop/Helix-iOS (main worktree).

---

## 1. Reproduction Status

- **Cannot be reproduced on simulator.** The HUD is a hardware artifact that lives on the G1 glasses' OLED panels behind a real BLE link. The simulator has no peripheral, no `BluetoothManager`, and the entire `0x4E`/`0xF4` packet pipeline never fires.
- **Static analysis + log review only.** I traced the session-start call graph end-to-end (Dart `RecordingCoordinator` → `EvenAI` → `HudController` → `Proto` → `BleManager` → Swift `BluetoothManager.writeData`) and inspected the byte-level packets sent on each step.
- "Factory default" is interpreted here as: the glasses revert to their stock dashboard / clock face that the firmware shows when no app overlay is active — i.e. either (a) the firmware's own head-up dashboard re-asserted itself, or (b) we explicitly issued an exit/clear/screen-0x00 packet without re-pushing our overlay.

---

## 2. Root Cause Hypotheses (ranked)

### H1 — `_overlayVisible` stale + post-reconnect `pushFull()` race  (CONFIDENCE: HIGH)

**Mechanism.**
1. User had the bitmap dashboard visible at some earlier point in the session lifetime. `DashboardService._showDashboard` calls `_bitmapSetOverlayVisible(true)` (`lib/services/dashboard_service.dart:578`). This flips `BitmapHudService._overlayVisible` to `true`.
2. The dashboard auto-hides after `displayDuration` via `DashboardService.hideDashboard`, which on the bitmap path calls `_bitmapSetOverlayVisible(false)` (`dashboard_service.dart:334`). **Good.** But this runs **only after `_restoreBitmapRoute` succeeds** — if the 0x26 hide ack times out or `_bitmapHideRenderer()` returns false (lines 386-390), the function returns early at line 332 and `_overlayVisible` is **never flipped back to false**. Post that failure, the BitmapHudService still believes a bitmap dashboard is on screen even though the user has moved on.
3. User starts a live session via `RecordingCoordinator._startAll → EvenAI.startContinuousSession → HudController.beginLiveListening → Proto.pushScreen(0x01)`. This puts us into Even AI text-display mode on the glasses. **Nothing in this path tells `BitmapHudService` to set `_overlayVisible = false`.** `setOverlayVisible(false)` is only ever called from `DashboardService.hideDashboard` (verified — grep returns zero other call sites in production code; only tests call it).
4. While the live session is running, BLE momentarily drops and reconnects. Causes for the drop are well-attested in this codebase: (a) thermal throttling on iPhone 17 Pro Max during streaming (see commit `f8f0269`, the Live-Activity 1000/sec storm; commit `9f2012d` documents the thermal pressure path); (b) the periodic stale-partial reconnect at 25 identical OpenAI partials (`docs/learning.md` "Stale partial detection"); (c) the Tier-1 firmware-side reconnects already noted in `MEMORY.md` → `project_hardware_test_issues.md`.
5. On reconnect, `BitmapHudService._handleConnectionState` (`bitmap_hud_service.dart:537-546`) fires:
   ```
   if (state != BleConnectionState.connected || !_overlayVisible) return;
   await Future.delayed(_reconnectPushDelay);     // 3 seconds
   if (_overlayVisible && isEnabled && _isConnected()) {
     await pushFull();                            // <-- repaints the BITMAP DASHBOARD
   }
   ```
   Because `_overlayVisible` was never reset (step 2 OR step 3), the service repaints the **bitmap dashboard frame** straight onto the glasses, on top of the live-listening text display.
6. To the user, this looks identical to "the HUD reset to factory default": the live-listening overlay disappears and a clock/calendar/weather frame replaces it. It is not literally the firmware's stock UI — it is *our* idle bitmap dashboard, painted unexpectedly. From the outside the two are indistinguishable.

**Why it correlates with thermal.** The trigger is a BLE reconnect during a live session. Thermal throttling on iPhone 17 Pro is the largest single cause of mid-session BLE drops on this hardware (cf. WS-G's audit, commits `9f2012d`/`f8f0269`). It does not have to be thermal — any reconnect during a live session is enough — but thermal makes it many times more likely on the affected handsets, which matches the "occasionally" in the bug title.

**Falsifiable predictions.**
- Forcing a BLE reconnect 5–10 s into a live session should reproduce the symptom 100% of the time, *provided* the bitmap dashboard was opened earlier in app lifetime. Without ever having opened the dashboard, `_overlayVisible` stays at its `false` initial value and the bug never fires. This matches user reports of "occasional" / "intermittent".
- Cold-launching the app, never opening the dashboard, and starting a session immediately should *never* reproduce this even after a BLE reconnect.

**Evidence (file:line).**
- `lib/services/bitmap_hud/bitmap_hud_service.dart:99`     — `bool _overlayVisible = false;` (initial)
- `lib/services/bitmap_hud/bitmap_hud_service.dart:195-206` — `setOverlayVisible` is the only mutator outside tests
- `lib/services/bitmap_hud/bitmap_hud_service.dart:537-546` — post-reconnect `pushFull()` gated only on `_overlayVisible`
- `lib/services/dashboard_service.dart:578`               — only place that sets `_overlayVisible = true`
- `lib/services/dashboard_service.dart:321-338`           — only place that sets it back to `false`, **early-returns on bitmap-hide failure**
- `lib/services/conversation_engine.dart:251`             — `setConversationActive(true)` called on engine start, **but this only pauses the refresh timer; it does NOT clear `_overlayVisible` and does NOT prevent the post-reconnect pushFull**
- `lib/services/evenai.dart:85,121` — `BleManager.get().startSendBeatHeart()` runs, but neither `EvenAI.toStartEvenAIByOS` nor `startContinuousSession` ever touches `BitmapHudService`
- `lib/ble_manager.dart:257`                              — `_handleGlassesConnected` calls `startSendBeatHeart`; `BleConnectionState.connected` is emitted on this same path, which is what `BitmapHudService._connectionSub` listens to

---

### H2 — `_flashFeedback` clears the live overlay with `pushScreen(0x00)`  (CONFIDENCE: MEDIUM)

**Mechanism.** `EvenAI._flashFeedback` (`lib/services/evenai.dart:284-297`) shows a 500 ms toast and then unconditionally fires `Proto.pushScreen(0x00)`. `pushScreen(0x00)` sends `[0xF4, 0x00]` which in this codebase is the "hide EvenAI screen" command (see `HudController.transitionTo` lines 55-59 — `0x00` = hide, `0x01` = show). It does **not** restore the prior screen.

If the user double-taps the touchpad (or the firmware fires `evenaiStart` near the start of a session and later fires another touchpad event that triggers `_triggerManualQuestionDetection` → `_flashFeedback('Q&A...')`), the 0x00 push will hide the live-listening overlay 500 ms later. From there the firmware reverts to its own dashboard / clock — i.e. the "factory default" look.

**Why "after session start".** The window for an accidental flash is largest in the first 1-2 seconds after start, when the `evenaiStart` (`notifyIndex 23`) and any leftover queued touchpad events are still being drained.

**Caveats.** Less likely than H1 because (a) it requires a touchpad event, which the user reports do not always mention, and (b) the 0x00 only hides the EvenAI text overlay; the bitmap layer would not necessarily come up. But it would still match "HUD reset to factory default" as a description.

**Evidence.**
- `lib/services/evenai.dart:286-296` — `_flashFeedback` body
- `lib/services/hud_controller.dart:55-59` — confirms `0x00` is hide-overlay
- `lib/services/evenai.dart:274-281` — `_triggerManualQuestionDetection` is wired to right-touchpad in liveListening when no answer present; calls `_flashFeedback('Q&A...')`

---

### H3 — Heartbeat timer interaction with conversation suppression  (CONFIDENCE: LOW)

**Mechanism.** `BleManager.startSendBeatHeart` is called inside `EvenAI.toStartEvenAIByOS` / `startContinuousSession` *before* `ConversationEngine.start` runs `updateHeartbeatMode(true)`. There is a brief window where the heartbeat timer is armed at the 8-second "failure" interval, fires once with `_conversationActive=false`, and then the engine flips it off. If that one heartbeat write races with the 0x4E live-listening packets on the same characteristic, the firmware can drop the entire write and revert to its dashboard.

**Caveats.** This is a 1-tick race that should have been caught by the existing tests. I include it for completeness; it is the weakest of the three.

**Evidence.**
- `lib/services/evenai.dart:85,121` — `startSendBeatHeart()` early in start
- `lib/ble_manager.dart:284-291`    — timer armed at 8 s (`_failureHeartbeatInterval`)
- `lib/services/conversation_engine.dart:248-249` — `updateHeartbeatMode(true)` runs after engine start

---

### Hypotheses considered and ruled out

- **"Init race: evenai bootstrap fires before HUD widget registered."** Ruled out — `EvenAI` does not depend on any bitmap widget registration; the live-listening path uses raw `Proto.pushScreen(0x01)` and `Proto.sendEvenAIData`, which are stateless byte sends. No widget registration order matters here.
- **"Inadvertent factory-reset packet."** No code path constructs a `0x4E` packet with an unknown `screen_status`. All `sendEvenAIData` callers pass legitimate `HudDisplayState` values. There is no `0x18` (clear screen) issued during session start. Ruled out by grep over `Proto.sendEvenAIData` callers.
- **"Watchdog/reconnect path resetting the HUD."** This is essentially H1 — the reconnect itself doesn't reset anything; it's the post-reconnect `pushFull()` that does. Folded into H1.
- **"BLE timing race: write before characteristic discovery completes on dual L/R."** Already mitigated. `BluetoothManager.notifyGlassesConnectedIfReady` (`ios/Runner/BluetoothManager.swift:427-470`) defers `glassesConnected` until both `leftWChar` and `rightWChar` exist. `connectPeripheral` line 718-722 has an explicit comment stating the previous race is closed. I verified the dispatch order. Ruled out.
- **"Dual L/R out of sync at session start."** Mitigated by the 400 ms inter-side delay in `Proto._sendEvenAIDataPipeline` (line 165, 202). Both lenses receive the same packets.

---

## 3. Proposed Minimal Fix

**Files (allowlist):**
1. `lib/services/bitmap_hud/bitmap_hud_service.dart`
2. `lib/services/conversation_engine.dart`
3. `lib/services/dashboard_service.dart`
4. `test/services/bitmap_hud_service_test.dart`
5. `test/services/conversation_engine_*` (existing engine tests, additive only)

**Change description (no code):**

**(a) `BitmapHudService` — gate the post-reconnect `pushFull` on conversation state.**
In `_handleConnectionState` (`bitmap_hud_service.dart:537-546`), in addition to `_overlayVisible`, also require `!_conversationPaused` before calling `pushFull()`. Rationale: during an active conversation the live-listening overlay (text HUD) is the canonical screen. Repainting the bitmap dashboard on top of it is always wrong.

**(b) `BitmapHudService` — force `_overlayVisible = false` whenever conversation becomes active.**
In `setConversationActive(true)`, also set `_overlayVisible = false`, drop `_lastSentBmp`, and cancel `_refreshTimer` for the same reason. This is the belt-and-braces fix for the stale-flag case where the dashboard hide failed earlier. When the conversation ends and `setConversationActive(false)` runs, `_overlayVisible` will remain `false` until `DashboardService` legitimately calls `setOverlayVisible(true)` again — which is the correct semantics.

**(c) `DashboardService` — when `_restoreBitmapRoute` fails, still drop overlay-visible.**
In `hideDashboard` (`dashboard_service.dart:321-338`), the early return on bitmap-restore failure leaves `_overlayVisible = true`. Move `_bitmapSetOverlayVisible(false)` *before* the early return, so the service's view of overlay state matches reality even when the BLE write failed. The user already lost the dashboard frame at this point; clinging to the flag only causes the WS-D bug later.

**(d) `EvenAI._flashFeedback` — restore prior screen instead of pushing 0x00.**
After the 500 ms delay, instead of unconditionally `Proto.pushScreen(0x00)`, re-issue the screen state implied by `HudController.currentIntent` (e.g. for `liveListening`, push `0x01`). This kills H2 even if H1 is the dominant cause. (Optional but cheap.)

**(e) Tests.**
- Unit test: `BitmapHudService.handleConnectionStateForTest` with `_overlayVisible=true` AND `_conversationPaused=true` must NOT call the full sender. Currently the existing test at `test/services/bitmap_hud_service_test.dart:233` only covers the no-conversation case.
- Unit test: `BitmapHudService.setConversationActive(true)` must clear `_overlayVisible` and `_lastSentBmp`.
- Unit test: `DashboardService.hideDashboard` with a failing `bitmapHideRenderer` must still call `bitmapSetOverlayVisible(false)`.
- Unit test: `EvenAI._flashFeedback` (or its public callsite) followed by 600 ms wait must end with `pushScreen(0x01)`, not `pushScreen(0x00)`, when in liveListening intent.

No production code outside that 5-file allowlist needs to change.

---

## 4. Test Plan

### Simulator (state machine, no glasses required)

Run the bitmap HUD + dashboard service Dart tests:
```
flutter test test/services/bitmap_hud_service_test.dart
flutter test test/services/dashboard_service_test.dart
flutter test test/services/conversation_engine_lifecycle_test.dart  # if present, else skip
```

New tests to add (per fix item e):

1. **`BitmapHudService` — post-reconnect during conversation does NOT push.**
   - Construct via `BitmapHudService.test(...)` with `overlayVisible: true`.
   - Call `service.setConversationActive(true)`.
   - Call `handleConnectionStateForTest(BleConnectionState.connected)`.
   - Wait `reconnectPushDelay` (use `Duration.zero` in test).
   - Assert: `fullSender` invocations == 0.

2. **`BitmapHudService.setConversationActive(true)` clears overlay flag.**
   - Construct with `overlayVisible: true, lastSentBmp: someBytes`.
   - Call `setConversationActive(true)`.
   - Assert: `service.isOverlayVisible == false`. Cached frame invalidated.
   - Then call `handleConnectionStateForTest(BleConnectionState.connected)` and assert no full push.

3. **`DashboardService.hideDashboard` — failing bitmap hide still drops overlay flag.**
   - Inject a `bitmapHideRenderer` that returns false.
   - Inject a recording stub for `bitmapSetOverlayVisible`.
   - Call `hideDashboard`.
   - Assert: stub recorded `false` exactly once even though restore failed.

4. **`EvenAI._flashFeedback` restores liveListening screen.**
   - Set `HudController.instance._currentIntent` to `HudIntent.liveListening` via existing test seam (or call `beginLiveListening` first with mock pushScreen).
   - Inject a mock for `Proto.pushScreen` that records calls.
   - Trigger the feedback path.
   - After 600 ms `Future.delayed`, assert the last recorded `pushScreen` call == `0x01`, not `0x00`.

5. **Regression: existing dashboard auto-hide tests still pass** — they cover the success path of `_bitmapSetOverlayVisible(false)` from line 334.

### Hardware (G1 + iPhone) — 10 sequential session-starts

Acceptance criterion verbatim: *"fix verified by 10 sequential session-starts with no factory reset"*.

Setup:
- iPhone 17 Pro Max (handset most affected by thermal).
- G1 glasses paired and connected (both lenses green in app status bar).
- Cold-launch the app, then **deliberately open the bitmap dashboard once** before each session start, and let it auto-hide. This is critical: it loads `_overlayVisible=true` into the stale-flag state and is the precondition for H1 in the field.
- For maximum thermal pressure, pre-warm the phone by running a 60-second session immediately before starting the checklist.

Per-iteration steps (repeat 10 times back-to-back, no app restart between iterations):
1. Wait for the dashboard to auto-hide (or manually dismiss).
2. Tap the live-session start button.
3. Watch both lenses for the live-listening overlay to appear.
4. Speak for ~30 seconds. Watch for any moment where the overlay vanishes and a clock/weather/calendar frame appears in its place.
5. Stop the session.
6. Record: PASS if the live-listening overlay was the only thing on screen for the entire 30 s; FAIL if a dashboard or stock UI appeared at any point.
7. Note phone temperature (touch the back) — if comfortable through iteration 5, intentionally drive it hotter with an extra warm-up session before iteration 6.

Pass criterion: 10/10 PASS. Any FAIL → fix is incomplete; reopen.

Auxiliary HW probes (optional but recommended):
- `idevicesyslog | grep -E "BitmapHud|pushFull|G1DBG TX cmd=0x4e"` — confirm no bitmap full pushes happen between session-start and session-stop.
- `Console.app` filter `[G1DBG]` — confirm the only `0x4E` packets between start and stop carry valid `screen_status` for live listening.

---

## 5. File Allowlist

The fix agent for WS-D MAY modify only these files:

1. `lib/services/bitmap_hud/bitmap_hud_service.dart`
2. `lib/services/conversation_engine.dart`  *(only `setConversationActive` invocation site, if any guard is added there)*
3. `lib/services/dashboard_service.dart`
4. `lib/services/evenai.dart`  *(only `_flashFeedback`, if H2 mitigation is included)*
5. `test/services/bitmap_hud_service_test.dart`
6. `test/services/dashboard_service_test.dart`
7. `test/services/evenai_*` *(new file allowed if no existing one)*

Files explicitly OUT OF SCOPE for this WS-D fix:
- `ios/Runner/BluetoothManager.swift` — already correctly defers `glassesConnected` until characteristics ready; no native change needed.
- `lib/services/proto.dart` — packet protocol is correct.
- `lib/services/hud_controller.dart` — current intent state is fine; the fix is in the bitmap layer not respecting it.
- `lib/services/recording_coordinator.dart` — the orchestration layer is correct; the bug is downstream.

---

## 6. Summary

The most likely root cause is **H1: a stale `_overlayVisible` flag in `BitmapHudService` combined with an unconditional post-reconnect `pushFull()`** that repaints the bitmap dashboard on top of an active live-listening overlay during the very BLE reconnects that thermal throttling causes. The "factory default" the user sees is *our own idle bitmap dashboard*, not the firmware's. The fix is small, localized, fully unit-testable on the simulator, and gated by 10 sequential session-starts on hardware for final acceptance.

Confidence ranking: H1 high, H2 medium, H3 low. Recommend the fix agent address H1 + H2 in the same patch (both are low-cost and the H2 mitigation kills a separate latent factory-default vector).
