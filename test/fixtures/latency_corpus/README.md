# Latency Corpus

Fixed set of 20 recorded conversation clips used for Phase 2 latency
regression measurement. See design doc
`~/.gstack/projects/FJiangArthur-Helix-iOS/artjiang-main-design-20260415-120339.md`
Phase 0 / Phase 2 sections.

## Purpose

This corpus is the **authoritative baseline** for the end-to-end latency
measurement (speech endpoint → first HUD page). Phase 2's 40% p50 reduction
target (and p95 no-regression gate) is evaluated against runs of this corpus
BEFORE vs. AFTER Phase 2 changes.

Phase 2's baseline is re-captured AFTER Phase 1 lands (so prep's 8k-token
overhead is included in the baseline). Do not compare Phase 2 against the
pre-Phase-1 baseline.

## Format

Each clip is a 16 kHz mono `.wav` file, 5 to 30 seconds long. Files are
named `clipNN-<kind>.wav` where `NN` is zero-padded 01-20 and `<kind>` is
one of:

- `qa`  — a speaker asking a question the AI should answer (8 clips)
- `st`  — a statement/assertion with no question (6 clips)
- `he`  — a speaker hesitating mid-sentence (3 clips)
- `mt`  — multi-turn back-and-forth (3 clips)

Mix tuned to exercise both the detection classifier (QA triggers, `st`
should NOT trigger) and endpoint handling (hesitations stress the endpointing
heuristic). Tail cases (multi-turn) stress the session state machine.

## Adding clips

1. Record at 16 kHz mono, 16-bit PCM, `.wav`.
2. Trim leading/trailing silence to <200 ms.
3. Save to this directory with the naming convention above.
4. Do NOT commit voice recordings to the repo; they are .gitignored (see
   the top-level `.gitignore`). The `manifest.json` tracks per-clip metadata
   (duration, expected markers) — that IS committed.

## Running a baseline

```
dart run tool/latency_baseline.dart \
  --corpus test/fixtures/latency_corpus/ \
  --output test/fixtures/latency_corpus/baseline.json
```

Script reads `$APPLICATION_DOCUMENTS_DIRECTORY/latency_markers.jsonl` emitted
by `LatencyTracker` after replaying each clip, computes p50/p95/p99 of the
(speechEndpoint → hudFirstPage) interval, and writes `baseline.json`.

Baselines are timestamped and tagged with git HEAD; keep the pre-Phase-1
and post-Phase-1 baselines side-by-side for Phase 2 to diff against.

## Current status

- Directory scaffolded: YES
- Clips committed: NO (recorded separately by the human operator)
- manifest.json: PENDING
- baseline.json: PENDING first run
