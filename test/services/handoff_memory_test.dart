import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/services/handoff_memory.dart';

void main() {
  group('HandoffMemory', () {
    tearDown(() {
      HandoffMemory.instance.clear();
    });

    test('emits pending then delivered updates for a handoff', () async {
      final events = <HandoffRecord?>[];
      final sub = HandoffMemory.instance.stream.listen(events.add);

      HandoffMemory.instance.startTransfer(
        'Ship the latest answer to the HUD.',
        source: 'test.home',
      );
      HandoffMemory.instance.markDelivered(note: 'Delivered');

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(events, hasLength(2));
      expect(events.first?.status, HandoffStatus.pending);
      expect(events.first?.source, 'test.home');
      expect(events.last?.status, HandoffStatus.delivered);
      expect(events.last?.note, 'Delivered');
      expect(HandoffMemory.instance.current?.preview, contains('Ship the latest'));
    });

    test('clear resets the current record and emits null', () async {
      final events = <HandoffRecord?>[];
      final sub = HandoffMemory.instance.stream.listen(events.add);

      HandoffMemory.instance.startTransfer('hello', source: 'test');
      HandoffMemory.instance.clear();

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(HandoffMemory.instance.current, isNull);
      expect(events.last, isNull);
    });
  });
}
