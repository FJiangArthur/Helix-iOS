# Hardware test results — 2026-04-07

**Build:** main @ 689b5ae (integrated C+B+D stack + Phase 0 hardware fixes + Q&A diagnostic)
**Device:** Art's Secret Castle (iPhone, iOS 26.4) — wireless release build

## Results

| # | Test | Result | Notes |
|---|---|---|---|
| 1 | Left-eye HUD — stuck on Listening | 🟡 Mostly fixed | Brief intermittent flash of "Even AI Listening" remains. Not stuck. Low priority. → `.planning/todos/pending/2026-04-08-evenai-listening-flash-brief-during-streaming.md` |
| 2 | LA buttons visible on answer | ✅ PASS | Works on both Lock Screen and Dynamic Island |
| 3 | HUD flashing during streaming (dashboard race) | ✅ PASS | No dashboard/AI alternation |
| 4 | Transcription drops 3-5s on Q&A press | ✅ PASS | No audio lost during Q&A press |
| 5 | Scroll-up during streaming | 🔴 FAIL for long answers | Works for short answers. Long answers still flash/snap. 64px tolerance insufficient. → `.planning/todos/pending/2026-04-08-homescreen-scroll-snap-on-long-streaming-answer.md` |
| 6 | Q&A failure diagnostic capture | ✅ Works | Q&A did not fail during this test; diagnostic logging remains in place for next repro |
| 7B | HUD line streaming flag | N/A | No Settings UI toggle exists — user could not test. Action: **flipped default to ON as of this session** |
| 8D | Session cost tracking badge | 🟡 Badge works, cost values wrong | Diagnostic logging added to `ConversationCostTracker.recordCompleted` to capture raw inputs, model IDs, and computed costs for next hardware run |

## Actions taken this session

1. **Enabled `hud.lineStreaming` default ON** (`lib/services/settings_manager.dart`).
   Default flipped from `false` → `true`. Existing users who explicitly turned it
   off will keep their preference via SharedPreferences; new installs get the
   new line-gated HUD path by default.

2. **Added cost-tracking diagnostic logging**
   (`lib/services/cost/conversation_cost_tracker.dart`). Every
   `recordCompleted` call now emits a debugPrint with:
   - operationType, providerId, modelId, modelRole
   - inputTokens, cachedInputTokens, outputTokens, audioInputTokens
   - computed per-call costUsd
   - running snapshot totals (smart / light / transcription / unpriced)

   Next hardware run: filter console on `[CostTracker]` to see the raw
   inputs and math for each LLM/transcription call. Report back what the
   badge shows vs what the running totals in the log show vs what you
   expected.

3. **Logged two new pending TODOs:**
   - `2026-04-08-evenai-listening-flash-brief-during-streaming.md` (low)
   - `2026-04-08-homescreen-scroll-snap-on-long-streaming-answer.md` (medium)

## What to test next run

1. Verify item 7B (HUD line streaming) works on hardware now that the
   default is ON. Compare cadence vs the legacy per-token path.
2. Trigger a few Q&A cycles and capture `[CostTracker]` console lines.
   Send back:
   - The log lines
   - What the badge shows on-screen
   - Your expected cost (rough order of magnitude is fine — "a few
     cents", "less than a penny", etc.)
3. Re-test item 5 with a fresh long answer to confirm the scroll bug is
   reproducible and matches the TODO description.
4. Item 1 (EvenAI Listening flash): if it becomes more frequent or
   blocking, re-prioritize the TODO.

## Additional issues flagged during test (new TODOs)

| Priority | Issue | TODO file |
|---|---|---|
| Tier-1 | Phone heats up fast during streaming + recording (like 4K video) | `.planning/todos/pending/2026-04-08-phone-thermal-during-streaming-and-recording.md` |
| Tier-2 | HUD works at session start, later head-up shows factory default then blank | `.planning/todos/pending/2026-04-08-hud-intermittent-factory-default-after-session-start.md` |
| Tier-1 | Live screen still blank (re-flagged) | `.planning/todos/pending/2026-04-08-tier1-live-page-blank.md` (existing) |

## Deferred

- Plan A (priority-pipeline) — still paused per handoff
- Tier-1 TODOs (Summarize/Rephrase/Translate/FactCheck, Follow-up deck
  send, Live Page blank)
- Plan D shim cleanup (blocked on Plan A)
