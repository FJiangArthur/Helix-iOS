# TODOs

Tracked long-lived work items from planning and review sessions. Tier-0/1 in-flight items live in `.planning/todos/pending/`.

---

## T-001: Audit LLM rate-limit (HTTP 429) handling during streaming

- **Source:** /gstack-plan-eng-review (2026-04-15) of `prep-on-your-face` design.
- **What:** Investigate and document how `LlmService.streamResponse()` and `OpenAiProvider.streamResponse()` handle HTTP 429 mid-stream. Verify the error surfaces via `_providerErrorController`. Add a test if handling is missing.
- **Why:** Phase 1 of the prep design adds ~8k tokens per call, increasing rate-limit exposure. If handling is "swallow and return partial stream," that's a silent failure mode. Users see a truncated answer and don't know why.
- **Pros:** Closes a known unknown before Phase 1 hits real users.
- **Cons:** ~2h of investigation; may find handling is already fine.
- **Context:** `conversation_engine.dart` has `_providerErrorController` but it's unclear what triggers it mid-stream. Check `openai_provider.dart:107` streamResponse implementation. Related: `provider_error_state.dart`.
- **Depends on:** nothing.
- **Blocks:** nothing (not a Phase 1 gate), but should land before Phase 1 ships to external users.

## T-002: Extract-refactor `conversation_engine.dart` into packages

- **Source:** /gstack-plan-eng-review (2026-04-15). Outside voice and primary review both flagged.
- **What:** Extract question detection and background analytics into separate packages:
  - `lib/services/question_detection/` — detection-stream logic currently in `conversation_engine.dart`
  - `lib/services/analytics/` — `_runBackgroundAnalytics` and sentiment/entity counters
- **Why:** File is 3552 LoC with 3 known bugs (BUG-001, 002, 005 — see `docs/TEST_BUG_REPORT.md`). File size correlates with bug density in this codebase's history. Phase 2 of the prep design will push it past 4000 LoC without this refactor.
- **Pros:** Future changes touch a smaller surface. Unblocks parallel work on detection vs. engine core.
- **Cons:** ~2-3 days of structural refactor with no user-facing delta.
- **Context:** Design doc's Phase 2 has a refactor guard ("extract before exceeding 4000 LoC") — this pre-stages that work. Recommended to schedule between Phase 1 ship and Phase 2 start.
- **Depends on:** BUG-005 fix (Phase 0 of prep design).
- **Blocks:** Phase 2 detection work if file hits 4000 LoC first.

## T-003: Upgrade "prep covers" classifier before Phase 3

- **Source:** /gstack-plan-eng-review (2026-04-15). Outside voice specifically called this out.
- **What:** Replace the Phase 3 v1 "prep covers" classifier (substring overlap with English stopword filtering) with either embedding-similarity or a small-LLM intent-matcher.
- **Why:** Substring matching fails on interview-style semantic questions. "Tell me about a challenging project" has zero keyword overlap with a resume listing actual project names. The classifier will return `false` on nearly every real-world question, defeating the 80ms retrieval gate and routing every turn through retrieval — which is the cost/latency regression Phase 3 was designed to avoid.
- **Pros:** Makes Phase 3's gating actually work. Without this, Phase 3 is effectively "always retrieve," doubling latency budget + cost.
- **Cons:** Adds an embedding call or LLM intent classifier to the hot path. Adds ~20-50ms to classifier latency itself.
- **Context:** Currently spec'd as v1 with note "upgradeable to embedding-similarity later." The upgrade is structural, not incremental — once data flows through the substring path, changing the classifier changes retrieval rates materially and affects measurement.
- **Depends on:** Phase 3 approval (conditional on Phase 1 + Assignment validation).
- **Blocks:** Phase 3 shipping without this would cause immediate cost/latency regression.
