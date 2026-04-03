import 'dart:async';
import 'dart:typed_data';

import '../ble_manager.dart';
import '../utils/app_logger.dart';
import '../models/dashboard_snapshot.dart';
import 'ble.dart';
import 'conversation_engine.dart';
import 'glasses_protocol.dart';
import 'handoff_memory.dart';
import 'hud_controller.dart';
import 'hud_intent.dart';
import 'bitmap_hud/bitmap_hud_service.dart';
import 'hud_widget_registry.dart';
import 'proto.dart';
import 'settings_manager.dart';

enum DashboardRenderPath {
  fallbackHud,
  nativeDashboard,
  bitmapHud,
  enhancedHud,
}

extension DashboardRenderPathLabel on DashboardRenderPath {
  String get label => switch (this) {
    DashboardRenderPath.fallbackHud => 'Fallback HUD',
    DashboardRenderPath.nativeDashboard => 'Native Dashboard',
    DashboardRenderPath.bitmapHud => 'Bitmap HUD',
    DashboardRenderPath.enhancedHud => 'Enhanced HUD',
  };
}

class DashboardDebugState {
  const DashboardDebugState({
    required this.renderPath,
    this.isActive = false,
    this.lastTriggeredAt,
    this.lastTriggerLabel,
    this.lastTriggerNotifyIndex,
    this.lastObservedEventLabel,
    this.lastObservedEventHex,
    this.lastBlockedReason,
    this.lastSnapshotText = '',
  });

  final DashboardRenderPath renderPath;
  final bool isActive;
  final DateTime? lastTriggeredAt;
  final String? lastTriggerLabel;
  final int? lastTriggerNotifyIndex;
  final String? lastObservedEventLabel;
  final String? lastObservedEventHex;
  final String? lastBlockedReason;
  final String lastSnapshotText;

  static const _sentinel = Object();

  DashboardDebugState copyWith({
    DashboardRenderPath? renderPath,
    bool? isActive,
    Object? lastTriggeredAt = _sentinel,
    Object? lastTriggerLabel = _sentinel,
    Object? lastTriggerNotifyIndex = _sentinel,
    Object? lastObservedEventLabel = _sentinel,
    Object? lastObservedEventHex = _sentinel,
    Object? lastBlockedReason = _sentinel,
    String? lastSnapshotText,
  }) {
    return DashboardDebugState(
      renderPath: renderPath ?? this.renderPath,
      isActive: isActive ?? this.isActive,
      lastTriggeredAt: identical(lastTriggeredAt, _sentinel)
          ? this.lastTriggeredAt
          : lastTriggeredAt as DateTime?,
      lastTriggerLabel: identical(lastTriggerLabel, _sentinel)
          ? this.lastTriggerLabel
          : lastTriggerLabel as String?,
      lastTriggerNotifyIndex: identical(lastTriggerNotifyIndex, _sentinel)
          ? this.lastTriggerNotifyIndex
          : lastTriggerNotifyIndex as int?,
      lastObservedEventLabel: identical(lastObservedEventLabel, _sentinel)
          ? this.lastObservedEventLabel
          : lastObservedEventLabel as String?,
      lastObservedEventHex: identical(lastObservedEventHex, _sentinel)
          ? this.lastObservedEventHex
          : lastObservedEventHex as String?,
      lastBlockedReason: identical(lastBlockedReason, _sentinel)
          ? this.lastBlockedReason
          : lastBlockedReason as String?,
      lastSnapshotText: lastSnapshotText ?? this.lastSnapshotText,
    );
  }
}

typedef DashboardTextRenderer = Future<bool> Function(String text);
typedef DashboardExitRenderer = Future<bool> Function();
typedef BitmapDashboardRenderer = Future<bool> Function();
typedef BitmapDashboardHideRenderer = Future<bool> Function();
typedef BitmapDashboardInvalidator = void Function();
typedef BitmapDashboardVisibilitySetter = void Function(bool visible);

class DashboardService {
  DashboardService({
    BleManager? bleManager,
    HudController? hudController,
    ConversationEngine? conversationEngine,
    HandoffMemory? handoffMemory,
    SettingsManager? settingsManager,
    DashboardTextRenderer? dashboardRenderer,
    DashboardTextRenderer? quickAskRestorer,
    DashboardExitRenderer? exitRenderer,
    BitmapDashboardRenderer? bitmapDeltaRenderer,
    BitmapDashboardRenderer? bitmapFullRenderer,
    BitmapDashboardHideRenderer? bitmapHideRenderer,
    BitmapDashboardInvalidator? bitmapInvalidateCache,
    BitmapDashboardVisibilitySetter? bitmapSetOverlayVisible,
    DateTime Function()? clock,
    this.cooldown = const Duration(seconds: 4),
    this.displayDuration = const Duration(seconds: 5),
    this.activeDisplayDuration = const Duration(seconds: 8),
  }) : _bleManager = bleManager ?? BleManager.get(),
       _hudController = hudController ?? HudController.instance,
       _conversationEngine = conversationEngine ?? ConversationEngine.instance,
       _handoffMemory = handoffMemory ?? HandoffMemory.instance,
       _settingsManager = settingsManager ?? SettingsManager.instance,
       _dashboardRenderer =
           dashboardRenderer ?? DashboardService._renderDashboardText,
       _quickAskRestorer =
           quickAskRestorer ?? DashboardService._restoreQuickAskText,
       _exitRenderer = exitRenderer ?? DashboardService._exitDashboardText,
       _bitmapDeltaRenderer =
           bitmapDeltaRenderer ?? BitmapHudService.instance.pushDelta,
       _bitmapFullRenderer =
           bitmapFullRenderer ?? BitmapHudService.instance.pushFull,
       _bitmapHideRenderer = bitmapHideRenderer ?? Proto.hideDashboard,
       _bitmapInvalidateCache =
           bitmapInvalidateCache ?? BitmapHudService.instance.invalidateCache,
       _bitmapSetOverlayVisible =
           bitmapSetOverlayVisible ?? BitmapHudService.instance.setOverlayVisible,
       _clock = clock ?? DateTime.now;

  static DashboardService? _instance;
  static DashboardService get instance => _instance ??= DashboardService();

  final BleManager _bleManager;
  final HudController _hudController;
  final ConversationEngine _conversationEngine;
  final HandoffMemory _handoffMemory;
  final SettingsManager _settingsManager;
  final DashboardTextRenderer _dashboardRenderer;
  final DashboardTextRenderer _quickAskRestorer;
  final DashboardExitRenderer _exitRenderer;
  final BitmapDashboardRenderer _bitmapDeltaRenderer;
  final BitmapDashboardRenderer _bitmapFullRenderer;
  final BitmapDashboardHideRenderer _bitmapHideRenderer;
  final BitmapDashboardInvalidator _bitmapInvalidateCache;
  final BitmapDashboardVisibilitySetter _bitmapSetOverlayVisible;
  final DateTime Function() _clock;
  final Duration cooldown;
  final Duration displayDuration;
  final Duration activeDisplayDuration;

  /// Returns the effective display duration: extended when in active
  /// conversation (listening/thinking/responding).
  Duration get _effectiveDisplayDuration {
    switch (_engineStatus) {
      case EngineStatus.listening:
      case EngineStatus.thinking:
      case EngineStatus.responding:
        return activeDisplayDuration;
      case EngineStatus.idle:
      case EngineStatus.error:
        return displayDuration;
    }
  }

  final StreamController<DashboardDebugState> _stateController =
      StreamController<DashboardDebugState>.broadcast();

  DashboardDebugState _state = const DashboardDebugState(
    renderPath: DashboardRenderPath.fallbackHud,
  );
  DashboardDebugState get state => _state;
  Stream<DashboardDebugState> get stream => _stateController.stream;

  StreamSubscription<BleDeviceEvent>? _deviceEventSub;
  StreamSubscription<BleConnectionState>? _connectionSub;
  StreamSubscription<EngineStatus>? _statusSub;
  StreamSubscription<ConversationMode>? _modeSub;
  StreamSubscription<String>? _aiResponseSub;
  StreamSubscription<HandoffRecord?>? _handoffSub;
  StreamSubscription<HudRouteState>? _intentSub;
  StreamSubscription<SettingsManager>? _settingsSub;
  StreamSubscription<void>? _widgetPagesSub;

  Timer? _minuteTimer;
  Timer? _hideTimer;
  bool _initialized = false;
  bool _active = false;
  bool _dashboardEnabled = true;
  DateTime? _lastShownAt;
  BleConnectionState _connectionState = BleConnectionState.disconnected;
  ConversationMode _mode = ConversationMode.general;
  EngineStatus _engineStatus = EngineStatus.idle;
  HandoffRecord? _lastHandoff;
  String _lastAiSnippet = '';
  HudIntent _currentIntent = HudIntent.idle;
  HudIntent? _previousIntent;
  String _previousDisplayText = '';

  /// Current page index for multi-page widget dashboard.
  int _currentPageIndex = 0;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    _initialized = true;
    _dashboardEnabled = _settingsManager.dashboardTiltEnabled;
    _connectionState = _bleManager.connectionState;
    _mode = _conversationEngine.mode;
    _engineStatus = _conversationEngine.isActive
        ? EngineStatus.listening
        : EngineStatus.idle;
    _lastHandoff = _handoffMemory.current;
    _currentIntent = _hudController.currentIntent;
    _lastAiSnippet = _latestAssistantSnippet();
    _updateSnapshotState();

    _deviceEventSub = _bleManager.deviceEventStream.listen(handleDeviceEvent);
    _connectionSub = _bleManager.connectionStateStream.listen((state) {
      _connectionState = state;
      _updateSnapshotState(refreshActive: true);
    });
    _statusSub = _conversationEngine.statusStream.listen((status) {
      _engineStatus = status;
      _updateSnapshotState(refreshActive: true);
    });
    _modeSub = _conversationEngine.modeStream.listen((mode) {
      _mode = mode;
      _updateSnapshotState(refreshActive: true);
    });
    _aiResponseSub = _conversationEngine.aiResponseStream.listen((response) {
      final normalized = _normalize(response);
      if (normalized.isNotEmpty) {
        _lastAiSnippet = normalized;
        _updateSnapshotState(refreshActive: true);
      }
    });
    _handoffSub = _handoffMemory.stream.listen((record) {
      _lastHandoff = record;
      _updateSnapshotState(refreshActive: true);
    });
    _intentSub = _hudController.intentStream.listen((route) {
      _currentIntent = route.intent;
      if (_active &&
          route.intent != HudIntent.dashboard &&
          !route.source.startsWith('DashboardService.')) {
        _cancelDashboardState();
      }
    });
    _settingsSub = _settingsManager.onSettingsChanged.listen((settings) {
      _dashboardEnabled = settings.dashboardTiltEnabled;
      if (!_dashboardEnabled && _active) {
        unawaited(hideDashboard(source: 'DashboardService.settingsDisabled'));
      }
    });
    _widgetPagesSub = HudWidgetRegistry.instance.onPagesChanged.listen((_) {
      if (_active && !_isInConversation) {
        unawaited(_renderCurrentWidgetPage());
      }
    });
    _scheduleMinuteBoundary();
  }

  Future<void> previewDashboard() async {
    final syntheticEvent = BleDeviceEvent(
      kind: BleDeviceEventKind.headUp,
      notifyIndex: 2,
      side: 'L',
      data: _bytesFromInts(const [0xF5, 0x02]),
      timestamp: _clock(),
      label: 'preview_dashboard',
    );
    _recordObservedEvent(syntheticEvent);
    await _showDashboard(syntheticEvent);
  }

  Future<void> handleDeviceEvent(BleDeviceEvent event) async {
    await _handleDeviceEvent(event);
  }

  Future<void> hideDashboard({String source = 'DashboardService.hide'}) async {
    if (!_active) {
      return;
    }

    _hideTimer?.cancel();
    _hideTimer = null;

    final previousIntent = _previousIntent ?? HudIntent.idle;
    final previousDisplayText = _previousDisplayText;

    _cancelDashboardState();

    if (_isBitmapMode) {
      _bitmapSetOverlayVisible(false);
      await _restoreBitmapRoute(
        previousIntent: previousIntent,
        previousDisplayText: previousDisplayText,
        source: source,
      );
      _updateSnapshotState(blockedReason: null, activeOverride: false);
      return;
    }

    switch (previousIntent) {
      case HudIntent.quickAsk:
        if (previousDisplayText.trim().isNotEmpty) {
          await _quickAskRestorer(previousDisplayText);
          _hudController.updateDisplay(previousDisplayText);
        } else {
          _hudController.clearDisplay();
        }
        await _hudController.transitionTo(
          HudIntent.quickAsk,
          source: '$source.restoreQuickAsk',
        );
        break;
      case HudIntent.notification:
        await _exitRenderer();
        _hudController.clearDisplay();
        await _hudController.beginNotification(
          source: '$source.restoreNotification',
        );
        break;
      case HudIntent.idle:
      case HudIntent.dashboard:
        await _exitRenderer();
        _hudController.clearDisplay();
        await _hudController.resetToIdle(source: '$source.restoreIdle');
        break;
      case HudIntent.liveListening:
      case HudIntent.textTransfer:
        await _hudController.resetToIdle(source: '$source.restoreIdle');
        break;
    }

    _updateSnapshotState(blockedReason: null, activeOverride: false);
  }

  Future<void> _restoreBitmapRoute({
    required HudIntent previousIntent,
    required String previousDisplayText,
    required String source,
  }) async {
    final shouldClearBitmap =
        previousIntent != HudIntent.quickAsk ||
        previousDisplayText.trim().isEmpty;
    if (shouldClearBitmap) {
      final hideOk = await _bitmapHideRenderer();
      if (!hideOk) {
        emitDeviceDiagnostic('BitmapHUD', 'dashboard hide send failed');
      }
    }

    switch (previousIntent) {
      case HudIntent.quickAsk:
        if (previousDisplayText.trim().isNotEmpty) {
          await _quickAskRestorer(previousDisplayText);
          _hudController.updateDisplay(previousDisplayText);
        } else {
          _hudController.clearDisplay();
        }
        await _hudController.transitionTo(
          HudIntent.quickAsk,
          source: '$source.restoreQuickAsk',
        );
        break;
      case HudIntent.notification:
        _hudController.clearDisplay();
        await _hudController.beginNotification(
          source: '$source.restoreNotification',
        );
        break;
      case HudIntent.idle:
      case HudIntent.dashboard:
        _hudController.clearDisplay();
        await _hudController.resetToIdle(source: '$source.restoreIdle');
        break;
      case HudIntent.liveListening:
      case HudIntent.textTransfer:
        await _hudController.resetToIdle(source: '$source.restoreIdle');
        break;
    }

    // Any bitmap hide that hands off to text/native routes leaves the device
    // frame unknown to the bitmap renderer, so the next bitmap show must
    // rebuild from a full frame.
    _bitmapInvalidateCache();
  }

  void dispose() {
    _minuteTimer?.cancel();
    _hideTimer?.cancel();
    _deviceEventSub?.cancel();
    _connectionSub?.cancel();
    _statusSub?.cancel();
    _modeSub?.cancel();
    _aiResponseSub?.cancel();
    _handoffSub?.cancel();
    _intentSub?.cancel();
    _settingsSub?.cancel();
    _widgetPagesSub?.cancel();
    _stateController.close();
  }

  bool get _isInConversation =>
      _engineStatus == EngineStatus.listening ||
      _engineStatus == EngineStatus.thinking ||
      _engineStatus == EngineStatus.responding;

  Future<void> _handleDeviceEvent(BleDeviceEvent event) async {
    _dashboardEnabled = _settingsManager.dashboardTiltEnabled;
    _recordObservedEvent(event);

    // Handle page navigation when dashboard is active
    if (event.kind == BleDeviceEventKind.pageBack && _active) {
      await _navigatePage(-1);
      return;
    }
    if (event.kind == BleDeviceEventKind.pageForward && _active) {
      await _navigatePage(1);
      return;
    }

    if (!event.isDashboardTrigger) {
      return;
    }

    if (!_dashboardEnabled) {
      _updateSnapshotState(blockedReason: 'Tilt dashboard disabled');
      return;
    }

    if (_active) {
      // In bitmap/enhanced mode, second tilt toggles off
      if (_isBitmapMode) {
        await hideDashboard(source: 'DashboardService.bitmapToggleOff');
        return;
      }
      _updateSnapshotState(blockedReason: 'Dashboard already visible');
      return;
    }

    if (_blocksDashboard(_currentIntent)) {
      _updateSnapshotState(
        blockedReason: 'Blocked while ${_currentIntent.name}',
      );
      return;
    }

    final now = _clock();
    if (_lastShownAt != null && now.difference(_lastShownAt!) < cooldown) {
      _updateSnapshotState(blockedReason: 'Cooldown active');
      return;
    }

    await _showDashboard(event);
  }

  /// Whether a bitmap-based HUD render path is active (bitmap or enhanced).
  bool get _isBitmapMode {
    final path = _settingsManager.hudRenderPath;
    return path == 'bitmap' || path == 'enhanced';
  }

  Future<void> _showDashboard(BleDeviceEvent event) async {
    _currentPageIndex = 0;

    // Bitmap HUD mode: delegate to BitmapHudService for delta push
    if (_isBitmapMode) {
      var pushOk = await _bitmapDeltaRenderer();

      // Retry with full send if delta failed
      if (!pushOk) {
        appLogger.w(
          '[DashboardService] Delta push failed, retrying with full send',
        );
        emitDeviceDiagnostic(
          'BitmapHUD',
          'dashboard delta failed, retrying full send',
        );
        _bitmapInvalidateCache();
        pushOk = await _bitmapFullRenderer();
      }

      if (!pushOk) {
        emitDeviceDiagnostic(
          'BitmapHUD',
          'dashboard full send failed after delta retry',
        );
        _updateSnapshotState(blockedReason: 'Bitmap dashboard push failed');
        return;
      }

      _previousIntent = _currentIntent;
      _previousDisplayText = _hudController.currentDisplayText;
      _lastShownAt = _clock();
      _active = true;

      _bitmapSetOverlayVisible(true);
      _hudController.updateDisplay('[Bitmap HUD]');
      await _hudController.beginDashboard(
        source: 'DashboardService.bitmap.${event.label}',
      );

      _updateSnapshotState(
        activeOverride: true,
        blockedReason: null,
        triggeredEvent: event,
      );

      _hideTimer?.cancel();
      _hideTimer = Timer(_effectiveDisplayDuration, () {
        unawaited(hideDashboard(source: 'DashboardService.autoHide'));
      });
      return;
    }

    // Text HUD mode: original behavior
    // In conversation mode: show conversation stats snapshot.
    // When idle: show widget pages from the registry.
    final String displayText;
    final int totalPages;
    if (_isInConversation) {
      final snapshot = _composeSnapshot(_clock());
      displayText = snapshot.hudText;
      totalPages = 1;
    } else {
      final registry = HudWidgetRegistry.instance;
      displayText = registry.pageText(0);
      totalPages = registry.pageCount;
    }

    final renderOk = await _renderPage(displayText, 1, totalPages);

    if (!renderOk) {
      _updateSnapshotState(blockedReason: 'Dashboard render failed');
      return;
    }

    _previousIntent = _currentIntent;
    _previousDisplayText = _hudController.currentDisplayText;
    _lastShownAt = _clock();
    _active = true;

    _hudController.updateDisplay(displayText);
    await _hudController.beginDashboard(
      source: 'DashboardService.${event.label}',
    );

    _updateSnapshotState(
      activeOverride: true,
      blockedReason: null,
      triggeredEvent: event,
    );

    _hideTimer?.cancel();
    _hideTimer = Timer(_effectiveDisplayDuration, () {
      unawaited(hideDashboard(source: 'DashboardService.autoHide'));
    });
  }

  /// Navigate to a different widget page. Resets the auto-hide timer.
  Future<void> _navigatePage(int delta) async {
    if (_isInConversation) return; // No paging during conversation

    final registry = HudWidgetRegistry.instance;
    final maxPage = registry.pageCount - 1;
    final newIndex = (_currentPageIndex + delta).clamp(0, maxPage);
    if (newIndex == _currentPageIndex) return;

    _currentPageIndex = newIndex;
    await _renderCurrentWidgetPage();

    // Guard: dashboard may have been hidden during the async render
    if (!_active) return;

    // Reset auto-hide timer on page navigation
    _hideTimer?.cancel();
    _hideTimer = Timer(_effectiveDisplayDuration, () {
      unawaited(hideDashboard(source: 'DashboardService.autoHide'));
    });
  }

  /// Render the current widget page to the glasses.
  Future<void> _renderCurrentWidgetPage() async {
    if (!_active) return;

    final registry = HudWidgetRegistry.instance;
    final text = registry.pageText(_currentPageIndex);
    final totalPages = registry.pageCount;

    final renderOk = await _renderPage(text, _currentPageIndex + 1, totalPages);
    if (renderOk) {
      _hudController.updateDisplay(text);
      _updateSnapshotState(activeOverride: true, blockedReason: null);
    }
  }

  /// Send a page of text to the glasses with page number indicators.
  Future<bool> _renderPage(String text, int pageNum, int maxPages) {
    if (pageNum == 1 && maxPages == 1) {
      // Use injectable renderer for single-page (keeps tests working)
      return _dashboardRenderer(text);
    }
    return Proto.sendEvenAIData(
      text,
      newScreen: HudDisplayState.dashboardCard(),
      pos: 0,
      current_page_num: pageNum,
      max_page_num: maxPages,
    );
  }

  void _scheduleMinuteBoundary() {
    _minuteTimer?.cancel();
    final now = _clock();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _minuteTimer = Timer(nextMinute.difference(now), () {
      _updateSnapshotState(refreshActive: true);
      _scheduleMinuteBoundary();
    });
  }

  Future<void> _refreshDashboardIfActive() async {
    if (!_active) {
      return;
    }

    if (_isInConversation) {
      // Refresh conversation stats snapshot
      final snapshot = _composeSnapshot(_clock());
      final renderOk = await _renderPage(snapshot.hudText, 1, 1);
      if (!renderOk) {
        _updateSnapshotState(blockedReason: 'Dashboard refresh failed');
        return;
      }
      _hudController.updateDisplay(snapshot.hudText);
    } else {
      // Refresh widget page
      await _renderCurrentWidgetPage();
      return;
    }
    _updateSnapshotState(activeOverride: true, blockedReason: null);
  }

  void _updateSnapshotState({
    bool refreshActive = false,
    bool? activeOverride,
    String? blockedReason,
    BleDeviceEvent? triggeredEvent,
  }) {
    final snapshot = _composeSnapshot(_clock());
    _state = _state.copyWith(
      isActive: activeOverride ?? _active,
      lastTriggeredAt:
          triggeredEvent?.timestamp ?? DashboardDebugState._sentinel,
      lastTriggerLabel: triggeredEvent?.label ?? DashboardDebugState._sentinel,
      lastTriggerNotifyIndex:
          triggeredEvent?.notifyIndex ?? DashboardDebugState._sentinel,
      lastBlockedReason: blockedReason,
      lastSnapshotText: snapshot.hudText,
    );
    _stateController.add(_state);

    if (refreshActive) {
      unawaited(_refreshDashboardIfActive());
    }
  }

  void _recordObservedEvent(BleDeviceEvent event) {
    _state = _state.copyWith(
      lastObservedEventLabel: event.label,
      lastObservedEventHex: _bytesToHex(event.data),
    );
    _stateController.add(_state);
  }

  DateTime? _recordingStartedAt;

  DashboardSnapshot _composeSnapshot(DateTime now) {
    final history = _conversationEngine.history;
    final isRecording = _conversationEngine.isActive;

    // Track recording start time
    if (isRecording && _recordingStartedAt == null) {
      _recordingStartedAt = now;
    } else if (!isRecording) {
      _recordingStartedAt = null;
    }

    final Duration? recDuration = isRecording && _recordingStartedAt != null
        ? now.difference(_recordingStartedAt!)
        : null;

    final questionCount = history.where((t) => t.role == 'user').length;
    final answerCount = history.where((t) => t.role == 'assistant').length;
    final wordCount = history.fold<int>(
      0,
      (sum, t) =>
          sum +
          t.content.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length,
    );

    return DashboardSnapshot(
      timestamp: now,
      connectionState: _connectionState,
      mode: _mode,
      engineStatus: _engineStatus,
      contextLine: _buildContextLine(),
      recordingDuration: recDuration,
      questionCount: questionCount,
      answerCount: answerCount,
      wordCount: wordCount,
      segmentCount: _conversationEngine.transcriptStats.segmentCount,
    );
  }

  String _buildContextLine() {
    // Contextual status based on engine state
    return switch (_engineStatus) {
      EngineStatus.thinking => 'THINKING...',
      EngineStatus.responding => 'RESPONDING...',
      EngineStatus.listening =>
        _lastUserQuestion().isNotEmpty
            ? _lastUserQuestion()
            : 'Listening for speech',
      EngineStatus.error => 'Assistant needs attention',
      EngineStatus.idle => _idleContextLine(),
    };
  }

  String _idleContextLine() {
    final handoff = _lastHandoff;
    if (handoff != null) {
      final prefix = switch (handoff.status) {
        HandoffStatus.pending => 'HUD ',
        HandoffStatus.delivered => 'LAST ',
        HandoffStatus.failed => 'FAIL ',
      };
      return '$prefix${handoff.preview}';
    }

    if (_lastAiSnippet.isNotEmpty) {
      return 'AI $_lastAiSnippet';
    }

    return 'Ready';
  }

  String _lastUserQuestion() {
    for (final turn in _conversationEngine.history.reversed) {
      if (turn.role == 'user') {
        return _normalize(turn.content);
      }
    }
    return '';
  }

  String _latestAssistantSnippet() {
    for (final turn in _conversationEngine.history.reversed) {
      if (turn.role == 'assistant') {
        final normalized = _normalize(turn.content);
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }
    return '';
  }

  bool _blocksDashboard(HudIntent intent) {
    return intent == HudIntent.textTransfer ||
        intent == HudIntent.liveListening;
  }

  void _cancelDashboardState() {
    _active = false;
    _previousIntent = null;
    _previousDisplayText = '';
    _currentPageIndex = 0;
  }

  static Future<bool> _renderDashboardText(String text) {
    return Proto.sendEvenAIData(
      text,
      newScreen: HudDisplayState.dashboardCard(),
      pos: 0,
      current_page_num: 1,
      max_page_num: 1,
    );
  }

  static Future<bool> _restoreQuickAskText(String text) {
    return Proto.sendEvenAIData(
      text,
      newScreen: HudDisplayState.aiFrame(isStreaming: false),
      pos: 0,
      current_page_num: 1,
      max_page_num: 1,
    );
  }

  static Future<bool> _exitDashboardText() {
    return Proto.exit();
  }

  static String _normalize(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= DashboardSnapshot.lineWidth - 3) {
      return normalized;
    }
    return '${normalized.substring(0, DashboardSnapshot.lineWidth - 6)}...';
  }

  static Uint8List _bytesFromInts(List<int> values) {
    return Uint8List.fromList(values);
  }

  static String _bytesToHex(Uint8List value) {
    return value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
