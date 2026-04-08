# Multi-Track Orchestration Design — 2026-04-08

**Status:** Approved (fast-path), dispatching
**Owner:** Orchestrator agent (this session)
**Recovery anchor:** This file + `.planning/orchestration/STATUS.md` + `docs/PROGRESS.md` "Multi-Track Orchestration 2026-04-08" section

## Goal

Ship fixes/features for 10 parallel items across Tier-1/2/3, minimize physical-device time, maximize simulator coverage via the `ios-sim-validation` skill (mcp__ios-simulator tools), parallel execution via git worktrees where safe, single orchestrator agent tracking end-to-end state until merged to `main`.

## Non-goals

No unrelated refactors. No architectural rewrites. Each workstream stays focused on its acceptance criteria.

## Workstream Inventory

| WS | Tier | ID | Item | Mode | Hardware? |
|---|---|---|---|---|---|
| WS-A | 1 | #1 | Tool buttons (summarize/rephrase/translate/factcheck) broken | single-phase | Sim only |
| WS-B | 1 | #2 | Live page goes blank mid-session | two-phase | Sim first, HW fallback |
| WS-C | 1 | #3 | Q&A button on live session fails | single-phase | Sim only |
| WS-D | 1 | #5 | HUD factory-default reset after session start | two-phase | Sim repro attempt, HW verify |
| WS-E | 1 | #8 | Active fact-check w/ live web search (new feature, promoted) | two-phase | Sim only |
| WS-F | 1 | #10 | Ring-remote HID → triggerQA (new feature) | two-phase | HW for final bind, sim for inspector |
| WS-G | 1 | #9 | Thermal #1–#5 + AGX firehose + audio reactivation storm | two-phase | Mostly sim, HW for thermal confirm |
| WS-H | 2 | #6 | Bitmap HUD 4× word-enlargement | single-phase | Sim for generation, HW for final |
| WS-I | 2 | #7 | Debug-log reduction (release + BLE) | single-phase | Sim only |
| WS-J | 3 | #4 | EvenAI listening indicator flash (demoted) | single-phase | HW required for visual |

## Dependency Graph & Worktrees

Hot-file conflict map:

| File | Touched by |
|---|---|
| `lib/services/conversation_engine.dart` | WS-A, WS-C, WS-E |
| `lib/services/evenai.dart` | WS-D, WS-F, WS-J |
| `lib/services/llm/llm_service.dart` | WS-A, WS-C, WS-E |
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | WS-D, WS-H |
| `ios/Runner/AppDelegate.swift` | WS-F, WS-G |
| `ios/Runner/BluetoothManager.swift` | WS-D, WS-G, WS-I |
| `ios/Runner/SpeechStreamRecognizer.swift` | WS-G |
| `lib/screens/home/*` | WS-A, WS-C, WS-F (inspector), WS-J |

Parallel groups (4 worktrees concurrent):

- **Group α — Conversation engine cluster** — WS-A → WS-C → WS-E (sequential inside)
  Worktree branch: `helix-group-alpha`
- **Group β — HUD + glasses cluster** — WS-D → WS-H (sequential inside)
  Worktree branch: `helix-group-beta`
- **Group γ — iOS native perf cluster** — WS-G → WS-I (sequential inside)
  Worktree branch: `helix-group-gamma`
- **Group δ — Ring remote HID** — WS-F (isolated)
  Worktree branch: `helix-group-delta`
- **Group ε — Listening flash** — WS-J runs Tier-3, post-merge to main, no worktree

Merge order to main (one at a time, gate must pass between each):
1. γ → 2. δ → 3. β → 4. α → 5. WS-J on top of merged main

Smallest blast radius first, biggest last. Halt on first gate failure and report.

## Orchestrator Agent

A single persistent orchestrator runs in the foreground in this session. It does not write code itself.

Responsibilities:
1. Create 4 worktrees via `superpowers:using-git-worktrees`
2. Dispatch investigation agents for two-phase workstreams (WS-B, WS-D, WS-E, WS-F, WS-G) — RCA + proposed fix only, no code
3. Review investigation reports, then dispatch fix agents with the approved plan
4. For single-phase workstreams (WS-A, WS-C, WS-H, WS-I, WS-J), dispatch one fix agent each
5. After each workstream's fix returns, run `bash scripts/run_gate.sh` inside that worktree
6. Run `ios-sim-validation` skill (mcp__ios-simulator tools) per WS sim test plan
7. Merge to main in prescribed order, gate between each
8. Report blockers; never silently retry
9. Maintain `.planning/orchestration/STATUS.md` with per-WS state: `not_started | investigating | review | fixing | sim_validating | gate_passing | merged | blocked`

Subagent types used:
- `gsd-debugger` — two-phase investigation for WS-B, WS-D
- `feature-dev:code-explorer` — two-phase exploration for WS-E, WS-F, WS-G
- `general-purpose` — single-phase fixes
- `feature-dev:code-reviewer` — runs after each fix agent, before gate
- `pr-review-toolkit:silent-failure-hunter` — once on merged main before WS-J

Subagent prompts MUST include: (a) acceptance criteria verbatim, (b) relevant CLAUDE.md constraints, (c) sim validation requirement with `mcp__ios-simulator__*` tool names, (d) worktree path, (e) "do not touch files outside this list" guard.

## Per-Workstream Acceptance & Sim Test Plan

| WS | Acceptance | Sim test | HW test |
|---|---|---|---|
| **A** Tool buttons | Tap each of summarize/rephrase/translate/factcheck on a finalized segment → handler fires, LLM stream returns, response renders, no errors | `ui_tap` each button, screenshot diff, assert text via `ui_describe_all` | None |
| **B** Live page blank | Bug repro recorded, RCA documented, fix verified by 5-min continuous session w/o blank state | Long-run session via `record_video`, `ui_view` snapshots every 30s | Only if sim can't repro |
| **C** Q&A button | Q&A on active session returns answer, no "assistant request failed" | Start session, tap Q&A, assert response renders | None |
| **D** HUD factory-default | RCA documented (BLE timing? thermal? init race?); 10 sequential session-starts with no factory reset | Test underlying state-machine path with unit tests; visual on HW | HW for visual confirm |
| **E** Active fact-check w/ web search | Design doc → provider chosen → impl behind flag → answers cite sources → integrated into existing fact-check pipeline | Start session, ask claim question, verify cited response | None |
| **F** Ring remote → triggerQA | Inspector logs all 4 channels; one stable signal identified; bound to `triggerQA()`; debounced; dead-button doc | Inspector screen rendered, simulated key events via `ui_tap`/press analogue, bind verified via mock event | HW required for actual ring pairing + final bind |
| **G** Thermal #1–#5 + AGX + audio storm | Each of 7 hotspots: measured before, patched, measured after, delta documented | Instruments via Bash, sim profiling for allocation/encode rates | HW for thermal state confirm |
| **H** Bitmap HUD 4× zoom | New render path produces 4× word bitmap, graceful fallback, gated by setting | Render to PNG, snapshot test, in-app preview | HW for final G1 render |
| **I** Debug log gating | Release log volume ≥80% reduction on BLE + remaining noisy paths | Run release in sim, count log lines vs baseline | None |
| **J** Listening flash (Tier-3) | Indicator stable through stream; no flash in 500ms window | State-machine unit tests | HW for visual confirm |

## Tracking & Recovery

Artifacts (all under `.planning/orchestration/`):
- `STATUS.md` — live state table, updated after every subagent return
- `reports/WS-{A..J}-investigation.md` — RCA reports (two-phase only)
- `reports/WS-{A..J}-fix.md` — fix agent reports
- `reports/WS-{A..J}-sim-validation.md` — `ios-sim-validation` outcomes

Recovery on system fault: read this spec + `STATUS.md` + `docs/PROGRESS.md` orchestration section → resume from last `merged` state.

TaskList in this session mirrors STATUS.md (one task per WS).

## Integration Sequence (strict)

1. Each worktree finishes its workstreams + local gate passes
2. Merge γ → main, run full `bash scripts/run_gate.sh`, sim smoke
3. Merge δ → main, gate, smoke
4. Merge β → main, gate, smoke
5. Merge α → main, gate, smoke
6. After all four merged: run `pr-review-toolkit:silent-failure-hunter` on cumulative diff
7. Branch off main for WS-J, fix, gate, merge
8. Final validation: full gate + scripted `ios-sim-validation` end-to-end happy path per WS + hardware checklist for G1 + ring remote

## Halt Conditions

- Any gate failure that fix agent + one retry can't resolve
- Investigation reveals root cause requires architectural change beyond scope
- Sim validation cannot reach a code path and HW unavailable
- Merge conflict requiring human judgment

## Backout Plan

Every merge is its own commit (no squash). Any WS revertible individually with `git revert` if a downstream gate fails post-merge.
