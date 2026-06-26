import 'package:flutter/material.dart';

import '../../theme/helix_theme.dart';
import 'helix_surface.dart';

class HelixActionDock extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final bool inputEnabled;
  final bool isRecording;
  final bool isBusy;
  final VoidCallback onSend;
  final VoidCallback onRecordTap;
  final VoidCallback? onTapOutside;

  const HelixActionDock({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.inputEnabled,
    required this.isRecording,
    required this.isBusy,
    required this.onSend,
    required this.onRecordTap,
    this.onTapOutside,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isRecording ? const Color(0xFFFF6B6B) : HelixTheme.cyan;
    return HelixSurface(
      emphasis: 0.24,
      accent: accent,
      active: isRecording,
      borderRadius: HelixTheme.radiusControl,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              key: const Key('home-composer-input-shell'),
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(HelixTheme.radiusPill),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: inputEnabled,
                style: TextStyle(
                  color: Colors.white.withValues(
                    alpha: inputEnabled ? 1 : 0.42,
                  ),
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.32),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                textInputAction: TextInputAction.send,
                onTapOutside: (_) => onTapOutside?.call(),
                onSubmitted: (_) {
                  if (inputEnabled) onSend();
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            key: const Key('home-composer-send-button'),
            onTap: inputEnabled ? onSend : null,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: inputEnabled
                    ? HelixTheme.cyan.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(HelixTheme.radiusControl),
                border: Border.all(
                  color: inputEnabled
                      ? HelixTheme.cyan.withValues(alpha: 0.24)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Icon(
                Icons.arrow_upward_rounded,
                size: 18,
                color: inputEnabled ? HelixTheme.cyan : HelixTheme.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: isBusy ? null : onRecordTap,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.95),
                    Color.lerp(accent, HelixTheme.background, 0.38)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(HelixTheme.radiusControl),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: isRecording
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.26),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
