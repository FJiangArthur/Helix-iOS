# Conversate Plan B — R1 ring on G1 (Android) Implementation Plan

> Executed inline with TDD. Spec: `docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md` §3 (R1 constraints), §4.1 (intent table), §5.6 (R1 on G1), D5 (own decoder, no GPL code).

**Goal:** Helix Android connects directly to an already-bonded Even R1 ring and turns its gestures into Conversate intents, alongside the G1 touchpad.

**Architecture:** `ring/R1Frame.kt` (pure decoder + gesture dedupe), `conversate/R1InputMapper` (gesture → intent), `ring/R1Transport.kt` (Android BLE central: bonded `EVEN R1_*` device, subscribe `bae80011`/`bae80013`, reconnect with backoff), `ConversateController.handleRing`, settings `ringEnabled`, Conversate card ring row.

## Global Constraints
- R1 GATT: service `bae80001-4f05-4503-8e65-3af1f7329d1f`; notify chars `bae80011-…` and `bae80013-…` (same base UUID). Subscribe only — **no writes** in v1.
- Frames (documented by community projects; decoder written from the formats, no copied code):
  3-byte `FF 04 01` tap, `FF 04 02` double tap, `FF 03 20` hold, `FF 05 pp` swipe (pp ≤ 1 forward, else back);
  11-byte `00 09 61 00 cc pL pH t0 t1 t2 t3`: cc 00 hold, 01 tap, 02 double, 04 swipe up (back), 05 swipe down (forward), 08 hold release.
- Unknown frames are ignored (logged), never guessed.
- Intent mapping (spec §4.1): tap→SELECT, double→BACK, hold→MENU, release→none, forward→NEXT, back→PREV.
- The same gesture can arrive on both characteristics: identical gestures within 150 ms from the ring are one gesture.
- Reconnect backoff 1 s → 30 s; touchpad keeps working throughout.
- Conversate disabled or ring disabled → transport stopped.

## Tasks
1. `R1Frame` decoder + `R1GestureDeduper` — tests: every documented frame, unknown/short/wrong-header frames → null, dedupe window.
2. `R1InputMapper` + `ConversateController.handleRing` — tests: ring hold opens menu, ring tap selects in menu, ring+touchpad duplicate within 250 ms counts once, disabled ignores ring.
3. `R1Transport` — name matcher test (`EVEN R1_A1B2C3` yes, `Even G1_L_…` no); BLE layer untested (hardware).
4. Settings `ringEnabled` + bridge wiring + Conversate card ring row (status, toggle, connect) — full suite + assembleDebug.
5. Deliver APK; hardware checklist (ring gestures reach Helix with Even app force-stopped).
