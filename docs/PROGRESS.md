# Development Progress

## Current Version: 1.1.0+2

## Completed Features

### Core Pipeline
- [x] Multi-backend speech recognition (Apple On-Device, Apple Cloud, OpenAI Transcription, OpenAI Realtime)
- [x] Progressive sentence splitting with segment finalization
- [x] Question detection from conversation context
- [x] AI response generation with streaming to glasses HUD
- [x] Background fact-check on every AI response
- [x] Configurable response length (1-10 sentences)
- [x] Direct speakable output (no meta-phrases)

### Glasses Integration
- [x] BLE dual connection (L/R glasses)
- [x] Bitmap HUD rendering with customizable layouts
- [x] Text HUD fallback mode
- [x] Touchpad page scrolling for multi-page answers
- [x] Head tilt dashboard trigger
- [x] Button gesture detection (single/double/long press)

### AI Providers
- [x] OpenAI (gpt-4.1 family + realtime)
- [x] Anthropic (claude-sonnet-4, claude-haiku-4)
- [x] DeepSeek (chat + reasoner)
- [x] Qwen (turbo, plus, max)
- [x] Zhipu (glm-4-flash, glm-4)
- [x] API key management with secure storage
- [x] Provider switching in settings

### Conversation Modes
- [x] General — balanced everyday assistant
- [x] Interview — STAR coaching, speakable output
- [x] Passive — silent listener, minimal interventions

### Data & Persistence
- [x] Drift SQLite database with DAOs (conversations, facts, memories, todos)
- [x] Entity memory for people/company recognition
- [x] Session context management (3-tier window)
- [x] Conversation history with session metadata

### UI
- [x] 4-tab navigation (Home, Glasses, History, Settings)
- [x] Onboarding flow (4 pages)
- [x] Dark glassmorphism theme
- [x] Follow-up chip suggestions
- [x] Fact-check alert banner
- [x] Response tools (summarize, rephrase, translate, fact-check, send to glasses)

### Testing
- [x] 97 unit tests across 13 test suites
- [x] Validation gate script (`scripts/run_gate.sh`)
- [x] Shared test helpers and mock infrastructure

## Known Bugs

See `docs/TEST_BUG_REPORT.md` for details:
- BUG-001: Segment compaction only from progressive splitting path
- BUG-002: Analytics counter skipped during rapid finalization
- BUG-003: Long-press gesture unreachable with production timers
- BUG-006: RNNoise processor header-only (noise reduction no-op)

## Recent Changes (v1.1.0)

- Fixed OpenAI transcription dropping sentences (`didEmitFinalResult` guard)
- Added configurable max response sentences setting
- Added background fact-check on every AI response
- Enabled touchpad page scrolling in liveListening mode
- Cleaned up OpenAI model list (gpt-4.1 family + realtime only)
- Updated prompts for direct speakable output
- Defaulted HUD to bitmap rendering
- Fixed keyboard dismiss on chat text field
- Cleaned up stale documentation
