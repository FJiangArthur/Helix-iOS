# Development Progress

Current version: **1.1.0+2**

## Multi-Track Orchestration 2026-04-08

Active parallel workstream effort. Recovery anchor on system fault.

- **Spec:** `docs/superpowers/specs/2026-04-08-multi-track-orchestration-design.md`
- **Live status:** `.planning/orchestration/STATUS.md`
- **Reports:** `.planning/orchestration/reports/`
- **Workstreams:** WS-A..WS-J (10 items, Tier-1/2/3) across 4 git worktrees (groups α/β/γ/δ) plus post-merge WS-J
- **Merge order:** γ → δ → β → α → WS-J
- **Mode:** fast-path (skip writing-plans, dispatch directly from spec)
- **Testing:** simulator-first via `ios-sim-validation` skill (mcp__ios-simulator tools), HW reserved for G1 visual + ring HID


## Capabilities

- Multi-backend transcription (Apple On-Device / Apple Cloud / OpenAI
  Transcription / OpenAI Realtime)
- Question detection + streaming AI response → glasses HUD
- Background fact-check after every response
- 5 LLM providers (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu)
- 3 modes: General / Interview / Passive
- Dual-BLE G1 dashboard + bitmap HUD with page scrolling
- Drift SQLite persistence (conversations / facts / memories / todos)
- 4-tab UI (Home / Glasses / History / Settings), onboarding flow

## Known bugs

See `docs/TEST_BUG_REPORT.md`.
