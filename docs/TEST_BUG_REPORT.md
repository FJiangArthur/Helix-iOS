# Test Bug Report

Open issues discovered during testing. Tier-0/1 issues live in
`.planning/todos/pending/` — this file is the stable long-lived list.

| ID | Sev | Component | File:Line | Summary |
|---|---|---|---|---|
| BUG-001 | Medium | `ConversationEngine._compactAndCapSegments` | `lib/services/conversation_engine.dart:384` | Compaction only fires from progressive splitting path, not from `onTranscriptionFinalized`. Unbounded memory growth on batch backends. |
| BUG-002 | Medium | `ConversationEngine._runBackgroundAnalytics` | `lib/services/conversation_engine.dart:1957` | `_analyticsRunning` guard skips rapid calls; sentiment/entity counters don't advance. Tests need 500ms delays to work around. |
| BUG-003 | Low | `ButtonGestureDetector` | `lib/services/button_gesture_detector.dart:175` | Production `multiTapWindow` (300ms) fires before `longPressThreshold` (600ms), so long-press is unreachable with defaults. |
| BUG-004 | Low | `ConversationListeningSession` | `lib/services/conversation_listening_session.dart` | `segmentId` type cast assumes `int?`; test code sending `String?` TypeErrors. |
| BUG-005 | Medium | `ConversationEngine._compactAndCapSegments` | `lib/services/conversation_engine.dart:396` | Fire-and-forget compaction removes 100 segments even if summarization fails → silent data loss. |
| BUG-006 | Info | Audio | `ios/Runner/RNNoiseProcessor.h` | RNNoiseProcessor is header-only; noise reduction toggle has no effect. |
