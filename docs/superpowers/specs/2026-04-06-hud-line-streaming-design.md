# Line-by-Line HUD Streaming

**Date:** 2026-04-06
**Status:** Design spec
**Depends on Spec A (Priority Pipeline) for the prefetch and preemption hooks.**

---

## Protocol findings

The authoritative protocol reference for this project is now `docs/research/g1-ble-protocol-consolidated.md` (synthesized 2026-04-05 from 10+ open-source SDKs including the JohnRThomas EvenDemoApp wiki, `emingenc/even_glasses`, `emingenc/even_realities_g1`, `lohmuller/even-g1-java-sdk`, Even Realities' official `EvenDemoApp`, AugmentOS, `binarythinktank/eveng1_python_sdk`, `rodrigofalvarez/g1-basis-android`, `meyskens/fahrplan`). That document supersedes the ad-hoc notes below. Spec B reads §1 (UART), §2 (dual glass), and §5 (Text / AI Result `0x4E`) from the consolidated doc as source of truth.

What the consolidated doc adds beyond Spec B's original audit — all **out of scope** for this spec but worth noting so callers know where to look:

- Complete phone→glasses outgoing command map (§3), including brightness `0x01`, silent mode `0x03`, whitelist `0x04`, dashboard set `0x06`, nav `0x0A`, mic `0x0E`, BMP `0x15`/`0x16`/`0x20`, notes `0x1E`, heartbeat `0x25`, hardware `0x26`, wear `0x27`, battery query `0x2C`, notification `0x4B`/`0x4C`/`0x4F`, init `0x4D`, our `0x4E`, dashboard position `0x50`, push screen `0xF4`, clear/AI stop `0xF5`.
- Complete glasses→phone incoming map: `0x0E` mic response, `0x22` status, `0xF1` audio, `0xF5` touchpad/gesture events (full subcmd table including `0x0A` battery level, `0x09` charging, `0x1E`/`0x1F` dashboard open/close, `0x17`/`0x18` EvenAI start/stop).
- Heartbeat packet layout (§4, 6 bytes, 5 s interval, 1500 ms timeout).
- Bitmap/image protocol (§6): 576×136, 1-bit, `0x15` chunks, `0x16` CRC-32/XZ over `storageAddress+data`, `0x20 0x0D 0x0E` complete signal, 194-byte chunks, L-then-R sequential (not interleaved), 8 ms inter-chunk (iOS).
- Notification protocol `0x4B` chunking (§7), dashboard subcommand map (§8), hardware settings subcommands (§9), touchpad event table (§10), mic/audio LC3 protocol (§11), quick notes (§12), SN decoding (§13), charging case serial (§14), error handling and reconnection timeouts (§15).
- Comparison with Helix-iOS (§18): confirms our BMP framing, CRC algorithm, storage address, text header format, screen status codes, and dual-side routing all match reference implementations.

Spec B's own protocol observations (retained from 2026-04-06 independent review of the official `EvenDemoApp` and `emingenc/even_glasses`), all of which the consolidated doc also confirms:

- **No append semantics on `pos`.** Both implementations hard-code `pos = 0` in every call site. There is no evidence the firmware treats a non-zero `pos` as an append offset; its likely meaning is "highlight offset within the current page," not "insert at byte N." **Spec B does not rely on `pos != 0` append.**
- **No scroll / view-window command exists.** Pagination is 100% phone-driven by re-pushing whole pages with updated `current_page_num` / `max_page_num`.
- **The actual BLE command byte for the AI/text family is `0x4E`.** The values Helix has been calling "screen codes" (`0x30`, `0x40`, `0x70`, etc.) are actually values of the 5th header byte (`screen_status` = `ScreenAction | AIStatus`). Helix's existing code happens to work because the layout is compatible, but the spec uses correct nomenclature from here on.
- **Status byte values, complete table** (community SDK + official demo):

| Value | Meaning | Helix uses |
|---|---|---|
| `0x01` | `ScreenAction.NEW_CONTENT` | yes |
| `0x30` | `AIStatus.DISPLAYING` (auto-advance mode) | yes |
| `0x40` | `AIStatus.DISPLAY_COMPLETE` (final page of an answer) | yes |
| `0x50` | `AIStatus.MANUAL_MODE` (suppress firmware auto-advance during user paging) | **no** |
| `0x60` | `AIStatus.NETWORK_ERROR` | **no** |
| `0x70` | text mode (non-AI text page) | yes |

- **Firmware is a dumb framebuffer keyed by `current_page_num`.** No page retention. Re-push is mandatory on every advance. There is no "push the whole answer once and let the firmware paginate" path.

## Open questions (still open)

1. **Glyph advance caching is not needed.** Resolved: reuse `TextPaginator.splitIntoLines` on the unsent tail (~80 chars typical, ~160 worst case). Sub-millisecond, byte-for-byte agreement with the final-page rendering. No glyph cache, no `TextPainter.getBoxesForRange` micro-cache.
2. **Multi-codepoint graphemes (emoji, CJK combining):** does the existing paginator handle them correctly today? Line streaming must not split inside a grapheme cluster. (Unchanged from prior spec.)
3. **Fact-check correction (Spec A) — does it replace the last sentence in place, or push a new page?** Spec A says fact-check pushes via the same arbiter; if it lands as a new high-priority slot, the existing `cancel()` + new-session path handles it. If Spec A wants in-place replacement of the last line, this spec needs a "rewrite line N" operation. Spec A authors please confirm.
4. **Should Helix start sending `MANUAL_MODE 0x50` on touchpad page navigation?** Out of scope for this spec, but flag as a follow-on: today Helix may be relying on side effects of `0x30`/`0x40` for paging behavior that the official app handles via `0x50`.

---

## 1. Current behavior audit

> **Updated 2026-04-06 to reflect the in-flight partial fixes already present on the branch** (checkpoint `10905f7`). The original audit was written against an earlier snapshot and overstated the remaining win.

### Token → BLE path (as of checkpoint 10905f7)

1. LLM provider (`lib/services/llm/*`) emits delta tokens on the response stream.
2. `ConversationEngine` accumulates them in `_realtimeResponseBuffer` and runs a debounced flush loop (`_responseFlushInterval = 75ms`, `_responseFlushThreshold = 14` chars).
3. Each flush calls `_streamToGlasses(fullBufferSoFar, isStreaming: true)` → `_sendToGlasses` (`lib/services/conversation_engine.dart:2363`).
4. `_sendToGlasses` paginates the full accumulated text and takes the last page.
5. Screen status byte is now chosen via `HudDisplayState.aiFrameForPage(...)` (`lib/services/glasses_protocol.dart:16-24`):
   - Non-streaming final → `0x40` (`_aiComplete`)
   - Streaming, `pageIndex == 0` → `0x31` (`_aiShowing | _displayNewContent`)
   - Streaming, subsequent pages → `0x30` (`_aiShowing`, no new-canvas bit)
6. `current_page_num` is now the **actual** current page index + 1 (`conversation_engine.dart:2405`), not `totalPages` as it used to be.
7. `Proto.sendEvenAIData` UTF-8-encodes the full current-page text, chunks into 191-byte `0x4E` packets via `EvenaiProto.evenaiMultiPackListV2`, and sends to L, **awaits a 400 ms inter-side delay** (`lib/services/proto.dart:166-168`), then sends to R.
8. `Proto.clearBitmapScreen` (`proto.dart:406-419`) exists as a fire-and-forget `0x18` helper for tearing down without waiting on ACK.

### What the in-flight work already fixes (no longer Spec B's problem)

These items were previously listed as Spec B wins. They are now covered by the checkpoint diff and Spec B does not need to touch them:

- **Per-page screen-status byte.** `aiFrameForPage` now returns `0x31` only for the first page and `0x30` for continuation, instead of the old unconditional `0x31`. Final frame uses `0x40` as a clean completion sentinel.
- **Correct `current_page_num`.** Previously always equal to `totalPages` (so the firmware always thought it was on the last page). Now tracks the actual streaming page.
- **400 ms inter-side text delay.** Previously absent; now present in `sendEvenAIData`. This is what the consolidated doc §2 and §5 require.
- **HUD state bookkeeping.** `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex` now exist on `ConversationEngine` (`conversation_engine.dart:98-100`) and gate the first-frame / page-boundary decisions.

### What is STILL wasted (the remaining Spec B win)

- **Flush trigger is still per-token, not per-line.** The `_responseFlushInterval = 75ms` / `_responseFlushThreshold = 14 chars` debounce means ~13 flushes/sec during active streaming. With L→R serialization capped near 2 Hz by the 400 ms inter-side delay, most of those flushes are silently coalesced by latency and wasted on the radio. **This is the load-bearing Spec B win.**
- **Streaming HUD state lives on `ConversationEngine`.** Three fields (`_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex`) and the branching logic in `_sendToGlasses` (`conversation_engine.dart:2363-2411`) should move to a dedicated owned class with a clear lifecycle. The engine is already ~3000 LOC and should not be growing per-stream ephemeral state inline.
- **No test coverage for the streaming path.** There is currently no unit test that asserts the sequence of screen-status bytes / page indices / payloads that a multi-line streaming response produces. A drift here is invisible until someone sees flicker on hardware.

### Exact code path that needs to change

- `ConversationEngine._sendToGlasses` (`conversation_engine.dart:2363-2411`): replace the token-rate flush gating with line-boundary gating (see §3).
- `ConversationEngine._realtimeResponseBuffer` flush loop (see usages of `_streamToGlasses` around `conversation_engine.dart:692, 959, 1986, 2078`): stop calling on `_responseFlushThreshold`/`_responseFlushInterval` and delegate to the new `HudStreamSession.appendDelta`.
- `Proto.sendEvenAIData` (`proto.dart:121-196`): **unchanged in wire format.** Spec B deliberately does not change a single byte in `sendEvenAIData`. The win is purely flush-rate reduction.
- The streaming HUD state fields on `ConversationEngine` (`conversation_engine.dart:98-100`) get absorbed into `HudStreamSession` and removed from the engine (see §4 and §10, "Coexistence with in-flight work").

---

## 2. Locked decision

Stream **one visual line at a time**. A "line" is the chunk of text that fills one wrapped row at the HUD's 488 px / 21 pt rendering. Tokens accumulate in a buffer; the buffer is only flushed to BLE when it has produced **at least one completed visual line** that has not yet been sent.

**The win is flush-rate reduction, not byte-payload reduction.** Per the protocol findings above, the firmware does not support partial-page append, so each flush still re-pushes the full current-page text via cmd `0x4E` + `screen_status = 0x01 | 0x30`. What changes versus today is that flushes now happen on line completion (~2/sec for typical streaming) instead of on the 14-char/75ms threshold (~13/sec). That is a **6-7× reduction in BLE writes** with identical per-write payload size.

This matches what L/R serialization with 400 ms inter-side gap can actually drain — today's higher flush rate is silently coalesced by latency, so reducing it costs nothing in perceived UX and frees radio time for other BLE traffic.

This applies to the normal LLM stream, to Spec A prefetched answers (which arrive pre-rendered and are flushed line-at-a-time on activation), and to Spec A fact-check corrections.

---

## 3. Line-detection algorithm

### Recommendation: reuse `TextPaginator.splitIntoLines` on the unsent tail

`TextPaginator.splitIntoLines(text)` (`text_paginator.dart:100-126`) already does pixel-accurate, word-boundary wrapping at 488 px / 21 pt with `TextPainter`. It is the source of truth and we must not diverge from it (drift between line-streaming and final-page rendering would cause visible re-flow on the last frame).

We do **not** need glyph-advance caching as a first cut. Instead:

1. Maintain `String _committedText` — everything that has already been sent as completed lines on the current page.
2. Maintain `String _pendingTail` — tokens received since the last flush.
3. On each token arrival, compute `candidate = _committedLastLineRemainder + _pendingTail` (the "active line" being filled). This is small — at most ~80 chars.
4. Run `splitIntoLines(candidate)`. If the result has **2 or more lines**, every line except the last is now complete and ready to send. The last line is the new in-progress line; keep it in `_pendingTail`.
5. Move completed lines into `_committedText` and emit them as one BLE write.

Cost: one `TextPainter.layout` per token over a ~80-char string. This is bounded and far cheaper than re-paginating the entire response. If profiling later shows cost, add a per-character advance cache keyed by `(codepoint, fontSize)` and short-circuit `_measureTextWidth` for ASCII runs — that is a follow-up, not a v1 requirement.

### Why not a running width counter

A naive "sum glyph advances" counter cannot reproduce `TextPainter`'s word-break decisions (it would split mid-word, or fail on kerning / ligatures / CJK). The paginator-on-the-tail approach guarantees byte-for-byte agreement with the final page render.

---

## 4. State machine — `HudStreamSession`

A new class in `lib/services/hud_stream_session.dart`. **Not** more state on `ConversationEngine`. One instance per active response stream; replaced (and `dispose()`-d) when a new response begins or Spec A preempts.

```dart
class HudStreamSession {
  HudStreamSession({required this.sink});
  final HudPacketSink sink; // injected — see §8 testing

  // Per-page state
  int _pageIndex = 0;            // 0-based current page
  final List<String> _lines = []; // committed lines on current page (max 5)
  String _pendingTail = '';      // unsent in-progress line

  // Per-stream state
  bool _firstFrameSent = false;

  // NOTE: no `_pageByteLength` field. The in-flight checkpoint still tracks
  // it on ConversationEngine for the legacy append-offset path, but
  // HudStreamSession uses `pos = 0` for every emit per the consolidated
  // protocol doc (`docs/research/g1-ble-protocol-consolidated.md` §5), so the
  // byte-length counter has no purpose here and is deliberately omitted.

  Future<void> appendDelta(String delta);   // called per LLM token
  Future<void> finish();                    // flush partial tail, send 0x40
  Future<void> cancel();                    // Spec A preemption — drop buffer, no final
}
```

Behavior:

- `appendDelta` updates `_pendingTail`, runs the paginator-on-tail check (§3), promotes any completed lines into `_lines`, and calls `_emit(...)` once per "batch of newly committed lines."
- `_emit` always sends the **full current-page text** via cmd `0x4E`, `pos = 0`. The status byte distinguishes the cases:
  - **First frame on page** → `screen_status = 0x01 | 0x30` (`NEW_CONTENT | DISPLAYING`), payload = joined committed lines + pending tail.
  - **Subsequent same-page** → `screen_status = 0x30`, payload = joined committed lines + pending tail (the entire current page so far). Identical to today's behavior except gated on line completion, not per-token.
  - **Page just filled** → emit the now-full page once with `0x01 | 0x30`, advance `_pageIndex++`, reset `_lines`, send the next page's first frame with whatever lives in `_pendingTail` (typically empty).
- `finish()` flushes any non-empty `_pendingTail` once more (full current page), then sends a single frame with `screen_status = 0x40` (`DISPLAY_COMPLETE`) containing the full final page — the firmware needs the complete sentinel.
- `cancel()` is called by Spec A's preemption hook. It tears down state without sending `0x40`; the new `HudStreamSession` for the replacement response will issue a `0x01 | 0x30` first frame which the firmware treats as a fresh canvas.

The `_pageByteLength` field is removed from the state — it was only useful for the dead append-offset path.

---

## 5. Packet protocol — corrected nomenclature

### What `glasses_protocol.dart` actually defines

`HudDisplayState` (`lib/services/glasses_protocol.dart:5-34`) encodes the `screen_status` byte (`0x01`, `0x30`, `0x40`, `0x70`) and now exposes `aiFrameForPage(...)` and `textPageForIndex(pageIndex)` helpers that differentiate the first page from continuation pages (the in-flight checkpoint added these). Helix's existing code previously called these values "screen codes," but per the protocol findings and confirmed by multiple independent sources in `docs/research/g1-ble-protocol-consolidated.md` §5, the **actual BLE command byte is `0x4E`** for the entire AI/text family — `0x30`/`0x40`/`0x70` are values of the 5th header byte (`screen_status`), not separate commands. The framing lives in `EvenaiProto.evenaiMultiPackListV2`.

Exact 9-byte header layout per the consolidated doc §5:

```
Offset  Size  Field           Description
------  ----  -----           -----------
0       1     command         0x4E (SEND_RESULT)
1       1     syncSeq         Sequence number (shared across packets in one message)
2       1     maxSeq          Total number of multi-packet chunks
3       1     seq             Current chunk index (0-based)
4       1     newScreen       screen_status (4-bit display style | 4-bit canvas state)
5       2     pos             new_char_pos (big-endian int16)
7       1     currentPage     Current page number
8       1     maxPages        Total page count
9+      N     data            UTF-8 payload (max 191 bytes per packet)
```

The consolidated doc confirms with multiple independent sources (JohnRThomas wiki, `emingenc/even_glasses`, official EvenDemoApp, Python SDK, Java SDK) that:

- **`cmd = 0x4E`** for the entire AI/text family. `0x30`/`0x40`/`0x70` are `screen_status` values, not commands.
- **`new_char_pos = 0`** in every reference call site. Its documented purpose is a highlight/animation offset for freshly arrived text, **not** an append offset into a server-side buffer. The firmware is a dumb framebuffer keyed by `current_page_num`; there is no append semantic.

Spec B uses the same constant `pos = 0` everywhere and does not rely on any interpretation of `new_char_pos` beyond "ignored by firmware."

### What changes in `Proto.sendEvenAIData`

**Nothing in the wire format.** No new parameter, no new screen code. The existing `text` argument and `pos = 0` semantics are kept.

What changes is the **flush trigger** in `ConversationEngine._streamToGlasses` (and the new `HudStreamSession` that owns it): instead of calling `_sendToGlasses` on every 14-char/75ms tick, call it only when the unsent token tail has produced at least one new completed visual line. The payload is still the full current-page text. The win is purely flush-rate reduction.

A future spec may revisit `screen_status = 0x50 MANUAL_MODE` for touchpad paging and `screen_status = 0x60 NETWORK_ERROR` for provider failures — neither is in scope here.

### Packet layout (illustrative only)

```
0x4E | syncSeq | maxSeq | seq | 0x01|0x30 | 0 | 0 | curPage | maxPage | <full current page bytes>
```

A 5-line page at ~60 chars/line is ~300 bytes → 2 packets at 191 bytes/packet, fragmented and reassembled by `evenaiMultiPackListV2` as today.

---

## 6. Page boundary handling

When the line that just completed is line 5 of the current page:

1. Emit the full page-N text once with `screen_status = 0x01 | 0x30` (so the user sees the page fill).
2. Immediately afterward, issue a fresh `0x01 | 0x30` frame for page N+1 with `current_page_num = N+1`, `max_page_num` updated, payload = whatever is currently in `_pendingTail` (typically empty; if mid-token-burst, may already contain the start of line 1 of the new page).
3. Reset `_lines`, increment `_pageIndex`.

We do not pre-emptively flip the page before line 5 is visible. The user should see "...line 5" complete on page N before the firmware swaps canvases.

For multi-page final answers, the existing touchpad pagination still works because the final `0x40` frame and the `current_page_num` / `max_page_num` header are unchanged.

---

## 7. Edge cases

| Case | Handling |
|---|---|
| Stream ends mid-line (no newline trigger) | `finish()` flushes `_pendingTail` once with the full current page (`0x01 | 0x30`), then sends `0x40` with the same full final page. |
| Stream cancelled mid-line (Spec A preemption) | `cancel()` drops `_pendingTail`, does not send `0x40`. The new session's first `0x01 | 0x30` frame overwrites the canvas. |
| Single token wider than 488 px (very long URL, no spaces) | `splitIntoLines` already breaks on word boundaries only — a single oversize "word" becomes one line that exceeds the width. **Acceptance:** v1 lets it overflow visually, matching today. Follow-up: hard-break long unbroken runs at the byte level. Tracked as a known limitation, not a blocker. |
| Token contains a literal `\n` | Treat `\n` as a forced line break: split `_pendingTail` at the newline, promote the left side as a completed line immediately (even if narrower than 488 px). |
| Empty delta | No-op. |
| Final frame coincides with a page boundary | Send the page's last `0x01 | 0x30`, then `0x40` for that same page. Do not advance to a phantom empty page N+1. |
| Final answer is exactly empty | Send `0x40` with empty body so the HUD knows the response completed. |
| Backend retransmits / duplicates a token | Idempotency is the LLM provider's job. `HudStreamSession` trusts its input. |

---

## 8. Backpressure

BLE write throughput on G1 is the binding constraint: serialized L-then-R with a 400ms inter-side delay caps us near 2 Hz. The line-streaming approach naturally gates flush rate to "once per completed line," which for a 21 pt / 488 px row is roughly every 6–10 tokens — a comfortable match for the BLE budget.

Still, if the LLM produces lines faster than BLE drains:

1. `HudStreamSession.appendDelta` is `async` and awaits the previous emit's `Future` before issuing the next. Tokens continue to accumulate in `_pendingTail` and `_lines` while the wire is busy.
2. **Coalescing rule:** if multiple lines complete during one in-flight emit, the next emit just sends the full current-page text — which now includes all the newly completed lines. No special "batch lines into one packet" logic needed; the protocol is already whole-page.
3. **No dropping.** Every emit must reach the glasses; the firmware is a dumb framebuffer and the next emit is the source of truth for the canvas.
4. If the wire is so slow that the entire response finishes before the first page is fully sent, `finish()` waits on the in-flight emit and then sends the final `0x40` frame. Worst case: user sees an instant final page rather than a stream — degraded UX, not a bug.

A `Completer`-based single-slot queue inside `HudStreamSession` is sufficient. No external queue manager.

---

## 9. Testing strategy

No hardware required. Inject a `HudPacketSink` interface into `HudStreamSession`:

```dart
abstract class HudPacketSink {
  Future<void> send({
    required int screenStatus, // 0x01|0x30, 0x30, 0x40, etc.
    required int pageIndex,
    required int totalPages,
    required String pageText,
  });
}
```

Production binding wraps `Proto.sendEvenAIData`. Tests use `RecordingHudPacketSink` which appends each call to a list. Assertions:

1. **Flush rate:** streaming a 3-line response produces exactly 3 streaming emits + 1 final `0x40` (4 total), regardless of token count.
2. **Page text monotonic growth:** within a page, each successive emit's `pageText` is a strict prefix-extension of the previous (no rewrites, no truncation).
3. **Final page agreement:** the last streaming emit's `pageText` equals `TextPaginator.instance.paginateText(input).last` for that page (drift guard).
4. **Page boundary:** streaming 7 lines produces 5 emits on page 0 (the last with `0x01 | 0x30` containing the full 5-line page), then 2 more emits on page 1, then `0x40`.
5. **Cancel mid-stream:** `cancel()` results in zero further emits, no `0x40`.
6. **Long token:** an unbroken 100-char token produces one (oversized) line emit and does not loop.
7. **Backpressure:** sink configured to await a manual `Completer` — feed 30 tokens fast, verify no lost lines and that coalesced emits still send the full current page.

Tests live in `test/services/hud_stream_session_test.dart`. No changes to the `lib/services/conversation_engine.dart` test surface beyond replacing `_glassesSender` injection with a `HudStreamSession` factory.

---

## 10. Coexistence with in-flight work

Checkpoint `10905f7` on the current branch has already landed several fixes that this spec's original draft proposed as part of Spec B:

- `HudDisplayState.aiFrameForPage` and `HudDisplayState.textPageForIndex` (per-page screen-status selection).
- `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex` fields on `ConversationEngine` (`conversation_engine.dart:98-100`).
- Correct `current_page_num` propagation in `_sendToGlasses`.
- 400 ms inter-side delay in `Proto.sendEvenAIData`.
- `Proto.clearBitmapScreen` fire-and-forget helper.

Spec B's migration strategy is therefore **absorb and clean up the existing fields into `HudStreamSession`**, not "introduce new state alongside the old state." Concretely:

1. Build `HudStreamSession` + `HudPacketSink` and its unit suite first (no behavior change; `_sendToGlasses` still runs).
2. Replace `ConversationEngine`'s per-token flush callers (`_streamToGlasses` usages at `conversation_engine.dart:692, 959, 1986, 2078`) with `HudStreamSession.appendDelta` / `finish` / `cancel`, behind the `SettingsManager` flag.
3. Once the flag flips, the three fields at `conversation_engine.dart:98-100` become dead code and are deleted. Their responsibilities move entirely into `HudStreamSession._firstFrameSent`, `_pageIndex`, and `_lines`.
4. `_sendToGlasses` stays as a fallback path for the text-HUD (non-AI) writes and for `HudStreamSession`'s `_emit` implementation of the `HudPacketSink` (it is the production binding that wraps `Proto.sendEvenAIData`).
5. `aiFrameForPage` / `textPageForIndex` are **kept and reused** by `HudStreamSession._emit`. The spec's original "introduce new screen-code helpers" note is obsolete — those helpers already exist and are correct.

The wire format does not change. The only risk is logical (page boundary accounting in `HudStreamSession`), and that is covered by the unit suite in §9.

---

## 11. Migration notes

1. Land `HudStreamSession` and `HudPacketSink` with full unit coverage. Keep `_sendToGlasses` as-is; the new class calls into it via the production `HudPacketSink` binding.
2. Behind a `SettingsManager.flag('hud.lineStreaming', default: false)` gate, route streaming responses through `HudStreamSession.appendDelta/finish/cancel` instead of the old per-token flush loop. Final-frame, text-HUD, and auto-answer UI path stay on the existing code.
3. Hardware QA on a real G1 pair: verify the line-gated cadence visibly improves streaming feel and reduces flicker. No protocol risk to validate — wire format is unchanged from today.
4. Flip the flag default to `true` after one release.
5. Remove `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex` from `ConversationEngine` (`conversation_engine.dart:98-100`) and delete the branching in `_sendToGlasses` that references them; the text-HUD path keeps the simpler non-streaming branch.
