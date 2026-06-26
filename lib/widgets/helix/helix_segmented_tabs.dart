import 'package:flutter/material.dart';

import '../../theme/helix_theme.dart';

class HelixSegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const HelixSegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HelixTheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(HelixTheme.radiusControl),
        border: Border.all(color: HelixTheme.borderSubtle),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: _SegmentButton(
                  label: labels[i],
                  selected: selectedIndex == i,
                  onTap: () => onChanged(i),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(HelixTheme.radiusCompact),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? HelixTheme.cyan.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(HelixTheme.radiusCompact),
            border: Border.all(
              color: selected
                  ? HelixTheme.cyan.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? HelixTheme.cyan : HelixTheme.textMuted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
