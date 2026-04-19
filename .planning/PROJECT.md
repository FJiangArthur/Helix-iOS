# Helix iOS — App Store Release

## What This Is

Helix is a Flutter iOS companion app for Even Realities G1 smart glasses that provides real-time conversation intelligence — listening to conversations, detecting questions, generating AI answers, and displaying them on the glasses HUD hands-free. The goal is to polish the existing feature set and add key capabilities to reach App Store submission quality within 2-4 weeks.

## Core Value

Real-time transcription must stream reliably with zero perceptible delay — everything else (Q&A, fact-checking, HUD display) depends on the transcript arriving in real time.

## Requirements

### Validated

- ✓ Multi-provider LLM integration (OpenAI, Anthropic, DeepSeek, Qwen, Zhipu) — existing
- ✓ Conversation transcription (Apple Cloud, OpenAI Realtime, Whisper batch) — existing
- ✓ Automatic question detection and AI answering — existing
- ✓ Glasses HUD output (bitmap + text rendering) — existing
- ✓ BLE dual-connection glasses communication — existing
- ✓ Interview coaching mode with STAR framework — existing
- ✓ Conversation history with database persistence — existing
- ✓ Settings management with secure API key storage — existing
- ✓ Background fact-checking after AI responses — existing
- ✓ Passive listener mode — existing

### Active

- [ ] Fix transcription streaming — eliminate 30s batching delay, real-time partials
- [ ] Fix Q&A reliability on glasses — answers must appear on HUD during live sessions
- [ ] Fix transcription gaps — missing words, mid-sentence cutouts
- [ ] Faster fact-checking — replace/supplement slow Tavily path with OpenAI web search
- [ ] Proactive insights — surface relevant context in passive mode without being asked
- [ ] App Store polish — stability, error handling, onboarding, edge cases

### Out of Scope

- Android support — iOS-only for initial release
- Custom LLM fine-tuning — use off-the-shelf models
- Voice response output — text-only for v1 (voice assistant exists but not ship-critical)
- Multi-language simultaneous detection — single language per session is fine
- Cloud sync / user accounts — local-only for v1

## Context

- **Hardware**: Even Realities G1 smart glasses with BLE dual connection, touchpad gestures
- **Stack**: Flutter 3.35+ with native Swift (BLE, speech recognition, audio processing)
- **Transcription backends**: OpenAI Realtime WebSocket (primary), Apple Cloud SFSpeech, Whisper batch REST
- **Known bugs**: BUG-001 through BUG-006 documented in docs/TEST_BUG_REPORT.md
- **Hardware issues**: Left-eye HUD broken, Q&A fails on live session, BLE reconnect issues (documented in .planning memory)
- **Current state**: Core features work in isolation but fail under real-world continuous use — transcription stalls, answers don't reach glasses, timing issues between subsystems

## Constraints

- **Timeline**: 2-4 weeks to App Store submission — aggressive, prioritize fixing over building
- **Platform**: iOS 15+ only, Xcode 26.3, Flutter 3.35+
- **Hardware**: Must work with Even Realities G1 glasses (BLE protocol is fixed)
- **API costs**: OpenAI Realtime API charges per audio-second — local VAD removal increases cost slightly but is necessary for reliability
- **Testing**: Physical glasses required for full integration testing; simulator covers UI + unit tests only

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Remove local VAD gating on OpenAI path | Server-side VAD handles silence; local gating was blocking audio and causing 30s transcription delays | — Pending |
| Stop pausing transcription during AI response | Pausing caused transcription to batch up and dump all at once after response completed | — Pending |
| OpenAI web search for fact-checking | Tavily path is too slow; OpenAI's built-in web_search tool is faster and single-call | — Pending |
| Keep transcription flowing to UI during response | Users need to see conversation continuing even while AI answer is generating | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-18 after initialization*
