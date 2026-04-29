# Warm Linen Theme Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the cool-cyan dark glassmorphism theme with a warm, light-first "Warm Linen" aesthetic — new color tokens, typography (Fraunces + Inter + JetBrains Mono), Phosphor duotone icon system, line+watercolor illustrations, and migration of all 60+ drift-introduced hardcoded `Color(0x...)` literals back into the theme.

**Architecture:** Token-first refactor in 5 atomically shippable phases. Phase 1 introduces the token files while preserving the *current* cyan look exactly (no user-visible change). Phase 2 flips the token values to Warm Linen and migrates hardcoded colors. Phase 3 ships new components and migrates icons + typography call sites. Phase 4 replaces illustration assets and the app icon. Phase 5 deletes deprecation shims and updates documentation.

**Tech Stack:** Flutter 3.35+, Dart 3.9+, Material 3, `phosphor_flutter` for duotone icons, bundled `.ttf` fonts in `pubspec.yaml` (no `google_fonts` HTTP fetch — Helix is conversation-realtime and can be offline). iOS 26 deployment target. Existing test infra (`flutter_test`, `mockito`, `bash scripts/run_gate.sh`).

**Spec:** `docs/superpowers/specs/2026-04-28-warm-linen-theme-redesign-design.md`

**Corrections discovered during planning** (override spec where they differ):
- Hardcoded `Color(0x...)` count is **~60+** across `lib/`, not ~20. Full enumeration in Task 7.
- `Icon(Icons.xxx)` count is **~54**, not 235.
- `MainScreen` in `lib/app.dart` has **5 tabs** (Home, Glasses, Live, Ask AI, Insights), not 4.
- HUD bitmap colors in `lib/services/bitmap_hud/` are **out of scope** (hardware constraint, B&W only).

---

## Phase 0 — Setup

### Task 0.1: Confirm gate baseline before starting

**Files:** none

- [ ] **Step 1: Run the validation gate to establish a green baseline**

```bash
bash scripts/run_gate.sh
```

Expected: PASS. If it fails, do not proceed — fix the underlying issue first. The plan assumes a clean starting state.

- [ ] **Step 2: Confirm the dedicated Helix simulator boots**

The simulator UDIDs `0D7C3AB2` (iPhone 17 Pro) and `6D249AFF` (iPhone 17) are in use by other apps. Boot a separate simulator instance for Helix:

```bash
xcrun simctl list devices available | grep -iE "iPhone (16|17)"
```

Pick any available iPhone 16 / 17 device that is **not** `0D7C3AB2` or `6D249AFF`. Save the UDID as `$HELIX_SIM` for later steps. Boot it:

```bash
xcrun simctl boot $HELIX_SIM
open -a Simulator
```

- [ ] **Step 3: Capture a "before" screenshot of every primary screen**

Run the app and screenshot each primary screen for visual diff later:

```bash
flutter run -d $HELIX_SIM
```

Tap through Home, Glasses, Live, Ask AI, Insights, Settings, Onboarding (sign out + relaunch). Save screenshots to `tmp/screenshots/before/` (already gitignored per `tmp/screenshots/` in git status).

```bash
mkdir -p tmp/screenshots/before
xcrun simctl io $HELIX_SIM screenshot tmp/screenshots/before/home.png
# repeat for each screen
```

- [ ] **Step 4: No commit for this task** — it's environment setup only.

---

## Phase 1 — Foundation (no user-visible change)

Goal: Introduce token files, fonts, icon dependency, and a rebuilt theme that consumes tokens. Token *values* are the **current cyan palette** so the app looks identical. This is a refactor with zero pixel changes.

### Task 1.1: Add `phosphor_flutter` dependency

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add the dependency**

Open `pubspec.yaml`. Find the `dependencies:` block (line ~12). Add `phosphor_flutter` directly after `cupertino_icons`:

```yaml
  # UI and Material Design
  cupertino_icons: ^1.0.8
  phosphor_flutter: ^2.1.0
```

- [ ] **Step 2: Fetch packages**

```bash
flutter pub get
```

Expected: succeeds, prints `Got dependencies!` (or `No dependencies changed` if already present).

- [ ] **Step 3: Verify import resolves**

```bash
dart -e 'import "package:phosphor_flutter/phosphor_flutter.dart";' 2>&1 | head -5
```

(That command is illustrative; just confirm the package resolves. The real verification is Task 1.5 compiling.)

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "chore(theme): add phosphor_flutter for duotone icon system

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.2: Bundle Fraunces, Inter, JetBrains Mono

**Files:**
- Create: `assets/fonts/Fraunces-VariableFont.ttf`
- Create: `assets/fonts/Inter-VariableFont.ttf`
- Create: `assets/fonts/JetBrainsMono-VariableFont.ttf`
- Create: `assets/fonts/Fraunces-Italic-VariableFont.ttf` (optional but cheap)
- Create: `assets/fonts/Inter-Italic-VariableFont.ttf` (optional but cheap)
- Modify: `pubspec.yaml`

- [ ] **Step 1: Create the fonts directory**

```bash
mkdir -p assets/fonts
```

- [ ] **Step 2: Download the variable fonts**

The user (or you, if this is run on a machine with curl) downloads these official open-source releases. Files are SIL OFL licensed and safe to bundle.

```bash
cd assets/fonts
# Fraunces (SIL OFL) — variable font with weight + soft + opsz axes
curl -L -o Fraunces-VariableFont.ttf \
  "https://github.com/undercase/fraunces/raw/main/fonts/variable/Fraunces%5BSOFT%2CWONK%2Copsz%2CwGHT%5D.ttf"
# Inter (SIL OFL) — variable font with weight axis
curl -L -o Inter-VariableFont.ttf \
  "https://github.com/rsms/inter/raw/master/docs/font-files/InterVariable.ttf"
# JetBrains Mono (SIL OFL) — variable font
curl -L -o JetBrainsMono-VariableFont.ttf \
  "https://github.com/JetBrains/JetBrainsMono/raw/master/fonts/variable/JetBrainsMono%5Bwght%5D.ttf"
cd ../..
```

If any URL 404s (font repos sometimes restructure), fall back to:
- Fraunces: https://fonts.google.com/specimen/Fraunces → "Get font" → download the variable .ttf from the .zip
- Inter: https://fonts.google.com/specimen/Inter → same
- JetBrains Mono: https://fonts.google.com/specimen/JetBrains+Mono → same

Verify each file is non-empty:

```bash
ls -la assets/fonts/
```

Expected: each `.ttf` is > 100KB.

- [ ] **Step 3: Wire fonts into pubspec.yaml**

Open `pubspec.yaml`. The `flutter:` block starts at line 83. Find the commented `# fonts:` stub at lines 91-95. Replace it with:

```yaml
  fonts:
    - family: Fraunces
      fonts:
        - asset: assets/fonts/Fraunces-VariableFont.ttf
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-VariableFont.ttf
    - family: JetBrainsMono
      fonts:
        - asset: assets/fonts/JetBrainsMono-VariableFont.ttf
```

Also confirm the `assets:` block (sibling key under `flutter:`) lists the fonts directory if a globbed entry doesn't already cover it. If `assets/` is not globbed, add:

```yaml
  assets:
    - assets/fonts/
```

- [ ] **Step 4: Run pub get**

```bash
flutter pub get
```

Expected: succeeds.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml assets/fonts/
git commit -m "chore(theme): bundle Fraunces, Inter, JetBrains Mono fonts

Variable fonts shipped as assets (no runtime HTTP fetch). Required
for Warm Linen typography rebuild.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.3: Create `helix_tokens.dart` with current cyan values

**Files:**
- Create: `lib/theme/helix_tokens.dart`
- Test: `test/theme/helix_tokens_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/theme/helix_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_tokens.dart';

void main() {
  group('HelixTokens — light scheme parity with current dark cyan theme', () {
    test('exposes named color tokens', () {
      final t = HelixTokens.light;
      expect(t.bg, isA<Color>());
      expect(t.surface, isA<Color>());
      expect(t.ink, isA<Color>());
      expect(t.accent, isA<Color>());
      expect(t.support, isA<Color>());
      expect(t.success, isA<Color>());
      expect(t.warning, isA<Color>());
      expect(t.danger, isA<Color>());
    });

    test('exposes radius tokens', () {
      expect(HelixTokens.radiusSm, 8);
      expect(HelixTokens.radiusControl, 10); // current cyan theme value
      expect(HelixTokens.radiusPanel, 8);    // current cyan theme value
      expect(HelixTokens.radiusLg, 22);
      expect(HelixTokens.radiusPill, 999);
    });

    test('exposes spacing scale', () {
      expect(HelixTokens.s4, 4);
      expect(HelixTokens.s8, 8);
      expect(HelixTokens.s12, 12);
      expect(HelixTokens.s16, 16);
      expect(HelixTokens.s20, 20);
      expect(HelixTokens.s24, 24);
      expect(HelixTokens.s32, 32);
      expect(HelixTokens.s48, 48);
    });

    test('exposes motion durations', () {
      expect(HelixTokens.durationFast, const Duration(milliseconds: 150));
      expect(HelixTokens.durationMed, const Duration(milliseconds: 250));
      expect(HelixTokens.durationSlow, const Duration(milliseconds: 400));
    });

    test('exposes elevation shadows', () {
      expect(HelixTokens.e1, isA<List<BoxShadow>>());
      expect(HelixTokens.e2, isA<List<BoxShadow>>());
      expect(HelixTokens.e3, isA<List<BoxShadow>>());
      expect(HelixTokens.e1.length, greaterThanOrEqualTo(1));
    });

    test('dark scheme is a separate ColorTokens instance', () {
      expect(HelixTokens.dark, isNot(same(HelixTokens.light)));
      expect(HelixTokens.dark.bg, isNot(equals(HelixTokens.light.bg)));
    });
  });
}
```

- [ ] **Step 2: Run the test — it must fail**

```bash
flutter test test/theme/helix_tokens_test.dart
```

Expected: FAIL — `Target of URI doesn't exist: 'package:flutter_helix/theme/helix_tokens.dart'`.

- [ ] **Step 3: Implement `helix_tokens.dart` with PHASE-1 (cyan-preserving) values**

Create `lib/theme/helix_tokens.dart`:

```dart
import 'package:flutter/material.dart';

/// Design tokens for the Helix theme system.
///
/// Phase 1 (this commit): values match the current cool-cyan dark theme so
/// no user-visible change occurs. Phase 2 flips these to Warm Linen.
class ColorTokens {
  const ColorTokens({
    required this.bg,
    required this.bgRaised,
    required this.surface,
    required this.surfaceSunk,
    required this.borderHairline,
    required this.borderStrong,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
    required this.accent,
    required this.accentDeep,
    required this.accentTint,
    required this.support,
    required this.gold,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color bg;
  final Color bgRaised;
  final Color surface;
  final Color surfaceSunk;
  final Color borderHairline;
  final Color borderStrong;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;
  final Color accent;
  final Color accentDeep;
  final Color accentTint;
  final Color support;
  final Color gold;
  final Color success;
  final Color warning;
  final Color danger;
}

class HelixTokens {
  HelixTokens._();

  /// Light token set. Phase 1: alias of the current dark theme so the visible
  /// surface is unchanged. Phase 2 will replace this with Warm Linen values.
  static const ColorTokens light = ColorTokens(
    bg: Color(0xFF090D12),
    bgRaised: Color(0xFF10161D),
    surface: Color(0xFF151B23),
    surfaceSunk: Color(0xFF0B1117),
    borderHairline: Color(0xFF2B3541),
    borderStrong: Color(0xFF3B4956),
    ink: Color(0xFFF1F4F7),
    inkSecondary: Color(0xFFB1BBC6),
    inkMuted: Color(0xFF7D8996),
    accent: Color(0xFF55C7E8),
    accentDeep: Color(0xFF1C7892),
    accentTint: Color(0x2255C7E8),
    support: Color(0xFF8B96C9),
    gold: Color(0xFFE7AE62),
    success: Color(0xFF8CD6A4),
    warning: Color(0xFFE7AE62),
    danger: Color(0xFFE56C6C),
  );

  /// Dark token set. Phase 1: same as light (single dark theme today).
  static const ColorTokens dark = light;

  // --- Radii ---
  static const double radiusSm = 8;
  static const double radiusControl = 10;
  static const double radiusPanel = 8;
  static const double radiusLg = 22;
  static const double radiusPill = 999;

  // --- Spacing scale ---
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;

  // --- Motion ---
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationMed = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 400);

  // Easing curves (Flutter built-ins, exposed for consistency at call sites).
  static const Curve easeEnter = Curves.easeOutQuint;
  static const Curve easeTransition = Curves.easeInOutCubic;

  // --- Elevation ---
  static const List<BoxShadow> e1 = [
    BoxShadow(
      color: Color(0x0A3C2814),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];
  static const List<BoxShadow> e2 = [
    BoxShadow(
      color: Color(0x0F3C2814),
      offset: Offset(0, 4),
      blurRadius: 12,
    ),
  ];
  static const List<BoxShadow> e3 = [
    BoxShadow(
      color: Color(0x1A3C2814),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];

  /// Resolve the token set for the current brightness.
  static ColorTokens of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }
}
```

- [ ] **Step 4: Run the test — it must pass**

```bash
flutter test test/theme/helix_tokens_test.dart
```

Expected: PASS, all 6 tests green.

- [ ] **Step 5: Run analyzer**

```bash
flutter analyze lib/theme/helix_tokens.dart test/theme/helix_tokens_test.dart
```

Expected: 0 errors, 0 warnings.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/helix_tokens.dart test/theme/helix_tokens_test.dart
git commit -m "feat(theme): add HelixTokens token system (cyan-preserving)

Introduces ColorTokens, spacing/radius/motion/elevation tokens. Values
mirror the current dark cyan theme so no visible change occurs. Phase 2
will flip these to Warm Linen.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.4: Create `helix_type.dart` with current font (SF Pro)

**Files:**
- Create: `lib/theme/helix_type.dart`
- Test: `test/theme/helix_type_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/theme/helix_type_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_type.dart';

void main() {
  group('HelixType — type scale', () {
    test('display style', () {
      final s = HelixType.display();
      expect(s.fontSize, 32);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.height, closeTo(1.15, 0.001));
    });

    test('title1 style', () {
      final s = HelixType.title1();
      expect(s.fontSize, 24);
      expect(s.fontWeight, FontWeight.w600);
      expect(s.height, closeTo(1.20, 0.001));
    });

    test('title2 style', () {
      expect(HelixType.title2().fontSize, 18);
      expect(HelixType.title2().fontWeight, FontWeight.w600);
    });

    test('title3 style', () {
      expect(HelixType.title3().fontSize, 15);
    });

    test('bodyLg style', () {
      expect(HelixType.bodyLg().fontSize, 16);
      expect(HelixType.bodyLg().height, closeTo(1.5, 0.001));
    });

    test('body style', () {
      expect(HelixType.body().fontSize, 14);
    });

    test('bodySm style', () {
      expect(HelixType.bodySm().fontSize, 13);
    });

    test('caption style', () {
      expect(HelixType.caption().fontSize, 12);
    });

    test('label style has tracking', () {
      final s = HelixType.label();
      expect(s.fontSize, 11);
      expect(s.letterSpacing, closeTo(0.6, 0.001));
    });

    test('mono style uses JetBrainsMono', () {
      expect(HelixType.mono().fontFamily, 'JetBrainsMono');
    });

    test('color override propagates', () {
      final s = HelixType.title1(color: const Color(0xFFAABBCC));
      expect(s.color, const Color(0xFFAABBCC));
    });
  });
}
```

- [ ] **Step 2: Run the test — it must fail**

```bash
flutter test test/theme/helix_type_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `helix_type.dart`**

Create `lib/theme/helix_type.dart`. Phase 1 keeps the old `SF Pro Display` family for non-mono styles to preserve current visuals; Phase 2 will swap to Fraunces/Inter.

```dart
import 'package:flutter/material.dart';

/// Typography scale for Helix.
///
/// Phase 1: serif/sans family is `SF Pro Display` (matches current theme).
/// Phase 2 swaps display/title to Fraunces and body to Inter.
class HelixType {
  HelixType._();

  // Phase 1 placeholders. Phase 2 changes _serifFamily to 'Fraunces' and
  // _sansFamily to 'Inter'.
  static const String _serifFamily = 'SF Pro Display';
  static const String _sansFamily = 'SF Pro Display';
  static const String _monoFamily = 'JetBrainsMono';

  static TextStyle display({Color? color}) => TextStyle(
        fontFamily: _serifFamily,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: color,
      );

  static TextStyle title1({Color? color}) => TextStyle(
        fontFamily: _serifFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.20,
        color: color,
      );

  static TextStyle title2({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.30,
        color: color,
      );

  static TextStyle title3({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: color,
      );

  static TextStyle bodyLg({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.50,
        color: color,
      );

  static TextStyle body({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.50,
        color: color,
      );

  static TextStyle bodySm({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: color,
      );

  static TextStyle caption({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.40,
        color: color,
      );

  static TextStyle label({Color? color}) => TextStyle(
        fontFamily: _sansFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.30,
        letterSpacing: 0.6,
        color: color,
      );

  static TextStyle mono({Color? color}) => TextStyle(
        fontFamily: _monoFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.50,
        color: color,
      );
}
```

- [ ] **Step 4: Run the test — it must pass**

```bash
flutter test test/theme/helix_type_test.dart
```

Expected: PASS, all 11 tests green.

- [ ] **Step 5: Run analyzer**

```bash
flutter analyze lib/theme/helix_type.dart test/theme/helix_type_test.dart
```

Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/helix_type.dart test/theme/helix_type_test.dart
git commit -m "feat(theme): add HelixType type scale (SF Pro placeholder)

Phase 1: scale exists, family is still SF Pro Display so visible text is
unchanged. Phase 2 swaps to Fraunces (display/title) + Inter (body).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.5: Create `helix_icons.dart` and `HelixIcon` widget

**Files:**
- Create: `lib/theme/helix_icons.dart`
- Test: `test/theme/helix_icons_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/theme/helix_icons_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:flutter_helix/theme/helix_icons.dart';

void main() {
  group('HelixIcons registry', () {
    test('every concept maps to a non-null PhosphorIconData', () {
      final entries = {
        'listen': HelixIcons.listen,
        'pause': HelixIcons.pause,
        'glasses': HelixIcons.glasses,
        'ai': HelixIcons.ai,
        'chat': HelixIcons.chat,
        'fact': HelixIcons.fact,
        'memory': HelixIcons.memory,
        'todo': HelixIcons.todo,
        'insight': HelixIcons.insight,
        'settings': HelixIcons.settings,
        'home': HelixIcons.home,
        'search': HelixIcons.search,
        'bookmark': HelixIcons.bookmark,
        'book': HelixIcons.book,
        'bluetooth': HelixIcons.bluetooth,
        'battery': HelixIcons.battery,
        'caret': HelixIcons.caret,
        'close': HelixIcons.close,
        'more': HelixIcons.more,
        'play': HelixIcons.play,
        'record': HelixIcons.record,
        'cost': HelixIcons.cost,
        'device': HelixIcons.device,
        'cloud': HelixIcons.cloud,
        'lightning': HelixIcons.lightning,
      };
      for (final entry in entries.entries) {
        expect(entry.value, isA<IconData>(), reason: entry.key);
      }
    });
  });

  group('HelixIcon widget', () {
    testWidgets('renders a PhosphorIcon with duotone weight by default',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelixIcon(HelixIcons.listen),
          ),
        ),
      );
      expect(find.byType(PhosphorIcon), findsOneWidget);
    });

    testWidgets('size override applies', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HelixIcon(HelixIcons.listen, size: 32),
          ),
        ),
      );
      final icon = tester.widget<PhosphorIcon>(find.byType(PhosphorIcon));
      expect(icon.size, 32);
    });
  });
}
```

- [ ] **Step 2: Run the test — it must fail**

```bash
flutter test test/theme/helix_icons_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `helix_icons.dart`**

Create `lib/theme/helix_icons.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'helix_tokens.dart';

/// Semantic icon registry — every screen pulls from here, never inlines
/// `Icon(Icons.xxx)`. Each entry resolves to a Phosphor IconData (regular
/// weight); HelixIcon swaps to duotone at render time.
class HelixIcons {
  HelixIcons._();

  static const IconData listen = PhosphorIconsRegular.microphone;
  static const IconData pause = PhosphorIconsRegular.pause;
  static const IconData glasses = PhosphorIconsRegular.eyeglasses;
  static const IconData ai = PhosphorIconsRegular.sparkle;
  static const IconData chat = PhosphorIconsRegular.chatCircleText;
  static const IconData fact = PhosphorIconsRegular.checkCircle;
  static const IconData memory = PhosphorIconsRegular.brain;
  static const IconData todo = PhosphorIconsRegular.checkSquare;
  static const IconData insight = PhosphorIconsRegular.chartLineUp;
  static const IconData settings = PhosphorIconsRegular.gearSix;
  static const IconData home = PhosphorIconsRegular.house;
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData bookmark = PhosphorIconsRegular.bookmarkSimple;
  static const IconData book = PhosphorIconsRegular.bookOpen;
  static const IconData bluetooth = PhosphorIconsRegular.bluetooth;
  static const IconData battery = PhosphorIconsRegular.batteryMedium;
  static const IconData caret = PhosphorIconsRegular.caretRight;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData more = PhosphorIconsRegular.dotsThree;
  static const IconData play = PhosphorIconsRegular.playCircle;
  static const IconData record = PhosphorIconsRegular.record;
  static const IconData cost = PhosphorIconsRegular.currencyDollar;
  static const IconData device = PhosphorIconsRegular.deviceMobile;
  static const IconData cloud = PhosphorIconsRegular.cloud;
  static const IconData lightning = PhosphorIconsRegular.lightning;
}

/// Theme-aware Phosphor icon.
///
/// Default weight is duotone (line + soft accent fill). Pass `weight:
/// PhosphorIconsRegular` (or any other weight constant) for line-only.
/// Color defaults to the current `ink` token; pass `color:` to override.
class HelixIcon extends StatelessWidget {
  const HelixIcon(
    this.icon, {
    super.key,
    this.size = 22,
    this.color,
    this.duotoneTint,
    this.useDuotone = true,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? duotoneTint;
  final bool useDuotone;

  @override
  Widget build(BuildContext context) {
    final tokens = HelixTokens.of(context);
    final inkColor = color ?? tokens.ink;
    if (useDuotone) {
      // Phosphor duotone icons are paired data — resolve from regular name.
      final duotone = _toDuotone(icon);
      return PhosphorIcon(
        duotone,
        size: size,
        color: inkColor,
        duotoneSecondaryColor: duotoneTint ?? tokens.accent,
        duotoneSecondaryOpacity: 0.35,
      );
    }
    return PhosphorIcon(icon, size: size, color: inkColor);
  }

  /// Map a regular Phosphor icon to its duotone counterpart by name lookup.
  /// Falls back to the regular icon if duotone is not available.
  IconData _toDuotone(IconData regular) {
    // PhosphorIcons exposes paired regular/duotone constants. The mapping is
    // stable: the duotone variant lives in PhosphorIconsDuotone with the same
    // member name. Because IconData is opaque, we keep an explicit table.
    return _duotoneMap[regular] ?? regular;
  }

  static const Map<IconData, IconData> _duotoneMap = {
    PhosphorIconsRegular.microphone: PhosphorIconsDuotone.microphone,
    PhosphorIconsRegular.pause: PhosphorIconsDuotone.pause,
    PhosphorIconsRegular.eyeglasses: PhosphorIconsDuotone.eyeglasses,
    PhosphorIconsRegular.sparkle: PhosphorIconsDuotone.sparkle,
    PhosphorIconsRegular.chatCircleText: PhosphorIconsDuotone.chatCircleText,
    PhosphorIconsRegular.checkCircle: PhosphorIconsDuotone.checkCircle,
    PhosphorIconsRegular.brain: PhosphorIconsDuotone.brain,
    PhosphorIconsRegular.checkSquare: PhosphorIconsDuotone.checkSquare,
    PhosphorIconsRegular.chartLineUp: PhosphorIconsDuotone.chartLineUp,
    PhosphorIconsRegular.gearSix: PhosphorIconsDuotone.gearSix,
    PhosphorIconsRegular.house: PhosphorIconsDuotone.house,
    PhosphorIconsRegular.magnifyingGlass: PhosphorIconsDuotone.magnifyingGlass,
    PhosphorIconsRegular.bookmarkSimple: PhosphorIconsDuotone.bookmarkSimple,
    PhosphorIconsRegular.bookOpen: PhosphorIconsDuotone.bookOpen,
    PhosphorIconsRegular.bluetooth: PhosphorIconsDuotone.bluetooth,
    PhosphorIconsRegular.batteryMedium: PhosphorIconsDuotone.batteryMedium,
    PhosphorIconsRegular.caretRight: PhosphorIconsDuotone.caretRight,
    PhosphorIconsRegular.x: PhosphorIconsDuotone.x,
    PhosphorIconsRegular.dotsThree: PhosphorIconsDuotone.dotsThree,
    PhosphorIconsRegular.playCircle: PhosphorIconsDuotone.playCircle,
    PhosphorIconsRegular.record: PhosphorIconsDuotone.record,
    PhosphorIconsRegular.currencyDollar: PhosphorIconsDuotone.currencyDollar,
    PhosphorIconsRegular.deviceMobile: PhosphorIconsDuotone.deviceMobile,
    PhosphorIconsRegular.cloud: PhosphorIconsDuotone.cloud,
    PhosphorIconsRegular.lightning: PhosphorIconsDuotone.lightning,
  };
}
```

> **Note for the implementing engineer:** verify the `phosphor_flutter` API in the version you installed. Class names `PhosphorIconsRegular` and `PhosphorIconsDuotone` are correct in v2.x. If the API differs (e.g., camelCase changes), adjust the lookups but keep the public surface (`HelixIcons.listen` etc.) identical.

- [ ] **Step 4: Run the test — it must pass**

```bash
flutter test test/theme/helix_icons_test.dart
```

Expected: PASS.

- [ ] **Step 5: Run analyzer**

```bash
flutter analyze lib/theme/helix_icons.dart test/theme/helix_icons_test.dart
```

Expected: 0 errors. If `PhosphorIcon` API differs, fix at this step.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/helix_icons.dart test/theme/helix_icons_test.dart
git commit -m "feat(theme): add HelixIcons registry + HelixIcon duotone widget

25 semantic icon names map to Phosphor duotone glyphs. Other screens will
migrate from Icon(Icons.xxx) to HelixIcon(HelixIcons.xxx) in Phase 3.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.6: Refactor `helix_theme.dart` to consume tokens

**Files:**
- Modify: `lib/theme/helix_theme.dart`

- [ ] **Step 1: Read the current file**

```bash
cat lib/theme/helix_theme.dart
```

(Confirm it matches the version captured in the spec — if a teammate has changed it since, reconcile before proceeding.)

- [ ] **Step 2: Replace inline color constants with token references**

Open `lib/theme/helix_theme.dart`. Replace the entire file body with:

```dart
import 'package:flutter/material.dart';

import 'helix_tokens.dart';

class HelixTheme {
  HelixTheme._();

  // --- Backwards-compat color aliases (call sites still reference these). ---
  // Phase 1: alias to the same cyan values via tokens. Phase 5 deletes these
  // and forces all call sites onto HelixTokens directly.
  static const Color background = Color(0xFF090D12);
  static const Color backgroundRaised = Color(0xFF10161D);
  static const Color surface = Color(0xFF151B23);
  static const Color surfaceRaised = Color(0xFF1B232D);
  static const Color surfaceInteractive = Color(0xFF222D38);
  static const Color borderSubtle = Color(0xFF2B3541);
  static const Color borderStrong = Color(0xFF3B4956);
  static const Color cyan = Color(0xFF55C7E8);
  static const Color cyanDeep = Color(0xFF1C7892);
  static const Color purple = Color(0xFF8B96C9);
  static const Color lime = Color(0xFF8CD6A4);
  static const Color amber = Color(0xFFE7AE62);
  static const Color error = Color(0xFFE56C6C);
  static const Color textPrimary = Color(0xFFF1F4F7);
  static const Color textSecondary = Color(0xFFB1BBC6);
  static const Color textMuted = Color(0xFF7D8996);

  static const Color statusListening = Color(0xFF55C7E8);
  static const Color statusThinking = Color(0xFFE7AE62);
  static const Color statusReady = Color(0xFF8CD6A4);
  static const Color statusOffline = Color(0xFF7D8996);

  // Radius aliases — pass through to tokens.
  static const double radiusPanel = HelixTokens.radiusPanel;
  static const double radiusControl = HelixTokens.radiusControl;
  static const double radiusPill = HelixTokens.radiusPill;

  static Color panelFill([double emphasis = 0.0]) {
    final strength = emphasis.clamp(0.0, 1.0);
    return Color.lerp(surface, surfaceRaised, strength)!
        .withValues(alpha: 0.96);
  }

  static Color panelBorder([double emphasis = 0.0]) {
    final strength = emphasis.clamp(0.0, 1.0);
    return Color.lerp(borderSubtle, borderStrong, strength)!;
  }

  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: ColorScheme.dark(
          primary: cyan,
          secondary: purple,
          surface: surface,
          onSurface: textPrimary,
          error: error,
        ),
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
              color: textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0),
          titleLarge: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2),
          titleMedium: TextStyle(
              color: textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2),
          bodyLarge: TextStyle(
              color: textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.45),
          bodyMedium: TextStyle(
              color: textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5),
          bodySmall: TextStyle(
              color: textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.45),
          labelLarge: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2),
          labelSmall: TextStyle(
              color: textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
              color: textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2),
        ),
        dividerTheme: DividerThemeData(
          color: borderSubtle.withValues(alpha: 0.9),
          space: 24,
          thickness: 1,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surfaceRaised.withValues(alpha: 0.94),
          indicatorColor: cyan.withValues(alpha: 0.14),
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.22),
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          height: 62,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? textPrimary : textMuted,
              letterSpacing: 0.2,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: cyan, size: 23);
            }
            return const IconThemeData(color: textMuted, size: 23);
          }),
        ),
        cardTheme: CardThemeData(
          color: panelFill(0.3),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPanel),
            side: const BorderSide(color: borderSubtle),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: surfaceRaised,
          contentTextStyle: const TextStyle(
              color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
            side: const BorderSide(color: borderStrong),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surfaceInteractive,
          hintStyle: const TextStyle(
              color: textMuted, fontSize: 14, fontWeight: FontWeight.w500),
          labelStyle: const TextStyle(
              color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusControl),
            borderSide: const BorderSide(color: borderSubtle),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusControl),
            borderSide: const BorderSide(color: borderSubtle),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusControl),
            borderSide: const BorderSide(color: cyan),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusControl),
            borderSide: const BorderSide(color: error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusControl),
            borderSide: const BorderSide(color: error),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      );

  /// Phase 1: lightTheme aliases darkTheme so the app shows no change. Phase 2
  /// rebuilds this from Warm Linen tokens.
  static ThemeData get lightTheme => darkTheme;
}
```

The behavior is unchanged. The only addition is the `import 'helix_tokens.dart';` and the `static const double radiusPanel = HelixTokens.radiusPanel;` aliases — which is fine because Phase 1 token values match the inlined ones.

- [ ] **Step 3: Run the gate**

```bash
bash scripts/run_gate.sh
```

Expected: PASS. Same UI, same tests.

- [ ] **Step 4: Manual smoke test on the simulator**

```bash
flutter run -d $HELIX_SIM
```

Compare against `tmp/screenshots/before/`. Visual diff should be zero. If anything looks different, the token migration introduced a regression — fix before committing.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/helix_theme.dart
git commit -m "refactor(theme): wire HelixTheme through HelixTokens (no visual change)

HelixTheme.radiusPanel/Control delegate to HelixTokens. lightTheme aliases
darkTheme — Phase 2 will fork them with Warm Linen values.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 1.7: Run full gate to lock in Phase 1

**Files:** none

- [ ] **Step 1: Run the validation gate**

```bash
bash scripts/run_gate.sh
```

Expected: PASS. This is the Phase 1 exit criterion per CLAUDE.md.

- [ ] **Step 2: Tag the Phase 1 milestone (optional but recommended)**

```bash
git tag phase-1-foundation
```

Phase 1 complete. No user-visible change. Foundation is in place.

---

## Phase 2 — Light theme switch (the visible jump)

Goal: Flip token values to Warm Linen, fork `lightTheme` from `darkTheme`, migrate all hardcoded `Color(0x...)` literals to tokens, and visually verify on simulator.

### Task 2.1: Update Warm Linen color tokens (light)

**Files:**
- Modify: `lib/theme/helix_tokens.dart`

- [ ] **Step 1: Replace the `light` ColorTokens body**

Open `lib/theme/helix_tokens.dart`. Find the `static const ColorTokens light = ColorTokens(...)` block (Phase 1 cyan values). Replace with:

```dart
  static const ColorTokens light = ColorTokens(
    bg: Color(0xFFF7F4F0),
    bgRaised: Color(0xFFFBF9F5),
    surface: Color(0xFFFFFFFF),
    surfaceSunk: Color(0xFFF1ECE3),
    borderHairline: Color(0xFFEBE3D7),
    borderStrong: Color(0xFFD9CDB9),
    ink: Color(0xFF2C2825),
    inkSecondary: Color(0xFF6F665C),
    inkMuted: Color(0xFFA09687),
    accent: Color(0xFFD89B7B),
    accentDeep: Color(0xFFB97A5A),
    accentTint: Color(0xFFF5E2D5),
    support: Color(0xFF88A89E),
    gold: Color(0xFFC7A35F),
    success: Color(0xFF6E9E78),
    warning: Color(0xFFC9A86A),
    danger: Color(0xFFC45A48),
  );
```

- [ ] **Step 2: Replace the `dark` ColorTokens body**

Below the `light` block, replace `static const ColorTokens dark = light;` with:

```dart
  static const ColorTokens dark = ColorTokens(
    bg: Color(0xFF1A1612),
    bgRaised: Color(0xFF221C16),
    surface: Color(0xFF2A231C),
    surfaceSunk: Color(0xFF16110D),
    borderHairline: Color(0xFF3A2F25),
    borderStrong: Color(0xFF4F3F31),
    ink: Color(0xFFF2EBDF),
    inkSecondary: Color(0xFFC2B6A3),
    inkMuted: Color(0xFF8A7F6E),
    accent: Color(0xFFE8B393),
    accentDeep: Color(0xFFC18A68),
    accentTint: Color(0xFF3A2A20),
    support: Color(0xFFA8C2B8),
    gold: Color(0xFFD9B976),
    success: Color(0xFF8DBE96),
    warning: Color(0xFFD9C284),
    danger: Color(0xFFE07A65),
  );
```

- [ ] **Step 3: Update token-aware radii to spec values**

Find the radius block. Update to spec:

```dart
  static const double radiusSm = 8;
  static const double radiusControl = 12;  // was 10
  static const double radiusPanel = 16;    // was 8
  static const double radiusLg = 22;
  static const double radiusPill = 999;
```

- [ ] **Step 4: Run unit tests — token tests should still pass**

```bash
flutter test test/theme/helix_tokens_test.dart
```

Expected: PASS (the test asserts radius == 8 for `radiusSm`, no longer constrains `radiusControl/Panel` to old values — but **update the test now if it does**).

If the test fails on `radiusControl == 10` or `radiusPanel == 8`, update the assertions in `test/theme/helix_tokens_test.dart` to the new values:

```dart
expect(HelixTokens.radiusControl, 12);
expect(HelixTokens.radiusPanel, 16);
```

Re-run; expect PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/theme/helix_tokens.dart test/theme/helix_tokens_test.dart
git commit -m "feat(theme): flip HelixTokens to Warm Linen palette

Light tokens become warm linen + terracotta + sage. Dark tokens become
warm-dark counterparts. Radius scale shifts to softer 12/16.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.2: Fork lightTheme from darkTheme in HelixTheme

**Files:**
- Modify: `lib/theme/helix_theme.dart`

- [ ] **Step 1: Replace HelixTheme entirely**

Open `lib/theme/helix_theme.dart`. Replace the file body with the new dual-mode implementation. The compatibility aliases (`HelixTheme.cyan` → `tokens.accent`, etc.) keep ~531 existing call sites compiling without per-call-site edits.

```dart
import 'package:flutter/material.dart';

import 'helix_tokens.dart';

class HelixTheme {
  HelixTheme._();

  // --- Backwards-compat aliases pointing to current (light) tokens. ---
  // These hardcode the LIGHT scheme — call sites that need dark-mode-aware
  // colors must migrate to `HelixTokens.of(context).<name>` directly. Phase 5
  // deletes these aliases entirely.
  static Color get background => HelixTokens.light.bg;
  static Color get backgroundRaised => HelixTokens.light.bgRaised;
  static Color get surface => HelixTokens.light.surface;
  static Color get surfaceRaised => HelixTokens.light.bgRaised;
  static Color get surfaceInteractive => HelixTokens.light.surfaceSunk;
  static Color get borderSubtle => HelixTokens.light.borderHairline;
  static Color get borderStrong => HelixTokens.light.borderStrong;
  static Color get cyan => HelixTokens.light.accent;
  static Color get cyanDeep => HelixTokens.light.accentDeep;
  static Color get purple => HelixTokens.light.support;
  static Color get lime => HelixTokens.light.success;
  static Color get amber => HelixTokens.light.gold;
  static Color get error => HelixTokens.light.danger;
  static Color get textPrimary => HelixTokens.light.ink;
  static Color get textSecondary => HelixTokens.light.inkSecondary;
  static Color get textMuted => HelixTokens.light.inkMuted;

  static Color get statusListening => HelixTokens.light.accent;
  static Color get statusThinking => HelixTokens.light.warning;
  static Color get statusReady => HelixTokens.light.success;
  static Color get statusOffline => HelixTokens.light.inkMuted;

  static double get radiusPanel => HelixTokens.radiusPanel;
  static double get radiusControl => HelixTokens.radiusControl;
  static double get radiusPill => HelixTokens.radiusPill;

  static Color panelFill([double emphasis = 0.0]) {
    final strength = emphasis.clamp(0.0, 1.0);
    return Color.lerp(
      HelixTokens.light.surface,
      HelixTokens.light.bgRaised,
      strength,
    )!;
  }

  static Color panelBorder([double emphasis = 0.0]) {
    final strength = emphasis.clamp(0.0, 1.0);
    return Color.lerp(
      HelixTokens.light.borderHairline,
      HelixTokens.light.borderStrong,
      strength,
    )!;
  }

  static ThemeData get lightTheme => _buildTheme(HelixTokens.light, Brightness.light);
  static ThemeData get darkTheme => _buildTheme(HelixTokens.dark, Brightness.dark);

  static ThemeData _buildTheme(ColorTokens t, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.bg,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: t.accent,
        onPrimary: isDark ? t.ink : Colors.white,
        secondary: t.support,
        onSecondary: isDark ? t.ink : Colors.white,
        surface: t.surface,
        onSurface: t.ink,
        surfaceContainerHighest: t.bgRaised,
        outline: t.borderStrong,
        outlineVariant: t.borderHairline,
        error: t.danger,
        onError: Colors.white,
      ),
      fontFamily: 'Inter',
      textTheme: TextTheme(
        headlineSmall: TextStyle(fontFamily: 'Fraunces', color: t.ink, fontSize: 28, fontWeight: FontWeight.w600, height: 1.18),
        titleLarge: TextStyle(fontFamily: 'Fraunces', color: t.ink, fontSize: 24, fontWeight: FontWeight.w600, height: 1.20),
        titleMedium: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.w600, height: 1.30),
        bodyLarge: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w500, height: 1.50),
        bodyMedium: TextStyle(color: t.inkSecondary, fontSize: 14, fontWeight: FontWeight.w500, height: 1.50),
        bodySmall: TextStyle(color: t.inkMuted, fontSize: 12, fontWeight: FontWeight.w500, height: 1.40),
        labelLarge: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.2),
        labelSmall: TextStyle(color: t.inkMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: 'Fraunces', color: t.ink, fontSize: 22, fontWeight: FontWeight.w600),
        iconTheme: IconThemeData(color: t.ink),
      ),
      dividerTheme: DividerThemeData(color: t.borderHairline, space: 24, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        indicatorColor: t.accentTint,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        height: 62,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? t.ink : t.inkMuted,
            letterSpacing: 0.2,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: t.accent, size: 23);
          }
          return IconThemeData(color: t.inkMuted, size: 23);
        }),
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HelixTokens.radiusPanel),
          side: BorderSide(color: t.borderHairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surface,
        contentTextStyle: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HelixTokens.radiusControl),
          side: BorderSide(color: t.borderStrong),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceSunk,
        hintStyle: TextStyle(color: t.inkMuted, fontSize: 14, fontWeight: FontWeight.w500),
        labelStyle: TextStyle(color: t.inkSecondary, fontSize: 13, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HelixTokens.radiusControl),
          borderSide: BorderSide(color: t.borderHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HelixTokens.radiusControl),
          borderSide: BorderSide(color: t.borderHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HelixTokens.radiusControl),
          borderSide: BorderSide(color: t.accent),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HelixTokens.radiusControl),
          borderSide: BorderSide(color: t.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HelixTokens.radiusControl),
          borderSide: BorderSide(color: t.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
```

- [ ] **Step 2: Update `lib/app.dart` to prefer `lightTheme`**

Open `lib/app.dart`. Find the `MaterialApp` (line ~18). Change the `theme:` line and add `darkTheme` + `themeMode`:

```dart
return MaterialApp(
  title: 'Helix',
  theme: HelixTheme.lightTheme,
  darkTheme: HelixTheme.darkTheme,
  themeMode: ThemeMode.system,
  builder: (context, child) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(
        textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.4),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  },
  home: const AppEntry(),
  debugShowCheckedModeBanner: false,
);
```

- [ ] **Step 3: Run analyzer**

```bash
flutter analyze
```

Expected: 0 errors. Compatibility aliases keep all 531 `HelixTheme.cyan/textPrimary/etc.` references green.

- [ ] **Step 4: Run tests**

```bash
flutter test test/
```

Expected: PASS. (Theme is not unit-tested directly; existing tests should remain green.)

- [ ] **Step 5: Visual smoke test**

```bash
flutter run -d $HELIX_SIM
```

Tap through Home, Glasses, Live, Ask AI, Insights, Settings, Onboarding. Capture "after" screenshots:

```bash
mkdir -p tmp/screenshots/after-phase2
xcrun simctl io $HELIX_SIM screenshot tmp/screenshots/after-phase2/home.png
# repeat per screen
```

Compare against `tmp/screenshots/before/`. The shift from dark cyan → warm linen should be obvious and intentional. Check for:
- App launches without crashing.
- Text is legible on every primary surface.
- No black-on-black or terracotta-on-terracotta unreadable combinations.
- Status indicators (listening, thinking, ready) are recolored but visible.
- App bar and bottom nav both use the new palette.

If a screen still shows dark cyan elements, those are hardcoded `Color(0xFF...)` literals — they get fixed in Tasks 2.3 and 2.4.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/helix_theme.dart lib/app.dart
git commit -m "feat(theme): flip Helix to Warm Linen — light primary, dark secondary

HelixTheme now builds light + dark variants from HelixTokens. Backwards-
compat color aliases (HelixTheme.cyan etc.) point at the new tokens, so
all 531 call sites keep compiling. MaterialApp adopts both themes with
ThemeMode.system. Dynamic Type clamped to 1.4x.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.3: Migrate `lib/app.dart` hardcoded colors

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Replace the bootstrap loading screen colors**

Open `lib/app.dart`. Find lines 58-63:

```dart
return const Scaffold(
  backgroundColor: Color(0xFF0A0E21),
  body: Center(
    child: CircularProgressIndicator(color: Color(0xFF00D4FF)),
  ),
);
```

Replace with:

```dart
return Scaffold(
  backgroundColor: HelixTokens.light.bg,
  body: Center(
    child: CircularProgressIndicator(color: HelixTokens.light.accent),
  ),
);
```

Add the import at the top of the file if not already present:

```dart
import 'theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace the bottom-nav border**

Find line ~141:

```dart
border: Border(
  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
),
```

Replace with:

```dart
border: Border(
  top: BorderSide(color: HelixTokens.light.borderHairline),
),
```

- [ ] **Step 3: Run analyzer + tests**

```bash
flutter analyze lib/app.dart && flutter test test/
```

Expected: 0 errors, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/app.dart
git commit -m "refactor(theme): migrate app.dart hardcoded colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.4: Migrate `settings_screen.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/settings_screen.dart`

This is the largest single migration target — 16 hardcoded literals.

- [ ] **Step 1: Add the import**

At the top of `lib/screens/settings_screen.dart`, ensure this import exists:

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace the 6 accent palette literals (lines 214, 224, 234, 244, 254, 264)**

The pattern at each line is `accent: Color(0xFF...)`. Apply the spec remap. Use Edit tool, one line at a time, anchoring on the unique surrounding context.

| Line | Old | New |
|------|-----|-----|
| 214 | `accent: Color(0xFF7DD3FC)` | `accent: HelixTokens.light.accent` |
| 224 | `accent: Color(0xFFD59B5B)` | `accent: HelixTokens.light.gold` |
| 234 | `accent: Color(0xFF4DB8FF)` | `accent: HelixTokens.light.support` |
| 244 | `accent: Color(0xFF57C785)` | `accent: HelixTokens.light.success` |
| 254 | `accent: Color(0xFF7C83FF)` | `accent: HelixTokens.light.accentDeep` |
| 264 | `accent: Color(0xFFFF8C42)` | `accent: HelixTokens.light.warning` |

Note: drop `const` when migrating to `HelixTokens` (since the token getters are not const-evaluable from Color literals at compile time in this layout).

- [ ] **Step 3: Replace the 6 dropdown background literals (lines 491, 519, 549, 590, 668, 2263)**

All read `dropdownColor: const Color(0xFF1A1F35)`. Replace each with:

```dart
dropdownColor: HelixTokens.light.surface,
```

(Drop `const`.)

- [ ] **Step 4: Replace the 3 selection-state literals (lines 1545, 1550, 1558)**

Pattern around line 1545:

```dart
? const Color(0xFF6E86FF).withValues(alpha: 0.15)
```

Replace `const Color(0xFF6E86FF)` with `HelixTokens.light.accent` at lines 1545, 1550, 1558. Final form, e.g.:

```dart
? HelixTokens.light.accent.withValues(alpha: 0.15)
```

- [ ] **Step 5: Replace the dev tools literals (lines 2490, 2562)**

Line 2490 (terminal text):

```dart
color: Color(0xFF00FF88),
```

→

```dart
color: HelixTokens.light.success,
```

Line 2562 (debug panel background):

```dart
backgroundColor: const Color(0xFF1A1F35),
```

→

```dart
backgroundColor: HelixTokens.light.surface,
```

- [ ] **Step 6: Verify no remaining `Color(0xFF` in settings_screen.dart**

```bash
grep -n "Color(0x" lib/screens/settings_screen.dart
```

Expected: empty output. If any literals remain, migrate using the closest matching token from the remap table.

- [ ] **Step 7: Run analyzer + tests**

```bash
flutter analyze lib/screens/settings_screen.dart && flutter test test/
```

Expected: 0 errors, all tests pass.

- [ ] **Step 8: Visual check on simulator**

```bash
flutter run -d $HELIX_SIM
```

Open Settings tab. Each section header (Recording, Glasses, AI, etc.) should show its new accent color from the remapped palette. Dropdowns should open with white surfaces, not navy. Selected items should highlight terracotta.

- [ ] **Step 9: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "refactor(theme): migrate settings_screen.dart hardcoded colors to tokens

16 inline Color(0xFF...) literals remapped to Warm Linen tokens via the
spec remap table. Dropdown surfaces flip from navy to white.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.5: Migrate `even_features_screen.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/even_features_screen.dart`

- [ ] **Step 1: Add import**

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace 3 literals**

| Line | Old | New |
|------|-----|-----|
| 53 | `accent: const Color(0xFFFFA726)` | `accent: HelixTokens.light.warning` |
| 70 | `accent: const Color(0xFF7CFFB2)` | `accent: HelixTokens.light.success` |
| 102 | `const Color(0xFF7CFFB2).withValues(alpha: 0.75)` | `HelixTokens.light.success.withValues(alpha: 0.75)` |

- [ ] **Step 3: Verify no remaining literals**

```bash
grep -n "Color(0x" lib/screens/even_features_screen.dart
```

Expected: empty.

- [ ] **Step 4: Analyzer + tests**

```bash
flutter analyze lib/screens/even_features_screen.dart && flutter test test/
```

Expected: 0 errors, all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/even_features_screen.dart
git commit -m "refactor(theme): migrate even_features_screen.dart colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.6: Migrate `detail_analysis_screen.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/detail_analysis_screen.dart`

5 literals; all are status colors used by score-grading branches.

- [ ] **Step 1: Add import**

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace literals**

| Line | Old | New |
|------|-----|-----|
| 228 | `const Color(0xFFFFB547)` | `HelixTokens.light.warning` |
| 229 | `const Color(0xFFFF6B6B)` | `HelixTokens.light.danger` |
| 314 | `const Color(0xFFFFB547).withValues(alpha: 0.28)` | `HelixTokens.light.warning.withValues(alpha: 0.28)` |
| 1029 | `const Color(0xFFFFB547)` | `HelixTokens.light.warning` |
| 1031 | `const Color(0xFFFF6B6B)` | `HelixTokens.light.danger` |

- [ ] **Step 3: Verify and commit**

```bash
grep -n "Color(0x" lib/screens/detail_analysis_screen.dart  # expect empty
flutter analyze lib/screens/detail_analysis_screen.dart && flutter test test/
git add lib/screens/detail_analysis_screen.dart
git commit -m "refactor(theme): migrate detail_analysis_screen.dart colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.7: Migrate `conversation_history_screen.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/conversation_history_screen.dart`

11 literals.

- [ ] **Step 1: Add import**

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace literals**

| Line | Old | New |
|------|-----|-----|
| 325 | `const Color(0xFF00FF88)` | `HelixTokens.light.success` |
| 331 | `const Color(0xFF00FF88)` | `HelixTokens.light.success` |
| 520 | `'Favorites' => const Color(0xFFFFC857)` | `'Favorites' => HelixTokens.light.gold` |
| 521 | `'Action Items' => const Color(0xFF7CFFB2)` | `'Action Items' => HelixTokens.light.success` |
| 522 | `'Fact-check Flags' => const Color(0xFFFFA726)` | `'Fact-check Flags' => HelixTokens.light.warning` |
| 791 | `const Color(0xFFFFC857)` | `HelixTokens.light.gold` |
| 884 | `accent: const Color(0xFF7CFFB2)` | `accent: HelixTokens.light.success` |
| 890 | `accent: const Color(0xFFFFA726)` | `accent: HelixTokens.light.warning` |
| 953 | `accent: const Color(0xFF7CFFB2)` | `accent: HelixTokens.light.success` |
| 962 | `accent: const Color(0xFFFFA726)` | `accent: HelixTokens.light.warning` |
| 1090 | `backgroundColor: const Color(0xFF1A1A24)` | `backgroundColor: HelixTokens.light.surface` |

- [ ] **Step 3: Verify**

```bash
grep -n "Color(0x" lib/screens/conversation_history_screen.dart
```

Expected: empty.

- [ ] **Step 4: Analyzer + tests + commit**

```bash
flutter analyze lib/screens/conversation_history_screen.dart && flutter test test/
git add lib/screens/conversation_history_screen.dart
git commit -m "refactor(theme): migrate conversation_history_screen.dart colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.8: Migrate `home_screen.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/home_screen.dart`

6 literals (warning/danger pairs at lines 3025, 3027, 3787, 3789, 3816, 3818).

- [ ] **Step 1: Add import**

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace each `Color(0xFFFFB547)` with `HelixTokens.light.warning`**

```bash
# preview hits before editing
grep -n "Color(0xFFFFB547)\|Color(0xFFFF6B6B)" lib/screens/home_screen.dart
```

Expected output: 6 lines.

Use Edit (or `sed -i ''` if you've reviewed the diff):

For each of the 6 lines, replace `const Color(0xFFFFB547)` with `HelixTokens.light.warning` and `const Color(0xFFFF6B6B)` with `HelixTokens.light.danger`. Note `const` is stripped.

- [ ] **Step 3: Verify**

```bash
grep -n "Color(0x" lib/screens/home_screen.dart
```

Expected: empty.

- [ ] **Step 4: Analyzer + tests + commit**

```bash
flutter analyze lib/screens/home_screen.dart && flutter test test/
git add lib/screens/home_screen.dart
git commit -m "refactor(theme): migrate home_screen.dart status colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.9: Migrate `g1_test_screen.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/g1_test_screen.dart`

4 literals.

- [ ] **Step 1: Add import**

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace literals**

| Line | Old | New |
|------|-----|-----|
| 749 | `const Color(0xFF111A31)` | `HelixTokens.light.surfaceSunk` |
| 779 | `HandoffStatus.delivered => const Color(0xFF7CFFB2)` | `HandoffStatus.delivered => HelixTokens.light.success` |
| 931 | `_UtilityChip(label: 'Notifications', color: Color(0xFFFFA726))` | `_UtilityChip(label: 'Notifications', color: HelixTokens.light.warning)` |
| 932 | `_UtilityChip(label: 'BMP Canvas', color: Color(0xFF7CFFB2))` | `_UtilityChip(label: 'BMP Canvas', color: HelixTokens.light.success)` |

> If `_UtilityChip` constructor is `const`, drop `const` at the call sites.

- [ ] **Step 3: Verify, analyze, test, commit**

```bash
grep -n "Color(0x" lib/screens/g1_test_screen.dart  # expect empty
flutter analyze lib/screens/g1_test_screen.dart && flutter test test/
git add lib/screens/g1_test_screen.dart
git commit -m "refactor(theme): migrate g1_test_screen.dart colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.10: Migrate `even_ai_history_screen.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/even_ai_history_screen.dart`

2 literals (both `Color(0xFFFEF991)` — pale yellow).

- [ ] **Step 1: Add import**

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace literals**

| Line | Old | New |
|------|-----|-----|
| 96 | `const Color(0xFFFEF991).withValues(alpha: 0.2)` | `HelixTokens.light.gold.withValues(alpha: 0.2)` |
| 115 | `const Color(0xFFFEF991).withValues(alpha: 0.2)` | `HelixTokens.light.gold.withValues(alpha: 0.2)` |

- [ ] **Step 3: Verify, analyze, test, commit**

```bash
grep -n "Color(0x" lib/screens/even_ai_history_screen.dart  # expect empty
flutter analyze lib/screens/even_ai_history_screen.dart && flutter test test/
git add lib/screens/even_ai_history_screen.dart
git commit -m "refactor(theme): migrate even_ai_history_screen.dart colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.11: Migrate `notification_page.dart` and `text_page.dart` hardcoded colors

**Files:**
- Modify: `lib/screens/features/notification/notification_page.dart`
- Modify: `lib/screens/features/text_page.dart`

- [ ] **Step 1: Add import to each file**

```dart
import '../../../theme/helix_tokens.dart';   // notification_page.dart
import '../../theme/helix_tokens.dart';       // text_page.dart
```

(Verify the relative depth based on actual paths.)

- [ ] **Step 2: Replace literals in `notification_page.dart`**

| Line | Old | New |
|------|-----|-----|
| 34 | `_isConnected ? const Color(0xFFFFA726) : Colors.orangeAccent` | `_isConnected ? HelixTokens.light.warning : HelixTokens.light.warning.withValues(alpha: 0.7)` |
| 313 | `? const Color(0xFFFFA726)` | `? HelixTokens.light.warning` |
| 473 | `fillColor: const Color(0xFF111A31)` | `fillColor: HelixTokens.light.surfaceSunk` |

- [ ] **Step 3: Replace literals in `text_page.dart`**

| Line | Old | New |
|------|-----|-----|
| 170 | `color: const Color(0xFF111A31)` | `color: HelixTokens.light.surfaceSunk` |
| 297 | `HandoffStatus.delivered => const Color(0xFF7CFFB2)` | `HandoffStatus.delivered => HelixTokens.light.success` |

- [ ] **Step 4: Verify**

```bash
grep -n "Color(0x" lib/screens/features/notification/notification_page.dart lib/screens/features/text_page.dart
```

Expected: empty.

- [ ] **Step 5: Analyzer, tests, commit**

```bash
flutter analyze lib/screens/features/notification/notification_page.dart lib/screens/features/text_page.dart && flutter test test/
git add lib/screens/features/notification/notification_page.dart lib/screens/features/text_page.dart
git commit -m "refactor(theme): migrate features/notification + text_page colors

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.12: Migrate `lib/widgets/` hardcoded colors

**Files:**
- Modify: `lib/widgets/session_cost_badge.dart`
- Modify: `lib/widgets/home_assistant_modules.dart`

- [ ] **Step 1: Add imports**

```dart
import '../theme/helix_tokens.dart';
```

- [ ] **Step 2: Replace `session_cost_badge.dart` line 39**

```dart
backgroundColor: const Color(0xFF1A1A24),
```

→

```dart
backgroundColor: HelixTokens.light.surface,
```

- [ ] **Step 3: Replace `home_assistant_modules.dart` literals**

| Line | Old | New |
|------|-----|-----|
| 614 | `color: const Color(0xFFFFB74D)` | `color: HelixTokens.light.warning` |
| 619 | `color: const Color(0xFF7CFFB2)` | `color: HelixTokens.light.success` |
| 786 | `color: const Color(0xFF7CFFB2)` | `color: HelixTokens.light.success` |
| 797 | `color: const Color(0xFFFFB74D)` | `color: HelixTokens.light.warning` |
| 945 | `color: const Color(0xFFFFB74D)` | `color: HelixTokens.light.warning` |

- [ ] **Step 4: Verify**

```bash
grep -n "Color(0x" lib/widgets/session_cost_badge.dart lib/widgets/home_assistant_modules.dart
```

Expected: empty.

- [ ] **Step 5: Analyzer, tests, commit**

```bash
flutter analyze lib/widgets/session_cost_badge.dart lib/widgets/home_assistant_modules.dart && flutter test test/
git add lib/widgets/session_cost_badge.dart lib/widgets/home_assistant_modules.dart
git commit -m "refactor(theme): migrate widget hardcoded colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2.13: Sweep for any remaining hardcoded `Color(0xFF...)` outside HUD bitmap

**Files:** any remaining

- [ ] **Step 1: Run the global scan**

```bash
grep -rn "Color(0xFF\|Color(0x" lib/ \
  | grep -v "lib/services/bitmap_hud/" \
  | grep -v "lib/theme/helix_tokens.dart" \
  | grep -v "lib/theme/helix_theme.dart"
```

Expected: empty output. The HUD bitmap renderer is the only legitimate place left for `Color(0xFFFFFFFF)` / `Color(0xFF000000)` literals (hardware B&W constraint).

- [ ] **Step 2: If anything remains, migrate it**

For each remaining literal, choose the closest matching token:
- Pure white → `Colors.white` (kept) for HUD-adjacent code, or `HelixTokens.light.surface` for UI surfaces.
- Pure black → keep only in HUD code; migrate UI `Color(0xFF000000)` to `HelixTokens.light.ink`.
- Yellows/golds → `gold` or `warning`.
- Reds/coral → `danger`.
- Greens → `success`.
- Blues/teals → `accent` (terracotta) or `support` (sage). For "process info" colors, prefer `support`.

- [ ] **Step 3: Re-run the scan to confirm clean**

Repeat the grep from Step 1. Must be empty.

- [ ] **Step 4: Commit any sweep edits**

```bash
git add lib/
git commit -m "refactor(theme): sweep remaining hardcoded colors to tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

If nothing changed, skip the commit.

---

### Task 2.14: Phase 2 gate

**Files:** none

- [ ] **Step 1: Run the validation gate**

```bash
bash scripts/run_gate.sh
```

Expected: PASS.

- [ ] **Step 2: Visual smoke test**

```bash
flutter run -d $HELIX_SIM
```

Tap through every screen listed in Task 0.1 Step 3. Capture screenshots:

```bash
mkdir -p tmp/screenshots/after-phase2-final
xcrun simctl io $HELIX_SIM screenshot tmp/screenshots/after-phase2-final/home.png
# repeat per screen
```

The whole app should now read as Warm Linen — terracotta accents, sage highlights, cream backgrounds, white surfaces, warm dark ink text. No remaining cyan or navy artifacts. If you see any, find them with `grep -rn "Color(0x" lib/` and migrate.

- [ ] **Step 3: Tag**

```bash
git tag phase-2-warm-linen
```

Phase 2 complete. The app is now visually Warm Linen.

---

## Phase 3 — Components & icons

Goal: Build the new widget primitives, migrate icons + typography call sites mechanically, and align with the in-flight hero-screens spec.

### Task 3.0: Re-read the hero-screens overhaul spec

**Files:** none

- [ ] **Step 1: Read the existing in-flight design**

```bash
cat docs/superpowers/specs/2026-04-25-hero-screens-overhaul-design.md
cat docs/superpowers/plans/2026-04-26-hero-screens-overhaul.md 2>/dev/null
```

- [ ] **Step 2: Identify any hero screens that the hero overhaul plan also touches** (likely: `home_screen`, `recording_screen`, `onboarding_screen`)

If the hero plan is in-progress and overlapping screens are about to be regenerated, skip those screens in this phase's mechanical icon/type migration — let the hero plan land first, then circle back. Document any deferred work in the commit message of the next task.

- [ ] **Step 3: No code change** — this task is alignment only.

---

### Task 3.1: Build `LinenCard`

**Files:**
- Create: `lib/widgets/linen_card.dart`
- Test: `test/widgets/linen_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/linen_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_theme.dart';
import 'package:flutter_helix/theme/helix_tokens.dart';
import 'package:flutter_helix/widgets/linen_card.dart';

void main() {
  testWidgets('LinenCard renders child with surface background and shadow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HelixTheme.lightTheme,
        home: const Scaffold(
          body: LinenCard(child: Text('hello')),
        ),
      ),
    );
    expect(find.text('hello'), findsOneWidget);
    final container = tester
        .widget<Container>(find.descendant(
          of: find.byType(LinenCard),
          matching: find.byType(Container),
        ))
        .decoration as BoxDecoration;
    expect(container.color, HelixTokens.light.surface);
    expect(container.borderRadius,
        BorderRadius.circular(HelixTokens.radiusPanel));
    expect(container.boxShadow, isNotNull);
    expect(container.boxShadow!.length, greaterThanOrEqualTo(1));
  });

  testWidgets('LinenCard with highlighted: true uses accentTint background',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HelixTheme.lightTheme,
        home: const Scaffold(
          body: LinenCard(highlighted: true, child: Text('hi')),
        ),
      ),
    );
    final container = tester
        .widget<Container>(find.descendant(
          of: find.byType(LinenCard),
          matching: find.byType(Container),
        ))
        .decoration as BoxDecoration;
    expect(container.color, HelixTokens.light.accentTint);
  });
}
```

- [ ] **Step 2: Run the test — must fail**

```bash
flutter test test/widgets/linen_card_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `linen_card.dart`**

Create `lib/widgets/linen_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/helix_tokens.dart';

/// Default surface for content blocks. Replaces glassmorphism with a clean
/// linen-and-paper feel.
class LinenCard extends StatelessWidget {
  const LinenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final double? borderRadius;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final t = HelixTokens.of(context);
    final radius = borderRadius ?? HelixTokens.radiusPanel;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: highlighted ? t.accentTint : t.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: t.borderHairline),
        boxShadow: HelixTokens.e1,
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run test — must pass**

```bash
flutter test test/widgets/linen_card_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/linen_card.dart test/widgets/linen_card_test.dart
git commit -m "feat(widgets): add LinenCard — replaces GlassCard

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.2: Build `WarmButton` (3 variants)

**Files:**
- Create: `lib/widgets/warm_button.dart`
- Test: `test/widgets/warm_button_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/widgets/warm_button_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_theme.dart';
import 'package:flutter_helix/widgets/warm_button.dart';

void main() {
  testWidgets('primary WarmButton fires onPressed', (tester) async {
    var fired = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: HelixTheme.lightTheme,
        home: Scaffold(
          body: WarmButton.primary(
            label: 'Tap',
            onPressed: () => fired = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tap'));
    expect(fired, isTrue);
  });

  testWidgets('isLoading replaces label with progress indicator',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HelixTheme.lightTheme,
        home: Scaffold(
          body: WarmButton.primary(
            label: 'Save',
            onPressed: () {},
            isLoading: true,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('secondary variant has ink border', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HelixTheme.lightTheme,
        home: Scaffold(
          body: WarmButton.secondary(label: 'Cancel', onPressed: () {}),
        ),
      ),
    );
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('ghost variant has no fill', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HelixTheme.lightTheme,
        home: Scaffold(
          body: WarmButton.ghost(label: 'Skip', onPressed: () {}),
        ),
      ),
    );
    expect(find.text('Skip'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test — must fail**

```bash
flutter test test/widgets/warm_button_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `warm_button.dart`**

Create `lib/widgets/warm_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/helix_tokens.dart';

enum WarmButtonVariant { primary, secondary, ghost }

class WarmButton extends StatefulWidget {
  const WarmButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = WarmButtonVariant.primary,
    this.isLoading = false,
  });

  factory WarmButton.primary({
    Key? key,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
  }) =>
      WarmButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
      );

  factory WarmButton.secondary({
    Key? key,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
  }) =>
      WarmButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
        variant: WarmButtonVariant.secondary,
      );

  factory WarmButton.ghost({
    Key? key,
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    bool isLoading = false,
  }) =>
      WarmButton(
        key: key,
        label: label,
        onPressed: onPressed,
        icon: icon,
        isLoading: isLoading,
        variant: WarmButtonVariant.ghost,
      );

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final WarmButtonVariant variant;
  final bool isLoading;

  @override
  State<WarmButton> createState() => _WarmButtonState();
}

class _WarmButtonState extends State<WarmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HelixTokens.durationMed,
    lowerBound: 0.96,
    upperBound: 1.0,
    value: 1.0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(_) => _controller.animateTo(0.96, curve: Curves.easeOut);
  void _up(_) => _controller.animateTo(1.0, curve: HelixTokens.easeEnter);

  @override
  Widget build(BuildContext context) {
    final t = HelixTokens.of(context);
    final radius = HelixTokens.radiusControl;
    final disabled = widget.isLoading;

    final (bg, fg, border) = switch (widget.variant) {
      WarmButtonVariant.primary => (t.accent, Colors.white, null),
      WarmButtonVariant.secondary =>
        (t.surface, t.ink, Border.all(color: t.borderStrong)),
      WarmButtonVariant.ghost => (Colors.transparent, t.ink, null),
    };

    return ScaleTransition(
      scale: _controller,
      child: GestureDetector(
        onTapDown: disabled ? null : _down,
        onTapUp: disabled ? null : _up,
        onTapCancel: disabled ? null : () => _up(null),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(radius),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(radius),
                border: border,
              ),
              child: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: fg, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests — must pass**

```bash
flutter test test/widgets/warm_button_test.dart
```

Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/warm_button.dart test/widgets/warm_button_test.dart
git commit -m "feat(widgets): add WarmButton (primary/secondary/ghost)

Replaces GlowButton. Adds 250ms scale-on-press tactility.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.3: Build `IconBadge`

**Files:**
- Create: `lib/widgets/icon_badge.dart`
- Test: `test/widgets/icon_badge_test.dart`

- [ ] **Step 1: Write failing test**

Create `test/widgets/icon_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_icons.dart';
import 'package:flutter_helix/theme/helix_theme.dart';
import 'package:flutter_helix/theme/helix_tokens.dart';
import 'package:flutter_helix/widgets/icon_badge.dart';

void main() {
  testWidgets('IconBadge renders a HelixIcon inside an accentTint circle',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HelixTheme.lightTheme,
        home: const Scaffold(
          body: IconBadge(icon: HelixIcons.chat),
        ),
      ),
    );
    expect(find.byType(HelixIcon), findsOneWidget);
    final container = tester
        .widget<Container>(find.descendant(
          of: find.byType(IconBadge),
          matching: find.byType(Container),
        ))
        .decoration as BoxDecoration;
    expect(container.color, HelixTokens.light.accentTint);
    expect(container.shape, BoxShape.circle);
  });
}
```

- [ ] **Step 2: Run — must fail**

```bash
flutter test test/widgets/icon_badge_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `icon_badge.dart`**

Create `lib/widgets/icon_badge.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/helix_icons.dart';
import '../theme/helix_tokens.dart';

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 48,
    this.iconSize = 24,
    this.tint,
    this.iconColor,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? tint;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = HelixTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint ?? t.accentTint,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: HelixIcon(icon, size: iconSize, color: iconColor),
    );
  }
}
```

- [ ] **Step 4: Test passes**

```bash
flutter test test/widgets/icon_badge_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/icon_badge.dart test/widgets/icon_badge_test.dart
git commit -m "feat(widgets): add IconBadge — duotone icon in tinted circle

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.4: Add deprecation shims for `GlassCard` and `GlowButton`

**Files:**
- Modify: `lib/widgets/glass_card.dart`
- Modify: `lib/widgets/glow_button.dart`

- [ ] **Step 1: Replace `glass_card.dart` with a deprecated re-export**

Open `lib/widgets/glass_card.dart`. Replace the entire file with:

```dart
import 'package:flutter/material.dart';

import 'linen_card.dart';

/// Deprecated. Use [LinenCard] directly. Removed in Phase 5.
@Deprecated('Use LinenCard instead — will be removed in Phase 5.')
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    // ignored — kept for API compatibility
    this.borderColor,
    this.opacity = 0.15,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? borderColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return LinenCard(
      padding: padding ?? const EdgeInsets.all(16),
      borderRadius: borderRadius,
      child: child,
    );
  }
}
```

- [ ] **Step 2: Replace `glow_button.dart` with a deprecated re-export**

Open `lib/widgets/glow_button.dart`. Replace with:

```dart
import 'package:flutter/material.dart';

import 'warm_button.dart';

/// Deprecated. Use [WarmButton] directly. Removed in Phase 5.
@Deprecated('Use WarmButton.primary instead — will be removed in Phase 5.')
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color, // ignored — color is now token-driven
    this.isLoading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return WarmButton.primary(
      label: label,
      onPressed: onPressed,
      icon: icon,
      isLoading: isLoading,
    );
  }
}
```

- [ ] **Step 3: Analyze + test (deprecations are warnings, not errors)**

```bash
flutter analyze lib/widgets/
flutter test test/
```

Expected: 0 errors. Existing call sites still compile (with deprecation warnings) so no screen file needs to change in this task.

- [ ] **Step 4: Commit**

```bash
git add lib/widgets/glass_card.dart lib/widgets/glow_button.dart
git commit -m "refactor(widgets): replace GlassCard/GlowButton with deprecation shims

Old call sites keep compiling and route to LinenCard/WarmButton. Phase 5
deletes the shims after all consumers migrate.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.5: Migrate `Icon(Icons.xxx)` call sites to `HelixIcon(HelixIcons.xxx)`

**Files:** screens and widgets that call `Icon(Icons.xxx)` (~17 files)

Strategy: do this per-file in small commits. Track progress with a checkbox per file.

- [ ] **Step 1: List remaining call sites**

```bash
grep -rn "Icon(Icons\." lib/ | sort | uniq -c | sort -rn | head -30
```

Save the file list mentally — these are the files to migrate. Skip `lib/services/bitmap_hud/` (HUD is hardware-constrained). Skip `lib/app.dart` for now (Task 3.6 covers nav specifically).

- [ ] **Step 2: For each file, perform the migration**

The pattern, file by file:

**a.** Add the imports at the top of the file:

```dart
import '../theme/helix_icons.dart';   // adjust relative depth
```

**b.** For each `Icon(Icons.X, size: S, color: C)` call, replace with the matching `HelixIcons.X` mapping:

| Material `Icons.xxx` | Maps to | `HelixIcon` call |
|----------------------|---------|------------------|
| `mic`, `mic_outlined` | `listen` | `HelixIcon(HelixIcons.listen, size: ...)` |
| `pause`, `pause_outlined` | `pause` | `HelixIcon(HelixIcons.pause, ...)` |
| `bluetooth_*` | `bluetooth` | `HelixIcon(HelixIcons.bluetooth, ...)` |
| `auto_awesome`, `auto_awesome_outlined` | `ai` | `HelixIcon(HelixIcons.ai, ...)` |
| `chat_bubble*`, `chat*` | `chat` | `HelixIcon(HelixIcons.chat, ...)` |
| `check_circle*` | `fact` | `HelixIcon(HelixIcons.fact, ...)` |
| `psychology`, `memory` | `memory` | `HelixIcon(HelixIcons.memory, ...)` |
| `check_box*`, `task*` | `todo` | `HelixIcon(HelixIcons.todo, ...)` |
| `lightbulb*`, `insights` | `insight` | `HelixIcon(HelixIcons.insight, ...)` |
| `settings*`, `tune` | `settings` | `HelixIcon(HelixIcons.settings, ...)` |
| `home*` | `home` | `HelixIcon(HelixIcons.home, ...)` |
| `search*` | `search` | `HelixIcon(HelixIcons.search, ...)` |
| `bookmark*` | `bookmark` | `HelixIcon(HelixIcons.bookmark, ...)` |
| `book*`, `menu_book*` | `book` | `HelixIcon(HelixIcons.book, ...)` |
| `battery*` | `battery` | `HelixIcon(HelixIcons.battery, ...)` |
| `chevron_right`, `arrow_forward_ios` | `caret` | `HelixIcon(HelixIcons.caret, ...)` |
| `close`, `clear` | `close` | `HelixIcon(HelixIcons.close, ...)` |
| `more_horiz`, `more_vert` | `more` | `HelixIcon(HelixIcons.more, ...)` |
| `play_arrow`, `play_circle*` | `play` | `HelixIcon(HelixIcons.play, ...)` |
| `fiber_manual_record`, `radio_button_checked` | `record` | `HelixIcon(HelixIcons.record, ...)` |
| `attach_money`, `monetization_on` | `cost` | `HelixIcon(HelixIcons.cost, ...)` |
| `phone_iphone`, `smartphone` | `device` | `HelixIcon(HelixIcons.device, ...)` |
| `cloud*` | `cloud` | `HelixIcon(HelixIcons.cloud, ...)` |
| `bolt`, `flash_on` | `lightning` | `HelixIcon(HelixIcons.lightning, ...)` |

If a Material icon doesn't map to an existing HelixIcons concept and isn't dev-screen-only, add it to `lib/theme/helix_icons.dart` and update `_duotoneMap` before using it.

For dev/utility screens (`g1_test_screen.dart`, `dev/`, `file_management_screen.dart`), `Icon(Icons.xxx)` is acceptable to leave in place — these are not user-facing.

**c.** Per-file commit example:

```bash
flutter analyze lib/screens/home_screen.dart && flutter test test/
git add lib/screens/home_screen.dart
git commit -m "refactor(icons): migrate home_screen Icons.xxx to HelixIcon

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

- [ ] **Step 3: Migrate per file** (one commit per file)

  - [ ] `lib/screens/home_screen.dart`
  - [ ] `lib/screens/recording_screen.dart`
  - [ ] `lib/screens/conversation_history_screen.dart`
  - [ ] `lib/screens/conversation_detail_screen.dart`
  - [ ] `lib/screens/ask_ai_screen.dart`
  - [ ] `lib/screens/insights_screen.dart`
  - [ ] `lib/screens/facts_screen.dart`
  - [ ] `lib/screens/memories_screen.dart`
  - [ ] `lib/screens/todos_screen.dart`
  - [ ] `lib/screens/settings_screen.dart`
  - [ ] `lib/screens/onboarding_screen.dart`
  - [ ] `lib/screens/even_features_screen.dart`
  - [ ] `lib/screens/even_ai_history_screen.dart`
  - [ ] `lib/screens/live_history_screen.dart`
  - [ ] `lib/screens/pending_facts_review.dart`
  - [ ] `lib/screens/session_prep_screen.dart`
  - [ ] `lib/screens/buzz_screen.dart`
  - [ ] `lib/widgets/active_project_chip.dart`
  - [ ] `lib/widgets/fact_card.dart`
  - [ ] `lib/widgets/home_assistant_modules.dart`
  - [ ] `lib/widgets/status_indicator.dart`

- [ ] **Step 4: Verify the bottom-nav still uses Material icons**

`lib/app.dart` `MainScreen` builds the `NavigationDestination`s. Material icons there are functional (the nav doesn't need to be duotone for v1 — it uses tinted weights driven by `navigationBarTheme`). Skip them in this task; Task 3.6 handles nav.

- [ ] **Step 5: Final verification**

```bash
grep -rn "Icon(Icons\." lib/ | grep -v "lib/services/bitmap_hud/" | grep -v "lib/app.dart" | grep -v "lib/screens/dev/" | grep -v "lib/screens/g1_test_screen.dart" | grep -v "lib/screens/file_management_screen.dart"
```

Expected: empty (or near-empty — only `dev/` etc. remaining).

- [ ] **Step 6: Phase 3.5 tag**

```bash
git tag phase-3-icons-migrated
```

---

### Task 3.6: Migrate bottom-nav to `HelixIcon` (and reduce 5 tabs → keep current)

**Files:**
- Modify: `lib/app.dart`

- [ ] **Step 1: Replace the 5 nav destinations**

Open `lib/app.dart`. The `MainScreen.build` method's `destinations:` list currently uses 5 `NavigationDestination`s with Material icons. Replace:

```dart
destinations: [
  NavigationDestination(
    icon: const HelixIcon(HelixIcons.home, useDuotone: false),
    selectedIcon: const HelixIcon(HelixIcons.home),
    label: tr('Home', '首页'),
  ),
  NavigationDestination(
    icon: const HelixIcon(HelixIcons.glasses, useDuotone: false),
    selectedIcon: const HelixIcon(HelixIcons.glasses),
    label: tr('Glasses', '眼镜'),
  ),
  NavigationDestination(
    icon: const HelixIcon(HelixIcons.listen, useDuotone: false),
    selectedIcon: const HelixIcon(HelixIcons.listen),
    label: tr('Live', '实时'),
  ),
  NavigationDestination(
    icon: const HelixIcon(HelixIcons.ai, useDuotone: false),
    selectedIcon: const HelixIcon(HelixIcons.ai),
    label: tr('Ask AI', '问 AI'),
  ),
  NavigationDestination(
    icon: const HelixIcon(HelixIcons.insight, useDuotone: false),
    selectedIcon: const HelixIcon(HelixIcons.insight),
    label: tr('Insights', '洞察'),
  ),
],
```

Add the imports:

```dart
import 'theme/helix_icons.dart';
```

- [ ] **Step 2: Update the placeholder error icon (line ~243)**

In `ErrorScreen.build`, replace:

```dart
const Icon(Icons.error_outline, size: 64, color: Colors.red),
```

with:

```dart
HelixIcon(HelixIcons.fact, size: 64, color: HelixTokens.light.danger, useDuotone: false),
```

(`fact` is `check-circle`; we don't have an "alert" icon in the registry. Add `alert` to `HelixIcons` if you prefer — `PhosphorIconsRegular.warningCircle`.)

If you add a new `alert` entry, also add the duotone map.

- [ ] **Step 3: Analyze + test**

```bash
flutter analyze lib/app.dart && flutter test test/
```

Expected: 0 errors.

- [ ] **Step 4: Visual check**

```bash
flutter run -d $HELIX_SIM
```

Bottom nav should now show duotone icons on the selected tab and line-only on unselected. Selected indicator pill should be terracotta-tinted.

- [ ] **Step 5: Commit**

```bash
git add lib/app.dart lib/theme/helix_icons.dart  # if you added alert
git commit -m "feat(nav): bottom navigation uses HelixIcon duotone

Selected tab shows duotone weight; unselected shows line weight.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3.7: Migrate `TextStyle(...)` call sites to `HelixType.xxx`

**Files:** all screens and widgets with `TextStyle(...)` (~438 hits)

Strategy: this is the biggest mechanical task. Migrate **per-file**, focusing on the most common patterns. Not every inline style needs migration — only ones whose properties match the spec scale.

- [ ] **Step 1: Identify the dominant inline patterns**

```bash
grep -rn "TextStyle(" lib/ | grep -oE "fontSize: [0-9]+" | sort | uniq -c | sort -rn | head
```

Expected output: most common sizes are 14, 12, 16, 11, 13, 18, 24, 28 — which map to `body`, `caption`, `bodyLg`, `label`, `bodySm`, `title2`, `title1`, `display`.

- [ ] **Step 2: Migrate file by file**

For each file with significant `TextStyle(...)` use, replace each instance with the matching `HelixType.xxx(color: someColor)` call. Examples:

`TextStyle(color: HelixTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)` → `HelixType.body(color: HelixTokens.light.ink).copyWith(fontWeight: FontWeight.w600)` — only if the weight actually differs from the scale's default.

If an inline style **exactly** matches a scale entry, replace it cleanly. If it has minor deviations (e.g., custom letter-spacing), use `.copyWith(...)`. If it has wildly different values (e.g., `fontSize: 96`), leave it inline — that's a one-off that doesn't belong in the scale.

- [ ] **Step 3: Files to migrate** (one commit per file)

For each file, the workflow is:
1. Add `import '../theme/helix_type.dart';`
2. Replace `TextStyle(...)` with matching `HelixType.xxx(...)`.
3. Run `flutter analyze <file>` and `flutter test test/`.
4. Commit.

  - [ ] `lib/screens/home_screen.dart`
  - [ ] `lib/screens/recording_screen.dart`
  - [ ] `lib/screens/conversation_history_screen.dart`
  - [ ] `lib/screens/conversation_detail_screen.dart`
  - [ ] `lib/screens/ask_ai_screen.dart`
  - [ ] `lib/screens/insights_screen.dart`
  - [ ] `lib/screens/facts_screen.dart`
  - [ ] `lib/screens/memories_screen.dart`
  - [ ] `lib/screens/todos_screen.dart`
  - [ ] `lib/screens/settings_screen.dart`
  - [ ] `lib/screens/onboarding_screen.dart`
  - [ ] `lib/screens/even_features_screen.dart`
  - [ ] `lib/screens/detail_analysis_screen.dart`
  - [ ] `lib/screens/live_history_screen.dart`
  - [ ] `lib/screens/even_ai_history_screen.dart`
  - [ ] `lib/screens/pending_facts_review.dart`
  - [ ] `lib/screens/session_prep_screen.dart`
  - [ ] `lib/screens/buzz_screen.dart`
  - [ ] `lib/screens/ai_assistant_screen.dart`
  - [ ] `lib/screens/hud_widgets_screen.dart`
  - [ ] `lib/widgets/active_project_chip.dart`
  - [ ] `lib/widgets/animated_text_stream.dart`
  - [ ] `lib/widgets/fact_card.dart`
  - [ ] `lib/widgets/home_assistant_modules.dart`
  - [ ] `lib/widgets/session_cost_badge.dart`
  - [ ] `lib/widgets/session_cost_breakdown_sheet.dart`
  - [ ] `lib/widgets/status_indicator.dart`

Skip migration for:
- `lib/services/bitmap_hud/` — HUD glyph rendering uses raw `ui.TextStyle`, not Material `TextStyle`. Not in scope.
- `lib/screens/dev/`, `g1_test_screen.dart`, `file_management_screen.dart` — utility screens. Migrating is optional but encouraged with `HelixType.mono()` where `fontFamily: 'monospace'` was used.

- [ ] **Step 4: Replace `'monospace'` and `'SF Mono'` font-family inlines**

```bash
grep -rn "fontFamily: 'monospace'\|fontFamily: 'SF Mono'" lib/
```

For each hit, replace the inline `TextStyle(fontFamily: 'monospace', ...)` with `HelixType.mono(color: ...)`.

- [ ] **Step 5: Run analyzer + tests**

```bash
flutter analyze && flutter test test/
```

Expected: 0 errors.

---

### Task 3.8: Re-skin reusable widgets (`StatusIndicator`, `FactCard`, `ActiveProjectChip`, `SessionCostBadge`, `AnimatedTextStream`)

**Files:**
- Modify: `lib/widgets/status_indicator.dart`
- Modify: `lib/widgets/fact_card.dart`
- Modify: `lib/widgets/active_project_chip.dart`
- Modify: `lib/widgets/session_cost_badge.dart`
- Modify: `lib/widgets/animated_text_stream.dart`

For each, follow this pattern (illustrating with `status_indicator.dart` — repeat per widget):

- [ ] **Step 1: Read the current widget**

```bash
cat lib/widgets/status_indicator.dart
```

- [ ] **Step 2: Apply the spec recolor**

For `StatusIndicator`: replace cyan/amber/lime references with token references:
- listening → `HelixTokens.of(context).accent` with a `1.5s` repeating pulse animation.
- thinking → `HelixTokens.of(context).warning`.
- ready → `HelixTokens.of(context).success`.
- offline → `HelixTokens.of(context).inkMuted`.

If pulse animation isn't already there, add a `Tween` between alpha 0.6 and 1.0 over `Duration(milliseconds: 1500)` repeating.

For `FactCard`: change card background from translucent dark to `t.surface`, add a left border `BorderSide(color: t.support, width: 4)`, use `HelixIcon(HelixIcons.fact, color: t.success)` for confirmed and a small dot in `t.warning` for pending.

For `ActiveProjectChip`: pill shape, `t.accentTint` background, terracotta `t.accent` text + `HelixIcon(HelixIcons.bookmark, color: t.accent)`.

For `SessionCostBadge`: gold chip — replace existing background with `t.gold.withValues(alpha: 0.15)`, text in `HelixType.mono(color: t.ink)`.

For `AnimatedTextStream`: blink cursor uses `t.accent`, AI answer text uses `HelixType.title1`, transcript uses `HelixType.bodyLg`.

- [ ] **Step 3: Per-widget commit**

```bash
flutter analyze lib/widgets/status_indicator.dart && flutter test test/
git add lib/widgets/status_indicator.dart
git commit -m "refactor(widgets): reskin StatusIndicator with Warm Linen tokens

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

Repeat per widget.

---

### Task 3.9: Phase 3 gate

**Files:** none

- [ ] **Step 1: Validation gate**

```bash
bash scripts/run_gate.sh
```

Expected: PASS.

- [ ] **Step 2: Visual smoke test**

```bash
flutter run -d $HELIX_SIM
```

Walk through every screen. All icons should be Phosphor duotone (not Material), all body text should render in Inter, all titles in Fraunces.

- [ ] **Step 3: Capture screenshots**

```bash
mkdir -p tmp/screenshots/after-phase3
xcrun simctl io $HELIX_SIM screenshot tmp/screenshots/after-phase3/home.png
# repeat per screen
```

- [ ] **Step 4: Tag**

```bash
git tag phase-3-components-migrated
```

Phase 3 complete.

---

## Phase 4 — Illustrations & app icon

Goal: regenerate the 5 existing illustrations and add 4 new empty-state assets in line+watercolor style. Replace iOS app icon.

### Task 4.1: Generate illustrations from LLM prompts

**Files:** none in repo (asset generation)

- [ ] **Step 1: Open the spec for the prompts**

```bash
sed -n '267,310p' docs/superpowers/specs/2026-04-28-warm-linen-theme-redesign-design.md
```

- [ ] **Step 2: Generate each asset** using your preferred image-gen tool (Recraft v3 recommended for editorial line+watercolor):

  - [ ] `onboarding-glasses-hud.png` — prompt #1 in spec
  - [ ] `home-live-conversation.png` — prompt #2
  - [ ] `glasses-device-hero.png` — prompt #3
  - [ ] `insights-knowledge-graph.png` — prompt #4
  - [ ] `helix-app-icon-source.png` — prompt #5
  - [ ] `empty-facts.png` — prompt #6
  - [ ] `empty-memories.png` — prompt #7
  - [ ] `empty-todos.png` — prompt #8
  - [ ] `empty-history.png` — prompt #9

For each, generate at least 4 variants and pick the best. Generate at 2048×2048 (or 2048×1536 for `home-live-conversation.png`). Save selections to `tmp/generated-assets/<name>.png` first for review.

- [ ] **Step 3: Review with the user** before committing — illustrations are taste-driven.

- [ ] **Step 4: No commit** — assets land in Task 4.2.

---

### Task 4.2: Replace asset files in `assets/illustrations/` and `assets/brand/`

**Files:**
- Modify: `assets/illustrations/onboarding-glasses-hud.png`
- Modify: `assets/illustrations/home-live-conversation.png`
- Modify: `assets/illustrations/glasses-device-hero.png`
- Modify: `assets/illustrations/insights-knowledge-graph.png`
- Modify: `assets/brand/helix-app-icon-source.png`
- Create: `assets/illustrations/empty-facts.png`
- Create: `assets/illustrations/empty-memories.png`
- Create: `assets/illustrations/empty-todos.png`
- Create: `assets/illustrations/empty-history.png`

- [ ] **Step 1: Replace existing 5 assets**

```bash
cp tmp/generated-assets/onboarding-glasses-hud.png assets/illustrations/
cp tmp/generated-assets/home-live-conversation.png assets/illustrations/
cp tmp/generated-assets/glasses-device-hero.png assets/illustrations/
cp tmp/generated-assets/insights-knowledge-graph.png assets/illustrations/
cp tmp/generated-assets/helix-app-icon-source.png assets/brand/
```

- [ ] **Step 2: Add new 4 empty-state assets**

```bash
cp tmp/generated-assets/empty-facts.png assets/illustrations/
cp tmp/generated-assets/empty-memories.png assets/illustrations/
cp tmp/generated-assets/empty-todos.png assets/illustrations/
cp tmp/generated-assets/empty-history.png assets/illustrations/
```

- [ ] **Step 3: Update `lib/theme/helix_assets.dart`**

```dart
class HelixAssets {
  HelixAssets._();

  static const appIconSource = 'assets/brand/helix-app-icon-source.png';
  static const onboardingGlasses =
      'assets/illustrations/onboarding-glasses-hud.png';
  static const homeConversation =
      'assets/illustrations/home-live-conversation.png';
  static const glassesHero = 'assets/illustrations/glasses-device-hero.png';
  static const insightsKnowledge =
      'assets/illustrations/insights-knowledge-graph.png';

  // Empty-state illustrations (Phase 4).
  static const emptyFacts = 'assets/illustrations/empty-facts.png';
  static const emptyMemories = 'assets/illustrations/empty-memories.png';
  static const emptyTodos = 'assets/illustrations/empty-todos.png';
  static const emptyHistory = 'assets/illustrations/empty-history.png';
}
```

- [ ] **Step 4: Verify pubspec.yaml `assets:` block lists `assets/illustrations/`**

```bash
grep -A 5 "^  assets:" pubspec.yaml
```

If the directory isn't listed, add it under `flutter: > assets:`:

```yaml
  assets:
    - assets/illustrations/
    - assets/brand/
    - assets/fonts/
```

- [ ] **Step 5: Run pub get + tests**

```bash
flutter pub get && flutter analyze && flutter test test/
```

Expected: PASS.

- [ ] **Step 6: Visual verification**

```bash
flutter run -d $HELIX_SIM
```

Onboarding, home, glasses tab should show the new illustrations.

- [ ] **Step 7: Commit**

```bash
git add assets/illustrations/ assets/brand/ lib/theme/helix_assets.dart pubspec.yaml
git commit -m "feat(theme): replace illustrations with line+watercolor renderings

Regenerated 5 existing illustrations and added 4 empty-state illustrations
in the new Warm Linen aesthetic.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4.3: Wire empty-state illustrations into screens

**Files:**
- Modify: `lib/screens/facts_screen.dart`
- Modify: `lib/screens/memories_screen.dart`
- Modify: `lib/screens/todos_screen.dart`
- Modify: `lib/screens/conversation_history_screen.dart`

For each screen, add an empty-state widget when the data list is empty.

- [ ] **Step 1: Define an `_EmptyState` private widget per screen** (or pull a shared one into `lib/widgets/empty_state.dart` if you prefer)

For `facts_screen.dart`, the pattern:

```dart
Widget _emptyState(BuildContext context) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(HelixAssets.emptyFacts, width: 200, height: 200),
          const SizedBox(height: 16),
          Text(
            'Facts will appear here as you converse.',
            style: HelixType.bodyLg(color: HelixTokens.of(context).inkSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
```

Use it in the build method when `facts.isEmpty`:

```dart
if (facts.isEmpty) return _emptyState(context);
```

Repeat per screen with the matching asset and copy from spec section 4:
- `facts_screen` → `emptyFacts` + "Facts will appear here as you converse."
- `memories_screen` → `emptyMemories` + "Memories collect over time."
- `todos_screen` → `emptyTodos` + "Things you mention to do will land here."
- `conversation_history_screen` → `emptyHistory` + "Your conversations live here."

- [ ] **Step 2: Per-file commit**

For each screen:

```bash
flutter analyze lib/screens/facts_screen.dart && flutter test test/
git add lib/screens/facts_screen.dart
git commit -m "feat(empty-states): wire empty-facts illustration into facts_screen

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

Repeat for memories, todos, history.

---

### Task 4.4: Replace iOS app icon set

**Files:**
- Modify: `ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png`

- [ ] **Step 1: Generate the icon set from the new source**

The Helix project ships a script (or uses a tool like `flutter_launcher_icons`). Check:

```bash
ls ios/Runner/Assets.xcassets/AppIcon.appiconset/
grep -l "flutter_launcher_icons" pubspec.yaml || echo "no launcher icons config"
```

If `flutter_launcher_icons` is configured, update its source to `assets/brand/helix-app-icon-source.png` and run:

```bash
flutter pub run flutter_launcher_icons
```

If no tool is configured, manually generate the iOS icon sizes from `helix-app-icon-source.png` (40, 58, 60, 80, 87, 120, 180, 1024px) and overwrite each PNG in `ios/Runner/Assets.xcassets/AppIcon.appiconset/`. The `Contents.json` mapping should not change.

- [ ] **Step 2: Verify on simulator**

```bash
flutter run -d $HELIX_SIM
# Press home, look at the app icon
```

The icon should be the helix-coil-with-terracotta-dawn-wash from the prompt.

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat(ios): replace app icon with Warm Linen helix-coil illustration

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4.5: Phase 4 gate

**Files:** none

- [ ] **Step 1: Validation gate**

```bash
bash scripts/run_gate.sh
```

Expected: PASS.

- [ ] **Step 2: Visual smoke test + Dynamic Type**

```bash
flutter run -d $HELIX_SIM
```

In simulator: Settings → Accessibility → Display & Text Size → Larger Text → drag to maximum. Open Helix. Verify text scales but layout doesn't break (the 1.4× cap from Task 2.2 should hold).

- [ ] **Step 3: Tag**

```bash
git tag phase-4-illustrations
```

Phase 4 complete.

---

## Phase 5 — Cleanup

### Task 5.1: Migrate remaining `GlassCard`/`GlowButton` call sites

**Files:** all files importing `glass_card.dart` or `glow_button.dart`

- [ ] **Step 1: Find consumers**

```bash
grep -rln "GlassCard\|GlowButton" lib/ | grep -v "linen_card.dart" | grep -v "warm_button.dart" | grep -v "glass_card.dart" | grep -v "glow_button.dart"
```

Expected: 17 files (per Task 1.5 mapping).

- [ ] **Step 2: For each file, replace imports and class names**

In each file:

```dart
import '../widgets/glass_card.dart';   →   import '../widgets/linen_card.dart';
import '../widgets/glow_button.dart';  →   import '../widgets/warm_button.dart';
```

And in code:

```dart
GlassCard(child: ...)         →   LinenCard(child: ...)
GlowButton(label: 'X', ...)   →   WarmButton.primary(label: 'X', ...)
```

Per-file commit.

- [ ] **Step 3: Verify deprecation warnings are gone**

```bash
flutter analyze 2>&1 | grep -i deprecat
```

Expected: empty (no GlassCard/GlowButton references remain).

---

### Task 5.2: Delete deprecation shims

**Files:**
- Delete: `lib/widgets/glass_card.dart`
- Delete: `lib/widgets/glow_button.dart`

- [ ] **Step 1: Confirm zero consumers**

```bash
grep -rln "GlassCard\|GlowButton" lib/
```

Expected: empty.

- [ ] **Step 2: Delete files**

```bash
git rm lib/widgets/glass_card.dart lib/widgets/glow_button.dart
```

- [ ] **Step 3: Analyzer + tests**

```bash
flutter analyze && flutter test test/
```

Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(widgets): delete GlassCard/GlowButton deprecation shims

All consumers migrated to LinenCard / WarmButton.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5.3: Delete `helix_visuals.dart` if fully superseded

**Files:**
- Maybe delete: `lib/widgets/helix_visuals.dart`

- [ ] **Step 1: Find consumers**

```bash
grep -rln "helix_visuals\|HelixVisual" lib/
```

If empty (or only the file itself), delete:

```bash
git rm lib/widgets/helix_visuals.dart
```

If consumers exist, migrate them to use illustration assets (Task 4.3 pattern) and then delete.

- [ ] **Step 2: Commit**

```bash
flutter analyze && flutter test test/
git commit -m "chore(widgets): delete superseded helix_visuals.dart

Replaced by line+watercolor illustration assets.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5.4: Drop `HelixTheme` color aliases — force migration to `HelixTokens`

**Files:**
- Modify: `lib/theme/helix_theme.dart`
- Modify: ~17 consumer files

This task is optional but recommended for long-term cleanliness.

- [ ] **Step 1: Find every consumer of the deprecated aliases**

```bash
grep -rn "HelixTheme\.\(cyan\|cyanDeep\|purple\|lime\|amber\|error\|background\|backgroundRaised\|surface\|surfaceRaised\|surfaceInteractive\|borderSubtle\|borderStrong\|textPrimary\|textSecondary\|textMuted\|statusListening\|statusThinking\|statusReady\|statusOffline\|panelFill\|panelBorder\)" lib/
```

- [ ] **Step 2: Mechanically replace each with the matching `HelixTokens.of(context).<name>` call**

Per the alias map in `helix_theme.dart` (Task 2.2). For files that aren't widgets and don't have a `BuildContext`, use `HelixTokens.light.<name>`.

- [ ] **Step 3: Per-file commit**

This is a large refactor — commit per file or per group of related files (e.g., all of `lib/screens/recording_screen.dart` in one commit).

- [ ] **Step 4: When all consumers migrated, drop the aliases**

In `lib/theme/helix_theme.dart`, delete the entire backwards-compat alias block (`background`, `cyan`, `textPrimary`, `panelFill`, `panelBorder`, etc.). Keep only `lightTheme`, `darkTheme`, and `_buildTheme`.

- [ ] **Step 5: Final analyzer + tests**

```bash
flutter analyze && flutter test test/
```

Expected: 0 errors.

- [ ] **Step 6: Commit**

```bash
git add lib/theme/helix_theme.dart
git commit -m "refactor(theme): drop HelixTheme color aliases — pure tokens-only

All consumers migrated to HelixTokens.of(context). HelixTheme is now
solely a ThemeData factory.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5.5: Update `CLAUDE.md` and project docs

**Files:**
- Modify: `CLAUDE.md`
- Maybe modify: `docs/PROGRESS.md`, `docs/learning.md`

- [ ] **Step 1: Update theme description in `CLAUDE.md`**

In the project memory or `CLAUDE.md`, update any reference to "dark glassmorphism" / "cyan theme" / "GlassCard" / "GlowButton" to the new descriptions:
- "Warm Linen light-first theme"
- "LinenCard, WarmButton primitives"
- "Phosphor duotone icons via HelixIcons"
- "Fraunces + Inter + JetBrains Mono"

- [ ] **Step 2: Append a milestone note in `docs/PROGRESS.md`**

```markdown
## 2026-XX-XX — Warm Linen theme redesign

- Light-first warm palette replaces cool-cyan dark glassmorphism
- 60+ hardcoded colors migrated to token system
- Phosphor duotone icons via `HelixIcons` registry
- Fraunces + Inter + JetBrains Mono bundled fonts
- Line+watercolor illustration set (5 hero + 4 empty states)
- Spec: `docs/superpowers/specs/2026-04-28-warm-linen-theme-redesign-design.md`
```

- [ ] **Step 3: Refresh screenshots in `docs/`**

If `docs/` has any product screenshots referencing the old theme, regenerate them:

```bash
mkdir -p docs/screenshots/warm-linen
xcrun simctl io $HELIX_SIM screenshot docs/screenshots/warm-linen/home.png
# repeat for hero screens
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md docs/
git commit -m "docs: update CLAUDE.md and progress for Warm Linen redesign

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5.6: Final gate + tag

**Files:** none

- [ ] **Step 1: Run the full validation gate**

```bash
bash scripts/run_gate.sh
```

Expected: PASS.

- [ ] **Step 2: Final visual smoke test**

```bash
flutter run -d $HELIX_SIM
```

Walk every screen. Confirm:
- Warm Linen palette throughout (no cyan/navy artifacts).
- Phosphor duotone icons everywhere.
- Fraunces titles, Inter body.
- Line+watercolor illustrations on hero + empty screens.
- Bottom-nav indicator is terracotta.
- New iOS app icon shows on home screen.

- [ ] **Step 3: Tag final**

```bash
git tag warm-linen-v1
```

- [ ] **Step 4: Open a PR**

```bash
gh pr create --title "Warm Linen theme redesign" --body "$(cat <<'EOF'
## Summary
- Replace cool-cyan dark glassmorphism with light-first Warm Linen palette
- Phosphor duotone icon system via `HelixIcons` registry (~25 semantic icons)
- Bundle Fraunces + Inter + JetBrains Mono fonts (no runtime fetch)
- Regenerate 5 existing illustrations + 4 new empty-state assets in line+watercolor style
- Migrate ~60 drift-introduced hardcoded `Color(0x...)` to tokens
- Replace iOS app icon

## Test plan
- [ ] Validation gate passes (`bash scripts/run_gate.sh`)
- [ ] Visual smoke test on iPhone 17 simulator (all primary screens)
- [ ] Dynamic Type at maximum scale doesn't break layout
- [ ] Light + dark mode both render correctly
- [ ] Onboarding shows new line+watercolor slides
- [ ] Empty states show new illustrations on facts/memories/todos/history

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

Plan complete.

---

## Self-review — appendix

(Used during plan-writing to confirm coverage. Kept here for traceability.)

**Spec section coverage:**

- Direction (light/warm/duotone/linen/serif) → Tasks 2.1, 2.2, 1.4, 3.1, 3.2 (palette, theme, type, components).
- Section 1 design tokens → Tasks 1.3, 2.1.
- Section 2 typography → Tasks 1.2, 1.4 (placeholder), 2.2 (theme adoption), 3.7 (call-site migration).
- Section 3 components → Tasks 3.1, 3.2, 3.3, 3.4, 3.6, 3.8.
- Section 4 icons → Tasks 1.1, 1.5, 3.5, 3.6.
- Section 4 illustrations → Tasks 4.1, 4.2, 4.3, 4.4.
- Section 5 implementation phases → Phases 1-5 of this plan map 1:1.
- Hardcoded color migration → Tasks 2.3-2.13.
- Hero-screens overlap risk → Task 3.0.
- Liquid Glass risk → Tokens never opt in (no task needed; default Flutter rendering).
- Dynamic Type cap → Task 2.2 Step 2.
- Dark mode parity → Tasks 2.1, 2.2 (both shipped together).
