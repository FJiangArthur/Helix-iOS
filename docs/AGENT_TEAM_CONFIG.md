# Helix-iOS Validation Agent Team Configuration

## Team Overview

| Property | Value |
|----------|-------|
| Team Name | `helix-sim-validation` |
| Team Size | 6 agents |
| Execution Model | Gated-parallel (strict gate ordering, parallelism within gates) |
| Target App | Helix-iOS (`com.artjiang.helix`) |
| Simulator | Dedicated `Helix-QA-*` instance (iPhone 17 Pro, iOS 26.4) |

---

## Agent Definitions

### 1. PM (Project Manager)

| Property | Value |
|----------|-------|
| Role ID | `pm` |
| Agent Type | `plan` |
| Gate Ownership | 0, 1, 2, 3, 4, 5 |
| Decision Authority | Gate pass/fail, priority triage |

**Responsibilities:**
- Define and enforce acceptance criteria for each gate
- Make go/no-go decisions at gate boundaries
- Risk assessment after each gate completes
- Priority triage for failures: P0 (blocker), P1 (critical), P2 (minor)
- Final sign-off authority (can veto if risk is unacceptable)

**Decision rules:**
- Gate 0: ALL criteria must pass
- Gate 1: ALL 11 criteria must pass
- Gate 2: >= 12/13 pass; any settings failure (F2.1-F2.5) = STOP
- Gate 3: API setup ALL pass; >= 5/6 API tests pass; fixtures pass
- Gate 4: ALL 6 must pass
- Gate 5: ALL 6 roles must APPROVE

---

### 2. Product Manager

| Property | Value |
|----------|-------|
| Role ID | `product_manager` |
| Agent Type | `plan` |
| Gate Ownership | 1, 2, 5 |
| Parallel With | QA Engineer |

**Responsibilities:**
- Validate user flows match product spec in `CLAUDE.md` Product Overview
- Feature completeness checks against documented user flows
- UX quality assessment (theme consistency, layout, responsiveness, animations)
- Regression identification vs previously validated state
- Ensure onboarding flow matches 4-page spec (Welcome, Smart Listening, Your Choice of AI, Glasses + Phone)

**Key references:**
- `CLAUDE.md` > Product Overview > User Flows
- `CLAUDE.md` > Configuration table
- `docs/product-overview.md`

---

### 3. SDE (Software Development Engineer)

| Property | Value |
|----------|-------|
| Role ID | `sde` |
| Agent Type | `general` |
| Gate Ownership | 2, 3, 4, 5 |
| Activation | Triggered on any gate failure |

**Responsibilities:**
- Debug test failures at code level with file:line references
- Provide fix recommendations (not implement fixes during validation)
- Architecture validation (singleton patterns, stream disposal, memory leaks)
- Performance assessment (no UI jank, reasonable load times)
- Verify known bugs (BUG-001 through BUG-006) are not causing new issues

**Key files to investigate on failure:**
- `lib/services/conversation_engine.dart` — core pipeline
- `lib/services/llm/llm_service.dart` — provider management
- `lib/services/llm/openai_provider.dart` — model filtering
- `lib/screens/settings_screen.dart` — settings UI
- `lib/app.dart` — navigation structure

---

### 4. MLE (Machine Learning Engineer)

| Property | Value |
|----------|-------|
| Role ID | `mle` |
| Agent Type | `general` |
| Gate Ownership | 3, 5 |
| Primary For | Gate 3 (Integration) |
| Requires | OpenAI API key |

**Responsibilities:**
- LLM provider integration testing with real gpt-4o-mini API
- Configure model via Settings > Custom Model dialog
- Evaluate AI response quality (coherence, relevance, latency)
- Transcription quality assessment from unit test results
- Model selection and switching validation
- Verify streaming behavior (response appears incrementally)

**API testing protocol:**
1. Enter API key via Settings UI
2. Set custom model to `gpt-4o-mini`
3. Test connection
4. Send test queries via Buzz and Home ask field
5. Evaluate response quality against criteria

**Quality criteria for responses:**
- Coherent and relevant to the question
- Completes within 15 seconds
- Streams incrementally (not all-at-once)
- No error messages or empty responses

---

### 5. QA Engineer

| Property | Value |
|----------|-------|
| Role ID | `qa_engineer` |
| Agent Type | `general` |
| Gate Ownership | 1, 2, 3, 4, 5 |
| Parallel With | Product Manager (Gates 1, 2) |

**Responsibilities:**
- Execute all simulator test criteria systematically
- Document bugs in standard format (BUG-NNN | Severity | Component | Description)
- Edge case testing: rapid tapping, empty states, long text input, quick navigation
- Regression testing against known bugs (BUG-001 through BUG-006)
- Verify element existence via accessibility tree (ground truth)

**Testing methodology:**
1. Navigate to target screen
2. Wait 2s for animations to settle
3. Run `mcp__ios-simulator__ui_describe_all` (accessibility = ground truth)
4. Take `mcp__ios-simulator__screenshot` (visual verification)
5. Evaluate against criterion
6. Record pass/fail with evidence

**Edge cases to test:**
- Empty text submission in ask field
- Rapid tab switching (5+ switches in 2s)
- Long text input (200+ characters)
- Back-to-back mode switches
- Scroll behavior on Facts/Memories with no data

---

### 6. Test Engineer

| Property | Value |
|----------|-------|
| Role ID | `test_engineer` |
| Agent Type | `general` |
| Gate Ownership | 0, 1, 5 |
| Owns Simulator | Yes (sole authority to create/boot/delete) |

**Responsibilities:**
- Simulator lifecycle: create, boot, install, launch, cleanup
- Run pre-flight checks (analyze, test, build)
- Audio fixture verification against manifest
- MCP tool orchestration and screenshot capture
- Results collection and final report generation
- Screenshot organization at `/tmp/Helix-QA/`

**Simulator rules:**
- ALWAYS create fresh `Helix-QA-*` instance
- NEVER reuse `0D7C3AB2` or `6D249AFF`
- Pass `udid` to EVERY MCP tool call
- Grant microphone + speech-recognition permissions
- Wait 3s after app launch before any interaction
- Wait 2s after navigation before `ui_describe_all`

---

## Parallel Execution Map

```
Gate 0 (Pre-flight):
  ┌──────────────────┐
  │  Test Engineer    │  sequential, solo
  └──────────────────┘

Gate 1 (UI Smoke):
  ┌──────────────────┐
  │  QA Engineer      │──> onboarding + tabs
  ├──────────────────┤
  │  Product Manager  │──> UX quality review      } parallel
  ├──────────────────┤
  │  Test Engineer    │──> screenshot capture
  └──────────────────┘

Gate 2 (Functional):
  ┌──────────────────┐
  │  QA Engineer      │──> settings + modes + screens  (primary)
  ├──────────────────┤
  │  Product Manager  │──> UX review alongside         (parallel)
  ├──────────────────┤
  │  SDE              │──> standby for debug           (on failure)
  └──────────────────┘

Gate 3 (Integration):
  ┌──────────────────┐
  │  MLE              │──> API setup + LLM testing     (primary, sequential)
  ├──────────────────┤
  │  Test Engineer    │──> audio fixture verification  (parallel)
  ├──────────────────┤
  │  QA Engineer      │──> assist with execution       (parallel)
  ├──────────────────┤
  │  SDE              │──> debug API failures          (on failure)
  └──────────────────┘

Gate 4 (Regression):
  ┌──────────────────┐
  │  QA Engineer      │──> regression test execution   (primary)
  ├──────────────────┤
  │  SDE              │──> analyze regressions         (parallel)
  └──────────────────┘

Gate 5 (Sign-off):
  ┌──────────────────┐
  │  All 6 roles      │──> parallel approval (ALL must approve)
  └──────────────────┘
```

---

## Invocation

To run the full validation protocol, invoke the `ios-sim-validation` skill:

```
/ios-sim-validation
```

Or run manually following `docs/SIMULATOR_VALIDATION_PROTOCOL.md`.

The post-run hook at `scripts/helix_sim_validation_hook.sh` automatically reminds developers to run validation after `lib/` or `ios/` changes.

---

## Failure Escalation

| Failure Type | Action |
|---|---|
| Gate 0 failure | STOP. Fix code issues before any simulator testing. |
| Gate 1 failure | STOP. App is fundamentally broken (UI doesn't render). |
| Gate 2 failure (settings) | STOP. Core configuration is broken. SDE investigates. |
| Gate 2 failure (non-settings) | PM decides: continue with documented issue or STOP. |
| Gate 3 failure (API setup) | STOP. Cannot validate LLM integration. Check API key. |
| Gate 3 failure (query) | Continue if >= 5/6 pass. Document failures. |
| Gate 4 failure | STOP. Regression detected. SDE investigates before sign-off. |
| Gate 5 rejection | STOP. Rejecting role documents reason. Team discusses resolution. |
