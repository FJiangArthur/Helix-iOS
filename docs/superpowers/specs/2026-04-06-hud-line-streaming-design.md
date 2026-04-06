# Line-by-Line HUD Streaming

**Date:** 2026-04-06
**Status:** Design spec
**Depends on Spec A (Priority Pipeline) for the prefetch and preemption hooks.**

---

## Open questions

1. **Does the G1 firmware actually honor a non-zero `pos` as an append offset on screen code `0x30`, or does it still treat the body as a full canvas replacement?** Today's code sets `pos` but still passes the entire `pageText` through `Proto.sendEvenAIData`, so the wire payload grows every flush. We need a hardware test (or vendor confirmation) before committing to "ship only the new line bytes." If firmware ignores `pos` and always overwrites, the win is purely BLE-byte savings on smaller payloads, not a true incremental append.
2. **Is there a dedicated "append" subcode** in the EvenAI command space (0x4E family) beyond 0x30/0x31/0x40/0x70? Vendor protocol docs are not in-tree.
3. **Glyph advance caching:** does Flutter's `TextPainter` expose per-glyph advances cheaply, or do we need a measurement micro-cache keyed by character?
4. **Multi-codepoint graphemes (emoji, CJK combining):** does the existing paginator handle them correctly today? Line streaming must not split inside a grapheme cluster.
5. **Fact-check correction (Spec A) — does it replace the last sentence in place, or push a new page?** That decision changes whether line streaming needs a "rewrite line N" operation in addition to "append line N+1."

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

Stream **one visual line at a time**. A "line" is the chunk of text that fills one wrapped row at the HUD's 488 px / 21 pt rendering. Tokens accumulate in a buffer; the buffer is only flushed to BLE when it has produced **at least one completed visual line** that has not yet been sent. The flushed payload is the new line(s) only — not the full page. Page transitions are handled via the existing 0x31 "new canvas" code; intra-page line additions use 0x30 with `pos` set to the running byte offset.

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
- `_emit` decides between:
  - **First frame on page** → 0x31 (new canvas), `pos = 0`, payload = the new lines joined by `\n`.
  - **Subsequent same-page** → 0x30, `pos = _pageByteLength` (the offset *before* appending), payload = only the newly committed lines (prefixed with `\n` if `_lines` was non-empty before this batch).
  - **Page just filled** → after emitting the line that completed line 5, advance `_pageIndex++`, reset `_lines`, `_pageByteLength`, send 0x31 for the next page with whatever already lives in `_pendingTail` (if non-empty, which is rare — usually nothing).
- `finish()` flushes any non-empty `_pendingTail` as a final partial-line append on the current page, then sends a single 0x40 frame with the page text (the firmware needs the "complete" sentinel; payload can be empty body if append model holds, otherwise full final page — see Open Question 1).
- `cancel()` is called by Spec A's preemption hook. It tears down state without sending 0x40; the new `HudStreamSession` for the replacement response will issue 0x31 and overwrite the canvas naturally.

---

## 5. Incremental packet protocol

### What `glasses_protocol.dart` actually defines

`HudDisplayState` only encodes the *screen code byte* (0x01 / 0x30 / 0x40 / 0x70 plus `aiFrameForPage` helper). The actual multi-packet framing lives in `EvenaiProto.evenaiMultiPackListV2` (called from `Proto.sendEvenAIData`). The header per CLAUDE.md is:

```
[cmd, syncSeq, maxSeq, seq, newScreen, pos_lo, pos_hi, currentPage, maxPage, ...data]
```

`pos` is already wired through. **No new screen code is required** for line streaming — 0x30 + non-zero `pos` is the existing "append at offset" affordance. What we are actually changing is the **payload semantics**: today `data` carries the full page; tomorrow `data` carries only the bytes from `pos` to end-of-current-page-so-far.

### Required change to `Proto.sendEvenAIData`

Add an optional named parameter `Uint8List? appendBytes`. When provided, it bypasses `utf8.encode(text)` and ships exactly those bytes as the body. `text` is still passed for logging. Old call sites (final-page, text-mode HUD) are unchanged.

Pending Open Question 1: if the firmware ignores `pos` and always treats body as full-canvas, we fall back to "send the smallest legal payload" — which means still sending the full page text per flush, and the win is reduced to "fewer flushes per response" (one per completed line, not one per 14 chars). That alone is still a significant BLE-radio win.

### Packet layout (illustrative only)

```
0x4E | syncSeq | maxSeq | seq | 0x30 | pos_lo | pos_hi | curPage | maxPage | <new line bytes incl. leading '\n'>
```

For a typical 60-char line, this fits in a single 191-byte packet — no fragmentation, single ACK round-trip per side.

---

## 6. Page boundary handling

When the line that just completed is line 5 of the current page:

1. Emit the 0x30 append for that 5th line on page N (so the user sees the page fill).
2. Immediately afterward, issue a 0x31 "new canvas" frame for page N+1 with payload = whatever is currently in `_pendingTail` (typically empty; if mid-token-burst, may already contain the start of line 1 of the new page).
3. Reset `_lines`, `_pageByteLength`, increment `_pageIndex`, set `_firstFrameSent = false` (because the 0x31 we just issued counts as "first frame on this new page" — actually set it `true` after emit).

We do not pre-emptively flip the page before line 5 is visible. The user should see "...line 5" complete on page N before the firmware swaps canvases.

For multi-page final answers, the existing touchpad pagination still works because the final 0x40 frame and the `current_page_num`/`max_page_num` header are unchanged.

---

## 7. Edge cases

| Case | Handling |
|---|---|
| Stream ends mid-line (no newline trigger) | `finish()` flushes `_pendingTail` as a 0x30 append on the current page, then sends 0x40. |
| Stream cancelled mid-line (Spec A preemption) | `cancel()` drops `_pendingTail`, does not send 0x40. The new session's first 0x31 overwrites. |
| Single token wider than 488 px (very long URL, no spaces) | `splitIntoLines` already breaks on word boundaries only — a single oversize "word" becomes one line that exceeds the width. **Acceptance:** v1 lets it overflow visually, matching today. Follow-up: hard-break long unbroken runs at the byte level. Tracked as a known limitation, not a blocker. |
| Token contains a literal `\n` | Treat `\n` as a forced line break: split `_pendingTail` at the newline, promote the left side as a completed line immediately (even if narrower than 488 px). |
| Empty delta | No-op. |
| Final frame coincides with a page boundary | Send the page's last 0x30, then 0x40 for that same page. Do not advance to a phantom empty page N+1. |
| Final answer is exactly empty | Send 0x40 with empty body so the HUD knows the response completed. |
| Backend retransmits / duplicates a token | Idempotency is the LLM provider's job. `HudStreamSession` trusts its input. |

---

## 8. Backpressure

BLE write throughput on G1 is the binding constraint: serialized L-then-R with a 400ms inter-side delay caps us near 2 Hz. The line-streaming approach naturally gates flush rate to "once per completed line," which for a 21 pt / 488 px row is roughly every 6–10 tokens — a comfortable match for the BLE budget.

Still, if the LLM produces lines faster than BLE drains:

1. `HudStreamSession.appendDelta` is `async` and awaits the previous emit's `Future` before issuing the next. Tokens continue to accumulate in `_pendingTail` and `_lines` while the wire is busy.
2. **Coalescing rule:** if `_lines` has 2+ uncommitted-to-wire entries when the wire frees up, emit them in a single 0x30 packet (still smaller than the full page). This means slow BLE → fewer, fatter frames; fast BLE → one frame per line.
3. **No dropping.** Every committed line must reach the glasses; partial loss would desync the `pos` offset and corrupt the canvas.
4. If the wire is so slow that the entire response finishes before the first page is fully sent, `finish()` waits on the in-flight emit and then sends 0x40. Worst case: user sees an instant final page rather than a stream — degraded UX, not a bug.

A `Completer`-based single-slot queue inside `HudStreamSession` is sufficient. No external queue manager.

---

## 9. Testing strategy

No hardware required. Inject a `HudPacketSink` interface into `HudStreamSession`:

```dart
abstract class HudPacketSink {
  Future<void> send({
    required int screenCode,
    required int pos,
    required int pageIndex,
    required int totalPages,
    required Uint8List body,
    required String debugText,
  });
}
```

Production binding wraps `Proto.sendEvenAIData`. Tests use `RecordingHudPacketSink` which appends each call to a list. Assertions:

1. **Packet count:** streaming a 3-line response produces exactly 3 same-page emits + 1 final 0x40 (4 total), not N-tokens emits.
2. **Incremental content:** for each 0x30 emit, `pos` equals the cumulative byte length of all previously emitted bodies on this page.
3. **No prefix re-send:** concatenating all bodies on a page reproduces the final page text exactly, with no duplicated bytes.
4. **Page boundary:** streaming 7 lines produces 5 emits on page 0, a 0x31 on page 1, then 2 more 0x30 emits on page 1.
5. **Cancel mid-stream:** `cancel()` results in zero further emits, no 0x40.
6. **Wire-agreement:** for a fixed input, the final accumulated page text from line streaming equals `TextPaginator.instance.paginateText(input)` page-by-page (drift guard).
7. **Long token:** an unbroken 100-char token produces one (oversized) line emit and does not loop.
8. **Backpressure:** sink configured to await a manual `Completer` — feed 30 tokens fast, verify no dropped lines, verify coalescing into fewer-than-30 emits.

Tests live in `test/services/hud_stream_session_test.dart`. No changes to the `lib/services/conversation_engine.dart` test surface beyond replacing `_glassesSender` injection with a `HudStreamSession` factory.

---

## 10. Migration notes

1. Land `HudStreamSession` and `HudPacketSink` with full unit coverage. Keep `_sendToGlasses` as-is.
2. Add an `appendBytes` parameter to `Proto.sendEvenAIData`. Existing callers unaffected.
3. Behind a `SettingsManager.flag('hud.lineStreaming', default: false)` gate, route streaming responses through `HudStreamSession` instead of the old flush loop. Final-frame and text-HUD path stay on `_sendToGlasses`.
4. Hardware QA on a real G1 pair: confirm `pos`+append actually appends. If yes, ship enabled. If no, fall back to "fewer flushes, full page bodies" mode (keep the line-completion gating, drop the `appendBytes` optimization) and document Open Question 1 as resolved-negative.
5. Remove `_lastStreamedByteLength`, `_isFirstStreamFrame`, `_lastStreamedPageIndex` from `ConversationEngine` once the flag is on by default for one release.
