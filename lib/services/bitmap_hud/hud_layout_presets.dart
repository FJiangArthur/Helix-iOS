import 'display_constants.dart';

/// Predefined HUD layouts for the G1 smart glasses (576x136 display).
class HudLayoutPresets {
  HudLayoutPresets._();

  static const String classicId = 'classic';
  static const String minimalId = 'minimal';
  static const String denseId = 'dense';
  static const String conversationId = 'conversation';

  /// Classic 2x2 grid layout for the 576x136 display.
  ///
  /// ```
  /// ┌───── top_left ─────┬───── top_right ─────┐
  /// │  clock/weather/     │  stock name+price    │
  /// │  notifications      │                      │
  /// ├─────────────────────┼──────────────────────┤
  /// │  bottom_left        │  bottom_right        │
  /// │  calendar event     │  sparkline+battery   │
  /// └─────────────────────┴──────────────────────┘
  /// ```
  static HudLayout classic() {
    return const HudLayout(
      id: classicId,
      name: 'Classic',
      zones: [
        HudZone(id: 'top_left', x: 0, y: 0, width: 285, height: 66),
        HudZone(id: 'top_right', x: 291, y: 0, width: 285, height: 66),
        HudZone(id: 'bottom_left', x: 0, y: 70, width: 285, height: 66),
        HudZone(id: 'bottom_right', x: 291, y: 70, width: 285, height: 66),
      ],
      dividers: [
        // Vertical divider splitting left/right columns
        HudDivider(x1: 288, y1: 0, x2: 288, y2: 136, thickness: 2),
        // Horizontal divider on the left half
        HudDivider(x1: 0, y1: 68, x2: 285, y2: 68, thickness: 2),
        // Horizontal divider on the right half
        HudDivider(x1: 291, y1: 68, x2: 576, y2: 68, thickness: 2),
      ],
      defaultWidgetAssignments: {
        'top_left': 'bmp_clock',
        'bottom_left': 'bmp_calendar',
        'top_right': 'bmp_stock',
        'bottom_right': 'bmp_battery',
      },
    );
  }

  /// Minimal 3 horizontal strips for the 576x136 display.
  ///
  /// ```
  /// ┌──────── center_top ────────┐  clock
  /// ├──────── center_mid ────────┤  weather
  /// ├──────── center_bot ────────┤  calendar
  /// └────────────────────────────┘
  /// ```
  static HudLayout minimal() {
    return const HudLayout(
      id: minimalId,
      name: 'Minimal',
      zones: [
        HudZone(id: 'center_top', x: 0, y: 0, width: 576, height: 43),
        HudZone(id: 'center_mid', x: 0, y: 46, width: 576, height: 43),
        HudZone(id: 'center_bot', x: 0, y: 92, width: 576, height: 44),
      ],
      dividers: [
        HudDivider(x1: 0, y1: 44, x2: 576, y2: 44, thickness: 2),
        HudDivider(x1: 0, y1: 90, x2: 576, y2: 90, thickness: 2),
      ],
      defaultWidgetAssignments: {
        'center_top': 'bmp_clock',
        'center_mid': 'bmp_weather',
        'center_bot': 'bmp_calendar',
      },
    );
  }

  /// Dense 3-column layout for the 576x136 display.
  ///
  /// ```
  /// ┌──── tl ────┬──── tc ────┬──── right ────┐
  /// │  clock      │  weather   │  stock+chart   │
  /// │             │            │                │
  /// └─────────────┴────────────┴────────────────┘
  /// ```
  static HudLayout dense() {
    return const HudLayout(
      id: denseId,
      name: 'Information Dense',
      zones: [
        HudZone(id: 'tl', x: 0, y: 0, width: 160, height: 136),
        HudZone(id: 'tc', x: 164, y: 0, width: 160, height: 136),
        HudZone(id: 'right', x: 328, y: 0, width: 248, height: 136),
      ],
      dividers: [
        // Vertical divider between tl and tc
        HudDivider(x1: 162, y1: 0, x2: 162, y2: 136, thickness: 2),
        // Vertical divider between tc and right
        HudDivider(x1: 326, y1: 0, x2: 326, y2: 136, thickness: 2),
      ],
      defaultWidgetAssignments: {
        'tl': 'bmp_clock',
        'tc': 'bmp_weather',
        'right': 'bmp_stock',
      },
    );
  }

  /// Conversation layout with status bar + two panels for the 576x136 display.
  ///
  /// ```
  /// ┌──────────── status_bar ────────────┐  recording status + time
  /// ├──── stats ────┬──── context ───────┤  Q/A count | last Q + AI response
  /// │               │                    │
  /// └───────────────┴────────────────────┘
  /// ```
  static HudLayout conversation() {
    return const HudLayout(
      id: conversationId,
      name: 'Conversation',
      zones: [
        HudZone(id: 'status_bar', x: 0, y: 0, width: 576, height: 24),
        HudZone(id: 'stats', x: 0, y: 27, width: 200, height: 109),
        HudZone(id: 'context', x: 204, y: 27, width: 372, height: 109),
      ],
      dividers: [
        // Horizontal divider below status bar
        HudDivider(x1: 0, y1: 25, x2: 576, y2: 25, thickness: 2),
        // Vertical divider between stats and context
        HudDivider(x1: 202, y1: 27, x2: 202, y2: 136, thickness: 2),
      ],
      defaultWidgetAssignments: {
        'status_bar': 'bmp_clock',
        'stats': 'bmp_notification',
        'context': 'bmp_calendar',
      },
    );
  }

  /// Returns all available preset layouts.
  static List<HudLayout> all() {
    return [
      classic(),
      minimal(),
      dense(),
      conversation(),
    ];
  }

  /// Looks up a preset layout by [id]. Falls back to [classic] if not found.
  static HudLayout byId(String id) {
    switch (id) {
      case classicId:
        return classic();
      case minimalId:
        return minimal();
      case denseId:
        return dense();
      case conversationId:
        return conversation();
      default:
        return classic();
    }
  }
}
