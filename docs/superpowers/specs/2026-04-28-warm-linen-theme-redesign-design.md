# Warm Linen — Theme & UI Redesign

**Date:** 2026-04-28
**Status:** Design approved, ready for implementation planning
**Scope:** Visual re-skin of the entire Helix-iOS app. No structural, navigation, or service-layer changes.

---

## Goal

Replace the current dark cool-cyan glassmorphism theme with a light-first, warm, human "companion" aesthetic. Unify icons under a single duotone style. Regenerate illustrations in a coherent line + watercolor style. Migrate ~20 drift-introduced hardcoded `Color(0x...)` literals back into the theme.

## Non-goals

- No new features, screens, or flows.
- No changes to `lib/services/`, BLE, conversation engine, or platform channels.
- No change to the green-on-black HUD bitmap rendering on the glasses themselves (hardware constraint).
- No use of iOS 26 Liquid Glass surfaces.

---

## Direction

- **Mood:** Warm & human (companion-like, calm, inviting)
- **Primary mode:** Light. Dark mode kept as warm secondary, *not* the existing cool cyan.
- **Palette:** Warm Linen — off-white linen base, terracotta accent, sage support, warm gold/brass highlights, warm dark ink text.
- **Icons:** Duotone — line outline + soft terracotta-tinted fill. Phosphor Icons via `phosphor_flutter`.
- **Illustrations:** Line + watercolor wash — delicate ink line over soft transparent watercolor blobs on cream paper.
- **Typography:** Fraunces (serif headings) + Inter (UI/body) + JetBrains Mono (transcripts/dev).

---

## Section 1 — Design tokens

### Color tokens (light, primary)

| Token | Hex | Use |
|-------|-----|-----|
| `bg` | `#F7F4F0` | App background (warm linen) |
| `bgRaised` | `#FBF9F5` | Subtly raised surface |
| `surface` | `#FFFFFF` | Cards, sheets, primary panels |
| `surfaceSunk` | `#F1ECE3` | Sunken surfaces (search, code) |
| `borderHairline` | `#EBE3D7` | Default 1px border |
| `borderStrong` | `#D9CDB9` | Emphasis, focused borders |
| `ink` | `#2C2825` | Primary text (warm near-black) |
| `inkSecondary` | `#6F665C` | Secondary text |
| `inkMuted` | `#A09687` | Tertiary text, captions |
| `accent` | `#D89B7B` | Terracotta — primary actions, brand |
| `accentDeep` | `#B97A5A` | Pressed / active accent |
| `accentTint` | `#F5E2D5` | Accent backgrounds, duotone fills |
| `support` | `#88A89E` | Sage — secondary highlight, links |
| `gold` | `#C7A35F` | Premium / brass — special states |
| `success` | `#6E9E78` | Confirmed facts, ready state |
| `warning` | `#C9A86A` | Thinking, attention |
| `danger` | `#C45A48` | Errors |

### Color tokens (dark, secondary)

Same hue family, inverted lightness:

| Token | Hex |
|-------|-----|
| `bg` | `#1A1612` |
| `bgRaised` | `#221C16` |
| `surface` | `#2A231C` |
| `surfaceSunk` | `#16110D` |
| `borderHairline` | `#3A2F25` |
| `borderStrong` | `#4F3F31` |
| `ink` | `#F2EBDF` |
| `inkSecondary` | `#C2B6A3` |
| `inkMuted` | `#8A7F6E` |
| `accent` | `#E8B393` |
| `accentDeep` | `#C18A68` |
| `accentTint` | `#3A2A20` |
| `support` | `#A8C2B8` |
| `gold` | `#D9B976` |
| `success` | `#8DBE96` |
| `warning` | `#D9C284` |
| `danger` | `#E07A65` |

### Radii

```
radiusSm:      8     (chips, small buttons)
radiusControl: 12    (buttons, inputs)
radiusPanel:   16    (cards, sheets)
radiusLg:      22    (hero panels, modals)
radiusPill:    999   (pills, status dots)
```

### Spacing scale

`HelixSpacing.s4..s48` → 4 / 8 / 12 / 16 / 20 / 24 / 32 / 48 px.

### Motion

```
durationFast: 150ms     (micro-interactions, taps)
durationMed:  250ms     (transitions, accent presses)
durationSlow: 400ms     (page changes, sheet present)
easeOutQuint            (enter)
easeInOutCubic          (transition)
```

Every primary accent action gets a 250ms scale-bounce on press (subtle haptic feel).

### Elevation

```
e1: 0 1px 2px rgba(60,40,20,0.04)     (cards)
e2: 0 4px 12px rgba(60,40,20,0.06)    (raised cards, sheets)
e3: 0 12px 32px rgba(60,40,20,0.10)   (modals, popovers)
```

### Hardcoded color migration

The following hardcoded `Color(0x...)` literals must be replaced with semantic tokens (no inline hex):

- `lib/app.dart:59,61` — bootstrapping background and indicator
- `lib/screens/even_features_screen.dart:53,70,102` — feature accents
- `lib/screens/settings_screen.dart:214,224,234,244,254,264,491,519,549,590,668,1545,1550,1558,2263` — accent palette and dropdown background

Settings screen's per-item `accent` parameter remaps:

| Old | New |
|-----|-----|
| `0xFF7DD3FC` cyan | `accent` (terracotta) |
| `0xFFD59B5B` amber | `gold` |
| `0xFF4DB8FF` sky | `support` (sage) |
| `0xFF57C785` green | `success` |
| `0xFF7C83FF` indigo | `accentDeep` |
| `0xFFFF8C42` orange | `warning` |
| `0xFF1A1F35` dropdown bg | `surface` (with `e2` shadow) |
| `0xFF6E86FF` selection | `accent` |

---

## Section 2 — Typography

### Font families

- **Fraunces** (serif) — display, screen titles, AI answer headings. Open-source, ships bundled.
- **Inter** (sans) — UI body, controls. Replaces SF Pro Display. SF stays as fallback.
- **JetBrains Mono** — transcripts in dev, code, log output.

All bundled in `pubspec.yaml` `fonts:` block (offline-safe; do not use `google_fonts` HTTP fetch — Helix is realtime/conversation-critical).

### Type scale

| Style | Family | Size / Weight / LH | Use |
|-------|--------|---------------------|-----|
| `display` | Fraunces | 32 / 600 / 1.15 | Onboarding hero, empty-state titles |
| `title1` | Fraunces | 24 / 600 / 1.20 | Screen titles, AI answer heading |
| `title2` | Inter | 18 / 600 / 1.30 | Section headings |
| `title3` | Inter | 15 / 600 / 1.35 | Card titles, list group headers |
| `bodyLg` | Inter | 16 / 450 / 1.50 | Primary reading text (transcripts, AI answers) |
| `body` | Inter | 14 / 450 / 1.50 | Default UI text |
| `bodySm` | Inter | 13 / 450 / 1.45 | Secondary text |
| `caption` | Inter | 12 / 500 / 1.40 | Captions, timestamps |
| `label` | Inter | 11 / 600 / 1.30, tracking 0.6 | Uppercase labels, status |
| `mono` | JetBrains Mono | 13 / 400 / 1.50 | Transcripts in dev, code |

### Dynamic Type

All sizes use `MediaQuery.textScaler`. Cap at 1.4× via `MaterialApp.builder` to prevent layout breakage while supporting iOS accessibility settings.

### API

Replace inline `TextStyle(...)` with `HelixType.title1(color: HelixTokens.ink)` etc. New file: `lib/theme/helix_type.dart`.

---

## Section 3 — Components & layout

### Renamed/reskinned widgets (in `lib/widgets/`)

| Old | New | Treatment |
|-----|-----|-----------|
| `GlassCard` | `LinenCard` | White surface, `e1` shadow, 16px radius. Optional `accentTint` wash for highlighted state. Glassmorphism removed. |
| `GlowButton` | `WarmButton` | Three variants: `primary` (terracotta filled, white ink), `secondary` (white filled, ink border), `ghost` (transparent, ink text). 12px radius, 250ms scale-on-press. |
| `StatusIndicator` | unchanged shape | listening → terracotta with 1.5s pulse; thinking → warning gold; ready → success sage; offline → muted ink. |
| `FactCard` | unchanged shape | Linen card with sage left border (4px), duotone fact glyph. Confirmed facts → tiny gold ✓; pending → warning gold dot. |
| `ActiveProjectChip` | unchanged shape | Pill in `accentTint` background, terracotta text, duotone bookmark glyph. |
| `SessionCostBadge` | unchanged shape | Gold chip, mono font for dollar amount. |
| `AnimatedTextStream` | unchanged shape | Terracotta blink cursor; `bodyLg` Inter for transcripts; `title1` Fraunces for AI answers. |
| `HelixVisuals` | superseded | Replaced with watercolor wash backgrounds via illustrations. |

### New components

- `LinenSurface` — base for all cards; owns radius/shadow/border tokens.
- `IconBadge` — duotone icon in soft tinted circle, for empty states and section headers.

### Navigation bar (4 tabs)

- Background: `surface` white with `e2` shadow above (was raised dark).
- Indicator: small terracotta pill *underneath* the icon (not behind it).
- Selected: duotone-weight icons.
- Unselected: line-only icons at 40% ink.
- Height: 62px (unchanged).

### App bar

- Solid `bg` (no transparency).
- Title: `title1` Fraunces centered.
- No shadow at rest. Hairline border appears only when content scrolls underneath.

### Screen-by-screen visual updates (no structural changes)

All 22 screens in `lib/screens/`:

- `home_screen` — watercolor wash backdrop, terracotta CTA, Fraunces greeting.
- `recording_screen` — terracotta circle mic with sage halo when listening; transcript in `bodyLg`; AI answer in `title1` Fraunces with sage left rule.
- `conversation_history_screen` — linen list rows; date pill (gold today / sage yesterday / muted otherwise); duotone chat avatar.
- `settings_screen` — accent remap (per Section 1 table); `e2`-shadowed dropdown surface.
- `onboarding_screen` — three line+watercolor slides (regenerated, see Section 4).
- `even_features_screen` — feature tiles as linen cards with duotone icons in `accentTint` circles.
- `g1_test_screen`, `dev/`, `file_management_screen` — utilitarian: `surfaceSunk` + mono font for log output, otherwise inherit theme.
- `facts_screen`, `memories_screen`, `todos_screen`, `insights_screen`, `ask_ai_screen`, `live_history_screen`, `even_ai_history_screen`, `conversation_detail_screen`, `detail_analysis_screen`, `pending_facts_review`, `session_prep_screen`, `buzz_screen`, `ai_assistant_screen`, `hud_widgets_screen` — uniform linen surfaces, duotone empty-state illustrations (where applicable), Fraunces titles.

### Layout polish

- 16px screen padding (unify from current 12-20px drift).
- 12px gap between cards in lists.
- 16px card content padding.
- Hairline divider uses `borderHairline` token (warmer than current `#2B3541`).

---

## Section 4 — Icons & illustrations

### Icon system

- **Library:** `phosphor_flutter` (~1500 icons, MIT, all six weights including duotone).
- **Wrapper:** `HelixIcon` widget pre-applies duotone weight + theme-aware coloring (`color: ink`, `duotoneColor: accent`, `duotoneOpacity: 0.35`).
- **Registry:** `HelixIcons` — single file mapping every semantic concept to a Phosphor name. Replaces the 235 scattered `Icon(Icons.xxx)` calls.

### Semantic icon registry

| Concept | Phosphor name | Where used |
|---------|---------------|------------|
| `listen` | microphone | recording, home |
| `pause` | pause | recording controls |
| `glasses` | glasses | onboarding, glasses tab, status |
| `ai` | sparkle | AI answer header, ask-ai |
| `chat` | chat-circle-text | history, ask-ai |
| `fact` | check-circle | facts, fact-check chip |
| `memory` | brain | memories screen |
| `todo` | check-square | todos screen |
| `insight` | chart-line-up | insights screen |
| `settings` | gear-six | settings tab |
| `home` | house | home tab |
| `search` | magnifying-glass | search fields |
| `bookmark` | bookmark-simple | active project chip |
| `book` | book-open | conversation detail |
| `bluetooth` | bluetooth | g1 test, status |
| `battery` | battery-medium | g1 status |
| `caret` | caret-right | list rows, navigation |
| `close` | x | dismiss |
| `more` | dots-three | overflow menus |
| `play` | play-circle | playback |
| `record` | record | recording state |
| `cost` | currency-dollar | session cost |
| `device` | device-mobile | text query |
| `cloud` | cloud | transcription backend |
| `lightning` | lightning | realtime model |

Material `Icons.xxx` remains as escape hatch in dev screens only. Anything missing is added to `HelixIcons` rather than inlined.

### Illustration regeneration — LLM prompts

**Style preamble** (prepend to every prompt below):

> Editorial watercolor illustration. Delicate hand-drawn ink line at ~1.5px weight in warm dark brown (#2C2825). Soft, transparent watercolor washes in terracotta (#D89B7B), sage green (#88A89E), and occasional warm gold (#C7A35F). Background is warm cream paper texture (#F7F4F0). Loose, calm, journal-like. Slightly imperfect linework — confident but human. No drop shadows. No gradients-as-effects. No glassmorphism. No neon. No 3D rendering. No hyper-realism. Centered composition, plenty of negative space. Style references: Apple Journal app illustrations, modern editorial book covers, Tom Froese, Maggie Chiang.

**Per-asset prompts:**

1. **`onboarding-glasses-hud.png`** (2048×2048):

   > A pair of round wire-frame smart glasses floating gently centered on the page, one round lens slightly larger than the other in mild perspective. A soft watercolor wash radiates outward from the right lens like quiet sunrise — terracotta into sage, fading to paper. A few faint hand-drawn lines suggest sound waves drifting toward the glasses from below. No face, no person, no text, no UI elements. Calm, inviting, the moment before a conversation begins.

2. **`home-live-conversation.png`** (2048×1536):

   > Two abstract human silhouettes facing each other in profile, drawn as single fluid ink lines, no facial features. Between them, a small watercolor cloud in soft terracotta where their words meet, dotted with three tiny sage circles like sparks of understanding. Below them, a soft sage horizon wash. The moment of being heard. Calm, intimate, journal-like.

3. **`glasses-device-hero.png`** (2048×2048):

   > A single pair of round smart glasses laid flat on warm cream paper, drawn three-quarter overhead view in delicate ink line. Soft terracotta watercolor pooling around the left lens like ink bleeding into paper. A faint sage shadow beneath suggests gentle weight. No background scenery. Object-as-portrait, considered and crafted, like a still life from a notebook.

4. **`insights-knowledge-graph.png`** (2048×2048):

   > A loose hand-drawn knowledge graph: 7-9 small circles connected by gentle curved ink lines, arranged organically like a constellation, not a rigid graph. Each circle is filled with a different soft watercolor wash — most terracotta, one or two sage, one warm gold. A few circles are larger, suggesting central ideas. The connecting lines are dotted in places, solid in others. Cream paper background. Reads as "ideas finding each other."

5. **`helix-app-icon-source.png`** (2048×2048, App Store source):

   > A single helix coil drawn as a continuous calligraphic ink line, two strands twisting around a vertical axis, centered. A soft terracotta watercolor wash glows behind it like dawn. Cream paper background. Bold enough to read at 60×60. Iconic, calm, unmistakably "Helix." No text, no other elements.

**New empty-state illustrations:**

6. **`empty-facts.png`** — A small folded paper note on a desk, faint terracotta watercolor circle behind. Caption: *"Facts will appear here as you converse."*

7. **`empty-memories.png`** — A small bird perched on a curled line, sage wash. Caption: *"Memories collect over time."*

8. **`empty-todos.png`** — A bare branch with one terracotta watercolor leaf budding. Caption: *"Things you mention to do will land here."*

9. **`empty-history.png`** — A single open notebook page, mostly blank. Caption: *"Your conversations live here."*

### Generation workflow

- Recraft v3 (best for editorial illustration), Midjourney v7, DALL-E 3, or Imagen.
- Generate 2048×2048; downscale to retina 2x and 3x.
- Wire empty-state assets into `facts_screen`, `memories_screen`, `todos_screen`, `conversation_history_screen`.
- iOS app icon set regenerated from prompt #5.

---

## Section 5 — Implementation plan

### New files

- `lib/theme/helix_tokens.dart` — color, spacing, radius, motion, elevation tokens.
- `lib/theme/helix_type.dart` — `HelixType` static methods replacing inline `TextStyle`.
- `lib/theme/helix_icons.dart` — `HelixIcons` registry + `HelixIcon` widget wrapping `phosphor_flutter`.
- `lib/widgets/linen_card.dart` — replaces `glass_card.dart`.
- `lib/widgets/warm_button.dart` — replaces `glow_button.dart`.
- `lib/widgets/icon_badge.dart` — duotone icon in tinted circle.

### Heavily modified

- `lib/theme/helix_theme.dart` — full rewrite; light-first `ColorScheme`; dark counterpart; consumes `helix_tokens.dart`.
- `lib/theme/helix_assets.dart` — add empty-state illustration paths.
- `pubspec.yaml` — add `phosphor_flutter`; bundle Fraunces / Inter / JetBrains Mono; add empty-state assets.

### Lightly modified (mechanical)

- All 22 screens: replace hardcoded colors with tokens, `Icon(Icons.xxx)` → `HelixIcon(HelixIcons.xxx)`, `TextStyle(...)` → `HelixType.xxx`.
- 8 widgets in `lib/widgets/`: internal recolor + icon swaps.
- `lib/app.dart`: replace 2 hardcoded color literals.

### Asset replacements

- `assets/illustrations/onboarding-glasses-hud.png`
- `assets/illustrations/home-live-conversation.png`
- `assets/illustrations/glasses-device-hero.png`
- `assets/illustrations/insights-knowledge-graph.png`
- `assets/brand/helix-app-icon-source.png`
- `assets/illustrations/empty-{facts,memories,todos,history}.png` (new)
- iOS app icon set regenerated from new source.

### Deleted (after one-release deprecation window)

- `lib/widgets/glass_card.dart`
- `lib/widgets/glow_button.dart`

### Migration phases

Each phase ends with mandatory `bash scripts/run_gate.sh` per CLAUDE.md.

**Phase 1 — Foundation (no user-visible change)**
- Add `helix_tokens.dart`, `helix_type.dart`, `helix_icons.dart`.
- Add `phosphor_flutter` and bundled fonts.
- Rebuild `helix_theme.dart` to consume tokens, but tokens hold *current* cyan values temporarily to preserve the look exactly.
- Gate must pass.

**Phase 2 — Light theme switch (the one visible jump)**
- Update `helix_tokens.dart` color values to Warm Linen.
- Rewrite `helix_theme.dart` to light-first; add dark counterpart.
- Replace hardcoded `Color(0x...)` literals across `app.dart`, `even_features_screen.dart`, `settings_screen.dart`.
- Visual smoke test on iPhone 17 Pro simulator (`0D7C3AB2`): home, recording, history, settings.
- Gate must pass.

**Phase 3 — Components & icons**
- Add `LinenCard`, `WarmButton`, `IconBadge`, `HelixIcon`.
- Add deprecation shims for old `GlassCard` / `GlowButton` paths.
- Mechanical migration: `Icon(Icons.xxx)` → `HelixIcon(HelixIcons.xxx)` per screen.
- `TextStyle(...)` → `HelixType.xxx` per screen.
- Re-read `docs/superpowers/specs/2026-04-25-hero-screens-overhaul-design.md` to align with in-flight hero screens work and avoid regenerating the same screens twice.
- Gate must pass.

**Phase 4 — Illustrations & app icon**
- Generate 9 illustrations using prompts in Section 4.
- Replace 5 existing assets, add 4 empty-state assets.
- Wire empty states into facts/memories/todos/history screens.
- Replace iOS app icon set.
- Visual review on simulator + device.

**Phase 5 — Cleanup**
- Remove `GlassCard` / `GlowButton` shims.
- Delete `helix_visuals.dart` if fully superseded.
- Update `CLAUDE.md` "Theme" line and any screenshots in `docs/`.

### Risks & mitigations

| Risk | Mitigation |
|------|-----------|
| Hardcoded colors missed | Phase 2 explicit grep `Color(0xFF` step. 20 known instances enumerated in Section 1; visual smoke test surfaces any remainder. |
| `google_fonts` runtime fetch fails offline | Bundle fonts as `pubspec.yaml` assets (~600KB) instead of HTTP fetch. Helix is conversation-realtime; offline risk unacceptable. |
| Phosphor icon coverage gap | Material Symbols fallback via `HelixIcon.material(Icons.xxx)` escape hatch. |
| Illustration generation quality varies | Generate 4 candidates per asset; hand-pick. Recraft v3 strongest for editorial line+watercolor; Midjourney v7 best for line quality. |
| Dynamic Type breaks layout | Cap at 1.4× scaler in `MaterialApp.builder`. |
| iOS 26 Liquid Glass conflicts with paper aesthetic | Don't opt in any surface. Default opaque rendering matches design. |
| Dark mode parity slips | Phase 2 ships both modes together; no ramp where only one exists. Token names mode-agnostic. |
| Overlap with hero-screens overhaul (commit `0197154`, `c13c07b`) | Phase 3 explicitly re-reads `docs/superpowers/specs/2026-04-25-hero-screens-overhaul-design.md` before touching screens. |

### Testing & validation

- `flutter analyze` — 0 errors per phase.
- `flutter test test/` — all existing tests pass (no test changes expected; theme not unit-tested directly).
- `bash scripts/run_gate.sh` — mandatory before any commit per CLAUDE.md.
- Manual visual smoke test on iPhone 17 Pro simulator (`0D7C3AB2`) after Phase 2, 3, 4.
- iOS Dynamic Type test (largest accessibility size) after Phase 4.

---

## Out of scope

- Conversation engine, BLE, transcription, or LLM service changes.
- HUD bitmap rendering on glasses (hardware-constrained palette).
- New features, screens, or flows.
- Liquid Glass adoption.
- Test infrastructure changes.

## Open questions

None remaining. All visual decisions resolved during brainstorming. Ready for implementation plan.
