import 'package:flutter/material.dart';

import '../theme/helix_theme.dart';

class StatusIndicator extends StatefulWidget {
  final bool isActive;
  final String label;
  final Color? activeColor;

  const StatusIndicator({
    super.key,
    required this.isActive,
    required this.label,
    this.activeColor,
  });

  @override
  State<StatusIndicator> createState() => _StatusIndicatorState();
}

class _StatusIndicatorState extends State<StatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(StatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && oldWidget.isActive) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.isActive
        ? (widget.activeColor ?? HelixTheme.lime)
        : HelixTheme.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isActive
            ? HelixTheme.surfaceInteractive.withValues(alpha: 0.96)
            : HelixTheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: widget.isActive
              ? dotColor.withValues(alpha: 0.3)
              : HelixTheme.borderSubtle,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: widget.isActive
                      ? [
                          BoxShadow(
                            color: dotColor.withValues(
                              alpha: _animation.value * 0.55,
                            ),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: TextStyle(
              color: widget.isActive
                  ? HelixTheme.textPrimary
                  : HelixTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
