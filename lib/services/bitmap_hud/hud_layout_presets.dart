import 'display_constants.dart';

/// Predefined HUD layouts for the G1 smart glasses (640×400 display).
class HudLayoutPresets {
  HudLayoutPresets._();

  static const String classicId = 'classic';
  static const String minimalId = 'minimal';
  static const String denseId = 'dense';
  static const String conversationId = 'conversation';

  /// Classic quad-zone layout with vertical and horizontal dividers.
  ///
  /// ```
  /// ┌───── top_left ─────┬───── top_right ─────┐
  /// │  clock/weather/     │  stock name+price    │
  /// │  notifications      │                      │
  /// ├────────────────────┤├─────────────────────│
  /// │  bottom_left        │  bottom_right        │
  /// │  calendar event     │  sparkline+battery   │
  /// └────────────────────┴──────────────────────┘
  /// ```
  static HudLayout classic() {
    return const HudLayout(
      id: classicId,
      name: 'Classic',
      zones: [
        HudZone(id: 'top_left', x: 0, y: 0, width: 316, height: 196),
        HudZone(id: 'top_right', x: 324, y: 0, width: 316, height: 196),
        HudZone(id: 'bottom_left', x: 0, y: 204, width: 316, height: 196),
        HudZone(id: 'bottom_right', x: 324, y: 204, width: 316, height: 196),
      ],
      dividers: [
        // Vertical divider splitting left/right columns
        HudDivider(x1: 320, y1: 0, x2: 320, y2: 400, thickness: 2),
        // Horizontal divider on the left half
        HudDivider(x1: 0, y1: 200, x2: 316, y2: 200, thickness: 2),
        // Horizontal divider on the right half
        HudDivider(x1: 324, y1: 200, x2: 640, y2: 200, thickness: 2),
      ],
      defaultWidgetAssignments: {
        'top_left': 'bmp_clock',
        'bottom_left': 'bmp_calendar',
        'top_right': 'bmp_stock',
        'bottom_right': 'bmp_battery',
      },
    );
  }

  /// Minimal single-column layout with three vertically stacked zones.
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
        HudZone(id: 'center_top', x: 0, y: 0, width: 640, height: 120),
        HudZone(id: 'center_mid', x: 0, y: 130, width: 640, height: 120),
        HudZone(id: 'center_bot', x: 0, y: 260, width: 640, height: 140),
      ],
      dividers: [
        HudDivider(x1: 0, y1: 125, x2: 640, y2: 125, thickness: 2),
        HudDivider(x1: 0, y1: 255, x2: 640, y2: 255, thickness: 2),
      ],
      defaultWidgetAssignments: {
        'center_top': 'bmp_clock',
        'center_mid': 'bmp_weather',
        'center_bot': 'bmp_calendar',
      },
    );
  }

  /// Information-dense layout with a tall right column and three left zones.
  ///
  /// ```
  /// ┌──── tl ────┬──── tc ────┬──── right ────┐
  /// │  clock      │  weather   │  stock+chart   │
  /// ├─────────────┴────────────┤                │
  /// │  bottom_wide             │                │
  /// │  calendar+notif+battery  │                │
  /// └──────────────────────────┴────────────────┘
  /// ```
  static HudLayout dense() {
    return const HudLayout(
      id: denseId,
      name: 'Information Dense',
      zones: [
        HudZone(id: 'tl', x: 0, y: 0, width: 200, height: 196),
        HudZone(id: 'tc', x: 204, y: 0, width: 200, height: 196),
        HudZone(id: 'right', x: 408, y: 0, width: 232, height: 400),
        HudZone(id: 'bottom_wide', x: 0, y: 204, width: 404, height: 196),
      ],
      dividers: [
        // Vertical divider separating left group from right column
        HudDivider(x1: 404, y1: 0, x2: 404, y2: 400, thickness: 2),
        // Horizontal divider across left group
        HudDivider(x1: 0, y1: 200, x2: 404, y2: 200, thickness: 2),
        // Vertical divider between tl and tc
        HudDivider(x1: 202, y1: 0, x2: 202, y2: 200, thickness: 2),
      ],
      defaultWidgetAssignments: {
        'tl': 'bmp_clock',
        'tc': 'bmp_weather',
        'right': 'bmp_stock',
        'bottom_wide': 'bmp_calendar',
      },
    );
  }

  /// Conversation layout optimised for active recording sessions.
  ///
  /// ```
  /// ┌──────── status_bar ────────┐  recording status + time
  /// ├──────── stats ─────────────┤  Q/A count, word count
  /// ├──────── context ───────────┤  last question + AI response
  /// └────────────────────────────┘
  /// ```
  static HudLayout conversation() {
    return const HudLayout(
      id: conversationId,
      name: 'Conversation',
      zones: [
        HudZone(id: 'status_bar', x: 0, y: 0, width: 640, height: 60),
        HudZone(id: 'stats', x: 0, y: 68, width: 640, height: 80),
        HudZone(id: 'context', x: 0, y: 160, width: 640, height: 240),
      ],
      dividers: [
        HudDivider(x1: 0, y1: 64, x2: 640, y2: 64, thickness: 2),
        HudDivider(x1: 0, y1: 155, x2: 640, y2: 155, thickness: 2),
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
