# Live Activity Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Question / Pause / Resume buttons to the Helix Live Activity, ensure visibility is gated to active sessions only, and exclude auto-detected question responses (and cost) from the Live Activity surface.

**Architecture:** Three `LiveActivityIntent` types in a Swift file shared between the Runner and widget extension targets. Button taps post Darwin notifications via `CFNotificationCenterGetDarwinNotifyCenter`. AppDelegate observes those notifications and forwards them over the existing `method.bluetooth` MethodChannel as a new outbound `liveActivityButtonPressed` method. Dart side wires events to Spec A's shared `ConversationEngine.handleQAButtonPressed()` entry point and to existing pause/resume actions on `RecordingCoordinator`.

**Tech Stack:** Swift 5+, AppIntents, ActivityKit, Flutter MethodChannel, iOS 26 deployment target

**Depends on:** Spec A for the shared Q&A entry point (`ConversationEngine.handleQAButtonPressed()`) and the `QuestionPriority` enum / `priority` field on `QuestionDetectionResult`.

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `ios/HelixLiveActivity/HelixLiveActivityIntentBridge.swift` | Darwin notification name constants and `post(_:)` helper. Shared between Runner + widget extension targets. |
| `ios/HelixLiveActivity/HelixLiveActivityIntents.swift` | Three `LiveActivityIntent` types: `AskQuestionIntent`, `PauseTranscriptionIntent`, `ResumeTranscriptionIntent`. Shared between Runner + widget extension targets. |
| `test/services/live_activity_service_buttons_test.dart` | Unit tests for Dart button dispatch and auto-detected-question filtering. |

### Modified files

| Path | Change |
|---|---|
| `ios/Runner/AppDelegate.swift` | Register/teardown Darwin observers; add outbound `liveActivityButtonPressed` MethodChannel call; drop `@available(iOS 16.2, *)` gates (iOS 26 floor). |
| `ios/Runner/LiveActivityManager.swift` | Drop `@available(iOS 16.2, *)`; add `status == "paused"` support in `updateActivity`; expose a restart helper for mode change. |
| `ios/Runner/HelixLiveActivityAttributes.swift` | Document `status` values (`listening`, `thinking`, `answered`, `paused`). No schema change. |
| `ios/HelixLiveActivity/HelixLiveActivityLiveActivity.swift` | Add Question / Pause / Resume button row on the Lock Screen layout and in `DynamicIslandExpandedRegion(.bottom)`. Pause and Resume are mutually exclusive based on `context.state.status == "paused"`. No cost field anywhere. |
| `lib/ble_manager.dart` | Add `setLiveActivityCallHandler(void Function(String buttonId))` shim and install a private `_channel.setMethodCallHandler` that dispatches `liveActivityButtonPressed` to the registered handler. |
| `lib/services/live_activity_service.dart` | Install native call handler in `initialize()`; add `_handleNativeCall`; filter `_handleQuestionDetected` / `_handleAnswerUpdated` to skip auto-detected-priority events; send `"paused"` status while paused; restart activity on mode change. |
| `lib/services/conversation_engine.dart` | (Depends on Spec A) expose `handleQAButtonPressed()` entry point if not already present; ensure `QuestionDetectionResult` carries a `priority` (`QuestionPriority.manual` / `QuestionPriority.autoDetected` / `QuestionPriority.factCheck`). |

---

## Phase 1 — Dart-side filter: exclude auto-detected questions from Live Activity content

Resolves the audit leak in §1.4 of the spec. Pure Dart, no native changes. Depends on Spec A having merged the `priority` field on `QuestionDetectionResult`; if Spec A has not merged, introduce a local `askedBy == 'auto'` shim and TODO-link to Spec A.

- [ ] **Task 1.1 — Write failing test for auto-detected filter.** Create `test/services/live_activity_service_buttons_test.dart` using `LiveActivityService.test` factory (pattern: `test/services/live_activity_service_test.dart` if it exists, otherwise model after `test/services/dashboard_service_test.dart`). Test case: feed a `QuestionDetectionResult` with `priority == QuestionPriority.autoDetected` into the injected `questionDetectionStream`; assert that the fake `invokeMethod` receives **zero** `updateLiveActivity` calls after the detection. Second test: manual priority result DOES produce one `updateLiveActivity` call with matching `question` payload.
  - Expected: both tests FAIL (current `_handleQuestionDetected` in `live_activity_service.dart:155-161` has no filter).
  - Run: `flutter test test/services/live_activity_service_buttons_test.dart` — expect 2 failing assertions.

- [ ] **Task 1.2 — Add the filter.** In `lib/services/live_activity_service.dart:155` (`_handleQuestionDetected`), add an early return when `detection.priority == QuestionPriority.autoDetected`. Do the same origin check in `_handleAnswerUpdated` (`live_activity_service.dart:163`): gate on a new `_lastQuestionPriority` field updated only when a non-auto detection arrives, and bail out of `_handleAnswerUpdated` if `_lastQuestionPriority == QuestionPriority.autoDetected` or null-and-never-set.
  - If Spec A has not yet introduced `QuestionPriority`, add the enum in the same file as a temporary local and wire `ConversationEngine` to populate it; leave a TODO comment referencing Spec A.
  - Run: `flutter test test/services/live_activity_service_buttons_test.dart` — expect both tests PASS.

- [ ] **Task 1.3 — Validate.** Run `flutter analyze` (must have 0 errors). Since `live_activity_service.dart` is not on the mandatory full-gate list but `conversation_engine.dart` is (if modified by this task), run `bash scripts/run_gate.sh` when `conversation_engine.dart` was touched; otherwise `flutter analyze && flutter test test/`.

---

## Phase 2 — Darwin notification bridge and three App Intents (no UI wiring yet)

Creates the Swift side infrastructure. Intents will compile and be testable via direct instantiation, but the Live Activity UI is not yet wired.

- [ ] **Task 2.1 — Create `HelixLiveActivityIntentBridge.swift`.** Write `ios/HelixLiveActivity/HelixLiveActivityIntentBridge.swift` with:
  ```swift
  import Foundation

  enum HelixLiveActivityIntentBridge {
      enum Button: String {
          case askQuestion         = "com.helix.liveactivity.askQuestion"
          case pauseTranscription  = "com.helix.liveactivity.pauseTranscription"
          case resumeTranscription = "com.helix.liveactivity.resumeTranscription"
      }

      static func post(_ button: Button) {
          let center = CFNotificationCenterGetDarwinNotifyCenter()
          let name = CFNotificationName(button.rawValue as CFString)
          CFNotificationCenterPostNotification(center, name, nil, nil, true)
      }
  }
  ```
  Add the file to **both** the `Runner` target and the `HelixLiveActivity` widget extension target via the Xcode project's target membership checkboxes (edit `ios/Runner.xcodeproj/project.pbxproj` to add the file reference to both targets' `PBXSourcesBuildPhase`).

- [ ] **Task 2.2 — Create `HelixLiveActivityIntents.swift`.** Write `ios/HelixLiveActivity/HelixLiveActivityIntents.swift` with:
  ```swift
  import AppIntents

  struct AskQuestionIntent: LiveActivityIntent {
      static var title: LocalizedStringResource = "Ask Question"
      init() {}
      func perform() async throws -> some IntentResult {
          HelixLiveActivityIntentBridge.post(.askQuestion)
          return .result()
      }
  }

  struct PauseTranscriptionIntent: LiveActivityIntent {
      static var title: LocalizedStringResource = "Pause"
      init() {}
      func perform() async throws -> some IntentResult {
          HelixLiveActivityIntentBridge.post(.pauseTranscription)
          return .result()
      }
  }

  struct ResumeTranscriptionIntent: LiveActivityIntent {
      static var title: LocalizedStringResource = "Resume"
      init() {}
      func perform() async throws -> some IntentResult {
          HelixLiveActivityIntentBridge.post(.resumeTranscription)
          return .result()
      }
  }
  ```
  No `@available` gating — iOS 26 is the project floor. Add the file to **both** targets (same pbxproj edit approach as Task 2.1).

- [ ] **Task 2.3 — Build validation.** Run `flutter build ios --simulator --no-codesign`. Expected: build succeeds. If Xcode reports "file not found" for either target, re-check target membership in `project.pbxproj`.

---

## Phase 3 — AppDelegate Darwin observer + MethodChannel forwarder

- [ ] **Task 3.1 — Store the MethodChannel as a property.** In `ios/Runner/AppDelegate.swift:10-11`, add `private var bluetoothChannel: FlutterMethodChannel?`. In `didFinishLaunchingWithOptions` where the channel is created (currently line 32), assign `self.bluetoothChannel = channel` right after construction.

- [ ] **Task 3.2 — Register Darwin observers.** After `GeneratedPluginRegistrant.register(with: self)` (line 24), add:
  ```swift
  registerLiveActivityButtonObservers()
  ```
  Define the method on `AppDelegate`:
  ```swift
  private func registerLiveActivityButtonObservers() {
      let center = CFNotificationCenterGetDarwinNotifyCenter()
      let observer = Unmanaged.passUnretained(self).toOpaque()
      let callback: CFNotificationCallback = { _, observer, name, _, _ in
          guard let observer = observer, let name = name else { return }
          let delegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
          let raw = name.rawValue as String
          DispatchQueue.main.async {
              delegate.forwardLiveActivityButton(rawName: raw)
          }
      }
      for button in [
          HelixLiveActivityIntentBridge.Button.askQuestion,
          .pauseTranscription,
          .resumeTranscription,
      ] {
          CFNotificationCenterAddObserver(
              center,
              observer,
              callback,
              button.rawValue as CFString,
              nil,
              .deliverImmediately
          )
      }
  }

  private func forwardLiveActivityButton(rawName: String) {
      guard let button = HelixLiveActivityIntentBridge.Button(rawValue: rawName) else { return }
      let id: String
      switch button {
      case .askQuestion:         id = "askQuestion"
      case .pauseTranscription:  id = "pauseTranscription"
      case .resumeTranscription: id = "resumeTranscription"
      }
      bluetoothChannel?.invokeMethod(
          "liveActivityButtonPressed",
          arguments: ["button": id]
      )
  }
  ```

- [ ] **Task 3.3 — Teardown on terminate.** Override `applicationWillTerminate(_:)` on `AppDelegate` (if not already present) and call `CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), Unmanaged.passUnretained(self).toOpaque())`.

- [ ] **Task 3.4 — Drop `@available(iOS 16.2, *)` gates.** In `ios/Runner/AppDelegate.swift` lines 20-22, 168, 175, 186: remove the `if #available(iOS 16.2, *)` branches since iOS 26 is the floor. In `ios/Runner/LiveActivityManager.swift:6`, remove `@available(iOS 16.2, *)` from the class declaration.

- [ ] **Task 3.5 — Build validation.** Run `flutter build ios --simulator --no-codesign`. Expected: build succeeds with no warnings about Darwin observer bridging.

---

## Phase 4 — Dart-side `liveActivityButtonPressed` handler

- [ ] **Task 4.1 — Add `setLiveActivityCallHandler` shim on `BleManager`.** In `lib/ble_manager.dart`, after the existing `_channel` constant (line 30), add:
  ```dart
  static void Function(String buttonId)? _liveActivityButtonHandler;

  static void setLiveActivityCallHandler(void Function(String buttonId) handler) {
    _liveActivityButtonHandler = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'liveActivityButtonPressed') {
        final args = call.arguments as Map?;
        final id = args?['button'] as String?;
        if (id != null) _liveActivityButtonHandler?.call(id);
      }
      return null;
    });
  }
  ```
  Note: the existing `_channel` is currently used only for outbound calls via `invokeMethod<T>` at line 470; no existing `setMethodCallHandler` to preserve. If one exists by the time this task runs, compose rather than replace.

- [ ] **Task 4.2 — Install handler in `LiveActivityService.initialize()`.** In `lib/services/live_activity_service.dart:92-104`, inside `initialize()` after subscriptions are added, call:
  ```dart
  BleManager.setLiveActivityCallHandler(_handleNativeButton);
  ```
  Add the method:
  ```dart
  void _handleNativeButton(String buttonId) {
    switch (buttonId) {
      case 'askQuestion':
        ConversationEngine.instance.handleQAButtonPressed();
        break;
      case 'pauseTranscription':
        RecordingCoordinator.instance.pause();
        break;
      case 'resumeTranscription':
        RecordingCoordinator.instance.resume();
        break;
    }
  }
  ```
  If `RecordingCoordinator` does not yet expose `pause()` / `resume()` (check `lib/services/recording_coordinator.dart`), add them as a thin wrapper calling `pauseEvenAI` / `resumeEvenAI` on the platform channel and updating `recordingStateStream` accordingly. Touching `recording_coordinator.dart` triggers the full gate per CLAUDE.md.

- [ ] **Task 4.3 — Unit test the dispatch table.** Extend `test/services/live_activity_service_buttons_test.dart`: mock `ConversationEngine.instance.handleQAButtonPressed` and `RecordingCoordinator.instance.pause/resume` via seams (or use the `LiveActivityService.test` factory with injected callbacks — add two optional named parameters `onAskQuestion`, `onPause`, `onResume` to the test factory for this). Feed each of the three button IDs and assert the correct call was made exactly once.

- [ ] **Task 4.4 — Validate.** `flutter analyze` must return 0 errors. `flutter test test/services/live_activity_service_buttons_test.dart` must pass. If `recording_coordinator.dart` was modified, run `bash scripts/run_gate.sh`.

---

## Phase 5 — Wire the three buttons into the Live Activity UI

Adds the buttons on both the Lock Screen layout and the Dynamic Island expanded region. **No cost field** is rendered anywhere. The content area continues to show only Q&A and fact-check results, never auto-detected question text (gated in Dart from Phase 1).

- [ ] **Task 5.1 — Add the Lock Screen button row.** In `ios/HelixLiveActivity/HelixLiveActivityLiveActivity.swift`, modify `lockScreenView(context:)` (lines 62-130). After the answer block (around line 126, before the closing `VStack` at 127), append:
  ```swift
  HStack(spacing: 12) {
      Button(intent: AskQuestionIntent()) {
          Label("Ask", systemImage: "questionmark.circle.fill")
              .labelStyle(.iconOnly)
              .font(.title2)
              .foregroundColor(.cyan)
      }
      .buttonStyle(.plain)

      if context.state.status == "paused" {
          Button(intent: ResumeTranscriptionIntent()) {
              Label("Resume", systemImage: "play.circle.fill")
                  .labelStyle(.iconOnly)
                  .font(.title2)
                  .foregroundColor(.green)
          }
          .buttonStyle(.plain)
      } else {
          Button(intent: PauseTranscriptionIntent()) {
              Label("Pause", systemImage: "pause.circle.fill")
                  .labelStyle(.iconOnly)
                  .font(.title2)
                  .foregroundColor(.yellow)
          }
          .buttonStyle(.plain)
      }
      Spacer()
  }
  .padding(.top, 4)
  ```
  Confirm there is NO reference to any `cost` field in the context state or anywhere in the rendered view.

- [ ] **Task 5.2 — Add the Dynamic Island expanded button row.** In the same file, `DynamicIslandExpandedRegion(.bottom)` currently renders the answer/thinking line (lines 33-48). Wrap the existing content and the new button row in a `VStack`:
  ```swift
  DynamicIslandExpandedRegion(.bottom) {
      VStack(spacing: 6) {
          // existing answer/thinking content unchanged
          if !context.state.answer.isEmpty {
              Text(context.state.answer)
                  .font(.caption2)
                  .foregroundColor(.white.opacity(0.8))
                  .lineLimit(3)
          } else if context.state.status == "thinking" {
              HStack(spacing: 4) {
                  ProgressView().scaleEffect(0.6)
                  Text("Thinking...").font(.caption2).foregroundColor(.secondary)
              }
          }
          HStack(spacing: 16) {
              Button(intent: AskQuestionIntent()) {
                  Image(systemName: "questionmark.circle.fill").foregroundColor(.cyan)
              }.buttonStyle(.plain)
              if context.state.status == "paused" {
                  Button(intent: ResumeTranscriptionIntent()) {
                      Image(systemName: "play.circle.fill").foregroundColor(.green)
                  }.buttonStyle(.plain)
              } else {
                  Button(intent: PauseTranscriptionIntent()) {
                      Image(systemName: "pause.circle.fill").foregroundColor(.yellow)
                  }.buttonStyle(.plain)
              }
          }
      }
  }
  ```
  `compactLeading`, `compactTrailing`, and `minimal` regions are unchanged — they MUST remain free of any cost or auto-detected-question content (today they only show mode icon / status emoji / brain icon, which is correct).

- [ ] **Task 5.3 — Propagate `"paused"` status from Dart.** In `lib/services/live_activity_service.dart`, when `RecordingCoordinator` reports a paused-but-recording state (or whenever Phase 4's `pauseTranscription` handler has just run), set `_currentStatus` to a sentinel that serializes to `"paused"` in the payload. Simplest form: add a `bool _isPaused` field on `LiveActivityService`, flip it in `_handleNativeButton` for pause/resume, and in `_updateActivity()` override the `status` payload value with `'paused'` when `_isPaused` is true, before reading `_currentStatus.name`.

- [ ] **Task 5.4 — Build validation.** Run `flutter build ios --simulator --no-codesign`. Expected: build succeeds. Manually inspect `HelixLiveActivityLiveActivity.swift` diff for any stray `cost` reference: `grep -n cost ios/HelixLiveActivity/HelixLiveActivityLiveActivity.swift` must return zero lines.

- [ ] **Task 5.5 — Manual smoke test on simulator.** Boot a dedicated Helix simulator per CLAUDE.md. Start a conversation. Lock the simulator. Verify: Lock Screen Live Activity shows the three-button row, the Dynamic Island expanded layout shows the buttons, and neither surface shows any cost or dollar figure. Tap Pause; verify the button swaps to Resume.

---

## Phase 6 — Visibility regression test + mode-change investigation

- [ ] **Task 6.1 — Regression test for recording-gated visibility.** In `test/services/live_activity_service_buttons_test.dart`, add a test: drive `recordingStateStream` through `false → true → false` and assert `invokeMethod` received exactly one `startLiveActivity` and one `stopLiveActivity`. Add a negative test: emit `modeStream`, `statusStream`, `questionDetectionStream`, and `aiResponseStream` events while `recordingStateStream` has never emitted `true` — assert zero Live Activity calls of any kind were made. This locks in the audit finding from spec §1.3.

- [ ] **Task 6.2 — Investigate mode-change restart (Open Question #5).** `ActivityAttributes.mode` is immutable after activity start. Today `_handleModeChanged` calls `_updateActivity()` which writes only `ContentState` — the `mode` displayed on the Lock Screen banner and Dynamic Island icon is stuck at whatever value was set when the activity was first started. Decision: on mode change while `_isActivityStarted == true`, end and restart the activity so the new `attributes.mode` takes effect. Implementation:
  ```dart
  void _handleModeChanged(ConversationMode mode) async {
    final previous = _currentMode;
    _currentMode = mode;
    if (_isActivityStarted && previous != mode) {
      await _stopActivity();
      await _startActivity();
      return;
    }
    if (_isActivityStarted) {
      unawaited(_updateActivity());
    }
  }
  ```
  Add a test: drive `modeStream` to emit `general → interview` while recording is true; assert one `stopLiveActivity` followed by one `startLiveActivity` with the new mode in args.

- [ ] **Task 6.3 — Run full validation gate.** Because this phase modifies `live_activity_service.dart` (and may have touched `recording_coordinator.dart` in Phase 4), run `bash scripts/run_gate.sh`. Must complete with all gates green.

---

## Channel & Naming Consistency Check

| Name | Where it appears | Value |
|---|---|---|
| Darwin name (Ask) | `HelixLiveActivityIntentBridge.Button.askQuestion` | `com.helix.liveactivity.askQuestion` |
| Darwin name (Pause) | `HelixLiveActivityIntentBridge.Button.pauseTranscription` | `com.helix.liveactivity.pauseTranscription` |
| Darwin name (Resume) | `HelixLiveActivityIntentBridge.Button.resumeTranscription` | `com.helix.liveactivity.resumeTranscription` |
| MethodChannel | `AppDelegate.bluetoothChannel` + `BleManager._channel` | `method.bluetooth` |
| Outbound method | `AppDelegate.forwardLiveActivityButton` + `BleManager.setLiveActivityCallHandler` | `liveActivityButtonPressed` |
| Button IDs in payload | Swift forwarder + Dart `_handleNativeButton` switch | `askQuestion` / `pauseTranscription` / `resumeTranscription` |
| Intent type names | `HelixLiveActivityIntents.swift` + widget UI `Button(intent:)` | `AskQuestionIntent`, `PauseTranscriptionIntent`, `ResumeTranscriptionIntent` |
| `status` enum string for pause | `LiveActivityService._updateActivity` + widget `context.state.status` comparison | `"paused"` |

---

## Validation Gate Summary

| After phase | Minimum validation |
|---|---|
| Phase 1 | `flutter analyze` + targeted test file. Full gate if `conversation_engine.dart` modified. |
| Phase 2 | `flutter build ios --simulator --no-codesign`. |
| Phase 3 | `flutter build ios --simulator --no-codesign`. |
| Phase 4 | `flutter analyze` + targeted test. Full gate if `recording_coordinator.dart` modified. |
| Phase 5 | `flutter build ios --simulator --no-codesign` + manual simulator smoke test. |
| Phase 6 | `bash scripts/run_gate.sh` (mandatory — touches `live_activity_service.dart` and likely `recording_coordinator.dart`). |

---

## Non-Goals / Constraints

- **No cost field** on any Live Activity surface (Lock Screen, compact, minimal, expanded). This plan adds zero references to cost anywhere in ActivityKit state or widget views.
- **No auto-detected question content** on any Live Activity surface. The Dart gate in Phase 1 is the single source of truth.
- **No `@available` gating.** iOS 26 is the deployment floor — all new Swift code is unconditional.
- **No force-quit relaunch workaround.** If the user force-quits Helix, buttons are inert; documented as expected behavior.
- **No push updates.** The activity is local-only (`pushType: nil`), unchanged.
