import 'display_constants.dart';

/// Enhanced HUD layouts optimized for the 576×136 display.
class EnhancedLayoutPresets {
  EnhancedLayoutPresets._();

  static const String commandCenterId = 'command_center';
  static const String cockpitId = 'cockpit';
  static const String focusId = 'focus';

  /// Command Center: header + 4 columns + footer.
  ///
  /// ```
  /// ┌──────────────── header (576×18) ────────────────┐
  /// ├─────────┬─────────┬─────────┬──────────────────┤
  /// │ stock   │calendar │activity │   news           │
  /// │ 140×96  │ 140×96  │ 140×96  │   144×96         │
  /// ├─────────┴─────────┴─────────┴──────────────────┤
  /// │ footer (576×16)                                │
  /// └────────────────────────────────────────────────┘
  /// ```
  static HudLayout commandCenter() {
    return const HudLayout(
      id: commandCenterId,
      name: 'Command Center',
      zones: [
        HudZone(id: 'header', x: 0, y: 0, width: 576, height: 18),
        HudZone(id: 'stock', x: 0, y: 21, width: 140, height: 96),
        HudZone(id: 'calendar', x: 144, y: 21, width: 140, height: 96),
        HudZone(id: 'activity', x: 288, y: 21, width: 140, height: 96),
        HudZone(id: 'news', x: 432, y: 21, width: 144, height: 96),
        HudZone(id: 'footer', x: 0, y: 120, width: 576, height: 16),
      ],
      dividers: [
        // Horizontal below header
        HudDivider(x1: 0, y1: 19, x2: 576, y2: 19, thickness: 1),
        // Vertical dividers between columns
        HudDivider(x1: 142, y1: 21, x2: 142, y2: 119, thickness: 1),
        HudDivider(x1: 286, y1: 21, x2: 286, y2: 119, thickness: 1),
        HudDivider(x1: 430, y1: 21, x2: 430, y2: 119, thickness: 1),
        // Horizontal above footer
        HudDivider(x1: 0, y1: 119, x2: 576, y2: 119, thickness: 1),
      ],
      defaultWidgetAssignments: {
        'header': 'enh_header',
        'stock': 'enh_stock',
        'calendar': 'enh_calendar',
        'activity': 'enh_activity',
        'news': 'enh_news',
        'footer': 'enh_footer',
      },
    );
  }

  /// Cockpit: header + 2 large panels (top) + 3 utility columns (bottom).
  ///
  /// ```
  /// ┌──────────────── header (576×18) ────────────────┐
  /// ├────────────────────┬───────────────────────────┤
  /// │ stock (284×54)     │ calendar (286×54)         │
  /// ├──────────┬─────────┴────┬──────────────────────┤
  /// │ activity │  todos       │  system              │
  /// │ 190×58   │  190×58      │  188×58              │
  /// └──────────┴──────────────┴──────────────────────┘
  /// ```
  static HudLayout cockpit() {
    return const HudLayout(
      id: cockpitId,
      name: 'Cockpit',
      zones: [
        HudZone(id: 'header', x: 0, y: 0, width: 576, height: 18),
        HudZone(id: 'stock', x: 0, y: 21, width: 284, height: 54),
        HudZone(id: 'calendar', x: 290, y: 21, width: 286, height: 54),
        HudZone(id: 'activity', x: 0, y: 78, width: 190, height: 58),
        HudZone(id: 'todos', x: 194, y: 78, width: 190, height: 58),
        HudZone(id: 'system', x: 388, y: 78, width: 188, height: 58),
      ],
      dividers: [
        // Horizontal below header
        HudDivider(x1: 0, y1: 19, x2: 576, y2: 19, thickness: 1),
        // Vertical divider in top row
        HudDivider(x1: 287, y1: 21, x2: 287, y2: 77, thickness: 1),
        // Horizontal between rows
        HudDivider(x1: 0, y1: 77, x2: 576, y2: 77, thickness: 1),
        // Vertical dividers in bottom row
        HudDivider(x1: 192, y1: 78, x2: 192, y2: 136, thickness: 1),
        HudDivider(x1: 386, y1: 78, x2: 386, y2: 136, thickness: 1),
      ],
      defaultWidgetAssignments: {
        'header': 'enh_header',
        'stock': 'enh_stock',
        'calendar': 'enh_calendar',
        'activity': 'enh_activity',
        'todos': 'enh_todos',
        'system': 'enh_system',
      },
    );
  }

  /// Focus: header + large primary panel + 2 supporting panels.
  ///
  /// ```
  /// ┌──────────────── header (576×18) ────────────────┐
  /// ├───────────────────────────┬─────────────────────┤
  /// │                           │ calendar (192×56)   │
  /// │ primary (380×115)         ├─────────────────────┤
  /// │                           │ activity (192×56)   │
  /// └───────────────────────────┴─────────────────────┘
  /// ```
  static HudLayout focus() {
    return const HudLayout(
      id: focusId,
      name: 'Focus',
      zones: [
        HudZone(id: 'header', x: 0, y: 0, width: 576, height: 18),
        HudZone(id: 'primary', x: 0, y: 21, width: 380, height: 115),
        HudZone(id: 'calendar', x: 384, y: 21, width: 192, height: 56),
        HudZone(id: 'activity', x: 384, y: 80, width: 192, height: 56),
      ],
      dividers: [
        // Horizontal below header
        HudDivider(x1: 0, y1: 19, x2: 576, y2: 19, thickness: 1),
        // Vertical divider (full height of content area)
        HudDivider(x1: 382, y1: 21, x2: 382, y2: 136, thickness: 1),
        // Horizontal divider between right panels
        HudDivider(x1: 384, y1: 78, x2: 576, y2: 78, thickness: 1),
      ],
      defaultWidgetAssignments: {
        'header': 'enh_header',
        'primary': 'enh_stock',
        'calendar': 'enh_calendar',
        'activity': 'enh_activity',
      },
    );
  }

  static List<HudLayout> all() {
    return [commandCenter(), cockpit(), focus()];
  }

  static HudLayout byId(String id) {
    switch (id) {
      case commandCenterId:
        return commandCenter();
      case cockpitId:
        return cockpit();
      case focusId:
        return focus();
      default:
        return commandCenter();
    }
  }
}
