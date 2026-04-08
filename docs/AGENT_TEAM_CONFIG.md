# Validation Agent Team

6-agent team for `ios-sim-validation` skill. Execution gates and
criteria live in `docs/SIMULATOR_VALIDATION_PROTOCOL.md` — this file
only documents the team composition.

## Roles

| Role | Type | Gates | Key responsibility |
|---|---|---|---|
| PM | plan | 0-5 | Gate pass/fail, priority triage, sign-off veto |
| Product Manager | plan | 1, 2, 5 | User-flow validation, UX quality, regression vs spec |
| SDE | general | 2, 3, 4, 5 | Debug failures, arch validation, known-bug regression |
| MLE | general | 3, 5 | LLM integration (real API), streaming, model switch |
| QA Engineer | general | 1-5 | Execute criteria, edge cases, bug documentation |
| Test Engineer | general | 0, 1, 5 | Simulator lifecycle, fixtures, screenshots, reports |

## Parallelism

- **Gate 0** — Test Engineer, solo sequential (pre-flight)
- **Gate 1** — QA + Product Manager + Test Engineer in parallel
- **Gate 2** — QA primary, PM parallel UX review, SDE standby
- **Gate 3** — MLE primary sequential, Test Engineer + QA parallel
- **Gate 4** — QA primary, SDE parallel analysis
- **Gate 5** — All 6 roles parallel; ALL must APPROVE

## Rules

- **PM authority:** Gate 0/1/4/5 must be 100% pass. Gate 2 allows 1
  non-critical miss with PM ack. Gate 3 requires ≥5/6 LLM tests pass.
- **Test Engineer owns the simulator.** Always create fresh
  `Helix-QA-*` instance. Never reuse `0D7C3AB2` or `6D249AFF` (belong
  to other projects). Grant mic + speech-recognition permissions.
- **On any gate failure** → SDE activates, Test Engineer pauses tear-
  down, PM triages P0/P1/P2.
- **Invocation:** `/ios-sim-validation` or manual per protocol doc.
  Post-run hook `scripts/helix_sim_validation_hook.sh` reminds after
  `lib/` or `ios/` changes.

## Escalation

| Failure | Action |
|---|---|
| Gate 0 | STOP, fix code |
| Gate 1 | STOP, UI broken |
| Gate 2 settings (F2.1-F2.5) | STOP, SDE investigates |
| Gate 2 non-settings | PM decides |
| Gate 3 API setup | STOP, check key |
| Gate 3 LLM query | Continue if ≥5/6 |
| Gate 4 | STOP, regression detected |
| Gate 5 | Rejecting role documents reason, team discusses |
