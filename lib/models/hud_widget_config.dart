/// Configuration for a single HUD widget: enabled state, sort order, and options.
class HudWidgetConfig {
  HudWidgetConfig({
    required this.widgetId,
    this.enabled = true,
    this.sortOrder = 0,
    Map<String, String>? options,
  }) : options = options ?? {};

  final String widgetId;
  bool enabled;
  int sortOrder;
  Map<String, String> options;

  Map<String, dynamic> toMap() => {
        'widgetId': widgetId,
        'enabled': enabled,
        'sortOrder': sortOrder,
        'options': options,
      };

  factory HudWidgetConfig.fromMap(Map<String, dynamic> map) {
    return HudWidgetConfig(
      widgetId: map['widgetId'] as String? ?? '',
      enabled: map['enabled'] as bool? ?? true,
      sortOrder: map['sortOrder'] as int? ?? 0,
      options: (map['options'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
    );
  }

  /// Default widget configs in display order.
  static List<HudWidgetConfig> get defaults => [
        HudWidgetConfig(widgetId: 'clock', sortOrder: 0),
        HudWidgetConfig(widgetId: 'calendar', sortOrder: 1),
        HudWidgetConfig(widgetId: 'weather', sortOrder: 2),
        HudWidgetConfig(widgetId: 'reminders', sortOrder: 3),
        HudWidgetConfig(widgetId: 'todos', sortOrder: 4, enabled: false),
        HudWidgetConfig(widgetId: 'news', sortOrder: 5, enabled: false),
        HudWidgetConfig(widgetId: 'battery', sortOrder: 6, enabled: false),
      ];
}
