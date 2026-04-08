---
created: 2026-04-08T00:00:00.000Z
title: Tier-2 — HUD intermittent, factory default shows then disappears
area: hud
status: pending
files:
  - lib/services/bitmap_hud/bitmap_hud_service.dart
  - lib/services/evenai.dart
  - lib/services/conversation_engine.dart
  - lib/services/proto.dart
  - ios/Runner/BluetoothManager.swift
---

## Problem

**Priority:** Tier-2
**Reported:** 2026-04-07 hardware test on main @ 689b5ae

HUD works great at the start of each connection / session. Later in the
same session (after some time / some AI answers), the head-up gesture
stops showing the Helix HUD. Instead:

1. User looks up (head-up gesture)
2. Glasses show the G1 factory-default dashboard HUD briefly
3. Factory HUD disappears after ~1 second
4. Nothing else renders — no Helix HUD, no transcript, no AI answer

The session is still logically active on the phone side (transcription
keeps running, AI answers still stream to the non-head-up state), but
the head-up-triggered HUD overlay is broken until a full disconnect +
reconnect.

## Why this matters

Tier-2 because the phone-side session still works — user can still use
the app. But the glasses HUD is the entire product value prop. If this
repros reliably after some threshold (minutes / # of answers / # of
head-ups), it's effectively a "works for 3 minutes then bricks" bug.

## Candidates

### 1. BitmapHudService widget registration going stale

`lib/services/bitmap_hud/bitmap_hud_service.dart` registers widgets at
app start. If the registration is one-shot and the firmware loses state
(e.g. after a firmware-side screen transition timeout), re-registration
never fires, so head-up tries to show a widget the firmware no longer
knows about → falls back to factory dashboard.

Check:
- Does BitmapHudService re-register on BLE reconnect?
- Does it re-register after each `notifyIndex` from the firmware?
- Is there a heartbeat / health-check for the widget registry?

### 2. Head-up notification handler unsubscribing

`ios/Runner/BluetoothManager.swift` handles `notifyIndex 2 = headUp`
and `notifyIndex 3 = headDown`. If the notification characteristic
subscription drops silently (iOS BLE restore, backgrounding, firmware
reset), the handler stops firing but the session continues.

Check:
- Is `setNotifyValue(true, ...)` re-applied after any state change?
- Does the CBPeripheralDelegate reconnect-without-full-disconnect flow
  re-subscribe?
- Any silent CBError we're swallowing?

### 3. Factory default HUD = fallback on missing widget

The G1 firmware likely has a fallback: if the phone doesn't push a new
screen within N ms after a head-up event, the firmware shows its
built-in dashboard and then times out. If Helix is late (or never sends
anything), the user sees factory → blank.

This would point at the phone-side handler being slow / missing rather
than the firmware being broken.

Check:
- Latency from head-up notification to first `0x4e` packet going out
- Does this latency grow over the session? (GC pause? Isolate stall?
  Thermal throttling — see
  `2026-04-08-phone-thermal-during-streaming-and-recording.md`)

### 4. Race with `thinking` / `responding` state suppression

The Phase 0 fix `ab4bb49` added dashboard-refresh suppression when
`EngineStatus` is `thinking` or `responding`. If the engine status is
getting stuck in one of those states (never returning to `listening`
/ `idle`), the head-up handler might be blocked from rendering.

Check:
- What's `EngineStatus` at the moment of the broken head-up?
- Is `_isGeneratingResponse` ever getting stuck true?

## Investigation steps

1. **Capture timing.** Add `debugPrint` to the head-up notification
   handler (native side, `BluetoothManager.swift` on `notifyIndex 2`)
   and to the Dart-side `HudController` / `BitmapHudService` entry
   point. Log timestamps and any state we're about to send.

2. **Correlate with thermal state.** Use Instruments thermal state log
   while reproducing. If the HUD breaks when thermal transitions from
   `nominal` → `fair`, the root cause is thermal throttling, fix is in
   the thermal TODO.

3. **Correlate with # of head-ups.** Does it break on head-up #N where
   N is consistent? If so, it's a counter / buffer overrun. If random,
   it's probably state drift.

4. **Test the head-up path directly** via a debug entry point — bypass
   the full streaming loop. If direct head-up works fine but
   streaming-then-head-up breaks, the streaming loop is corrupting
   state.

5. **Full reconnect resets it?** Confirm: disconnect + reconnect (or
   session stop + start) brings it back. If yes, that narrows to
   something that accumulates over session time.

## Success criteria

- Head-up gesture reliably shows Helix HUD throughout a 30+ minute
  session
- No silent fall-through to factory dashboard
- No reconnect required

## Related

- `2026-04-08-phone-thermal-during-streaming-and-recording.md` — may
  share root cause if thermal throttling is blocking head-up handlers
- `ab4bb49` dashboard-race fix — made sure we don't push dashboard
  frames during `thinking`/`responding`. Verify we're not also
  suppressing head-up frames by mistake.
- Protocol notes in CLAUDE.md: `notifyIndex 2 = headUp, 3 = headDown`
