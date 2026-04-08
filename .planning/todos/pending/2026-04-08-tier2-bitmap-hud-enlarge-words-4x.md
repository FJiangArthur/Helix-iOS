---
created: 2026-04-08T00:00:00.000Z
title: Tier-2 — Bitmap HUD text too small, enlarge words ~4x
area: hud
status: pending
priority: tier-2
files:
  - lib/services/bitmap_hud/bitmap_hud_service.dart
  - lib/services/hud_widgets/
  - lib/services/bitmap_hud/
---

## Problem

**Reported:** 2026-04-07 hardware test on main @ 689b5ae

Bitmap HUD text on the G1 glasses is too small to distinguish individual
words at a glance. Low effective resolution (576x136 per CLAUDE.md
protocol notes) combined with the current font size makes the text
unreadable in practice.

User wants words **~4x larger** than current.

## Context

- G1 physical display: 576x136 pixels per lens (per CLAUDE.md G1 BLE
  protocol section)
- Text HUD (fallback): 488px max width, 21pt font, 5 lines per page
- Bitmap HUD (default): full widget-based rendering via
  `BitmapHudService`. Recent commits redesigned widget scaling for
  576x136:
  - `b63d359 fix: scale enhanced HUD widgets for 576x136 display zones`
  - `ad71fae fix: scale standard HUD widgets for 576x136 display zones`
  - `a1391df fix: redesign enhanced HUD layouts for 576x136 display`
  - `4ccf9ea fix: redesign standard HUD layouts for 576x136 display`
  - `ff6a6c8 fix: match bitmap HUD logical space to physical display
    (576x136)`
- `05d11e7 Fix bitmap dashboard hide and increase minimum font size` —
  already raised the minimum font size, but user says it's still too
  small

## 4x enlargement — what it means

"4x" is ambiguous:
- **4x in area** (2x linear) — current words take up 2x as much width
  and 2x as much height. Fits ~1/4 as many words per page.
- **4x in linear** (each dimension) — current words take up 4x as much
  width and 4x as much height. Fits ~1/16 as many words per page.

Given the display is already small (576x136, 5 lines of 21pt text),
**4x linear is probably too aggressive** — it would leave room for
maybe 3-5 words per page. Start with **2x linear (4x area)** and get
user feedback. Escalate to 3x linear if still too small.

Confirm with user before implementing.

## Investigation

1. **Find the current font size constant.** Search
   `lib/services/hud_widgets/`, `lib/services/bitmap_hud/` for `fontSize`,
   `TextStyle`, `minFontSize`. There should be a base size that all
   standard HUD text widgets inherit.
2. **Check widget layout assumptions.** Enlarging font will break
   layout — multi-line text that currently fits in 5 lines will
   overflow, cards that use fixed heights will clip. Audit:
   - `lib/services/hud_widgets/` per-widget layout
   - `bitmap_hud_service.dart` rendering pipeline and RepaintBoundary
     bounds
   - Pagination — `TextPaginator` assumes 21pt / 488px width / 5 lines
     per page. Needs to scale with font.
3. **Update the TextPaginator.** The paginator is the source of truth
   for "words per page" / "lines per page". It must be updated in
   tandem with the font size or pagination will emit way too much text
   per page.
4. **Regression tests.** `test/services/` has HUD-related tests —
   update expected values.

## Proposed change

1. Settings-level toggle (simplest): add a `hudTextScale` factor in
   SettingsManager with default `2.0` (= 2x linear / 4x area). Let user
   tune it. Maps to a multiplier on the base font size everywhere
   bitmap HUD text is rendered.
2. Update `TextPaginator` to consume the same scale factor and emit
   proportionally fewer words per page.
3. Update the per-widget layouts in `lib/services/hud_widgets/` if they
   have any fixed-height assumptions that break at 2x.
4. Update tests.
5. Deploy. User validates. Tune scale factor up or down based on
   feedback.

## Risks

1. **Pagination desync.** If font size and paginator are not updated
   together, either text gets clipped (font bigger than paginator
   thinks) or wasted space (font smaller).
2. **Widget layout breakage.** Some enhanced HUD widgets have cards,
   headers, icons with fixed dimensions — these may need proportional
   scaling too, not just the text.
3. **Reading speed tradeoff.** Fewer words per page = more page turns.
   User may prefer smaller text if they read faster than pagination.
4. **Bitmap encoding cost.** Larger text = larger antialiased glyph
   coverage = more packed pixels to encode into 1-bit bitmap. May
   slightly increase per-frame cost (but should not dominate thermal
   budget — see thermal TODO).

## Success criteria

- User can read a word without straining or leaning forward
- Paragraphs of answer text are comprehensible at a glance
- No clipped text, no pagination drift
- No new regressions in existing HUD widget tests

## Related

- `05d11e7 Fix bitmap dashboard hide and increase minimum font size` —
  previous font increase attempt
- `ff6a6c8 fix: match bitmap HUD logical space to physical display
  (576x136)` — the logical-space fix
- `2026-04-08-phone-thermal-during-streaming-and-recording.md` —
  bitmap encoding is a candidate for the thermal issue; changes here
  should be measured against that
