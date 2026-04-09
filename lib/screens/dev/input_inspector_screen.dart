// input_inspector_screen.dart
//
// WS-F: Dev tools screen that visualises the native `event.input_inspector`
// firehose. Lets a developer press each button on a paired BT HID ring
// remote, identify which channel/signature is emitted, and bind that
// signature to the Q&A trigger.
//
// This screen subscribes to the event channel DIRECTLY — not through
// InputDispatcher — so the raw stream is visible even if the dispatcher
// would filter or debounce it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/input_dispatcher.dart';
import '../../services/settings_manager.dart';

class InputInspectorScreen extends StatefulWidget {
  const InputInspectorScreen({super.key});

  @override
  State<InputInspectorScreen> createState() => _InputInspectorScreenState();
}

class _InputInspectorScreenState extends State<InputInspectorScreen> {
  static const _method = MethodChannel('method.input_inspector');
  static const _events = EventChannel('event.input_inspector');

  final List<_InspectorEvent> _events_list = [];
  StreamSubscription<dynamic>? _sub;
  final Map<String, int> _channelCounts = {
    'keyCommand': 0,
    'pressEvent': 0,
    'mediaCommand': 0,
    'volumeChange': 0,
  };

  @override
  void initState() {
    super.initState();
    _startCapture();
  }

  Future<void> _startCapture() async {
    try {
      await _method.invokeMethod<void>('startInspector');
    } catch (_) {}
    _sub = _events.receiveBroadcastStream().listen((event) {
      if (event is! Map) return;
      final map = Map<String, dynamic>.from(event as Map);
      final channel = map['channel'] as String? ?? 'unknown';
      setState(() {
        _channelCounts[channel] = (_channelCounts[channel] ?? 0) + 1;
        _events_list.insert(0, _InspectorEvent(channel, map));
        if (_events_list.length > 200) {
          _events_list.removeRange(200, _events_list.length);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _method.invokeMethod<void>('stopInspector');
    super.dispose();
  }

  void _clear() {
    setState(() {
      _events_list.clear();
      for (final k in _channelCounts.keys) {
        _channelCounts[k] = 0;
      }
    });
  }

  Future<void> _bind(String signature) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bind this signal?'),
        content: Text('Signature: $signature\n\n'
            'Pressing this button on your ring remote will trigger Q&A.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Bind'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await SettingsManager.instance.setRingBindingSignature(signature);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bound: $signature')),
      );
      setState(() {});
    }
  }

  Future<void> _unbind() async {
    await SettingsManager.instance.setRingBindingSignature(null);
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bound = SettingsManager.instance.ringBindingSignature;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Inspector'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clear,
            tooltip: 'Clear',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Pair the ring remote in iOS Settings, then press each button. '
              'Tap "Bind this signal" on the row you want to use for Q&A.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          _ChannelPills(counts: _channelCounts),
          const Divider(height: 1),
          Expanded(
            child: _events_list.isEmpty
                ? const Center(child: Text('No events yet — press a button'))
                : ListView.separated(
                    itemCount: _events_list.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final ev = _events_list[i];
                      final sig = canonicalSignatureFromEvent(ev.payload) ??
                          '(not canonicalisable)';
                      return ListTile(
                        dense: true,
                        title: Text(
                          sig,
                          style: const TextStyle(
                              fontFamily: 'Menlo', fontSize: 12),
                        ),
                        subtitle: Text(
                          ev.payload.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Menlo', fontSize: 10),
                        ),
                        trailing: TextButton(
                          onPressed: sig.startsWith('(')
                              ? null
                              : () => _bind(sig),
                          child: const Text('Bind'),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.all(12),
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    bound == null
                        ? 'No binding set'
                        : 'Current: $bound',
                    style: const TextStyle(fontFamily: 'Menlo'),
                  ),
                ),
                if (bound != null)
                  TextButton(
                    onPressed: _unbind,
                    child: const Text('Unbind'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectorEvent {
  _InspectorEvent(this.channel, this.payload);
  final String channel;
  final Map<String, dynamic> payload;
}

class _ChannelPills extends StatelessWidget {
  const _ChannelPills({required this.counts});
  final Map<String, int> counts;

  static const _colors = <String, Color>{
    'keyCommand': Colors.blue,
    'pressEvent': Colors.purple,
    'mediaCommand': Colors.orange,
    'volumeChange': Colors.green,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: counts.entries.map((e) {
          final color = _colors[e.key] ?? Colors.grey;
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${e.key} · ${e.value}',
              style: TextStyle(color: color, fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }
}
