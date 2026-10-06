# Helix-iOS

Native headless framework for Even Realities G1 smart glasses conversation intelligence.

**Version**: 2.2.98+202608312013

## Validation (MANDATORY)

**Before completing any code change**, run the validation gate:

```bash
bash scripts/run_gate.sh
```

See `VALIDATION.md` for full details on each gate and how to run individual test suites.

### Minimum validation before any commit or PR:

1. **Run `bash scripts/run_native_swift_gate.sh`** — native package must build and test successfully
2. **Run `bash scripts/run_gate.sh`** — headless boundary, security, and native package gates must pass
3. Do not add legacy cross-platform UI/tooling or platform-channel work. Product behavior belongs in native framework modules. SwiftUI belongs only in the iOS app shell.

## Build

- Xcode 27.0, Swift Package Manager, iOS 17+ / macOS 14+ package baseline
- Default validation is headless Swift package validation
- Use `swift build --package-path NativeHelix --target HelixRuntime`
- Use `swift test --package-path NativeHelix`
- Always boot a **dedicated simulator instance** for simulator work — the simulator is shared by multiple apps on this machine
- Simulators in use: iPhone 17 Pro (`0D7C3AB2`) = Album Clean, iPhone 17 (`6D249AFF`) = Pet App. Boot a separate instance for Helix.

## Product Overview

Helix listens to conversations, detects questions, generates AI answers, and displays them on the glasses HUD — hands-free.

### User Flows

1. **Live Conversation**: Listen -> transcribe -> detect question -> AI answer -> stream to glasses HUD -> background fact-check
2. **Text Query**: Type question -> AI answer -> phone + optional glasses -> follow-up chips
3. **Interview Coach**: Directly speakable output, STAR framework, no "you could say" phrasing
4. **Passive Listener**: Silent monitor, only facts/corrections/context

### Configuration

| Setting | Default | Range |
|---------|---------|-------|
| Max Response Sentences | 3 | 1-10 |
| Transcription Backend | OpenAI | OpenAI / Apple Cloud / Apple On-Device |
| Transcription Models | gpt-4o-mini-transcribe | gpt-4o-mini-transcribe, gpt-4o-transcribe, whisper-1, gpt-4o-mini-realtime, gpt-4o-realtime |
| HUD Render Path | Bitmap | Bitmap / Text (fallback) |
| Auto-detect Questions | On | On / Off |
| Auto-answer | On | On / Off |

### AI Providers

| Provider | Models |
|----------|--------|
| OpenAI | gpt-4.1, gpt-4.1-mini, gpt-4.1-nano, gpt-realtime |
| Anthropic | claude-sonnet-4, claude-haiku-4 |
| DeepSeek | deepseek-chat, deepseek-reasoner |
| Qwen | qwen-turbo, qwen-plus, qwen-max |
| Zhipu | glm-4-flash, glm-4 |

## Architecture

- **NativeHelix/Package.swift** is the source of truth for new work
- **HelixRuntime** owns the headless dependency container, runtime states, and eval report harness
- **HelixConversation** owns conversation modes, question detection, passive corrections, active answers, RAG orchestration, and HUD event output
- **HelixAI** owns provider protocols and answer validation
- **HelixSpeech** owns audio/file transcription contracts and transcript normalization
- **HelixG1** owns BLE protocol, HUD pagination, and touchpad routing
- **HelixPersistence** owns fresh native persistence contracts and SwiftData/SQLite-backed stores
- No legacy method/event channels in new code
- No SwiftUI screens or UI assets in the headless framework package; app-shell SwiftUI stays under `ios/Runner`

### Key Files

| File | Purpose |
|------|---------|
| `NativeHelix/Package.swift` | Headless native package products and target graph |
| `NativeHelix/Sources/HelixRuntime` | Runtime dependency container and non-UI session/device/knowledge states |
| `NativeHelix/Sources/HelixConversation` | Conversation pipeline, eval runner, passive/active behavior |
| `NativeHelix/Sources/HelixAI` | Provider protocols, deterministic test provider, answer validation |
| `NativeHelix/Sources/HelixSpeech` | Transcription contracts and question detection |
| `NativeHelix/Sources/HelixG1` | G1 protocol, touchpad routing, HUD pagination |
| `NativeHelix/Sources/HelixPersistence` | Native stores, SwiftData schema, document chunking |
| `NativeHelix/Tests/HelixConversationTests` | Native framework parity and eval tests |
| `conversate-core/` | Shared Conversate contract (menu, prompts, cue schema, test vectors) for the Android G1 app and the G2 Even Hub app |
| `android/app/src/main/java/com/artjiang/helix/conversate/` | Android Conversate: session state machine, G1 HUD composer/driver, cue engine, Prep Notes |

### BLE & HUD Protocol

- G1 uses dual BLE connections (L/R glasses) through native CoreBluetooth services in the iOS app shell
- Touchpad events: `notifyIndex` 0=exit, 1=pageBack/Forward (L/R), 2=headUp, 3=headDown, 23=evenaiStart, 24=evenaiRecordOver
- EvenAI protocol: multi-packet chunking (191 bytes/packet) with sequence numbers
- **BLE command byte for the AI/text family is `0x4E`** (`SEND_RESULT`). The values below are NOT separate commands — they are values of the 5th header byte (`screen_status` = `ScreenAction | AIStatus`).
- Packet header: `[0x4E, syncSeq, maxSeq, seq, screen_status, new_char_pos_hi, new_char_pos_lo, currentPage, maxPage, ...data]`
- `screen_status` = `AIStatus | ScreenAction`; `ScreenAction` is always `0x01` (NEW_CONTENT), so the on-wire byte is `0x31`/`0x41`/`0x51`/`0x61`/`0x71`. `AIStatus`: `0x30` DISPLAYING (auto-advance), `0x40` DISPLAY_COMPLETE, `0x50` MANUAL_MODE, `0x60` NETWORK_ERROR, `0x70` direct text.
- **NORMATIVE SOURCE: `docs/G1_PROTOCOL_SLA.md`** (derived from the official EvenDemoApp @`3899aac` **source**, with `file:line` citations). Read it before touching any BLE/HUD byte. The vendor README contradicts the vendor's own code — it says the exit command is `[0xF5,0x00]`; `proto.dart:121-135` uses `[0x18]`. Trust the Dart.
- **`0x71` and `0x31`/`0x41` are two DIFFERENT display paths.** Plain text (what Helix uses) sends `0x71` for every page with **no** completion byte. The AI-session path sends `0x31`, waits 3 s, then `0x41` — its vendor comment reads "The glasses need to have 0x30 before they can process 0x40". Do not mix one path's header conventions into the other: encoding `0x71` with the PAGED header is what made text never render on hardware (fixed 2026-08-28, confirmed on device).
- **Chunk size is 191 PAYLOAD bytes on both text paths** (`evenai_proto.dart:8`); the 9-byte header is prefixed after, so frames are 200 bytes against MTU 251. Deriving `191-9=182` misreads `len` as a whole-frame budget. `maxSeq` (byte 2) is the packet **COUNT**, not count−1. `current_page_num` is **1-based**, never 0.
- **Every `0x4E` packet is individually ACK-gated** (`0xC9` and `0xCB` are success, `0xCA` is failure), and the left lens must fully ACK before the right is written. `0x4E` must be in `G1StatusDecoder`'s ACK command list or every screen times out.
- **Blanking is not free.** iOS never blanks the HUD — content sits on the lens until something overwrites it. A timed "answer disappears after N seconds" is therefore NEW behaviour on both platforms and cannot be obtained by copying iOS. Android implements it as an explicit `0x18` EXIT_ALL_FUNCTIONS after a user-configurable dwell (Device tab, 1–30 s, default 3), which clears the lens and returns it to the firmware dashboard. Safe here because Helix never sends `0x0E` (glasses mic) — it uses the phone mic. Manual touchpad paging latches MANUAL and suppresses the auto-clear, so hand-paged content is never blanked out from under the wearer.
- **Single-lens links are a supported state.** `isGlassesConnected` is `left READY || right READY`. `sendScreen` distinguishes an **ABSENT** lens (write rejected before any bytes left — the other lens still carries the screen) from a **FAILED** one (accepted, then no ACK — a real failure). ANDing both lenses made every screen fail whenever one was down, aborting the HUD lifecycle before teardown was scheduled.
- **The official `com.even.g1` app steals the lenses.** A connected BLE peripheral stops advertising, so while it holds them Helix can never discover the glasses and sits on "Scanning…" forever. `adb shell am force-stop com.even.g1` before any hardware test.
- Notifications use command `0x4B`: header `[0x4B, msgId, maxSeq, seq]` + ≤176 B of `{"ncs_notification":{msg_id,app_identifier,title,subtitle,message,time_s,display_name}}`, **left lens only**, up to 6 retries. The app whitelist is `0x04`: header `[0x04, maxSeq, seq]` + ≤177 B JSON, left lens only. `syncSeq` (byte 1 of `0x4E`) is per-**screen**, not per-packet; `new_char_pos` is always 0 in every reference implementation.
- `new_char_pos` is hard-coded `0` in every reference implementation (official Even Realities demo + community Python SDK). It is **not an append offset** — likely a highlight position. Pagination is 100% phone-driven by re-pushing whole pages with updated `current_page_num`.
- Text HUD: 488px max width, 21pt font, 5 lines per page
- Bitmap HUD: Full widget-based rendering via `BitmapHudService`

### Touchpad Behavior (liveListening mode)

| State | Left Touchpad | Right Touchpad |
|-------|--------------|----------------|
| No active answer | Pause/resume transcription | Trigger manual question detection |
| Active answer displayed | Previous page | Next page |

Answer flag (`EvenAI.hasActiveAnswer`) set when response completes, cleared when new transcription arrives.

**Conversate mode (Android)** owns the whole touchpad while enabled: left long-press = menu (select inside lists), right/left tap = next/previous, double-tap = back (twice at the session root ends it). An OS-bonded **Even R1 ring** can drive the same intents (tap select, double-tap back, hold menu, swipe scroll) via `ring/R1Transport.kt` — bonded rings only, never a name-matched scan. Spec: `docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md`.

## Technical Findings

### Transcription
- Apple Cloud is the most reliable backend for continuous conversation transcription
- OpenAI `didEmitFinalResult` guard was blocking all finals after first segment — fixed by resetting on new partials
- `AVAudioInputNode.installTap` crashes with hardcoded 16kHz — must use hardware input format and convert
- Stale partial detection: reconnect after 25 identical partials (~2.5s)
- Shutdown `buffer too small` error is benign — suppressed from user display

### LLM Providers
- OpenAI-compatible providers (DeepSeek/Qwen/Zhipu) share `OpenAiCompatibleProvider` base class
- Anthropic uses custom SSE parsing (`content_block_delta` events)
- Model filter: `filterQueriedModels()` only keeps gpt-4.1 family + realtime models

### Prompts
- All mode prompts use `maxResponseSentences` from settings (configurable 1-10)
- All prompts enforce direct output — never "you could say" or "here's a suggestion"
- Profile directive is a single line: `Profile: {name} — {answerStyle}`
- Background fact-check runs after every AI response (non-blocking)

### Audio
- Microphone permission deferred to first recording (was triggering at launch)
- RNNoise processor is header-only — noise reduction toggle has no effect (BUG-006)

## Known Bugs

See `docs/TEST_BUG_REPORT.md` for full details:

| Bug | Severity | Summary |
|-----|----------|---------|
| BUG-006 | Info | RNNoiseProcessor is header-only / not implemented |

## Documentation

| File | Purpose |
|------|---------|
| `CLAUDE.md` | This file — build, architecture, product, findings |
| `AGENTS.md` | Quick-reference agent context |
| `VALIDATION.md` | Test gate details, test suites, writing new tests |
| `docs/product-overview.md` | User flows, configuration, supported hardware |
| `docs/PROGRESS.md` | Feature checklist, version history |
| `docs/learning.md` | Technical findings: BLE protocol, transcription, LLM providers |
| `docs/TEST_BUG_REPORT.md` | Documented bugs with file/line references |
| `docs/appstore-metadata.md` | App Store submission copy |
| `docs/SIMULATOR_VALIDATION_PROTOCOL.md` | 6-gate simulator validation with real API testing |
| `docs/AGENT_TEAM_CONFIG.md` | 6-role agent team config for validation |

## gstack (REQUIRED — global install)

**Before doing ANY work, verify gstack is installed:**

```bash
test -d ~/.claude/skills/gstack/bin && echo "GSTACK_OK" || echo "GSTACK_MISSING"
```

If GSTACK_MISSING: STOP. Do not proceed. Tell the user:

> gstack is required for all AI-assisted work in this repo.
> Install it:
> ```bash
> git clone --depth 1 https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
> cd ~/.claude/skills/gstack && ./setup --team
> ```
> Then restart your AI coding tool.

Do not skip skills, ignore gstack errors, or work around missing gstack.

Using gstack skills: After install, skills like /qa, /ship, /review, /investigate,
and /browse are available. Use /browse for all web browsing.
Use ~/.claude/skills/gstack/... for gstack file paths (the global path).
