---
created: 2026-04-08T00:00:00.000Z
title: Tier-4 — Active fact-check with web search + proactive glasses alerts
area: conversation-intelligence
status: pending
priority: tier-4
files:
  - lib/services/conversation_engine.dart
  - lib/services/llm/llm_service.dart
  - lib/services/tools/web_search_tool.dart
  - lib/services/evenai.dart
  - lib/services/bitmap_hud/bitmap_hud_service.dart
---

## Feature request

**Active fact-checking during live conversation**, with web search for
verification, and proactive glasses HUD alerts when false information
is detected.

Currently fact-check runs after every AI response as a background task
(per CLAUDE.md Technical Findings: "Background fact-check runs after
every AI response (non-blocking)"). This TODO extends fact-check to
**listen to the live conversation itself**, verify factual claims made
by any participant, and **push corrections to the glasses HUD
proactively** without requiring a user Q&A press.

## Behavior spec

### Gating
- **Only runs when the fact-check feature is enabled** in settings.
- **Only verifies publicly knowable factual claims** — dates, named
  entities, quantities, historical events, geographic facts, scientific
  consensus, definitions. Skip opinions, preferences, subjective
  statements, personal anecdotes, predictions.
- **Does not surface claims it cannot verify** — absence of evidence is
  NOT evidence of falsity. Only flag when there is clear contradicting
  evidence from a reliable source.

### Detection pipeline
1. **Claim extraction.** Periodically (e.g. after each finalized
   transcript segment of sufficient length) send the recent transcript
   window to the light-model LLM with a prompt asking:
   > "List any publicly verifiable factual claims in this transcript.
   > For each, output the claim, confidence it's a factual claim (not
   > opinion), and whether it's the kind of thing worth verifying."
2. **Filter.** Drop claims that are:
   - Already the topic of the current AI answer (already being handled)
   - Low-confidence factual claims (opinion-heavy)
   - Trivially true or within the last minute's already-verified set
3. **Verify via web search.** For remaining candidate claims, use the
   existing `web_search_tool` (already exists per `lib/services/tools/
   web_search_tool.dart`) through the smart-model LLM:
   > "Verify this claim: {claim}. Use web search. Return: verdict
   > (true / false / unverifiable), confidence, one-sentence correction
   > if false, source URL."
4. **Rate-limit.** Max N claims verified per minute per session to
   bound cost and thermal impact.

### Proactive HUD alert
When a claim comes back **false with high confidence**:

1. **Queue a correction overlay** on the glasses HUD
2. **Priority rules:**
   - **User Q&A has highest priority.** If the user is currently
     pressing Q&A or an active Q&A response is rendering, fact-check
     corrections are suppressed until the Q&A completes.
   - **Active AI answer has priority over fact-check.** Corrections
     queue behind.
   - **Fact-check corrections preempt idle/dashboard state** — if
     nothing else is showing, a correction can render.
3. **Display format (glasses):**
   - Icon or prefix: `⚠ FACT` or similar short marker
   - One-line correction: `Correct: {one-sentence fix}`
   - Optional source abbreviation: `(source)` if space allows
   - Auto-dismiss after N seconds (e.g. 8s) unless user taps touchpad
     to keep it visible
4. **Phone-side:** show the correction in the conversation stream as a
   "fact-check" annotation attached to the offending transcript segment,
   so the user has a full record after the session.

### UI toggle
- Settings: `conversation.activeFactCheck` boolean
- Default: OFF (cost + thermal + false-positive risk until tuned)
- When OFF, existing post-answer background fact-check continues
  unchanged

## Integration with existing systems

- **`web_search_tool.dart`** already exists — see line 42 ref from the
  Q&A search earlier. Reuse it. Tool-call loop already supported in
  `_generateResponse` (up to `maxToolRounds = 3`).
- **`SessionContextManager`** (three-tier context window, per CLAUDE.md)
  — use the mid-tier window to extract claims, not the full session.
  Bounds token cost.
- **`ConversationCostTracker`** — new fact-check LLM calls need to be
  recorded. They use the smart model for verification and light model
  for claim extraction. Add `modelRole: ModelRole.smart` /
  `ModelRole.light` so the badge breakdown reflects fact-check cost.
- **Priority/queue system** — coordinate with Plan A's priority-pipeline
  rework. This feature SHOULD land AFTER Plan A merges, because Plan A
  introduces the proper `AnswerSlot` / `QARequest` queue that this
  feature needs to slot into. Attempting this before Plan A would mean
  inventing a parallel queue and then ripping it out.

## Known risks

1. **False positives.** Claim extraction from conversational transcript
   is noisy — "I think..." / "maybe..." hedges should not be verified
   as facts.
2. **Cost.** Every fact-check adds both a claim-extraction LLM call and
   a web-search LLM call. Enforce hard rate limits and a monthly cost
   cap.
3. **Thermal.** See `2026-04-08-phone-thermal-during-streaming-and-
   recording.md`. More LLM calls = more heat. This feature must NOT
   land until the thermal Tier-1 TODO is diagnosed.
4. **Social friction.** Flagging a user's own incorrect statement in
   real time during a live conversation may be awkward. Consider a
   "private mode" where corrections only show on the user's glasses
   (not the phone) so other participants don't see them.
5. **Web search accuracy.** Web search results themselves may be wrong.
   Require high confidence + citation before surfacing.

## Success criteria

- User enables active fact-check in settings
- During a live conversation where someone says "The Berlin Wall fell
  in 1987", within ~10 seconds the glasses show:
  `⚠ FACT Correct: 1989 (source)`
- User's active Q&A presses are never interrupted by fact-check alerts
- Session cost badge shows the fact-check cost separately or rolled
  into smart/light buckets

## Priority

Tier-4 — product feature, not a bug. Lands after:
1. All Tier-1 bugs cleared (thermal, cost bug, live page blank,
   follow-up/send button)
2. Plan A (priority-pipeline) merged — provides the queue this feature
   needs
3. Thermal TODO resolved — or rate-limit very aggressively

## Related

- CLAUDE.md Technical Findings: "Background fact-check runs after every
  AI response (non-blocking)" — existing passive implementation
- `lib/services/tools/web_search_tool.dart` — existing web search tool
- Plan A `.worktrees/2026-04-06-priority-pipeline` — introduces the
  answer-slot priority queue this feature depends on
- `2026-04-08-phone-thermal-during-streaming-and-recording.md` — blocker
