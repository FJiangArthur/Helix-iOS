import 'display_constants.dart';

/// Enhanced HUD layouts that maximize the 640×400 display with data-dense zones.
class EnhancedLayoutPresets {
  EnhancedLayoutPresets._();

  static const String commandCenterId = 'command_center';
  static const String cockpitId = 'cockpit';
  static const String focusId = 'focus';

  /// Command Center: header strip + 3×2 grid + footer strip.
  ///
  /// ```
  /// ┌──────────── header (640×30) ────────────┐
  /// ├──────────┬───────────┬──────────────────┤
  /// │ stock    │ calendar  │   activity       │
  /// │ 196×166  │ 220×166   │   200×166        │
  /// ├──────────┼───────────┼──────────────────┤
  /// │ news     │ todos     │   system         │
  /// │ 196×166  │ 220×166   │   200×166        │
  /// ├──────────┴───────────┴──────────────────┤
  /// │ footer (640×24)                         │
  /// └─────────────────────────────────────────┘
  /// ```
  static HudLayout commandCenter() {
    return const HudLayout(
      id: commandCenterId,
      name: 'Command Center',
      zones: [
        HudZone(id: 'header', x: 0, y: 0, width: 640, height: 30),
        HudZone(id: 'stock', x: 0, y: 34, width: 196, height: 166),
        HudZone(id: 'calendar', x: 200, y: 34, width: 220, height: 166),
        HudZone(id: 'activity', x: 424, y: 34, width: 216, height: 166),
        HudZone(id: 'news', x: 0, y: 204, width: 196, height: 166),
        HudZone(id: 'todos', x: 200, y: 204, width: 220, height: 166),
        HudZone(id: 'system', x: 424, y: 204, width: 216, height: 166),
        HudZone(id: 'footer', x: 0, y: 376, width: 640, height: 24),
      ],
      dividers: [
        // Horizontal below header
        HudDivider(x1: 0, y1: 32, x2: 640, y2: 32, thickness: 1),
        // Horizontal between rows
        HudDivider(x1: 0, y1: 202, x2: 640, y2: 202, thickness: 1),
        // Horizontal above footer
        HudDivider(x1: 0, y1: 374, x2: 640, y2: 374, thickness: 1),
        // Vertical dividers in top row
        HudDivider(x1: 198, y1: 34, x2: 198, y2: 202, thickness: 1),
        HudDivider(x1: 422, y1: 34, x2: 422, y2: 202, thickness: 1),
        // Vertical dividers in bottom row
        HudDivider(x1: 198, y1: 204, x2: 198, y2: 374, thickness: 1),
        HudDivider(x1: 422, y1: 204, x2: 422, y2: 374, thickness: 1),
      ],
      defaultWidgetAssignments: {
        'header': 'enh_header',
        'stock': 'enh_stock',
        'calendar': 'enh_calendar',
        'activity': 'enh_activity',
        'news': 'enh_news',
        'todos': 'enh_todos',
        'system': 'enh_system',
        'footer': 'enh_footer',
      },
    );
  }

  /// Cockpit: status strip + two large panels + ticker + three utility zones.
  ///
  /// ```
  /// ┌────────── status (640×28) ──────────────┐
  /// ├──────────────────┬──────────────────────┤
  /// │ stock (312×172)  │ calendar (312×172)   │
  /// ├──────────────────┴──────────────────────┤
  /// │ news ticker (640×44)                    │
  /// ├──────────┬───────────┬──────────────────┤
  /// │ activity │  todos    │  system          │
  /// │ 210×128  │  210×128  │  196×128         │
  /// └──────────┴───────────┴──────────────────┘
  /// ```
  static HudLayout cockpit() {
    return const HudLayout(
      id: cockpitId,
      name: 'Cockpit',
      zones: [
        HudZone(id: 'header', x: 0, y: 0, width: 640, height: 28),
        HudZone(id: 'stock', x: 0, y: 32, width: 316, height: 172),
        HudZone(id: 'calendar', x: 320, y: 32, width: 320, height: 172),
        HudZone(id: 'news', x: 0, y: 208, width: 640, height: 44),
        HudZone(id: 'activity', x: 0, y: 256, width: 210, height: 144),
        HudZone(id: 'todos', x: 214, y: 256, width: 210, height: 144),
        HudZone(id: 'system', x: 428, y: 256, width: 212, height: 144),
      ],
      dividers: [
        HudDivider(x1: 0, y1: 30, x2: 640, y2: 30, thickness: 1),
        HudDivider(x1: 318, y1: 32, x2: 318, y2: 206, thickness: 1),
        HudDivider(x1: 0, y1: 206, x2: 640, y2: 206, thickness: 1),
        HudDivider(x1: 0, y1: 254, x2: 640, y2: 254, thickness: 1),
        HudDivider(x1: 212, y1: 256, x2: 212, y2: 400, thickness: 1),
        HudDivider(x1: 426, y1: 256, x2: 426, y2: 400, thickness: 1),
      ],
      defaultWidgetAssignments: {
        'header': 'enh_header',
        'stock': 'enh_stock',
        'calendar': 'enh_calendar',
        'news': 'enh_news',
        'activity': 'enh_activity',
        'todos': 'enh_todos',
        'system': 'enh_system',
      },
    );
  }

  /// Focus: header + one large primary zone + three supporting zones.
  ///
  /// ```
  /// ┌────────── header (640×32) ──────────────┐
  /// ├─────────────────────────────────────────┤
  /// │   primary (640×204) — full width        │
  /// ├──────────┬───────────┬──────────────────┤
  /// │ calendar │ activity  │  todos           │
  /// │ 210×140  │ 210×140   │  196×140         │
  /// └──────────┴───────────┴──────────────────┘
  /// ```
  static HudLayout focus() {
    return const HudLayout(
      id: focusId,
      name: 'Focus',
      zones: [
        HudZone(id: 'header', x: 0, y: 0, width: 640, height: 32),
        HudZone(id: 'primary', x: 0, y: 36, width: 640, height: 204),
        HudZone(id: 'calendar', x: 0, y: 246, width: 210, height: 154),
        HudZone(id: 'activity', x: 214, y: 246, width: 210, height: 154),
        HudZone(id: 'todos', x: 428, y: 246, width: 212, height: 154),
      ],
      dividers: [
        HudDivider(x1: 0, y1: 34, x2: 640, y2: 34, thickness: 1),
        HudDivider(x1: 0, y1: 244, x2: 640, y2: 244, thickness: 1),
        HudDivider(x1: 212, y1: 246, x2: 212, y2: 400, thickness: 1),
        HudDivider(x1: 426, y1: 246, x2: 426, y2: 400, thickness: 1),
      ],
      defaultWidgetAssignments: {
        'header': 'enh_header',
        'primary': 'enh_stock',
        'calendar': 'enh_calendar',
        'activity': 'enh_activity',
        'todos': 'enh_todos',
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
