# Helix iOS -- UI Design Specification v3

> Comprehensive design document for the Even Companion (Helix) Flutter app.
> All color values, font specs, padding, border radii, and shadow parameters are
> extracted directly from source code. This document is intended to serve as a
> pixel-accurate reference for any LLM or designer recreating every screen.

---

## Table of Contents

1. [Design System](#1-design-system)
2. [App Architecture](#2-app-architecture)
3. [Screen Wireframes](#3-screen-wireframes)
4. [HUD Wireframes](#4-hud-wireframes)
5. [Component Library](#5-component-library)
6. [Navigation and Interaction Patterns](#6-navigation-and-interaction-patterns)
7. [Accessibility](#7-accessibility)

---

## 1. Design System

### 1.1 Color Palette

All colors are defined in `lib/theme/helix_theme.dart` as static constants on
the `HelixTheme` class.

#### Backgrounds

| Token              | Hex         | Usage                                    |
|--------------------|-------------|------------------------------------------|
| `background`       | `#FF07111F` | Scaffold / root background               |
| `backgroundRaised` | `#FF0D1726` | Slightly elevated surfaces               |
| `surface`          | `#FF131D2B` | Card fills, dialog backgrounds           |
| `surfaceRaised`    | `#FF1A2636` | Higher-emphasis card fills               |
| `surfaceInteractive` | `#FF23344A` | Input fields, tappable areas           |

#### Borders

| Token          | Hex         | Usage                       |
|----------------|-------------|-----------------------------|
| `borderSubtle` | `#FF2A3A4D` | Default card/input borders  |
| `borderStrong` | `#FF3A5167` | High-emphasis borders       |

#### Accent Colors

| Token      | Hex         | Usage                                        |
|------------|-------------|----------------------------------------------|
| `cyan`     | `#FF39D7FF` | Primary accent, selected nav icons, links     |
| `cyanDeep` | `#FF117A9D` | Deep cyan for gradients / secondary roles     |
| `purple`   | `#FF6E86FF` | Secondary accent, interview mode, Q&A cards   |
| `lime`     | `#FF75E8A3` | Active/online status, success states          |
| `amber`    | `#FFFFB14A` | Warning banners, passive mode                 |
| `error`    | `#FFFF6B6B` | Error states, recording dot, destructive      |

#### Text Colors

| Token           | Hex         | Usage                           |
|-----------------|-------------|---------------------------------|
| `textPrimary`   | `#FFF4F7FB` | Headlines, body text, labels    |
| `textSecondary` | `#FFAAB6C7` | Subtitles, descriptions         |
| `textMuted`     | `#FF76859A` | Captions, disabled, timestamps  |

#### Derived Colors (Functions)

```dart
// panelFill(emphasis) -- lerp surface..surfaceRaised at 96% opacity
static Color panelFill([double emphasis = 0.0])
  // emphasis 0.0 = surface @ 0.96 alpha
  // emphasis 1.0 = surfaceRaised @ 0.96 alpha

// panelBorder(emphasis) -- lerp borderSubtle..borderStrong
static Color panelBorder([double emphasis = 0.0])
```

#### Provider Accent Colors (Settings Screen)

| Provider    | Hex         |
|-------------|-------------|
| OpenAI      | `#FF39D7FF` (HelixTheme.cyan) |
| Anthropic   | `#FFD59B5B` |
| DeepSeek    | `#FF4DB8FF` |
| Qwen        | `#FF57C785` |
| Zhipu       | `#FF7C83FF` |
| SiliconFlow | `#FFFF8C42` |

#### Mode Colors (Home Screen)

| Mode      | Color           |
|-----------|-----------------|
| General   | cyan `#FF39D7FF`|
| Interview | purple `#FF6E86FF` |
| Passive   | amber / orange  |
| Proactive | `#FFFF6B35`     |

### 1.2 Typography

Font family: **SF Pro Display** (system default on iOS, set via `fontFamily`).

| TextTheme Role    | Size | Weight | Letter Spacing | Line Height | Color         |
|-------------------|------|--------|----------------|-------------|---------------|
| `headlineSmall`   | 28   | w700   | -0.5           | default     | textPrimary   |
| `titleLarge`      | 20   | w700   | 0.2            | default     | textPrimary   |
| `titleMedium`     | 16   | w600   | 0.2            | default     | textPrimary   |
| `bodyLarge`       | 15   | w500   | default        | 1.45        | textPrimary   |
| `bodyMedium`      | 14   | w500   | default        | 1.5         | textSecondary |
| `bodySmall`       | 12   | w500   | default        | 1.45        | textMuted     |
| `labelLarge`      | 14   | w700   | 0.2            | default     | textPrimary   |
| `labelSmall`      | 11   | w700   | 1.0            | default     | textMuted     |

#### Additional Ad-Hoc Text Styles

| Context                  | Size | Weight | Spacing | Notes                                |
|--------------------------|------|--------|---------|--------------------------------------|
| Section label (caps)     | 11   | w700   | 1.2     | cyan @ 0.7 alpha, uppercase          |
| Status badge text        | 10   | w600   | --      | Uses status color                    |
| Connection dot label     | 10   | w500   | --      | white @ 0.5 alpha                    |
| Recording timer          | 11   | w600   | --      | `#FFFF6B6B`, monospace font          |
| Mode chip text           | 12   | w600   | --      | Mode color                           |
| Utility chip text        | 12   | w700   | --      | Chip accent color                    |
| Pill badge (ONLINE etc)  | 11   | w700   | 1.0     | Accent color                         |
| GlowButton label         | 15   | w700   | 0.2     | White                                |
| StatusIndicator label    | 13   | w700   | 0.2     | textPrimary (active), textSecondary  |
| AppBar title             | 20   | w700   | 0.2     | textPrimary                          |
| Navigation bar label     | 11   | w700/w500 | 0.2  | Hidden (alwaysHide)                  |

### 1.3 Spacing Grid

The app uses a soft 4-px grid. Common spacing values found across all screens:

| Token   | Value | Usage                                     |
|---------|-------|-------------------------------------------|
| `xs`    | 4     | Tight gaps (between dots, inline)         |
| `sm`    | 8     | Inter-chip, inter-element                 |
| `md`    | 12    | Section padding start, inline gaps        |
| `base`  | 16    | Default card padding, horizontal margins  |
| `lg`    | 18    | GlassCard section padding                 |
| `xl`    | 20    | Hero card padding, expanded cards         |
| `xxl`   | 24    | Large vertical gaps, divider space        |
| `xxxl`  | 32    | Onboarding horizontal padding             |
| `jumbo` | 40    | Onboarding bottom margin, icon-title gap  |

### 1.4 Elevation and Shadow Tokens

The app does not use Material elevation. Instead, custom `BoxShadow` lists
provide the glassmorphism look.

| Shadow Context           | Color                    | Blur | Spread | Offset     |
|--------------------------|--------------------------|------|--------|------------|
| GlassCard primary        | black @ 0.24             | 18   | 0      | (0, 10)    |
| GlassCard inner glow     | white @ 0.03             | 1    | 0.5    | (0, 0)     |
| GlowButton drop          | darkened base @ 0.26     | 22   | 0      | (0, 12)    |
| GlowButton glow          | base color @ 0.2         | 18   | -4     | (0, 0)     |
| StatusIndicator pulse    | dotColor @ 0..0.55       | 8    | 2      | (0, 0)     |
| Onboarding icon halo     | gradient.first @ 0.3     | 30   | 5      | (0, 0)     |
| NavigationBar shadow     | black @ 0.28             | --   | --     | theme      |
| Recording dot glow       | `#FFFF6B6B` @ 0.5       | 6-8  | 0      | (0, 0)     |

### 1.5 Border Radii

| Context                | Radius |
|------------------------|--------|
| Card (CardTheme)       | 20     |
| GlassCard default      | 16     |
| GlowButton             | 18     |
| Input fields           | 16     |
| SnackBar               | 16     |
| StatusIndicator pill    | 999    |
| Pill badge (ONLINE)    | 999    |
| Utility chip           | 999    |
| Filter chip            | 20     |
| Mode chip              | 12-14  |
| Onboarding page dot    | 4      |
| Dialog                 | 16-18  |
| Status badge           | 8      |

### 1.6 Material Theme Overrides

| Theme Property                        | Value                                |
|---------------------------------------|--------------------------------------|
| `useMaterial3`                        | `true`                               |
| `brightness`                          | `Brightness.dark`                    |
| `scaffoldBackgroundColor`             | `#FF07111F`                          |
| `colorScheme.primary`                 | cyan `#FF39D7FF`                     |
| `colorScheme.secondary`              | purple `#FF6E86FF`                   |
| `colorScheme.surface`                 | `#FF131D2B`                          |
| `colorScheme.onSurface`              | `#FFF4F7FB`                          |
| `colorScheme.error`                   | `#FFFF6B6B`                          |
| `appBarTheme.backgroundColor`         | transparent                          |
| `appBarTheme.elevation`               | 0                                    |
| `appBarTheme.centerTitle`             | true                                 |
| `navigationBarTheme.backgroundColor`  | surfaceRaised @ 0.94 alpha           |
| `navigationBarTheme.indicatorColor`   | surfaceInteractive                   |
| `navigationBarTheme.height`           | 56                                   |
| `navigationBarTheme.labelBehavior`    | alwaysHide                           |
| `dividerTheme.color`                  | borderSubtle @ 0.9 alpha             |
| `dividerTheme.space`                  | 24                                   |
| `dividerTheme.thickness`              | 1                                    |
| `inputDecorationTheme.fillColor`      | surfaceInteractive `#FF23344A`       |
| `inputDecorationTheme.contentPadding` | horizontal 16, vertical 16           |

---

## 2. App Architecture

### 2.1 Launch Flow

```
App Start
  |
  v
AppEntry (StatefulWidget)
  |
  +-- checks SharedPreferences 'onboarding_complete'
  |
  +-- if null -> splash screen (background #0A0E21, cyan spinner)
  |
  +-- if false -> OnboardingScreen (4-page PageView)
  |       |
  |       +-- on complete -> write 'onboarding_complete' = true
  |       +-- transition to MainScreen
  |
  +-- if true -> MainScreen directly
```

### 2.2 Main Screen (5-Tab Shell)

The `MainScreen` uses an `IndexedStack` with a bottom `NavigationBar`.
Tab labels are always hidden (`NavigationDestinationLabelBehavior.alwaysHide`).

```
┌──────────────────────────────────────────┐
│                                          │
│              IndexedStack                │
│  ┌────────────────────────────────────┐  │
│  │  [0] HomeScreen (no AppBar)       │  │
│  │  [1] G1TestScreen                 │  │
│  │  [2] ConversationHistoryScreen    │  │
│  │  [3] DetailAnalysisScreen         │  │
│  │  [4] SettingsScreen               │  │
│  └────────────────────────────────────┘  │
│                                          │
├──────────────────────────────────────────┤
│ ─── top border: white @ 0.08 ─────────  │
│  NavigationBar (height: 56)              │
│  bg: surfaceRaised @ 0.94 alpha          │
│                                          │
│  [chat] [glasses] [history] [chart] [cog]│
│                                          │
└──────────────────────────────────────────┘
```

#### Tab Definitions

| Index | Title     | Icon (unselected)              | Icon (selected)              | Screen Class                  |
|-------|-----------|--------------------------------|------------------------------|-------------------------------|
| 0     | Assistant | `chat_bubble_outline_rounded`  | `chat_bubble_rounded`        | `HomeScreen`                  |
| 1     | Glasses   | `visibility_outlined`          | `visibility`                 | `G1TestScreen`                |
| 2     | History   | `history`                      | `history`                    | `ConversationHistoryScreen`   |
| 3     | Detail    | `analytics_outlined`           | `analytics_rounded`          | `DetailAnalysisScreen`        |
| 4     | Settings  | `settings_outlined`            | `settings`                   | `SettingsScreen`              |

- Selected icon color: cyan `#FF39D7FF`, size 24
- Unselected icon color: textMuted `#FF76859A`, size 24
- Tab 0 (HomeScreen) has **no AppBar**; tabs 1-4 show a centered AppBar title
- `MainScreen.switchToTab(int)` is a static method that child screens can call
  to programmatically change tabs (e.g., Home -> Settings for API key setup)

### 2.3 Assistant Profiles

Defined in `lib/models/assistant_profile.dart`. Four default profiles:

| ID           | Name         | Answer Style                              |
|--------------|--------------|-------------------------------------------|
| `general`    | General      | Brief, useful, and adaptable.             |
| `professional` | Professional | Clear, direct, and business-ready.      |
| `social`     | Social       | Warm, natural, and conversational.        |
| `interview`  | Interview    | Confident, structured, and evidence-backed.|

Each profile controls visibility of: Summary Tool, Follow-ups, Fact Check,
Action Items.

### 2.4 Conversation Modes

| Mode      | Description                                   |
|-----------|-----------------------------------------------|
| General   | Default; balanced conversation assistance      |
| Interview | Structured coaching (STAR framework support)   |
| Passive   | Quiet listener; chimes in only when it matters |
| Proactive | Active monitoring with word/segment stats      |

### 2.5 Quick Ask Presets

| Preset       | Icon                          | Description                          |
|--------------|-------------------------------|--------------------------------------|
| Concise      | `flash_on_rounded`            | Default short answer, fastest        |
| Speak For Me | `record_voice_over_outlined`  | Rewrite for natural speech           |
| Interview    | `badge_outlined`              | Persuasive interview answer          |
| Fact Check   | `fact_check_outlined`         | Verification-focused                 |

---

## 3. Screen Wireframes

### 3.1 Onboarding Screen

4-page PageView with gradient icon circles, centered text, and page dots.

```
┌──────────────────────────────────────────┐
│                                [Skip] >> │  TextButton, white @ 0.5, 15px
│                                          │
│                                          │
│              ┌──────────┐                │  100x100 circle
│              │  (icon)  │                │  gradient bg (page-specific)
│              │   44px   │                │  glow shadow: first color @ 0.3
│              └──────────┘                │  blur 30, spread 5
│                                          │
│                                          │  SizedBox(height: 40)
│          Welcome to Even Companion       │  28px, bold, white, -0.5 ls
│                                          │
│       Your AI-powered conversation edge  │  16px, w500, cyan @ 0.8
│                                          │
│        Imagine never being caught off    │  15px, white @ 0.5
│        guard in a conversation again...  │  height: 1.6, center align
│                                          │
│                                          │
│             ●──── ○  ○  ○               │  Dots: active=24w cyan, inactive=8w
│                                          │  height: 8, borderRadius: 4
│                                          │  SizedBox(height: 32)
│     ┌─────────────────────────────┐      │
│     │     [arrow] Next            │      │  GlowButton (cyan)
│     └─────────────────────────────┘      │  Last page: "Get Started"
│                                          │  SizedBox(height: 40)
└──────────────────────────────────────────┘
```

**Page Gradients:**
1. `[cyan, purple]` -- Welcome
2. `[#00D4FF, #00FF88]` -- Smart Listening
3. `[purple, #FF6B6B]` -- Your Choice of AI
4. `[#FF6B6B, #FFAA00]` -- Glasses + Phone

**Icons:** `auto_awesome`, `hearing`, `psychology`, `visibility`

### 3.2 Home Screen (Tab 0 -- Assistant)

The home screen has no AppBar. It uses a SafeArea with a custom compact status
bar, an optional setup banner, a chat list, a floating real-time transcript
overlay, and a composer dock pinned at the bottom.

#### 3.2.1 Idle State (No API Key)

```
┌──────────────────────────────────────────┐
│ SafeArea (padding: 12,8,12,0)            │
│                                          │
│ ┌─ Status Bar ─────────────────────────┐ │
│ │ [General v] ● G1   [Idle]  [tune] │ │  Mode chip | dots | status | tune
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Setup Banner (orange) ──────────────┐ │  GlassCard opacity=0.08
│ │ ⚠ Connect OpenAI, Anthropic...      │ │  border: orange @ 0.3
│ │   Add API keys in Settings...        │ │
│ │                          [Settings]  │ │  Taps -> switchToTab(4)
│ └──────────────────────────────────────┘ │
│                                          │
│              ┌──────────┐                │
│              │  (empty)  │               │  Empty chat area
│              │           │               │
│              └──────────┘                │
│                                          │
│ ┌─ Composer Dock ──────────────────────┐ │  GlassCard, pinned bottom
│ │  [text field]                 [mic]  │ │  height: 66
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

#### 3.2.2 Active Recording State

```
┌──────────────────────────────────────────┐
│ ┌─ Status Bar ─────────────────────────┐ │
│ │ [General v] ● G1  ● 02:34 [Listen] [t]│  Red pulsing dot + timer
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Chat List (ScrollView) ─────────────┐ │
│ │                                      │ │
│ │  ┌─ User Bubble ──────────────────┐  │ │  Right-aligned
│ │  │ "Tell me about your experience"│  │ │  Transcribed text
│ │  └────────────────────────────────┘  │ │
│ │                                      │ │
│ │  ┌─ AI Bubble ────────────────────┐  │ │  Left-aligned
│ │  │ "Based on the conversation..." │  │ │  Streaming response
│ │  │  [Rephrase] [Translate]        │  │ │  Response tools
│ │  │  [Fact Check] [Send to G1]     │  │ │
│ │  │  [Copy]                        │  │ │
│ │  └────────────────────────────────┘  │ │
│ │                                      │ │
│ │  ┌─ Follow-up Chips ──────────────┐  │ │  Horizontal scroll
│ │  │ [Ask about X] [Clarify Y]     │  │ │
│ │  └────────────────────────────────┘  │ │
│ │                                      │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Realtime Transcript (floating) ─────┐ │  Positioned above composer
│ │ "...and I think the key thing is..." │ │  Partial italic, cyan tinted
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Composer Dock ──────────────────────┐ │
│ │  [text field]             [STOP mic] │ │  Red-tinted stop button
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

#### 3.2.3 Status Bar Detail

```
┌──────────────────────────────────────────────────────────────┐
│ [Mode v] ● src  {stats?}  {● timer?}  [status]  [tune] LLM │
└──────────────────────────────────────────────────────────────┘

Mode chip:      padding h:10 v:6, borderRadius:12, modeColor bg @ 0.12
                border: modeColor @ 0.25
                icon 13px + label 12px w600 + expand_more 12px
                Tappable -> opens ModePickerSheet

Connection:     6px circle (cyan=connected, grey=disconnected)
                + "G1" or "Phone" label, 10px w500

Stats:          (proactive+recording only) "42w 3seg", 10px w600
                color #FF6B35 @ 0.7

Recording dot:  7px circle #FF6B6B, pulsing shadow
                + "02:34" timer, 11px w600 monospace

Status badge:   padding h:8 v:3, borderRadius:8
                5px dot + status text 10px w600

Tune button:    padding:6, borderRadius:8, modeColor bg @ 0.1
                tune_rounded icon 14px
                Tappable -> opens AssistantSetupSheet

Provider label: 11px, white @ 0.4
```

#### 3.2.4 Mode Picker Bottom Sheet

```
┌──────────────────────────────────────────┐
│          ─── (drag handle 42x4) ───      │  white @ 0.18, radius 999
│                                          │
│              Select Mode                 │  16px, w700, white
│                                          │
│  ┌────────────┐  ┌────────────┐          │  Wrap with spacing:8
│  │ ● General  │  │   Interview │          │  AnimatedContainer
│  │ (selected) │  │             │          │  Selected: color bg @ 0.15
│  └────────────┘  └────────────┘          │  border: color @ 0.3
│  ┌────────────┐  ┌────────────┐          │  Unselected: transparent
│  │   Passive  │  │  Proactive │          │  border: white @ 0.06
│  └────────────┘  └────────────┘          │  radius: 14
│                                          │  padding: h12 v10
└──────────────────────────────────────────┘
  Hosted in GlassCard(opacity:0.2, border: modeColor @ 0.24)
```

#### 3.2.5 Assistant Setup Bottom Sheet

A scrollable bottom sheet (`isScrollControlled: true`) with sections:

```
┌──────────────────────────────────────────┐
│          ─── (drag handle) ───     [X]   │
│                                          │
│  Assistant Setup                         │  20px w700
│  Adjust the active profile and...        │  13px, white @ 0.62
│                                          │
│  ┌─ PROFILE STRIP ────────────────────┐  │  Horizontal scroll
│  │ [General] [Professional] [Social]  │  │  of profile cards
│  │ [Interview]                        │  │
│  └────────────────────────────────────┘  │
│                                          │
│  ┌─ ANSWER PRESET ───────────────────┐   │  Horizontal scroll
│  │ [Concise] [Speak For Me]          │   │  of preset chips
│  │ [Interview] [Fact Check]          │   │
│  └───────────────────────────────────┘   │
│                                          │
│  ┌─ Loadout Preview Card ────────────┐   │  Summary of selections
│  │  Profile: General                 │   │
│  │  Preset: Concise                  │   │
│  │  Backend: Apple Cloud             │   │
│  │  Mic: Auto                        │   │
│  └───────────────────────────────────┘   │
│                                          │
│  TOOLING                                 │  11px w700, ls1.1
│  ┌─ Toggle Tiles ────────────────────┐   │
│  │  [x] Summary Tool                │   │
│  │  [x] Follow-up Suggestions       │   │
│  │  [x] Fact Check                   │   │
│  │  [x] Action Items                 │   │
│  └───────────────────────────────────┘   │
│                                          │
│  AUTO SURFACES                           │
│  ┌─ Toggle Tiles ────────────────────┐   │
│  │  [x] Auto Insights               │   │
│  │  [x] Auto Follow-ups             │   │
│  └───────────────────────────────────┘   │
└──────────────────────────────────────────┘
```

### 3.3 Glasses Screen (Tab 1 -- G1TestScreen)

SingleChildScrollView with multiple GlassCard sections. The layout changes
significantly based on connection state.

#### 3.3.1 Disconnected State

```
┌──────────────────────────────────────────┐
│              Glasses (AppBar)            │
│                                          │
│ ┌─ Hero Card ──────────────────────────┐ │  GlassCard padding:20
│ │ ┌────┐                               │ │
│ │ │icon│ Waiting for Glasses            │ │  58x58 gradient icon box
│ │ │ 30 │ Left: disconnected...   [OFF] │ │  radius:18
│ │ └────┘                      OFFLINE   │ │  orange gradient when disconn.
│ │                                       │ │
│ │ Scan for nearby glasses, pick a pair  │ │  14px, white @ 0.7, h1.45
│ │ and return here once the hardware...  │ │
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ MIC SOURCE ─────────────────────────┐ │  GlassCard padding:18
│ │ ○ Phone only                         │ │  RadioListTile x3
│ │ ● Glasses mic                        │ │  activeColor: cyan
│ │ ○ Auto (glasses when connected)      │ │
│ │ ─────────────────────────────        │ │
│ │ [toggle] Noise reduction             │ │  SwitchListTile
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ GLASSES SETTINGS ───────────────────┐ │  GlassCard padding:18
│ │ [toggle] Auto-connect                │ │  SwitchListTile
│ │ HUD Brightness ═══════○══            │ │  Slider, cyan active
│ │ ─────────────────────────────        │ │
│ │ [dashboard_customize] HUD Widgets    │ │  ListTile -> HudWidgetsScreen
│ │   3 widgets . 2 pages           [>]  │ │
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ CONNECTION FLOW ────────────────────┐ │  GlassCard padding:18
│ │ Start a scan to discover available   │ │
│ │ left/right G1 pairs...               │ │  13px, white @ 0.66
│ │                                      │ │
│ │ ┌──────────────────────────────────┐ │ │
│ │ │ [BT icon] Scan for Glasses      │ │ │  GlowButton (cyan)
│ │ └──────────────────────────────────┘ │ │
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ No pairs discovered yet ────────────┐ │  GlassCard padding:22
│ │ [BT disabled icon 42px]              │ │  white @ 0.28
│ │ No pairs discovered yet              │ │  16px w600
│ │ Run a scan and stay close...         │ │  13px, white @ 0.58
│ └───────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

#### 3.3.2 Scanning State

The CONNECTION FLOW card changes:

```
│ ┌─ CONNECTION FLOW ────────────────────┐ │
│ │ Scanning now. Nearby pairs will      │ │
│ │ appear below as soon as...           │ │
│ │                                      │ │
│ │        (spinner 28x28)               │ │  CircularProgressIndicator
│ │        [Stop Scan]                   │ │  cyan, strokeWidth 2.2
│ └───────────────────────────────────────┘ │
```

#### 3.3.3 Discovered Pairs

```
│ AVAILABLE PAIRS                          │  Section label
│ ┌─ Pair Card ──────────────────────────┐ │  GlassCard, tappable InkWell
│ │ ┌──────┐ Pair 1                      │ │  48x48 icon box
│ │ │  BT  │ L: Even_G1_L_001     [>]   │ │  cyan bg @ 0.14
│ │ │ icon │ R: Even_G1_R_001           │ │  border: cyan @ 0.22
│ │ └──────┘                             │ │  16px w700 title
│ └───────────────────────────────────────┘ │  12px, white @ 0.65
```

#### 3.3.4 Connected State

Hero card changes to cyan gradient, "G1 Ready", "ONLINE" badge.
Additional sections appear:

```
│ ┌─ SYSTEM SNAPSHOT ────────────────────┐ │  GlassCard padding:18
│ │ [battery] Battery path    Connected  │ │  _buildInfoRow rows
│ │ ─────────────────────────────        │ │
│ │ [bluetooth] BLE channel   Active     │ │
│ │ ─────────────────────────────        │ │
│ │ [hearing] Microphone route Ready     │ │
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ TILT DASHBOARD ──── [BITMAP] ───────┐ │  Render path badge
│ │ [gesture] Last trigger   HH:MM:SS   │ │
│ │ ─────────────────────────────        │ │
│ │ [sensors] Observed event  ...        │ │
│ │ 0xFF02... (monospace hex)            │ │  12px, SF Mono
│ │                                      │ │
│ │ Last resolved snapshot               │ │  13px w600
│ │ ┌──────────────────────────────────┐ │ │  Container bg #111A31
│ │ │ Snapshot text...                 │ │ │  radius:16
│ │ └──────────────────────────────────┘ │ │
│ │ [dash icon] Preview Dashboard        │ │  GlowButton
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ LAST HANDOFF ──── [DELIVERED] ──────┐ │  Status badge (green/red/orange)
│ │ Preview text of last handoff...      │ │  15px w600
│ │ source . Transfer updated            │ │  12px, white @ 0.56
│ │ [playlist icon] Push Last Handoff    │ │  GlowButton (disabled if offline)
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ UTILITY DECK ───────────────────────┐ │
│ │ Launch focused tools for HUD text... │ │  13px, white @ 0.66
│ │ [HUD Text] [Notifications] [BMP]    │ │  _UtilityChip widgets
│ │ [auto_awesome] Open Utilities        │ │  GlowButton -> FeaturesPage
│ └───────────────────────────────────────┘ │
│                                          │
│ ┌─ Disconnect ─────────────────────────┐ │  GlassCard h:10 padding
│ │ [BT disabled] Disconnect             │ │  TextButton, redAccent @ 0.9
│ └───────────────────────────────────────┘ │
```

### 3.4 History Screen (Tab 2 -- ConversationHistoryScreen)

#### 3.4.1 Empty State

```
┌──────────────────────────────────────────┐
│              History (AppBar)            │
│                                          │
│ Sessions  0 sessions . 0 fav     [search]│  Compact header
│                                          │
│ [All] [General] [Interview] [Passive]    │  Mode filter chips
│  | [All] [Favorites] [Action] [Fact]     │  Library filter chips
│                                          │  Horizontal ListView h:44
│                                          │
│              ┌──────────┐                │
│              │  (icon)  │                │  96x96 gradient circle
│              │  40px    │                │  cyan..purple gradient
│              └──────────┘                │  auto_stories_rounded
│                                          │
│          No Sessions Yet                 │  22px w700
│    Your assistant sessions will          │  14px, white @ 0.54
│    collect here as reusable...           │  h1.5, center align
│                                          │
└──────────────────────────────────────────┘
```

#### 3.4.2 Populated State

```
┌──────────────────────────────────────────┐
│ Sessions  12 sessions . 3 fav    [search]│
│                                          │
│ ┌─ Search Bar (collapsible) ───────────┐ │  AnimatedContainer h:52/0
│ │ [search icon] Search sessions...  [x]│ │  GlassCard radius:16, cyan tint
│ └──────────────────────────────────────┘ │
│                                          │
│ [All*] [General] [Interview] [Passive]   │  Selected: color bg @ 0.18
│  | [All] [Favorites*] [Action] [Fact]    │  border: color @ 0.56
│                                          │  Unselected: white @ 0.04
│ ┌─ Session Card ───────────────────────┐ │  border: white @ 0.12
│ │ ★  General  12 turns  5m ago        │ │
│ │ "Can you explain the architecture..."│ │  GlassCard, expandable
│ │                             [expand] │ │
│ │ ┌─ Expanded Turns ────────────────┐  │ │  (when expanded)
│ │ │ User: "Can you explain..."      │  │ │
│ │ │ AI: "The architecture uses..."  │  │ │  Copy button per turn
│ │ └─────────────────────────────────┘  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Session Card ───────────────────────┐ │
│ │    Interview  8 turns  2h ago       │ │
│ │ "Tell me about a time when..."      │ │
│ └──────────────────────────────────────┘ │
│                                          │
│        [Clear History]                   │  TextButton, bottom
└──────────────────────────────────────────┘
```

**Filter Chip Colors:**
- Mode: General=cyan, Interview=purple, Passive=orangeAccent
- Favorites: `#FFFFC857`
- Action Items: `#FF7CFFB2`
- Fact-check Flags: `#FFFFA726`

**Timestamp Formatting:**
- <1 min: "Just now"
- <1 hour: "Xm ago"
- <1 day: "3:45 PM"
- <7 days: "Mon 3:45 PM"
- older: "Mar 15"

### 3.5 Detail Screen (Tab 3 -- DetailAnalysisScreen)

#### 3.5.1 Idle State (Not Recording)

```
┌──────────────────────────────────────────┐
│              Detail (AppBar)             │
│                                          │
│                                          │
│ ┌─ Post-Conversation Analysis ─────────┐ │
│ │                                      │ │
│ │ (empty if no recording has occurred) │ │
│ │                                      │ │
│ │ ┌─ Summary ───────────────────────┐  │ │  If _postAnalysis != null:
│ │ │ Core summary: The discussion... │  │ │  AssistantInsightSnapshot
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ ┌─ Topics ────────────────────────┐  │ │  Chip list
│ │ │ [Architecture] [Performance]   │  │ │
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ ┌─ Action Items ──────────────────┐  │ │  Bullet list
│ │ │ - Review the documentation     │  │ │
│ │ │ - Schedule follow-up meeting   │  │ │
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ ┌─ Sentiment ─────────────────────┐  │ │
│ │ │ Positive / Smooth              │  │ │
│ │ └─────────────────────────────────┘  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│           (●) Start Recording            │  FAB, center float
└──────────────────────────────────────────┘
```

#### 3.5.2 Active Recording State

```
┌──────────────────────────────────────────┐
│              Detail (AppBar)             │
│                                          │
│ ┌─ Recording Indicator ────────────────┐ │  GlassCard opacity:0.14
│ │ ●  Recording           02:34        │ │  border: #FF6B6B @ 0.3
│ └──────────────────────────────────────┘ │  10px red dot + glow
│                                          │
│ ┌─ LIVE TRANSCRIPT ────────── seg 5 ──┐ │  GlassCard opacity:0.1
│ │                                      │ │  border: cyan @ 0.2
│ │ Finalized segment 1...               │ │  14px, white @ 0.88
│ │ Finalized segment 2...               │ │  h1.5
│ │ Finalized segment 3...               │ │
│ │ live partial text here...            │ │  14px italic, cyan @ 0.75
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ STAR Coaching (interview mode) ─────┐ │  (conditional)
│ │ Situation: Describe the context...   │ │  coaching.prompt
│ │ Task: What was your role?            │ │
│ │ Action: What steps did you take?     │ │
│ │ Result: What was the outcome?        │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Q&A Card ───────────────────────────┐ │  GlassCard opacity:0.08
│ │ ? What is the deployment strategy?   │ │  border: purple @ 0.22
│ │ ┌─────────────────────────────────┐  │ │  question: purple 14px w700
│ │ │ "...heard them say about using  │  │ │  excerpt: white @ 0.03 bg
│ │ │  blue-green deployments..."     │  │ │
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ The deployment strategy involves...  │ │  answer: 14px white @ 0.9
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Stats Bar ──────────────────────────┐ │  Compact stats
│ │ 142 words  .  5 segments             │ │
│ └──────────────────────────────────────┘ │
│                                          │
│           (■) Stop Recording             │  FAB (red tint)
└──────────────────────────────────────────┘
```

### 3.6 Settings Screen (Tab 4 -- SettingsScreen)

SingleChildScrollView with sectioned GlassCard groups.

```
┌──────────────────────────────────────────┐
│              Settings (AppBar)           │
│                                          │
│ ┌─ AI Provider [psychology icon] ──────┐ │  Section header
│ │                                      │ │
│ │ ┌─ Provider Selector ─────────────┐  │ │  Ordered list:
│ │ │ [●] OpenAI     [cyan accent]    │  │ │  openai, anthropic, deepseek,
│ │ │ [ ] Anthropic  [amber accent]   │  │ │  qwen, zhipu, siliconflow
│ │ │ [ ] DeepSeek   [blue accent]    │  │ │  Each with icon, name,
│ │ │ [ ] Qwen       [green accent]   │  │ │  description, protocol,
│ │ │ [ ] Zhipu      [purple accent]  │  │ │  region labels
│ │ │ [ ] SiliconFlow [orange accent] │  │ │
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ ┌─ API Key ───────────────────────┐  │ │  SecureStorage backed
│ │ │ API Key         [Enter] / [Set] │  │ │  TextField or status
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ ┌─ Model Selector ────────────────┐  │ │  DropdownButton
│ │ │ Model: gpt-4o-mini              │  │ │  + "Custom..." option
│ │ │  [Refresh] [Custom...]          │  │ │  -> dialog for custom ID
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ ┌─ Temperature ───────────────────┐  │ │  Slider
│ │ │ Temperature  ═══○═══  0.7       │  │ │
│ │ └─────────────────────────────────┘  │ │
│ │                                      │ │
│ │ ┌─ Connection Test ───────────────┐  │ │
│ │ │ [Test Connection]  [✓ Success]  │  │ │  GlowButton + result
│ │ └─────────────────────────────────┘  │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Conversation [chat icon] ───────────┐ │
│ │ Language: [Auto / EN / ZH / ...]     │ │  DropdownButton
│ │ [x] Auto-detect Questions            │ │  SwitchListTile
│ │ [x] Auto-answer                      │ │  SwitchListTile
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Transcription [mic icon] ───────────┐ │
│ │ Backend: [Apple Cloud v]             │ │  Dropdown: openai, appleCloud,
│ │ (conditional: OpenAI Session Mode)   │ │           appleOnDevice, whisper
│ │ (conditional: Model, Prompt)         │ │
│ │ [x] Speaker Diarization             │ │  (when non-openai)
│ │ Microphone: [Auto v]                 │ │
│ └──────────────────────────────────────┘ │
│                                          │
│ ┌─ Assistant Defaults [tune icon] ─────┐ │
│ │ Profile: [General v]                 │ │
│ │ Default Preset: [Concise v]          │ │
│ │ [x] Auto-show Summary               │ │
│ │ [x] Auto-show Follow-ups            │ │
│ │ Max Response: ══○══ 3 sentences      │ │  Slider 1..10
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

---

## 4. HUD Wireframes

### 4.1 Display Specifications

The G1 smart glasses use a 1-bit monochrome micro-OLED display.

| Property         | Value                                |
|------------------|--------------------------------------|
| Resolution       | 640 x 400 pixels                     |
| Bits per pixel   | 1 (monochrome)                       |
| Row bytes        | 80 (rows padded to 4-byte boundary)  |
| Pixel data size  | 32,000 bytes                         |
| BMP header size  | 62 bytes (14 file + 40 info + 8 CT)  |
| Total BMP size   | 32,062 bytes                         |
| Colors           | White (on) / Black (off)             |

### 4.2 Zone System

Each layout is composed of `HudZone` rectangles and `HudDivider` lines.
Zones define where widgets render. Dividers are 2px thick lines between zones.

### 4.3 Layout Presets

#### 4.3.1 Classic (Quad-Zone)

```
640px
┌─────────────────────┬─────────────────────┐
│                     │                     │  y:0
│     top_left        │     top_right       │
│   316 x 196         │   316 x 196         │
│   clock/weather/    │   stock name+price  │
│   notifications     │                     │
│                     │                     │  y:196
├─────────────────────┼─────────────────────┤  divider y:200
│                     │                     │  y:204
│    bottom_left      │    bottom_right     │
│   316 x 196         │   316 x 196         │
│   calendar event    │  sparkline+battery  │
│                     │                     │
│                     │                     │  y:400
└─────────────────────┴─────────────────────┘
  x:0           x:316  x:324          x:640

Dividers:
  Vertical:   x=320, y=0..400  (2px)
  Horizontal: x=0..316, y=200  (2px) -- left half
  Horizontal: x=324..640, y=200 (2px) -- right half

Default assignments:
  top_left     -> bmp_clock
  bottom_left  -> bmp_calendar
  top_right    -> bmp_stock
  bottom_right -> bmp_battery
```

#### 4.3.2 Minimal (Three-Row)

```
640px
┌─────────────────────────────────────────┐
│              center_top                  │  y:0
│            640 x 120                     │  clock
│                                          │  y:120
├──────────────────────────────────────────┤  divider y:125
│              center_mid                  │  y:130
│            640 x 120                     │  weather
│                                          │  y:250
├──────────────────────────────────────────┤  divider y:255
│              center_bot                  │  y:260
│            640 x 140                     │  calendar
│                                          │  y:400
└──────────────────────────────────────────┘

Dividers:
  Horizontal: x=0..640, y=125  (2px)
  Horizontal: x=0..640, y=255  (2px)

Default assignments:
  center_top -> bmp_clock
  center_mid -> bmp_weather
  center_bot -> bmp_calendar
```

#### 4.3.3 Dense (Information-Dense)

```
640px
┌──────────┬──────────┬─────────────────────┐
│   tl      │    tc     │                     │  y:0
│ 200x196   │ 200x196  │      right          │
│ clock     │ weather  │    232 x 400         │
│           │          │   stock+chart        │
│           │          │                     │  y:196
├───────────┴──────────┤                     │  divider y:200
│                      │                     │  y:204
│    bottom_wide       │                     │
│    404 x 196          │                     │
│  calendar+notif+batt │                     │
│                      │                     │  y:400
└──────────────────────┴─────────────────────┘
  x:0    x:200 x:204  x:404 x:408      x:640

Dividers:
  Vertical: x=404, y=0..400 (2px) -- left group / right column
  Horizontal: x=0..404, y=200 (2px) -- across left group
  Vertical: x=202, y=0..200 (2px) -- between tl and tc

Default assignments:
  tl          -> bmp_clock
  tc          -> bmp_weather
  right       -> bmp_stock
  bottom_wide -> bmp_calendar
```

#### 4.3.4 Conversation (Active Recording)

```
640px
┌──────────────────────────────────────────┐
│              status_bar                   │  y:0
│            640 x 60                       │  recording status + time
│                                           │  y:60
├───────────────────────────────────────────┤  divider y:64
│                stats                      │  y:68
│            640 x 80                       │  Q/A count, word count
│                                           │  y:148
├───────────────────────────────────────────┤  divider y:155
│                                           │  y:160
│               context                     │
│            640 x 240                      │  last question + AI response
│                                           │
│                                           │
│                                           │
│                                           │  y:400
└───────────────────────────────────────────┘

Dividers:
  Horizontal: x=0..640, y=64  (2px)
  Horizontal: x=0..640, y=155 (2px)

Default assignments:
  status_bar -> bmp_clock
  stats      -> bmp_notification
  context    -> bmp_calendar
```

---

## 5. Component Library

### 5.1 GlassCard

**Source:** `lib/widgets/glass_card.dart`

A frosted glass container that provides the primary surface treatment across the
entire application.

| Property      | Type          | Default     | Description                        |
|---------------|---------------|-------------|------------------------------------|
| `child`       | `Widget`      | required    | Content                            |
| `padding`     | `EdgeInsets?` | `all(16)`   | Inner padding                      |
| `borderRadius`| `double?`     | `16.0`      | Corner radius                      |
| `borderColor` | `Color?`      | auto        | Derived from panelBorder(emphasis) |
| `opacity`     | `double`      | `0.15`      | Controls emphasis (0.0 to 0.2+)    |

**Visual Treatment:**

```
emphasis = (opacity / 0.2).clamp(0.0, 1.0)
fill     = panelFill(emphasis)        // surface..surfaceRaised lerp @ 96%
topFill  = Color.lerp(fill, white, 0.04)  // subtle top-left highlight
stroke   = borderColor ?? panelBorder(emphasis)
```

- **Backdrop blur:** `sigmaX: 14, sigmaY: 14`
- **Gradient fill:** `LinearGradient(topLeft -> bottomRight, [topFill, fill])`
- **Border:** 1px, `stroke` color
- **Shadow 1:** black @ 0.24 alpha, blur 18, offset (0, 10)
- **Shadow 2:** white @ 0.03 alpha, blur 1, spread 0.5 (inner glow)

**Usage examples:**
```
GlassCard(child: ...)                    // Default: opacity 0.15
GlassCard(opacity: 0.08, ...)           // Low emphasis (setup banner)
GlassCard(opacity: 0.2, ...)            // High emphasis (sheets)
GlassCard(borderColor: cyan @ 0.2, ...) // Accent border (transcript)
GlassCard(padding: EdgeInsets.zero, ...) // No padding (tappable cards)
```

### 5.2 GlowButton

**Source:** `lib/widgets/glow_button.dart`

A gradient-filled call-to-action button with a colored glow underneath.

| Property   | Type          | Default     | Description                    |
|------------|---------------|-------------|--------------------------------|
| `label`    | `String`      | required    | Button text                    |
| `onPressed`| `VoidCallback`| required    | Tap callback                   |
| `icon`     | `IconData?`   | null        | Leading icon                   |
| `color`    | `Color?`      | cyan        | Base color for gradient + glow |
| `isLoading`| `bool`        | false       | Shows spinner, disables tap    |

**Visual Treatment:**

```
baseColor  = color ?? HelixTheme.cyan (#39D7FF)
shadowColor = Color.lerp(baseColor, black, 0.35)
darkEdge   = Color.lerp(baseColor, background, 0.45)
```

- **Border radius:** 18
- **Gradient:** `LinearGradient(topLeft -> bottomRight, [baseColor, darkEdge])`
- **Border:** 1px, white @ 0.14 alpha
- **Shadow 1:** shadowColor @ 0.26 alpha, blur 22, offset (0, 12)
- **Shadow 2:** baseColor @ 0.2 alpha, blur 18, spread -4
- **Padding:** horizontal 28, vertical 16
- **Text:** white, 15px, w700, letterSpacing 0.2
- **Icon:** white, 20px, gap 10px to label
- **Loading state:** 24x24 CircularProgressIndicator, strokeWidth 2.2, white

### 5.3 StatusIndicator

**Source:** `lib/widgets/status_indicator.dart`

An animated pill-shaped status chip with a pulsing dot.

| Property     | Type     | Default  | Description                          |
|--------------|----------|----------|--------------------------------------|
| `isActive`   | `bool`   | required | Controls animation and color         |
| `label`      | `String` | required | Status text                          |
| `activeColor`| `Color?` | lime     | Dot color when active                |

**Visual Treatment:**

- **Shape:** pill (borderRadius: 999), padding h:12 v:8
- **Background (active):** surfaceInteractive @ 0.96 alpha
- **Background (inactive):** surface @ 0.96 alpha
- **Border (active):** dotColor @ 0.3 alpha
- **Border (inactive):** borderSubtle
- **Dot size:** 8x8 circle
- **Dot (active):** pulsing glow shadow (0.4..1.0 opacity, 1500ms, ease)
  - Shadow: dotColor @ (animation * 0.55), blur 8, spread 2
- **Dot (inactive):** textMuted, no shadow
- **Label (active):** textPrimary, 13px, w700, ls 0.2
- **Label (inactive):** textSecondary, 13px, w700, ls 0.2
- **Transition:** AnimatedContainer, 220ms, easeOutCubic

### 5.4 AnimatedTextStream

**Source:** `lib/widgets/animated_text_stream.dart`

A typewriter-effect text widget that reveals characters from a Stream or static
string.

| Property     | Type            | Default  | Description                     |
|--------------|-----------------|----------|---------------------------------|
| `textStream` | `Stream<String>?`| null    | Incoming text chunks            |
| `staticText` | `String?`       | null     | One-shot text to animate        |
| `style`      | `TextStyle?`    | see below| Custom text styling             |

- **Animation speed:** 30ms per character (`Timer.periodic`)
- **Default style:** white @ 0.9 alpha, 16px, height 1.5
- Stream chunks are appended; the typing timer processes the full accumulated
  text character by character

### 5.5 AssistantPresetStrip

**Source:** `lib/widgets/home_assistant_modules.dart`

Horizontal scrolling list of quick-ask preset chips.

Each chip shows: icon + label + description line. Selection state toggles
color intensity. Section caption: "ANSWER PRESET" with tune_rounded icon.

### 5.6 AssistantProfileStrip

**Source:** `lib/widgets/home_assistant_modules.dart`

Horizontal scrolling list of profile cards (General, Professional, Social,
Interview). Each card shows: name, description, answer style. Selected card
has accent border and elevated emphasis.

### 5.7 AssistantInsightSnapshot

**Source:** `lib/widgets/home_assistant_modules.dart`

Data model that generates post-conversation analysis from transcription and AI
response text. Provides:
- `summary` -- Truncated at 120 chars, prefixed with "Core summary:"
- `topics` -- Top 4 words by frequency (excluding stop words)
- `actionItems` -- Up to 3 sentences matching action keywords
- `sentiment` -- "Positive / Smooth", "Cautious / Risky", or "Neutral / Informational"
- `verificationCandidates` -- Sentences with numbers or fact-related keywords
- `recommendedNextMove` -- Context-aware next-step suggestion

### 5.8 Section Label

A reusable pattern used across Glasses and Detail screens:

```dart
Text(
  'SECTION NAME',
  style: TextStyle(
    color: HelixTheme.cyan.withValues(alpha: 0.7),
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
  ),
)
```

### 5.9 Info Row

Used in Glasses screen telemetry and dashboard cards:

```
[icon 20px cyan]  [label 14px white@0.68]  ...spacer...  [value 14px white w600]
```

### 5.10 Utility Chip

```dart
_UtilityChip(label: 'HUD Text', color: HelixTheme.cyan)
```

- Padding: h:10 v:6
- Background: color @ 0.14 alpha
- Border: color @ 0.2 alpha, radius 999
- Text: color, 12px, w700

### 5.11 Filter Chip (History)

- Padding: h:14 v:8
- Selected: color bg @ 0.18, border color @ 0.56, radius 20
- Unselected: white @ 0.04 bg, border white @ 0.12, radius 20
- Text selected: color, 12px, w600
- Text unselected: white @ 0.54, 12px, w500
- AnimatedContainer, 200ms

### 5.12 Pill Badge

Used for ONLINE/OFFLINE, handoff status, render path labels:

- Padding: h:12 v:6 (hero) or h:10 v:6 (smaller)
- Background: accent @ 0.14
- Border: accent @ 0.22, radius 999
- Text: accent, 11px, w700, letterSpacing 1.0

### 5.13 Error Boundary / Error Screen

**Source:** `lib/app.dart`

Catches FlutterError and displays:
- Red error_outline icon (64px)
- "Oops! Something went wrong" (24px bold)
- Error message (16px grey)
- "Try Again" ElevatedButton

### 5.14 Chat Bubbles (Home Screen)

The home screen chat list renders conversation turns as bubbles:

- **User bubble:** Right-aligned, surface fill, rounded corners
- **AI bubble:** Left-aligned, slightly different fill, with response tools row
- **Response tools:** Rephrase, Translate, Fact Check, Send to G1, Copy
  - Appear as small icon+text buttons below the AI response
- **Follow-up chips:** Horizontal scrolling row of tappable suggestion chips

### 5.15 Recording Indicator (Detail Screen)

```
┌──────────────────────────────────────────┐
│  ●  Recording                    02:34   │
└──────────────────────────────────────────┘
  GlassCard(opacity: 0.14, borderColor: #FF6B6B @ 0.3)
  Dot: 10x10, #FF6B6B, shadow blur 8
  Label: "Recording", 13px w700, #FF6B6B
  Timer: 16px w700 monospace, white @ 0.9
```

### 5.16 Q&A Card (Detail Screen)

```
┌──────────────────────────────────────────┐
│ ? What is the deployment strategy?       │  purple 14px w700
│ ┌──────────────────────────────────────┐ │
│ │ "...heard them say about using..."   │ │  Excerpt: white@0.03 bg
│ └──────────────────────────────────────┘ │  border: white@0.06, r:10
│                                          │
│ The deployment strategy involves...      │  Answer: 14px, white@0.9
└──────────────────────────────────────────┘
  GlassCard(opacity: 0.08, borderColor: purple @ 0.22)
```

---

## 6. Navigation and Interaction Patterns

### 6.1 Tab Navigation

- Bottom NavigationBar with 5 icon-only destinations
- `IndexedStack` preserves all tab states simultaneously
- Tab switching via `onDestinationSelected` callback
- Programmatic switching via `MainScreen.switchToTab(int)` static method
  - Used by: Home setup banner -> Settings (tab 4)
  - Used by: Home "View Detail" -> Detail (tab 3)

### 6.2 Modal Bottom Sheets

Two primary bottom sheets from the Home tab:

1. **Mode Picker Sheet:**
   - `showModalBottomSheet`, transparent background
   - Wraps content in GlassCard(opacity: 0.2)
   - Drag handle: 42x4, white @ 0.18, radius 999
   - Closes on selection (tap mode chip -> dismiss)

2. **Assistant Setup Sheet:**
   - `showModalBottomSheet`, transparent, `isScrollControlled: true`
   - Wraps in GlassCard(opacity: 0.18)
   - Has explicit close button (34x34 circle)
   - Scrollable content with profile strip, preset strip, loadout preview,
     and multiple toggle tiles

### 6.3 Push Navigation

- Glasses tab -> `HudWidgetsScreen` (ListTile tap)
- Glasses tab -> `FeaturesPage` / `EvenFeaturesScreen` (GlowButton tap)
- Both use `Navigator.push` with `MaterialPageRoute`

### 6.4 Dialogs

- **Clear History:** AlertDialog, bg: surface, radius 16
- **Custom Model:** AlertDialog, bg: surface, radius 18
- **Realtime Prompt:** AlertDialog, bg: surface, radius 18, multi-line TextField

### 6.5 Recording Interaction

1. User taps mic button in composer dock
2. State resets (clears previous response, transcript, detection)
3. `RecordingCoordinator.toggleRecording()` called
4. Live Activity started via platform channel `method.evenai`
5. Recording state stream updates UI (red dot, timer)
6. Transcript snapshot stream updates in real-time (150ms debounce)
7. AI response stream shows progressive text
8. Question detection highlights detected questions
9. Follow-up chips appear after response settles
10. User taps stop -> recording ends -> post-analysis builds
11. Live Activity ended

### 6.6 Text Input (Composer Dock)

- TextField in composer dock for manual question entry
- "Send" action submits text to `_engine.askQuestion(prompt)`
- Response tools appear below AI response:
  - **Rephrase:** Rewrites answer for natural speech
  - **Translate:** Translates to detected/configured language
  - **Fact Check:** Verifies claims in the answer
  - **Send to G1:** Pushes answer text to glasses HUD
  - **Copy:** Copies answer to clipboard

### 6.7 Localization

The app supports 6 languages with a `_tr()` helper pattern:
- English (default)
- Chinese (zh)
- Japanese (ja)
- Korean (ko)
- Spanish (es)
- Russian (ru)

Language detection: `SettingsManager.instance.language == 'zh'` drives `_isChinese`
boolean used throughout screens.

### 6.8 Error Handling

- **Provider errors:** Displayed inline via `_providerError` state
- **Listening errors:** Displayed inline with localized messages
- **Connection test:** Success/failure shown next to test button
- **Model query errors:** "Could not query models right now" fallback
- **Global errors:** `ErrorBoundary` widget catches FlutterError -> ErrorScreen

---

## 7. Accessibility

### 7.1 Semantic Labels

- Mode selector chips use `Semantics(button: true, label: 'Switch to $label mode')`
- Navigation destinations have `label` properties (even though visually hidden)

### 7.2 Color Contrast

| Text Level   | Foreground         | Background      | Notes                  |
|--------------|--------------------|-----------------|------------------------|
| Primary      | `#FFF4F7FB` (97%)  | `#FF07111F`     | ~15:1 ratio            |
| Secondary    | `#FFAAB6C7` (72%)  | `#FF07111F`     | ~8:1 ratio             |
| Muted        | `#FF76859A` (53%)  | `#FF07111F`     | ~4.5:1 ratio           |
| Accent (cyan)| `#FF39D7FF`        | `#FF07111F`     | ~8:1 ratio             |

All primary and secondary text passes WCAG AA for normal text (4.5:1).
Muted text passes AA at 4.5:1, suitable for decorative captions.

### 7.3 Touch Targets

- NavigationBar height: 56px (exceeds 48px minimum)
- Icon size in nav: 24px (within standard)
- GlowButton padding: h28 v16 (generous tap area)
- Mode chips: h12 v10 (compact but within row of options)
- Filter chips: h14 v8 (within horizontal scrollable)
- Tune button: 26x26 (padding 6 + icon 14, could be improved)

### 7.4 Motion

- StatusIndicator pulse: 1500ms, can be suppressed by checking
  `MediaQuery.of(context).disableAnimations`
- AnimatedContainer transitions: 200-250ms, easeInOut / easeOutCubic
- Mode switch animation: 300ms, easeOutCubic
- Recording pulse: 1200ms, easeInOut (1.0..1.3 scale)
- AnimatedTextStream: 30ms per character (not affected by motion preference)

### 7.5 Dark Mode

The app is dark-only by design (space/glasses aesthetic). There is no light
theme variant. The `ThemeData` brightness is set to `Brightness.dark`.

### 7.6 Recommendations for Improvement

- Add `Semantics` widgets to all GlassCard sections for screen reader grouping
- Add `excludeFromSemantics` to decorative icons (gradient backgrounds)
- Increase tune button tap target to minimum 44x44
- Consider `AccessibleNavigation` wrapping for the IndexedStack
- Add `tooltip` to icon-only buttons (search, close, tune)
- Test VoiceOver flow through all 5 tabs
- Add `MediaQuery.boldTextOf(context)` checks for dynamic type support
