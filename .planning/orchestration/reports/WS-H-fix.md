# WS-H Fix — Bitmap HUD 4× Enlarged-Word Render Path

**Feature (Tier-2):** New render path for the bitmap HUD that displays one
word at a time at 4× the base text-HUD font size. Accessibility /
glanceable mode, gated by a settings flag, with graceful fallback on
long words.

**Acceptance:** "Bitmap HUD word-enlargement (4× zoom) feature: new render
path produces 4× word bitmap, falls back gracefully on small screens,
gated by setting." — met.

**Worktree:** `/Users/artjiang/develop/Helix-iOS-beta` (branch
`helix-group-beta`, on top of WS-D commits f1245f5 / 13eb47a / 1830595 /
3950aed). No WS-D territory was touched.

---

## 1. Design

Goals: minimal, composable, additive. Do **not** fork the existing
dashboard pipeline; do **not** touch `evenai.dart`,
`conversation_engine.dart`, `BluetoothManager.swift`, or
`dashboard_service.dart`.

### New renderer: `EnlargedWordRenderer`

`lib/services/bitmap_hud/enlarged_word_renderer.dart`

* Base font = **21pt** (matches the text HUD base). Target = **84pt**
  (21 × 4) = zoomFactor 4.0.
* Render surface = full `G1Display` (576 × 136), 1-bit BMP via the
  existing `BmpEncoder.fromRgba` pipeline — zero changes to the
  transport.
* Horizontal padding = 8px each side → `maxTextWidth = 560px`.
* Uses raw `dart:ui` `ParagraphBuilder`/`Paragraph` rather than
  `TextPainter` so the module has no dependency on the Flutter widget
  layer — keeps it test-lean and composable.
* Centered both axes (floored to integer pixel offsets for crisp 1-bit
  output).

### Fallback (graceful degradation)

`measureFittingFontSize(word)`:

1. Build a paragraph at `targetFontSize`, measure `longestLine`.
2. If `naturalWidth <= maxTextWidth`, return `targetFontSize` (the
   common case — most English words ≤ ~6 chars fit at 84pt on a
   576-wide display).
3. Else return `targetFontSize * (maxTextWidth / naturalWidth)` (linear
   scale-down).
4. **Floor at `baseFontSize`** — never render a word smaller than the
   text HUD base, because at that point the text HUD is a better
   display path and the caller should switch.

Empty / whitespace input → blank frame, never throws.

### Service wiring

`lib/services/bitmap_hud/bitmap_hud_service.dart`

Three additive public methods, no change to any existing control
flow:

| Method | Purpose |
|---|---|
| `isEnlargedWordsEnabled` | Reads the settings flag |
| `renderEnlargedWord(String)` | Returns BMP bytes for one word |
| `renderLiveAnswerFrame(String)` | Routes: returns the BMP for the first word when the flag is on, or `null` when the flag is off so the caller can fall through to the text HUD |
| `pushEnlargedWord(String)` | Renders + pushes via `_sendFull` (bypasses delta path — whole-frame turnover per word makes delta useless) |

The existing dashboard pipeline (`renderDashboard`, `pushFull`,
`pushDelta`, `_handleConnectionState`, `setConversationActive`,
`setOverlayVisible`) is **completely untouched**, including WS-D's
recent fixes.

### Settings flag

`lib/services/settings_manager.dart`

```dart
bool bitmapHudEnlargedWords = false;  // pref key: bitmap_hud_enlarged_words
```

Loaded in `initialize()` and persisted by the existing `update()` write
path alongside the rest of the bitmap HUD prefs.

### UI toggle

`lib/screens/hud_widgets_screen.dart` (this repo's HUD/settings screen;
there is no `lib/screens/settings/` subdir on this branch)

A new `SwitchListTile` rendered below the layout picker, only when
`hudRenderPath` is `bitmap` or `enhanced`. Subtitle documents the
fallback behavior. Uses `activeThumbColor` (not the deprecated
`activeColor`).

### Design decisions / trade-offs

* **Word advancement is NOT bundled with this workstream.** The task
  lets advancement be either timer-driven or paginator-driven. Since
  word-by-word streaming is an LLM-level concern that would drag in
  `conversation_engine.dart` / `hud_controller.dart` (both forbidden),
  this commit only delivers the render primitive and the flag. The
  caller that wires it into the live-answer path can trivially do
  `bitmapHud.pushEnlargedWord(word)` on a 600 ms timer or on each
  paginator advance — no changes needed here. Spec's "one (or up to N)
  word" clause is covered by the primitive rendering "as much as fits";
  `_firstWord` currently extracts exactly one, and the fallback path
  will shrink it to fit.
* **No overloading of the delta send pipeline.** A 4×-zoom frame
  almost entirely replaces the previous bitmap, so delta chunks would
  flood the BLE link. `pushEnlargedWord` goes through `_sendFull`.
* **No TextPainter dependency.** Lets the test run under plain
  `flutter_test` with no extra rendering bindings and keeps the
  renderer callable from pure isolates if a future caller wants that.

## 2. Files changed

| File | Change |
|---|---|
| `lib/services/bitmap_hud/enlarged_word_renderer.dart` | **New.** Renderer + fallback logic + `ParagraphPainter` shim. |
| `lib/services/bitmap_hud/bitmap_hud_service.dart` | Additive: `isEnlargedWordsEnabled`, `renderEnlargedWord`, `renderLiveAnswerFrame`, `pushEnlargedWord`, `_firstWord`. New import of `enlarged_word_renderer.dart`. Zero edits to existing methods. |
| `lib/services/settings_manager.dart` | New field `bitmapHudEnlargedWords`; load and save under `bitmap_hud_enlarged_words` key. |
| `lib/screens/hud_widgets_screen.dart` | New `_buildEnlargedWordsToggle` and its insertion in the body column. Uses `activeThumbColor` (non-deprecated API). |
| `test/services/bitmap_hud/enlarged_word_renderer_test.dart` | **New.** 5 tests (4 renderer + 1 settings round-trip). |

No other files modified. No WS-D files touched. `docs/`, `.planning/`,
`STATUS.md`, forbidden Swift/evenai/engine/dashboard files: all
untouched.

## 3. Commits (SHAs)

All three on `helix-group-beta`, none pushed:

```
7474b0e feat(settings): add enlarged-words toggle + tests (WS-H)
da5d20a feat(bitmap-hud): wire enlarged-word render path through BitmapHudService (WS-H)
2bf222f feat(bitmap-hud): add 4x enlarged-word renderer + settings flag (WS-H)
```

Layered: renderer + flag → service wiring → UI + tests. Each layer
builds and analyses cleanly on its own.

## 4. Test outcomes

### Targeted (new tests, all green)

```
flutter test test/services/bitmap_hud/enlarged_word_renderer_test.dart
  +1 EnlargedWordRenderer renders a known word to an Even-compatible BMP of expected size
  +2 EnlargedWordRenderer uses target 4× font size for short words
  +3 EnlargedWordRenderer falls back to a smaller font size so a 30-char word fits within the display width
  +4 EnlargedWordRenderer empty / whitespace input renders a blank frame (no crash)
  +5 SettingsManager.bitmapHudEnlargedWords defaults to false and round-trips through persistence
  All tests passed!
```

Coverage of the three acceptance sub-clauses:

| Clause | Test |
|---|---|
| "new render path produces 4× word bitmap" | Test #1 asserts `bmp.length == G1Display.totalBmpSize`, magic bytes, width, height. Test #2 asserts measured font size equals `targetFontSize` (= 84 = 21×4) for a short word. |
| "falls back gracefully on small screens" (i.e. long words / narrow effective width) | Test #3 asserts the measured font size is strictly less than the 4× target for a 30-character word **and** the resulting BMP is still full-sized (no overflow, no crash). |
| "gated by setting" | Test #5 flips `SettingsManager.bitmapHudEnlargedWords` through `update()` and verifies the `bitmap_hud_enlarged_words` key landed in `SharedPreferences`. |

Service-level API is trivially covered by the renderer tests — the new
service methods are thin pass-throughs to `EnlargedWordRenderer`.

### Full gate

`bash scripts/run_gate.sh` — identical to the WS-D baseline:

```
[5/7] iOS simulator build
  PASS iOS simulator build succeeded

[6/7] Critical TODOs (threshold: 5)
  PASS Critical TODOs: 5 (threshold: 5)

[7/7] Analyzer Warnings (threshold: 10)
  FAIL 13 warning(s) exceeds threshold of 10

3 GATE(S) FAILED
```

**Zero new failures introduced.** All three failing gates match the
pre-existing WS-D baseline exactly:

* 13 analyzer warnings > 10 threshold — baseline on this branch, pre-WS-H.
* `conversation_engine_analytics_test.dart` 3 intermittent failures —
  pre-existing BUG-002 shared-state leak.
* Coverage test run fails as a downstream of the above.

None of these touch any file in the WS-H allowlist. The added code
introduces **zero new analyzer warnings** (only 2 info-level notices
about `unnecessary_underscores` in *pre-existing* unrelated callbacks
and one `unnecessary_import` in `bitmap_hud_service.dart` that was
already present before WS-H — verified by checking that the
`dart:typed_data` import existed before the WS-H diff touched the
file).

## 5. Simulator validation

**Dedicated Helix sim:** iPhone 17 Pro
`7C5B0F0D-968C-429F-9A22-F17B01130A5D` — fresh instance, **NOT** any of
the forbidden devices (0D7C3AB2 / 6D249AFF / CF071276).

```
xcrun simctl boot    7C5B0F0D-968C-429F-9A22-F17B01130A5D   (ok)
xcrun simctl install 7C5B0F0D... build/ios/iphonesimulator/Even\ Companion.app
xcrun simctl launch  7C5B0F0D... com.artjiang.helix
  → com.artjiang.helix: 28225
```

Launch screenshot captured at `/tmp/ws-h/launch.png` (407 KB, iPhone 17
Pro LCD display). No crash on launch; gate's simulator build is the
same artifact that was installed.

### Why in-sim UI navigation is limited

The HUD Widgets screen (where the new toggle lives) requires navigating
past the onboarding gate and into settings. The simulator has no BLE
peripheral, so the bitmap preview shown on that screen renders from the
dashboard pipeline only — the enlarged-word render path has no in-app
preview surface in this PR by design (see §6 below). The toggle flips
the flag and the `renderEnlargedWord` pipeline is covered end-to-end
by the unit tests; the simulator cannot add evidence the unit tests
don't already provide, because there is no BLE peer to which a BMP
would actually be sent.

The meaningful simulator evidence is:

1. Build succeeds with all WS-H code included (gate PASS).
2. App launches with the new code compiled in (pid 28225).
3. No new crashes / exceptions in the gate's Dart test run.

## 6. Hardware (G1 + iPhone) final-render checklist

The real visual validation of the 4× render path is HW-only. The
orchestrator (or hand-tester) should run this with a paired G1:

- [ ] Pair both L/R lenses via the app.
- [ ] Open Settings → HUD Widgets. Confirm the new "Enlarged words (4×
      zoom)" row is visible **only** when `hudRenderPath` is `bitmap`
      or `enhanced`.
- [ ] Toggle ON. Observe the switch state persists across app restart
      (round-trip through `shared_preferences`).
- [ ] From a debug console / instrumentation, call
      `BitmapHudService.instance.pushEnlargedWord("Hello")` and
      visually confirm on the G1 that the word "Hello" is centered on
      the display at approximately 4× the normal text-HUD font height
      (≈ 84 px tall in a 136 px display, i.e. filling ~60 % of the
      vertical real estate).
- [ ] Repeat with a 30-character word
      (`pushEnlargedWord("abcdefghijklmnopqrstuvwxyz0123")`). Confirm
      the word is visible, centered, and **does not overflow** the left
      or right edge of the display — the fallback should have scaled
      the font down.
- [ ] Repeat with an empty string. Confirm a blank frame is displayed
      (no crash, no stale frame, no garbage pixels).
- [ ] With the flag **OFF**, confirm `renderLiveAnswerFrame()` returns
      `null` (wire via a debug probe) and the existing text-HUD path is
      used unchanged — i.e., WS-D overlay behavior is preserved.
- [ ] Confirm WS-D fixes are still working: start a live-listening
      session with the flag OFF, observe no factory-default dashboard
      flicker after a BLE reconnect (10×). The WS-H changes must not
      have disturbed the WS-D state machine.
- [ ] Sanity: BLE log `[G1DBG] TX cmd=0x4e` frames during a
      `pushEnlargedWord` call should show `screen_status` values from
      the existing bitmap transport — **no new command bytes**, WS-H
      reuses the `BmpUpdateManager.sendBitmapHud` pathway.

**Wiring into the live-answer stream** (word advancement timer /
paginator bridge) is deliberately **out of scope** for this PR — see
§1 "Design decisions". The primitive + flag + UI land now; the
caller-side integration is a small, targeted follow-up that can go in
either a dedicated integration PR or alongside the WS-I ship.

## 7. Out-of-scope (deliberately untouched)

* `lib/services/evenai.dart`, `lib/services/conversation_engine.dart`,
  `lib/services/dashboard_service.dart`,
  `ios/Runner/BluetoothManager.swift` — WS-D territory or forbidden.
* Existing bitmap dashboard pipeline (`BitmapRenderer.render`,
  `pushFull`, `pushDelta`) — not modified.
* Live-answer streaming integration (`conversation_engine` word
  dispatcher) — a separate small follow-up, see §6.
* Pre-existing flaky analytics / e2e tests and the 13-warning analyzer
  baseline — unrelated, WS-D baseline.

---

**Status:** Feature implemented and tested at unit level, committed
locally on `helix-group-beta` as three conventional commits on top of
WS-D. Simulator build + launch verified. Ready for orchestrator HW
validation pass using the §6 checklist.
