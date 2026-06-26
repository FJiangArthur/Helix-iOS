# Helix Wireframe Redesign Map

This package treats generated images as visual references only. Final text,
icons, and controls should be rebuilt natively in Figma and Flutter.

## Reference Images

| File | Purpose |
| --- | --- |
| `references/assistant-main.png` | Assistant tab target: live conversation control surface. |
| `references/device-main.png` | Device tab target: G1 pairing, mic source, HUD utilities, diagnostics. |
| `references/sessions-main.png` | Sessions tab target: monitor, archive, projects. |
| `references/knowledge-main.png` | Knowledge tab target: ask, facts, memories, review. |
| `references/settings-main.png` | Settings tab target: grouped configuration console. |
| `references/component-kit.png` | Reusable component direction. |
| `references/icon-concepts.png` | Icon art direction only; rebuild as vectors before shipping. |

## Navigation

| Current UI | New UI |
| --- | --- |
| Home | Assistant |
| Glasses | Device |
| Live > Live | Sessions > Monitor |
| Live > History | Sessions > Archive |
| Live > Projects | Sessions > Projects |
| Ask AI > Daily AI | Knowledge > Ask |
| Ask AI > Review | Knowledge > Review |
| Insights > Facts | Knowledge > Facts |
| Insights > Memories | Knowledge > Memories |
| Settings push screen | Settings bottom tab |

## Component Mapping

| Current Element | New Native Component |
| --- | --- |
| `GlassCard` hero/control panels | `HelixSurface` where a stronger cockpit panel is needed. |
| Status pills and ad hoc badges | `HelixStatusBadge`. |
| TabBar rows for merged areas | `HelixSegmentedTabs`. |
| Session/count/cost chips | `HelixMetricChip`. |
| Home fixed composer | `HelixActionDock`. |
| Transcript/answer/session preview blocks | `HelixPreviewCard`. |

## Implementation Boundaries

- Keep `ConversationEngine`, BLE services, database DAOs, and settings
  persistence unchanged.
- Use Material icons for v1; generated icon art is not production-ready.
- Keep generated PNGs under docs only unless a later task promotes a specific
  illustration into `assets/illustrations/`.
