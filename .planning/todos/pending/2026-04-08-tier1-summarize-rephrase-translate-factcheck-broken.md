---
created: 2026-04-08T03:45:43.947Z
updated: 2026-04-08T00:00:00.000Z
title: Tier-2 — Summarize/Rephrase/Translate/FactCheck actions broken
area: conversation-tools
status: pending
priority: tier-2
files:
  - lib/services/conversation_engine.dart
---

## Problem

The conversation tool actions Summarize, Rephrase, Translate, and
FactCheck are all broken on hardware as of 2026-04-07.

**Priority change 2026-04-07:** Originally logged as Tier-1 deferred.
Re-tiered to **Tier-2** per user — no longer deferred, but not blocking
either. Pick up after the Tier-1 issues (thermal, live page blank,
follow-up deck send, cost bug) are cleared.

> Note: filename kept as `tier1-...` for grep-stability — the canonical
> tier is in the frontmatter `priority:` field.

## Solution

TBD. Investigation path:
1. Trace each action through ConversationEngine → LlmService
2. Determine if all four share a common failure point (likely) or
   fail independently
3. Check recent changes to prompt construction or tool dispatch
4. Plan B (hud.lineStreaming now default ON) may affect HUD routing for
   these actions if they reuse `_streamToGlasses` — verify the line-gated
   path handles the short-output case (1-sentence summaries etc.) cleanly
5. Cross-check with the Plan D shim TODOs in conversation_engine.dart —
   one of the action dispatch sites may be sitting behind an unused
   priority-pipeline branch that never executes

## Related

- `2026-04-08-tier1-follow-up-deck-send-broken.md`
- Plan A resumption (priority-pipeline) will touch the same engine
  dispatch code
