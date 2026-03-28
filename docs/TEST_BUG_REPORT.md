# Helix-iOS Test Bug Report

Generated: 2026-03-26

## Bugs Found During Testing

### BUG-001: Segment compaction only fires from progressive splitting path
- **Severity**: Medium
- **Component**: ConversationEngine._compactAndCapSegments
- **File**: `lib/services/conversation_engine.dart:384-387`
- **Description**: The `_compactAndCapSegments()` method is only called from `onTranscriptionUpdate()` (the progressive sentence splitting path). It is NOT called from `onTranscriptionFinalized()`. This means conversations that finalize segments directly (e.g., from Whisper batch backend) will never trigger compaction, leading to unbounded memory growth in `_finalizedSegments`.
- **Impact**: Long conversations using Whisper batch transcription can grow without bound.
- **Fix**: Add the compaction check to `onTranscriptionFinalized()` as well.
- **Test**: `conversation_engine_long_session_test.dart` B12

### BUG-002: Analytics counter skipped during rapid segment finalization
- **Severity**: Medium
- **Component**: ConversationEngine._runBackgroundAnalytics
- **File**: `lib/services/conversation_engine.dart:1957-1971`
- **Description**: The `_analyticsRunning` guard in `_runBackgroundAnalytics()` prevents concurrent execution. When segments are finalized rapidly, only the first call's analytics runs — subsequent calls return immediately. The sentiment and entity counters (which are incremented inside the guarded methods) don't advance for skipped calls. This means sentiment analysis requires N * 3 segments (where N-1 analytics calls were skipped) instead of exactly 3.
- **Impact**: Sentiment and entity analysis may never trigger during fast-paced conversations.
- **Fix**: Move counter increments outside the guard, or queue analytics runs instead of skipping them.
- **Test**: `conversation_engine_analytics_test.dart` B9 (requires 500ms delays between segments)

### BUG-003: ButtonGestureDetector long-press timing paradox
- **Severity**: Low
- **Component**: ButtonGestureDetector state machine
- **File**: `lib/services/button_gesture_detector.dart:175-201`
- **Description**: Production defaults have `longPressThreshold` (600ms) > `multiTapWindow` (300ms). The `_onMultiTapExpired` callback fires at 300ms and cancels the `_longPressTimer`. This means long-press detection can never trigger with default settings — the multi-tap timer always fires first and transitions to idle before the long-press threshold is reached.
- **Impact**: Long-press gestures (voice note, walkie-talkie mode) are unreachable with production defaults.
- **Fix**: Either increase `multiTapWindow` to > `longPressThreshold`, or restructure so `_onMultiTapExpired` only fires when the button has been released.
- **Test**: `button_gesture_detector_test.dart` D3 (uses custom timers to work around)

### BUG-004: SpeechEventEmitter segmentId type mismatch
- **Severity**: Low
- **Component**: ConversationListeningSession
- **File**: `lib/services/conversation_listening_session.dart`
- **Description**: The native platform channel sends `segmentId` as `int?`, but test emitters may send `String?`. The session casts it as `int?`, causing a `TypeError` at runtime if a string is passed.
- **Impact**: Only affects test code, not production. But makes it harder to write realistic test scenarios.
- **Fix**: Either validate the type in the session or document the expected type.

### BUG-005: _compactAndCapSegments silently loses data on failure
- **Severity**: Medium
- **Component**: ConversationEngine._compactAndCapSegments
- **File**: `lib/services/conversation_engine.dart:396-410`
- **Description**: The method calls `_sessionContextManager.compactOldSegments()` fire-and-forget, then immediately removes 100 segments from `_finalizedSegments`. If the summarization fails, those 100 segments are permanently lost — no data recovery, no user notification.
- **Impact**: Summarization failures during long sessions lead to silent data loss.
- **Fix**: Only remove segments after successful compaction, or keep a backup.

### BUG-006: RNNoiseProcessor is header-only (not implemented)
- **Severity**: Info
- **Component**: Audio processing
- **File**: `ios/Runner/RNNoiseProcessor.h`
- **Description**: The `noiseReduction` setting in the app references RNNoiseProcessor, but only the header file exists. The C source files are not added. The TODO comment says to add them from the rnnoise repo.
- **Impact**: Noise reduction toggle in settings has no effect.

## Test Coverage Summary

| Category | Tests | Pass | Fail |
|----------|-------|------|------|
| Button Gesture Detector | 8 | 8 | 0 |
| Transcription Pipeline | 9 | 9 | 0 |
| E2E Conversation Flow | 3 | 3 | 0 |
| Engine Error Handling | 4 | 4 | 0 |
| Engine Modes | 5 | 5 | 0 |
| Silence Timeout | 3 | 3 | 0 |
| Engine Analytics | 9 | 9 | 0 |
| Engine Proactive | 5 | 5 | 0 |
| Engine Features | 7 | 7 | 0 |
| Entity Memory | 9 | 9 | 0 |
| Session Context Manager | 16 | 16 | 0 |
| Gesture Action Router | 12 | 12 | 0 |
| Long Session | 8 | 8 | 0 |
| **Total New Tests** | **97** | **97** | **0** |
