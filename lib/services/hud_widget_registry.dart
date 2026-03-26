import 'dart:async';
import '../models/hud_widget_config.dart';
import 'hud_widgets/hud_widget.dart';
import 'settings_manager.dart';

/// Manages all HUD widgets: registration, refresh scheduling, and page composition.
class HudWidgetRegistry {
  HudWidgetRegistry._();

  static HudWidgetRegistry? _instance;
  static HudWidgetRegistry get instance => _instance ??= HudWidgetRegistry._();

  final Map<String, HudWidget> _widgets = {};
  List<HudWidgetConfig> _configs = [];
  Timer? _refreshTimer;
  SettingsManager? _settings;

  final StreamController<void> _pagesChangedController =
      StreamController<void>.broadcast();
  Stream<void> get onPagesChanged => _pagesChangedController.stream;

  List<List<String>>? _cachedPages;

  /// Register a widget instance. Call before [initialize].
  void register(HudWidget widget) {
    _widgets[widget.id] = widget;
  }

  /// Load configs from settings and start the refresh timer.
  Future<void> initialize([SettingsManager? settings]) async {
    _settings = settings ?? SettingsManager.instance;
    _configs = _settings!.hudWidgetConfigs;

    // Ensure all registered widgets have a config entry
    _ensureConfigsComplete();

    // Initial refresh of all enabled widgets
    await _refreshAll();

    // Single timer: every 60s, check which widgets need refresh
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkRefreshes();
    });
  }

  /// Returns enabled configs sorted by sortOrder.
  List<HudWidgetConfig> get enabledConfigs =>
      _configs.where((c) => c.enabled && _widgets.containsKey(c.widgetId)).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  /// All configs (for settings UI). Returns a sorted copy — does not mutate `_configs`.
  List<HudWidgetConfig> get allConfigs {
    final sorted = List.of(_configs)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return List.unmodifiable(sorted);
  }

  /// Get a widget by id.
  HudWidget? getWidget(String id) => _widgets[id];

  /// Number of composed pages.
  int get pageCount => composePages().length;

  /// Compose enabled widget lines into pages of 5 lines each.
  /// Widgets are kept together on the same page when possible.
  /// A `---` separator line is inserted between widgets.
  List<List<String>> composePages() {
    if (_cachedPages != null) return _cachedPages!;

    final enabled = enabledConfigs;
    if (enabled.isEmpty) {
      _cachedPages = [
        ['No widgets enabled', '', 'Go to Settings >', 'HUD Widgets', 'to add some'],
      ];
      return _cachedPages!;
    }

    final pages = <List<String>>[];
    var currentPage = <String>[];

    for (var i = 0; i < enabled.length; i++) {
      final widget = _widgets[enabled[i].widgetId];
      if (widget == null) continue;

      final lines = widget.renderLines();
      if (lines.isEmpty) continue;

      // Need separator between widgets (not before first)
      final needsSeparator = currentPage.isNotEmpty;
      final separatorCost = needsSeparator ? 1 : 0;
      final totalNeeded = lines.length + separatorCost;

      // If adding this widget would overflow, start a new page
      if (currentPage.length + totalNeeded > 5 && currentPage.isNotEmpty) {
        // Pad current page to 5 lines
        while (currentPage.length < 5) {
          currentPage.add('');
        }
        pages.add(currentPage);
        currentPage = [];
      }

      // Add separator if needed
      if (currentPage.isNotEmpty) {
        currentPage.add('---');
      }

      currentPage.addAll(lines);
    }

    // Add final page
    if (currentPage.isNotEmpty) {
      while (currentPage.length < 5) {
        currentPage.add('');
      }
      pages.add(currentPage);
    }

    if (pages.isEmpty) {
      pages.add(['No data available', '', '', '', '']);
    }

    _cachedPages = pages;
    return pages;
  }

  /// Get text for a specific page index.
  String pageText(int pageIndex) {
    final pages = composePages();
    final clamped = pageIndex.clamp(0, pages.length - 1);
    return pages[clamped].join('\n');
  }

  /// Update configs from settings and recompose.
  void updateConfigs(List<HudWidgetConfig> configs) {
    _configs = configs;
    _invalidatePages();
  }

  /// Force refresh a specific widget.
  Future<void> refreshWidget(String widgetId) async {
    final widget = _widgets[widgetId];
    if (widget == null) return;
    try {
      await widget.refresh();
    } catch (_) {}
    _invalidatePages();
  }

  void _invalidatePages() {
    _cachedPages = null;
    _pagesChangedController.add(null);
  }

  void _ensureConfigsComplete() {
    final existingIds = _configs.map((c) => c.widgetId).toSet();
    var maxOrder = _configs.isEmpty
        ? 0
        : _configs.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b);

    for (final widget in _widgets.values) {
      if (!existingIds.contains(widget.id)) {
        maxOrder++;
        // Use the default config's enabled state if available
        final defaultConfig = HudWidgetConfig.defaults
            .where((d) => d.widgetId == widget.id)
            .firstOrNull;
        _configs.add(HudWidgetConfig(
          widgetId: widget.id,
          enabled: defaultConfig?.enabled ?? false,
          sortOrder: maxOrder,
        ));
      }
    }
  }

  Future<void> _refreshAll() async {
    for (final config in enabledConfigs) {
      final widget = _widgets[config.widgetId];
      if (widget == null) continue;
      try {
        await widget.refresh();
      } catch (_) {}
    }
    _invalidatePages();
  }

  void _checkRefreshes() {
    final now = DateTime.now();

    for (final config in enabledConfigs) {
      final widget = _widgets[config.widgetId];
      if (widget == null) continue;

      final lastRefresh = widget.lastRefreshed;
      if (lastRefresh == null ||
          now.difference(lastRefresh) >= widget.refreshInterval) {
        widget.refresh().then((_) {
          _invalidatePages();
        }).catchError((_) {});
      }
    }

    // Always invalidate for time-sensitive widgets (e.g., clock shows current time)
    _invalidatePages();
  }

  void dispose() {
    _refreshTimer?.cancel();
    _pagesChangedController.close();
  }
}
