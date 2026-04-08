# Home screen still snaps/flashes on long streaming answers

**Priority:** Medium
**Reported:** 2026-04-07 hardware test on main @ 689b5ae
**Severity:** UX regression — user cannot read earlier transcript during long answers
**Status:** RESOLVED 2026-04-07 — replaced content-relative tolerance with intent-relative gate

## Resolution

Replaced the 64px content-relative tolerance in `_scrollToBottom` with
an intent-relative gate driven by `ScrollController.position.userScrollDirection`:

- Added `_userHasScrolledUp` flag to `_HomeScreenState`.
- Added `_handleScrollPositionChange` listener attached in `initState`,
  removed in `dispose`. Sets the flag when `userScrollDirection ==
  ScrollDirection.reverse`, clears it when the user scrolls back within
  16px of `maxScrollExtent`.
- `_scrollToBottom` now early-returns if `_userHasScrolledUp` is true,
  regardless of distance from bottom.
- Cleared on recording-state transition to true so a new session always
  auto-scrolls fresh.

This decouples the auto-scroll decision from the streaming-content
delta rate, fixing the long-answer regression where the 64px window was
crossed in either direction between frames.

Files: `lib/screens/home_screen.dart`. No new tests (no widget test
infra for HomeScreen in this repo). Hardware verification still owed.

## Symptom

Item 5 of the hardware smoke test: scroll-up-during-streaming.

- **Short answers** (~1-3 sentences): works correctly. User can scroll up
  and the transcript stays where they scrolled.
- **Long answers** (paragraph+): screen still flashes / snaps back toward
  the bottom. The 64px tolerance in `HomeScreen._scrollToBottom` (cherry-
  picked as part of `ab4bb49` from Plan A's `03c1bdc`) is insufficient.

## Current implementation

`lib/screens/home_screen.dart` — `_scrollToBottom` added a 64px tolerance:
> "detect 'user is not at the bottom' with a 64px tolerance and skip the
> auto-scroll if so"

This works when the content delta per frame is small. But long answers
add multiple lines per streaming flush, so by the time the next
transcript snapshot arrives the scroll position may already be >64px from
the new `maxScrollExtent`, causing the auto-scroll to fire again and
snap down.

## Likely root cause

The tolerance check is **content-relative** (distance from current
`maxScrollExtent`), not **intent-relative** (did the user initiate the
scroll). When the content grows rapidly, the "distance from bottom"
metric is a moving target and can cross the threshold in either direction
between frames.

## Proposed fix

Track user-initiated scroll separately from content-driven scroll:

1. Attach a listener to `ScrollController.position.userScrollDirection`.
2. When direction transitions to `reverse` (user scrolling up),
   set `_userHasScrolledUp = true`.
3. When user scrolls all the way back to the bottom (within a small
   tolerance, e.g. 16px), clear `_userHasScrolledUp = false`.
4. In `_scrollToBottom`, skip auto-scroll if `_userHasScrolledUp == true`
   regardless of current distance from bottom.

Alternative: use a `NotificationListener<ScrollStartNotification>` and
check if the scroll was user-initiated (`metrics.axis` + drag source) vs
programmatic.

## Investigation steps

1. Reproduce with a long answer locally to confirm the failure mode.
2. Add `debugPrint` to `_scrollToBottom` logging `(atBottomDistance,
   maxScrollExtent, pixels, userScrollDirection)` to see the sequence.
3. Verify the fix on hardware with both a 500-word answer and a 50-word
   answer.

## Related

- `ab4bb49` (cherry-pick of Plan A's `03c1bdc`) — introduced the 64px
  tolerance
- `.planning/HANDOFF-2026-04-07.md` — original description of the
  scroll-during-streaming fix
