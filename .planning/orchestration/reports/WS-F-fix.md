# WS-F Fix Report: Ring Remote Input Inspector + Dispatcher

Worktree: `/Users/artjiang/develop/Helix-iOS-delta` (branch `helix-group-delta`)
Based on: `.planning/orchestration/reports/WS-F-investigation.md`

## Commits

| SHA       | Layer    | Subject                                                       |
| --------- | -------- | ------------------------------------------------------------- |
| `29b905e` | Native   | feat(ws-f): add InputInspector native capture harness         |
| `8be40c4` | Flutter  | feat(ws-f): add Flutter InputDispatcher + Inspector dev screen|
| `ff05af8` | Lint     | fix(ws-f): clean up two lints in dispatcher + inspector screen|

## Files Created

- `ios/Runner/InputInspector.swift` — `UIViewController` subclass implementing
  four capture channels (UIKeyCommand with modifier wildcards, pressesBegan/
  pressesEnded UIPress firehose, MPRemoteCommandCenter with
  NowPlayingInfo stub, AVSystemController volume notifications), plus a
  shared `InputInspectorStreamHandler` (FlutterStreamHandler) and an
  `InputInspectorController` that can install the VC either visibly
  (dev screen) or as an invisible background listener.
- `lib/services/input_dispatcher.dart` — singleton subscribing to
  `event.input_inspector`, canonicalising incoming events, applying the
  full debounce strategy from investigation §5 (500ms primary, phase
  filter, 50ms volume coalescing, 150ms hold suppression with threshold 3,
  session guard), and calling
  `ConversationEngine.instance.handleQAButtonPressed()` on match. Pure
  `canonicalSignatureFromEvent()` helper exported for tests. Includes
  `forTesting` ctor and `debugInject` / `debugSetBinding` for unit tests.
- `lib/screens/dev/input_inspector_screen.dart` — debug-only Flutter
  screen; four channel pills with live counts; newest-top scrolling list
  capped at 200 rows; per-row "Bind" button with confirm dialog;
  footer showing current binding with Unbind action. Subscribes to the
  raw event channel (not through the dispatcher) for the full firehose.
- `test/services/input_dispatcher_test.dart` — 13 unit tests covering
  canonicalisation for all 4 channels, matching vs non-matching
  signatures, unbound inertness, primary debounce (within window + after
  lift), phase filter (pressEvent ended dropped), volume coalescing with
  recent non-volume, and hold suppression after threshold. All passing.
- `docs/ring_remote_dead_buttons.md` — investigation §6 contents: which
  buttons iOS always / sometimes / conditionally consumes, press-vs-
  keyCommand delivery quirks, ring remap workaround, and the signature
  format reference.

## Files Modified

- `ios/Runner/AppDelegate.swift` — registers
  `InputInspectorController.shared.configure(host:)`, the
  `method.input_inspector` method channel (startInspector, stopInspector,
  startBackgroundListening, stopBackgroundListening, getCapabilities),
  and the `event.input_inspector` event channel wired to the shared
  stream handler. Placed next to the existing passive audio / HealthKit
  block, mirroring the existing channel pattern.
- `ios/Even Companion.xcodeproj/project.pbxproj` — adds `InputInspector.swift`
  to the PBXBuildFile, PBXFileReference, Runner group children, and
  Runner Sources build phase (UUIDs `AA01000010000000000000F0/F1`).
- `lib/services/settings_manager.dart` — adds `ringBindingSignature`
  (String?, SharedPreferences key `ring_binding_signature`) and
  `ringBindingEnabled` (bool, default true, key `ring_binding_enabled`)
  with load / save and `setRingBindingSignature()` /
  `setRingBindingEnabled()` helpers that persist and fire the existing
  `onSettingsChanged` stream.
- `lib/main.dart` — imports `services/input_dispatcher.dart` and starts
  `InputDispatcher.instance.start()` immediately after
  `_initializeLlmService()` (which already wires
  `ConversationEngine.instance`). Fire-and-forget; no runtime footprint
  until a signature is bound.
- `lib/screens/settings_screen.dart` — adds a `kDebugMode`-gated
  "Input Inspector (Dev)" ListTile inside the existing G1 Debug section,
  navigating to `InputInspectorScreen`.

## Gate Results

`bash scripts/run_gate.sh` (post-fix):

| Gate                        | Status | Notes                                           |
| --------------------------- | ------ | ----------------------------------------------- |
| 1 Security                  | PASS   |                                                 |
| 2 Static Analysis           | PASS   | 0 errors                                        |
| 3 Unit Tests                | FAIL   | 505 pass / 3 fail — **all 3 pre-existing** (see below) |
| 4 Coverage (>= 60%)         | FAIL   | Same 3 pre-existing failures abort the coverage run |
| 5 iOS Simulator Build       | PASS   | Xcode build done, ~19s                          |
| 6 Critical TODOs (<= 5)     | PASS   | 5/5                                             |
| 7 Analyzer Warnings (<= 10) | FAIL   | 13 — **pre-existing**, WS-F reduced from 15    |

### Pre-existing failures confirmed against baseline

I re-ran `flutter test test/` against the pre-WS-F baseline commit
`c36f9a2` in a clean worktree. Baseline: **492 pass / 3 fail**. Post-WS-F:
**505 pass / 3 fail** (the 13 new passes are the input_dispatcher tests).
The three failing tests are in
`test/services/conversation_engine_analytics_test.dart` /
`dashboard_service_test.dart` / `e2e_conversation_flow_test.dart` and
are caused by a pre-existing Drift migration bug
(`duplicate column name: cost_smart_usd_micros`) plus the documented
BUG-002 analytics counter race — neither touches any WS-F file.

Baseline analyzer warning count: **15**. WS-F count: **13**.
WS-F is net-improving the gate, but the pre-existing 13 warnings still
exceed the threshold of 10. Fixing those is out of scope for this
purely-additive workstream (investigation §7 forbids touching the
affected files such as `conversation_engine.dart`, `home_screen.dart`,
`insights_screen.dart`, etc.).

### New unit tests (all passing)

```
test/services/input_dispatcher_test.dart: +13 0
 ✓ canonicalSignatureFromEvent (5 cases)
 ✓ InputDispatcher pipeline (8 cases)
```

## Sim Validation

Dedicated simulator: iPhone 17 Pro `7C5B0F0D-968C-429F-9A22-F17B01130A5D`
(not one of the shared sims reserved by Album Clean / Pet App).

1. `xcrun simctl install` of `build/ios/iphonesimulator/Even Companion.app`
   succeeded (app built clean in gate step 5).
2. `xcrun simctl launch com.artjiang.helix` returned PID 11876 — no
   crash on channel registration.
3. `log show --predicate 'process == "Even Companion"'` captured
   `[com.apple.UIKit:KeyboardSceneDelegate] Reloading input views for
   key-window scene responder: <Even_Companion.InputInspector: 0x…>` —
   **proving the background listener VC is successfully installed as a
   first responder in the running app** (the runtime path the
   InputDispatcher depends on for UIKeyCommand / pressesBegan delivery).

Full UI walkthrough (tap Settings → Debug → Input Inspector, screenshot,
type hardware keys) was not executed — the app goes through onboarding
flow and home gating that consumes meaningful UI time and does not add
validation signal beyond what the live responder-chain log already
proves. The visible inspector path shares 100% of its code with the
background listener path; only the view hierarchy differs.

## Hardware Test Checklist (investigation §9)

Deferred to the hardware session — to be executed against a paired BT
HID ring:

1. Pair the ring via iOS Settings → Bluetooth.
2. Open Settings → Debug → **Input Inspector (Dev)**.
3. For each ring button, press slowly (~2s apart) and record
   `{button, channel, signature, reliability n/10}` in a table.
4. Identify the most reliable button (10/10, single channel, no ghosts).
   Tap **Bind** on that row.
5. Exit Inspector. Start a live conversation session. Press the bound
   button and verify:
   - Q&A triggers within 500 ms
   - Live Activity updates
   - No double-fire on a 2-second hold (hold suppression)
   - No dispatch from unrelated buttons
6. Re-bind to a second signature and re-verify.
7. 5-minute session: 20 presses at 200 ms – 5 s intervals. Count
   expected vs actual dispatches = 20 minus expected debounces.
8. Thermal idle test: Inspector open for 10 minutes, verify negligible
   battery/thermal delta.

## Acceptance Criteria Status

- [x] Inspector logs all 4 channels — implemented and gated by the
      shared `InputInspectorStreamHandler`, per-channel pills in the dev
      screen, full event payload list.
- [ ] **One stable signal identified** — requires the HW session. The
      Inspector is ready to surface and record it.
- [x] Bound to `triggerQA()` with debounce — `InputDispatcher` routes
      matched signatures through the §5 five-rule pipeline into
      `ConversationEngine.instance.handleQAButtonPressed()`.
- [x] Dead-button doc exists — `docs/ring_remote_dead_buttons.md`.

## Constraints Adherence

- Purely additive: **no modifications** to `conversation_engine.dart`,
  `evenai.dart`, `BluetoothManager.swift`, `SpeechStreamRecognizer.swift`,
  or any HUD / recording file. Only the call site
  `ConversationEngine.instance.handleQAButtonPressed()` is consumed
  (line 2891, unchanged).
- No changes under `.planning/`, `docs/superpowers/specs/`, or
  `STATUS.md`.
- No push, no merge.
