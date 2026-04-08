---
created: 2026-04-08T00:00:00.000Z
title: Tier-0 — Line-by-line HUD streaming to fix scroll artifacts
area: hud
status: pending
priority: tier-0
files:
  - lib/services/conversation_engine.dart
  - lib/services/hud_stream_session.dart
  - lib/services/proto.dart
---

## Problem

**Priority:** Tier-0 — ship-blocking. Fix before anything else.

During AI answer streaming on the glasses HUD, the scroll behavior
produces visible artifacts: partial words, half-flushed lines, and
content that appears/disappears as the streaming buffer grows. This is
distinct from the left-eye "Even AI Listening" flash (tracked in
`2026-04-08-evenai-listening-flash-brief-during-streaming.md`) and
from the home-screen scroll snap
(`2026-04-08-homescreen-scroll-snap-on-long-streaming-answer.md`) —
this TODO is specifically about **what gets sent to the glasses during
streaming and how often**.

## Root cause (hypothesized)

The current streaming path in `_sendToGlasses` (post-`ddaab66` revert)
sends the **full current canvas** on every flush, with `pos: 0` and
`screen_status` set based on streaming state. The flush cadence is
controlled by `_responseFlushInterval` (in `conversation_engine.dart`)
and by token arrival — so mid-word, mid-line, partial content can be
pushed to the glasses, visible briefly, then replaced by the next
frame. The firmware renders each frame immediately.

Plan B's `HudStreamSession` (now default ON as of `762b005`) was
supposed to gate emission on **visual line boundaries** instead of
token boundaries. But the hardware report says scroll artifacts are
still visible. Possibilities:

1. **HudStreamSession is not actually routing** — the default toggle
   flipped but the routing check in `_streamToGlasses` may be false at
   runtime for some reason (stale SharedPreferences override, code
   path not reached, etc.).
2. **Line-gating is too coarse or too fine** — emits mid-line when a
   new token crosses a wrap boundary but the remainder of the line is
   still incoming.
3. **Full canvas re-send is the problem** — even if line-gated, each
   emit sends the WHOLE canvas including previously-sent lines. The
   firmware re-renders from scratch each time, so if there's even one
   frame of partial text the user sees a flicker.
4. **Pagination boundary drift** — when text overflows to a new page,
   `TextPaginator.currentPageText` changes abruptly, causing a
   perceived jump.

## Desired behavior

- **Never send a partial/unfinished visual line to the glasses.**
- Buffer the streaming tail locally until a complete line is ready
  (either a hard `\n` or a soft wrap that won't be consumed by the
  next token).
- When a complete line is ready, emit it. When pagination changes,
  emit the new page atomically.
- The final frame (`isStreaming: false`, `screen_status: 0x40`) should
  include any trailing partial line so nothing is lost.

## Investigation steps

1. **Verify HudStreamSession is actually active on release build.**
   - Add a one-shot `debugPrint` at the entry of
     `HudStreamSession.appendDelta` (or wherever the streaming entry
     is) saying "hud.lineStreaming=ON, routing via session".
   - If you don't see it on hardware, the settings flag isn't taking
     effect — check SharedPreferences and verify `762b005` actually
     flipped both the field default and the `getBool` fallback.
   - If you DO see it, proceed to step 2.

2. **Trace what HudStreamSession emits.** Temporary debug logging on
   every `ProtoHudPacketSink.send` call: timestamp + first 20 chars of
   pageText + current line count + whether it ends in a newline or a
   wrap boundary.

3. **Check the line detection logic.** Read
   `lib/services/hud_stream_session.dart` — what counts as a "complete
   line" for gating purposes? Is it:
   - Hard newline only?
   - Hard newline OR wrap boundary (based on TextPaginator)?
   - Character count threshold?

   If it's character-count or wrap-boundary, it can emit mid-word when
   a token happens to complete a line even though the NEXT token was
   going to be part of the same visual phrase.

4. **Consider sentence-gating instead of line-gating.** Emit on
   sentence boundaries (`.`, `?`, `!`, `。`, etc.) — less frequent than
   line gating, no mid-word artifacts. Tradeoff: longer latency before
   the first frame appears. May be acceptable for short sentences.

5. **Consider delta-append semantics, revisited carefully.** Plan E
   had `0x30` delta mode but the firmware didn't support append-at-pos
   reliably (per `ddaab66` revert). But we could simulate it: keep a
   stable canvas for the first N lines and only re-send the tail line.
   Requires firmware cooperation — probably not worth the risk.

6. **Measure minimum inter-frame interval** that the firmware can
   accept without dropping. If the problem is that we're sending faster
   than the firmware can render, simple rate-limiting to 10Hz might
   fix the visible artifacts without any semantic change.

## Proposed implementation

Start with the simplest fix and escalate only if needed:

### Phase 1 (fast, minimal risk)
1. **Rate-limit streaming flushes** to max 5Hz (200ms intervals).
   Already have `_minFlushInterval` at 200ms via `_lastGlassesFlush` —
   verify this is actually enforced in the B line-streaming path, not
   bypassed.
2. **Only flush on line-complete**, not token-complete. If
   HudStreamSession already does this but the line detection is bad,
   tighten it to require a newline OR a hard-wrap boundary where the
   next token can't extend the line.
3. **Suppress emits where pageText is unchanged** (or differs only in
   whitespace).

### Phase 2 (if Phase 1 insufficient)
4. **Buffer one line behind.** Always hold the currently-filling line
   locally, only emit up to the last fully-completed line. On final
   frame, include the buffered tail.
5. **Sentence-gate** instead of line-gate.

### Phase 3 (only if Phase 1+2 fail)
6. **Reconsider delta-append** — with firmware cooperation, maintain a
   stable head canvas and only re-send the tail. High risk, high work.

## Success criteria

- During a 500-word streaming answer on real G1 hardware:
  - No partial words visible mid-stream
  - No visible flicker as each line appears
  - Text grows downward smoothly line-by-line
  - Final frame shows complete text with no trailing partial
- Frame rate to the glasses is ≤ 5Hz during streaming
- Session thermal stays comparable to pre-B baseline

## Related

- `2026-04-08-evenai-listening-flash-brief-during-streaming.md` — same
  display surface, different bug
- `2026-04-08-homescreen-scroll-snap-on-long-streaming-answer.md` —
  phone-side scroll, unrelated surface but same class of
  "content-driven reflow" bug
- `2026-04-08-phone-thermal-during-streaming-and-recording.md` —
  reducing frame rate to the glasses may directly help thermal too
- Commit `ddaab66` — reverted delta-append scheme; do not reintroduce
  without firmware-side support
- Commit `762b005` — flipped `hud.lineStreaming` default ON
- `lib/services/hud_stream_session.dart` — B's line-streaming
  implementation, primary file to modify
