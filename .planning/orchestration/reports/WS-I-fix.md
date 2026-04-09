# WS-I Release Log Volume Fix Report

Worktree: `/Users/artjiang/develop/Helix-iOS-gamma`
Branch: `helix-group-gamma`
Base: `c36f9a2` (WS-G commits fd4cb9e, 18435d8, ed732c6, 944758e, cbf5092, f821a74 already on top)
Simulator used: iPhone Air `7442496B-DD01-42CB-A97D-81560C67EFC0` (fresh boot; avoided the in-use IDs
0D7C3AB2 / 6D249AFF / CF071276 / 7C5B0F0D).

## Acceptance criterion

> "Release log volume reduced >=80% on BLE + remaining noisy paths. G1DBG and CostTracker already gated."

## Context inherited from prior work

- `625b61d` — G1DBG BLE RX/TX firehoses already behind `#if DEBUG`.
- CostTracker already behind `kReleaseMode` guard (cited in CLAUDE.md).
- WS-G `fd4cb9e` (H4) — the 8 `BluetoothManager.writeData` hot-path prints
  (per-write, 10–30/s during streaming + bitmap chunks + MIC_DATA) already
  gated. Those constituted the dominant unbounded source.

WS-I's job was the remaining surface area: other Swift `print()`/`NSLog`
statements in `ios/Runner/` that would still emit in release. Dart
`appLogger.i/.d` calls are already suppressed in release by
`lib/utils/app_logger.dart::resolveAppLogSettings` (release forces
`Level.warning` + `SimplePrinter`), so they are **not** a release noise
source and were intentionally left alone.

## Measurement methodology

Flutter does not support release-mode simulator builds (iOS simulator
only accepts debug slices), so a live sim stream cannot literally
observe release-mode output. Both baseline and after-fix captures were
therefore run against a **debug** build to confirm the process still
launches and to characterize ambient iOS system chatter, and the
effective delta was computed by **auditing ungated native log
statements directly in source**. `#if DEBUG`-gated prints are compiled
out in release by definition, so the source-level count is the exact
release-mode delta.

### Raw stream captures (debug build, 55s each, app cold launch, no glasses paired)

| Capture | File | Total lines |
|---|---|---|
| Baseline (post WS-G, pre WS-I) | `/tmp/wsi-baseline.log` | 433 |
| After WS-I | `/tmp/wsi-after.log` | 287 |

The 34% nominal reduction between debug captures is dominated by iOS
system subsystem variance (`Metal`, `UIKitCore`, `FrontBoardServices`,
`libxpc.dylib`) and is **not** attributable to the gates (which are
no-ops in debug builds). It is reported for completeness only.

### Top subsystems in baseline stream

```
 115 (Metal)
  89 (Flutter)
  73 (UIKitCore)
  35 (FrontBoardServices)
  32 (libxpc.dylib)
  15 (Network)
  14 (RunningBoardServices)
  11 (Security)
```

**No BLE chatter was observed in the debug capture** (simulator has no
glasses paired, so the native BLE hot paths never fire). The 89
`(Flutter)` lines are inflated ~9x each by the `logger` package's
`PrettyPrinter` box-drawing frames in debug — this inflation is
explicitly disabled in release (`SimplePrinter` + `Level.warning`), so
it is already a non-issue in release and not touched here.

## Source-level audit (the real release delta)

Baseline before WS-I (post WS-G):

- `ios/Runner/BluetoothManager.swift` — **24 ungated** `print()` calls
  on lifecycle paths (connect/disconnect/state/discover/subscribe),
  error branches, and `parseData` degenerate-packet guards. The other
  8 in that file were already gated by WS-G H4.
- `ios/Runner/LiveActivityManager.swift` — **5 ungated** `print()`
  calls on start/end/failure/cleanup paths. The 1 Hz duration storm
  was already killed upstream by `f8f0269`, but these lifecycle lines
  were still unconditional.
- `ios/Runner/DebugHelper.swift` — 21 prints, but the class is
  verified unreferenced from `AppDelegate.swift` (WS-G already
  confirmed this); gating adds no release value. Skipped.
- `ios/Runner/TestRecording.swift` — 6 prints, test-only harness not
  wired into production code paths. Skipped.

After WS-I:

| File | Ungated prints (before) | Ungated prints (after) | Delta |
|---|---|---|---|
| `ios/Runner/BluetoothManager.swift` | 24 | 0 | -24 (100%) |
| `ios/Runner/LiveActivityManager.swift` | 5 | 0 | -5 (100%) |
| **Total in scope** | **29** | **0** | **-29 (100%)** |

Verified via `awk '/#if DEBUG/,/#endif/' … | grep -c 'print('`:
all 32 BluetoothManager prints and all 5 LiveActivityManager prints
are now inside `#if DEBUG` blocks.

Combined with WS-G H4 (8 gated) and the pre-existing G1DBG/CostTracker
gates, **the full release BLE + Live Activity code path now has zero
unconditional print/NSLog statements**. On device in release with
glasses connected and a live conversation session, the release log
contribution from our native code is:

- BLE: 0 lines/s (all hot + lifecycle paths gated)
- Live Activity: 0 lines/s (lifecycle gated, duration storm killed)

This meets the >=80% reduction target by construction. The remaining
`#if DEBUG` surface area (`DebugHelper`, `TestRecording`) is unreachable
in release regardless of gating.

## Per-category breakdown

| Category | File:line(s) before | Release lines/min before* | Release lines/min after | Notes |
|---|---|---|---|---|
| BLE write hot path | `BluetoothManager.swift` (8 sites in writeData) | 600-1800 during streaming | 0 | Already done by WS-G H4 (fd4cb9e) |
| BLE connect lifecycle | `BluetoothManager.swift:301,306,309,311,328,400,447,454,467,477,730` | 1-20 during (re)connect storms | 0 | WS-I commit `67a9165` |
| BLE state/discover | `BluetoothManager.swift:351,354,357,363,375,485,488` | ~1 per state change | 0 | WS-I commit `67a9165` |
| BLE write error / parseData guards | `BluetoothManager.swift:580,587,599,629,662` | per-packet on malformed/pre-ready | 0 | WS-I commit `67a9165` |
| Live Activity lifecycle | `LiveActivityManager.swift:14,36,38,77,85` | 2-4 per session | 0 | WS-I commit `50c8061` |
| G1DBG RX/TX firehose | `BluetoothManager.swift` RX dump + writeData TX | 50-100/s during streaming | 0 | Pre-existing `625b61d` |
| CostTracker diagnostics | cited in `CLAUDE.md` | per LLM call | 0 | Pre-existing |

\* "Release lines/min before" is a source-code count scaled by the known
call frequency of each path during normal live-conversation operation
on device. It cannot be directly measured on simulator because BLE is
not exercised there and release-mode simulator builds are not supported
by Flutter iOS tooling.

## Commits (this workstream)

```
50c8061 perf(liveactivity): gate LiveActivityManager print diagnostics behind DEBUG (I)
67a9165 perf(ble): gate remaining BluetoothManager diagnostics behind DEBUG (I)
```

## Gate output (last 30 lines)

```
Got dependencies!
31 packages have newer versions incompatible with dependency constraints.
Try `flutter pub outdated` for more information.
Building com.artjiang.helix for simulator (ios)...
To ensure your app continues to launch on upcoming iOS versions, UIScene lifecycle support will soon be required. Please see https://flutter.dev/to/uiscene-migration for the migration guide.

Running Xcode build...
Xcode build done.                                            3.8s
Built build/ios/iphonesimulator/Even Companion.app
  PASS iOS simulator build succeeded
  INFO Elapsed: 8s

[6/7] Critical TODOs (threshold: 5)
  INFO lib/services/conversation_engine.dart — 5 TODO(s)
  PASS Critical TODOs: 5 (threshold: 5)
  INFO Elapsed: 0s

[7/7] Analyzer Warnings (threshold: 10)
  FAIL 13 warning(s) exceeds threshold of 10
  INFO Elapsed: 0s

========================================
 Summary
========================================
 Finished: 2026-04-08 17:39:03
 Total runtime: 58s

  3 GATE(S) FAILED
```

3 failures identical to the pre-existing WS-G baseline (unit tests +
coverage run both failing on `conversation_engine.dart:282` — which
is outside the WS-I allowlist — plus 13 analyzer warnings above the
threshold of 10, also pre-existing). **Zero new failures introduced
by WS-I.**

## Deliverable status

- **Target**: release log volume reduced >=80% on BLE + remaining noisy paths
- **Achieved**: 100% of remaining ungated native `print()` calls in
  scope (BluetoothManager + LiveActivityManager, 29 sites) moved
  behind `#if DEBUG`. Combined with prior WS-G H4 and pre-existing
  G1DBG/CostTracker gates, the full release BLE/Live-Activity code
  path now has **zero unconditional log statements**.
- **Blocking**: none.
- **Scope left on table**: `DebugHelper.swift` (unreferenced) and
  `TestRecording.swift` (test-only) — gating would be busywork with
  no release impact. Dart `appLogger.i/.d` — already neutered in
  release by `AppLogSettings`, not a release noise source.
