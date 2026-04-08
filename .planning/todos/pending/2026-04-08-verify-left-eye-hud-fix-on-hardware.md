---
created: 2026-04-08T03:45:43.947Z
title: Verify left-eye HUD fix on hardware (revert of 10905f7 delta scheme)
area: ble
status: active
priority: high
files:
  - lib/services/conversation_engine.dart
---

## Problem

Software fix landed for the left-eye HUD bug — `_sendToGlasses` reverted to always-full-canvas (`screenCode = aiFrame(isStreaming)`, `pos: 0`). Root cause was commit `10905f7` introducing an append-at-`pos` delta scheme that the G1 firmware does not support; L lens timed out on the malformed delta packets and stayed stuck on the EvenAI listening screen.

Software validation:
- `flutter analyze lib/services/conversation_engine.dart` — No issues found
- `bash scripts/run_gate.sh` — build + tests pass (only pre-existing 13>10 warnings gate failure, unrelated)

**Hardware verification still required** before this can be considered closed.

## Solution

1. Boot a dedicated Helix simulator instance (or flash to real G1 hardware) — see CLAUDE.md "Simulators in use" note.
2. Start a live conversation session with both L and R glasses connected.
3. Trigger an AI answer (auto-detected question or manual Q&A).
4. Observe both lenses during streaming:
   - **PASS**: both L and R show the streamed answer text identically, transitioning out of "Even AI Listening" placeholder.
   - **FAIL**: L still stuck on "Even AI Listening" while R shows text → reopen the original todo and dig deeper (possibly the inter-side 400ms delay or a different code path).
5. Also verify multi-page answers — make the AI generate >5 lines so the paginator advances. Both lenses should page correctly.
6. If hardware test passes, also delete the now-unused `aiFrameForPage` helper in `lib/services/glasses_protocol.dart` (no callers remaining after the revert).
7. Move both this todo and `2026-04-08-left-eye-hud-broken-streaming-even-ai-listening.md` to `.planning/todos/done/`.
