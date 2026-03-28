import 'dart:async';

import 'package:flutter_helix/utils/app_logger.dart';

class SilenceTimeoutService {
  static SilenceTimeoutService? _instance;
  static SilenceTimeoutService get instance =>
      _instance ??= SilenceTimeoutService._();
  SilenceTimeoutService._();

  Timer? _silenceTimer;
  Duration _timeout = const Duration(minutes: 15);

  final _timeoutController = StreamController<void>.broadcast();
  Stream<void> get onSilenceTimeout => _timeoutController.stream;

  /// Call this every time transcription activity is detected.
  void onActivity() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_timeout, () {
      appLogger.i('Silence timeout reached ($_timeout) — firing event');
      _timeoutController.add(null);
    });
  }

  /// Start monitoring. Called when recording begins.
  void start({Duration? timeout}) {
    if (timeout != null) _timeout = timeout;
    appLogger.d('SilenceTimeoutService started (timeout: $_timeout)');
    onActivity();
  }

  /// Stop monitoring. Called when recording stops.
  void stop() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    appLogger.d('SilenceTimeoutService stopped');
  }

  void dispose() {
    stop();
    _timeoutController.close();
    _instance = null;
  }
}
