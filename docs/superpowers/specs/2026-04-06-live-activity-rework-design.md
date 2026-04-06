# Live Activity Rework — Design Spec

**Date:** 2026-04-06
**Status:** Draft
**Depends on:** Spec A (Priority Q&A Pipeline) — for the shared Q&A entry point that the Live Activity Question button must invoke.

---

## Open Questions

1. **Darwin notification flavor** — `CFNotificationCenterGetDarwinNotifyCenter` vs. `DistributedNotificationCenter`. Recommendation below is Darwin (CFNotificationCenter) since `DistributedNotificationCenter` is macOS-only on iOS App Intents won't reach it. Confirm during implementation.
2. **App-suspended wake behavior** — App Intents marked `LiveActivityIntent` are documented to run in the app's process. We assume iOS will wake the suspended host app to execute the intent, then the Darwin notification reaches an in-process observer. Needs simulator confirmation; if false, the intent itself must call into a shared framework target rather than relying on a notification round-trip.
3. **Force-quit behavior** — if the user force-quits Helix, can the Live Activity buttons still relaunch the app? (Likely no — system policy.) Document expectation; do not try to work around.
4. **"Session active" definition** — `RecordingCoordinator.isRecording` vs. `ConversationEngine.status != idle`. Recommendation: gate on `RecordingCoordinator.recordingStateStream` (current behavior), since Live Activity should follow the mic, not the engine substate.
5. **Mode change mid-session** — current code re-issues `update`. Should a mode change tear down and restart the activity (so `attributes.mode` updates)? `ActivityAttributes` are immutable after start, so today's mode-change handling is silently broken for the mode label. Decide whether to restart on mode change.

---

## 1. Current State Audit

### 1.1 Files

| File | Role |
|---|---|
| `ios/Runner/LiveActivityManager.swift` | Singleton that wraps `Activity<HelixLiveActivityAttributes>` request/update/end. |
| `ios/Runner/HelixLiveActivityAttributes.swift` | `ActivityAttributes` schema: static `mode`, dynamic `ContentState { question, answer, status, duration }`. |
| `ios/HelixLiveActivity/HelixLiveActivityBundle.swift` | Widget extension entry point. |
| `ios/HelixLiveActivity/HelixLiveActivityLiveActivity.swift` | `HelixLiveActivityWidget` — Lock Screen + Dynamic Island layouts. No buttons today. |
| `ios/Runner/AppDelegate.swift` (lines 19–22, 167–189) | Cleans up stale activities at launch; handles `startLiveActivity` / `updateLiveActivity` / `stopLiveActivity` over the `method.bluetooth` MethodChannel. |
| `lib/services/live_activity_service.dart` | Dart orchestrator; subscribes to `RecordingCoordinator`, `ConversationEngine` streams; calls `startLiveActivity` / `updateLiveActivity` / `stopLiveActivity`. |
| `lib/main.dart` (line 51) | `LiveActivityService.instance().initialize()` at app start. |

### 1.2 Lifecycle today

- **Start**: `LiveActivityService._handleRecordingStateChanged(true)` fires when `RecordingCoordinator.recordingStateStream` flips to `true`. It calls `startLiveActivity` then immediately `updateLiveActivity`.
- **Update**: triggered by mode, duration, status, question detection, or AI response stream events.
- **Stop**: when `recordingStateStream` flips to `false`, `_stopActivity()` calls `stopLiveActivity` → `LiveActivityManager.endActivity()` with `dismissalPolicy: .immediate`.
- **Stale cleanup**: `AppDelegate.didFinishLaunchingWithOptions` calls `LiveActivityManager.shared.cleanupStaleActivities()` to dismiss any activities surviving a crash/force-kill.

### 1.3 Visibility — current behavior

The activity is **already gated on `RecordingCoordinator.isRecording`** and is *not* shown when there is no active session. **Locked decision #1 is largely satisfied today** for the start/end edges. The audit work is to:

- Verify there is no other code path that calls `startLiveActivity` outside `_handleRecordingStateChanged`. (Confirmed by Grep — only the service starts it.)
- Verify "session ended" coverage on app crash (handled by `cleanupStaleActivities` at next launch — there is a window where a stale activity is visible until launch).
- Verify the Live Activity tracks `RecordingCoordinator` rather than `ConversationEngine.isActive`. It does. Decision: keep this binding; document it.

### 1.4 Auto-detected question content leak

`_handleQuestionDetected` and `_handleAnswerUpdated` write *every* question/answer event (including auto-detected priority-3 questions per Spec A) into the Live Activity content state. **This violates locked decision #4.** Fix is in §6.

### 1.5 No buttons today

`HelixLiveActivityLiveActivity.swift` has no `Button(intent:)` controls in either Lock Screen or Dynamic Island regions. All three buttons (Question / Pause / Resume) must be added.

### 1.6 Deployment target

`IPHONEOS_DEPLOYMENT_TARGET = 16.2` across all targets. **Interactive Live Activity buttons require iOS 17.0+** (`Button(intent:)` and `LiveActivityIntent`). Decision: bump the **widget extension target only** to iOS 17.0; keep the Runner app at 16.2 so non-interactive activities still work on iOS 16.2–16.7. The widget bundle's `availability` will gate buttons via `if #available(iOS 17, *)`.

---

## 2. App Intents

Three intents live in a new file, **`ios/HelixLiveActivity/HelixLiveActivityIntents.swift`**, included in **both** the widget extension target and the Runner app target (so the Runner can decode them when iOS wakes the app).

```swift
import AppIntents

@available(iOS 17.0, *)
struct AskQuestionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Ask Question"
    func perform() async throws -> some IntentResult {
        HelixLiveActivityIntentBridge.post(.askQuestion)
        return .result()
    }
}

@available(iOS 17.0, *)
struct PauseTranscriptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Pause"
    func perform() async throws -> some IntentResult {
        HelixLiveActivityIntentBridge.post(.pauseTranscription)
        return .result()
    }
}

@available(iOS 17.0, *)
struct ResumeTranscriptionIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Resume"
    func perform() async throws -> some IntentResult {
        HelixLiveActivityIntentBridge.post(.resumeTranscription)
        return .result()
    }
}
```

**Why `LiveActivityIntent`** (not plain `AppIntent`): `LiveActivityIntent` is documented to run **in the host app's process**, which is what we need so the Darwin notification observer registered in `AppDelegate` actually receives the post. Plain `AppIntent` from a widget runs in the widget extension process.

---

## 3. Darwin Notification Names

Stable string identifiers, defined once in `HelixLiveActivityIntentBridge.swift`:

| Name | Trigger |
|---|---|
| `com.helix.liveactivity.askQuestion` | AskQuestionIntent |
| `com.helix.liveactivity.pauseTranscription` | PauseTranscriptionIntent |
| `com.helix.liveactivity.resumeTranscription` | ResumeTranscriptionIntent |

`HelixLiveActivityIntentBridge.post(_:)` wraps `CFNotificationCenterPostNotification` on `CFNotificationCenterGetDarwinNotifyCenter()` with the matching CFString. Names are constants on the bridge enum so the intent and the observer cannot drift.

---

## 4. AppDelegate Observer

### 4.1 Registration

In `AppDelegate.application(_:didFinishLaunchingWithOptions:)`, after `GeneratedPluginRegistrant.register`, register three Darwin observers via `CFNotificationCenterAddObserver` on `CFNotificationCenterGetDarwinNotifyCenter()`. Each observer's callback dispatches to `DispatchQueue.main` and calls a single forwarding method on `AppDelegate`.

The C-style callback cannot capture `self`, so the observer is registered with `Unmanaged.passUnretained(self).toOpaque()` as `observer`, and the callback bridges back via `Unmanaged.fromOpaque`.

### 4.2 Teardown

`applicationWillTerminate` removes all observers via `CFNotificationCenterRemoveEveryObserver`. (App suspension does not require removal.)

### 4.3 Forwarding to Dart

Reuse the **existing `method.bluetooth` MethodChannel** that already carries the Live Activity start/stop calls. Add a new outbound (Swift→Dart) method via `channel.invokeMethod`:

| Outbound method | Argument | Triggered by |
|---|---|---|
| `liveActivityButtonPressed` | `{"button": "askQuestion"}` | askQuestion Darwin notification |
| `liveActivityButtonPressed` | `{"button": "pauseTranscription"}` | pause Darwin notification |
| `liveActivityButtonPressed` | `{"button": "resumeTranscription"}` | resume Darwin notification |

Single method name with a discriminator avoids three new method registrations on the Dart side. The channel reference is captured during AppDelegate setup and stored as a property so the observer callback can use it.

If the observer fires while the channel is not yet ready (extremely early launch), the call is dropped — acceptable because the Live Activity cannot exist before recording started, which cannot happen before the channel is wired.

---

## 5. Dart-Side Handler

### 5.1 Listener location

`LiveActivityService` (`lib/services/live_activity_service.dart`) gains a `MethodChannel` handler. It already has access to `BleManager.invokeMethod` for outbound calls; we add an inbound listener installed during `initialize()`:

```dart
BleManager.setLiveActivityCallHandler(_handleNativeCall);
```

`BleManager` exposes a small registration shim because the underlying `MethodChannel` is owned there. The shim filters for `liveActivityButtonPressed` and forwards to the registered callback.

### 5.2 Action mapping

```
askQuestion         -> ConversationEngine.instance.handleQAButtonPressed()  // Spec A entry point
pauseTranscription  -> RecordingCoordinator.instance.pause()
resumeTranscription -> RecordingCoordinator.instance.resume()
```

### 5.3 Shared Q&A entry point

Spec A defines `ConversationEngine.handleQAButtonPressed()` as the **single shared entry point** for hardware Q&A button presses. The Live Activity Question button MUST call this exact method — not a parallel code path. This guarantees:

- Same priority-pipeline behavior (priority 1 manual Q&A).
- Same debouncing and active-session checks.
- Same telemetry.

If the button is pressed when no session is active, the entry point is a no-op (the Live Activity should not be visible in that state anyway, per §6).

---

## 6. Visibility Lifecycle (locked decision #1 + #4)

### 6.1 Where activities are started/ended

No changes to the trigger source: `LiveActivityService._handleRecordingStateChanged` remains the only caller of `_startActivity` / `_stopActivity`. "Session active" is defined as `RecordingCoordinator.recordingStateStream == true`.

### 6.2 Auto-response exclusion

Add a discriminator to `QuestionDetectionResult` (or read an existing field — Spec A introduces `priority`). In `_handleQuestionDetected`:

```
if (detection.priority == QuestionPriority.autoDetected) return;  // do not surface in Live Activity
```

Same gate on `_handleAnswerUpdated`: only stream answers tied to Q&A button presses or fact-check corrections. The engine must tag each `aiResponseStream` event with its origin so the Live Activity service can filter. Alternative if tagging the stream is invasive: expose two streams, `qaResponseStream` and `factCheckResponseStream`, and have the Live Activity subscribe to those instead of the generic `aiResponseStream`.

This matches the existing glasses HUD rule (auto-responses bypass the HUD).

### 6.3 Force-kill safety net

`cleanupStaleActivities` already runs at next launch. No change.

---

## 7. Live Activity UI

### 7.1 Lock Screen

Existing layout (header + Q + A blocks) gains a **bottom button row** with three buttons:

| Button | Icon | Intent |
|---|---|---|
| Question | `questionmark.circle.fill` | `AskQuestionIntent` |
| Pause | `pause.circle.fill` | `PauseTranscriptionIntent` (hidden when paused) |
| Resume | `play.circle.fill` | `ResumeTranscriptionIntent` (hidden when running) |

Pause/Resume mutual exclusivity is driven by `context.state.status` — extend the status enum with `"paused"` so the widget can pick the correct button. (Today the status is a free-form string; keep that, but add the `"paused"` value.)

### 7.2 Dynamic Island

- **Compact**: unchanged (mode icon + status emoji).
- **Minimal**: unchanged.
- **Expanded**: add a `DynamicIslandExpandedRegion(.bottom)` button row identical to the Lock Screen row. The existing bottom region (answer/thinking) moves into the `.center` region or stacks above the buttons.

### 7.3 Content area

Question and answer fields remain. Per §6.2, only Q&A and fact-check corrections populate them. If the session is active but nothing has been asked, the content area shows "Listening..." (existing behavior).

---

## 8. Reliability

### 8.1 App suspended

`LiveActivityIntent.perform()` runs in the host app's process. iOS launches/wakes the app (background) to execute the intent. The Darwin notification is posted in-process and the observer fires immediately. The forwarded MethodChannel call reaches Dart while the app is in the background.

`RecordingCoordinator.pause()` / `resume()` and `ConversationEngine.handleQAButtonPressed()` must be safe to call from a background-launched state. They already are (the engine is a singleton initialized eagerly in `main.dart`). Verify in §10.

### 8.2 App force-quit

iOS will not relaunch a force-quit app from a `LiveActivityIntent`. The buttons will appear to do nothing. Acceptable; document in user-facing help. The Live Activity itself remains visible until the user dismisses it or the system reaps it after ~8h.

### 8.3 Stale Live Activity after crash

Handled by `cleanupStaleActivities` at next launch (§1.2).

### 8.4 Mode change mid-session

`ActivityAttributes` are immutable. Decision (open question #5): on mode change, end and restart the activity so `attributes.mode` reflects the new mode. Add an `_handleModeChanged` branch that, while `_isActivityStarted`, calls `_stopActivity()` then `_startActivity()`.

---

## 9. Channel & Naming Summary

| Channel/method | Direction | Purpose |
|---|---|---|
| `method.bluetooth` `startLiveActivity` | Dart → Swift | (existing) start activity with mode |
| `method.bluetooth` `updateLiveActivity` | Dart → Swift | (existing) update content state |
| `method.bluetooth` `stopLiveActivity` | Dart → Swift | (existing) end activity |
| `method.bluetooth` `liveActivityButtonPressed` | Swift → Dart | **NEW** Forward Darwin notification to Dart with `{"button": ...}` |
| Darwin: `com.helix.liveactivity.askQuestion` | Intent → AppDelegate | New |
| Darwin: `com.helix.liveactivity.pauseTranscription` | Intent → AppDelegate | New |
| Darwin: `com.helix.liveactivity.resumeTranscription` | Intent → AppDelegate | New |

---

## 10. Testing Strategy

iOS Simulator supports Live Activities since iOS 16.2 (tap the Lock Screen with the activity visible). Interactive buttons need iOS 17+ simulator runtime.

### 10.1 Manual

1. Boot a dedicated Helix simulator (per CLAUDE.md).
2. Start a conversation session — confirm Live Activity appears on Lock Screen and Dynamic Island.
3. Lock the device. Tap each of the three buttons; verify:
   - **Question**: same telemetry/state as a hardware Q&A press.
   - **Pause**: `RecordingCoordinator.isRecording == true` but transcription is paused (audio session frozen).
   - **Resume**: button toggles back, transcription resumes.
4. End the session — confirm activity disappears immediately.
5. Trigger an auto-detected question — confirm the Live Activity content area is **not** updated, while glasses HUD also stays clear (parity check).
6. Force-kill the app mid-session, relaunch — confirm `cleanupStaleActivities` removes the orphan.
7. Background the app, fire a button — confirm the Dart handler runs (visible via log).

### 10.2 Automated

- Unit-test `LiveActivityService` filtering of auto-detected events using the existing `LiveActivityService.test` factory. Add cases:
  - auto-detected `QuestionDetectionResult` → no `updateLiveActivity` invocation.
  - manual `QuestionDetectionResult` → `updateLiveActivity` invoked with question text.
- Unit-test the `liveActivityButtonPressed` Dart handler dispatch table with a fake `ConversationEngine` and `RecordingCoordinator`.

### 10.3 Validation gate

Per CLAUDE.md, run `bash scripts/run_gate.sh` after touching `live_activity_service.dart`, `recording_coordinator.dart`, or `conversation_engine.dart`.

---

## 11. Implementation Order (non-binding)

1. Add `HelixLiveActivityIntentBridge.swift` (Darwin name constants + post helper). Include in both targets.
2. Add the three `LiveActivityIntent` types.
3. Wire the widget UI buttons (gated `if #available(iOS 17, *)`).
4. Bump widget extension deployment target to iOS 17.
5. Register/teardown Darwin observers in `AppDelegate`; add the `liveActivityButtonPressed` outbound call.
6. Add `BleManager.setLiveActivityCallHandler` shim.
7. Wire `LiveActivityService._handleNativeCall` → engine/coordinator actions.
8. Add `priority` filter in `_handleQuestionDetected` / `_handleAnswerUpdated` (depends on Spec A landing).
9. Add status `"paused"` plumbing.
10. Add mode-change restart.
11. Tests + run full gate.
