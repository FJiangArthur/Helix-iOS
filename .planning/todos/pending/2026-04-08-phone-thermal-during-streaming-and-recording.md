---
created: 2026-04-08T00:00:00.000Z
title: Tier-1 — Phone heats up very fast during streaming + voice recording
area: performance
status: in-progress
progress_2026-04-07: |
  Cheap wins applied without Instruments (full investigation requires
  hardware profiling, blocked):
  - Tier-0 HUD streaming fix landed (commit 59d24ff): line-gated emits
    now skip empty pages, dedupe identical pageText, and drop one
    redundant streaming flush in finish(). Should reduce BLE write rate
    by 1 frame per response and eliminate near-duplicate frames during
    rapid token bursts.
  - Gated [CostTracker] debugPrint behind kDebugMode — was firing on
    every LLM call (incl. background fact-check, entity extraction,
    sentiment) in release. This is candidate #6 from the TODO.
  - Commit 625b61d: wrapped [G1DBG] TX + RX NSLog firehoses in
    #if DEBUG — fired 10+/sec on every BLE packet in release and
    routed through the iOS unified logging system.
progress_2026-04-08: |
  **Major finding from on-device profiling** (commit f8f0269):
  RecordingCoordinator.durationStream ticks at SUB-MILLISECOND cadence
  and every tick was unconditionally forwarded to ActivityKit. Since
  the Live Activity only renders duration with second precision, 999
  of every 1000 updates pushed an identical payload. Verified on-
  device as a ~1000 updates/sec storm routed through chronod +
  runningboardd on iPhone 17 Pro Max, confirmed via Console.app log
  capture before/after. This was a major contributor to the "phone
  heats up like 4K video" symptom.
  Fix: gate the forward on `duration.inSeconds` change →
  exactly 1/sec. 9-line patch in lib/services/live_activity_service.dart.
  This was NOT in the original candidate list (#1-#6) — profiling
  found a hot path the static audit missed. Worth keeping in mind
  for future thermal investigations: check IPC/runtime-broker cadence
  (chronod, runningboardd, rosetta) in addition to app-internal CPU.
  Still pending: full Instruments sweep with Time Profiler + Energy
  Log + Allocations to quantify the post-fix delta and identify any
  remaining hot paths (bitmap HUD encoding, BLE write queue, PCM
  convert). Next hardware session should run the 3-trace plan from
  debugging-instruments skill.
files:
  - lib/services/conversation_engine.dart
  - lib/services/hud_stream_session.dart
  - lib/services/bitmap_hud/bitmap_hud_service.dart
  - lib/services/proto.dart
  - ios/Runner/SpeechStreamRecognizer.swift
  - ios/Runner/BluetoothManager.swift
  - ios/Runner/PcmConverter.m
---

## Problem

**Priority:** Tier-1
**Reported:** 2026-04-07 hardware test on main @ 689b5ae (integrated
C+B+D stack, with `hud.lineStreaming` default ON pending)

The phone heats up very quickly during a live listening session —
specifically when streaming audio to a transcription backend AND
streaming AI answers back to the glasses HUD at the same time. User
compared the thermal profile to recording 4K video on the device.

This is fast enough that a 10-20 minute session will probably hit thermal
throttling and the system may start degrading audio quality or killing
background work.

## Why this matters

- Battery drain scales with heat
- Thermal throttling can cause audio dropouts and BLE disconnects —
  either of which would look like a different bug to the user
- App Store review may flag excessive power draw (5.2.3 / Hardware
  Compatibility)
- If the glasses HUD jitter / intermittent HUD issue (see
  `2026-04-08-hud-intermittent-factory-default-after-session-start.md`)
  correlates with thermal state, they may be symptoms of the same root
  cause

## Candidates to investigate

Ranked roughly by how likely I think each is to be a hot loop on main
post-merge. Measure before fixing.

### 1. `HudStreamSession` / `_sendToGlasses` re-pagination every flush

`lib/services/hud_stream_session.dart` emits a full `ProtoHudPacketSink.send`
on every line boundary. Each send re-runs `TextPaginator.paginateText`
on the full current answer, re-encodes UTF-8, chunks into 191-byte BLE
packets, and writes to BOTH L and R characteristics. For a long answer
this can fire 10-30 times.

Check:
- How expensive is `TextPaginator.paginateText` per call?
- Are we re-encoding the same leading bytes every time?
- Is there a faster memoized path for "same text as last time plus N new
  tokens"?

With Plan B's line-streaming now default ON (this session), the call
frequency went DOWN (line-gated vs token-gated), so this should actually
be *less* hot than the pre-B path. But verify with Instruments.

### 2. Bitmap HUD widget re-rendering

`lib/services/bitmap_hud/bitmap_hud_service.dart` registers widgets and
renders to a bitmap every frame. If this is invoked on every streaming
update (token or line), the bitmap encode + BLE send loop is the hot
path. Measure:
- Frames per second during streaming
- CPU % of the bitmap rendering thread
- Whether we're rendering to the OffscreenCanvas or the real
  RepaintBoundary

The CLAUDE.md lists "HUD Render Path | Bitmap" as the default. So this
path IS live.

### 3. Audio downsample / PCM conversion in main isolate

`ios/Runner/PcmConverter.m` converts mic buffers from hardware format
(44.1kHz or 48kHz) to 16kHz mono for the transcription backend. If this
runs on the main thread or is called per-buffer without reuse, it's hot.

Check:
- Which thread does `AVAudioInputNode.installTap`'s tap block run on?
- Is the converter allocated per-buffer or reused?
- Are we allocating Data buffers per frame?

### 4. BLE write loop burning CPU waiting for ACKs

`ios/Runner/BluetoothManager.swift` dual-connects L + R. If the write
queue is polling or spinning on writeWithResponse acks, the main BLE
dispatch queue may be hot. The `G1DBG` firehose logs from earlier
sessions suggest the firmware ACK cadence is high.

Check:
- Is there a `while` loop in the write path?
- Is `writeValue(for:type:.withResponse)` being awaited with a busy
  wait, or CBPeripheralDelegate callback?

### 5. Transcription websocket keepalive + chunking

`ios/Runner/OpenAIRealtimeTranscriber.swift` (Realtime backend) keeps a
WebSocket open and streams 100ms audio frames. If we're encoding each
frame as base64 in the main queue and writing immediately, the JSON
serialize + base64 is hot. Less hot for Apple Cloud (HTTP streaming).

Note: the default backend per CLAUDE.md is OpenAI, which uses
`gpt-4o-mini-transcribe` via... we should confirm whether that's the
batch HTTP or the realtime WS path on hardware.

### 6. `debugPrint` firehose from new diagnostics

This session added two sets of diagnostics that fire on every LLM call:
- `[CostTracker] +...` in `conversation_cost_tracker.dart`
- `[ConversationEngine] _generateResponse received [Error]` (only on
  error path — cheap)
- `[ProviderErrorState] UNKNOWN bucket: ...` (only on error path — cheap)

`debugPrint` is cheap but if you're ALSO running `G1DBG` native logs and
transcription-timing logs, the combined console volume could be a
contributor in release builds. Release builds strip most debugPrint via
`kReleaseMode`, but check that the new ones I added are inside release-
mode guards where appropriate. (Spot check: the CostTracker debugPrint
is not — it always fires. That's a candidate to gate behind
`kDebugMode` once we've captured enough repro data.)

## Investigation steps

1. **Baseline with Instruments.** Build for profiling
   (`flutter build ios --profile`), attach Instruments "Energy Log" +
   "Time Profiler" + "Thermal State", record a 2-minute session with
   streaming audio + one AI answer, and look at:
   - Thermal state (nominal / fair / serious / critical)
   - CPU % per thread
   - Top 10 functions by self-time
   - Energy impact breakdown (CPU / networking / location / display)

2. **Isolate subsystems.** Run the same scenario with:
   - Glasses disconnected (eliminates BLE + bitmap HUD)
   - Bitmap HUD disabled (Text HUD fallback)
   - `hud.lineStreaming` OFF (legacy per-token path)
   - Apple Cloud transcription (vs OpenAI)
   - `kDebugTranscriptionTiming` flag off (Phase 0 diag timers)

   Compare thermal state across combinations to find the dominant
   contributor.

3. **Gate the new `[CostTracker]` debugPrint behind `kDebugMode`** once
   we've captured the cost bug repro — it fires on every LLM call and
   we don't need it in release.

4. **Check `RNNoiseProcessor` is genuinely no-op** (BUG-006 says it's
   header-only). If somehow it's still being called and allocating
   per-buffer, that's free waste.

## Success criteria

- Session of 10 minutes streaming audio + 5 AI answers stays at thermal
  state `nominal` or `fair`, never `serious`
- Phone does not become uncomfortable to hold
- CPU stays under 30% average

## Related

- `BUG-006` RNNoiseProcessor is header-only (docs/TEST_BUG_REPORT.md) —
  should confirm it's genuinely not doing work
- `2026-04-08-hud-intermittent-factory-default-after-session-start.md` —
  may be correlated with thermal throttling
- Handoff note on `kDebugTranscriptionTiming` compile-time flag
