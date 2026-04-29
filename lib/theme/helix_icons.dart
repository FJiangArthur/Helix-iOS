import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'helix_tokens.dart';

/// Semantic icon registry for Helix.
///
/// Phase 1: defined but unused; screens migrate from `Icon(Icons.xxx)` to
/// `HelixIcon(HelixIcons.xxx)` in Phase 3.
///
/// Each constant names a *concept* used in the product (listen, ai, fact,
/// glasses…) and binds it to a Phosphor regular-weight glyph. Screens render
/// these via [HelixIcon], which substitutes the matching duotone variant by
/// default so the look (line outline + soft accent fill) is consistent.
///
/// Adding a new concept: pick a Phosphor regular icon, add it here, then add
/// the duotone counterpart to [HelixIcon._duotoneMap]. The parity test
/// `helix_icons_test.dart` will fail until both sides are updated.
class HelixIcons {
  HelixIcons._();

  /// Every public concept in the registry, ordered by declaration. Used by
  /// the parity-lock test to verify each entry has a duotone counterpart.
  @visibleForTesting
  static const List<IconData> all = <IconData>[
    listen,
    pause,
    glasses,
    ai,
    chat,
    fact,
    memory,
    todo,
    insight,
    settings,
    home,
    search,
    bookmark,
    book,
    bluetooth,
    battery,
    caret,
    close,
    more,
    play,
    record,
    cost,
    device,
    cloud,
    lightning,
  ];

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

/// Renders a [HelixIcons] entry as a Phosphor icon.
///
/// Defaults to the duotone weight (line outline + soft accent fill at
/// opacity 0.35) for a warmer, friendlier feel than monoline icons. Pass
/// `useDuotone: false` to render the regular weight instead.
///
/// The primary stroke colour defaults to [ColorTokens.ink]; the secondary
/// (fill) colour defaults to [ColorTokens.accent]. Both are overridable.
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
      final duotone = _duotoneMap[icon] ?? icon;
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

  @visibleForTesting
  static Map<IconData, IconData> get duotoneMap => _duotoneMap;

  static final Map<IconData, IconData> _duotoneMap = {
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
