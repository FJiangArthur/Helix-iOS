import 'package:flutter/material.dart';

import '../../theme/helix_theme.dart';

class HelixGeneratedIcon extends StatelessWidget {
  final String asset;
  final bool selected;
  final double size;
  final String? semanticLabel;

  const HelixGeneratedIcon({
    super.key,
    required this.asset,
    this.selected = false,
    this.size = 30,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: Image.asset(
        asset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        semanticLabel: semanticLabel,
        errorBuilder: (context, error, stackTrace) => _fallbackIcon(),
      ),
    );

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: selected ? 1 : 0.58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.30),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: HelixTheme.cyan.withValues(alpha: 0.30),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: image,
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: HelixTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: HelixTheme.borderSubtle),
      ),
      child: Icon(
        Icons.blur_on_rounded,
        size: size * 0.62,
        color: selected ? HelixTheme.cyan : HelixTheme.textSecondary,
      ),
    );
  }
}

class HelixGeneratedBackdrop extends StatelessWidget {
  final String asset;
  final double height;
  final Color accent;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Alignment imageAlignment;

  const HelixGeneratedBackdrop({
    super.key,
    required this.asset,
    required this.accent,
    this.height = 128,
    this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = HelixTheme.radiusPanel,
    this.imageAlignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: HelixTheme.surfaceRaised,
          border: Border.all(color: accent.withValues(alpha: 0.22)),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: imageAlignment,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    HelixTheme.background.withValues(alpha: 0.68),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: accent.withValues(alpha: 0.24)),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
            if (child != null) Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
