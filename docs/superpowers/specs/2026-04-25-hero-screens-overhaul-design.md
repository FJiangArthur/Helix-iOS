# Hero Screens Visual Overhaul — Design Spec

**Date:** 2026-04-25
**Scope:** Visual upgrade to the three highest-impact screens: Home, Glasses, Insights.
**Direction:** Expressive — push the existing dark-glassmorphism vocabulary into a signature, identity-defining experience.

## Goal

Turn three screens from "clean and competent" into the visual face of the product. The smart-glasses domain gives us permission to be expressive in ways most apps cannot; we use that permission to make Home feel alive, Glasses feel like a real piece of hardware on screen, and Insights feel like reading a living journal.

## Non-Goals

- Refactoring `home_screen.dart` (~4000 lines). The screen gets new widgets composed in; size is unchanged.
- Light theme. The app stays dark-only.
- Hero / shared-element transitions between screens.
- New native telemetry plumbing (RSSI polling, packet-rate, latency streams). Deferred.
- Detail screens, settings, onboarding. Out of scope.
- Backwards compatibility shims for the old visual style. Old `GlassCard` and `GlowButton` continue to work and are still used in non-hero regions; nothing is deprecated in this phase.

## Decisions Locked

| Decision | Choice |
|---|---|
| Screens to overhaul | Home, Glasses (G1Test), Insights |
| Direction | Expressive (vs. Refined / Spatial) |
| Signature moment | Reactive waveform as the Home hero |
| Hot icons | 14 hand-drawn brand icons (enumerated below) |
| Long-tail icon family | SF Symbols (via `cupertino_icons`) |
| Motion budget | Living surface (ambient micro-motion, no cinematic transitions) |
| Component scope | Hero + theme tokens (not a full design-system retrofit) |
| Sequencing | Approach 2 — hero vertical slice first, then formalize tokens |

## Theme Tokens (`HelixTheme` extensions)

Three additive token families. Existing widgets are not forced to adopt them.

### `HelixGradients`

Named `LinearGradient` constants applied to surfaces, borders, and bars.

| Name | Stops | Used by |
|---|---|---|
| `liveSignal` | cyan → purple | Waveform bars, live pill border |
| `quietGlass` | cyan @ 4% alpha, drifts | `LivingPanel` ambient surface |
| `factWarm` | amber → cyan | Freshly-confirmed fact rows in Insights |
| `glassesPhosphor` | green-on-black | Anything depicting the actual HUD |

### `HelixGlow`

Named `BoxShadow` recipes.

| Name | Shape | Used by |
|---|---|---|
| `subtle` | Codified version of today's `GlassCard` shadow | Default, all surfaces |
| `active` | Cyan halo, alpha 28%, blur 22 | Live cards (`LivingPanel.isActive`) |
| `pulse` | Cyan halo animating 0.18 ↔ 0.32 alpha at 1.4s | Waveform border, selected chip |

### `HelixMotion`

Named durations and curves so timing is consistent.

| Name | Duration | Curve | Used by |
|---|---|---|---|
| `fast` | 180ms | `easeOutCubic` | Pressed states, chip taps, waveform bar lerp |
| `standard` | 320ms | `easeOutQuart` | Panel state changes, swipe commit |
| `ambient` | 1400ms | `easeInOutSine` | Gradient drift, breathing |
| `wave` | per-frame, 30Hz cap | RMS-driven | Waveform painter |

A single app-wide `HelixMotion.ambientTicker` (a shared `AnimationController`) drives all 1.4s breathing animations so they stay in sync and we don't burn ticks on disconnected timers.

## New Primitives (`lib/widgets/`)

Five new widgets. Each has one responsibility, defined props, isolated tests.

### `LiveWaveform` (`live_waveform.dart`)

Reactive bar visualization driven by mic RMS.

**Props**
- `Stream<double>? rmsStream` — 0..1, nullable for idle preview
- `Stream<double>? speechProbabilityStream` — 0..1, modulates glow
- `int barCount` — default 28
- `double height` — default 80
- `Gradient barGradient` — defaults to `HelixGradients.liveSignal`

**Behavior**
- Painter runs at 30Hz max, even if streams emit faster.
- Per-bar: lerps to target height with `HelixMotion.fast` (180ms).
- Idle (no stream / null values for >500ms): bars settle into a flat aurora line, gradient drifts on `ambient` 1.4s loop.
- Glow alpha lerps from `speechProbability` 0..1 → 0.18..0.32.
- Decorative — `excludeSemantics: true`.

**Implementation**
- One `CustomPainter` with `repaint: rmsValueNotifier`. Tree never rebuilds on audio frames.
- Per-paint cost: 28 `Canvas.drawRRect` + one gradient. No allocations in `paint()`.

### `LivingPanel` (`living_panel.dart`)

Glass surface with ambient gradient drift and optional active glow.

**Props**
- `Widget child`
- `double emphasis` (0..1) — fill darkness, like `GlassCard.opacity`
- `bool isActive` — toggles `pulse` glow on border
- `EdgeInsets? padding`
- `double? borderRadius`

**Behavior**
- `quietGlass` gradient translates -8px → +8px on the shared `ambientTicker`.
- `isActive: true` adds animated `pulse` border glow synchronized with the ticker.
- Honors `MediaQuery.disableAnimations`: gradient becomes static, glow becomes the average alpha.

**Perf rule:** at most one `LivingPanel` visible at a time per screen. Lists of items use `GlassCard`. The `BackdropFilter` is too expensive to nest.

### `LiveStatusPill` (`live_status_pill.dart`)

State pill with color, label, and dot.

**Props**
- `LiveStatus status` enum: `idle / listening / answering / error`
- `String? label` — defaults per status
- `Duration? elapsed` — when present, appended to label as `mm:ss`

**Behavior**
- State swap: 320ms cross-fade. Dot color and pill stroke lerp over the same window. Pill width animates with `AnimatedSize` if label length changes.
- Dot animation per status:
  - `idle` — static
  - `listening` — 1.2s pulse, alpha 0.6..1.0
  - `answering` — 0.8s pulse, faster
  - `error` — static, no glow
- Semantic label exposes the state ("Listening, 42 seconds elapsed").

### `BreathingChip` (`breathing_chip.dart`)

Entrance + idle micro-motion chip.

**Props**
- `String label`
- `IconData? icon` — accepts `HelixIcon` data via the same enum
- `VoidCallback onTap`
- `BreathingChipTone tone` — `cyan / purple / lime / amber`
- `bool isSelected` — selected state replaces breathe with `pulse` glow
- `int? entranceIndex` — staggers entrance by `60ms × index`, capped at 6

**Behavior**
- Entrance: scale 0.92 → 1.0 + opacity 0 → 1 over 320ms `easeOutQuart`.
- Idle breathe: alpha 0.92 ↔ 1.0 on a 4-second `easeInOutSine` loop. Disabled when `isSelected` (would conflict with `pulse`).
- Honors `MediaQuery.disableAnimations`: static appearance, no entrance / no breathe.

### `HelixIcon` (`helix_icon.dart`)

Single API for both icon families.

**Props**
- `HelixIcons icon` — enum
- `double size` — default 20
- `Color? color`
- `String? semanticLabel`

**Behavior**
- Brand icons (12-15 entries) resolve to a custom SVG painter (`flutter_svg`), assets in `assets/icons/helix/*.svg`.
- All other entries resolve to an SF Symbol via `cupertino_icons`.
- `semanticLabel` defaults: brand icons get a hand-written label; SF Symbol fallback is the symbol name in title case.

**Brand icon list (Phase 1, 14 entries):**
`helix` (logo), `listen`, `glasses`, `hud`, `factCheck`, `buzz`, `transcript`, `memory`, `project`, `profile`, `interview`, `passive`, `pageNext`, `pagePrev`.

## Screen-Level Designs

### Home

The first ~30% of the screen — the hero region — is replaced. Everything below is unchanged.

**Hero card (`HomeHeroCard`, `lib/widgets/home/home_hero_card.dart`):**
- A `LivingPanel` containing:
  - `LiveStatusPill` (top-left), driven by `ConversationEngine.statusStream`.
  - Session timer (top-right) when listening.
  - `LiveWaveform` (~80px tall, full-width), fed by `MicLevelService.rmsStream`.
  - One-line context summary: `Project: {name} · Profile: {name}`.
  - Two primary actions inline: a `GlowButton` (start/stop) and a secondary `IconButton` (switch mode).

**Mode selector (`_buildModeSelector`):**
- Three modes (`general / interview / passive`) become `BreathingChip` instances. Tones: cyan / purple / lime. Selected chip gets `pulse` glow.

**Follow-up + suggestion chips (`_buildFollowUpChipDeck`, `_buildSuggestionChips`):**
- Migrated to `BreathingChip` with staggered entrance.

**Custom Helix icons** in the hero region only:
- `HelixIcons.listen` on the start button
- `HelixIcons.glasses` on the HUD-delivery row
- `HelixIcons.factCheck` on the cited-fact disclosure header

**Unchanged:** transcript message cards, composer, record button, status bar, conditional banners, fact-check disclosure bodies.

**Data flow:**
- `MicLevelService.rmsStream` (new, see below) → `LiveWaveform` painter via a `ValueNotifier`.
- `ConversationEngine.statusStream` (existing) → `LiveStatusPill`.
- Both are `StreamBuilder`s scoped to the hero card so the rest of the screen does not rebuild on every audio frame.

### Glasses (G1Test)

Hero, telemetry, connection workflow, active-pair are upgraded. Lower debug cards stay as-is.

**Hero card (`GlassesHeroCard`, `lib/widgets/glasses/glasses_hero_card.dart`):**
- A `LivingPanel` shaped around the device. Contains:
  - Two glowing dots representing **L** and **R** glasses, each with its own connection state (`disconnected / scanning / connecting / connected`). State→color uses the `LiveStatusPill` palette.
  - A faint horizontal connection bar between the dots — animated dashes when scanning, solid cyan when paired.
  - Battery percentages stacked under each dot, shown only when connected.
  - `LiveStatusPill` showing overall link state and uptime ("LINK READY · 00:08:42").
  - One primary action: `GlowButton` whose label varies by state ("Pair Glasses" / "Reconnect" / "Disconnect").
  - Watermark: `HelixIcons.glasses` at low alpha behind the dots.

**Telemetry card (`_buildTelemetryCard`):**
- Visual upgrade only. Moves to `LivingPanel`, gets `HelixIcon` rows, richer typography and state colors.
- Adds **one** real live indicator: a connection-uptime ticker for the active link, derived from the existing connection-state-change timestamp. No new native code.
- Content stays state-label based (no live charts). Sparklines deferred.

**Connection workflow (`_buildConnectionWorkflow`):**
- Steps become a horizontal `BreathingChip` stepper. Active step gets `pulse`; completed steps fade to a soft check.

**Paired list (`_buildPairedList` / `_buildGlassesCard`):**
- The currently-paired device card is on `LivingPanel` with `isActive: true`. Other paired devices stay on `GlassCard`.

**Custom Helix icons:**
- `HelixIcons.glasses` (hero, paired-list rows)
- `HelixIcons.transcript` (handoff card)
- Connection-state dots use no icon — pure color and shape.

**Unchanged:** Mic Source section, Glasses Settings sliders, Dashboard Debug card, Last Handoff card body, Utility Launcher chips, Disconnect card.

**Data flow:**
- `BluetoothManager` connection-state stream (existing) → two `StreamBuilder`s for L/R dots.
- `BluetoothManager` battery streams (existing) → battery percentages.
- Connection-uptime: a `Ticker` started on connect-complete, stopped on disconnect.

### Insights

Three sub-tabs: Facts, Memories, Buzz. Information-as-aesthetic — the data is the hero.

**Facts tab:**
- **Pending-facts review (`_buildPendingCards`):** new swipe-stack. Top card on `LivingPanel` (active). Next two cards stack behind with reduced opacity and scale. Swipe-confirm/dismiss promotes the next card with the standard 280ms animation. Threshold 40% of card width; below → spring-back over 220ms.
- **Confirmed-facts list:** `factWarm` gradient applied to rows confirmed within the last 60s, fading out via per-row 60s controller (only spun up when the row appears within the freshness window).
- **Search bar:** `LivingPanel` border + `HelixIcons.search` (resolves to SF Symbol `magnifyingglass`).

**Memories tab:**
- **Day-section headers (`_buildDaySection`):** thin 2px cyan-gradient spine on the left, connecting headers down the page.
- **Theme chips (`_buildThemeChip`):** migrated to `BreathingChip` with `tone: cyan`.
- **Memory cards (`_buildMemoryCard`):** subtle gradient drift only on cards that contain themes. Plain cards stay on `GlassCard`.
- **Empty state (`_buildMemoriesEmptyState`):** custom Helix illustration — `HelixIcons.memory` plus a soft halo composition. Defined inline; not a new primitive.

**Buzz tab:**
- **Buzz starters (`_buildBuzzStarters`):** `BreathingChip` row, `tone: purple`.
- **Streaming-text indicator (`_buildSearchingIndicator` / `_StreamingText`):** `LiveStatusPill` in `answering` state replaces the bare progress dot.
- **Citation chips (`_buildCitationChips`):** `BreathingChip` with `tone: lime` (visual differentiation from suggestion chips on Home).

**Unchanged:** day-section grouping logic, search/filter behavior, conversation cards in History, sentiment dots, Buzz chat-bubble structure (`_buildUserBubble` / `_buildAssistantBubble`).

## New Native Code

### `MicLevelService` + `eventMicLevel` platform channel

The waveform needs a 30Hz RMS stream. The native side already has the audio tap for transcription; we add a second observer on the same `AVAudioInputNode` tap that publishes RMS values without changing the audio session config.

**Dart side (`lib/services/mic_level_service.dart`):**
- Singleton, hot-replaceable in tests via `MicLevelService.test()` factory matching `ConversationListeningSession.test()`.
- Exposes `Stream<double> rmsStream` (0..1) and `Stream<double> speechProbabilityStream` (0..1, derived from VAD when available, else null-coalesced to RMS).
- Auto-pauses when no listeners.

**iOS side (`ios/Runner/MicLevelObserver.swift`):**
- Hooks the existing `inputNode` tap. For each PCM buffer, computes RMS over the buffer, sends through `eventMicLevel`. Throttles to 30Hz.
- No new audio session activation — observer is registered alongside the existing transcription tap.
- No-op when transcription is not active (no audio tap exists).

**Channel:** `eventMicLevel` (Flutter `EventChannel`).

### Connection-uptime ticker

Pure Dart. A `DateTime?` field on `BluetoothManager` storing `connectedAt`; `GlassesHeroCard` runs a 1Hz `Ticker` to format the elapsed string. No native changes.

## Motion Specifications

Pulled in section above. Key invariants:

- All ambient motion respects `MediaQuery.disableAnimations`.
- Single shared `ambientTicker` for breathe/drift loops. No per-widget timers.
- Waveform painter is the only widget allowed to repaint at 30Hz.
- No custom page transitions in this phase. Tab switches stay instant.

## Rollout Phases

Each phase is one PR, gated by `bash scripts/run_gate.sh` (the project's mandatory validation gate).

**Phase 1 — Hero vertical slice.**
- Build `MicLevelService` (Dart + iOS).
- Build `HelixGradients`, `HelixGlow`, `HelixMotion` tokens.
- Build primitives: `LiveWaveform`, `LiveStatusPill`, `LivingPanel`, `BreathingChip`, `HelixIcon` (with the 12 brand SVGs).
- Replace Home's hero region only. Ships visibly.

**Phase 2 — Home polish.**
- Migrate Home's mode selector + chip rows to `BreathingChip`.
- Apply Helix icons to hero-adjacent regions on Home.

**Phase 3 — Glasses.**
- Build `GlassesHeroCard` and connection-uptime ticker.
- Visual upgrade to telemetry card.
- Connection-workflow chip stepper.
- Active-pair `LivingPanel`.

**Phase 4 — Insights.**
- Pending-facts swipe stack.
- Day-section spine + theme-chip migration + freshness gradient.
- Buzz tab polish.

## Testing

Each new primitive ships with a widget test in `test/widgets/`:

- `live_waveform_test.dart` — fake `Stream<double>`, painter calls, idle-state fallback, 30Hz throttle.
- `living_panel_test.dart` — golden test for emphasis 0/0.5/1.0 × `isActive` on/off.
- `breathing_chip_test.dart` — entrance, selected vs. unselected, tap callback, `disableAnimations` short-circuit.
- `live_status_pill_test.dart` — one test per state plus state-transition cross-fade.
- `helix_icon_test.dart` — both code paths; assert all `HelixIcons.*` enum values resolve.

Screen-level tests:
- `home_screen_test.dart`: hero region with fake `MicLevelService` and `ConversationEngine`. `LiveStatusPill` reflects engine state; waveform paints. Existing tests must still pass.
- `g1_test_screen_test.dart`: `GlassesHeroCard` L/R dot states across `BluetoothManager` connection states.
- `insights_screen_test.dart`: pending-facts swipe stack renders 3 deep; swipe-confirm advances next card.

`bash scripts/run_gate.sh` runs end-of-phase. No phase ships with `flutter analyze` errors or failing tests.

## Accessibility

- All `HelixIcon` instances accept `semanticLabel`; brand icons get default labels.
- `LiveStatusPill` exposes its state and elapsed time as a semantic label.
- `LiveWaveform` is `excludeSemantics: true` (decorative).
- `BreathingChip` preserves underlying button semantics; breathe animation does not interfere with focus.
- `MediaQuery.disableAnimations` honored by every ambient/breathe loop. The waveform still updates from real audio (it's a live indicator, not decorative motion); idle-state drift stops.

## Risk and Mitigation

| Risk | Mitigation |
|---|---|
| Waveform burns battery | 30Hz cap in painter; `MicLevelService` auto-pauses with no listeners; iOS observer no-ops outside transcription. |
| `LivingPanel` `BackdropFilter` is expensive | Rule: at most one visible at a time per screen. Lists use `GlassCard`. |
| 4000-line `home_screen.dart` makes edits brittle | We compose new widgets in, do not refactor. Each phase touches the file in narrow, named sections. |
| 12 brand SVGs require design work | Phase 1 ships with placeholder SVGs (geometric shapes built from primitives) if final art is not ready; final art replaces placeholders without code changes. |
| Swipe-stack on Insights changes behavior | Behavior is more discoverable (top card on `LivingPanel` clearly signals active). Swipe gestures and thresholds are unchanged from today's vertical-list swipe. |
| Hidden coupling in 4000-line Home | Mitigated by the vertical-slice approach: hero region is the smallest possible incision. If unexpected coupling surfaces, scope can be narrowed without invalidating earlier phases. |

## Out of Scope (explicit)

- Sparklines / live telemetry data plumbing. Deferred.
- Refactoring `home_screen.dart` size.
- Page or hero transitions between screens.
- Detail-screen overhauls (`DetailAnalysisScreen`, `ConversationDetailScreen`, settings, onboarding).
- Light theme. The app is dark-only and stays dark-only.
