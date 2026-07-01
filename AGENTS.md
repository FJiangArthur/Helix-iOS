# Agent Context — Helix-iOS

## Identity

- **Project**: Helix-iOS (v2.2.75+202607011303)
- **Type**: Native iOS Swift app with headless Swift framework
- **Purpose**: Companion app for Even Realities G1 smart glasses — real-time conversation intelligence with AI

## Rules

1. Read `CLAUDE.md` before making changes
2. Run `bash scripts/run_gate.sh` before completing any task
3. Boot a **dedicated simulator** — `0D7C3AB2` is Album Clean, `6D249AFF` is Pet App
4. Commit to `main`, always increment `VERSION` and the Xcode marketing/build settings
5. Do not add new Flutter, Dart UI, or platform-channel work. SwiftUI belongs only in the iOS app shell.

## Architecture

```
NativeHelix/Package.swift
  → HelixRuntime (headless dependency container and runtime state)
  → HelixConversation (general/interview/passive modes)
  → HelixAI (provider protocols and answer validation)
  → HelixSpeech (transcription and question detection)
  → HelixG1 (protocol, HUD pagination, touchpad routing)
  → HelixPersistence (fresh native stores)

No Flutter method/event channels. Product logic belongs in `NativeHelix`; SwiftUI app shell code belongs in `ios/Runner`.
```

## Key Files

| File | Purpose |
|------|---------|
| `NativeHelix/Package.swift` | Headless native package graph |
| `NativeHelix/Sources/HelixRuntime` | Dependency container, runtime state, eval report harness |
| `NativeHelix/Sources/HelixConversation` | Transcription → question detection → AI → HUD events |
| `NativeHelix/Sources/HelixAI` | Provider protocol, answer validation |
| `NativeHelix/Sources/HelixSpeech` | Transcription contracts, question detection |
| `NativeHelix/Sources/HelixG1` | BLE protocol, HUD pagination, touchpad routing |
| `NativeHelix/Sources/HelixPersistence` | Native stores and SwiftData schema |

## Current Features

- 3 conversation modes with configurable sentence limit (1-10)
- Direct speakable output (no "you could say" meta-phrases)
- Background fact-check on every AI response
- Touchpad page scrolling for multi-page answers on glasses
- Bitmap HUD default, text fallback
- 5 LLM providers with streaming
- 4 transcription backends
- Native Swift package tests and validation gate script

## Known Bugs

BUG-006: RNNoise header-only. Legacy Dart conversation compaction bugs are archived with the removed Flutter tree.

Full details: `docs/TEST_BUG_REPORT.md`

## BLE Protocol Quick Reference

- Dual L/R connection, 191 bytes/packet, sequence numbered
- Touchpad: notifyIndex 1 = pageBack(L)/pageForward(R)
- Screen codes: `0x30` streaming, `0x40` complete, `0x70` text page
- Text HUD: 488px, 21pt, 5 lines/page

## Documentation

`CLAUDE.md` (full reference) | `VALIDATION.md` (test gates) | `docs/product-overview.md` (user flows) | `docs/PROGRESS.md` (feature status) | `docs/learning.md` (technical findings) | `docs/TEST_BUG_REPORT.md` (bugs) | `docs/appstore-metadata.md` (App Store copy)
