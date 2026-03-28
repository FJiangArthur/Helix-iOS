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
