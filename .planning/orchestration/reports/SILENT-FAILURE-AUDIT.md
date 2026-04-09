# Silent-Failure Audit — Multi-Track Orchestration 2026-04-08

**Range:** `c36f9a2..a5448bd` (PHASE 3 cumulative diff after γ→δ→β→α merges)
**Run by:** pr-review-toolkit:silent-failure-hunter
**Date:** 2026-04-08

## Verdict

**8 MAJOR findings** (mostly WS-I + WS-G regressions) + 6 minor. Recommend a HOTFIX commit before WS-J / final HW handoff. Gate is green vs baseline but release builds will lose signal on critical BLE/audio failure paths.

## MAJOR

| # | File:Line | WS | Issue | Fix |
|---|---|---|---|---|
| 1 | `ios/Runner/SpeechStreamRecognizer.swift:69,284,567,678,1385` | WS-G H7 | `isAudioSessionActive` flag latches on iOS-external deactivation (interruption / route change). No `AVAudioSession.interruptionNotification` observer. Audio silently fails to flow with zero log. | Observe `interruptionNotification` + `routeChangeNotification`; clear flag; log when activation skipped because already active. |
| 2 | `ios/Runner/PcmConverter.m:57-77` | WS-G H3 | `_scratchPCM` shared instance returned via `as Data` (CoW). Next MIC_DATA packet calls `setLength:` mutating memory still referenced by async WebSocket sender (H5 fast path). Corrupted audio frames, no error. | Return `[_scratchPCM copy]` or use a free-list of buffers. |
| 3 | `ios/Runner/BluetoothManager.swift:497-520, 553-604` | WS-I | `writeData` nil-char/peripheral branches now `#if DEBUG print()` then silently return. Caller assumes write succeeded; HUD state machines latch on packet that never went out. | Even with print gated, `invokeMethod("writeFailed", ...)` to Dart or unconditional NSLog. |
| 4 | `ios/Runner/BluetoothManager.swift:508-514` | WS-I | `didWriteValueFor characteristic error` only prints in DEBUG. ACK-path failures from glasses are completely discarded in release. | Forward via `invokeMethod("bleWriteError", ...)` or unconditional log. |
| 5 | `ios/Runner/BluetoothManager.swift:310-316` | WS-I | `didDisconnectPeripheral` error message DEBUG-gated; `glassesDisconnected` invokeMethod doesn't carry error. Disconnect reason lost in release. | Include `error?.localizedDescription` in invokeMethod args. |
| 6 | `ios/Runner/BluetoothManager.swift:328-333` | WS-I | "Max reconnect attempts reached" DEBUG-gated. Terminal failure invisible to Dart and user. | invokeMethod `"status": "reconnect_exhausted"` before return. |
| 7 | `ios/Runner/BluetoothManager.swift:510-516` | WS-I | `didUpdateNotificationStateFor error` DEBUG-gated. Failed subscribe means downstream pipelines never fire silently. | Propagate via invokeMethod or unconditional log. |
| 8 | `ios/Runner/LiveActivityManager.swift:38-42` | WS-I | "[LiveActivity] Failed to start" DEBUG-gated; catch swallows. User expects Dynamic Island, gets nothing, no signal. | Unconditional error log OR invokeMethod to Flutter. |

## MINOR

| # | File:Line | WS | Issue | Fix |
|---|---|---|---|---|
| 9 | `lib/services/conversation_engine.dart:2147` | WS-A | Realtime guard bare `return` no log when `bypassRealtimeGuard==false`. Trap for future callers. | `appLogger.d('_generateResponse skipped: realtime active, bypass=false');` |
| 10 | `lib/services/factcheck/tavily_search_provider.dart:46-79` | WS-E | All error paths log at `appLogger.d` (debug). Release: invisible. | Upgrade to `appLogger.w`. |
| 11 | `lib/services/conversation_engine.dart:~1536` | WS-E | `_activeFactCheck` outer catch logs at `d`, no stack trace. | `appLogger.w('[ActiveFactCheck] failed', error: e, stackTrace: st);` |
| 12 | `lib/services/bitmap_hud/bitmap_hud_service.dart` | WS-H | `pushEnlargedWord` returns false; audit callers don't swallow. Not a regression. |
| 13 | `lib/services/dashboard_service.dart:334-341` | WS-D | Bitmap restore failure has `blockedReason` snapshot but no error log at site. | Add `appLogger.e(...)` before return. |
| 14 | `ios/Runner/BluetoothManager.swift:697-700` | WS-I | `blueInfoSink not ready, dropping data` no counter. | Bump int counter, expose via introspection. |

## CLEAN (verified)

- WS-B `ConversationEngine.start()` idempotent — logs both branches ✅
- WS-B `clearHistory({force})` — observable ✅
- WS-F `InputDispatcher` — every drop counted (debouncedCount/coalescedVolumeCount/holdSuppressedCount), errors logged with stack traces. **Model for the rest of the codebase.** ✅
- WS-D `setConversationActive(true)` early return ✅
- WS-D `evenai._flashFeedback` intent restore ✅
- WS-G H2 bitmap delta short-circuit ✅
- WS-G H1 TextPaginator cache ✅
- WS-G H5 `sendAudioAppendFast` — calls `handleDisconnect` + `warningLog` on error ✅

## Recommended Action

Land a single hotfix commit "fix(ble,audio): preserve release visibility for terminal failure paths" that addresses MAJOR #3–#8 (BLE silencing cluster) at minimum, and ideally #1 + #2 too. Minor issues can be folded in or deferred to a follow-up sweep.
