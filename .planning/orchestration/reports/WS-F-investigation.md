# WS-F Investigation: Bluetooth HID Ring Remote → triggerQA

## 1. triggerQA Entry Point

- `lib/services/conversation_engine.dart:2877` — `forceQuestionAnalysis()`, called by `EvenAI._triggerManualQuestionDetection()` (right-touch handler) at `lib/services/evenai.dart:280`. Branches on `SettingsManager.instance.answerAll`.
- `lib/services/conversation_engine.dart:2891` — `handleQAButtonPressed()`. Always calls `_runManualContextualQa()`. Documented as "Entry point for the QA button (Live Activity, BLE touchpad, etc)."

**Bind target: `ConversationEngine.instance.handleQAButtonPressed()`** — same sink as Live Activity `askQuestion` (`AppDelegate.forwardLiveActivityButton` at `ios/Runner/AppDelegate.swift:388`). Ring becomes a third peer alongside touchpad and Live Activity.

## 2. Inspector Screen Design

### Native: `ios/Runner/InputInspector.swift` (NEW)

A `UIViewController` subclass installed as a child of `FlutterViewController` while the inspector is visible. Required because the responder chain must include a first-responder VC override to see `UIKeyCommand` and `pressesBegan`.

Channels instrumented:

1. **UIKeyCommand** — override `keyCommands` returning broad set (a-z, 0-9, arrows, return, space, escape, tab) with modifier-flag wildcards. `canBecomeFirstResponder → true`, call `becomeFirstResponder()` on `viewDidAppear`. Emit `{channel: "keyCommand", input, modifierFlags, timestamp}`.
2. **UIPress / pressesBegan/Ended** — override `pressesBegan(_:with:)` and `pressesEnded`. For each `press.key` emit `{channel: "pressEvent", phase, keyCode, characters, charactersIgnoringModifiers, modifierFlags, timestamp}`. Captures keys `UIKeyCommand` filters out — most likely surface for the ring.
3. **MPRemoteCommandCenter** — `viewDidAppear`: `beginReceivingRemoteControlEvents()`, set `nowPlayingInfo = [MPMediaItemPropertyTitle: "Helix Inspector"]` (iOS requires "now playing" state to deliver remote events), register `playCommand`, `pauseCommand`, `togglePlayPauseCommand`, `nextTrackCommand`, `previousTrackCommand`, `seekForwardCommand`, `seekBackwardCommand`. Each handler emits `{channel: "mediaCommand", command, timestamp}` and returns `.commandFailed`. Tear down on `viewDidDisappear`.
4. **Volume notifications** — subscribe to `Notification.Name("AVSystemController_SystemVolumeDidChangeNotification")`. Emit `{channel: "volumeChange", newVolume, reason, timestamp}`. Private-API name; observation only, dev tool only — document in file header.

### Flutter: `lib/screens/dev/input_inspector_screen.dart` (NEW)

- Header: "Input Inspector — pair the ring, then press each button"
- Four color-coded pills with live channel counts
- Scrolling list (newest top), last 200 events: `timestamp [channel] payload`
- Clear button
- "Bind this signal" per row → confirm dialog → write to SettingsManager → pop
- "Current binding" footer with Unbind action

Entry: Settings → Dev tools → Input Inspector (debug visible, release behind long-press easter egg).

## 3. Platform Channel Contract

**Method channel** `method.input_inspector`:
- `startInspector()` → install VC as first responder, begin remote events
- `stopInspector()` → tear down, resign first responder, end remote events, clear now-playing
- `getCapabilities()` → `{hasHardwareKeyboard, remoteControlEnabled}`

**Event channel** `event.input_inspector`:
- `keyCommand`: `{channel, input, modifierFlags, timestamp}`
- `pressEvent`: `{channel, phase, keyCode, characters, charactersIgnoringModifiers, modifierFlags, timestamp}`
- `mediaCommand`: `{channel, command, timestamp}`
- `volumeChange`: `{channel, newVolume, reason, timestamp}`

All events share `channel` discriminator.

**Canonical signature strings:**
- `keyCommand:<input>:<modifierFlags>`
- `pressEvent:<keyCode>` (phase always `began`)
- `mediaCommand:<command>` e.g. `mediaCommand:togglePlayPause`
- `volumeChange:up` or `volumeChange:down` (derived from prev volume)

## 4. Binding Flow

1. User opens inspector, presses ring button
2. Event arrives, user taps "Bind this signal"
3. Dart serialises canonical signature, writes `SettingsManager.instance.setRingBindingSignature(...)`
4. New SettingsManager fields: `String? ringBindingSignature` (SharedPreferences `ring_binding_signature`), `bool ringBindingEnabled` (`ring_binding_enabled`, default true when signature set)
5. New singleton `InputDispatcher` (`lib/services/input_dispatcher.dart`) started from `main.dart` after `ConversationEngine.instance` init
   - `start()` calls native `startBackgroundListening` — same plumbing minus visible UI; invisible VC as first responder while foregrounded
   - Media-command handlers registered with NowPlayingInfo stub only during active listening (avoid ghost player)
   - Subscribes to event stream, canonicalises, compares to stored signature
   - On match + debounce passed → `ConversationEngine.instance.handleQAButtonPressed()`
6. Observe `SettingsManager.onSettingsChanged` so rebinding takes effect without restart

## 5. Debounce Strategy

Constants at top of `input_dispatcher.dart`:

1. **Primary debounce**: 500ms from last successful dispatch. Drops counted in `ringDebouncedCount`
2. **Phase filter**: only `pressEvent` `phase == "began"` participates
3. **Volume coalescing**: `volumeChange` within 50ms of `mediaCommand`/`keyCommand` → suppress as duplicate
4. **Hold suppression**: same signature 3+ times within 150ms → keep first edge only
5. **Session guard**: dispatch even if `isActive == false` (engine handles inactive case), tagged for tests

## 6. Dead-Button Documentation

`docs/ring_remote_dead_buttons.md` (also in-app under Inspector → "Why isn't my button showing up?"):

- **Always consumed by iOS**: Home, Power, Ringer switch, Screenshot combo, Siri long-press, accessibility triple-click
- **Sometimes consumed**: Volume Up/Down (only with audio focus), Play/Pause/Next/Prev (only with `nowPlayingInfo` set)
- **Delivered to `pressesBegan` but NOT `UIKeyCommand`**: modifier-only presses (Shift alone), some Fn keys
- **Workaround**: remap in ring's companion app to a generic key (`a`) or play/pause

## 7. File Allowlist

**New files:**
- `ios/Runner/InputInspector.swift`
- `lib/services/input_dispatcher.dart`
- `lib/screens/dev/input_inspector_screen.dart`
- `test/services/input_dispatcher_test.dart`
- `docs/ring_remote_dead_buttons.md`

**Modified:**
- `ios/Runner/AppDelegate.swift` — register two new channels
- `ios/Runner.xcodeproj/project.pbxproj` — add InputInspector.swift to target
- `lib/services/settings_manager.dart` — `ringBindingSignature`, `ringBindingEnabled`
- `lib/screens/settings/settings_screen.dart` (verify path in fix phase) — Dev tools tile
- `lib/main.dart` — `InputDispatcher.instance.start()` after `ConversationEngine`
- `pubspec.yaml` — only if new dep needed (none expected)

**Forbidden:** `conversation_engine.dart`, `evenai.dart`, `bluetooth_manager.swift`, `speech_stream_recognizer.swift`, any HUD/recording files. Purely additive.

## 8. Sim Test Plan

**Sim CAN validate:**
1. Inspector renders, four pills visible (`mcp__ios-simulator__ui_view`)
2. Mock event injection via `--dart-define=INPUT_INSPECTOR_MOCK=true` flag — synthetic events on a timer
3. Bind flow: tap row → confirm → SettingsManager state set (unit test)
4. Dispatcher unit tests:
   - Signature canonicalisation reference strings
   - Debounce: 100ms apart → 1 dispatch; 600ms apart → 2 dispatches
   - Volume coalescing: `mediaCommand:play` + `volumeChange:up` within 50ms → 1 dispatch
   - Mocked `ConversationEngine.handleQAButtonPressed` called
5. Hardware keyboard smoke: enable in sim, press `a` while inspector open → row appears, bind to `keyCommand:a:0`, press `a` from home → assert dispatch within 500ms via log

**Sim CANNOT validate (HW required):**
1. Actual ring BT HID pairing
2. Which channel each ring button uses
3. `MPRemoteCommandCenter` from BT HID (sim only delivers from host media keys)
4. `AVSystemController` volume from ring rocker
5. Thermal/battery impact of persistent invisible first-responder VC

## 9. Hardware Test Plan

1. Pair ring via iOS Settings → Bluetooth
2. Settings → Dev tools → Input Inspector
3. Press each button slowly, 2s apart. Record `{button, channel, signature, reliability n/10}` table
4. Identify most reliable button (10/10, single channel, no ghost events). Bind it
5. Exit Inspector. Start live session. Press bound button. Assert:
   - Q&A triggers within 500ms
   - Live Activity updates
   - No double-fire on 2s hold
   - No fire from unrelated buttons
6. Rebind test with second signature
7. 5-min session, 20 presses at 200ms–5s intervals: count expected vs actual = 20 minus expected debounces
8. Thermal: 10-min Inspector idle, expect negligible delta

## 10. Implementation Steps

1. Create `InputInspector.swift` with VC + `FlutterStreamHandler` + 4 capture paths. Add to Xcode target.
2. Register channels in `AppDelegate.swift` next to existing `nlChannel`/`eventKitChannel` block.
3. Extend `SettingsManager` with binding fields + persistence + change notification.
4. Create `input_dispatcher.dart` singleton with start/stop/dispose, debounce state, mockable engine hook.
5. Wire `InputDispatcher.instance.start()` in `main.dart` after `ConversationEngine` init.
6. Create `input_inspector_screen.dart` — subscribe directly to event channel (not dispatcher) for raw firehose.
7. Add Dev tools tile in settings (debug-visible).
8. Write `input_dispatcher_test.dart` covering canonicalisation/debounce/coalescing/hold.
9. Write `docs/ring_remote_dead_buttons.md`.
10. Run `bash scripts/run_gate.sh` in `helix-group-delta`. Fix until green.
11. Sim validation: scripted `mcp__ios-simulator` flow from Section 8.
12. HW test: fill button-to-signature table, append to fix report.
13. If a default signature is reliable across devices, ship as default; else leave null and require one inspector visit.

## Key References

- `lib/services/conversation_engine.dart:2877, 2891`
- `lib/services/evenai.dart:224-281`
- `ios/Runner/AppDelegate.swift:14-194, 361-400`
- `lib/services/settings_manager.dart:14-27`
