import 'dart:async';

enum HandoffStatus { pending, delivered, failed }

class HandoffRecord {
  const HandoffRecord({
    required this.text,
    required this.source,
    required this.timestamp,
    required this.status,
    this.note,
  });

  final String text;
  final String source;
  final DateTime timestamp;
  final HandoffStatus status;
  final String? note;

  String get preview {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 88) return normalized;
    return '${normalized.substring(0, 87)}...';
  }

  HandoffRecord copyWith({
    String? text,
    String? source,
    DateTime? timestamp,
    HandoffStatus? status,
    String? note,
  }) {
    return HandoffRecord(
      text: text ?? this.text,
      source: source ?? this.source,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      note: note ?? this.note,
    );
  }
}

class HandoffMemory {
  HandoffMemory._();

  static HandoffMemory? _instance;
  static HandoffMemory get instance => _instance ??= HandoffMemory._();

  final StreamController<HandoffRecord?> _controller =
      StreamController<HandoffRecord?>.broadcast();

  HandoffRecord? _current;

  Stream<HandoffRecord?> get stream => _controller.stream;
  HandoffRecord? get current => _current;

  void startTransfer(String text, {required String source}) {
    _current = HandoffRecord(
      text: text,
      source: source,
      timestamp: DateTime.now(),
      status: HandoffStatus.pending,
      note: 'Transfer queued',
    );
    _controller.add(_current);
  }

  void markDelivered({String? note}) {
    if (_current == null) return;
    _current = _current!.copyWith(
      status: HandoffStatus.delivered,
      note: note ?? 'Delivered to the HUD',
    );
    _controller.add(_current);
  }

  void markFailed({String? note}) {
    if (_current == null) return;
    _current = _current!.copyWith(
      status: HandoffStatus.failed,
      note: note ?? 'Transfer failed',
    );
    _controller.add(_current);
  }

  void clear() {
    _current = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}
