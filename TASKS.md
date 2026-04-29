# Helix-iOS TASKS

Iterative QA task tracker. New findings are appended; resolved findings are marked `[x]` with the fixing change.

> Triage source: `bash scripts/run_gate.sh` + manual UI verification on the iOS simulator. See `VALIDATION.md` for gate definitions, `CLAUDE.md` for product/architecture context, and `TODOS.md` for long-lived planning items.

## Loop policy

- Run the validation gate at the top of every iteration. Capture failures as `F-##` entries below.
- Fix root causes. No `--no-verify`, no test skips, no swallowed exceptions outside boundary code.
- Mark `[x]` only after the relevant gate is green AND the symptom is reproduced as resolved.
- For UI work, capture a simulator screenshot under `tmp/screenshots/` and reference it in the task.

## Iteration log

### Iteration 1 — 2026-04-28 (UTC) / 2026-04-27 (PT)

**Validation gate (initial run, commit `753ff9c`):** ALL 7 GATES PASSED — 658/658 tests, 0 analyze errors, 0 warnings, 5 critical-file TODOs (== threshold), simulator build OK.

**Validation gate (after F-01 fix):** ALL 7 GATES PASSED — same metrics, 133s total.

**Simulator UI walkthrough (Helix-QA, `C9AB82C4-1107-4E99-867A-E161E90E00CB`):**

| # | Screen | Screenshot | Status |
|---|--------|-----------|--------|
| 1 | Onboarding (page 1) | `tmp/screenshots/07-clean-launch.png` | OK — "A quiet edge for live conversations", Skip + Next |
| 2 | Home (post-skip) | `tmp/screenshots/08-after-skip.png` | OK — Conversation Hub, profile chips (General/Professional/Social/Interview/Technical), G1 OFFLINE badge, ready stack |
| 3 | Glasses tab | `tmp/screenshots/09-tab-glasses.png` | OK — Mic source toggle, Noise reduction, Auto-connect, HUD Brightness slider, HUD Widgets header |
| 4 | Live tab | `tmp/screenshots/10-tab-live.png` | OK — Live/History/Projects pills, mic FAB, "No analysis yet" empty state |
| 5 | Ask AI tab | `tmp/screenshots/11-tab-askai.png` | OK — Daily AI / Review pills, suggestion chips, ask field, send button |
| 6 | Insights tab | `tmp/screenshots/12-tab-insights.png` | OK — Facts / Memories pills, Knowledge Graph card, search icon |
| 7 | Settings (from Live) | `tmp/screenshots/13-settings.png` | OK — Setup Status, AI Provider, Model Catalog (gpt-5.4-mini), Model Tiers |
| 8 | Settings → Set API key sheet | `tmp/screenshots/14-set-api-key.png` | OK — modal sheet, paste field, Test + Save buttons |
| 9 | Save with empty input | `tmp/screenshots/15-after-save.png` | OK — no exception in flutter logs, sheet remains open (validation prevents write) |

## Findings

### F-01 — App stuck on iOS launch screen on simulator (regression) [x] FIXED

- **Repro:** Install + launch on iPhone 17 Pro (iOS 26.0, `C9AB82C4`). LaunchScreen.storyboard image (eye logo) persists indefinitely; Flutter UI never appears.
- **Root cause:** `lib/main.dart:55-56` calls `await SettingsManager.instance.getApiKey('openai')` before `runApp()`. On unsigned simulator builds, `FlutterSecureStorage.read` raises `PlatformException(-34018, "A required entitlement isn't present")` because the app has neither `application-identifier` nor `keychain-access-groups`. The unhandled async exception kills `main()` before any widget is mounted.
- **Evidence:** `xcrun simctl spawn <sim> log show … Flutter` shows `[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: PlatformException(Unexpected security result code, Code: -34018 …)` originating from `MethodChannel._invokeMethod` called by `main` at `main.dart:56`.
- **Fix:** `lib/services/settings_manager.dart` — wrap every `_secureStorage.read/write/delete` call in `try { … } on PlatformException { return null / no-op; }` via `_readSecure / _writeSecure / _deleteSecure` helpers. Boundary code (system framework call) is the right place to absorb keychain-unavailable. Comment in source explains why.
- **Impact:** App now launches into onboarding on unsigned simulator builds. No behavior change on signed device builds (keychain succeeds, no exception thrown). All 658 tests still pass.
- **Verified:** `tmp/screenshots/07-clean-launch.png` (onboarding rendered) + `bash scripts/run_gate.sh` (ALL GATES PASSED, 133s).

### F-02 — sqlite3.framework built for iOS device platform on incremental rebuild [x] WORKED-AROUND, MONITOR

- **Repro:** After editing `settings_manager.dart` and re-running `flutter build ios --simulator --no-codesign` (no `flutter clean`), launch failed with dyld:
  > Library not loaded: @rpath/sqlite3.framework/sqlite3 … (have 'iOS', need 'iOS-simulator')
- **Inspection:** `otool -l` on the bundled `Frameworks/sqlite3.framework/sqlite3` showed `LC_BUILD_VERSION platform 2` (iOS device) instead of `7` (iOS simulator). Pod was `sqlite3 3.52.0` from `sqlite3_flutter_libs 0.5.42`.
- **Workaround:** `flutter clean && flutter build ios --simulator --no-codesign` rebuilt the framework with `platform 7`. Subsequent rebuilds (gate run) also produced `platform 7`. Could not reproduce a second time after clean.
- **Why not promoted to fix:** Single-occurrence and self-healed by `flutter clean`; pod logic appears sound. If this recurs deterministically, file a Podfile fix to force the simulator slice on first install.
- **Action:** Documented; will re-trigger investigation on next occurrence.

## Resolved bugs (closed in iteration 1)

- F-01: see above.

### Iteration 2 — 2026-04-28 (UTC)

**Validation gate (initial run, with prior modifications staged):** ALL 7 GATES PASSED — 658/658 tests, 0 analyze errors, 0 warnings, 5 critical TODOs (== threshold), simulator build OK, 376s total.

**Validation gate (after F-03 fix):** ALL 7 GATES PASSED — 658/658 tests, 0 analyze errors, 202s total.

**Simulator UI walkthrough (Helix-QA, `C9AB82C4-1107-4E99-867A-E161E90E00CB`):**

| # | Screen | Screenshot | Status |
|---|--------|-----------|--------|
| 1 | App launch (post-fresh-install) | `tmp/screenshots/iter2-01-launch.png` | OK — splash with Helix eye logo |
| 2 | Home (post-skip, persisted onboarding) | `tmp/screenshots/iter2-02-after-launch.png` | OK — Conversation Hub, profile chips, ready stack |
| 3 | Glasses tab (top) | `tmp/screenshots/iter2-03-glasses.png` | OK — OFFLINE badge, Mic Source toggles, Noise reduction, Auto-connect, HUD Brightness |
| 4 | Glasses tab (scrolled) | `tmp/screenshots/iter2-04-glasses-scroll.png` | OK — HUD Widgets entry, Scan for Glasses CTA, "No pairs discovered yet" empty state |
| 5 | HUD Widgets (top) | `tmp/screenshots/iter2-05-hud-widgets.png` | OK — Display Mode picker (Text/Bitmap/Enhanced), Layout (Classic/Minimal/Information Dense), Enlarged words toggle, Glasses Preview, widget list (Clock) |
| 6 | HUD Widgets (after Refresh tap) | `tmp/screenshots/iter2-07-hud-preview.png` | OK — Glasses Preview rendered: date "Tue, Apr 28", time, "No upcoming events", stocks chart, 100% battery |
| 7 | Live tab | `tmp/screenshots/iter2-08-live.png` | OK — Live/History/Projects pills, mic FAB, "No analysis yet" empty state |
| 8 | Projects tab | `tmp/screenshots/iter2-09-projects.png` | OK — Active/Recently deleted segmented, "+" create button, "QA test project" item from prior iteration persisted |
| 9 | Project detail | `tmp/screenshots/iter2-10-project-detail.png` | OK — title, chat/settings/trash icons, "Use for live session" toggle, "No documents" empty state, Upload FAB |
| 10 | Ask AI tab | `tmp/screenshots/iter2-11-askai.png` | OK — Daily AI/Review pills, sparkline, suggestion chips ("What topics came up", "Summarize my last conversation", "What do I know about..."), ask field |
| 11 | Insights → Facts | `tmp/screenshots/iter2-12-insights.png` | OK — Knowledge Graph card, "0 confirmed", chart, "Confirmed facts will appear here." empty state |
| 12 | Insights → Memories | `tmp/screenshots/iter2-13-insights-memories.png` | OK — "No conversations yet" empty state |
| 13 | Settings (top) | `tmp/screenshots/iter2-14-settings.png` | OK — Setup Status, AI Provider OpenAI gpt-5.4-mini, Set API key, Model Catalog (9 options), Model Tiers |
| 14 | Settings (Transcription section) | `tmp/screenshots/iter2-15-settings-scroll1.png` | OK — Light/Smart Model selectors, Temperature slider, OpenAI Session, gpt-4o-transcribe, 24kHz Realtime, Transcription Prompt |
| 15 | Settings (AI Tools / Features) | `tmp/screenshots/iter2-16-settings-scroll2.png` | OK — Web Search, Active Fact-Check, Voice Responses, Sentiment Monitor, Entity Memory, Session Prep, Edit Session Prep |
| 16 | Settings (All-Day / Translation / About) — pre-fix | `tmp/screenshots/iter2-17-settings-scroll3.png` | **F-03 found** — Version "1.0.0" / Build "1" hardcoded, while pubspec.yaml says `2.2.42+53` |
| 17 | Settings (About) — post-fix | `tmp/screenshots/iter2-21-version-fixed.png` | OK — Version `2.2.42` / Build `53` now reflects pubspec source of truth |

## Findings

### F-03 — Settings → About displays hardcoded "1.0.0 / 1" instead of real pubspec version [x] FIXED

- **Repro:** Open Settings → scroll to About. Displayed "Version 1.0.0" and "Build 1".
- **Root cause:** `lib/screens/settings_screen.dart:834-835` (pre-fix) hardcoded the version/build strings in a `_buildInfoTile` call. `pubspec.yaml` is at `version: 2.2.42+53`, so the UI was nearly two majors stale and would silently rot on every release.
- **Fix:** Add `package_info_plus: ^8.0.0` to `pubspec.yaml`, import it in `settings_screen.dart`, store `_appVersion`/`_appBuild` state fields populated via `PackageInfo.fromPlatform()` in a new `_loadPackageInfo()` async method called from `initState`. The About tiles now bind to those fields. Default `'...'` placeholders shown until the platform channel returns. Boundary `try/catch` swallows errors (e.g. in pure-Dart unit tests where the platform plugin isn't registered) so the screen still renders.
- **Impact:** About screen now reads live version 2.2.42 / build 53 from the binary's plist; no more drift between marketing build and displayed version. All 658 tests still pass.
- **Verified:** `tmp/screenshots/iter2-21-version-fixed.png` (Version `2.2.42`, Build `53`) + `bash scripts/run_gate.sh` (ALL GATES PASSED, 202s).

## Resolved bugs (closed in iteration 2)

- F-03: see above.

## Carry-overs / open follow-ups

- F-02: monitor for recurrence.
- Pre-existing tracked debt lives in `TODOS.md` (T-001 through T-010) and `docs/TEST_BUG_REPORT.md` (BUG-001 through BUG-006). Out of scope for this loop iteration unless a gate run flags them.
- CLAUDE.md states version 1.1.0+2; the source of truth is `pubspec.yaml` (`2.2.42+53`). Doc drift not in scope for QA gate.
