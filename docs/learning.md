# Learning & Technical Findings

Consolidated findings from research and development.

## BLE Integration (Even Realities G1)

### Key Findings
- G1 uses dual BLE connections (L/R glasses) via `MethodChannel('method.bluetooth')`
- No third-party BLE packages — pure native `CoreBluetooth` + Flutter platform channels
- Data sent independently to L and R via `BleManager.requestList()`
- Touchpad events arrive as `BleDeviceEvent` with `notifyIndex`:
  - 0: exit, 1: pageBack/pageForward (L/R side), 2: headUp, 3: headDown
  - 17: glassesConnectSuccess, 23: evenaiStart, 24: evenaiRecordOver
- EvenAI protocol uses multi-packet chunking (191 bytes per BLE packet) with sequence numbers

### HUD Display Protocol
- Packet header: `[cmd, syncSeq, maxSeq, seq, newScreen, pos(2B), currentPage, maxPage, ...data]`
- Screen codes: `0x01` new content, `0x30` AI streaming, `0x40` AI complete, `0x70` text page
- Text HUD: 488px max width, 21pt font, 5 lines per page
- Bitmap HUD: Full widget-based rendering via `BitmapHudService`

## Transcription Backends

### Apple Speech (Preferred)
- `SpeechStreamRecognizer.swift` with 4 backends: Apple On-Device, Apple Cloud, OpenAI Transcription, OpenAI Realtime
- Apple resets `didEmitFinalResult` on each 15-second segment restart — works reliably
- Apple Cloud is the most reliable for continuous conversation transcription

### OpenAI Transcription
- **Bug found & fixed**: `didEmitFinalResult` guard blocked ALL finals after first segment
  - OpenAI sends multiple segments per WebSocket session (different `item_id`)
  - Fix: Reset `didEmitFinalResult = false` when new partials arrive
- Stale partial detection: reconnect after 25 identical partials (~2.5s)
- `AVAudioInputNode.installTap` crashes with hardcoded 16kHz — must use hardware input format and convert
- Accumulated transcript deltas by `item_id` so streaming text grows correctly
- Shutdown `buffer too small` error is benign — suppress from user-facing display

### OpenAI Realtime Mode
- Transcription mode vs realtime conversation mode require different session setup
- Partial deltas were rendering incorrectly (replacing instead of accumulating by `item_id`)
- Realtime assistant responses must stream through chatbot response path, not wait for final chunk

## LLM Providers

- OpenAI, Anthropic, DeepSeek, Qwen, Zhipu — all use SSE streaming
- OpenAI-compatible providers share a base class (DeepSeek/Qwen/Zhipu use same format)
- Anthropic uses custom SSE parsing (`content_block_delta` events)
- Model catalog: Only keep gpt-4.1 family + realtime models (removed old gpt-4, o1, o3, o4, codex)

## Audio Pipeline
- Microphone permission deferred to first recording (was triggering at launch)
- `flutter_sound` for audio capture, native `PcmConverter` for format conversion
- RNNoise processor is header-only — noise reduction toggle currently has no effect (BUG-006)

## Bitmap HUD Hide on Head-Down + Proto L/R Coordination (2026-04-07)

**Problem:** Multiple branches attempted to fix the head-up/head-down → bitmap HUD show/hide cycle and kept regressing on each other.

### What works (confirmed on hardware 2026-04-07)

**Three changes, all on the `fix/bitmap-hud-dashboard-hide-and-display` integration branch, stacked together:**

1. **`dashboard_service.dart` — 0x18 fire-and-forget after 0x26 dashboard visibility**
   - The Even Realities SDK requires BOTH the `0x26` dashboard visibility command AND a `0x18` clear-screen command to fully empty the bitmap overlay.
   - Earlier attempts sent only `0x26`, or sent `0x26` + `pushScreen(0xF4)`. The `0xF4` variant timed out and blocked state recovery with "dashboard screen hide failed". The `0x26`-only variant left the bitmap on screen because the display buffer was never cleared.
   - The correct path is: `_bitmapHideRenderer()` sends `0x26`, then `_bitmapScreenClearRenderer()` sends `0x18` fire-and-forget (no ACK wait). The 0x18 helper is `Proto.clearBitmapScreen`.
   - Cache behavior: only invalidate the bitmap cache when handing off to text/native routes (quickAsk, notification, liveListening, textTransfer). When returning to idle/dashboard intents, preserve the cache — the glasses still hold our last uploaded frame at `0x001C0000` so the next show can delta-send with zero changed chunks for near-instant re-display.

2. **`proto.dart` — per-side screen codes, not canvas-reset flag on every page**
   - Previous behavior sent `newScreen=0x01` on every page of a multi-page response, causing the glasses to reset the canvas between pages (visible flicker).
   - Correct behavior: `0x01` fires ONLY on page index 0; pages ≥1 use `0x00`. Helpers `HudDisplayState.aiFrameForPage` and `textPageForIndex` route this properly.
   - `conversation_engine._sendToGlasses` must pass the actual `currentPageIndex + 1` as `current_page_num` instead of always reporting the last page.

3. **`proto.dart` — 400 ms inter-side delay between L and R writes**
   - When sending AI data to both glasses, inserting `Proto.evenAIInterSideDelay` (400 ms) between the L write and the R write eliminates the "R-eye-first-then-both" visual glitch.
   - Gate the delay on `leftConnected && rightConnected` — skip it if only one side is connected.

### Subtle points that tripped earlier attempts

- **Head-up/head-down are NOT wired to the hide path in `ble_manager.dart`.** Both events fall through to a log-only branch. The hide is triggered via `dashboard_service._deviceEventSub`, which subscribes to `BleManager.deviceEventStream` and calls `handleDeviceEvent`. If you grep for `headDown` in `ble_manager.dart` and see it's log-only, don't assume hide is broken — the wiring is in `dashboard_service`.

- **`BleTransportPolicy` was changed from "require both sides ACK" to "at-least-one-side success is sufficient"** because the glasses internally relay between L and R. This means tests checking `expect(result, isFalse)` for single-side failure paths are stale and must be updated.

- **`0x22` and `0xF5` event parsing were added to `ble.dart`** (battery, triple-tap, charging, dashboard open/close, head-up, right-tap). These are parsed and emitted on `statusMessageStream` but consumer wiring is diagnostic-only — no behavior change wired through them yet. The comment in the commit message was "consumer wiring lands in follow-up commits" but in practice the existing `deviceEventStream` subscription in `dashboard_service` is enough for head-down → hide to work.

### How earlier attempts regressed

- **Plan E (`feat/2026-04-06-g1-protocol-correctness`)** cherry-picked from an early checkpoint (`10905f7`) that removed the `_bitmapScreenClearRenderer()` call entirely. The idea was "just send 0x26 and nothing else". This was wrong — the 0x18 clear is what actually empties the display buffer. E's commit also explicitly said "Skip the screen-hide step entirely to avoid the timeout failure that was blocking state recovery" — but the correct fix was to keep the clear and make it fire-and-forget, not to remove it.
- Result on hardware: head-up showed HUD cleanly (E's proto fixes worked for show), but head-down did nothing (clear step was removed).

### Verified working on hardware 2026-04-07

- Phone: Art's Secret Castle, iOS 26.4
- Glasses: G1 (both sides)
- Branch: `fix/bitmap-hud-dashboard-hide-and-display` at `d0bf64a`
- Confirmed: bitmap HUD shows on head-up, hides on head-down, no factory HUD flash, no R-eye-first visible latency.

