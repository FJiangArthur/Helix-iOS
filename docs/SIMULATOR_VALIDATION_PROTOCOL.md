# Helix-iOS Multi-Agent Simulator Validation Protocol

## Overview

This protocol defines a 6-gate validation pipeline for the Helix-iOS app, executed by a 6-role agent team on a dedicated iOS simulator. It validates UI rendering, functional behavior, real LLM integration (gpt-4o-mini), audio fixture integrity, and regression safety.

**When to run:** After any code change to `lib/` or `ios/` files. A post-run hook reminds the developer automatically.

**Duration:** ~30-40 minutes end-to-end.

## Prerequisites

- Xcode 26.3+, Flutter 3.35+, iOS Simulator runtime 26.4
- OpenAI API key with gpt-4o-mini access (set via `HELIX_TEST_OPENAI_KEY` env var or entered manually)
- Audio fixtures present at `test/fixtures/` (10 WAV files per manifest)
- `bash scripts/run_gate.sh` must pass (existing 6-gate code quality pipeline)
- MCP iOS simulator tools available (`mcp__ios-simulator__*`)

## Simulator Setup

**CRITICAL: Never reuse existing simulators.** `0D7C3AB2` (Album Clean) and `6D249AFF` (Pet App) belong to other projects.

```bash
# Create dedicated simulator
SIM_UDID=$(xcrun simctl create "Helix-QA-$(date +%H%M%S)" \
  "iPhone 17 Pro" "com.apple.CoreSimulator.SimRuntime.iOS-26-4")
echo "Created: $SIM_UDID"

# Boot
xcrun simctl boot "$SIM_UDID"

# Grant permissions
xcrun simctl privacy "$SIM_UDID" grant microphone com.artjiang.helix
xcrun simctl privacy "$SIM_UDID" grant speech-recognition com.artjiang.helix

# Build, install, launch
flutter build ios --simulator --no-codesign
# Then use mcp__ios-simulator__install_app and mcp__ios-simulator__launch_app
```

Store `$SIM_UDID` and pass it to ALL MCP tool calls. Create screenshot directory:

```bash
mkdir -p /tmp/Helix-QA
```

---

## Gate 0: Pre-flight

**Owner:** Test Engineer | **Duration:** ~3 min | **Blocking:** Yes

| # | Step | Command | Pass Criteria |
|---|------|---------|---------------|
| 0.1 | Static analysis | `flutter analyze --no-fatal-infos` | 0 errors |
| 0.2 | Unit tests | `flutter test test/ --reporter expanded` | All pass (127+) |
| 0.3 | Simulator build | `flutter build ios --simulator --no-codesign` | Exit code 0 |
| 0.4 | Create simulator | `xcrun simctl create "Helix-QA-..." "iPhone 17 Pro" ...` | Returns valid UDID |
| 0.5 | Boot simulator | `xcrun simctl boot $SIM_UDID` | Boots successfully |
| 0.6 | Install app | `mcp__ios-simulator__install_app` | Success |
| 0.7 | Launch app | `mcp__ios-simulator__launch_app` (bundle: `com.artjiang.helix`) | App launches |
| 0.8 | Audio fixtures | Check 10 WAV files in `test/fixtures/` | All present |

**Gate decision:** ALL 8 must pass. Any failure = STOP.

---

## Gate 1: UI Smoke

**Owners:** QA Engineer + Product Manager (parallel) + Test Engineer (screenshots) | **Duration:** ~5 min | **Blocking:** Yes

### 1A. Onboarding Flow

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| S1.1 | Page 1 shows "Welcome to Even Companion" | `ui_describe_all` + screenshot | Title text found |
| S1.2 | "Skip" button visible on pages 1-3 | `ui_describe_all` | Button found |
| S1.3 | All 4 pages traversable (Welcome, Smart Listening, Your Choice of AI, Glasses + Phone) | `ui_swipe` left 3x, verify each title | All 4 titles found |
| S1.4 | Page 4 has "Get Started", no "Skip" | `ui_describe_all` | Get Started found, Skip absent |
| S1.5 | "Get Started" transitions to MainScreen | `ui_tap` + verify NavigationBar | 5 nav destinations found |

### 1B. Tab Navigation

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| S1.6 | Home tab default (index 0), no AppBar | `ui_describe_all` | selectedIndex=0, no AppBar |
| S1.7 | Memories tab renders with title | Tap tab, `ui_describe_all` | AppBar = "Memories" |
| S1.8 | Facts tab renders with title | Tap tab | AppBar = "Facts" |
| S1.9 | Buzz tab renders with starter chips | Tap tab | Title = "Buzz", 3 chips visible |
| S1.10 | Settings tab renders with title | Tap tab | AppBar = "Settings" |
| S1.11 | Dark theme confirmed | Screenshot analysis | Dark background |

**Gate decision:** All 11 must pass. 1 failure = STOP.

---

## Gate 2: Functional

**Owners:** QA Engineer (primary) + Product Manager (UX) + SDE (debug on failure) | **Duration:** ~8 min

### 2A. Settings Configuration

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| F2.1 | All 6 providers visible (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu, SiliconFlow) | Navigate Settings, `ui_describe_all` | All names found |
| F2.2 | Selecting OpenAI shows model dropdown | `ui_tap` on OpenAI row | Dropdown appears |
| F2.3 | API key field accepts text | `ui_tap` key field, `ui_type` test key | Text entered |
| F2.4 | "Test Connection" button exists | `ui_describe_all` | Button found |
| F2.5 | Model dropdown contains gpt-4.1 family | After valid key, check dropdown | gpt-4.1, gpt-4.1-mini, gpt-4.1-nano |

### 2B. Home Screen

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| F2.6 | Mode selector visible | Navigate Home, `ui_describe_all` | Mode selector found |
| F2.7 | Switch between general/interview/passive/proactive | Tap each mode | Mode label updates |
| F2.8 | Ask field accepts text | `ui_tap` + `ui_type` "test question" | Text appears |
| F2.9 | Preset chips visible (Concise, Speak For Me, Interview, Fact Check) | `ui_describe_all` | All 4 found |

### 2C. Buzz Screen

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| F2.10 | 3 starter chips visible | `ui_describe_all` on Buzz tab | All 3 chip texts found |
| F2.11 | Message input field present | `ui_describe_all` | TextField found |

### 2D. Facts Screen

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| F2.12 | Pending section visible | `ui_describe_all` | Section found |
| F2.13 | Search available | `ui_describe_all` | Search element found |

**Gate decision:** >= 12/13 must pass. Any failure in F2.1-F2.5 (settings) = STOP. PM decides acceptability of 1 non-critical failure.

---

## Gate 3: Integration (Real API)

**Owners:** MLE (primary) + Test Engineer (audio) + QA (execution) + SDE (debug) | **Duration:** ~10 min

### 3A. API Setup (prerequisite)

| # | Step | Method |
|---|------|--------|
| I3.0a | Navigate to Settings | `ui_tap` Settings tab |
| I3.0b | Select OpenAI provider | `ui_tap` OpenAI row |
| I3.0c | Enter real API key | `ui_tap` key field, `ui_type` with real key |
| I3.0d | Open custom model dialog | `ui_tap` edit button next to model selector |
| I3.0e | Enter `gpt-4o-mini` | `ui_type` in custom model field, confirm |
| I3.0f | Test connection | `ui_tap` "Test Connection" |
| I3.0g | Verify success | `ui_describe_all` — success indicator visible |

### 3B. LLM via Buzz Chat

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| I3.1 | Send "What is photosynthesis in one sentence?" | Navigate Buzz, type + send | Response within 15s |
| I3.2 | Response is coherent | `ui_describe_all` | Contains "light" or "plant" or "energy" |
| I3.3 | Follow-up "Explain to a 5 year old" | Type + send | Response received, simpler language |

### 3C. LLM via Home Ask Field

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| I3.4 | Send "What is 2+2?" via ask field | Navigate Home, type + submit | AI response appears |
| I3.5 | Response contains "4" | `ui_describe_all` | "4" found in response |
| I3.6 | Streaming indicator during response | Screenshot during streaming | Streaming UI visible |

### 3D. Audio & Transcription Verification

| # | Criterion | Method | Pass |
|---|-----------|--------|------|
| I3.7 | 10 audio fixtures present | File system check against manifest | All present |
| I3.8 | Transcription pipeline tests pass | Gate 0 unit test results | 9/9 pass |

**Note:** The iOS simulator cannot receive mic input from WAV files. Audio fixtures are validated at the unit test level. Future enhancement: add debug `AudioFileInjector` service for end-to-end simulator audio testing.

**Gate decision:** I3.0a-g ALL pass (API setup). >= 5/6 of I3.1-I3.6 pass. I3.7-I3.8 pass.

---

## Gate 4: Regression

**Owners:** QA Engineer + SDE | **Duration:** ~5 min

| # | Bug | Criterion | Method | Pass |
|---|-----|-----------|--------|------|
| R4.1 | BUG-001 | No crash during 30s Home screen use | Interact with Home, wait | No crash |
| R4.2 | BUG-002 | Analytics unit tests pass with 500ms delays | Gate 0 results | Tests pass |
| R4.3 | BUG-003 | Gesture interactions no crash | Tap/swipe on Home | No crash |
| R4.4 | BUG-005 | Rapid mode switching (5x) no crash | Switch modes rapidly | No crash |
| R4.5 | BUG-006 | Noise reduction toggle no crash | Toggle in Settings if present | No crash |
| R4.6 | General | All 5 tabs still accessible post-integration | Navigate all tabs | All render |

**Gate decision:** ALL 6 must pass. Any crash = STOP.

---

## Gate 5: Sign-off

**All 6 roles** | **Duration:** ~2 min

| Role | Approval Criteria |
|------|-------------------|
| **PM** | All gates passed, risk acceptable, no P0 blockers |
| **Product Manager** | All user flows validated, UX acceptable, no feature regressions |
| **SDE** | No architectural issues, no crashes, performance acceptable |
| **MLE** | LLM integration working, response quality acceptable with gpt-4o-mini |
| **QA Engineer** | All criteria met, bugs documented, edge cases covered |
| **Test Engineer** | Simulator stable, results collected, report generated |

**Gate decision:** ALL 6 must APPROVE. Any REJECT = FAIL with documented reason.

---

## Report Template

```markdown
# Helix-iOS Simulator Validation Report

**Date:** YYYY-MM-DD HH:MM
**Version:** 2.2.0+9
**Simulator:** <UDID> (iPhone 17 Pro, iOS 26.4)
**API Model:** gpt-4o-mini
**Total Duration:** XX minutes

## Gate Results

| Gate | Name | Result | Duration | Failures |
|------|------|--------|----------|----------|
| 0 | Pre-flight | PASS/FAIL | Xm Xs | N |
| 1 | UI Smoke | PASS/FAIL | Xm Xs | N |
| 2 | Functional | PASS/FAIL | Xm Xs | N |
| 3 | Integration | PASS/FAIL | Xm Xs | N |
| 4 | Regression | PASS/FAIL | Xm Xs | N |
| 5 | Sign-off | PASS/FAIL | Xm Xs | N |

## Detailed Results
[Per-gate tables with individual criterion pass/fail and evidence]

## Sign-off Matrix
| Role | Decision | Notes |
|------|----------|-------|
| PM | APPROVE/REJECT | ... |
| Product Manager | APPROVE/REJECT | ... |
| SDE | APPROVE/REJECT | ... |
| MLE | APPROVE/REJECT | ... |
| QA Engineer | APPROVE/REJECT | ... |
| Test Engineer | APPROVE/REJECT | ... |

## Screenshots
[Saved at /tmp/Helix-QA/ with naming: S1.1-onboarding-page1.png, F2.3-api-key.png, etc.]

## Issues Found
[New bugs discovered, format: BUG-NNN | Severity | Component | Description]

## Recommendations
[Improvements suggested by each role]
```

---

## Cleanup

After validation is complete (user confirms):

```bash
xcrun simctl shutdown "$SIM_UDID"
xcrun simctl delete "$SIM_UDID"
```

Do NOT delete between test iterations. Only when the full session is done.
