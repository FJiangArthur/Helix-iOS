# Native Headless Framework Rewrite

This document tracks the native rewrite foundation. New work must target headless Swift framework modules. SwiftUI belongs only in the iOS app shell.

## Target

- iOS 17+ native headless framework modules.
- Internal Swift Package modules under `NativeHelix/`.
- Fresh native storage; no Drift data migration.
- No legacy method/event channels in the final native framework.
- No UI target in the Swift package; product behavior is validated through runtime state, services, and eval reports.

## Modules

- `HelixCore`: domain models, skill presets, session memory, settings, errors, eval report schema.
- `HelixPersistence`: fresh persistence contracts and in-memory test repositories.
- `HelixAI`: answer provider protocol, deterministic provider, OpenAI request adapter, model discovery, answer style validation, fake web-search synthesis.
- `HelixSpeech`: audio-file transcription protocol, OpenAI audio-file transcriber, realtime speech session contracts, deterministic transcriber, question detection, duplicate suppression.
- `HelixConversation`: actor-based conversation engine, passive trigger classification, passive correction detection, latency metrics, native eval runner.
- `HelixG1`: G1 touchpad routing, HUD pagination, text packet encoding.
- `HelixRuntime`: headless dependency container, runtime states, and eval report harness.

## Parity Contract

The native implementation must preserve these behaviors before cutover:

- Audio file and live transcription across Apple and OpenAI backends.
- Question detection, statement suppression, duplicate question suppression, active answer generation, passive reminders.
- Passive Q&A trigger behavior with answer/ignore/wait decisions, duplicate suppression, and realtime latency metrics.
- Active skill presets for DSA, Programming, System Design, Behavioral, Discussion Strategy, General Chat, plus custom prompts.
- Rolling session memory injected into active and passive answer requests.
- Direct speakable answers without "you could say" style meta-phrasing.
- RAG answers that use project facts and expose citations/context markers.
- Deterministic web-search routing, citation markers, and optional live web-search smoke testing.
- Dynamic OpenAI model discovery with fallback model lists.
- Even G1 dual BLE, packet protocol, touchpad page navigation, text HUD, bitmap HUD, and diagnostics.
- Session history, conversation details, costs, post-conversation analysis, facts, memories, todos, projects, settings, provider keys, and debug/eval controls.

## Gates

Run the native package gate directly:

```bash
bash scripts/run_native_swift_gate.sh
```

The native gate explicitly builds the `HelixRuntime` target, then runs the package tests.

Run it as part of the main gate:

```bash
HELIX_RUN_NATIVE_SWIFT_GATE=1 bash scripts/run_gate.sh
```

The legacy conversation-quality gate is intentionally disabled for headless native work:

```bash
HELIX_RUN_CONVERSATION_EVAL=1 bash scripts/run_gate.sh
```

That command exits with a gate failure. Use the native Swift gate and native eval report harness for current headless validation.

The native eval runner currently covers deterministic transcription, question detection, statement suppression, duplicate suppression, passive correction latency, passive trigger routing, active answer style, skill/session-memory behavior, RAG context use, fake web-search synthesis, OpenAI model discovery fallback, G1 packet encoding, and report aggregation.

Live OpenAI smoke testing is opt-in and uses only the inherited shell environment key:

```bash
HELIX_RUN_LIVE_OPENAI_EVAL=1 swift test --package-path NativeHelix --filter NativeConversationTests/testLiveOpenAIAnswerProviderWithEnvironmentKeyWhenRequested
```

The test skips by default, never writes `OPENAI_API_KEY`, and fails if the opt-in flag is set without a key.

`HelixNativeEvalGateHarness` runs the native eval runner and writes both report artifacts for CI or simulator eval mode:

- `helix_eval_report.json`: schema-compatible gate report with `overall`, `startedAt`, `gitSha`, `simulatorUdid`, `latencySummary`, and `checks`.
- `helix_eval_report.md`: compact human-readable summary table with each check's pass/fail status, latency, expected result, actual result, and details.

UI assets are intentionally out of scope for this package. Runtime tests assert feature coverage without icon PNGs or SwiftUI views.
