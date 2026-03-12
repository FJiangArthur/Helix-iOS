import 'dart:async';
import 'dart:math';
import '../utils/app_logger.dart';
import 'glasses_protocol.dart';
import 'handoff_memory.dart';
import 'hud_controller.dart';
import 'proto.dart';
import 'text_paginator.dart';

class TextService {
  static TextService? _instance;
  static TextService get get => _instance ??= TextService._();
  static bool isRunning = false;
  static int maxRetry = 5;
  static int _currentLine = 0;
  static Timer? _timer;
  static List<String> list = [];
  static List<String> sendReplys = [];
  final HudController _hudController = HudController.instance;

  TextService._();

  /// Text transfer uses the dedicated text-display state instead of the AI result view.
  int _screenCodeForPage() => HudDisplayState.textPage();

  Future startSendText(String text, {String source = 'unknown'}) async {
    final content = text.trim();
    if (content.isEmpty) return;

    await stopTextSendingByOS();
    HandoffMemory.instance.startTransfer(content, source: source);
    isRunning = true;
    await _hudController.beginTextTransfer(source: 'TextService.startSendText');

    _currentLine = 0;
    final paginator = TextPaginator.instance;
    paginator.paginateText(content);
    list = List.generate(paginator.pageCount, (i) {
      paginator.goToPage(i);
      return paginator.currentPageText;
    });
    paginator.clear();

    if (list.length <= 1) {
      final singlePage = list.isNotEmpty ? list[0] : '';
      final isSuccess = await doSendText(singlePage, _screenCodeForPage(), 0);
      clear();
      if (isSuccess) {
        HandoffMemory.instance.markDelivered(note: 'Single-page handoff complete');
        await _hudController.resetToIdle(
          source: 'TextService.startSendText.singlePage',
        );
      } else {
        HandoffMemory.instance.markFailed(note: 'Single-page handoff failed');
        await _hudController.resetToIdle(
          source: 'TextService.startSendText.singlePage.failure',
        );
      }
      return;
    }

    String startScreenWords = list[0];
    bool isSuccess = await doSendText(
      startScreenWords,
      _screenCodeForPage(),
      0,
    );
    if (isSuccess && list.length > 1) {
      _currentLine = 0;
      await updateReplyToOSByTimer();
    } else if (!isSuccess) {
      clear();
      HandoffMemory.instance.markFailed(note: 'The first HUD page was rejected');
      await _hudController.resetToIdle(
        source: 'TextService.startSendText.failure',
      );
    }
  }

  Future<bool> doSendText(String text, int screenCode, int pos) async {
    if (!isRunning) {
      return false;
    }

    for (var attempt = 0; attempt < maxRetry; attempt++) {
      bool isSuccess = await Proto.sendEvenAIData(
        text,
        newScreen: screenCode,
        pos: pos,
        current_page_num: getCurrentPage(),
        max_page_num: getTotalPages(),
      );
      if (isSuccess) {
        return true;
      }
    }
    return false;
  }

  Future updateReplyToOSByTimer() async {
    if (!isRunning) return;
    int interval = 8;

    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: interval), (timer) async {
      _currentLine = min(_currentLine + 1, list.length - 1);

      if (_currentLine >= list.length) {
        _timer?.cancel();
        _timer = null;
        clear();
        return;
      }

      final isSuccess = await doSendText(
        list[_currentLine],
        _screenCodeForPage(),
        0,
      );

      if (!isSuccess) {
        _timer?.cancel();
        _timer = null;
        clear();
        HandoffMemory.instance.markFailed(note: 'A later HUD page failed');
        await _hudController.resetToIdle(
          source: 'TextService.updateReplyToOSByTimer.failure',
        );
        return;
      }

      if (_currentLine >= list.length - 1) {
        _timer?.cancel();
        _timer = null;
        clear();
        HandoffMemory.instance.markDelivered(note: 'Multi-page handoff complete');
        await _hudController.resetToIdle(
          source: 'TextService.updateReplyToOSByTimer.complete',
        );
      }
    });
  }

  int getTotalPages() {
    if (list.isEmpty) {
      return 0;
    }
    if (list.length < 6) {
      return 1;
    }
    int pages = 0;
    int div = list.length ~/ 5;
    int rest = list.length % 5;
    pages = div;
    if (rest != 0) {
      pages++;
    }
    return pages;
  }

  int getCurrentPage() {
    if (_currentLine == 0) {
      return 1;
    }
    int currentPage = 1;
    int div = _currentLine ~/ 5;
    int rest = _currentLine % 5;
    currentPage = 1 + div;
    if (rest != 0) {
      currentPage++;
    }
    return currentPage;
  }

  Future stopTextSendingByOS() async {
    appLogger.d("stopTextSendingByOS---------------");
    if (isRunning) {
      HandoffMemory.instance.markFailed(note: 'Transfer interrupted');
    }
    isRunning = false;
    clear();
    await _hudController.resetToIdle(
      source: 'TextService.stopTextSendingByOS',
    );
  }

  void clear() {
    isRunning = false;
    _currentLine = 0;
    _timer?.cancel();
    _timer = null;
    list = [];
    sendReplys = [];
  }
}
