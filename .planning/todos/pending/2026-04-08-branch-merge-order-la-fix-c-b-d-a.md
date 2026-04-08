---
created: 2026-04-08T03:45:43.947Z
title: Branch merge order — LA-buttons fix → C → B → D → A
area: planning
files: []
---

## Problem

Multiple in-flight branches need to land in a specific order to minimize hardware-critical regressions and avoid merge conflicts. Captured 2026-04-07.

## Solution

Merge in this order:

1. **Fix: LA buttons disappear on answer** — Plan C regression discovered during hardware testing. Tiny fix. **Must land on the C branch before C merges to main.**
2. **C (LA rework)** — Already hardware-tested except for the LA-buttons regression above.
3. **B (hud-line-streaming)** — Feature-complete; fixes the HUD jitter currently visible.
4. **D (session-cost-tracking)** — Independent work; no hardware-critical regression.
5. **A (priority-pipeline)** — Biggest, needs Phase 0 capture first, will conflict with everything else, so last.

**Deferred (per user instruction, do NOT pick up until told):** Tier-1 TODOs — Summarize/Rephrase/Translate/FactCheck broken, Follow-up deck send broken, Live Page blank.
