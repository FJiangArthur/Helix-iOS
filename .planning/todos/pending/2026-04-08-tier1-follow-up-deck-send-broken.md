---
created: 2026-04-08T03:45:43.947Z
updated: 2026-04-08T00:00:00.000Z
title: Tier-3 — Follow-up deck: chip-press should send immediately + fix broken send button
area: conversation-tools
status: pending
priority: tier-3
files:
  - lib/services/conversation_engine.dart
  - lib/screens/home_screen.dart
  - lib/widgets/compose_bar.dart
  - lib/widgets/followup_chips.dart
---

## Problem

**Two related bugs** observed on hardware 2026-04-07.

> Note: filename kept as `tier1-...` for grep-stability — the canonical
> tier is in the frontmatter `priority:` field.

### Bug 1 — send button is broken in general

Pressing the send button next to the composer text box does not send
the typed message. The send button appears pressable but nothing
happens — no LLM call, no message added to conversation. This affects
the text query flow entirely (not just follow-up chips).

### Bug 2 — follow-up chip requires manual send

Pressing a follow-up chip (after an AI answer finishes, the chips deck
shows suggested follow-up questions) currently:
1. Populates the composer text box with the chip's question text
2. Does NOT auto-send
3. User has to press the send button to actually fire the query
4. ...and the send button is broken (bug 1), so they can't

## Desired behavior

### For the send button (bug 1)
- Fix the send button so it actually dispatches the composer text to
  the LLM pipeline. This is the text-query flow documented in
  CLAUDE.md — it should work.

### For follow-up chips (bug 2)
- Change the chip tap handler to **send immediately**. Do not populate
  the composer first.
- Tap chip → fire LLM query with the chip text as the question → stream
  answer to glasses HUD and phone.
- Same path as if the user had typed the text and pressed send.

## Investigation

1. **Find the send button handler.** Likely in `lib/widgets/compose_bar.dart`
   or `lib/screens/home_screen.dart`. Trace it to see where it's
   supposed to call into ConversationEngine.
2. **Check if send button is calling a real method or a stub.** It may
   be wired to a no-op callback or an old method that was renamed.
3. **Follow-up chip handler.** Find where chip presses are wired. Change
   from "populate composer" to "dispatch directly". Reuse the same
   dispatch path as the fixed send button.
4. **Verify the text-query flow still works for all modes** (general,
   interview, passive) — the send path may be mode-gated somewhere.

## Success criteria

- Type in composer → press send → AI answer streams to phone + HUD
- Press follow-up chip → AI answer streams immediately to phone + HUD
  (no composer population step)
- Both flows work in general, interview, and passive modes where
  appropriate

## Related

- `2026-04-08-tier1-summarize-rephrase-translate-factcheck-broken.md` —
  may share a common dispatch bug
