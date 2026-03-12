import 'dart:async';

import 'package:flutter/material.dart';

class AnimatedTextStream extends StatefulWidget {
  final Stream<String>? textStream;
  final String? staticText;
  final TextStyle? style;

  const AnimatedTextStream({
    super.key,
    this.textStream,
    this.staticText,
    this.style,
  });

  @override
  State<AnimatedTextStream> createState() => _AnimatedTextStreamState();
}

class _AnimatedTextStreamState extends State<AnimatedTextStream> {
  String _displayedText = '';
  String _pendingText = '';
  Timer? _typingTimer;
  StreamSubscription<String>? _streamSubscription;

  @override
  void initState() {
    super.initState();
    if (widget.staticText != null) {
      _pendingText = widget.staticText!;
      _startTyping();
    }
    _subscribeToStream();
  }

  @override
  void didUpdateWidget(AnimatedTextStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textStream != oldWidget.textStream) {
      _streamSubscription?.cancel();
      _subscribeToStream();
    }
    if (widget.staticText != oldWidget.staticText &&
        widget.staticText != null) {
      _pendingText = widget.staticText!;
      _displayedText = '';
      _startTyping();
    }
  }

  void _subscribeToStream() {
    _streamSubscription = widget.textStream?.listen((chunk) {
      _pendingText += chunk;
      if (_typingTimer == null || !_typingTimer!.isActive) {
        _startTyping();
      }
    });
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(
      const Duration(milliseconds: 30),
      (timer) {
        if (_displayedText.length >= _pendingText.length) {
          timer.cancel();
          return;
        }
        setState(() {
          _displayedText =
              _pendingText.substring(0, _displayedText.length + 1);
        });
      },
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.9),
      fontSize: 16,
      height: 1.5,
    );

    return Text(
      _displayedText,
      style: widget.style ?? defaultStyle,
    );
  }
}
