import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../controllers/bmp_update_manager.dart';
import '../../ble_manager.dart';
import '../ble.dart';
import '../settings_manager.dart';
import '../../utils/app_logger.dart';
import 'bitmap_renderer.dart';
import 'bmp_encoder.dart';
import 'bmp_widget.dart';
import 'delta_encoder.dart';
import 'display_constants.dart';
import 'enhanced_layout_presets.dart';
import 'enhanced_widgets/bmp_activity_widget.dart';
import 'enhanced_widgets/bmp_enhanced_calendar_widget.dart';
import 'enhanced_widgets/bmp_enhanced_footer_widget.dart';
import 'enhanced_widgets/bmp_enhanced_header_widget.dart';
import 'enhanced_widgets/bmp_enhanced_stock_widget.dart';
import 'enhanced_widgets/bmp_news_widget.dart';
import 'enhanced_widgets/bmp_system_widget.dart';
import 'enhanced_widgets/bmp_todos_widget.dart';
import 'hud_layout_presets.dart';
import 'widgets/bmp_battery_widget.dart';
import 'widgets/bmp_calendar_widget.dart';
import 'widgets/bmp_clock_widget.dart';
import 'widgets/bmp_notification_widget.dart';
import 'widgets/bmp_stock_widget.dart';
import 'widgets/bmp_weather_widget.dart';

/// Orchestrates the bitmap HUD: widget management, rendering, and BLE delivery.
///
/// Usage:
/// 1. Call [initialize] once at app startup.
/// 2. The service automatically pushes a full BMP on BLE connect.
/// 3. Periodic delta updates refresh the display every 1-2 minutes.
class BitmapHudService {
  BitmapHudService._({
    Future<Uint8List> Function(HudLayout, Map<String, BmpWidget>)? renderer,
    Future<bool> Function(Uint8List)? fullSender,
    Future<bool> Function(Uint8List, List<int>)? deltaSender,
    bool Function()? isConnectedChecker,
  }) : _renderer = renderer,
       _fullSender = fullSender,
       _deltaSender = deltaSender,
       _isConnectedChecker = isConnectedChecker;

  static BitmapHudService? _instance;
  static BitmapHudService get instance => _instance ??= BitmapHudService._();
  static final Uint8List _blankBmp = _buildBlankBmp();

  @visibleForTesting
  factory BitmapHudService.test({
    required HudLayout layout,
    required Map<String, BmpWidget> zoneWidgets,
    Uint8List? lastSentBmp,
    Future<Uint8List> Function(HudLayout, Map<String, BmpWidget>)? renderer,
    Future<bool> Function(Uint8List)? fullSender,
    Future<bool> Function(Uint8List, List<int>)? deltaSender,
    bool Function()? isConnectedChecker,
  }) {
    final service = BitmapHudService._(
      renderer: renderer,
      fullSender: fullSender,
      deltaSender: deltaSender,
      isConnectedChecker: isConnectedChecker,
    );
    service._activeLayout = layout;
    service._zoneWidgets = Map<String, BmpWidget>.from(zoneWidgets);
    service._lastSentBmp = lastSentBmp;
    return service;
  }

  final Map<String, BmpWidget> _widgets = {};
  HudLayout _activeLayout = HudLayoutPresets.classic();
  Map<String, BmpWidget> _zoneWidgets = {};
  final Future<Uint8List> Function(HudLayout, Map<String, BmpWidget>)?
  _renderer;
  final Future<bool> Function(Uint8List)? _fullSender;
  final Future<bool> Function(Uint8List, List<int>)? _deltaSender;
  final bool Function()? _isConnectedChecker;

  /// Cached last-sent BMP for delta comparison.
  Uint8List? _lastSentBmp;

  Timer? _refreshTimer;
  StreamSubscription<BleConnectionState>? _connectionSub;
  StreamSubscription<SettingsManager>? _settingsSub;
  bool _initialized = false;
  bool _sending = false;
  _PendingBitmapSend? _pendingSend;
  final List<Completer<bool>> _pendingSendWaiters = [];

  /// Adaptive refresh interval: starts at 60s, doubles on no-change deltas
  /// (up to 300s), resets to 60s when a widget reports dirty.
  int _currentRefreshIntervalSeconds = 60;
  static const int _minRefreshInterval = 60;
  static const int _maxRefreshInterval = 300;

  /// Whether bitmap refresh is paused during active conversation.
  bool _conversationPaused = false;

  /// Whether bitmap HUD mode is active (bitmap or enhanced).
  bool get isEnabled {
    final path = SettingsManager.instance.hudRenderPath;
    return path == 'bitmap' || path == 'enhanced';
  }

  /// Whether the enhanced HUD variant is active.
  bool get _isEnhancedMode =>
      SettingsManager.instance.hudRenderPath == 'enhanced';

  /// Initialize the bitmap HUD service. Registers widgets and starts timers.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register widgets based on render mode
    _registerAllWidgets();

    // Load active layout
    _loadLayout();

    // Initial refresh only when bitmap mode is active
    if (isEnabled) {
      await _refreshAllWidgets();
    }

    // Listen for BLE connection to auto-push on connect
    _connectionSub = BleManager.get().connectionStateStream.listen((state) {
      if (state == BleConnectionState.connected &&
          isEnabled &&
          _hasConnectedSide()) {
        // Delay slightly to let glasses initialize
        Future.delayed(const Duration(seconds: 3), () {
          if (isEnabled && _hasConnectedSide()) {
            pushFull();
          }
        });
      }
    });

    // Listen for settings changes (layout, render path, stock ticker)
    _settingsSub = SettingsManager.instance.onSettingsChanged.listen((_) {
      _onSettingsChanged();
    });

    // Adaptive periodic refresh timer
    _startAdaptiveRefreshTimer();
  }

  void _startAdaptiveRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(
      Duration(seconds: _currentRefreshIntervalSeconds),
      () {
        if (isEnabled && _hasConnectedSide() && !_conversationPaused) {
          pushDelta();
        }
        // Re-schedule (interval may have changed after pushDelta).
        _startAdaptiveRefreshTimer();
      },
    );
  }

  /// Pause bitmap refresh during active conversation (text HUD takes
  /// precedence). Call with `true` when conversation starts, `false` when
  /// it stops.
  void setConversationActive(bool active) {
    _conversationPaused = active;
    if (!active && isEnabled && _hasConnectedSide()) {
      // Reset to base interval and push immediately on resume.
      _currentRefreshIntervalSeconds = _minRefreshInterval;
      _startAdaptiveRefreshTimer();
      pushDelta();
    }
  }

  void _registerWidget(BmpWidget widget) {
    _widgets[widget.id] = widget;
  }

  void _registerAllWidgets() {
    _widgets.clear();
    // Always register basic bitmap widgets
    _registerWidget(BmpClockWidget());
    _registerWidget(BmpWeatherWidget());
    _registerWidget(BmpCalendarWidget());
    _registerWidget(
      BmpStockWidget(symbol: SettingsManager.instance.stockTicker),
    );
    _registerWidget(BmpNotificationWidget());
    _registerWidget(BmpBatteryWidget());

    // Register enhanced widgets (available in both modes for flexibility)
    _registerWidget(BmpEnhancedHeaderWidget());
    _registerWidget(BmpEnhancedFooterWidget());
    _registerWidget(
      BmpEnhancedStockWidget(symbol: SettingsManager.instance.stockTicker),
    );
    _registerWidget(BmpEnhancedCalendarWidget());
    _registerWidget(BmpActivityWidget());
    _registerWidget(BmpNewsWidget());
    _registerWidget(BmpTodosWidget());
    _registerWidget(BmpSystemWidget());
  }

  void _loadLayout() {
    if (_isEnhancedMode) {
      final presetId = SettingsManager.instance.enhancedLayoutPreset;
      _activeLayout = EnhancedLayoutPresets.byId(presetId);
    } else {
      final presetId = SettingsManager.instance.bitmapLayoutPreset;
      _activeLayout = HudLayoutPresets.byId(presetId);
    }
    _rebuildZoneWidgets();
  }

  void _rebuildZoneWidgets() {
    _zoneWidgets = {};
    for (final zone in _activeLayout.zones) {
      final widgetId = _activeLayout.defaultWidgetAssignments[zone.id];
      final widget = widgetId != null ? _widgets[widgetId] : null;
      if (widget != null) {
        _zoneWidgets[zone.id] = widget;
      }
    }
  }

  void _onSettingsChanged() {
    final settings = SettingsManager.instance;

    // Update stock ticker if changed
    bool stockUpdated = false;
    final stockWidget = _widgets['bmp_stock'];
    if (stockWidget is BmpStockWidget &&
        stockWidget.symbol != settings.stockTicker) {
      _widgets['bmp_stock'] = BmpStockWidget(symbol: settings.stockTicker);
      stockUpdated = true;
    }
    final enhStockWidget = _widgets['enh_stock'];
    if (enhStockWidget is BmpEnhancedStockWidget &&
        enhStockWidget.symbol != settings.stockTicker) {
      _widgets['enh_stock'] = BmpEnhancedStockWidget(
        symbol: settings.stockTicker,
      );
      stockUpdated = true;
    }
    if (stockUpdated) {
      _rebuildZoneWidgets();
    }

    // Reload layout if changed (check both bitmap and enhanced presets)
    final currentPreset = _activeLayout.id;
    final targetPreset = _isEnhancedMode
        ? settings.enhancedLayoutPreset
        : settings.bitmapLayoutPreset;
    if (targetPreset != currentPreset) {
      _loadLayout();
      // Force full re-push on layout change
      if (isEnabled && _hasConnectedSide()) {
        _lastSentBmp = null;
        pushFull();
      }
    }
  }

  Future<void> _refreshAllWidgets() async {
    for (final entry in _zoneWidgets.entries) {
      try {
        await entry.value.refresh();
      } catch (e) {
        appLogger.w('BitmapHud: widget "${entry.key}" refresh failed: $e');
      }
    }
  }

  /// Refresh only stale widgets (past their refresh interval).
  ///
  /// Tracks whether any widget was refreshed and whether any widget is dirty.
  Future<_WidgetRefreshState> _refreshStaleWidgets() async {
    final now = DateTime.now();
    bool refreshedAny = false;
    bool anyDirty = _zoneWidgets.values.any((widget) => widget.isDirty);

    for (final entry in _zoneWidgets.entries) {
      final widget = entry.value;
      final last = widget.lastRefreshed;
      if (last == null || now.difference(last) >= widget.refreshInterval) {
        refreshedAny = true;
        try {
          await widget.refresh();
          if (widget.isDirty) anyDirty = true;
        } catch (e) {
          appLogger.w('BitmapHud: widget "${entry.key}" refresh failed: $e');
        }
      }
    }

    return _WidgetRefreshState(refreshedAny: refreshedAny, anyDirty: anyDirty);
  }

  /// Render the current dashboard to BMP bytes.
  Future<Uint8List> renderDashboard() async {
    final renderer = _renderer;
    if (renderer != null) {
      return renderer(_activeLayout, _zoneWidgets);
    }
    return BitmapRenderer.render(_activeLayout, _zoneWidgets);
  }

  /// Full BMP send: render and push all chunks to both glasses.
  Future<bool> pushFull() async {
    return _requestSend(_PendingBitmapSend.full);
  }

  /// Internal full push that assumes caller manages the send loop.
  Future<bool> _performFullPush() async {
    try {
      await _refreshAllWidgets();
      final bmpData = await renderDashboard();

      final success = await _sendFull(bmpData);
      if (success) {
        _lastSentBmp = bmpData;
        _clearDirtyFlags();
        appLogger.d(
          'BitmapHud: full push complete '
          '(${bmpData.length} bytes)',
        );
      }
      return success;
    } catch (e) {
      appLogger.e('BitmapHud: full push error: $e');
      emitDeviceDiagnostic('BitmapHUD', 'full push exception=$e');
      return false;
    }
  }

  /// Delta BMP send: refresh stale widgets, render, diff, send changed chunks.
  ///
  /// Falls back to full send if no previous frame is cached or if delta fails.
  /// Uses dirty-flag rendering: if no widget reports dirty after refresh,
  /// [renderDashboard] is skipped entirely and the refresh interval is doubled
  /// (up to [_maxRefreshInterval]).
  Future<bool> pushDelta() async {
    return _requestSend(_PendingBitmapSend.delta);
  }

  /// Clear the bitmap HUD by pushing a blank frame and aligning the cache to it.
  Future<bool> clearDisplay() async {
    return _requestSend(_PendingBitmapSend.blank);
  }

  Future<bool> _performDeltaPush() async {
    try {
      if (_lastSentBmp == null) {
        return _performFullPush();
      }

      final refreshState = await _refreshStaleWidgets();

      // If nothing refreshed and no widget is marked dirty, skip rendering.
      if (!refreshState.refreshedAny && !refreshState.anyDirty) {
        appLogger.d('BitmapHud: no widget dirty, skipping render');
        _currentRefreshIntervalSeconds = (_currentRefreshIntervalSeconds * 2)
            .clamp(_minRefreshInterval, _maxRefreshInterval);
        return true;
      }

      // At least one widget changed — reset to base interval.
      _currentRefreshIntervalSeconds = _minRefreshInterval;

      final newBmp = await renderDashboard();
      final changedIndices = DeltaEncoder.diff(_lastSentBmp!, newBmp);

      if (changedIndices.isEmpty) {
        _clearDirtyFlags();
        appLogger.d('BitmapHud: no pixel changes, skipping send');
        return true;
      }

      final total =
          (newBmp.length + DeltaEncoder.chunkSize - 1) ~/
          DeltaEncoder.chunkSize;
      appLogger.d('BitmapHud: delta ${changedIndices.length}/$total chunks');

      final success = await _sendDelta(newBmp, changedIndices);

      if (success) {
        _lastSentBmp = newBmp;
        _clearDirtyFlags();
        return true;
      }

      // Delta failed — fall back to full send (keep lock held)
      appLogger.w('BitmapHud: delta failed, falling back to full send');
      final fullSuccess = await _sendFull(newBmp);
      if (fullSuccess) {
        _lastSentBmp = newBmp;
        _clearDirtyFlags();
      }
      return fullSuccess;
    } catch (e) {
      appLogger.e('BitmapHud: delta push error: $e');
      emitDeviceDiagnostic('BitmapHUD', 'delta push exception=$e');
      return false;
    }
  }

  Future<bool> _performBlankPush() async {
    try {
      if (_lastSentBmp != null) {
        final changedIndices = DeltaEncoder.diff(_lastSentBmp!, _blankBmp);
        if (changedIndices.isEmpty) {
          _lastSentBmp = _blankBmp;
          _clearDirtyFlags();
          appLogger.d('BitmapHud: clear skipped, frame already blank');
          return true;
        }

        final deltaSuccess = await _sendDelta(_blankBmp, changedIndices);
        if (deltaSuccess) {
          _lastSentBmp = _blankBmp;
          _clearDirtyFlags();
          appLogger.d(
            'BitmapHud: cleared display via delta '
            '(${changedIndices.length} chunks)',
          );
          return true;
        }

        appLogger.w('BitmapHud: blank delta failed, falling back to full send');
      }

      final fullSuccess = await _sendFull(_blankBmp);
      if (fullSuccess) {
        _lastSentBmp = _blankBmp;
        _clearDirtyFlags();
        appLogger.d('BitmapHud: cleared display via full push');
      }
      return fullSuccess;
    } catch (e) {
      appLogger.e('BitmapHud: clear display error: $e');
      emitDeviceDiagnostic('BitmapHUD', 'clear display exception=$e');
      return false;
    }
  }

  Future<bool> _requestSend(_PendingBitmapSend requestedSend) async {
    if (!_isConnected()) {
      final message =
          '${requestedSend.name} skipped no connected side '
          'left=${BleManager.isConnectedL()} right=${BleManager.isConnectedR()}';
      appLogger.d('BitmapHud: $message');
      emitDeviceDiagnostic('BitmapHUD', message);
      return false;
    }

    final completer = Completer<bool>();
    _pendingSend = _mergePendingSend(_pendingSend, requestedSend);
    _pendingSendWaiters.add(completer);

    if (_sending) {
      final message =
          'queued ${requestedSend.name} send while send already in progress';
      appLogger.d('BitmapHud: $message');
      emitDeviceDiagnostic('BitmapHUD', message);
      return completer.future;
    }

    unawaited(_drainPendingSends());
    return completer.future;
  }

  Future<void> _drainPendingSends() async {
    if (_sending) {
      return;
    }

    _sending = true;
    try {
      while (_pendingSend != null) {
        final send = _pendingSend!;
        final waiters = List<Completer<bool>>.from(_pendingSendWaiters);
        _pendingSend = null;
        _pendingSendWaiters.clear();

        final success = switch (send) {
          _PendingBitmapSend.full => await _performFullPush(),
          _PendingBitmapSend.delta => await _performDeltaPush(),
          _PendingBitmapSend.blank => await _performBlankPush(),
        };

        for (final waiter in waiters) {
          if (!waiter.isCompleted) {
            waiter.complete(success);
          }
        }
      }
    } finally {
      _sending = false;
      if (_pendingSend != null) {
        unawaited(_drainPendingSends());
      }
    }
  }

  /// Force invalidate the cached frame (next refresh will do a full send).
  void invalidateCache() {
    _lastSentBmp = null;
  }

  /// Get a registered widget by ID.
  BmpWidget? getWidget(String id) => _widgets[id];

  /// Set the notification count on the notification widget.
  void setNotificationCount(int count) {
    final w = _widgets['bmp_notification'];
    if (w is BmpNotificationWidget) w.setCount(count);
  }

  /// Set the battery level on the battery widget.
  void setBatteryLevel(double level) {
    final w = _widgets['bmp_battery'];
    if (w is BmpBatteryWidget) w.setLevel(level);
  }

  void dispose() {
    _refreshTimer?.cancel();
    _connectionSub?.cancel();
    _settingsSub?.cancel();
  }

  bool _isConnected() => _isConnectedChecker?.call() ?? _hasConnectedSide();

  bool _hasConnectedSide() =>
      BleManager.isConnectedL() || BleManager.isConnectedR();

  Future<bool> _sendFull(Uint8List bmpData) {
    final sender = _fullSender;
    if (sender != null) {
      return sender(bmpData);
    }
    return BmpUpdateManager.sendBitmapHud(bmpData);
  }

  Future<bool> _sendDelta(Uint8List bmpData, List<int> changedIndices) {
    final sender = _deltaSender;
    if (sender != null) {
      return sender(bmpData, changedIndices);
    }
    return BmpUpdateManager.sendBitmapHudDelta(bmpData, changedIndices);
  }

  void _clearDirtyFlags() {
    for (final widget in _zoneWidgets.values) {
      widget.isDirty = false;
    }
  }

  static Uint8List _buildBlankBmp() {
    final rgba = Uint8List(G1Display.bitmapWidth * G1Display.bitmapHeight * 4);
    for (var i = 0; i < rgba.length; i += 4) {
      rgba[i] = 0xff;
      rgba[i + 1] = 0xff;
      rgba[i + 2] = 0xff;
      rgba[i + 3] = 0xff;
    }
    return BmpEncoder.fromRgba(
      ByteData.sublistView(rgba),
      G1Display.bitmapWidth,
      G1Display.bitmapHeight,
    );
  }
}

enum _PendingBitmapSend { delta, full, blank }

_PendingBitmapSend _mergePendingSend(
  _PendingBitmapSend? current,
  _PendingBitmapSend next,
) {
  if (next == _PendingBitmapSend.blank) {
    return _PendingBitmapSend.blank;
  }
  if (next == _PendingBitmapSend.full) {
    return _PendingBitmapSend.full;
  }
  if (current == _PendingBitmapSend.blank) {
    return _PendingBitmapSend.blank;
  }
  if (current == _PendingBitmapSend.full) {
    return _PendingBitmapSend.full;
  }
  return _PendingBitmapSend.delta;
}

class _WidgetRefreshState {
  const _WidgetRefreshState({
    required this.refreshedAny,
    required this.anyDirty,
  });

  final bool refreshedAny;
  final bool anyDirty;
}
