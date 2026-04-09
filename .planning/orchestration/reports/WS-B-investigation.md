# WS-B Investigation — Live Page Goes Blank Mid-Session

**Tier-1 Bug #2.** Read-only RCA. No code changes performed.

**Acceptance for fix agent:** "Bug repro recorded, RCA documented, fix verified by 5-min continuous session w/o blank state."

---

## TL;DR

The "Live page" is the home tab's CONVERSATION HUB card in `lib/screens/home_screen.dart`. Its visibility and content are driven entirely by a small set of `setState`-tracked fields fed by streams from `ConversationEngine` and `RecordingCoordinator`. The card collapses to a non-live placeholder (`_buildLoadoutCard()` + suggestion chips) the instant `hasLiveConversation` evaluates to false:

```dart
// home_screen.dart:1985
final hasLiveConversation =
    _isRecording ||
    _transcription.isNotEmpty ||
    _aiResponse.isNotEmpty ||
    _latestQuestionDetection != null ||
    (_listeningError?.isNotEmpty ?? false) ||
    _showDetailLink;
```

Several mid-session code paths can drive **all six** of those flags to falsy values within the same frame, producing the visually-blank state the user is reporting. The single highest-confidence offender is `ConversationEngine.start()` getting re-entered while a session is already active — it unconditionally calls `_resetLiveSessionState(clearConversationHistory: true)` which `_finalizedSegments.clear()`s, blanks `_aiResponse`, blanks `_followUpChips`, and re-emits an empty `TranscriptSnapshot`. Combined with a transient `_isRecording=false` from the recording-state stream, the predicate flips and the page renders `_buildLoadoutCard()` until new audio arrives.

There are at least three independent ways `start()` can be re-entered or the predicate can flip mid-session. They are listed in confidence order below.

## Reproduction

**Sim repro: not attempted in this investigation pass.** The investigation budget was spent on static analysis because the symptoms are reproducible deterministically from the code paths below; the fix agent should record a repro on sim *while validating* (acceptance criterion: "5-min continuous session w/o blank state"), not before.

**Suggested deterministic repro** (for the fix agent to record before patching):
1. Boot dedicated Helix sim; `flutter run -d <sim>` debug build.
2. Tap record on Home; let transcription start (Apple Cloud backend).
3. With the session still active, trigger any one of:
   - **(A)** Tap a Quick-Ask preset chip on Home (`home_screen.dart:3387` calls `_engine.askQuestion`) — the bug is **not** in askQuestion itself, but in the suggestion-chip variants that internally short-circuit through `_runResponseToolPrompt` when `previewText` is set; observe whether `_transcription` overwrite races with the next snapshot emit.
   - **(B)** Force a `recordingStateStream` glitch: pause then resume from the Live Activity (`coordinator.pauseTranscription()` / `resumeTranscription()`), or rotate background→foreground rapidly. Watch for any transient `recording=false` event.
   - **(C)** Trigger native restart of speech recognition (e.g. mic interrupted by another audio source / phone call / Siri). Native side will re-call `startEvenAI` -> `_engine.start(source:)` (`conversation_listening_session.dart:97`) which **clears `_finalizedSegments` mid-session**.
4. Observe: CONVERSATION HUB card collapses to LOADOUT placeholder for the duration of the gap.

## Root Cause Hypotheses (ranked)

### H1 — Mid-session `_engine.start()` re-entry wipes `_finalizedSegments` (HIGH confidence)

`ConversationListeningSession.startSession` always invokes `_engine.start(source: source)` (`lib/services/conversation_listening_session.dart:97`). `start()` then calls `_resetLiveSessionState(clearConversationHistory: true)` (`lib/services/conversation_engine.dart:229`), whose body includes:

```dart
// conversation_engine.dart:2604-2628
_finalizedSegments.clear();           // wipes the live transcript
_partialTranscription = '';
_currentTranscription = '';
_followUpChipsController.add(const []);
_aiResponseController.add('');         // <- pushes empty string to home_screen
_postConversationController.add(null);
_emitTranscriptSnapshot();             // <- pushes empty transcript snapshot
```

Note that `_aiResponseController.add('')` flows through the home screen stream listener (`home_screen.dart:169-178`) and clears `_aiResponse`. `_emitTranscriptSnapshot` flows through `home_screen.dart:158-168` and clears `_transcription` and `_transcriptEntries`. `_followUpChipsController.add(const [])` clears `_followUpChips`. If the `recordingStateStream` is also briefly false (because the coordinator has not yet flipped `isRecording.value` back, or because an interrupt-driven restart races `_recordingStateController.add(false)` before the new `add(true)`), `hasLiveConversation` evaluates to false and the page renders the LOADOUT placeholder.

`startSession` already protects against double-entry with `_starting`/`_isRunning` and a `stopEvenAI` call (`conversation_listening_session.dart:77-89`), but **it does not protect `_engine.start()` from being called when the engine is already `_isActive`**. There is no `if (_isActive) return;` guard on `ConversationEngine.start()` (`conversation_engine.dart:222-253`).

Triggers that re-enter `startSession` while the session is logically still alive:
- iOS mic interruption (Siri, phone call, other audio app) — native layer re-establishes the speech subscription which can re-call into `startSession`.
- Platform speech-recognizer error path that the existing code recovers from by tearing down and re-starting (see `OpenAIRealtimeTranscriber` reconnect after 25 identical partials, mentioned in CLAUDE.md "stale partial detection").
- The Live Activity Pause→Resume flow if (in a future change or under an error) it falls through to a restart instead of pure `pauseEvenAI`/`resumeEvenAI`. Today this is only `_invokeMethod('pauseEvenAI'/'resumeEvenAI')` (`conversation_listening_session.dart:364-373`) but the call site is unguarded — any code path that does `coordinator.toggleRecording` twice will reach `_startAll` again.

Evidence (file:line):
- `lib/services/conversation_engine.dart:229` `start()` -> unconditional `_resetLiveSessionState(clearConversationHistory: true)`
- `lib/services/conversation_engine.dart:2604-2628` reset clears `_finalizedSegments`, emits empty AI response and empty snapshot
- `lib/services/conversation_listening_session.dart:97` `_engine.start(source: source)` called from every `startSession`
- `lib/services/conversation_listening_session.dart:77-89` `_starting` guard exists at the listening-session layer but does NOT short-circuit when `_isRunning` is true — instead it calls `stopEvenAI(emitFinal:false)` and falls through to a fresh start, intentionally resetting state.
- `lib/screens/home_screen.dart:158-168, 169-178` snapshot + AI response stream listeners blanket-overwrite local state
- `lib/screens/home_screen.dart:1985-1991` `hasLiveConversation` predicate

### H2 — `recordingStateStream` glitch (false→true) inside the same frame as a snapshot reset (MEDIUM confidence)

When the user toggles the Home record button (`home_screen.dart:425-444`), the listener at `home_screen.dart:134-149` does:

```dart
if (recording) {
  _resetLiveSessionUiState();   // sets _transcription='', _aiResponse='', etc.
  _userHasScrolledUp = false;
}
```

This is correct on a fresh start. However it also fires *every* time `_recordingStateController.add(true)` runs. Any code path that emits `false` then `true` in quick succession (mid-session restart, audio-only fallback in `_handleListeningError` at `recording_coordinator.dart:332`, or a `_setCaptureState` transition that you incorrectly tied to `recordingStateStream` in a future change) drives the visible state to blank for at least one frame.

Today `_recordingStateController.add(false)` is only invoked from `_stopAll` (`recording_coordinator.dart:307`), so this is currently a latent risk rather than an active reproducer — but combined with H1, any restart that passes through `_stopAll` (none today, but `_cleanupFailedStartAttempt` is one stop short of this) would manifest as both H1 and H2 firing together.

Evidence:
- `lib/screens/home_screen.dart:134-149` recordingStateStream listener resets UI on every `true` event
- `lib/services/recording_coordinator.dart:271-272, 306-307` only producers of `_recordingStateController` events
- `lib/services/recording_coordinator.dart:318-330` `_cleanupFailedStartAttempt` does NOT emit `false` (intentional), so today H2 alone is dormant.

### H3 — `clearHistory()` invoked from another tab while a session is active (LOW–MEDIUM confidence)

`ConversationEngine.clearHistory()` (`conversation_engine.dart:2598-2602`) calls `_resetLiveSessionState(clearConversationHistory: true)` and is wired to a UI button: `lib/screens/conversation_history_screen.dart:242` (`_clearHistory` action). If the user opens the History tab during a live session and taps "Clear history", the engine wipes `_finalizedSegments` and emits an empty snapshot — Home will go blank instantly even though `_isRecording` is still true. (`hasLiveConversation` would still be true via `_isRecording`, so the *outer* card stays "live", but the inner block at `home_screen.dart:2042-2049` only renders the transcript card when `_transcription.isNotEmpty || _isRecording` — the transcript paragraph itself disappears, which is the user-visible "live page goes blank" symptom on the transcript subview.)

This is a real and trivially-reproducible mid-session blank for the transcript region. Confidence is LOW–MEDIUM only because we don't yet know whether the user's "blank" report is the *whole card* (H1/H2) or the *transcript subview* (H3). The fix agent should ask or capture both.

Evidence:
- `lib/screens/conversation_history_screen.dart:215, 242, 1302` Clear-history button wiring
- `lib/services/conversation_engine.dart:2598-2602` `clearHistory()` ignores `_isActive`

### H4 — `_compactAndCapSegments` background failure dropping all segments (LOW confidence, but documented bug surface)

CLAUDE.md known bug **BUG-005** says `_compactAndCapSegments` "silently loses data on failure". The implementation at `conversation_engine.dart:609-625` unconditionally `removeRange(0, 100)` from `_finalizedSegments` *before* (and independent of) the background `compactOldSegments` future resolving. It only fires past 200 segments, so it requires a **long** session (>200 finalized segments) — exactly the kind of "5-minute continuous session" the acceptance criterion calls out. After the cap, `_emitTranscriptSnapshot` is **not** explicitly called from inside `_compactAndCapSegments` itself, but the surrounding `onTranscriptionUpdate` flow at `conversation_engine.dart:598-604` does emit one immediately after, so the snapshot will reflect the trimmed list. If the user is scrolled to the top of the live transcript, the visible region becomes empty until they scroll. This is not strictly "blank" but reads as such on small viewports.

Evidence:
- `lib/services/conversation_engine.dart:598-625`
- CLAUDE.md "Known Bugs" BUG-005

## Proposed Minimal Fix

The fix should be defensive at **three** layers, smallest blast radius first:

### Fix 1 — Idempotent `ConversationEngine.start()` (REQUIRED)

In `lib/services/conversation_engine.dart`, at the top of `start()` (around line 222), short-circuit when already active for the same source:

- If `_isActive == true && _transcriptSource == source`, **do not** call `_resetLiveSessionState`. Just refresh the status (`_statusController.add(EngineStatus.listening)`) and return.
- If `_isActive == true && _transcriptSource != source`, log a warning and proceed with the reset (this is a real source change and the caller deserves a clean slate).

This single change blocks H1 entirely. It also makes `ConversationListeningSession.startSession` safe to call from native restart paths without losing the live transcript.

### Fix 2 — Decouple `clearHistory()` from `_resetLiveSessionState` while a session is active (REQUIRED for H3)

In `lib/services/conversation_engine.dart:2598-2602`:

- Guard with `if (_isActive) { _history.clear(); _persistHistory(); return; }` so a clear-history button press during a live session only clears stored history, not the in-memory live transcript.
- Alternatively, refuse the call when `_isActive` and surface an error to the caller, and update `lib/screens/conversation_history_screen.dart:215-245` to disable the Clear button during active sessions.

Pick one — the first is less UX-disruptive.

### Fix 3 — Stable `hasLiveConversation` predicate (DEFENSIVE)

In `lib/screens/home_screen.dart:1985-1991`, add latching: once `hasLiveConversation` becomes true within a session, it should not flip false until the user explicitly stops recording or the session enters terminal idle. Concretely, track a `bool _liveCardLatched` field set to true on `recording=true` and the first non-empty snapshot/AI response, cleared only in `_resetLiveSessionUiState()` and the recording-stop branch. Use it as an additional `||` term.

This is a belt-and-suspenders defense against any future stream glitch (H2-class issues).

### Fix 4 — `_compactAndCapSegments` (out of scope here; tracked as BUG-005)

Do not bundle into this fix. Note in the fix PR description that BUG-005 remains and could surface as a different blank-symptom on >200-segment sessions.

## Test Plan (sim, for the fix agent)

1. **Repro pre-fix.** Apply no changes. Boot dedicated Helix sim, debug build, start a 5-min recorded transcription session via `mcp__ios-simulator__record_video`. While recording, in another terminal tap the History tab and "Clear history". Capture `mcp__ios-simulator__ui_view` immediately after — expect the transcript subview to be empty. Save the recording as the H3 baseline.
2. **Repro pre-fix (H1).** With a recorded session active, simulate a native restart by toggling the OpenAI session mode in Settings (forces `stopSession`/`startSession` cycle). Capture the moment the CONVERSATION HUB card collapses to LOADOUT.
3. **Apply Fix 1 + Fix 2 + Fix 3.**
4. **Verify Fix 1.** Repeat step 2. The transcript and answer should remain intact across the restart. Transcript snapshot listener log line `[HomeScreen] transcriptSnapshot:` should NOT show `segments=0` mid-session.
5. **Verify Fix 2.** Repeat step 1. Transcript subview must remain populated; only the History tab list should clear.
6. **5-minute soak (acceptance gate).** Start a session, leave it transcribing for 5 minutes via sim mic input (or `simulateTranscription` helper at `conversation_engine.dart:2899`). Take `ui_view` snapshots every 30s. Pass = no snapshot shows the LOADOUT placeholder while recording is active.
7. **Regression: Quick-Ask presets.** Tap a preset mid-session and confirm the transcript card remains rendered (Quick-Ask path at `home_screen.dart:3380-3395`).
8. **Gate.** `bash scripts/run_gate.sh` from the worktree. New unit test belongs in `test/services/conversation_engine_test.dart`: assert that calling `start()` twice with the same source does not clear `_finalizedSegments`.

## File Allowlist (fix agent — touch ONLY these)

- `lib/services/conversation_engine.dart` — Fix 1 (idempotent start), Fix 2 (guarded clearHistory)
- `lib/screens/home_screen.dart` — Fix 3 (latched `hasLiveConversation`)
- `test/services/conversation_engine_test.dart` — new regression test for Fix 1
- `test/screens/home_screen_live_card_test.dart` (new file, optional) — widget test for Fix 3 latching
- `.planning/orchestration/reports/WS-B-fix.md` — fix report

**Out of scope (do not touch):**
- `lib/services/conversation_listening_session.dart` — the `startSession` reset semantics are intentional; the fix lives in the engine layer.
- `lib/services/recording_coordinator.dart` — no change needed.
- `lib/services/live_activity_service.dart` — pause/resume path is already correct.
- Any iOS native files — this is a Dart-layer state-management bug.
- `_compactAndCapSegments` — separate bug (BUG-005), separate workstream.

## Confidence Summary

| Hypothesis | Confidence | Reproducible from static evidence? |
|---|---|---|
| H1 mid-session `start()` re-entry | HIGH | Yes — `start()` has no `_isActive` guard, and `startSession` calls it on every entry |
| H2 recordingStateStream glitch | MEDIUM (latent) | Latent — no current producer of mid-session false→true, but defensively worth fixing |
| H3 `clearHistory()` from history tab | MEDIUM-HIGH | Yes — button is reachable mid-session and unconditionally wipes segments |
| H4 `_compactAndCapSegments` long-session | LOW | Requires >200 segments; tracked as BUG-005 |

H1 is the primary fix target. H2 and H3 are co-defensive. H4 is deferred.
