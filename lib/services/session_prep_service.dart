import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_logger.dart';
import 'conversation_engine.dart';

/// Stores the user's "prep on your face" material (job description, resume,
/// meeting notes, etc.) and injects it into the system prompt during a
/// prepared conversation.
///
/// Phase 1 design:
/// - Flat `String`, SharedPreferences-backed (not secure storage — prep isn't
///   a secret and can run large).
/// - Hard cap 8000 tokens, estimated as chars/4 (same heuristic used by
///   `SessionContextManager`). Excess content is truncated at save time and
///   the user is shown a banner.
/// - Clears on conversation-end (auto-subscribed to
///   `ConversationEngine.sessionSavedStream`) AND on explicit user action.
/// - Refuses prompt-injection patterns ("ignore previous instructions",
///   case-insensitive) with a rejection reason the UI can show.
/// - On SharedPreferences failure, keeps prep in-memory for the current app
///   session and surfaces a non-fatal warning; next cold start loses the
///   prep.
///
/// Not a singleton with global state in tests — callers construct and
/// initialize an instance, and the app-level singleton lives in
/// `SessionPrepService.instance` for production wiring.
class SessionPrepService {
  SessionPrepService._();

  static final SessionPrepService instance = SessionPrepService._();

  /// Shared key for persistence.
  static const String _prefsKey = 'sessionPrep';

  /// Hard cap on prep tokens.
  static const int maxPrepTokens = 8000;

  /// Rough chars-per-token estimate. Matches `SessionContextManager`.
  static const int _charsPerToken = 4;

  /// Max chars we allow to be pasted before we start truncating.
  static int get maxPrepChars => maxPrepTokens * _charsPerToken;

  /// Pattern that indicates a likely prompt-injection attempt. Lightweight
  /// defense only — not foolproof, but catches the obvious footgun.
  static final RegExp _injectionPattern = RegExp(
    r'ignore\s+(all\s+)?previous\s+(instructions?|prompts?|messages?|directions?)',
    caseSensitive: false,
  );

  SharedPreferences? _prefs;
  String _prep = '';
  bool _inMemoryOnly = false;
  StreamSubscription<String>? _sessionSavedSub;

  // Listeners receive (prep, wasTruncated) notifications so UI can refresh.
  final List<void Function()> _listeners = [];

  /// The currently-loaded prep text. Empty string means no prep.
  String get prep => _prep;

  /// True when the last save had to be truncated because it exceeded the
  /// token budget.
  bool get wasTruncated => _wasTruncated;
  bool _wasTruncated = false;

  /// True when SharedPreferences failed and prep is held only in RAM.
  /// Callers can use this to render a "session-only" indicator.
  bool get inMemoryOnly => _inMemoryOnly;

  /// Estimate the token count of a prep string. O(1).
  static int estimateTokens(String text) => (text.length / _charsPerToken).ceil();

  /// Load persisted prep from SharedPreferences and subscribe to
  /// conversation-end events so prep auto-clears. Safe to call multiple
  /// times; second + calls are no-ops.
  Future<void> initialize() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      _prep = _prefs!.getString(_prefsKey) ?? '';
      appLogger.d(
        '[SessionPrep] initialized — ${_prep.length} chars loaded',
      );
    } catch (e) {
      // SharedPreferences failed at startup. Don't block the app; prep stays
      // empty and inMemoryOnly so subsequent saves can still work in RAM.
      appLogger.w('[SessionPrep] SharedPreferences init failed: $e');
      _inMemoryOnly = true;
    }

    // Subscribe once. We don't auto-cancel — the service lives for the app's
    // lifetime.
    _sessionSavedSub ??= ConversationEngine.instance.sessionSavedStream.listen(
      (_) => _clearInMemoryOnly(),
    );
  }

  /// Attempt to save [text] as the active prep. Returns a [SaveResult]
  /// describing what happened (success, truncated, rejected, or storage
  /// fallback to memory-only).
  Future<SaveResult> save(String text) async {
    // Initial sanitization: trim edges; do not mangle interior whitespace
    // because prep often has semantic line breaks (resume, meeting notes).
    final trimmed = text.trim();

    // Empty → treat as clear.
    if (trimmed.isEmpty) {
      await clear();
      _notify();
      return SaveResult.cleared;
    }

    // Injection check before anything else. Rejects the paste and returns
    // a reason so the UI can surface it.
    if (_injectionPattern.hasMatch(trimmed)) {
      appLogger.w(
        '[SessionPrep] rejected paste — injection pattern detected',
      );
      return SaveResult.rejected;
    }

    // Truncation check. If we exceed the token budget, keep only the first
    // maxPrepChars characters. Downstream callers read `wasTruncated` to
    // show the banner.
    String toStore = trimmed;
    _wasTruncated = false;
    if (trimmed.length > maxPrepChars) {
      toStore = trimmed.substring(0, maxPrepChars);
      _wasTruncated = true;
    }

    _prep = toStore;
    final persisted = await _persist(toStore);
    _notify();

    if (_wasTruncated && !persisted) {
      return SaveResult.truncatedAndInMemory;
    }
    if (_wasTruncated) return SaveResult.truncated;
    if (!persisted) return SaveResult.savedInMemory;
    return SaveResult.saved;
  }

  /// Clear prep both in-memory and on-disk. Called by the user and by the
  /// conversation-end stream subscriber.
  Future<void> clear() async {
    _prep = '';
    _wasTruncated = false;
    _inMemoryOnly = false;
    final prefs = _prefs;
    if (prefs != null) {
      try {
        await prefs.remove(_prefsKey);
      } catch (e) {
        appLogger.w('[SessionPrep] failed to clear persisted prep: $e');
      }
    }
    _notify();
  }

  /// Internal: conversation-saved event handler. Clears prep without
  /// touching SharedPreferences errors (they're not actionable at this
  /// point) and notifies listeners so the Settings UI reflects the change.
  void _clearInMemoryOnly() {
    if (_prep.isEmpty) return;
    appLogger.d(
      '[SessionPrep] conversation ended — clearing ${_prep.length} chars',
    );
    _prep = '';
    _wasTruncated = false;
    _notify();
    // Fire-and-forget on-disk clear; don't block the conversation-end path.
    final prefs = _prefs;
    if (prefs != null) {
      unawaited(
        prefs.remove(_prefsKey).catchError((e) {
          appLogger.w('[SessionPrep] post-session clear failed: $e');
          return false;
        }),
      );
    }
  }

  Future<bool> _persist(String value) async {
    final prefs = _prefs;
    if (prefs == null) {
      _inMemoryOnly = true;
      return false;
    }
    try {
      final ok = await prefs.setString(_prefsKey, value);
      if (!ok) {
        _inMemoryOnly = true;
        appLogger.w(
          '[SessionPrep] setString returned false — holding in-memory',
        );
        return false;
      }
      _inMemoryOnly = false;
      return true;
    } catch (e) {
      appLogger.w('[SessionPrep] setString threw: $e — holding in-memory');
      _inMemoryOnly = true;
      return false;
    }
  }

  /// Subscribe to prep-changed notifications. Returns a disposer.
  void Function() addListener(void Function() cb) {
    _listeners.add(cb);
    return () => _listeners.remove(cb);
  }

  void _notify() {
    for (final cb in List.of(_listeners)) {
      try {
        cb();
      } catch (e) {
        appLogger.w('[SessionPrep] listener threw: $e');
      }
    }
  }

  /// Test seam: dispose the conversation-saved subscription and reset
  /// all mutable state. Safe to call from tearDown.
  Future<void> debugReset() async {
    await _sessionSavedSub?.cancel();
    _sessionSavedSub = null;
    _prep = '';
    _wasTruncated = false;
    _inMemoryOnly = false;
    _prefs = null;
    _listeners.clear();
  }
}

/// Outcome of [SessionPrepService.save].
enum SaveResult {
  /// Saved to both memory and disk.
  saved,

  /// Saved in memory; disk write failed. UI should surface a non-fatal
  /// "session-only" toast.
  savedInMemory,

  /// Over-budget content was truncated to the first `maxPrepChars` chars
  /// and then saved to disk. UI should show a truncation banner.
  truncated,

  /// Over-budget content was truncated AND disk write failed. Both banners
  /// apply.
  truncatedAndInMemory,

  /// Paste contained a prompt-injection pattern; nothing was saved.
  rejected,

  /// Empty save → cleared any prior prep.
  cleared,
}
