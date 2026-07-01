# Simulator Validation Protocol

Swift-native validation pipeline for Helix-iOS. Runs on a dedicated iOS
simulator and keeps the retired Flutter harness out of the release path.

- **When:** After code changes to `NativeHelix/` or `ios/`
- **Duration:** ~30-40 min
- **Invoke:** `/ios-sim-validation` skill

## Prerequisites

- Xcode 27.0+, iOS Simulator runtime 27.0
- OpenAI API key with `gpt-4o-mini` and `gpt-4o-mini-transcribe`
  access. The eval scripts prefer `HELIX_TEST_OPENAI_KEY`; if it is unset
  they use Codex's `OPENAI_API_KEY`.
- `bash scripts/run_gate.sh` passes
- `mcp__ios-simulator__*` tools available

## Conversation eval gate

The old Flutter conversation-quality eval gate is retired. The default
pre-release gate is the native gate:

```bash
bash scripts/run_gate.sh
```

It runs:

- the security gate
- the `NativeHelix` headless boundary check
- `swift build --package-path NativeHelix --target HelixRuntime`
- `swift test --package-path NativeHelix`

The native eval runner still writes schema-compatible reports when invoked
from native test or harness code:

- `/tmp/Helix-QA/helix_eval_report.json`
- `/tmp/Helix-QA/helix_eval_report.md`
- the simulator app container at
  `Documents/helix_eval_report.json` and `Documents/helix_eval_report.md`

The JSON schema is:

```json
{
  "overall": "PASS",
  "startedAt": "2026-06-29T00:00:00.000Z",
  "gitSha": "abcdef0",
  "simulatorUdid": "....",
  "latencySummary": {"p50Ms": 123, "p95Ms": 456},
  "checks": [
    {
      "id": "Q1",
      "area": "question-detection",
      "status": "PASS",
      "latencyMs": 120,
      "expected": "...",
      "actual": "...",
      "details": "..."
    }
  ]
}
```

### Audio fixture setup

Downloaded YouTube audio is local-only and not committed. Keep any temporary
audio corpus outside the repo, using only Creative Commons or user-authorized
sources, then run native package tests against explicit local fixture paths.

```bash
swift test --package-path NativeHelix --filter NativeConversationTests
```

Do not commit downloaded audio.

### Latency policy

Hard failures: deterministic local pipeline checks must complete under 1s
from transcript finalization to reminder, detection, or first answer text.

Report-only latency: live OpenAI audio transcription and other network-bound
checks are measured and shown in the report, but do not fail the gate solely
for exceeding 1s. Correctness failures still fail their own check.

## Simulator setup

**Never reuse existing simulators** — `0D7C3AB2` and `6D249AFF` belong
to other projects. Always create a fresh `Helix-QA-*` instance.

```bash
SIM_UDID=$(xcrun simctl create "Helix-QA-$(date +%H%M%S)" \
  "iPhone 17 Pro" "com.apple.CoreSimulator.SimRuntime.iOS-27-0")
xcrun simctl boot "$SIM_UDID"
xcrun simctl privacy "$SIM_UDID" grant microphone com.artjiang.helix
xcrun simctl privacy "$SIM_UDID" grant speech-recognition com.artjiang.helix
xcodebuild -workspace "ios/Even Companion.xcworkspace" -scheme Runner \
  -configuration Debug -destination "platform=iOS Simulator,id=$SIM_UDID" \
  CODE_SIGNING_ALLOWED=NO build
mkdir -p /tmp/Helix-QA
```

Pass `$SIM_UDID` to every MCP tool call.

## Gates

### Gate 0 — Pre-flight (Test Engineer, ~3 min, blocking)

Checks, all must pass: `bash scripts/run_gate.sh`, clean Xcode simulator
build, create + boot dedicated simulator, install + launch app, screenshot
proof that Helix is foregrounded.

### Gate 1 — UI Smoke (QA + PM parallel, ~5 min, blocking)

**1A Onboarding (S1.1-S1.5):** 4 pages traversable (Welcome, Smart
Listening, Your Choice of AI, Glasses + Phone), "Skip" on pages 1-3,
"Get Started" on page 4 transitions to MainScreen with 5 nav dests.

**1B Tab nav (S1.6-S1.11):** All 5 tabs render
(Assistant/Device/Sessions/Knowledge/Settings), white theme confirmed.

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
