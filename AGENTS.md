# Agent Context — Helix-iOS

## Identity

- **Project**: Helix-iOS (v1.1.0+2)
- **Type**: Flutter + iOS native
- **Purpose**: Companion app for Even Realities G1 smart glasses — real-time conversation intelligence with AI

## Rules

1. Read `CLAUDE.md` before making changes
2. Run `bash scripts/run_gate.sh` before completing any task
3. Boot a **dedicated simulator** — `0D7C3AB2` is Album Clean, `6D249AFF` is Pet App
4. Commit to `main`, always increment version in `pubspec.yaml`

## Architecture

```
lib/main.dart → lib/app.dart (4 tabs: Home, Glasses, History, Settings)

ConversationListeningSession (platform channel bridge)
  → ConversationEngine (3 modes: general/interview/passive)
    → LlmService (5 providers: OpenAI, Anthropic, DeepSeek, Qwen, Zhipu)
    → EvenAI → Proto → BLE → Glasses HUD

Settings: SettingsManager (SharedPreferences + FlutterSecureStorage)
Database: Drift SQLite (conversations, facts, memories, todos)
State: GetX + plain Streams
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/conversation_engine.dart` | Core: transcription → question detection → AI → HUD |
| `lib/services/conversation_listening_session.dart` | Speech capture bridge |
| `lib/services/llm/llm_service.dart` | Multi-provider LLM routing |
| `lib/services/llm/openai_provider.dart` | OpenAI (gpt-4.1 family + realtime only) |
| `lib/services/settings_manager.dart` | All settings (maxResponseSentences, hudRenderPath, etc.) |
| `lib/services/evenai.dart` | Touchpad routing, hasActiveAnswer flag |
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | Bitmap HUD rendering |
| `lib/services/button_gesture_detector.dart` | BLE button gestures |
| `ios/Runner/SpeechStreamRecognizer.swift` | 4-backend speech (Apple Cloud/OnDevice, OpenAI Transcription/Realtime) |
| `ios/Runner/BluetoothManager.swift` | BLE dual connection (L/R) |
| `ios/Runner/AppDelegate.swift` | Platform channel handlers |

## Current Features

- 3 conversation modes with configurable sentence limit (1-10)
- Direct speakable output (no "you could say" meta-phrases)
- Background fact-check on every AI response
- Touchpad page scrolling for multi-page answers on glasses
- Bitmap HUD default, text fallback
- 5 LLM providers with streaming
- 4 transcription backends
- 97 unit tests, validation gate script

## Known Bugs

BUG-001: Segment compaction only from progressive splitting | BUG-002: Analytics skipped during rapid finalization | BUG-003: Long-press unreachable with production timers | BUG-005: Compaction silently loses data | BUG-006: RNNoise header-only

Full details: `docs/TEST_BUG_REPORT.md`

## BLE Protocol Quick Reference

- Dual L/R connection, 191 bytes/packet, sequence numbered
- Touchpad: notifyIndex 1 = pageBack(L)/pageForward(R)
- Screen codes: `0x30` streaming, `0x40` complete, `0x70` text page
- Text HUD: 488px, 21pt, 5 lines/page

## Documentation

`CLAUDE.md` (full reference) | `VALIDATION.md` (test gates) | `docs/product-overview.md` (user flows) | `docs/PROGRESS.md` (feature status) | `docs/learning.md` (technical findings) | `docs/TEST_BUG_REPORT.md` (bugs) | `docs/appstore-metadata.md` (App Store copy)
