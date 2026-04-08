# Simulator Validation Protocol

6-gate validation pipeline for Helix-iOS. Runs on a dedicated iOS
simulator with the agent team in `docs/AGENT_TEAM_CONFIG.md`.

- **When:** After code change to `lib/` or `ios/`
- **Duration:** ~30-40 min
- **Invoke:** `/ios-sim-validation` skill

## Prerequisites

- Xcode 26.3+, Flutter 3.35+, iOS Simulator runtime 26.4
- OpenAI API key with `gpt-4o-mini` access
  (`HELIX_TEST_OPENAI_KEY` env var)
- 10 WAV audio fixtures at `test/fixtures/`
- `bash scripts/run_gate.sh` passes
- `mcp__ios-simulator__*` tools available

## Simulator setup

**Never reuse existing simulators** — `0D7C3AB2` and `6D249AFF` belong
to other projects. Always create a fresh `Helix-QA-*` instance.

```bash
SIM_UDID=$(xcrun simctl create "Helix-QA-$(date +%H%M%S)" \
  "iPhone 17 Pro" "com.apple.CoreSimulator.SimRuntime.iOS-26-4")
xcrun simctl boot "$SIM_UDID"
xcrun simctl privacy "$SIM_UDID" grant microphone com.artjiang.helix
xcrun simctl privacy "$SIM_UDID" grant speech-recognition com.artjiang.helix
flutter build ios --simulator --no-codesign
mkdir -p /tmp/Helix-QA
```

Pass `$SIM_UDID` to every MCP tool call.

## Gates

### Gate 0 — Pre-flight (Test Engineer, ~3 min, blocking)

8 checks, all must pass: `flutter analyze --no-fatal-infos` (0 errors),
`flutter test test/` (all pass), `flutter build ios --simulator`
(exit 0), create + boot simulator, install + launch app, 10 audio
fixtures present.

### Gate 1 — UI Smoke (QA + PM parallel, ~5 min, blocking)

**1A Onboarding (S1.1-S1.5):** 4 pages traversable (Welcome, Smart
Listening, Your Choice of AI, Glasses + Phone), "Skip" on pages 1-3,
"Get Started" on page 4 transitions to MainScreen with 5 nav dests.

**1B Tab nav (S1.6-S1.11):** All 5 tabs render
(Home/Memories/Facts/Buzz/Settings), dark theme confirmed.

Method: `ui_describe_all` + `screenshot`. All 11 must pass.

### Gate 2 — Functional (QA + PM, ~8 min)

**2A Settings (F2.1-F2.5):** 6 providers listed, OpenAI dropdown,
API key field, Test Connection button, gpt-4.1 family model list.
**Any failure in 2A = STOP.**

**2B Home (F2.6-F2.9):** mode selector, mode switching, Ask field,
4 preset chips.

**2C Buzz (F2.10-F2.11):** 3 starter chips, message input.

**2D Facts (F2.12-F2.13):** Pending section, Search.

Pass: ≥12/13 overall.

### Gate 3 — Integration with real API (MLE + Test Engineer, ~10 min)

**3A Setup (I3.0a-g):** Enter real OpenAI key, set model
`gpt-4o-mini`, Test Connection succeeds. **All of 3A must pass.**

**3B Buzz LLM (I3.1-I3.3):** "What is photosynthesis in one sentence?"
→ response within 15s, contains `light`/`plant`/`energy`. Follow-up
"Explain to a 5 year old" → simpler language.

**3C Home ask LLM (I3.4-I3.6):** "What is 2+2?" → response contains
"4", streaming indicator visible during response.

**3D Audio (I3.7-I3.8):** 10 fixtures present, 9/9 transcription
pipeline unit tests pass. Note: simulator cannot inject mic audio;
audio validation is unit-test level.

Pass: 3A all, ≥5/6 of I3.1-I3.6, I3.7/I3.8 pass.

### Gate 4 — Regression (QA + SDE, ~5 min)

Verify none of BUG-001 through BUG-006 crash on:
- 30s Home interaction
- Analytics tests with 500ms delays
- Tap/swipe gestures
- Rapid mode switching (5x)
- Noise reduction toggle
- All 5 tabs still accessible

All 6 must pass. Any crash = STOP.

### Gate 5 — Sign-off (all 6 roles, ~2 min)

Each role independently APPROVE/REJECT. ALL 6 must APPROVE.

## Cleanup

Only after full session is done:

```bash
xcrun simctl shutdown "$SIM_UDID"
xcrun simctl delete "$SIM_UDID"
```

## Report

Save to `/tmp/Helix-QA/report.md` with per-gate tables (criterion
pass/fail + evidence), sign-off matrix, new bugs in
`BUG-NNN | Severity | Component | Description` format. Screenshots at
`/tmp/Helix-QA/` named by criterion (`S1.1-onboarding-page1.png`, etc.).
