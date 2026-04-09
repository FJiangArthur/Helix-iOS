# WS-G Thermal Investigation Report

## Hotspot Inventory

| ID | Location | Current behavior | Why hot | Proposed fix | Measurement | Target delta |
|---|---|---|---|---|---|---|
| **H1** HudStreamSession re-pagination | `lib/services/hud_stream_session.dart:103` + `lib/services/text_paginator.dart:86-97` | On EVERY streaming token delta, `_pendingTail` is rewrapped via `splitIntoLines`, which constructs new `TextPainter`+`TextSpan` per width test. O(words²) layouts per delta. ~20 tok/s × 4-sentence answer = hundreds of layout() calls on UI isolate | (a) Reuse single `TextPainter` instance, swap `text`. (b) LRU cache `_measureTextWidth` (cap 128). (c) Skip wrap when `delta`<2 and `_pendingTail`<previous boundary. (d) Length heuristic short-circuit | Instruments Time Profiler filtered to `TextPainter.layout`; DEBUG counter every 2s | ≥80% TextPainter.layout reduction; UI-isolate CPU −15-25% during streaming |
| **H2** Bitmap HUD encode rate | `lib/services/bitmap_hud/bitmap_hud_service.dart:165-178, 311-340, 380-436` | Refresh timer pauses on `setConversationActive(true)` BUT `pushDelta` re-renders full dashboard + `DeltaEncoder.diff` over whole BMP every tick. Settings/reconnect/external callers pay full cost. `_refreshAllWidgets` awaits sequentially | (a) Verify `setConversationActive(true)` actually called from ConversationEngine. (b) Hash-compare rendered bytes, skip `DeltaEncoder.diff` on match. (c) `Future.wait` for `_refreshAllWidgets` | Counters for `renderDashboard`/`_sendFull`/`_sendDelta`; Allocations on `BitmapRenderer.render` | Zero bitmap encodes during active streaming; background rate halved |
| **H3** PCM converter allocation | `ios/Runner/PcmConverter.m:44-62` + call `BluetoothManager.swift:617` | Every BLE MIC_DATA packet allocates new `NSMutableData` of `frameCount × _bytesOfFrames`, append-loops per 20-byte LC3 frame. Two `Data` bridge copies on BLE callback queue per buffer | (a) Instance-level `_scratchPCM` `NSMutableData`, `setLength:` to expected size, decode into `mutableBytes`, return `dataWithBytesNoCopy:freeWhenDone:NO`. (b) Or expose `-decodeInto:capacity:` + ring buffer. (c) Skip rebridge when RNNoise off | Instruments Allocations filtered to `NSMutableData`/`Data`, 60s of streaming | ≥90% per-packet heap allocations reduction; BLE callback CPU −5-10% |
| **H4** BLE write loop | `ios/Runner/BluetoothManager.swift:496-560` | Per-write `print(...)` diagnostics on lines 508-512, 520, 523, 533, 536, 545, 548, 555, 558 are NOT `#if DEBUG`-gated (only G1DBG NSLog block above). Fire on every BLE write — 10-30 streaming pushes/answer + MIC_DATA + bitmap chunks. `print()` lands in unified log even in release | Wrap all `print("writeData ...")` diagnostics in `#if DEBUG`. Keep only fatal-path logs. Consider `peripheralIsReady(toSendWriteWithoutResponse:)` coalescing | Console.app capture, count `writeData` lines in 60s sim session; Instruments os_log Energy | ≥95% log line reduction in release; BLE dispatch queue CPU −2-5% |
| **H5** OpenAI Realtime WS encode | `ios/Runner/OpenAIRealtimeTranscriber.swift:429-498` | Every 100ms tick: full resample 16k→24k, alloc `Data`, base64-encode, build NSDictionary, `JSONSerialization`, `URLSessionWebSocketTask.Message.string`. 10 Hz sustained. `audioBuffer.removeFirst(overflow)` at :187 is O(n) on NSData | (a) Reuse output buffer in `AudioResampler.resample`. (b) JSON template string concat, skip `JSONSerialization`. (c) Ring buffer or size-check discard for overflow trim. (d) Batch 2× 100ms → 200ms cadence in transcriptionOnly mode | Instruments Time Profiler on `flushAudioBuffer`; existing `flushLogCount`; Allocations on `Data`/`String` | Send rate −50% (10→5 Hz batched); per-tick CPU −30%; zero resampler allocs |
| **H6** AGX 5 Hz sandbox-denial firehose | Likely `ios/Runner/DebugHelper.swift:9-32` (`AVAudioSession debugging enabled` route/interruption notifications) + `BluetoothManager` `CBCentralManager` state queries + `hasPermissionToRecord` at `SpeechStreamRecognizer.swift:1507`. AGX-prefixed denial = system framework querying Metal/GPU-backed service without entitlement. Candidates: `flutter_sound`/`record` initing `AVAudioRecorder` at startup, Speech framework prewarming AppIntents Metal path, Flutter shader compiler `MTLCreateSystemDefaultDevice()` from background | Repro first: `log stream --predicate 'subsystem contains "AGX" OR eventMessage contains "Sandbox"'` for 30s launch, identify exact process/message. Likely fixes: (a) remove `DebugHelper.setupAudioSessionLogging()` in release, (b) verify Speech auth deferred, (c) `#if DEBUG`-gate any widget/preview Metal path | `xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "AGX" OR eventMessage CONTAINS "sandbox"'` count/60s | ≥95% reduction (~300/min → <10/min) |
| **H7** Audio session reactivation storm | `ios/Runner/SpeechStreamRecognizer.swift:266-281, 544-553, 652-661, 1347-1372`. `result.isFinal` from Apple Speech triggers `cleanupRecognition(deactivateSession: true)` at lines 321, 436, 448, which `setActive(false)` then next `beginRecognition` re-activates. Segment restart timer at `:74` (15s) compounds | (a) In `cleanupRecognition` from `result.isFinal`, pass `deactivateSession: false` (pattern at 854, 861, 900, 907 already does this). (b) Debounce: skip `setActive(true)` if already in desired category/mode. (c) Centralize via single `configureAudioSessionIfNeeded()` — three drift-prone copies | `NSLog("[AudioSess] setActive...")` counter + 5-min sim conversation; `log stream --predicate 'subsystem == "com.apple.audio.AVFAudio"'` | `setActive()` calls / 5-min: ~20-40 → ≤2 |

## Scope Notes

- LiveActivity 1000 Hz storm ALREADY FIXED (`f8f0269`) — out of scope
- G1DBG TX/RX NSLog firehose ALREADY GATED (`625b61d`) — H4 covers REMAINING ungated `print()`
- RNNoise header-only (BUG-006) — H3(c) cosmetic

## File Allowlist

- `lib/services/hud_stream_session.dart`
- `lib/services/text_paginator.dart`
- `lib/services/bitmap_hud/bitmap_hud_service.dart`
- `lib/services/bitmap_hud/bitmap_renderer.dart` (only if hash cache added)
- `ios/Runner/PcmConverter.h`
- `ios/Runner/PcmConverter.m`
- `ios/Runner/BluetoothManager.swift` (gate remaining `print` only)
- `ios/Runner/OpenAIRealtimeTranscriber.swift`
- `ios/Runner/AudioResampler.swift`
- `ios/Runner/SpeechStreamRecognizer.swift`
- `ios/Runner/DebugHelper.swift` (release gating only)
- `ios/Runner/AppDelegate.swift` (only DebugHelper call gating or AGX log predicate)

**MUST NOT touch:** `conversation_engine.dart`, `lib/services/llm/**`, `evenai.dart`, `recording_coordinator.dart`, test helpers, migrations.

## Sim Test Plan

1. Boot dedicated Helix sim (NOT shared 0D7C3AB2 / 6D249AFF). `flutter run --profile -d <sim>`
2. Baseline (pre-fix):
   - `xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "AGX" OR eventMessage CONTAINS "sandbox" OR eventMessage CONTAINS "writeData" OR subsystem == "com.apple.audio.AVFAudio"' > /tmp/wsg-baseline.log &`
   - Start session via `mcp__ios-simulator__ui_tap`, hold 2 min, ask 2 questions
   - Kill stream, count lines per predicate
3. Instruments baseline: `xcrun xctrace record --template 'Time Profiler' --launch -- <app>` for 120s same scenario; export top 20 self-time CSV
4. Allocations run separately — heap growth + `NSMutableData` count
5. Apply fixes, rerun 2-4. Delta table per hotspot
6. Unit test: `TextPaginator` TextPainter call counter, assert ≤N layouts per 100-token stream
7. `bash scripts/run_gate.sh`

**Metrics persisted in `WS-G-fix.md`:** layouts/100tok (H1), renderDashboard/min during session (H2), `NSMutableData` allocs/sec MIC_DATA (H3), `writeData` log lines/min release (H4), `flushAudioBuffer`/min + CPU (H5), AGX/sandbox lines/min (H6), `setActive(true)` / 5min (H7)

## HW Verification Plan (G1 required)

1. Profile build on iPhone. Instruments: Energy Log + Thermal State + Time Profiler
2. 10-min session: OpenAI transcription + 5 Q&A + bitmap HUD + G1 connected
3. Record thermal state transitions, avg CPU%, ProcessEnergy/subsystem
4. Success: thermal ≤ `fair`, avg CPU ≤30%, no thermal-induced BLE disconnects
5. Compare vs pre-fix HW baseline (or 4K-video heat reference)

## Implementation Order (cheapest/safest first)

1. **H4** — `#if DEBUG`-gate `BluetoothManager.writeData` `print()`. Mechanical, zero risk. ~5 min
2. **H7** — `cleanupRecognition(deactivateSession: false)` from final-result branches + setActive guard. Covered by speech tests. ~1 hr
3. **H6** — log-predicate repro → identify source → targeted gate. ~1 hr
4. **H3** — `_scratchPCM` reusable buffer. ~1 hr
5. **H1** — `TextPainter` reuse + LRU. Wrap-accuracy risk; cover with paginator + snapshot tests. ~2 hr
6. **H5** — Realtime batching + JSON template. Protocol compliance risk; gate behind flag. ~2 hr
7. **H2** — bitmap hash short-circuit + verify `setConversationActive(true)` wiring. Shared file, last. ~2 hr

Total ~10 hr single fix agent. Gate after each step + targeted sim scenario. Halt on any regression.

## Load-bearing references

- `lib/services/hud_stream_session.dart:103` — `splitIntoLines` per delta
- `lib/services/text_paginator.dart:86-97` — new TextPainter per measurement
- `ios/Runner/BluetoothManager.swift:617` — `pcmConverter.decode as Data` per packet
- `ios/Runner/BluetoothManager.swift:508-558` — ungated `print()` diagnostics
- `ios/Runner/OpenAIRealtimeTranscriber.swift:464-498` — 100ms resample+base64+JSON
- `ios/Runner/OpenAIRealtimeTranscriber.swift:187` — `removeFirst` O(n) trim
- `ios/Runner/SpeechStreamRecognizer.swift:321, 436, 448` — `cleanupRecognition(true)` from final
- `ios/Runner/SpeechStreamRecognizer.swift:74` — `segmentRestartInterval = 15`
- `lib/services/bitmap_hud/bitmap_hud_service.dart:183-193` — `setConversationActive` gate (verify caller)
