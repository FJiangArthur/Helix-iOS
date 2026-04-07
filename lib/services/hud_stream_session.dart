import 'dart:async';

import 'package:flutter_helix/services/proto.dart';
import 'package:flutter_helix/services/text_paginator.dart';

/// Sink abstraction for full-page HUD writes during a streaming response.
///
/// Production binding wraps [Proto.sendEvenAIData]; tests inject a recording
/// or manual-completer sink to assert protocol behaviour without hardware.
abstract class HudPacketSink {
  Future<void> send({
    required int screenStatus,
    required int pageIndex,
    required int totalPages,
    required String pageText,
  });
}

/// Production [HudPacketSink] binding that writes through [Proto.sendEvenAIData].
///
/// `pos` is hard-coded to `0` per the consolidated G1 protocol findings — the
/// firmware does not implement an append offset, so every emit re-pushes the
/// full current-page text.
class ProtoHudPacketSink implements HudPacketSink {
  const ProtoHudPacketSink();

  @override
  Future<void> send({
    required int screenStatus,
    required int pageIndex,
    required int totalPages,
    required String pageText,
  }) {
    return Proto.sendEvenAIData(
      pageText,
      newScreen: screenStatus,
      pos: 0,
      current_page_num: pageIndex + 1,
      max_page_num: totalPages,
    ).then((_) {});
  }
}

/// State machine that flushes streaming LLM output to the G1 HUD on
/// **completed visual line** boundaries instead of per token.
///
/// See `docs/superpowers/specs/2026-04-06-hud-line-streaming-design.md` §4.
class HudStreamSession {
  HudStreamSession({required this.sink});

  final HudPacketSink sink;

  // Per-page state.
  int _pageIndex = 0;
  final List<String> _lines = [];
  String _pendingTail = '';

  // Per-page lifecycle bit: true once a 0x01|0x30 NEW_CONTENT frame has been
  // emitted for the current page. Reset to false on page boundary so the next
  // page's first emit re-asserts NEW_CONTENT.
  bool _firstFrameSent = false;

  // Per-stream lifecycle bit: blocks all further emits after `cancel()`.
  bool _cancelled = false;

  // Single-slot queue serializing sink writes; backpressure handler.
  Future<void> _inFlight = Future.value();

  static const int _newContent = 0x01;
  static const int _aiShowing = 0x30;
  static const int _aiComplete = 0x40;

  /// Append a streaming delta and emit one HUD frame iff the delta produced
  /// at least one newly completed visual line (or page boundary).
  Future<void> appendDelta(String delta) async {
    if (_cancelled || delta.isEmpty) return;

    // Handle literal `\n` as forced line breaks: split the new pending tail on
    // newlines, promoting each non-final segment as a completed line.
    final combined = _pendingTail + delta;
    final newlineSplit = combined.split('\n');
    bool committedFromNewline = false;
    if (newlineSplit.length > 1) {
      for (var i = 0; i < newlineSplit.length - 1; i++) {
        final segment = newlineSplit[i];
        if (segment.isNotEmpty) {
          await _commitLine(segment);
          committedFromNewline = true;
          if (_cancelled) return;
        }
      }
      _pendingTail = newlineSplit.last;
    } else {
      _pendingTail = combined;
    }

    // Pixel-accurate wrap on the unsent tail. Any non-final wrapped entry is
    // a completed visual line.
    final wrapped = TextPaginator.instance.splitIntoLines(_pendingTail);
    bool committedFromWrap = false;
    if (wrapped.length >= 2) {
      for (var i = 0; i < wrapped.length - 1; i++) {
        await _commitLine(wrapped[i]);
        committedFromWrap = true;
        if (_cancelled) return;
      }
      _pendingTail = wrapped.last;
    }

    if (committedFromNewline || committedFromWrap) {
      await _emitStreaming();
    }
  }

  /// Flush whatever has accumulated and emit the final 0x40 frame.
  Future<void> finish() async {
    await _inFlight;
    if (_cancelled) return;

    // Push any in-progress tail one last time so the user sees the partial
    // line before completion.
    if (_pendingTail.isNotEmpty || _lines.isNotEmpty) {
      await _emitStreaming();
      if (_cancelled) return;
    }

    await _emitFinal();
  }

  /// Spec A preemption hook: tear down state without emitting 0x40.
  Future<void> cancel() async {
    _cancelled = true;
    _lines.clear();
    _pendingTail = '';
    await _inFlight;
  }

  Future<void> _commitLine(String line) async {
    _lines.add(line);
    if (_lines.length == TextPaginator.linesPerPage) {
      // Emit the now-full page once before advancing.
      await _emitStreaming();
      if (_cancelled) return;
      _pageIndex++;
      _lines.clear();
      _firstFrameSent = false;
    }
  }

  String _pageTextSnapshot() {
    if (_pendingTail.isEmpty) return _lines.join('\n');
    if (_lines.isEmpty) return _pendingTail;
    return '${_lines.join('\n')}\n$_pendingTail';
  }

  Future<void> _emitStreaming() async {
    final prev = _inFlight;
    final completer = Completer<void>();
    _inFlight = completer.future;
    await prev;
    if (_cancelled) {
      completer.complete();
      return;
    }
    final int status = _firstFrameSent
        ? _aiShowing
        : (_newContent | _aiShowing);
    _firstFrameSent = true;
    final pageText = _pageTextSnapshot();
    try {
      await sink.send(
        screenStatus: status,
        pageIndex: _pageIndex,
        totalPages: _pageIndex + 1,
        pageText: pageText,
      );
    } finally {
      completer.complete();
    }
  }

  Future<void> _emitFinal() async {
    final prev = _inFlight;
    final completer = Completer<void>();
    _inFlight = completer.future;
    await prev;
    if (_cancelled) {
      completer.complete();
      return;
    }
    final pageText = _pageTextSnapshot();
    try {
      await sink.send(
        screenStatus: _aiComplete,
        pageIndex: _pageIndex,
        totalPages: _pageIndex + 1,
        pageText: pageText,
      );
    } finally {
      completer.complete();
    }
  }
}
