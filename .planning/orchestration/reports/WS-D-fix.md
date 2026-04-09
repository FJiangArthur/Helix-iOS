# WS-D Fix — HUD factory-default reset after session start

**Bug:** Tier-1 #5 — "HUD occasionally resets to factory default after session
start (may correlate with thermal throttling)."
**Acceptance:** RCA documented; fix verified by 10 sequential session-starts
with no factory reset. (HW validation deferred to orchestrator — this
report covers simulator-level state-machine verification and provides the
HW checklist.)
**Worktree:** `/Users/artjiang/develop/Helix-iOS-beta` (branch
`helix-group-beta`)
**Investigation source of truth:** `.planning/orchestration/reports/WS-D-investigation.md`

---

## 1. Root cause confirmation

After reading every target file region cited in the investigation, the
H1 hypothesis is confirmed end-to-end:

1. `BitmapHudService._overlayVisible` has exactly one production mutator
   outside `setOverlayVisible`: `DashboardService.hideDashboard` at
   `lib/services/dashboard_service.dart:334`. That line runs **only
   after** `_restoreBitmapRoute` returns `true`. On failure the function
   early-returns at `:332` and leaves `_overlayVisible = true`.
2. `BitmapHudService._handleConnectionState`
   (`lib/services/bitmap_hud/bitmap_hud_service.dart:537-546`, pre-fix)
   was gated **only** on `_overlayVisible`. It did not consult
   `_conversationPaused`, so a BLE reconnect during an active
   live-listening session would call `pushFull()` and repaint the
   bitmap dashboard over the text HUD. To the user that looks identical
   to "HUD reset to factory default".
3. `EvenAI._flashFeedback` (H2, pre-fix at `lib/services/evenai.dart:284-297`)
   unconditionally called `Proto.pushScreen(0x00)` 500 ms after showing
   its toast, hiding the EvenAI overlay regardless of the current HUD
   intent. A stray right-touchpad event during liveListening therefore
   drops the glasses back to the firmware's stock dashboard.

All four fixes from the investigation's §"Proposed Minimal Fix" were
implemented verbatim. H3 (heartbeat race) was not touched — it is
LOW-confidence and the investigation explicitly marks it optional.

## 2. Files changed

| File | Change |
|---|---|
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | Fix #1: `_handleConnectionState` now also gates on `!_conversationPaused` on both the fast-path and slow-path branches. Fix #2: `setConversationActive(true)` force-clears `_overlayVisible`, drops `_lastSentBmp`, and cancels `_refreshTimer`. |
| `lib/services/dashboard_service.dart` | Fix #3: `hideDashboard` moves `_bitmapSetOverlayVisible(false)` to BEFORE the bitmap-hide failure early return. |
| `lib/services/evenai.dart` | Fix #4: `_flashFeedback`'s 500 ms auto-dismiss now routes through a new `@visibleForTesting` pure helper `restoreScreenIdForIntent(HudIntent)` that returns `0x01` for liveListening/textTransfer and `0x00` for idle-like intents, instead of unconditionally pushing `0x00`. Added `package:flutter/foundation.dart` import for `@visibleForTesting`. |
| `test/services/bitmap_hud_service_test.dart` | New test `WS-D: post-reconnect does not push while conversation is active`; new test `WS-D: setConversationActive(true) clears overlay flag and cache`; updated the existing `resuming conversation only pushes delta when overlay is visible` test to the new semantics (overlay flag now goes false when conversation becomes active). |
| `test/services/dashboard_service_test.dart` | New test `WS-D: hideDashboard clears overlay flag even when bitmap hide fails` injecting a failing `bitmapHideRenderer` and asserting `overlayVisibility` contains `false`. |
| `test/services/evenai_flash_feedback_test.dart` | New file pinning the `restoreScreenIdForIntent` mapping for all HudIntent variants. |

`ios/Runner/BluetoothManager.swift` was **not** modified — the
investigation flagged it as already correct (characteristic discovery
race was closed at `BluetoothManager.swift:427-470`).

## 3. Commits (SHAs)

All four commits on `helix-group-beta`, none pushed:

```
3950aed fix(evenai): restore current-intent screen after flash feedback (WS-D #4)
1830595 fix(dashboard): clear overlay flag even on bitmap hide failure (WS-D #3)
13eb47a fix(bitmap-hud): clear overlay flag when conversation becomes active (WS-D #2)
f1245f5 fix(bitmap-hud): gate post-reconnect pushFull on conversation state (WS-D #1)
```

Each commit is scoped to a single fix plus its test, per the task
process requirements.

## 4. Validation gate output (last 30 lines)

```
  win32 5.15.0 (6.0.0 available)
Got dependencies!
31 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Building com.artjiang.helix for simulator (ios)...
To ensure your app continues to launch on upcoming iOS versions, UIScene lifecycle support will soon be required. Please see https://flutter.dev/to/uiscene-migration for the migration guide.

Running Xcode build...
Xcode build done.                                            5.8s
OK Built build/ios/iphonesimulator/Even Companion.app
  PASS iOS simulator build succeeded
  INFO Elapsed: 12s

[6/7] Critical TODOs (threshold: 5)
  INFO lib/services/conversation_engine.dart — 5 TODO(s)
  PASS Critical TODOs: 5 (threshold: 5)
  INFO Elapsed: 0s

[7/7] Analyzer Warnings (threshold: 10)
  FAIL 13 warning(s) exceeds threshold of 10
  INFO Elapsed: 0s

========================================
 Summary
========================================
 Finished: 2026-04-08 17:25:56
 Total runtime: 60s

  3 GATE(S) FAILED
```

### Gate status versus baseline

Three gates fail, all **pre-existing** on the `helix-group-beta` HEAD
before any WS-D changes (verified by `git stash` → rerun → same state):

- **Unit tests had failures** — intermittent shared-state leak in
  `conversation_engine_analytics_test.dart` /
  `conversation_engine_proactive_test.dart` /
  `e2e_conversation_flow_test.dart` driven by SQLite duplicate-column
  DDL on repeated in-memory DB reuse. Baseline: 492 +4 failures. Post
  WS-D: 498 +3 failures (net-positive). The new tests added by this
  WS-D fix all pass cleanly both in isolation and in the full suite.
- **Coverage test run failed** — same root cause as the previous gate,
  baseline condition.
- **13 warnings > 10 threshold** — baseline on `helix-group-beta` also
  reports exactly 13 warnings (`flutter analyze | grep -c warning` ==
  `13` with changes stashed). No new warnings introduced. The warnings
  are unused dashboard-service fields (`_bitmapScreenHideRenderer`,
  `_bitmapScreenHideDelay`) plus analyzer info notices unrelated to
  this workstream.

### Targeted test runs (all green)

```
flutter test test/services/bitmap_hud_service_test.dart          -> +10 All tests passed!
flutter test test/services/dashboard_service_test.dart           -> +15 All tests passed!
flutter test test/services/evenai_flash_feedback_test.dart       -> +3  All tests passed!
```

## 5. Simulator observations

**Dedicated sim:** iPhone 17 Pro Max
`CF071276-D9E9-4DA0-9D4F-6EE67ACBB211` (NOT `0D7C3AB2` / Album Clean,
NOT `6D249AFF` / Pet App — this instance is unique to Helix-beta).

```
xcrun simctl boot     CF071276-D9E9-4DA0-9D4F-6EE67ACBB211   (OK — already Booted)
xcrun simctl install  CF071276-D9E9-4DA0-9D4F-6EE67ACBB211   build/ios/iphonesimulator/Even\ Companion.app
xcrun simctl launch   CF071276-D9E9-4DA0-9D4F-6EE67ACBB211   com.artjiang.helix
  -> com.artjiang.helix: 16052
```

`launchctl list | grep helix` after +5s: process still resident
(`UIKitApplication:com.artjiang.helix[...][rb-legacy]`). No crash on
launch. The BitmapHudService path does **not** exercise on the
simulator because there is no BLE peripheral to reconnect to — which
is exactly why the investigation explicitly scoped state-machine
coverage to Dart unit tests and declared HW runtime verification as
the acceptance gate.

Log scrape over 10 s:
```
log show --predicate 'processImagePath CONTAINS "Even Companion"' \
  | grep -iE "BitmapHud|pushFull|handleConnectionState|flashFeedback"
  -> (no matches)
```
No spurious pushFull invocations, no flashFeedback loops — expected
quiescent state with no BLE and no active session.

State-machine paths that would exercise on HW but cannot on sim:
- Post-reconnect `_handleConnectionState` → `pushFull` branch
- `hideDashboard` bitmap-hide ACK timeout → overlay-flag clear
- Touchpad-triggered `_flashFeedback` → post-500 ms screen restore
All three are covered by the new unit tests in this fix.

## 6. Hardware checklist for final acceptance (orchestrator to run)

Per the investigation §4 "Hardware (G1 + iPhone) — 10 sequential
session-starts". Acceptance = 10/10 PASS.

- [ ] Use iPhone 17 Pro Max (worst thermal, most likely to reproduce).
- [ ] Cold-launch the app. Confirm both L/R lenses connect.
- [ ] **Critical precondition:** open the bitmap dashboard once
      (tilt head up or preview) and let it auto-hide. This loads
      `_overlayVisible=true` into the service, which is the H1 stale
      flag the fix defends against. Without this step the bug could
      not reproduce even on the baseline.
- [ ] Pre-warm the phone with a single 60 s session before the 10-pass
      checklist to approximate the thermal pressure under which the
      bug was originally reported.
- [ ] **Per iteration (×10, no app restart between iterations):**
   1. Wait for the dashboard to auto-hide (or manually dismiss).
   2. Tap the live-session start button.
   3. Confirm the live-listening overlay appears on both lenses.
   4. Speak for ~30 s. Watch for any moment where the overlay
      disappears and a clock/weather/calendar dashboard frame appears.
   5. Stop the session.
   6. Record PASS if the live-listening overlay was the only thing
      on screen for the entire 30 s; FAIL otherwise.
   7. Touch the back of the phone; if still cool by iteration 5, run
      an extra 30-60 s warm-up session before iteration 6 to drive
      thermal pressure.
- [ ] Pass criterion: **10/10 PASS**. Any FAIL reopens WS-D.
- [ ] Optional auxiliary probes while the checklist runs:
   - `idevicesyslog | grep -E "BitmapHud|pushFull|G1DBG TX cmd=0x4e"`
     — confirm zero bitmap full-pushes between any session-start and
     its stop, and that 0x4E traffic during the session only carries
     legitimate liveListening screen_status values.
   - Console.app filter `[G1DBG]` — same expectation.
- [ ] Spot-verify touchpad-driven flash feedback (right touchpad
      during liveListening) does **not** drop the glasses back to
      stock dashboard — this exercises fix #4 (`_flashFeedback`
      screen restore) which cannot be covered by the main 10-pass loop
      unless the tester happens to bump the touchpad.

## 7. Out-of-scope deliberately left alone

- `ios/Runner/BluetoothManager.swift` — investigation explicitly says
  the characteristic discovery race is already closed; no changes.
- `lib/services/proto.dart` — packet layer is correct.
- `lib/services/hud_controller.dart` — intent state is authoritative
  and correct; the bug is downstream readers not respecting it. Fix
  #4 teaches `_flashFeedback` to respect it.
- `lib/services/recording_coordinator.dart` — orchestration is fine.
- Pre-existing flaky analytics / e2e tests — not touched; unrelated
  SQLite/DB ordering issue on repeated suite runs.
- Pre-existing 13 analyzer warnings — unrelated unused-field and
  unused-import notices; not this workstream.

---

**Status:** Fix implemented, tested at unit level, committed locally
on `helix-group-beta`. Ready for orchestrator HW validation pass.
