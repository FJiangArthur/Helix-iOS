# Brief "Even AI Listening" flash during streaming

**Priority:** Low
**Reported:** 2026-04-07 hardware test on main @ 689b5ae (integrated C+B+D stack)
**Severity:** Cosmetic — not blocking

## Symptom

Left lens occasionally shows the "Even AI Listening" screen very briefly
during streaming, then returns to the answer. Unlike the pre-`ddaab66`
bug (where L was stuck on Listening for the entire streaming duration),
this is a momentary flash. "Not too bad" per user.

## Context

- `ddaab66` fixed the *stuck on Listening* regression by reverting
  `_sendToGlasses` from the append-delta scheme back to full-canvas.
- The brief flash remaining suggests that the first streaming packet of a
  new response (or of a new page within a response) still triggers a
  firmware screen-mode transition on L — possibly because:
  - L's `requestList` ACK is slightly slower than R's, so L renders one
    frame of the default AI screen before the first full-canvas frame
    arrives, OR
  - The transition from `aiFrame(isStreaming: false)` (the previous
    idle/dashboard state) to `aiFrame(isStreaming: true)` (first streaming
    frame) briefly shows the firmware's default AI overlay on L before
    the phone-pushed text replaces it.

## Where to look

- `lib/services/conversation_engine.dart` — `_sendToGlasses` (post-revert)
  and `_streamToGlasses` → `HudStreamSession` (Plan B line-streaming path,
  now default ON as of 2026-04-07).
- `lib/services/proto.dart` — `sendEvenAIData`, especially the L/R send
  ordering and any inter-side delay.
- `ios/Runner/BluetoothManager.swift` — L vs R ACK pipeline.
- G1 firmware screen-mode transition docs (if captured): the first
  `0x4e/0x31 new-canvas` frame after an idle state may be when L briefly
  shows the listening screen.

## Possible fixes (not yet investigated)

1. **Pre-send a warm-up frame**: when the engine transitions from idle to
   `thinking`, push a single `0x4e/0x31` empty frame so the firmware is
   already in "AI overlay showing" state before the first real streaming
   frame arrives. Both L and R would then transition together.
2. **Force L-first ordering** for the first streaming frame: if L is the
   slower side, send its packet first so the user-visible transition is
   synchronized.
3. **Debounce the streaming start**: suppress the first ~50ms of
   streaming frames and only emit the first frame once enough text has
   accumulated to fill a line, so the transition is less visible.

## Investigation steps

1. Capture a hardware video of the flash (slow-mo if possible) to confirm
   the exact frame sequence.
2. Add `debugPrint` timestamps to `HudStreamSession.emit` and
   `_sendToGlasses` with L vs R identifiers to see which side renders
   first.
3. Check whether the flash disappears when `hud.lineStreaming` is toggled
   OFF — if so, the HudStreamSession line-gating is adding the transition;
   if not, it's deeper in the protocol.

## Related

- `2026-04-08-verify-left-eye-hud-fix-on-hardware.md` (partially resolved
  on 2026-04-07 — the stuck case is gone, the flash remains)
- `2026-04-08-left-eye-hud-broken-streaming-even-ai-listening.md` (main
  case resolved by `ddaab66`)
