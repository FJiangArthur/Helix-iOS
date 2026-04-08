---
created: 2026-04-08T03:45:43.947Z
title: Priority pipeline — Phase 0 capture (prereq for branch A)
area: planning
status: active
blocks: merge-a-priority-pipeline
files: []
---

## Problem

Branch A (priority-pipeline) is the biggest in-flight branch and will conflict with everything else. Before it can be merged, a "Phase 0 capture" step must be done first to baseline the current pipeline behavior.

Captured 2026-04-07 as a prerequisite gate, not the merge itself.

## Solution

TBD. Phase 0 capture likely means:
- Snapshot current pipeline behavior / timing / outputs as a reference baseline
- Document the existing priority/ordering semantics so the rewrite can be compared against them
- Possibly record a hardware session as a replay fixture

User needs to define exactly what "Phase 0 capture" entails before branch A can start merging. Ask before executing.
