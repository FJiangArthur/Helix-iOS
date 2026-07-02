# Development Progress

Current version: **2.2.95+202607012117**

## Current Architecture

- **NativeHelix**: headless Swift package for conversation, AI, speech, G1 HUD, runtime state, and persistence.
- **iOS app shell**: SwiftUI surfaces under `ios/Runner`.
- **Validation**: `bash scripts/run_gate.sh` runs security, boundary, package build, and package tests. `bash scripts/install_git_hooks.sh` installs the pre-commit and pre-push gates.
- **Simulator policy**: use a dedicated `Helix-QA-*` simulator; do not reuse shared project simulators.


## Capabilities

- Multi-backend transcription (Apple On-Device / Apple Cloud / OpenAI
  Transcription / OpenAI Realtime)
- Question detection + streaming AI response → glasses HUD
- Background fact-check after every response
- 5 LLM providers (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu)
- 3 modes: General / Interview / Passive
- Dual-BLE G1 dashboard + bitmap HUD with page scrolling
- Native persistence for conversations, facts, memories, todos, projects, settings, and provider keys
- 5-tab SwiftUI shell: Assistant / Device / Sessions / Knowledge / Settings

## Known bugs

See `docs/TEST_BUG_REPORT.md`.
