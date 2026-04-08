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

## Progress 2026-04-08

Static audit found **3 bugs** in `lib/screens/home_screen.dart` — 2 fixed, 1 diagnostic.

### Bug 1 (fixed): Summarize wasn't wired to a prompt

`AssistantResponseActions(onSummarize: _navigateToDetail)` — the Summarize
button just switched to the Live tab (`MainScreen.switchToTab(2)`). It
never sent a summarize prompt to the engine.

**Fix:** added `_summarizeLastAnswer()` mirroring the other three tool
prompts (rephrase/translate/factcheck) — builds a "summarize in 1-3
bullet points" prompt and routes it through `_runResponseToolPrompt`.
Wired `onSummarize: _summarizeLastAnswer`.

### Bug 2 (fixed): all 4 actions silently no-oped during recording

`_runResponseToolPrompt` had `if (_isRecording || prompt.trim().isEmpty) return;`.
So pressing Summarize/Rephrase/Translate/FactCheck while a live session
was recording **silently returned with no error, no log, no snack**.
This is almost certainly the "all 4 broken" hardware symptom — user
tested these during a live session.

**Fix:** removed the `_isRecording` early-return. The original reason
for the guard was to protect `_transcription` (the live transcript
display) from being overwritten by the preview text. Kept that
protection via a `showPreview` flag: the action runs regardless of
recording state, but the preview text overwrite is skipped when
recording. `_engine.askQuestion` still transitions HUD state, which
may interact with live recording in unexpected ways — needs hardware
verification.

### Bug 3 (diagnostic): unknown remaining failures

Added kDebugMode-gated `[HomeScreen] _runResponseToolPrompt: recording=
... promptLen=... aiResponseLen=...` at the entry of the tool handler.
If any action still silently no-ops on hardware, the device console
will show whether `_aiResponse` was empty or the prompt itself was bad.

### Side note: dead enum

`lib/models/assistant_action_type.dart` defines `AssistantActionType`
with summarize/rephrase/translate/factCheck/etc. **Zero usages in the
codebase.** Orphaned from an earlier dispatch design. Not deleted this
session — keeping cleanup out of scope — but a candidate for a future
housekeeping commit.

## Still TBD
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
