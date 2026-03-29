# Helix-iOS Status Baseline — 2026-03-28

## Version
- **App Version**: 2.2.0+9
- **Branch**: main
- **Latest Commit**: 946bc43
- **Build**: Release (no debug harness)
- **Device**: iPhone 17 Pro Max (iOS 26.4)

---

## Session Summary

### What Was Built Today

| Feature | Commit | Status |
|---------|--------|--------|
| Fastlane setup (TestFlight + App Store) | d81bc78, 3becc1e, 6335a02 | Working |
| Tab restructure: Home, Glasses, History, Live, Insights | 468f79b | Working |
| InsightsScreen (Facts + Memories + Ask Buzz merged) | 468f79b | Working |
| 7-page onboarding walkthrough | 468f79b | Working |
| Settings as pushed route (gear icon in AppBar) | 468f79b | Working |
| Mic source chip on Home (Auto/Phone/G1) | 468f79b | Working |
| Mic permission fix for OpenAI path (iOS 17+) | 468f79b | Deployed, untested on device |
| Transcription event sink race condition fix | a1d366d | Deployed, needs device verification |
| Bitmap HUD timeout increase (200→500ms) + retry | a1d366d | Deployed, still failing |
| Default HUD to text mode | 4e7779b | Working |
| Home screen reverted to paragraph layout | 946bc43 | Working |
| Multi-agent validation protocol + post-run hook | 76ba8c8 | Docs only |
| Branch cleanup (42 branches deleted) | — | Done |

### TestFlight Builds Deployed
| Build Number | Time | Content |
|---|---|---|
| 202603280024 | 00:32 | First fastlane build |
| 202603280037 | 00:39 | Fastlane ship lane verified |
| 202603281230 | 12:31 | Tab restructure + onboarding |
| 202603281245 | 12:46 | Settings tooltip fix |
| 202603281701 | 17:02 | Pre-device-test build |
| 202603281807 | 18:09 | Transcription + bitmap fix |

---

## Known Issues (Active)

### BUG: Transcription Not Working on Device
- **Severity**: P0 (Critical)
- **Status**: Fix deployed (a1d366d), needs device verification
- **Symptom**: Recording activates (UI shows recording state, duration timer runs) but no transcription text appears. Affects both Apple Cloud and OpenAI backends.
- **Root Cause**: Race condition in event sink attachment. The Flutter EventChannel subscription and native `startEvenAI` method channel call fire in the same run loop cycle. The native `SpeechStreamRecognizer.beginRecognition()` starts producing transcript events before the Flutter event sink is attached. Events are buffered but the buffer is cleared at session start.
- **Fix Applied**: Added 100ms delay between EventChannel subscribe and `startEvenAI` call to ensure the event sink attaches first. Wrapped `getApiKey` in try-catch for simulator compatibility.
- **Files**: `lib/services/conversation_listening_session.dart`, `ios/Runner/SpeechStreamRecognizer.swift`
- **Verification**: Needs real device test with both Apple Cloud and OpenAI backends.

### BUG: Bitmap HUD Render Failed
- **Severity**: P1 (High)
- **Status**: Partially mitigated, underlying issue remains
- **Symptom**: "Bitmap dashboard render failed" on Glasses tab. Sometimes only one eye (L or R) updates.
- **Root Cause**: Bitmap HUD sends 32KB (165 chunks × 194 bytes) via sequential BLE request/response through a 200ms write coalescing buffer. The per-chunk timeout (originally 200ms) was too tight, causing frequent timeouts. When L side fails, R side never gets sent (sequential abort).
- **Fix Applied**: Increased timeout to 500ms, added per-chunk retry, dashboard retries full send before showing error.
- **Workaround Applied**: Defaulted HUD to text mode (sentence streaming). Bitmap is opt-in via Settings.
- **Files**: `lib/controllers/bmp_update_manager.dart`, `lib/services/dashboard_service.dart`, `lib/services/settings_manager.dart`
- **Remaining**: Need to either fix the BLE chunking reliability or redesign the bitmap transfer protocol (e.g., stream without request/response per chunk).

### BUG: Auto-sentence "Give me an interesting topic"
- **Severity**: P2 (Medium)
- **Status**: Investigating
- **Symptom**: The suggestion "Give me an interesting topic to discuss" appears as an auto-submitted message in the conversation, even though the user didn't tap it.
- **Root Cause**: Unknown. The suggestion chips in `home_screen.dart` all require explicit `onTap` gesture. No auto-submit code found. Possible causes:
  - Follow-up chip auto-execution from a previous session
  - Stale conversation state persisted across app restarts
  - Accidental touch on suggestion chip during app launch
- **Files**: `lib/screens/home_screen.dart:2308-2331` (suggestion chips)
- **Next Steps**: Add logging to `_submitQuestion()` to track what triggers it.

### BUG: No Recording Playback
- **Severity**: P2 (Medium)
- **Status**: Not started
- **Symptom**: Past conversations show analysis (summary, topics, transcript) but no audio playback.
- **Root Cause**: Audio files ARE recorded to disk (`~/Documents/recordings/helix_recording_*.wav`) but the file path is never saved to the database. The `Conversations` table lacks an `audioPath` column.
- **Files**:
  - `lib/services/database/helix_database.dart` — needs `audioPath` column
  - `lib/services/conversation_engine.dart:281-320` — needs to capture `RecordingCoordinator.lastAudioFilePath`
  - `lib/screens/conversation_detail_screen.dart` — needs playback UI
- **Next Steps**: Add column, migration, save path on stop, add playback widget.

---

## Known Issues (Pre-existing, Documented)

| Bug | Severity | Summary | Status |
|-----|----------|---------|--------|
| BUG-001 | Medium | Segment compaction only fires from progressive splitting path | Open |
| BUG-002 | Medium | Analytics counter skipped during rapid finalization (500ms delay workaround in tests) | Open |
| BUG-003 | Low | Long-press gesture unreachable with production timer defaults | Open |
| BUG-005 | Medium | _compactAndCapSegments silently loses data on failure | Open |
| BUG-006 | Info | RNNoiseProcessor is header-only / not implemented | Open |

---

## Architecture State

### Tab Layout (Current)
| Index | Screen | File |
|-------|--------|------|
| 0 | Home (paragraph transcript + AI) | `home_screen.dart` |
| 1 | Glasses (G1 control + mic source) | `g1_test_screen.dart` |
| 2 | History (filterable sessions) | `conversation_history_screen.dart` |
| 3 | Live (real-time analysis) | `detail_analysis_screen.dart` |
| 4 | Insights (Facts + Memories + Buzz) | `insights_screen.dart` |
| — | Settings (pushed route via gear icon) | `settings_screen.dart` |

### Home Screen Layout (Reverted)
- **Single paragraph** transcript card with highlighted question excerpt
- **Detected question** card with question icon
- **AI answer** card with streaming text
- **Response tools**: Summarize, Rephrase, Translate, Fact Check, Send to Glasses, Pin Answer
- **Follow-up chip deck** with AI-generated suggestions
- **Glasses scrolling** status indicator
- **Composer dock**: ask field + mic source chip + record button

### HUD Render Path
- **Default**: Text mode (sentence-by-sentence streaming via EvenAI protocol)
- **Optional**: Bitmap mode (opt-in, reliability issues with BLE chunking)

### Transcription Backends
- **Apple Cloud** (default): SFSpeechRecognizer with cloud processing
- **Apple On-Device**: SFSpeechRecognizer with on-device processing
- **OpenAI**: gpt-4o-mini-transcribe via WebSocket
- **Whisper**: Batch transcription via WhisperBatchTranscriber

### LLM Providers
- OpenAI (gpt-4.1 family), Anthropic, DeepSeek, Qwen, Zhipu, SiliconFlow
- Custom model override via Settings dialog

---

## Test State

- **Static analysis**: 0 errors, 47 warnings/infos
- **Unit tests**: 356 passing, 31 failing (all pre-existing)
- **Simulator validation**: 18/18 passed (onboarding, tabs, sub-tabs, settings)
- **Device testing**: Transcription bug identified and fix deployed, awaiting verification

---

## Deployment

- **Fastlane**: Configured with `testflight_release`, `release`, `ship` lanes
- **API Key**: App Store Connect via `~/.appstoreconnect/admin-AuthKey_334J623VNU.p8`
- **Signing**: Automatic with team 4SA9UFLZMT
- **Bundle ID**: `com.artjiang.helix`
- **Display Name**: Even Companion

---

## Next Priority Actions

1. **Verify transcription fix** on device with Apple Cloud and OpenAI
2. **Investigate auto-sentence** bug — add logging to `_submitQuestion()`
3. **Add recording playback** — database migration + playback UI
4. **Fix bitmap HUD** — redesign BLE transfer protocol or implement fire-and-forget streaming
5. **Add notification forwarding** — sync whitelist to G1 on BLE connect
