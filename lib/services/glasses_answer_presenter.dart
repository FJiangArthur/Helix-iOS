import 'dart:async';

import '../ble_manager.dart';
import '../utils/app_logger.dart';
import 'glasses_protocol.dart';
import 'hud_controller.dart';
import 'proto.dart';
import 'text_paginator.dart';
import 'text_service.dart';

typedef GlassesAnswerWindowSender =
    Future<bool> Function(String text, int currentWindow, int totalWindows);

enum GlassesAnswerDeliveryStatus {
  idle,
  preparing,
  delivering,
  delivered,
  failed,
}

class GlassesAnswerDeliveryState {
  const GlassesAnswerDeliveryState({
    required this.status,
    required this.answerText,
    required this.currentWindow,
    required this.totalWindows,
    this.note,
  });

  const GlassesAnswerDeliveryState.idle()
    : status = GlassesAnswerDeliveryStatus.idle,
      answerText = '',
      currentWindow = 0,
      totalWindows = 0,
      note = null;

  final GlassesAnswerDeliveryStatus status;
  final String answerText;
  final int currentWindow;
  final int totalWindows;
  final String? note;

  bool get isActive =>
      status == GlassesAnswerDeliveryStatus.preparing ||
      status == GlassesAnswerDeliveryStatus.delivering;
}

class GlassesAnswerPresenter {
  GlassesAnswerPresenter({
    TextPaginator? paginator,
    GlassesAnswerWindowSender? sender,
    Duration cadence = const Duration(seconds: 1),
    HudController? hudController,
    Future<void> Function()? prepareDelivery,
    Future<void> Function(String source)? beginTextTransfer,
    Future<void> Function(String source)? resetToIdle,
  }) : _paginator = paginator ?? TextPaginator.instance,
       _sender = sender ?? _defaultSender,
       _cadence = cadence,
       _hudController = hudController ?? HudController.instance,
       _prepareDelivery = prepareDelivery,
       _beginTextTransfer = beginTextTransfer,
       _resetToIdle = resetToIdle;

  static GlassesAnswerPresenter? _instance;
  static GlassesAnswerPresenter get instance =>
      _instance ??= GlassesAnswerPresenter();

  final TextPaginator _paginator;
  final GlassesAnswerWindowSender _sender;
  final Duration _cadence;
  final HudController _hudController;
  final Future<void> Function()? _prepareDelivery;
  final Future<void> Function(String source)? _beginTextTransfer;
  final Future<void> Function(String source)? _resetToIdle;
  final StreamController<GlassesAnswerDeliveryState> _stateController =
      StreamController<GlassesAnswerDeliveryState>.broadcast();

  int _sessionToken = 0;
  GlassesAnswerDeliveryState _state = const GlassesAnswerDeliveryState.idle();

  Stream<GlassesAnswerDeliveryState> get stateStream => _stateController.stream;
  GlassesAnswerDeliveryState get currentState => _state;

  List<String> buildWindows(String answer) {
    final lines = _paginator.splitIntoLines(answer.trim());
    if (lines.isEmpty) {
      return const [];
    }
    if (lines.length <= TextPaginator.linesPerPage) {
      return [lines.join('\n')];
    }

    final windows = <String>[];
    final maxStart = lines.length - TextPaginator.linesPerPage;
    for (var start = 0; start <= maxStart; start++) {
      final end = start + TextPaginator.linesPerPage;
      windows.add(lines.sublist(start, end).join('\n'));
    }
    return windows;
  }

  Future<void> present(String answer, {String source = 'unknown'}) async {
    final trimmed = answer.trim();
    if (trimmed.isEmpty) return;

    final sessionToken = ++_sessionToken;
    _emit(
      GlassesAnswerDeliveryState(
        status: GlassesAnswerDeliveryStatus.preparing,
        answerText: trimmed,
        currentWindow: 0,
        totalWindows: 0,
      ),
    );

    if (!BleManager.isBothConnected()) {
      _emit(
        GlassesAnswerDeliveryState(
          status: GlassesAnswerDeliveryStatus.failed,
          answerText: trimmed,
          currentWindow: 0,
          totalWindows: 0,
          note: 'Glasses are not connected.',
        ),
      );
      return;
    }

    final windows = buildWindows(trimmed);
    _currentWindows = windows;
    _manualPageIndex = 0;
    _isManualMode = false;
    if (windows.isEmpty) {
      _emit(
        GlassesAnswerDeliveryState(
          status: GlassesAnswerDeliveryStatus.failed,
          answerText: trimmed,
          currentWindow: 0,
          totalWindows: 0,
          note: 'Nothing to send to the glasses.',
        ),
      );
      return;
    }

    try {
      await (_prepareDelivery?.call() ?? TextService.get.stopTextSendingByOS());
      await (_beginTextTransfer?.call(
            'GlassesAnswerPresenter.present:$source',
          ) ??
          _hudController.beginTextTransfer(
            source: 'GlassesAnswerPresenter.present:$source',
          ));

      for (var index = 0; index < windows.length; index++) {
        if (sessionToken != _sessionToken) {
          return;
        }

        _emit(
          GlassesAnswerDeliveryState(
            status: GlassesAnswerDeliveryStatus.delivering,
            answerText: trimmed,
            currentWindow: index + 1,
            totalWindows: windows.length,
          ),
        );

        final isSuccess = await _sender(
          windows[index],
          index + 1,
          windows.length,
        );
        if (!isSuccess) {
          if (sessionToken != _sessionToken) {
            return;
          }
          _emit(
            GlassesAnswerDeliveryState(
              status: GlassesAnswerDeliveryStatus.failed,
              answerText: trimmed,
              currentWindow: index + 1,
              totalWindows: windows.length,
              note: 'The glasses rejected the answer payload.',
            ),
          );
          await (_resetToIdle?.call('GlassesAnswerPresenter.present.failure') ??
              _hudController.resetToIdle(
                source: 'GlassesAnswerPresenter.present.failure',
              ));
          return;
        }

        if (index < windows.length - 1) {
          await Future<void>.delayed(_cadence);
        }
      }

      if (sessionToken != _sessionToken) {
        return;
      }

      _emit(
        GlassesAnswerDeliveryState(
          status: GlassesAnswerDeliveryStatus.delivered,
          answerText: trimmed,
          currentWindow: windows.length,
          totalWindows: windows.length,
        ),
      );
      await (_resetToIdle?.call('GlassesAnswerPresenter.present.complete') ??
          _hudController.resetToIdle(
            source: 'GlassesAnswerPresenter.present.complete',
          ));
    } catch (error) {
      if (sessionToken != _sessionToken) {
        return;
      }
      appLogger.e('Failed to present answer on glasses', error: error);
      _emit(
        GlassesAnswerDeliveryState(
          status: GlassesAnswerDeliveryStatus.failed,
          answerText: trimmed,
          currentWindow: 0,
          totalWindows: windows.length,
          note: '$error',
        ),
      );
      await (_resetToIdle?.call('GlassesAnswerPresenter.present.exception') ??
          _hudController.resetToIdle(
            source: 'GlassesAnswerPresenter.present.exception',
          ));
    }
  }

  Future<void> cancel({String source = 'unknown'}) async {
    _sessionToken++;
    if (_state.isActive) {
      _emit(
        GlassesAnswerDeliveryState(
          status: GlassesAnswerDeliveryStatus.failed,
          answerText: _state.answerText,
          currentWindow: _state.currentWindow,
          totalWindows: _state.totalWindows,
          note: 'Interrupted by a newer answer.',
        ),
      );
    }
    await (_resetToIdle?.call('GlassesAnswerPresenter.cancel:$source') ??
        _hudController.resetToIdle(
          source: 'GlassesAnswerPresenter.cancel:$source',
        ));
  }

  // --- Manual page navigation ---

  List<String> _currentWindows = const [];
  int _manualPageIndex = 0;
  bool _isManualMode = false;

  /// Whether the user has taken manual control of page navigation
  bool get isManualMode => _isManualMode;

  /// Navigate to the previous page of the current answer.
  /// Increments `_sessionToken` to cancel any in-flight auto-paging loop.
  void previousPage() {
    if (_currentWindows.isEmpty) return;
    if (_manualPageIndex > 0) {
      _enterManualMode();
      _manualPageIndex--;
      _showManualPage();
    }
  }

  /// Navigate to the next page of the current answer.
  /// Increments `_sessionToken` to cancel any in-flight auto-paging loop.
  void nextPage() {
    if (_currentWindows.isEmpty) return;
    if (_manualPageIndex < _currentWindows.length - 1) {
      _enterManualMode();
      _manualPageIndex++;
      _showManualPage();
    }
  }

  /// Switch to manual paging mode, cancelling the auto-paging loop.
  void _enterManualMode() {
    if (!_isManualMode) {
      _isManualMode = true;
      _sessionToken++; // cancel any running auto-page loop
      appLogger.d('[GlassesAnswerPresenter] Entered manual paging mode');
    }
  }

  void _showManualPage() {
    final text = _currentWindows[_manualPageIndex];
    _sender(text, _manualPageIndex + 1, _currentWindows.length);
    _emit(
      GlassesAnswerDeliveryState(
        status: GlassesAnswerDeliveryStatus.delivering,
        answerText: _state.answerText,
        currentWindow: _manualPageIndex + 1,
        totalWindows: _currentWindows.length,
      ),
    );
  }

  void dispose() {
    _stateController.close();
  }

  void _emit(GlassesAnswerDeliveryState state) {
    _state = state;
    _stateController.add(state);
  }

  static Future<bool> _defaultSender(
    String text,
    int currentWindow,
    int totalWindows,
  ) {
    return Proto.sendEvenAIData(
      text,
      newScreen: HudDisplayState.textPage(),
      pos: 0,
      current_page_num: currentWindow,
      max_page_num: totalWindows,
    );
  }
}
