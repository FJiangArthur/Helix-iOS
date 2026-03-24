import 'dart:async';
import 'dart:typed_data';

import '../../controllers/bmp_update_manager.dart';
import '../../ble_manager.dart';
import '../ble.dart';
import '../settings_manager.dart';
import '../../utils/app_logger.dart';
import 'bitmap_renderer.dart';
import 'bmp_widget.dart';
import 'delta_encoder.dart';
import 'display_constants.dart';
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
  BitmapHudService._();

  static BitmapHudService? _instance;
  static BitmapHudService get instance => _instance ??= BitmapHudService._();

  final Map<String, BmpWidget> _widgets = {};
  HudLayout _activeLayout = HudLayoutPresets.classic();
  Map<String, BmpWidget> _zoneWidgets = {};

  /// Cached last-sent BMP for delta comparison.
  Uint8List? _lastSentBmp;

  Timer? _refreshTimer;
  StreamSubscription<BleConnectionState>? _connectionSub;
  StreamSubscription<SettingsManager>? _settingsSub;
  bool _initialized = false;
  bool _sending = false;

  /// Whether bitmap HUD mode is active (vs text HUD).
  bool get isEnabled =>
      SettingsManager.instance.hudRenderPath == 'bitmap';

  /// Initialize the bitmap HUD service. Registers widgets and starts timers.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // Register all bitmap widgets
    _registerWidget(BmpClockWidget());
    _registerWidget(BmpWeatherWidget());
    _registerWidget(BmpCalendarWidget());
    _registerWidget(BmpStockWidget(
        symbol: SettingsManager.instance.stockTicker));
    _registerWidget(BmpNotificationWidget());
    _registerWidget(BmpBatteryWidget());

    // Load active layout
    _loadLayout();

    // Initial refresh only when bitmap mode is active
    if (isEnabled) {
      await _refreshAllWidgets();
    }

    // Listen for BLE connection to auto-push on connect
    _connectionSub = BleManager.get().connectionStateStream.listen((state) {
      if (state == BleConnectionState.connected && isEnabled) {
        // Delay slightly to let glasses initialize
        Future.delayed(const Duration(seconds: 3), () {
          if (isEnabled && BleManager.get().isConnected) {
            pushFull();
          }
        });
      }
    });

    // Listen for settings changes (layout, render path, stock ticker)
    _settingsSub = SettingsManager.instance.onSettingsChanged.listen((_) {
      _onSettingsChanged();
    });

    // Periodic refresh timer (every 60 seconds)
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (isEnabled && BleManager.get().isConnected) {
        pushDelta();
      }
    });
  }

  void _registerWidget(BmpWidget widget) {
    _widgets[widget.id] = widget;
  }

  void _loadLayout() {
    final presetId = SettingsManager.instance.bitmapLayoutPreset;
    _activeLayout = HudLayoutPresets.byId(presetId);
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
    final stockWidget = _widgets['bmp_stock'];
    if (stockWidget is BmpStockWidget &&
        stockWidget.symbol != settings.stockTicker) {
      _widgets['bmp_stock'] = BmpStockWidget(symbol: settings.stockTicker);
    }

    // Reload layout if changed
    final currentPreset = _activeLayout.id;
    if (settings.bitmapLayoutPreset != currentPreset) {
      _loadLayout();
      // Force full re-push on layout change
      if (isEnabled && BleManager.get().isConnected) {
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
  Future<bool> _refreshStaleWidgets() async {
    final now = DateTime.now();
    bool anyRefreshed = false;

    for (final entry in _zoneWidgets.entries) {
      final widget = entry.value;
      final last = widget.lastRefreshed;
      if (last == null || now.difference(last) >= widget.refreshInterval) {
        try {
          await widget.refresh();
          anyRefreshed = true;
        } catch (e) {
          appLogger.w('BitmapHud: widget "${entry.key}" refresh failed: $e');
        }
      }
    }

    return anyRefreshed;
  }

  /// Render the current dashboard to BMP bytes.
  Future<Uint8List> renderDashboard() async {
    return BitmapRenderer.render(_activeLayout, _zoneWidgets);
  }

  /// Full BMP send: render and push all chunks to both glasses.
  Future<bool> pushFull() async {
    if (_sending) return false;
    return _pushFullLocked();
  }

  /// Internal full push that assumes caller manages _sending lock.
  Future<bool> _pushFullLocked() async {
    _sending = true;
    try {
      await _refreshAllWidgets();
      final bmpData = await renderDashboard();

      final success = await BmpUpdateManager.sendBitmapHud(bmpData);
      if (success) {
        _lastSentBmp = bmpData;
        appLogger.d('BitmapHud: full push complete '
            '(${bmpData.length} bytes)');
      }
      return success;
    } catch (e) {
      appLogger.e('BitmapHud: full push error: $e');
      return false;
    } finally {
      _sending = false;
    }
  }

  /// Delta BMP send: refresh stale widgets, render, diff, send changed chunks.
  ///
  /// Falls back to full send if no previous frame is cached or if delta fails.
  Future<bool> pushDelta() async {
    if (_sending) return false;
    if (_lastSentBmp == null) return _pushFullLocked();

    _sending = true;

    try {
      await _refreshStaleWidgets();
      final newBmp = await renderDashboard();
      final changedIndices = DeltaEncoder.diff(_lastSentBmp!, newBmp);

      if (changedIndices.isEmpty) {
        appLogger.d('BitmapHud: no changes, skipping send');
        return true;
      }

      final total =
          (newBmp.length + DeltaEncoder.chunkSize - 1) ~/ DeltaEncoder.chunkSize;
      appLogger.d('BitmapHud: delta ${changedIndices.length}/$total chunks');

      final success =
          await BmpUpdateManager.sendBitmapHudDelta(newBmp, changedIndices);

      if (success) {
        _lastSentBmp = newBmp;
        return true;
      }

      // Delta failed — fall back to full send (keep lock held)
      appLogger.w('BitmapHud: delta failed, falling back to full send');
      final bmpData = await renderDashboard();
      final fullSuccess = await BmpUpdateManager.sendBitmapHud(bmpData);
      if (fullSuccess) _lastSentBmp = bmpData;
      return fullSuccess;
    } catch (e) {
      appLogger.e('BitmapHud: delta push error: $e');
      return false;
    } finally {
      _sending = false;
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
}
