---
created: 2026-04-08T03:45:43.947Z
title: Tier-1 — Follow-up deck send broken
area: conversation-tools
status: deferred
defer_reason: User instruction — do NOT pick up until explicitly requested
files: []
---

## Problem

Sending the follow-up deck (chips/suggestions after an answer) is broken on hardware as of 2026-04-07.

**Deferred per user instruction** — logged so it's not forgotten, but do NOT start work until user explicitly greenlights Tier-1 items.

## Solution

TBD. Investigation path (when un-deferred):
1. Identify the follow-up deck send path (likely EvenAI or HudController)
2. Check packet chunking / screen_status code for the deck payload
3. Compare against working send paths (main answer stream)
