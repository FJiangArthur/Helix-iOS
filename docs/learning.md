# Technical Findings

Durable notes on BLE, transcription, audio, and LLM providers. Short-
term findings live in `.planning/todos/` and in commit messages.

## G1 BLE

- Dual BLE connections (L/R) via `MethodChannel('method.bluetooth')`.
  Pure native CoreBluetooth + platform channels; no 3rd-party BLE pkg.
- Touchpad events via `notifyIndex`:
  `0=exit, 1=pageBack/Forward, 2=headUp, 3=headDown, 17=connected,
  23=evenaiStart, 24=evenaiRecordOver`
- EvenAI protocol: multi-packet, 191 bytes/packet, sequence numbers.
- Packet header layout + `screen_status` values: see **CLAUDE.md** →
  "BLE & HUD Protocol" (authoritative). See `docs/research/` for the
  consolidated open-source protocol reference.
- **`new_char_pos` is not an append offset** — hard-coded `0` in every
  reference SDK. Pagination is phone-driven: re-push whole page with
  updated `current_page_num`. Append-at-pos semantics caused the
  left-eye "listening" bug (reverted in `ddaab66`).
- Full-canvas only. No scroll command.

## HUD rendering

- Text HUD: 488px width, 21pt font, 5 lines per page.
- Bitmap HUD (default): widget-based, full render via
  `BitmapHudService`. Physical display is 576x136 per lens.
- L/R coordination: 400 ms inter-side delay between writes eliminates
  "R-first then both" visual glitch. Gate on both-sides-connected.
- Dashboard hide requires BOTH `0x26` visibility AND `0x18` clear-
  screen (fire-and-forget, no ACK wait). `0xF4` path times out.

## Transcription

- **Apple Cloud** is the most reliable backend for continuous
  conversation transcription.
- OpenAI `didEmitFinalResult` guard bug: blocked ALL finals after the
  first segment on multi-segment WS sessions. Fix: reset on new
  partials.
- `AVAudioInputNode.installTap` with hardcoded 16kHz crashes — must
  use hardware input format and convert.
- Stale partial detection: reconnect after 25 identical partials
  (~2.5s).
- Shutdown `buffer too small` error is benign — suppress from UI.
- OpenAI Realtime: accumulate transcript deltas by `item_id`, route
  assistant responses through chatbot response path.

## LLM providers

- OpenAI, Anthropic, DeepSeek, Qwen, Zhipu — all SSE streaming.
- OpenAI-compatible (DeepSeek/Qwen/Zhipu) share
  `OpenAiCompatibleProvider` base class.
- Anthropic uses custom SSE parsing (`content_block_delta` events).
- Model filter: only gpt-4.1 / gpt-5.4 family + realtime kept; legacy
  models removed.

## Audio

- Mic permission deferred to first recording (was triggering at
  launch).
- `flutter_sound` capture + native `PcmConverter` format conversion.
- `RNNoiseProcessor` is header-only (BUG-006) — noise reduction
  toggle is a no-op.
