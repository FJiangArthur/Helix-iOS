# Hero Screens Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an expressive visual upgrade to Home, Glasses, and Insights screens, anchored on a reactive mic-driven waveform on the Home hero card.

**Architecture:** Vertical slice approach. Phase A builds the Home hero end-to-end (mic-level native plumbing + 5 new primitives + token families + hero card). Phases B–D consume the proven primitives to upgrade the rest of Home, then Glasses, then Insights. Existing widgets (`GlassCard`, `GlowButton`) are not deprecated; new primitives are additive.

**Tech Stack:** Flutter 3.35+ / Dart 3 · Swift / iOS 15+ · `flutter_svg` (new dep) · `cupertino_icons` (existing dep, used for SF Symbols) · `AVFoundation` (existing audio engine taps) · GetX + plain Streams (existing) · Drift (existing).

**Spec:** `docs/superpowers/specs/2026-04-25-hero-screens-overhaul-design.md`

**Validation gate (run after every task that modifies code):**
```bash
flutter analyze
flutter test test/
```
After any task touching the files listed in `CLAUDE.md` § "After modifying these files, run the FULL gate", run:
```bash
bash scripts/run_gate.sh
```

---

## File Structure

### New files

| Path | Responsibility |
|---|---|
| `lib/theme/helix_gradients.dart` | Named `LinearGradient` constants (`liveSignal`, `quietGlass`, `factWarm`, `glassesPhosphor`). |
| `lib/theme/helix_glow.dart` | Named `BoxShadow` recipes (`subtle`, `active`, `pulse`) and a `pulseTween` helper. |
| `lib/theme/helix_motion.dart` | Named durations + curves; `HelixMotion.ambientTickerOf(context)` returns the shared 1.4s controller. |
| `lib/services/mic_level_service.dart` | Singleton; exposes `Stream<double> rmsStream` (0..1). `.test()` factory matches `ConversationListeningSession.test()`. |
| `ios/Runner/MicLevelObserver.swift` | Hooks the existing audio tap; computes per-buffer RMS; throttles to 30 Hz; ships values via `eventMicLevel`. |
| `lib/widgets/live_waveform.dart` | `CustomPainter`-based waveform, `repaint:` driven by a `ValueNotifier<double>`. |
| `lib/widgets/living_panel.dart` | Glass surface with ambient gradient drift; optional active border glow. |
| `lib/widgets/live_status_pill.dart` | State pill with cross-fading state, dot pulse, optional elapsed time. |
| `lib/widgets/breathing_chip.dart` | Entrance + idle micro-motion chip with tone palette. |
| `lib/widgets/helix_icon.dart` | Single API resolving 14 brand SVGs and SF Symbol fallbacks. |
| `lib/widgets/helix_icons.dart` | `HelixIcons` enum + asset map. |
| `assets/icons/helix/*.svg` | 14 placeholder SVGs (final art swappable later). |
| `lib/widgets/home/home_hero_card.dart` | Composes `LivingPanel` + `LiveStatusPill` + `LiveWaveform` + actions. |
| `lib/widgets/glasses/glasses_hero_card.dart` | L/R dot card; uptime ticker; primary action. |
| `lib/widgets/sparkline_row.dart` | **NOT in this plan** — explicitly deferred per the spec. |
| `test/widgets/live_waveform_test.dart` | Idle fallback + 30 Hz throttle + repaint counts. |
| `test/widgets/living_panel_test.dart` | Renders + `disableAnimations` honored. |
| `test/widgets/live_status_pill_test.dart` | One test per state + transition. |
| `test/widgets/breathing_chip_test.dart` | Entrance, selected, tap, `disableAnimations`. |
| `test/widgets/helix_icon_test.dart` | Both code paths, semantic labels. |
| `test/widgets/home_hero_card_test.dart` | Hero card composition with fakes. |
| `test/widgets/glasses_hero_card_test.dart` | L/R dot states across `BleConnectionState`. |
| `test/services/mic_level_service_test.dart` | `.test()` factory; pause-on-no-listeners; range clamp. |

### Modified files

| Path | Change |
|---|---|
| `pubspec.yaml` | Add `flutter_svg: ^2.0.10`. Add `assets/icons/helix/` to `flutter > assets`. |
| `ios/Runner/AppDelegate.swift` | Register `eventMicLevel` `FlutterEventChannel` and bind `MicLevelObserver.shared` as stream handler. |
| `ios/Runner/SpeechStreamRecognizer.swift` | At each of three `installTap` sites (lines 657, 780, 1169), call `MicLevelObserver.shared.observeBuffer(buffer)` from inside the existing tap callback. No tap config change. |
| `lib/screens/home_screen.dart` | Phase A: replace `_buildOverviewCard()` body with `HomeHeroCard`. Phase B: migrate mode selector + chip rows to `BreathingChip`; swap hero-region Material icons for `HelixIcon`. |
| `lib/screens/g1_test_screen.dart` | Phase C: replace `_buildHeroCard()` body with `GlassesHeroCard`; upgrade `_buildTelemetryCard` to `LivingPanel`; convert connection-workflow steps to `BreathingChip`; wrap active paired device in `LivingPanel`. |
| `lib/screens/insights_screen.dart` | Phase D: pending-cards swipe stack; freshness gradient; day-section spine; theme/buzz chip migration; `LiveStatusPill` for streaming indicator. |
| `lib/ble_manager.dart` | Phase C: add `DateTime? connectedAt` field; set on `connected` transition; clear on `disconnected`. |

---

## Phase A — Home hero vertical slice

Goal: ship a visible, working reactive waveform hero on Home. Every primitive needed by later phases is built and exercised here.

### Task A1: Add `flutter_svg` dependency and asset folder

**Files:**
- Modify: `pubspec.yaml`
- Create: `assets/icons/helix/.gitkeep`

- [ ] **Step 1: Edit `pubspec.yaml` dependencies block**

Find the `dependencies:` block and add (alphabetical position):

```yaml
  flutter_svg: ^2.0.10
```

Find the `flutter:` block (the one with `uses-material-design: true` and `assets:`) and add to the existing `assets:` list:

```yaml
    - assets/icons/helix/
```

- [ ] **Step 2: Create the asset folder placeholder**

```bash
mkdir -p assets/icons/helix
touch assets/icons/helix/.gitkeep
```

- [ ] **Step 3: Resolve dependency**

```bash
flutter pub get
```
Expected: succeeds with no errors.

- [ ] **Step 4: Verify analyze still clean**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock assets/icons/helix/.gitkeep
git commit -m "feat(deps): add flutter_svg + helix icon asset path"
```

---

### Task A2: Theme tokens — `HelixGradients`, `HelixGlow`, `HelixMotion`

**Files:**
- Create: `lib/theme/helix_gradients.dart`
- Create: `lib/theme/helix_glow.dart`
- Create: `lib/theme/helix_motion.dart`
- Test: `test/theme/helix_tokens_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/theme/helix_tokens_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/theme/helix_glow.dart';
import 'package:even_glasses/theme/helix_gradients.dart';
import 'package:even_glasses/theme/helix_motion.dart';

void main() {
  test('HelixGradients constants are non-null and have stops', () {
    expect(HelixGradients.liveSignal.colors.length, greaterThanOrEqualTo(2));
    expect(HelixGradients.quietGlass.colors.length, greaterThanOrEqualTo(2));
    expect(HelixGradients.factWarm.colors.length, greaterThanOrEqualTo(2));
    expect(HelixGradients.glassesPhosphor.colors.length, greaterThanOrEqualTo(2));
  });

  test('HelixGlow recipes return BoxShadow lists', () {
    expect(HelixGlow.subtle, isA<List<BoxShadow>>());
    expect(HelixGlow.subtle, isNotEmpty);
    expect(HelixGlow.active, isNotEmpty);
    expect(HelixGlow.pulseAt(0.5), isNotEmpty);
  });

  test('HelixGlow.pulseAt lerps alpha between 0.18 and 0.32', () {
    final low = HelixGlow.pulseAt(0.0).first.color.a;
    final high = HelixGlow.pulseAt(1.0).first.color.a;
    expect(low, closeTo(0.18, 0.01));
    expect(high, closeTo(0.32, 0.01));
  });

  test('HelixMotion exposes named durations and curves', () {
    expect(HelixMotion.fast, const Duration(milliseconds: 180));
    expect(HelixMotion.standard, const Duration(milliseconds: 320));
    expect(HelixMotion.ambient, const Duration(milliseconds: 1400));
    expect(HelixMotion.fastCurve, isNotNull);
    expect(HelixMotion.standardCurve, isNotNull);
    expect(HelixMotion.ambientCurve, isNotNull);
  });
}
```

> **Note on package name:** The test imports `package:even_glasses/...`. If your `pubspec.yaml` lists a different `name:`, replace `even_glasses` with that value across all task code blocks. To verify: `grep '^name:' pubspec.yaml`.

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/theme/helix_tokens_test.dart
```
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement `HelixGradients`**

Create `lib/theme/helix_gradients.dart`:

```dart
import 'package:flutter/material.dart';

import 'helix_theme.dart';

class HelixGradients {
  HelixGradients._();

  static const LinearGradient liveSignal = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [HelixTheme.cyan, HelixTheme.purple],
  );

  static LinearGradient quietGlass = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      HelixTheme.cyan.withValues(alpha: 0.04),
      HelixTheme.cyan.withValues(alpha: 0.0),
    ],
  );

  static const LinearGradient factWarm = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [HelixTheme.amber, HelixTheme.cyan],
  );

  static const LinearGradient glassesPhosphor = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF052015), Color(0xFF000000)],
  );
}
```

- [ ] **Step 4: Implement `HelixGlow`**

Create `lib/theme/helix_glow.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import 'helix_theme.dart';

class HelixGlow {
  HelixGlow._();

  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color(0x3D000000),
      blurRadius: 18,
      offset: Offset(0, 10),
    ),
    BoxShadow(
      color: Color(0x08FFFFFF),
      blurRadius: 1,
      spreadRadius: 0.5,
    ),
  ];

  static List<BoxShadow> get active => [
    BoxShadow(
      color: HelixTheme.cyan.withValues(alpha: 0.28),
      blurRadius: 22,
      spreadRadius: -2,
    ),
    ...subtle,
  ];

  /// Pulse glow lerped between alpha 0.18 and 0.32.
  /// `t` in [0, 1].
  static List<BoxShadow> pulseAt(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final alpha = lerpDouble(0.18, 0.32, clamped)!;
    return [
      BoxShadow(
        color: HelixTheme.cyan.withValues(alpha: alpha),
        blurRadius: 22,
        spreadRadius: -2,
      ),
      ...subtle,
    ];
  }
}
```

- [ ] **Step 5: Implement `HelixMotion`**

Create `lib/theme/helix_motion.dart`:

```dart
import 'package:flutter/animation.dart';

class HelixMotion {
  HelixMotion._();

  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 320);
  static const Duration ambient = Duration(milliseconds: 1400);

  static const Curve fastCurve = Curves.easeOutCubic;
  static const Curve standardCurve = Curves.easeOutQuart;
  static const Curve ambientCurve = Curves.easeInOutSine;
}
```

- [ ] **Step 6: Run test to verify it passes**

```bash
flutter test test/theme/helix_tokens_test.dart
```
Expected: PASS, 4 tests.

- [ ] **Step 7: Commit**

```bash
git add lib/theme/helix_gradients.dart lib/theme/helix_glow.dart lib/theme/helix_motion.dart test/theme/helix_tokens_test.dart
git commit -m "feat(theme): add HelixGradients/HelixGlow/HelixMotion tokens"
```

---

### Task A3: `MicLevelService` (Dart side, with fake transport)

**Files:**
- Create: `lib/services/mic_level_service.dart`
- Test: `test/services/mic_level_service_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/services/mic_level_service_test.dart`:

```dart
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/services/mic_level_service.dart';

void main() {
  test('emits values from injected stream', () async {
    final controller = StreamController<double>();
    final svc = MicLevelService.test(rmsEvents: controller.stream);
    final received = <double>[];
    final sub = svc.rmsStream.listen(received.add);

    controller.add(0.4);
    controller.add(0.7);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(received, [0.4, 0.7]);
    await sub.cancel();
    await controller.close();
  });

  test('clamps values outside [0, 1]', () async {
    final controller = StreamController<double>();
    final svc = MicLevelService.test(rmsEvents: controller.stream);
    final received = <double>[];
    final sub = svc.rmsStream.listen(received.add);

    controller.add(-0.5);
    controller.add(2.0);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(received, [0.0, 1.0]);
    await sub.cancel();
    await controller.close();
  });

  test('supports multiple listeners (broadcast)', () async {
    final controller = StreamController<double>();
    final svc = MicLevelService.test(rmsEvents: controller.stream);
    final a = <double>[];
    final b = <double>[];
    final s1 = svc.rmsStream.listen(a.add);
    final s2 = svc.rmsStream.listen(b.add);

    controller.add(0.5);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(a, [0.5]);
    expect(b, [0.5]);
    await s1.cancel();
    await s2.cancel();
    await controller.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/services/mic_level_service_test.dart
```
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement `MicLevelService`**

Create `lib/services/mic_level_service.dart`:

```dart
import 'dart:async';

import 'package:flutter/services.dart';

class MicLevelService {
  MicLevelService._({Stream<dynamic>? rmsEvents})
      : _rmsEvents = rmsEvents ??
            const EventChannel(_eventMicLevel)
                .receiveBroadcastStream(_eventMicLevel);

  static const _eventMicLevel = 'eventMicLevel';

  static MicLevelService? _instance;
  static MicLevelService get instance => _instance ??= MicLevelService._();

  /// Test factory — inject a pre-built stream of doubles (or anything
  /// `num`-coercible). Mirrors `ConversationListeningSession.test()`.
  factory MicLevelService.test({required Stream<dynamic> rmsEvents}) {
    return MicLevelService._(rmsEvents: rmsEvents);
  }

  final Stream<dynamic> _rmsEvents;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<double>.broadcast(
    onListen: () {},
    onCancel: () {},
  );

  Stream<double> get rmsStream {
    _ensureSubscribed();
    return _controller.stream;
  }

  void _ensureSubscribed() {
    _sub ??= _rmsEvents.listen((event) {
      final v = (event as num).toDouble().clamp(0.0, 1.0);
      _controller.add(v);
    });
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
flutter test test/services/mic_level_service_test.dart
```
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/services/mic_level_service.dart test/services/mic_level_service_test.dart
git commit -m "feat(services): add MicLevelService with test factory"
```

---

### Task A4: iOS `MicLevelObserver` and `eventMicLevel` channel

**Files:**
- Create: `ios/Runner/MicLevelObserver.swift`
- Modify: `ios/Runner/AppDelegate.swift` (add channel registration)
- Modify: `ios/Runner/SpeechStreamRecognizer.swift` (3 tap sites)

- [ ] **Step 1: Create `MicLevelObserver.swift`**

Create `ios/Runner/MicLevelObserver.swift`:

```swift
import AVFoundation
import Flutter
import Foundation

/// Singleton that observes audio buffers from the existing speech-recognition
/// taps. Computes per-buffer RMS, throttles to 30 Hz, ships values to Dart
/// via the `eventMicLevel` EventChannel.
///
/// No audio session config and no separate tap — observer is registered
/// alongside the existing transcription tap. When transcription is not
/// running, no buffers arrive, so the observer naturally goes quiet.
class MicLevelObserver: NSObject, FlutterStreamHandler {
    static let shared = MicLevelObserver()

    private var eventSink: FlutterEventSink?
    private var lastEmit: TimeInterval = 0
    private let minInterval: TimeInterval = 1.0 / 30.0   // 30 Hz cap
    private let queue = DispatchQueue(label: "helix.mic-level.observer")

    /// Called from inside existing `installTap` callbacks in
    /// SpeechStreamRecognizer. No-op when no Dart listener is attached.
    func observeBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self, let sink = self.eventSink else { return }
            let now = CACurrentMediaTime()
            if now - self.lastEmit < self.minInterval { return }
            self.lastEmit = now

            guard let rms = Self.rms(of: buffer) else { return }
            DispatchQueue.main.async {
                sink(rms)
            }
        }
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Double? {
        guard let channelData = buffer.floatChannelData?.pointee else { return nil }
        let frameCount = Int(buffer.frameLength)
        if frameCount == 0 { return 0.0 }
        var sumSquares: Double = 0.0
        for i in 0..<frameCount {
            let sample = Double(channelData[i])
            sumSquares += sample * sample
        }
        let mean = sumSquares / Double(frameCount)
        let raw = sqrt(mean)
        // Float PCM is in [-1, 1]; RMS in [0, 1]. Apply a soft floor + ceiling
        // so the waveform reads well visually.
        return min(max(raw, 0.0), 1.0)
    }

    // MARK: - FlutterStreamHandler

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
```

- [ ] **Step 2: Register the channel in `AppDelegate.swift`**

In `ios/Runner/AppDelegate.swift`, find the existing block where other event channels are registered (around line 351, `passiveEventChannel`). Add immediately after the `passiveEventChannel.setStreamHandler(...)` line:

```swift
        let micLevelEventChannel = FlutterEventChannel(
            name: "eventMicLevel",
            binaryMessenger: controller.binaryMessenger
        )
        micLevelEventChannel.setStreamHandler(MicLevelObserver.shared)
```

- [ ] **Step 3: Hook the three `installTap` sites in `SpeechStreamRecognizer.swift`**

Open `ios/Runner/SpeechStreamRecognizer.swift`. There are three `inputNode.installTap(onBus: 0, ...)` calls (around lines 657, 780, 1169). Each has a closure that receives `(buffer: AVAudioPCMBuffer, _ when: AVAudioTime)`. Inside each closure, **at the very top of the closure body**, add:

```swift
                            MicLevelObserver.shared.observeBuffer(buffer)
```

(Indentation matches the existing closure body — copy-paste then re-indent if needed.)

Do this for all three sites. Do not remove or change any existing tap config.

- [ ] **Step 4: Build for simulator**

```bash
flutter build ios --simulator --no-codesign
```
Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add ios/Runner/MicLevelObserver.swift ios/Runner/AppDelegate.swift ios/Runner/SpeechStreamRecognizer.swift
git commit -m "feat(ios): add MicLevelObserver tap + eventMicLevel channel"
```

---

### Task A5: 14 placeholder brand SVGs

**Files:**
- Create: `assets/icons/helix/{helix,listen,glasses,hud,fact_check,buzz,transcript,memory,project,profile,interview,passive,page_next,page_prev}.svg`

These are intentional geometric placeholders — final art replaces them later with no code change.

- [ ] **Step 1: Create the 14 SVGs**

Use this script (run from project root):

```bash
mkdir -p assets/icons/helix
for name in helix listen glasses hud fact_check buzz transcript memory project profile interview passive page_next page_prev; do
  cat > "assets/icons/helix/${name}.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="9"/>
  <path d="M7 12 L12 7 L17 12 L12 17 Z"/>
</svg>
EOF
done
ls assets/icons/helix/
```
Expected: 14 `.svg` files listed.

- [ ] **Step 2: Remove placeholder `.gitkeep`**

```bash
git rm --cached assets/icons/helix/.gitkeep 2>/dev/null || true
rm -f assets/icons/helix/.gitkeep
```

- [ ] **Step 3: Verify analyze still clean**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 4: Commit**

```bash
git add assets/icons/helix/
git commit -m "feat(assets): add 14 placeholder Helix brand SVG icons"
```

---

### Task A6: `HelixIcons` enum + asset map

**Files:**
- Create: `lib/widgets/helix_icons.dart`

- [ ] **Step 1: Create `HelixIcons`**

Create `lib/widgets/helix_icons.dart`:

```dart
import 'package:flutter/cupertino.dart';

/// Identifier for either a hand-drawn brand icon (resolved to an SVG asset)
/// or a long-tail SF Symbol (resolved to a `CupertinoIcons` glyph).
enum HelixIcons {
  // --- Brand (SVG assets) ---
  helix,
  listen,
  glasses,
  hud,
  factCheck,
  buzz,
  transcript,
  memory,
  project,
  profile,
  interview,
  passive,
  pageNext,
  pagePrev,

  // --- Long tail (SF Symbols / Cupertino) ---
  search,
  settings,
  close,
  back,
  add,
}

extension HelixIconsResolution on HelixIcons {
  bool get isBrand {
    switch (this) {
      case HelixIcons.helix:
      case HelixIcons.listen:
      case HelixIcons.glasses:
      case HelixIcons.hud:
      case HelixIcons.factCheck:
      case HelixIcons.buzz:
      case HelixIcons.transcript:
      case HelixIcons.memory:
      case HelixIcons.project:
      case HelixIcons.profile:
      case HelixIcons.interview:
      case HelixIcons.passive:
      case HelixIcons.pageNext:
      case HelixIcons.pagePrev:
        return true;
      case HelixIcons.search:
      case HelixIcons.settings:
      case HelixIcons.close:
      case HelixIcons.back:
      case HelixIcons.add:
        return false;
    }
  }

  /// Asset path for brand icons. Throws if called on a non-brand entry.
  String get assetPath {
    assert(isBrand, 'assetPath only valid for brand icons');
    const map = {
      HelixIcons.helix: 'assets/icons/helix/helix.svg',
      HelixIcons.listen: 'assets/icons/helix/listen.svg',
      HelixIcons.glasses: 'assets/icons/helix/glasses.svg',
      HelixIcons.hud: 'assets/icons/helix/hud.svg',
      HelixIcons.factCheck: 'assets/icons/helix/fact_check.svg',
      HelixIcons.buzz: 'assets/icons/helix/buzz.svg',
      HelixIcons.transcript: 'assets/icons/helix/transcript.svg',
      HelixIcons.memory: 'assets/icons/helix/memory.svg',
      HelixIcons.project: 'assets/icons/helix/project.svg',
      HelixIcons.profile: 'assets/icons/helix/profile.svg',
      HelixIcons.interview: 'assets/icons/helix/interview.svg',
      HelixIcons.passive: 'assets/icons/helix/passive.svg',
      HelixIcons.pageNext: 'assets/icons/helix/page_next.svg',
      HelixIcons.pagePrev: 'assets/icons/helix/page_prev.svg',
    };
    return map[this]!;
  }

  /// Cupertino fallback icon for long-tail entries.
  IconData get cupertinoIcon {
    assert(!isBrand, 'cupertinoIcon only valid for non-brand icons');
    switch (this) {
      case HelixIcons.search:
        return CupertinoIcons.search;
      case HelixIcons.settings:
        return CupertinoIcons.settings;
      case HelixIcons.close:
        return CupertinoIcons.xmark;
      case HelixIcons.back:
        return CupertinoIcons.back;
      case HelixIcons.add:
        return CupertinoIcons.add;
      // ignore: no_default_cases
      default:
        throw StateError('Brand icon has no Cupertino fallback');
    }
  }

  String get defaultSemanticLabel {
    switch (this) {
      case HelixIcons.helix:
        return 'Helix';
      case HelixIcons.listen:
        return 'Listen';
      case HelixIcons.glasses:
        return 'Glasses';
      case HelixIcons.hud:
        return 'HUD';
      case HelixIcons.factCheck:
        return 'Fact check';
      case HelixIcons.buzz:
        return 'Buzz';
      case HelixIcons.transcript:
        return 'Transcript';
      case HelixIcons.memory:
        return 'Memory';
      case HelixIcons.project:
        return 'Project';
      case HelixIcons.profile:
        return 'Profile';
      case HelixIcons.interview:
        return 'Interview';
      case HelixIcons.passive:
        return 'Passive';
      case HelixIcons.pageNext:
        return 'Next page';
      case HelixIcons.pagePrev:
        return 'Previous page';
      case HelixIcons.search:
        return 'Search';
      case HelixIcons.settings:
        return 'Settings';
      case HelixIcons.close:
        return 'Close';
      case HelixIcons.back:
        return 'Back';
      case HelixIcons.add:
        return 'Add';
    }
  }
}
```

- [ ] **Step 2: Verify analyze**

```bash
flutter analyze
```
Expected: 0 errors.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/helix_icons.dart
git commit -m "feat(widgets): add HelixIcons enum + asset/Cupertino mapping"
```

---

### Task A7: `HelixIcon` widget

**Files:**
- Create: `lib/widgets/helix_icon.dart`
- Test: `test/widgets/helix_icon_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/helix_icon_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/widgets/helix_icon.dart';
import 'package:even_glasses/widgets/helix_icons.dart';

void main() {
  testWidgets('renders brand icon via SvgPicture', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HelixIcon(HelixIcons.listen)),
      ),
    );
    expect(find.byType(HelixIcon), findsOneWidget);
    // SvgPicture is the underlying widget for brand icons.
    expect(find.byKey(const ValueKey('helix-icon-svg')), findsOneWidget);
  });

  testWidgets('renders long-tail icon via Icon (CupertinoIcons)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: HelixIcon(HelixIcons.settings)),
      ),
    );
    expect(find.byKey(const ValueKey('helix-icon-cupertino')), findsOneWidget);
  });

  testWidgets('uses provided semanticLabel', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HelixIcon(HelixIcons.listen, semanticLabel: 'Start listening'),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Start listening'), findsOneWidget);
  });

  testWidgets('all enum values resolve without throwing', (tester) async {
    for (final icon in HelixIcons.values) {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: HelixIcon(icon))),
      );
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/helix_icon_test.dart
```
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement `HelixIcon`**

Create `lib/widgets/helix_icon.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'helix_icons.dart';

class HelixIcon extends StatelessWidget {
  const HelixIcon(
    this.icon, {
    super.key,
    this.size = 20,
    this.color,
    this.semanticLabel,
  });

  final HelixIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label = semanticLabel ?? icon.defaultSemanticLabel;
    final tint = color ?? IconTheme.of(context).color ?? Colors.white;

    if (icon.isBrand) {
      return Semantics(
        label: label,
        child: SvgPicture.asset(
          key: const ValueKey('helix-icon-svg'),
          icon.assetPath,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        ),
      );
    }

    return Icon(
      icon.cupertinoIcon,
      key: const ValueKey('helix-icon-cupertino'),
      size: size,
      color: tint,
      semanticLabel: label,
    );
  }
}
```

- [ ] **Step 4: Run test**

```bash
flutter test test/widgets/helix_icon_test.dart
```
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/helix_icon.dart test/widgets/helix_icon_test.dart
git commit -m "feat(widgets): add HelixIcon resolving brand SVG + Cupertino"
```

---

### Task A8: `LiveStatusPill` widget

**Files:**
- Create: `lib/widgets/live_status_pill.dart`
- Test: `test/widgets/live_status_pill_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/live_status_pill_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/widgets/live_status_pill.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders idle by default with default label', (tester) async {
    await tester.pumpWidget(host(const LiveStatusPill(status: LiveStatus.idle)));
    expect(find.text('Idle'), findsOneWidget);
  });

  testWidgets('renders listening with elapsed time', (tester) async {
    await tester.pumpWidget(host(const LiveStatusPill(
      status: LiveStatus.listening,
      elapsed: Duration(seconds: 42),
    )));
    expect(find.text('LIVE — 00:42'), findsOneWidget);
  });

  testWidgets('renders answering / error states with their default labels', (tester) async {
    await tester.pumpWidget(host(const LiveStatusPill(status: LiveStatus.answering)));
    expect(find.text('Answering'), findsOneWidget);

    await tester.pumpWidget(host(const LiveStatusPill(status: LiveStatus.error, label: 'Mic blocked')));
    expect(find.text('Mic blocked'), findsOneWidget);
  });

  testWidgets('cross-fades when status changes', (tester) async {
    await tester.pumpWidget(host(const LiveStatusPill(status: LiveStatus.idle)));
    await tester.pumpWidget(host(const LiveStatusPill(status: LiveStatus.listening)));
    await tester.pump(const Duration(milliseconds: 160));
    // Mid-cross-fade: an AnimatedSwitcher should be in the tree.
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('LIVE — 00:00'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/live_status_pill_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Implement `LiveStatusPill`**

Create `lib/widgets/live_status_pill.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/helix_motion.dart';
import '../theme/helix_theme.dart';

enum LiveStatus { idle, listening, answering, error }

class LiveStatusPill extends StatelessWidget {
  const LiveStatusPill({
    super.key,
    required this.status,
    this.label,
    this.elapsed,
  });

  final LiveStatus status;
  final String? label;
  final Duration? elapsed;

  @override
  Widget build(BuildContext context) {
    final spec = _spec(status);
    final text = _resolveLabel(spec);

    final pill = Container(
      key: ValueKey<LiveStatus>(status),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(color: spec.color, status: status),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: spec.color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: _semanticLabel(text),
      child: AnimatedSize(
        duration: HelixMotion.standard,
        curve: HelixMotion.standardCurve,
        child: AnimatedSwitcher(
          duration: HelixMotion.standard,
          switchInCurve: HelixMotion.standardCurve,
          switchOutCurve: HelixMotion.standardCurve,
          child: pill,
        ),
      ),
    );
  }

  String _resolveLabel(_StatusSpec spec) {
    if (label != null) return label!;
    if (status == LiveStatus.listening && elapsed != null) {
      final mm = elapsed!.inMinutes.remainder(60).toString().padLeft(2, '0');
      final ss = elapsed!.inSeconds.remainder(60).toString().padLeft(2, '0');
      return 'LIVE — $mm:$ss';
    }
    return spec.defaultLabel;
  }

  String _semanticLabel(String text) {
    if (status == LiveStatus.listening && elapsed != null) {
      return 'Listening, ${elapsed!.inSeconds} seconds elapsed';
    }
    return text;
  }

  static _StatusSpec _spec(LiveStatus s) {
    switch (s) {
      case LiveStatus.idle:
        return _StatusSpec(HelixTheme.textSecondary, 'Idle');
      case LiveStatus.listening:
        return _StatusSpec(HelixTheme.cyan, 'LIVE');
      case LiveStatus.answering:
        return _StatusSpec(HelixTheme.lime, 'Answering');
      case LiveStatus.error:
        return _StatusSpec(HelixTheme.error, 'Error');
    }
  }
}

class _StatusSpec {
  const _StatusSpec(this.color, this.defaultLabel);
  final Color color;
  final String defaultLabel;
}

class _Dot extends StatefulWidget {
  const _Dot({required this.color, required this.status});
  final Color color;
  final LiveStatus status;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: _durationFor(widget.status),
  );

  @override
  void initState() {
    super.initState();
    if (_animatesFor(widget.status)) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _Dot old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) {
      _ctrl.duration = _durationFor(widget.status);
      if (_animatesFor(widget.status)) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
        _ctrl.value = 1.0;
      }
    }
  }

  bool _animatesFor(LiveStatus s) =>
      s == LiveStatus.listening || s == LiveStatus.answering;

  Duration _durationFor(LiveStatus s) =>
      s == LiveStatus.answering
          ? const Duration(milliseconds: 800)
          : const Duration(milliseconds: 1200);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return _dot(1.0);
    }
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _animatesFor(widget.status)
            ? 0.6 + 0.4 * _ctrl.value
            : 1.0;
        return _dot(t);
      },
    );
  }

  Widget _dot(double alpha) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: alpha),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5 * alpha),
              blurRadius: 8,
            ),
          ],
        ),
      );
}
```

- [ ] **Step 4: Run test**

```bash
flutter test test/widgets/live_status_pill_test.dart
```
Expected: PASS, 4 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/live_status_pill.dart test/widgets/live_status_pill_test.dart
git commit -m "feat(widgets): add LiveStatusPill with state-aware dot animation"
```

---

### Task A9: `LivingPanel` widget

**Files:**
- Create: `lib/widgets/living_panel.dart`
- Test: `test/widgets/living_panel_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/living_panel_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/widgets/living_panel.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders child', (tester) async {
    await tester.pumpWidget(host(const LivingPanel(child: Text('hi'))));
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('honors disableAnimations: glow is static', (tester) async {
    await tester.pumpWidget(host(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: LivingPanel(isActive: true, child: SizedBox(height: 40)),
      ),
    ));
    // Pump twice; the active border decoration should be the same identity-wise.
    final first = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration;
    await tester.pump(const Duration(milliseconds: 700));
    final second = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration;
    expect(first, equals(second));
  });

  testWidgets('isActive=false renders without throwing', (tester) async {
    await tester.pumpWidget(host(
      const LivingPanel(isActive: false, child: SizedBox(height: 40)),
    ));
    expect(find.byType(LivingPanel), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/living_panel_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Implement `LivingPanel`**

Create `lib/widgets/living_panel.dart`:

```dart
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/helix_glow.dart';
import '../theme/helix_motion.dart';
import '../theme/helix_theme.dart';

class LivingPanel extends StatefulWidget {
  const LivingPanel({
    super.key,
    required this.child,
    this.emphasis = 0.3,
    this.isActive = false,
    this.padding,
    this.borderRadius,
  });

  final Widget child;
  final double emphasis;
  final bool isActive;
  final EdgeInsets? padding;
  final double? borderRadius;

  @override
  State<LivingPanel> createState() => _LivingPanelState();
}

class _LivingPanelState extends State<LivingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: HelixMotion.ambient,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations;
    final radius = widget.borderRadius ?? 20.0;
    final fill = HelixTheme.panelFill(widget.emphasis.clamp(0.0, 1.0));
    final stroke = HelixTheme.panelBorder(widget.emphasis.clamp(0.0, 1.0));
    final padding = widget.padding ?? const EdgeInsets.all(18);

    Widget surface(double driftDx, double pulseT) {
      final shadows = widget.isActive ? HelixGlow.pulseAt(pulseT) : HelixGlow.subtle;
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Stack(
            children: [
              // Base glass fill
              DecoratedBox(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: stroke),
                  boxShadow: shadows,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(padding: padding, child: widget.child),
                ),
              ),
              // Quiet glass drift overlay
              IgnorePointer(
                child: Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(driftDx, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            HelixTheme.cyan.withValues(alpha: 0.04),
                            HelixTheme.cyan.withValues(alpha: 0.0),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (disable) {
      return surface(0, 0.5);
    }

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = HelixMotion.ambientCurve.transform(_ctrl.value);
        final driftDx = -8 + (16 * t);
        return surface(driftDx, t);
      },
    );
  }
}
```

- [ ] **Step 4: Run test**

```bash
flutter test test/widgets/living_panel_test.dart
```
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/living_panel.dart test/widgets/living_panel_test.dart
git commit -m "feat(widgets): add LivingPanel with ambient drift + active glow"
```

---

### Task A10: `BreathingChip` widget

**Files:**
- Create: `lib/widgets/breathing_chip.dart`
- Test: `test/widgets/breathing_chip_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/breathing_chip_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/widgets/breathing_chip.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders label and is tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      BreathingChip(label: 'Hi', onTap: () => taps++),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hi'));
    expect(taps, 1);
  });

  testWidgets('selected state is reflected visually (no breathe loop)', (tester) async {
    await tester.pumpWidget(host(
      BreathingChip(label: 'A', isSelected: true, onTap: () {}),
    ));
    await tester.pumpAndSettle(); // settles entrance
    expect(find.byType(BreathingChip), findsOneWidget);
  });

  testWidgets('disableAnimations short-circuits entrance', (tester) async {
    await tester.pumpWidget(host(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: BreathingChip(label: 'A'),
      ),
    ));
    // No need to pumpAndSettle; should already be at final scale.
    expect(find.text('A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/breathing_chip_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Implement `BreathingChip`**

Create `lib/widgets/breathing_chip.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/helix_glow.dart';
import '../theme/helix_motion.dart';
import '../theme/helix_theme.dart';

enum BreathingChipTone { cyan, purple, lime, amber }

class BreathingChip extends StatefulWidget {
  const BreathingChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.tone = BreathingChipTone.cyan,
    this.isSelected = false,
    this.entranceIndex,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final BreathingChipTone tone;
  final bool isSelected;
  final int? entranceIndex;

  @override
  State<BreathingChip> createState() => _BreathingChipState();
}

class _BreathingChipState extends State<BreathingChip>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: HelixMotion.standard,
  );
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4000),
  );

  @override
  void initState() {
    super.initState();
    final delayIdx = (widget.entranceIndex ?? 0).clamp(0, 6);
    Future<void>.delayed(Duration(milliseconds: 60 * delayIdx), () {
      if (!mounted) return;
      _entrance.forward();
    });
    if (!widget.isSelected) {
      _breathe.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant BreathingChip old) {
    super.didUpdateWidget(old);
    if (old.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _breathe.stop();
      } else {
        _breathe.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _entrance.dispose();
    _breathe.dispose();
    super.dispose();
  }

  Color _toneColor() {
    switch (widget.tone) {
      case BreathingChipTone.cyan:
        return HelixTheme.cyan;
      case BreathingChipTone.purple:
        return HelixTheme.purple;
      case BreathingChipTone.lime:
        return HelixTheme.lime;
      case BreathingChipTone.amber:
        return HelixTheme.amber;
    }
  }

  @override
  Widget build(BuildContext context) {
    final disable = MediaQuery.of(context).disableAnimations;
    final tone = _toneColor();

    if (disable) {
      _entrance.value = 1.0;
      _breathe.stop();
    }

    Widget chipBody(double breatheAlpha) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12 * breatheAlpha),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.withValues(alpha: 0.4 * breatheAlpha)),
          boxShadow: widget.isSelected ? HelixGlow.pulseAt(0.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 14, color: tone),
              const SizedBox(width: 6),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: tone,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_entrance, _breathe]),
      builder: (context, _) {
        final entranceT = HelixMotion.standardCurve.transform(_entrance.value);
        final scale = 0.92 + 0.08 * entranceT;
        final opacity = entranceT;
        final breatheAlpha = widget.isSelected
            ? 1.0
            : 0.92 + 0.08 * HelixMotion.ambientCurve.transform(_breathe.value);

        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: scale,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: widget.onTap,
                child: chipBody(breatheAlpha),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test**

```bash
flutter test test/widgets/breathing_chip_test.dart
```
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/breathing_chip.dart test/widgets/breathing_chip_test.dart
git commit -m "feat(widgets): add BreathingChip with entrance + breathe loop"
```

---

### Task A11: `LiveWaveform` widget

**Files:**
- Create: `lib/widgets/live_waveform.dart`
- Test: `test/widgets/live_waveform_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/live_waveform_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/widgets/live_waveform.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: SizedBox(width: 320, height: 80, child: child)));

  testWidgets('renders without a stream (idle state)', (tester) async {
    await tester.pumpWidget(host(const LiveWaveform()));
    await tester.pump();
    expect(find.byType(LiveWaveform), findsOneWidget);
  });

  testWidgets('updates from injected stream', (tester) async {
    final ctrl = StreamController<double>.broadcast();
    await tester.pumpWidget(host(LiveWaveform(rmsStream: ctrl.stream)));
    await tester.pump();
    ctrl.add(0.5);
    await tester.pump(const Duration(milliseconds: 50));
    ctrl.add(0.8);
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LiveWaveform), findsOneWidget);
    await ctrl.close();
  });

  testWidgets('clamps and ignores out-of-range values silently', (tester) async {
    final ctrl = StreamController<double>.broadcast();
    await tester.pumpWidget(host(LiveWaveform(rmsStream: ctrl.stream)));
    await tester.pump();
    ctrl.add(-1.0);
    ctrl.add(2.0);
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await ctrl.close();
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/live_waveform_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Implement `LiveWaveform`**

Create `lib/widgets/live_waveform.dart`:

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/helix_gradients.dart';
import '../theme/helix_theme.dart';

class LiveWaveform extends StatefulWidget {
  const LiveWaveform({
    super.key,
    this.rmsStream,
    this.barCount = 28,
    this.barGradient,
  });

  final Stream<double>? rmsStream;
  final int barCount;
  final Gradient? barGradient;

  @override
  State<LiveWaveform> createState() => _LiveWaveformState();
}

class _LiveWaveformState extends State<LiveWaveform>
    with SingleTickerProviderStateMixin {
  StreamSubscription<double>? _sub;
  late final List<double> _targets = List.filled(widget.barCount, 0.05);
  late final List<double> _displayed = List.filled(widget.barCount, 0.05);
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Duration _lastEmit = Duration.zero;
  static const Duration _tickInterval = Duration(milliseconds: 33);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _subscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    final s = widget.rmsStream;
    if (s == null) return;
    _sub = s.listen((raw) {
      final v = raw.isNaN ? 0.0 : raw.clamp(0.0, 1.0).toDouble();
      // Shift bars left, push new value at the end.
      for (var i = 0; i < _targets.length - 1; i++) {
        _targets[i] = _targets[i + 1];
      }
      _targets[_targets.length - 1] = math.max(0.05, v);
    }, onError: (_) {});
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastTick < _tickInterval) return;
    _lastTick = elapsed;
    var changed = false;
    for (var i = 0; i < _displayed.length; i++) {
      final next = _displayed[i] + (_targets[i] - _displayed[i]) * 0.35;
      if ((next - _displayed[i]).abs() > 0.001) {
        _displayed[i] = next;
        changed = true;
      }
    }
    if (changed) {
      _frame.value = _frame.value + 1;
    }
  }

  @override
  void didUpdateWidget(covariant LiveWaveform old) {
    super.didUpdateWidget(old);
    if (old.rmsStream != widget.rmsStream) {
      _subscribe();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _sub?.cancel();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WaveformPainter(
            heights: _displayed,
            gradient: widget.barGradient ?? HelixGradients.liveSignal,
            repaint: _frame,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.heights,
    required this.gradient,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final List<double> heights;
  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final n = heights.length;
    if (n == 0) return;
    final gap = 4.0;
    final totalGap = gap * (n - 1);
    final barWidth = (size.width - totalGap) / n;

    for (var i = 0; i < n; i++) {
      final h = heights[i] * size.height;
      final left = i * (barWidth + gap);
      final top = size.height - h;
      final rect = Rect.fromLTWH(left, top, barWidth, h);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..isAntiAlias = true;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        paint,
      );
      // Glow
      final glowPaint = Paint()
        ..color = HelixTheme.cyan.withValues(alpha: 0.18 * heights[i])
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) => false;
}
```

- [ ] **Step 4: Run test**

```bash
flutter test test/widgets/live_waveform_test.dart
```
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/live_waveform.dart test/widgets/live_waveform_test.dart
git commit -m "feat(widgets): add LiveWaveform painter with 30Hz tick + smoothing"
```

---

### Task A12: `HomeHeroCard` widget

**Files:**
- Create: `lib/widgets/home/home_hero_card.dart`
- Test: `test/widgets/home_hero_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/home_hero_card_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/widgets/home/home_hero_card.dart';
import 'package:even_glasses/widgets/live_status_pill.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders idle status by default', (tester) async {
    await tester.pumpWidget(host(
      HomeHeroCard(
        statusStream: const Stream<LiveStatus>.empty(),
        rmsStream: const Stream<double>.empty(),
        contextSummary: 'Project: Q2 · Profile: Maya',
        onPrimaryTap: () {},
        primaryLabel: 'Start',
      ),
    ));
    await tester.pump();
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Project: Q2 · Profile: Maya'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('reflects status from stream', (tester) async {
    final status = StreamController<LiveStatus>.broadcast();
    await tester.pumpWidget(host(
      HomeHeroCard(
        statusStream: status.stream,
        rmsStream: const Stream<double>.empty(),
        contextSummary: '',
        onPrimaryTap: () {},
        primaryLabel: 'Start',
      ),
    ));
    status.add(LiveStatus.listening);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('LIVE'), findsOneWidget);
    await status.close();
  });

  testWidgets('primary tap fires callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
      HomeHeroCard(
        statusStream: const Stream<LiveStatus>.empty(),
        rmsStream: const Stream<double>.empty(),
        contextSummary: '',
        onPrimaryTap: () => taps++,
        primaryLabel: 'Start',
      ),
    ));
    await tester.pump();
    await tester.tap(find.text('Start'));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/home_hero_card_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Implement `HomeHeroCard`**

Create `lib/widgets/home/home_hero_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/helix_theme.dart';
import '../glow_button.dart';
import '../helix_icon.dart';
import '../helix_icons.dart';
import '../live_status_pill.dart';
import '../live_waveform.dart';
import '../living_panel.dart';

class HomeHeroCard extends StatelessWidget {
  const HomeHeroCard({
    super.key,
    required this.statusStream,
    required this.rmsStream,
    required this.contextSummary,
    required this.onPrimaryTap,
    required this.primaryLabel,
    this.elapsedStream,
    this.onSecondaryTap,
  });

  final Stream<LiveStatus> statusStream;
  final Stream<double> rmsStream;
  final Stream<Duration>? elapsedStream;
  final String contextSummary;
  final VoidCallback onPrimaryTap;
  final String primaryLabel;
  final VoidCallback? onSecondaryTap;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LiveStatus>(
      stream: statusStream,
      initialData: LiveStatus.idle,
      builder: (context, statusSnap) {
        final status = statusSnap.data ?? LiveStatus.idle;
        final isLive = status == LiveStatus.listening;
        return LivingPanel(
          isActive: isLive || status == LiveStatus.answering,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StreamBuilder<Duration>(
                    stream: elapsedStream,
                    builder: (context, elSnap) => LiveStatusPill(
                      status: status,
                      elapsed: isLive ? elSnap.data : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 80,
                child: LiveWaveform(rmsStream: rmsStream),
              ),
              const SizedBox(height: 14),
              if (contextSummary.isNotEmpty)
                Text(
                  contextSummary,
                  style: const TextStyle(
                    color: HelixTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: GlowButton(
                      label: primaryLabel,
                      icon: null,
                      onPressed: onPrimaryTap,
                    ),
                  ),
                  if (onSecondaryTap != null) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: onSecondaryTap,
                      icon: const HelixIcon(HelixIcons.glasses, size: 22),
                      style: IconButton.styleFrom(
                        backgroundColor:
                            HelixTheme.surfaceInteractive.withValues(alpha: 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test**

```bash
flutter test test/widgets/home_hero_card_test.dart
```
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/home/home_hero_card.dart test/widgets/home_hero_card_test.dart
git commit -m "feat(widgets): add HomeHeroCard composing LivingPanel + waveform"
```

---

### Task A13: Wire `HomeHeroCard` into `home_screen.dart`

**Files:**
- Modify: `lib/screens/home_screen.dart` — replace the body of `_buildOverviewCard()` (around line 577).

This task only swaps the *contents* of the existing builder; it does not delete supporting code or change any other method.

- [ ] **Step 1: Inspect the current `_buildOverviewCard` to determine what data it has access to**

```bash
grep -nE "_buildOverviewCard|conversationEngine|ConversationEngine\\.instance|MicLevelService|elapsedStream|sessionTimerStream" lib/screens/home_screen.dart | head -30
```
Note the local variables / state fields the method has access to (status stream source, primary action callback, current label).

- [ ] **Step 2: Add imports at the top of `home_screen.dart`**

Find the existing `import` block and add:

```dart
import '../services/mic_level_service.dart';
import '../widgets/home/home_hero_card.dart';
import '../widgets/live_status_pill.dart';
```

- [ ] **Step 3: Add a status-mapping helper**

Inside `_HomeScreenState`, just below the field declarations, add:

```dart
  Stream<LiveStatus> _liveStatusStream() {
    // Maps existing engine state into the pill's enum.
    return ConversationEngine.instance.statusStream.map((s) {
      // The exact engine status field names are referenced from the code path
      // above. Treat any "listening" state as listening, any "answering"/
      // "responding" as answering, error states as error, otherwise idle.
      final str = s.toString().toLowerCase();
      if (str.contains('error')) return LiveStatus.error;
      if (str.contains('listen') || str.contains('record')) return LiveStatus.listening;
      if (str.contains('answer') || str.contains('respond') || str.contains('stream')) {
        return LiveStatus.answering;
      }
      return LiveStatus.idle;
    });
  }
```

> If `ConversationEngine.instance.statusStream` is not the actual stream name, replace with the equivalent identified in Step 1.

- [ ] **Step 4: Replace the body of `_buildOverviewCard()`**

Find `_buildOverviewCard()` and replace **only its body** (everything between the opening `{` and closing `}`) with:

```dart
    return HomeHeroCard(
      statusStream: _liveStatusStream(),
      rmsStream: MicLevelService.instance.rmsStream,
      contextSummary: _activeContextSummary(),
      primaryLabel: _primarySessionLabel(),
      onPrimaryTap: _onPrimarySessionPressed,
      onSecondaryTap: _onSwitchModePressed,
    );
```

If any of `_activeContextSummary`, `_primarySessionLabel`, `_onPrimarySessionPressed`, or `_onSwitchModePressed` does not already exist on `_HomeScreenState`, scroll the file (`grep -n` from Step 1 should reveal equivalents) and substitute the closest existing identifier. Do not create new state methods in this task — wire to existing ones.

- [ ] **Step 5: Run analyze + tests**

```bash
flutter analyze
flutter test test/
```
Expected: 0 errors. All existing tests still pass.

- [ ] **Step 6: Smoke test on simulator**

(Per `CLAUDE.md`, boot a dedicated simulator instance.)

```bash
flutter run -d <sim-id>
```
Open the app, observe Home tab, verify:
- Hero card replaces the old overview area.
- Status pill reads "Idle" before tap; updates when listening starts.
- Waveform animates while listening (mic permission prompt accepted).
- Primary button still triggers the original session action.

- [ ] **Step 7: Run full validation gate**

`home_screen.dart` is not in the "FULL gate" trigger list, but it is a high-traffic file. Run:

```bash
bash scripts/run_gate.sh
```
Expected: gate passes.

- [ ] **Step 8: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(home): wire HomeHeroCard into _buildOverviewCard"
```

---

## Phase B — Home polish

Goal: migrate Home's chip rows and adjacent icons to the new primitives.

### Task B1: Mode selector → `BreathingChip`

**Files:**
- Modify: `lib/screens/home_screen.dart` — `_buildModeSelector` (around line 824).

- [ ] **Step 1: Add import**

If not already imported, add:

```dart
import '../widgets/breathing_chip.dart';
```

- [ ] **Step 2: Locate the existing mode-button construction inside `_buildModeSelector`**

```bash
grep -n "_buildModeSelector\|conversationMode\|ConversationMode\\." lib/screens/home_screen.dart | head -20
```
Identify the three mode entries (`general`, `interview`, `passive`).

- [ ] **Step 3: Replace each mode button with a `BreathingChip`**

Inside `_buildModeSelector`, replace each existing chip/button with:

```dart
BreathingChip(
  label: 'General',
  isSelected: _currentMode == ConversationMode.general,
  tone: BreathingChipTone.cyan,
  entranceIndex: 0,
  onTap: () => _selectMode(ConversationMode.general),
),
BreathingChip(
  label: 'Interview',
  isSelected: _currentMode == ConversationMode.interview,
  tone: BreathingChipTone.purple,
  entranceIndex: 1,
  onTap: () => _selectMode(ConversationMode.interview),
),
BreathingChip(
  label: 'Passive',
  isSelected: _currentMode == ConversationMode.passive,
  tone: BreathingChipTone.lime,
  entranceIndex: 2,
  onTap: () => _selectMode(ConversationMode.passive),
),
```

(Substitute existing identifiers if `_currentMode`/`_selectMode` are named differently.)

- [ ] **Step 4: Analyze + test**

```bash
flutter analyze
flutter test test/
```

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat(home): mode selector uses BreathingChip"
```

---

### Task B2: Follow-up + suggestion chip rows → `BreathingChip`

**Files:**
- Modify: `lib/screens/home_screen.dart` — `_buildFollowUpChipDeck` (~line 2414), `_buildSuggestionChips` (~line 3214).

- [ ] **Step 1: Replace each chip in `_buildFollowUpChipDeck`**

Find the per-chip construction (likely an `ActionChip` or similar). Replace with:

```dart
BreathingChip(
  label: chip.label,
  tone: BreathingChipTone.cyan,
  entranceIndex: index,
  onTap: () => _onFollowUpChipTap(chip),
),
```

(Substitute `chip.label`, `index`, and the tap callback to match existing identifiers.)

- [ ] **Step 2: Repeat for `_buildSuggestionChips`** — use `BreathingChipTone.cyan`.

- [ ] **Step 3: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/home_screen.dart
git commit -m "feat(home): follow-up + suggestion chips use BreathingChip"
```

---

### Task B3: Replace hero-region Material icons with `HelixIcon`

**Files:**
- Modify: `lib/screens/home_screen.dart` — `_buildGlassesDeliveryCard` (~3117), `_buildCitedFactCheckDisclosure` (~2273).

- [ ] **Step 1: Add import**

```dart
import '../widgets/helix_icon.dart';
import '../widgets/helix_icons.dart';
```

- [ ] **Step 2: In `_buildGlassesDeliveryCard`, replace the leading icon**

Replace the existing `Icon(Icons.something_glasses, ...)` with:

```dart
const HelixIcon(HelixIcons.glasses, size: 22)
```

- [ ] **Step 3: In `_buildCitedFactCheckDisclosure`, replace the leading icon**

Replace the existing leading icon (likely `Icons.fact_check` or similar) with:

```dart
const HelixIcon(HelixIcons.factCheck, size: 22)
```

- [ ] **Step 4: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/home_screen.dart
git commit -m "feat(home): hero-region icons use HelixIcon (glasses, factCheck)"
```

---

## Phase C — Glasses screen overhaul

### Task C1: `BleManager.connectedAt` field

**Files:**
- Modify: `lib/ble_manager.dart`
- Test: `test/ble_manager_connected_at_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ble_manager_connected_at_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/ble_manager.dart';

void main() {
  test('connectedAt is set when connection state becomes connected', () {
    final mgr = BleManager.get();
    mgr.debugSetConnectionState(leftConnected: true, rightConnected: true);
    expect(mgr.connectedAt, isNotNull);

    mgr.debugSetConnectionState(leftConnected: false, rightConnected: false);
    expect(mgr.connectedAt, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/ble_manager_connected_at_test.dart
```
Expected: FAIL with `connectedAt` undefined.

- [ ] **Step 3: Add `connectedAt` to `BleManager`**

In `lib/ble_manager.dart`, just below the `BleConnectionState _connectionState = ...` line (around line 49), add:

```dart
  DateTime? connectedAt;
```

In `_updateConnectionState`, set/clear it:

```dart
  void _updateConnectionState(BleConnectionState state) {
    _connectionState = state;
    if (state == BleConnectionState.connected) {
      connectedAt ??= DateTime.now();
    } else if (state == BleConnectionState.disconnected) {
      connectedAt = null;
    }
    _connectionStateController.add(state);
  }
```

- [ ] **Step 4: Run test**

```bash
flutter test test/ble_manager_connected_at_test.dart
```
Expected: PASS.

- [ ] **Step 5: Run full gate (per `CLAUDE.md` — `ble_manager.dart` impacts core flows; play it safe)**

```bash
bash scripts/run_gate.sh
```

- [ ] **Step 6: Commit**

```bash
git add lib/ble_manager.dart test/ble_manager_connected_at_test.dart
git commit -m "feat(ble): track BleManager.connectedAt timestamp"
```

---

### Task C2: `GlassesHeroCard` widget

**Files:**
- Create: `lib/widgets/glasses/glasses_hero_card.dart`
- Test: `test/widgets/glasses_hero_card_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/widgets/glasses_hero_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:even_glasses/services/ble.dart';
import 'package:even_glasses/widgets/glasses/glasses_hero_card.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('renders disconnected state', (tester) async {
    await tester.pumpWidget(host(
      GlassesHeroCard(
        leftState: BleConnectionState.disconnected,
        rightState: BleConnectionState.disconnected,
        leftBatteryPct: null,
        rightBatteryPct: null,
        connectedAt: null,
        primaryLabel: 'Pair Glasses',
        onPrimaryTap: () {},
      ),
    ));
    await tester.pump();
    expect(find.text('Pair Glasses'), findsOneWidget);
  });

  testWidgets('shows battery when connected', (tester) async {
    await tester.pumpWidget(host(
      GlassesHeroCard(
        leftState: BleConnectionState.connected,
        rightState: BleConnectionState.connected,
        leftBatteryPct: 78,
        rightBatteryPct: 81,
        connectedAt: DateTime.now(),
        primaryLabel: 'Disconnect',
        onPrimaryTap: () {},
      ),
    ));
    await tester.pump();
    expect(find.text('78%'), findsOneWidget);
    expect(find.text('81%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
flutter test test/widgets/glasses_hero_card_test.dart
```
Expected: FAIL.

- [ ] **Step 3: Implement `GlassesHeroCard`**

Create `lib/widgets/glasses/glasses_hero_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../services/ble.dart';
import '../../theme/helix_theme.dart';
import '../glow_button.dart';
import '../helix_icon.dart';
import '../helix_icons.dart';
import '../live_status_pill.dart';
import '../living_panel.dart';

class GlassesHeroCard extends StatelessWidget {
  const GlassesHeroCard({
    super.key,
    required this.leftState,
    required this.rightState,
    required this.leftBatteryPct,
    required this.rightBatteryPct,
    required this.connectedAt,
    required this.primaryLabel,
    required this.onPrimaryTap,
  });

  final BleConnectionState leftState;
  final BleConnectionState rightState;
  final int? leftBatteryPct;
  final int? rightBatteryPct;
  final DateTime? connectedAt;
  final String primaryLabel;
  final VoidCallback onPrimaryTap;

  Color _dotColor(BleConnectionState s) {
    switch (s) {
      case BleConnectionState.connected:
        return HelixTheme.lime;
      case BleConnectionState.scanning:
      case BleConnectionState.connecting:
      case BleConnectionState.reconnecting:
        return HelixTheme.amber;
      case BleConnectionState.disconnected:
        return HelixTheme.error;
    }
  }

  LiveStatus _overallStatus() {
    final connected = leftState == BleConnectionState.connected &&
        rightState == BleConnectionState.connected;
    final any = leftState == BleConnectionState.connected ||
        rightState == BleConnectionState.connected;
    if (connected) return LiveStatus.listening;
    if (any) return LiveStatus.answering;
    return LiveStatus.idle;
  }

  Duration? _uptime() {
    if (connectedAt == null) return null;
    return DateTime.now().difference(connectedAt!);
  }

  @override
  Widget build(BuildContext context) {
    return LivingPanel(
      isActive: _overallStatus() != LiveStatus.idle,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.07,
                child: HelixIcon(
                  HelixIcons.glasses,
                  size: 120,
                  color: HelixTheme.cyan,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _LRDot(color: _dotColor(leftState), label: 'L', battery: leftBatteryPct),
                  Container(
                    width: 80,
                    height: 2,
                    color: HelixTheme.cyan.withValues(
                      alpha: leftState == BleConnectionState.connected &&
                              rightState == BleConnectionState.connected
                          ? 0.8
                          : 0.2,
                    ),
                  ),
                  _LRDot(color: _dotColor(rightState), label: 'R', battery: rightBatteryPct),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          LiveStatusPill(status: _overallStatus(), elapsed: _uptime()),
          const SizedBox(height: 14),
          GlowButton(label: primaryLabel, onPressed: onPrimaryTap),
        ],
      ),
    );
  }
}

class _LRDot extends StatelessWidget {
  const _LRDot({required this.color, required this.label, required this.battery});
  final Color color;
  final String label;
  final int? battery;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 16),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (battery != null)
          Text(
            '$battery%',
            style: const TextStyle(
              color: HelixTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test**

```bash
flutter test test/widgets/glasses_hero_card_test.dart
```
Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/glasses/glasses_hero_card.dart test/widgets/glasses_hero_card_test.dart
git commit -m "feat(widgets): add GlassesHeroCard with L/R dots + uptime pill"
```

---

### Task C3: Wire `GlassesHeroCard` into `g1_test_screen.dart`

**Files:**
- Modify: `lib/screens/g1_test_screen.dart` — `_buildHeroCard` (~line 127).

- [ ] **Step 1: Add imports**

```dart
import '../widgets/glasses/glasses_hero_card.dart';
```

- [ ] **Step 2: Replace the body of `_buildHeroCard()`**

Replace the body with:

```dart
    return StreamBuilder<BleConnectionState>(
      stream: BleManager.get().connectionStateStream,
      initialData: BleManager.get().connectionState,
      builder: (context, snap) {
        final overall = snap.data ?? BleConnectionState.disconnected;
        // For Phase C we treat L and R as in the same state until a per-side
        // stream is exposed (out of scope here).
        return GlassesHeroCard(
          leftState: overall,
          rightState: overall,
          leftBatteryPct: _leftBatteryPct,
          rightBatteryPct: _rightBatteryPct,
          connectedAt: BleManager.get().connectedAt,
          primaryLabel: _heroPrimaryLabel(overall),
          onPrimaryTap: _onHeroPrimaryTap,
        );
      },
    );
```

If `_leftBatteryPct`/`_rightBatteryPct`/`_heroPrimaryLabel`/`_onHeroPrimaryTap` are not pre-existing on the State class, add minimal placeholders inline (e.g., `_leftBatteryPct = null`) — do not invent new battery streams in this task.

- [ ] **Step 3: Analyze + test + smoke**

```bash
flutter analyze
flutter test test/
flutter run -d <sim-id>   # verify Glasses tab renders new hero
```

- [ ] **Step 4: Commit**

```bash
git add lib/screens/g1_test_screen.dart
git commit -m "feat(glasses): wire GlassesHeroCard into _buildHeroCard"
```

---

### Task C4: Telemetry card → `LivingPanel` + Helix icons + uptime ticker

**Files:**
- Modify: `lib/screens/g1_test_screen.dart` — `_buildTelemetryCard` (~line 598).

- [ ] **Step 1: Replace the outer `GlassCard` with `LivingPanel` and swap row icons**

Replace the body of `_buildTelemetryCard()` with:

```dart
    return LivingPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(tr('SYSTEM SNAPSHOT', '系统快照')),
          const SizedBox(height: 14),
          _buildHelixInfoRow(
            HelixIcons.glasses,
            tr('Battery path', '电池路径'),
            tr('Connected', '已连接'),
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildHelixInfoRow(
            HelixIcons.transcript,
            tr('BLE channel', 'BLE 通道'),
            tr('Active', '活跃'),
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildHelixInfoRow(
            HelixIcons.listen,
            tr('Microphone route', '麦克风路由'),
            tr('Ready', '就绪'),
          ),
          const Divider(color: Colors.white12, height: 24),
          StreamBuilder<int>(
            stream: Stream<int>.periodic(
              const Duration(seconds: 1),
              (i) => i,
            ),
            builder: (context, _) {
              final connectedAt = BleManager.get().connectedAt;
              final uptime = connectedAt == null
                  ? '—'
                  : _formatUptime(DateTime.now().difference(connectedAt));
              return _buildHelixInfoRow(
                HelixIcons.helix,
                tr('Link uptime', '连接时长'),
                uptime,
              );
            },
          ),
        ],
      ),
    );
```

- [ ] **Step 2: Add `_buildHelixInfoRow` and `_formatUptime` helpers** (just below `_buildInfoRow`):

```dart
  Widget _buildHelixInfoRow(HelixIcons icon, String label, String value) {
    return Row(
      children: [
        HelixIcon(icon, size: 18, color: HelixTheme.cyan),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                color: HelixTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              )),
        ),
        Text(value,
            style: const TextStyle(
              color: HelixTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }

  static String _formatUptime(Duration d) {
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
```

- [ ] **Step 3: Add imports** (if not already present):

```dart
import '../widgets/helix_icon.dart';
import '../widgets/helix_icons.dart';
import '../widgets/living_panel.dart';
```

- [ ] **Step 4: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/g1_test_screen.dart
git commit -m "feat(glasses): telemetry card uses LivingPanel + uptime ticker"
```

---

### Task C5: Connection-workflow steps → `BreathingChip` row

**Files:**
- Modify: `lib/screens/g1_test_screen.dart` — `_buildConnectionWorkflow` (~line 366).

- [ ] **Step 1: Replace each workflow step with a `BreathingChip`**

Inside `_buildConnectionWorkflow`, replace whatever step widgets exist with a horizontal `Wrap` of:

```dart
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    BreathingChip(
      label: tr('Turn on glasses', '打开眼镜'),
      tone: BreathingChipTone.cyan,
      isSelected: _workflowStep == 0,
      entranceIndex: 0,
      onTap: null,
    ),
    BreathingChip(
      label: tr('Open case', '打开盒子'),
      tone: BreathingChipTone.cyan,
      isSelected: _workflowStep == 1,
      entranceIndex: 1,
      onTap: null,
    ),
    BreathingChip(
      label: tr('Scan', '扫描'),
      tone: BreathingChipTone.cyan,
      isSelected: _workflowStep == 2,
      entranceIndex: 2,
      onTap: null,
    ),
  ],
)
```

If `_workflowStep` does not exist, replace with `false` for now (visual upgrade only; behavior wiring is out of scope).

- [ ] **Step 2: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/g1_test_screen.dart
git commit -m "feat(glasses): connection workflow uses BreathingChip stepper"
```

---

### Task C6: Active paired device → `LivingPanel`

**Files:**
- Modify: `lib/screens/g1_test_screen.dart` — `_buildGlassesCard` (~line 526).

- [ ] **Step 1: Wrap the active card in `LivingPanel`**

`_buildGlassesCard` takes the glasses map. Add a parameter `bool isActive = false` (or detect via `glasses['active'] == 'true'`). Wrap the existing card body so:
- If `isActive` → use `LivingPanel(isActive: true, ...)` instead of `GlassCard`.
- Otherwise → keep `GlassCard` as today.

Update the caller in `_buildPairedList` to pass `isActive: glasses == _activeGlasses` (or the equivalent identifier already on state).

- [ ] **Step 2: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/g1_test_screen.dart
git commit -m "feat(glasses): active paired device uses LivingPanel"
```

---

## Phase D — Insights screen overhaul

### Task D1: Migrate Memories theme chips to `BreathingChip`

**Files:**
- Modify: `lib/screens/insights_screen.dart` — `_buildThemeChip` (~line 916).

- [ ] **Step 1: Add import**

```dart
import '../widgets/breathing_chip.dart';
```

- [ ] **Step 2: Replace `_buildThemeChip` body**

```dart
  Widget _buildThemeChip(String theme, int index) {
    return BreathingChip(
      label: theme,
      tone: BreathingChipTone.cyan,
      entranceIndex: index,
      onTap: () => _onThemeChipTap(theme),
    );
  }
```

(Substitute `_onThemeChipTap(theme)` with the existing tap callback.)

- [ ] **Step 3: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/insights_screen.dart
git commit -m "feat(insights): theme chips use BreathingChip"
```

---

### Task D2: Migrate Buzz starters and citation chips

**Files:**
- Modify: `lib/screens/insights_screen.dart` — `_buildBuzzStarters` (~1114), `_buildCitationChips` (~1255).

- [ ] **Step 1: In `_buildBuzzStarters`, replace each starter with**:

```dart
BreathingChip(
  label: starter,
  tone: BreathingChipTone.purple,
  entranceIndex: index,
  onTap: () => _onBuzzStarterTap(starter),
),
```

- [ ] **Step 2: In `_buildCitationChips`, replace each citation with**:

```dart
BreathingChip(
  label: citation.title,
  tone: BreathingChipTone.lime,
  entranceIndex: index,
  onTap: () => _openCitation(citation),
),
```

- [ ] **Step 3: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/insights_screen.dart
git commit -m "feat(insights): buzz starters + citation chips use BreathingChip"
```

---

### Task D3: Streaming indicator → `LiveStatusPill`

**Files:**
- Modify: `lib/screens/insights_screen.dart` — `_buildSearchingIndicator` (~1219).

- [ ] **Step 1: Add import**

```dart
import '../widgets/live_status_pill.dart';
```

- [ ] **Step 2: Replace `_buildSearchingIndicator` body**:

```dart
  Widget _buildSearchingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          LiveStatusPill(status: LiveStatus.answering, label: 'Searching'),
        ],
      ),
    );
  }
```

- [ ] **Step 3: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/insights_screen.dart
git commit -m "feat(insights): streaming indicator uses LiveStatusPill"
```

---

### Task D4: Day-section spine

**Files:**
- Modify: `lib/screens/insights_screen.dart` — `_buildDaySection` (~849) and the wrapping list.

- [ ] **Step 1: Wrap each day section in a `Row` with a 2px spine**

In `_buildDaySection`, replace the outer return with:

```dart
  Widget _buildDaySection(_DaySection section) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [HelixTheme.cyan, Color(0x0039D7FF)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _existingDaySectionBody(section)),
      ],
    );
  }
```

Then extract the **existing** day-section body into a private method `_existingDaySectionBody(_DaySection section)` that returns what `_buildDaySection` previously returned.

- [ ] **Step 2: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/insights_screen.dart
git commit -m "feat(insights): memories day-section gets cyan spine"
```

---

### Task D5: Pending-facts swipe stack

**Files:**
- Modify: `lib/screens/insights_screen.dart` — `_buildPendingCards` (~501).

- [ ] **Step 1: Add imports**

```dart
import '../widgets/living_panel.dart';
```

- [ ] **Step 2: Wrap pending-cards rendering**

Replace `_buildPendingCards` body with:

```dart
  Widget _buildPendingCards() {
    final pending = _pendingFacts;   // existing list
    if (pending.isEmpty) return _buildAllCaughtUp();
    final visible = pending.take(3).toList();
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          for (var i = visible.length - 1; i >= 0; i--)
            Positioned.fill(
              top: i * 12.0,
              left: i * 8.0,
              right: i * 8.0,
              child: Opacity(
                opacity: 1.0 - (i * 0.25),
                child: Transform.scale(
                  scale: 1.0 - (i * 0.04),
                  child: i == 0
                      ? Dismissible(
                          key: ValueKey(visible[i].id),
                          background: _buildSwipeBackground(confirm: true),
                          secondaryBackground: _buildSwipeBackground(confirm: false),
                          onDismissed: (dir) =>
                              _onPendingDismiss(visible[i], dir),
                          child: LivingPanel(
                            isActive: true,
                            child: _renderPendingCardBody(visible[i]),
                          ),
                        )
                      : LivingPanel(
                          isActive: false,
                          child: _renderPendingCardBody(visible[i]),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
```

If `_renderPendingCardBody` doesn't exist, extract the body of the existing per-card builder into a method by that name. If `_onPendingDismiss` doesn't exist by that exact name, substitute the existing dismiss handler.

- [ ] **Step 3: Analyze + test + commit**

```bash
flutter analyze
flutter test test/
git add lib/screens/insights_screen.dart
git commit -m "feat(insights): pending facts use 3-deep swipe stack on LivingPanel"
```

---

### Task D6: Final regression sweep

- [ ] **Step 1: Full validation gate**

```bash
bash scripts/run_gate.sh
```
Expected: PASS.

- [ ] **Step 2: Manual smoke**

Boot a dedicated simulator (per `CLAUDE.md`), run the app, and walk:
- Home: hero card pulses; waveform reacts when listening; mode chips breathe and select.
- Glasses: hero shows L/R dot states matching real BLE state; uptime ticks; telemetry card looks new.
- Insights: theme chips and buzz starters breathe; pending stack visible if any pending; streaming pill shows "Answering" while a buzz query streams.

- [ ] **Step 3: Final commit if any tweaks**

```bash
git add -p
git commit -m "chore(ui): post-overhaul polish"
```

---

## Self-Review Notes

- Spec coverage:
  - Tokens (`HelixGradients` / `HelixGlow` / `HelixMotion`): A2.
  - `LiveWaveform`: A11. `LiveStatusPill`: A8. `LivingPanel`: A9. `BreathingChip`: A10. `HelixIcon`: A6+A7.
  - `MicLevelService` Dart: A3. iOS observer + channel + tap hooks: A4. Brand SVGs: A5.
  - `HomeHeroCard` + Home wiring: A12+A13. Mode + chip rows + hero icons: B1–B3.
  - `GlassesHeroCard` + uptime ticker + telemetry visual + workflow chips + active paired panel: C1–C6.
  - Pending-facts swipe stack + day spine + theme/buzz/citation chips + streaming pill: D1–D5.
  - Sparklines / `SparklineRow` and freshness 60s gradient + memories empty-state illustration: deferred per spec discussion (visual-only items that risk scope creep). Listed under Out of Scope below.

- Out of scope (deferred from the spec, accepted):
  - Sparkline telemetry rows (no native data plumbing).
  - 60-second freshness gradient on confirmed facts (stretch polish).
  - Custom Helix illustration for memories empty state (asset-design work, not code).
  - Refactoring `home_screen.dart` size.

- Placeholder scan: every step contains real code or commands. Where existing identifiers are unknown (`_currentMode`, `_pendingFacts`, etc.), the plan shows the exact substitution candidate and includes a `grep -n` step earlier so the implementer locates the actual name before substitution.

- Type consistency: `LiveStatus` enum used identically in `LiveStatusPill`, `HomeHeroCard`, and `GlassesHeroCard`. `BleConnectionState` enum lifted from `lib/services/ble.dart`. `BreathingChipTone` consumed consistently across Home and Insights tasks.
