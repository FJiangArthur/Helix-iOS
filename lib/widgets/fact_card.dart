import 'package:flutter/material.dart';

import '../models/fact.dart';
import '../theme/helix_theme.dart';
import 'glass_card.dart';

/// A single fact card for the swipe-to-confirm interface.
///
/// Displays category pill, content text, optional source quote, and a
/// confidence indicator bar along the bottom.
class FactCard extends StatelessWidget {
  final String category;
  final String content;
  final String? sourceQuote;
  final double confidence;
  final VoidCallback? onTap;

  const FactCard({
    super.key,
    required this.category,
    required this.content,
    this.sourceQuote,
    this.confidence = 0.5,
    this.onTap,
  });

  /// Map a category string to its theme colour.
  static Color categoryColor(String category) {
    switch (category) {
      case 'preference':
        return HelixTheme.cyan;
      case 'relationship':
        return HelixTheme.purple;
      case 'habit':
        return HelixTheme.lime;
      case 'opinion':
        return HelixTheme.amber;
      case 'goal':
        return HelixTheme.amber;
      case 'biographical':
        return HelixTheme.cyan;
      case 'skill':
        return HelixTheme.lime;
      default:
        return HelixTheme.cyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(category);
    final catEnum = FactCategory.fromString(category);
    final theme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        borderColor: color.withValues(alpha: 0.3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                catEnum.displayName,
                style: theme.labelSmall?.copyWith(
                  color: color,
                  letterSpacing: 0.8,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Main content
            Text(
              content,
              style: theme.bodyLarge,
            ),

            // Source quote
            if (sourceQuote != null && sourceQuote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote_rounded,
                    size: 14,
                    color: HelixTheme.textMuted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      sourceQuote!,
                      style: theme.bodySmall?.copyWith(
                        color: HelixTheme.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // Confidence bar
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: confidence,
                minHeight: 3,
                backgroundColor:
                    HelixTheme.borderSubtle.withValues(alpha: 0.4),
                valueColor: AlwaysStoppedAnimation<Color>(
                  color.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
