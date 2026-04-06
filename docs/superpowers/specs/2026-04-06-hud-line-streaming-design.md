# Line-by-Line HUD Streaming

**Date:** 2026-04-06
**Status:** Design spec
**Depends on Spec A (Priority Pipeline) for the prefetch and preemption hooks.**

---

## Protocol findings (2026-04-06 research, resolves prior open questions 1 & 2)

Two independent reference implementations — Even Realities' official `EvenDemoApp` (Flutter) and the community `emingenc/even_glasses` (Python) — were inspected. Verdicts (high confidence):

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

### Token → BLE path

1. LLM provider (`lib/services/llm/*`) emits delta tokens on the response stream.
2. `ConversationEngine` accumulates them in `_realtimeResponseBuffer` and runs a debounced flush loop (`_responseFlushInterval = 75ms`, `_responseFlushThreshold = 14` chars). See `conversation_engine.dart:84-85, 1994, 2136`.
3. Each flush calls `_streamToGlasses(fullBufferSoFar, isStreaming: true)` → `_sendToGlasses` (`conversation_engine.dart:2363`).
4. `_sendToGlasses` re-paginates the **entire** accumulated text via `TextPaginator.instance.paginateText(text)` and grabs the **last** page (`currentPageText`).
5. It then picks a screen code:
   - first frame or page change → `0x31` (new canvas), `pos = 0`
   - same page subsequent flush → `0x30`, `pos = _lastStreamedByteLength` (UTF-8 byte offset of previously sent content)
6. It calls `Proto.sendEvenAIData(pageText, newScreen: …, pos: …)` (`proto.dart:121`).
7. `sendEvenAIData` UTF-8-encodes **the full `pageText`** and chunks it into 191-byte packets via `EvenaiProto.evenaiMultiPackListV2`. The same packet stream is then sent to L and R sides serially with a 400ms gap.
8. Streaming complete → one final call with `0x40`.

### What is wasted

- **`pageText` always contains every byte of the current page.** Even though `pos` advertises the offset of "new content," the wire payload still carries bytes `[0..pos)`. The intent of incremental streaming is correct on paper but is not reflected in the bytes leaving the phone.
- Re-pagination on every flush re-runs `TextPainter.layout()` over the entire accumulated response. Cheap individually, expensive at 13 flushes/sec across a multi-paragraph answer.
- L and R writes are serialized with a 400ms inter-side delay, so the effective HUD frame rate is bounded near ~2 Hz regardless of how often we flush. Any flush we issue beyond that rate is silently coalesced by latency.
- Each flush causes the glasses firmware to re-render the same prefix bytes it already has, which is observed (and the original motivation for this spec) as flicker / wasted radio time.

### Exact code path that needs to change

- `ConversationEngine._sendToGlasses` (`conversation_engine.dart:2363-2411`)
- `Proto.sendEvenAIData` (`proto.dart:121-196`) — must accept either a full page payload (legacy) or a "tail bytes only" payload (new) and pass the right slice to `evenaiMultiPackListV2`.
- The streaming HUD state on `ConversationEngine` (lines 98-100) gets pulled out into a dedicated class (see §4).

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
  int _pageByteLength = 0;       // running utf8 byte length of joined committed lines + '\n's

  // Per-stream state
  bool _firstFrameSent = false;

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

`HudDisplayState` encodes the `screen_status` byte (`0x01`, `0x30`, `0x40`, `0x70`) plus the `aiFrameForPage` helper. Helix's existing code calls these "screen codes" but per the protocol findings above, the **actual BLE command byte is `0x4E`** for the entire AI/text family — `0x30`/`0x40`/`0x70` are values of the 5th header byte (`screen_status`), not separate commands. The framing lives in `EvenaiProto.evenaiMultiPackListV2`. Header layout:

```
[0x4E, syncSeq, maxSeq, seq, screen_status, new_char_pos_hi, new_char_pos_lo, currentPage, maxPage, ...data]
```

The `new_char_pos` field's documented purpose (per `even_glasses/models.py`) is "new character position" — likely a highlight offset for the firmware to animate freshly arrived text. **It is not an append offset.** Both the official demo and the community SDK hard-code it to 0 in every call site.

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

## 10. Migration notes

1. Land `HudStreamSession` and `HudPacketSink` with full unit coverage. Keep `_sendToGlasses` as-is.
2. Behind a `SettingsManager.flag('hud.lineStreaming', default: false)` gate, route streaming responses through `HudStreamSession` instead of the old per-token flush loop. Final-frame and text-HUD path stay on `_sendToGlasses`.
3. Hardware QA on a real G1 pair: verify the line-gated cadence visibly improves streaming feel and reduces flicker. No protocol risk to validate — wire format is unchanged from today.
4. Flip the flag default to `true` after one release.
5. Remove `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex` from `ConversationEngine`.
