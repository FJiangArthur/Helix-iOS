/// Streaming state-machine parser for the Realtime API's delimited 3-layer
/// output format. See `conversation_engine` realtime path + the structured
/// conversation prompt in `OpenAIRealtimeTranscriber.swift` for the contract.
///
/// Wire format (model is instructed to emit exactly this, no JSON because
/// gpt-realtime-mini and gpt-realtime-1.5 do not support structured outputs):
///
///     §Q§
///     <question text or NONE>
///     §A§
///     <answer text or NONE>
///     §END§
///
/// Tokens arrive as `response.output_text.delta` chunks of arbitrary size.
/// A marker like `§A§` can be split across two deltas (`§A` in one chunk,
/// `§` in the next). The parser therefore buffers a small tail whenever the
/// current state's content ends with a prefix that could grow into the next
/// marker. All other content flushes immediately so the answer streams
/// word-by-word into the HUD with minimum latency.
library;

/// Emitter callbacks. Callers wire these into the conversation engine:
///   * [onQuestionDelta] — tokens for the §Q§ section (usually short, so the
///     UI can wait for [onQuestionComplete] instead of showing partials).
///   * [onQuestionComplete] — fires once when the §A§ marker closes the
///     question section. Payload is the full question, trimmed. `null` if
///     the model emitted `NONE`.
///   * [onAnswerDelta] — tokens for the §A§ section. These stream straight
///     into the HUD.
///   * [onAnswerComplete] — fires once when `§END§` arrives OR the upstream
///     stream closes. Payload is the full trimmed answer. `null` if NONE.
///   * [onDrift] — fires if the model forgot the format. The parser then
///     treats every remaining token as part of the answer (fallback so the
///     user still gets *something* visible). Question is reported as null.
typedef StringEmit = void Function(String text);
typedef NullableStringEmit = void Function(String? text);
typedef VoidEmit = void Function();

class DelimitedQaParser {
  DelimitedQaParser({
    this.onQuestionDelta,
    this.onQuestionComplete,
    this.onAnswerDelta,
    this.onAnswerComplete,
    this.onDrift,
  });

  final StringEmit? onQuestionDelta;
  final NullableStringEmit? onQuestionComplete;
  final StringEmit? onAnswerDelta;
  final NullableStringEmit? onAnswerComplete;
  final VoidEmit? onDrift;

  // Markers. Using a non-ASCII section-sign makes accidental collisions with
  // real answer content extremely unlikely, which matters for the drift
  // detection heuristic.
  static const String _markerQ = '§Q§';
  static const String _markerA = '§A§';
  static const String _markerEnd = '§END§';

  // Longest-marker length is used to decide how much of the tail might still
  // be growing into a marker and therefore must be buffered, not flushed.
  // '§' is U+00A7 (single UTF-16 code unit), so '§END§'.length == 5.
  // Kept for documentation; _tailCouldBeMarkerPrefix reads the marker length
  // directly from the marker string.
  // ignore: unused_field
  static const int _maxMarkerLen = 5;

  _State _state = _State.preQ;
  final StringBuffer _questionBuf = StringBuffer();
  final StringBuffer _answerBuf = StringBuffer();
  // Carry-over buffer: a short tail of the last accepted chunk that might be
  // the prefix of an upcoming marker. It is NOT yet emitted to the section
  // buffer — it lives here until the next chunk arrives or the stream ends.
  String _carry = '';
  bool _closed = false;

  /// Feed one raw delta from the realtime stream.
  void addDelta(String delta) {
    if (_closed || delta.isEmpty) return;
    // Pull any held-back prefix and consume it together with the new delta.
    // `_consume` will re-populate `_carry` if it needs to hold back again.
    final combined = _carry + delta;
    _carry = '';
    _consume(combined);
  }

  /// Signal the upstream stream has ended. Flushes any carry buffer into
  /// the active section and fires the *Complete callbacks.
  void finish() {
    if (_closed) return;
    _closed = true;
    // Any remaining carry is content, not a marker start — flush it.
    if (_carry.isNotEmpty) {
      _appendToActiveSection(_carry);
      _carry = '';
    }
    _finalize();
  }

  /// Reset between turns. Called on every new response.created event.
  void reset() {
    _state = _State.preQ;
    _questionBuf.clear();
    _answerBuf.clear();
    _carry = '';
    _closed = false;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  void _consume(String input) {
    var remaining = input;
    while (remaining.isNotEmpty) {
      // Drift detection: if we're in preQ and a non-whitespace character
      // arrives that is not the start of §Q§, the model has ignored the
      // format. Treat all subsequent content as answer.
      if (_state == _State.preQ) {
        final trimmedLeading = remaining.trimLeft();
        if (trimmedLeading.isEmpty) {
          remaining = '';
          break;
        }
        if (_markerQ.startsWith(trimmedLeading) ||
            trimmedLeading.startsWith(_markerQ)) {
          // Either a full marker or a potential marker prefix.
          if (trimmedLeading.length < _markerQ.length) {
            _carry = trimmedLeading;
            return;
          }
          _state = _State.inQuestion;
          remaining = trimmedLeading.substring(_markerQ.length);
          continue;
        }
        // Not the expected marker — model drifted. Fall through into drift
        // mode: emit a drift signal, switch to inAnswer, and reprocess the
        // current remaining as answer content.
        _enterDriftMode();
        remaining = trimmedLeading;
        continue;
      }

      final marker = _expectedCloseMarker();
      final idx = remaining.indexOf(marker);
      if (idx >= 0) {
        // Everything up to idx belongs to the current section. Flush.
        if (idx > 0) {
          _appendToActiveSection(remaining.substring(0, idx));
        }
        _advanceState();
        remaining = remaining.substring(idx + marker.length);
        _carry = '';
        continue;
      }

      // No full marker found. The *tail* of `remaining` might be the start
      // of the marker though — keep up to (markerLen - 1) characters as
      // carry and flush the rest.
      final keep = _tailCouldBeMarkerPrefix(remaining, marker);
      if (keep > 0) {
        final flushable = remaining.substring(0, remaining.length - keep);
        if (flushable.isNotEmpty) {
          _appendToActiveSection(flushable);
        }
        _carry = remaining.substring(remaining.length - keep);
      } else {
        _appendToActiveSection(remaining);
        _carry = '';
      }
      return;
    }
  }

  String _expectedCloseMarker() {
    switch (_state) {
      case _State.inQuestion:
        return _markerA;
      case _State.inAnswer:
        return _markerEnd;
      case _State.drift:
        // No closing marker in drift mode — everything is answer.
        return '\u{0}'; // sentinel that cannot appear in real text
      case _State.preQ:
      case _State.done:
        return '\u{0}';
    }
  }

  void _appendToActiveSection(String text) {
    switch (_state) {
      case _State.inQuestion:
        _questionBuf.write(text);
        onQuestionDelta?.call(text);
        break;
      case _State.inAnswer:
      case _State.drift:
        _answerBuf.write(text);
        onAnswerDelta?.call(text);
        break;
      case _State.preQ:
      case _State.done:
        // Ignore content before §Q§ or after §END§. Pre-§Q§ leading
        // whitespace is common; trailing tokens after §END§ are drift but
        // harmless to drop.
        break;
    }
  }

  void _advanceState() {
    switch (_state) {
      case _State.inQuestion:
        _state = _State.inAnswer;
        // Fire onQuestionComplete now — downstream can decide whether to
        // display it or suppress NONE.
        final q = _questionBuf.toString().trim();
        onQuestionComplete?.call(_isNone(q) ? null : q);
        break;
      case _State.inAnswer:
        _state = _State.done;
        _finalizeAnswer();
        break;
      case _State.preQ:
      case _State.drift:
      case _State.done:
        break;
    }
  }

  void _enterDriftMode() {
    _state = _State.drift;
    onDrift?.call();
    // No question available in drift mode.
    onQuestionComplete?.call(null);
  }

  void _finalize() {
    // Called from finish() — may be mid-section if the model's stream was
    // cut short. Fire whatever complete callbacks haven't fired yet.
    switch (_state) {
      case _State.preQ:
        // Stream ended before any marker arrived — treat as drift with empty
        // answer so downstream knows nothing came out.
        onQuestionComplete?.call(null);
        onAnswerComplete?.call(null);
        break;
      case _State.inQuestion:
        // Question never closed → surface it anyway, no answer.
        final q = _questionBuf.toString().trim();
        onQuestionComplete?.call(_isNone(q) || q.isEmpty ? null : q);
        onAnswerComplete?.call(null);
        break;
      case _State.inAnswer:
      case _State.drift:
        _finalizeAnswer();
        break;
      case _State.done:
        // Already finalized — nothing to do.
        break;
    }
    _state = _State.done;
  }

  void _finalizeAnswer() {
    final a = _answerBuf.toString().trim();
    onAnswerComplete?.call(_isNone(a) || a.isEmpty ? null : a);
  }

  static bool _isNone(String s) =>
      s.trim().toUpperCase() == 'NONE';

  /// Returns how many trailing characters of [text] must be held back because
  /// they form a strict prefix of [marker] that could complete on the next
  /// delta. Cheaper than running a full KMP — markers are tiny.
  static int _tailCouldBeMarkerPrefix(String text, String marker) {
    final maxCheck = marker.length - 1;
    final start = text.length - maxCheck;
    final lo = start < 0 ? 0 : start;
    for (var i = lo; i < text.length; i++) {
      final tail = text.substring(i);
      if (marker.startsWith(tail)) {
        return text.length - i;
      }
    }
    return 0;
  }
}

enum _State {
  preQ,
  inQuestion,
  inAnswer,
  drift,
  done,
}
