---
created: 2026-04-08T00:00:00.000Z
title: Tier-2 — Reduce debug logging in release + gate G1 BLE debug behind setting toggle
area: performance
status: pending
priority: tier-2
files:
  - lib/services/conversation_engine.dart
  - lib/services/cost/conversation_cost_tracker.dart
  - lib/services/provider_error_state.dart
  - lib/services/settings_manager.dart
  - lib/services/g1_debug_service.dart
  - lib/utils/app_logger.dart
  - ios/Runner/BluetoothManager.swift
  - ios/Runner/SpeechStreamRecognizer.swift
---

## Problem

**Reported:** 2026-04-07 hardware test — user noticed debug info noise,
specifically two concerns:

1. **BLE energy waste.** G1 glasses receive verbose debug info (firmware
   `G1DBG` firehose or phone-side debug notifications) even during
   normal operation. Wireless writes consume glasses battery; every
   debug byte pushed to the glasses is waste.
2. **Release builds log too much.** Formal release builds (TestFlight /
   App Store) should not emit the same firehose the dev builds do —
   both for user privacy and because console logging has measurable
   CPU and thermal cost.

## What's logging right now

### Recent additions this session (need review)
- `[CostTracker] +${operationType} ...` in
  `lib/services/cost/conversation_cost_tracker.dart` — fires on every
  LLM/transcription call. Added as diagnostic for cost bug.
- `[ConversationEngine] _generateResponse received [Error] ...` —
  fires only on error path (cheap)
- `[ProviderErrorState] UNKNOWN bucket: raw=... errorType=...` —
  fires only on unknown-error path (cheap)

All three use `debugPrint` which is technically stripped in release via
`kReleaseMode` being handled by the Dart SDK... but worth confirming.

### Pre-existing noise
- `kDebugTranscriptionTiming` compile-time flag (from Plan A Phase 0) —
  gates mach-time logs. Already compile-time gated. ✓
- `G1DebugService` — Dart-side wrapper for G1 BLE debug logging. Need
  to check if it has a runtime toggle.
- `appLogger.e/w/i/d` — centralized logger in `lib/utils/app_logger.dart`.
  Already has sanitization hooks per security gate. Verify log level
  is `warning` or higher in release.
- Native `BluetoothManager.swift` — may have `NSLog` / `print`
  statements that fire on every BLE packet. Audit.
- Native `SpeechStreamRecognizer.swift` — same question.
- **G1 firmware debug mode** — if the phone enables G1's own debug
  reporting via a BLE command, the firmware streams verbose data back.
  This is the real BLE-energy concern. Need to find where (and if)
  Helix enables this.

## Desired behavior

### Settings toggle
Add a **Debug Logging** toggle in Settings (advanced / developer
section):

- Default: OFF in release, ON in debug builds
- When OFF:
  - No `[CostTracker]` debugPrints
  - No `G1DebugService` output
  - No native `print` / `NSLog` from BLE / speech paths
  - `appLogger` level = warning
  - G1 firmware debug mode is NOT enabled (no debug command sent to
    glasses → zero extra BLE traffic)
- When ON (dev mode):
  - All current diagnostics active
  - G1 firmware debug mode can be enabled if needed for deep protocol
    debugging

### Release build constraints
Regardless of the toggle:
- In release (`kReleaseMode == true`), diagnostic `debugPrint` from this
  session's cost tracker MUST be stripped or gated. Options:
  a. Wrap in `if (kDebugMode) debugPrint(...)` — simplest
  b. Use `appLogger.d(...)` which is already sanitized
  c. Gate behind the new settings toggle (if runtime-adjustable is
     worth the complexity)
- Native `print` / `NSLog` on BLE hot paths should be `#if DEBUG` or
  use `os_log` with category-based filtering

### G1 BLE energy
- Audit every place we send data to the glasses that's NOT user-facing
  HUD content (ping, heartbeat, debug enable, firmware probes)
- Make sure debug-mode commands to glasses are ONLY sent when the
  settings toggle is ON
- Verify the `G1DBG` firehose from firmware is not the result of us
  enabling debug mode on the glasses by default

## Investigation

1. **Grep for logging sources.**
   ```
   rg 'debugPrint|appLogger\.' lib/ | wc -l
   rg 'print\(|NSLog' ios/Runner/ | wc -l
   ```
   Baseline the log density.

2. **Find the G1 debug enable command.** Search for any BLE write that
   activates firmware-side logging. CLAUDE.md mentions `G1DBG` firehose
   — find where we enable it or whether it's on by default.

3. **Check `appLogger` release behavior.** Read `lib/utils/app_logger.dart`
   — is there a level gate? Is it level-filtered in release?

4. **Audit `debugPrint` in release.** The Dart SDK strips `debugPrint`
   output automatically if `debugPrint = debugPrintThrottled` is null.
   But verify with a release build + Console.app that no
   `[CostTracker]` lines appear.

5. **Audit native logging.**
   ```
   rg 'print\(|NSLog' ios/Runner/BluetoothManager.swift
   rg 'print\(|NSLog' ios/Runner/SpeechStreamRecognizer.swift
   ```
   Gate hot-path ones behind `#if DEBUG`.

## Progress 2026-04-08

Phase 1 (cheap wins, no Settings toggle yet):

- **`[CostTracker]` debugPrint** — already gated behind `kDebugMode` in
  commit `80e5d8d` (Tier-1 thermal iteration).
- **`[ConversationEngine] _generateResponse received [Error]`** — now
  gated behind `kDebugMode`. Was on the error path only but consistent
  gating is worth the two-line change.
- **`[G1DBG] TX` firehose** (BluetoothManager.swift:501-507) — wrapped
  in `#if DEBUG`. Fired on every outbound BLE write, 10+/sec during
  streaming. Highest-impact single change of this iteration.
- **`[G1DBG] RX` firehose** (BluetoothManager.swift:587-602) — wrapped
  in `#if DEBUG`. Fired on every inbound BLE notification.

**Not yet done (out of scope for loop iteration):**
- Settings toggle (developer section) for runtime gating.
- `appLogger` audit — already release-gated to warning level (verified
  by reading `lib/utils/app_logger.dart`).
- Other native `print(...)` sites in BluetoothManager — one-shot
  connect/disconnect/discover events, NOT hot paths. Leaving as-is.
- `[ProviderErrorState] UNKNOWN bucket` — still ungated because it
  only fires on unclassified errors (very rare) and the diagnostic
  value is high right now (Q&A Tier-1 is waiting on this exact log
  line). Will gate once the Q&A root cause is identified.
- G1 firmware debug mode — did NOT find any BLE command in our code
  that enables firmware-side debug. If the `0xF4 RX DEBUG:` frames are
  arriving, they're either always-on from the firmware or enabled
  elsewhere (e.g. via a service UUID config we don't set). Safe to
  defer until actual BLE measurement is available.

## Success criteria

- Release build console shows zero `[CostTracker]`, zero `G1DBG`, zero
  BLE-per-packet logs
- Glasses receive only user-content BLE writes (no debug-enable
  commands) unless the settings toggle is ON
- Toggle in Settings can enable all debug output for dev builds without
  recompiling
- BLE traffic on-wire (measured with Bluetooth Packet Logger or the
  macOS BluetoothAnalyzer) drops noticeably in release vs debug

## Related

- `2026-04-08-phone-thermal-during-streaming-and-recording.md` — debug
  logging is one of the candidates for the thermal cost
- Plan A Phase 0 `kDebugTranscriptionTiming` — precedent for compile-
  time gating
- `docs/AGENT_TEAM_CONFIG.md` / `scripts/run_gate.sh` security-gate step
  already enforces sanitized release logging via `appLogger`; this TODO
  extends that to cover the newer `debugPrint` sites
- CLAUDE.md "Known Bugs" / `docs/TEST_BUG_REPORT.md` — add an entry
  here when fix lands
