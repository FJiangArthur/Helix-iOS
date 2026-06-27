# Helix Wireframe Redesign Map

This package treats the original generated wireframes as visual references.
The follow-up production pass ships generated PNGs only for tab icons and
background/hero art; final text, controls, state, and layout remain native
Flutter.

## Reference Images

| File | Purpose |
| --- | --- |
| `references/assistant-main.png` | Assistant tab target: live conversation control surface. |
| `references/device-main.png` | Device tab target: G1 pairing, mic source, HUD utilities, diagnostics. |
| `references/sessions-main.png` | Sessions tab target: monitor, archive, projects. |
| `references/knowledge-main.png` | Knowledge tab target: ask, facts, memories, review. |
| `references/settings-main.png` | Settings tab target: grouped configuration console. |
| `references/component-kit.png` | Reusable component direction. |
| `references/icon-concepts.png` | Source direction for the generated PNG icon set now shipped under `assets/illustrations/wireframe-redesign/icons/`. |

## Shipped Generated Assets

| Asset folder | Purpose |
| --- | --- |
| `assets/illustrations/wireframe-redesign/icons/` | Generated Assistant, Device, Sessions, Knowledge, and Settings navigation icons. |
| `assets/illustrations/wireframe-redesign/backgrounds/` | Generated hero/background images for the five primary surfaces. |

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
- Use generated PNGs for primary navigation icons and tab/background art.
- Keep readable UI text, controls, settings state, and interaction logic native.
- Add designer-approved vector icons later only if a final vector set is
  delivered.
