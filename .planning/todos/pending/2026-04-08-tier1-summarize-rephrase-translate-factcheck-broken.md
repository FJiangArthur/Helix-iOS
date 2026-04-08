---
created: 2026-04-08T03:45:43.947Z
title: Tier-1 — Summarize/Rephrase/Translate/FactCheck actions broken
area: conversation-tools
status: deferred
defer_reason: User instruction — do NOT pick up until explicitly requested
files:
  - lib/services/conversation_engine.dart
---

## Problem

The conversation tool actions Summarize, Rephrase, Translate, and FactCheck are all broken on hardware as of 2026-04-07.

**Deferred per user instruction** — logged so it's not forgotten, but do NOT start work until user explicitly greenlights Tier-1 items.

## Solution

TBD. Investigation path (when un-deferred):
1. Trace each action through ConversationEngine → LlmService
2. Determine if all four share a common failure point (likely) or fail independently
3. Check recent changes to prompt construction or tool dispatch
