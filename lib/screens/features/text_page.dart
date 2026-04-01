import 'dart:async';

import 'package:flutter/material.dart';

import '../../ble_manager.dart';
import '../../services/handoff_memory.dart';
import '../../services/text_service.dart';
import '../../theme/helix_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/glow_button.dart';

class TextPage extends StatefulWidget {
  const TextPage({super.key});

  @override
  State<TextPage> createState() => _TextPageState();
}

class _TextPageState extends State<TextPage> {
  late final TextEditingController _textController;
  StreamSubscription<HandoffRecord?>? _handoffSub;
  bool _isSending = false;
  HandoffRecord? _handoffRecord;
  String _statusTitle = 'Ready';
  String _statusBody =
      'Stage text for the dedicated HUD reader. Single tap starts a transfer and locks the action while the current payload settles.';

  final String _sampleContent = '''Welcome to G1.

You're holding eyewear designed to keep useful information in view without pulling you out of the moment.

This page now uses the dedicated text-display state instead of the overview/AI response screen.''';

  bool get _isConnected => BleManager.isBothConnected();
  bool get _hasText => _textController.text.trim().isNotEmpty;
  bool get _canSend => _isConnected && _hasText && !_isSending;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _sampleContent);
    _handoffRecord = HandoffMemory.instance.current;
    _handoffSub = HandoffMemory.instance.stream.listen(_handleHandoffUpdate);
  }

  @override
  void dispose() {
    _handoffSub?.cancel();
    _textController.dispose();
    super.dispose();
  }

  bool _isTextPageSource(String source) => source.startsWith('text_page');

  Future<void> _sendText() async {
    if (!_canSend) return;

    setState(() {
      _isSending = true;
      _statusTitle = 'Transferring';
      _statusBody =
          'Sending your text to the G1 text-display channel. Avoid tapping again until the current transfer settles.';
    });

    try {
      await TextService.get.startSendText(
        _textController.text.trim(),
        source: 'text_page.composer',
      );
    } catch (error) {
      _finishTransfer(
        title: 'Transfer failed',
        body: 'The glasses did not accept the text payload. $error',
      );
    }
  }

  void _finishTransfer({required String title, required String body}) {
    if (!mounted) return;
    setState(() {
      _isSending = false;
      _statusTitle = title;
      _statusBody = body;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body)));
  }

  void _handleHandoffUpdate(HandoffRecord? record) {
    if (!mounted) return;
    setState(() => _handoffRecord = record);

    if (record == null || !_isTextPageSource(record.source)) {
      return;
    }

    switch (record.status) {
      case HandoffStatus.pending:
        setState(() {
          _isSending = true;
          _statusTitle = 'Transferring';
          _statusBody =
              'Sending your text to the G1 text-display channel. Avoid tapping again until the current transfer settles.';
        });
        break;
      case HandoffStatus.delivered:
        _finishTransfer(
          title: 'Text sent',
          body:
              'The payload has been staged on the glasses. Update the copy above if you want to send a new card.',
        );
        break;
      case HandoffStatus.failed:
        _finishTransfer(
          title: 'Transfer failed',
          body: record.note ?? 'The glasses did not accept the text payload.',
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isConnected ? HelixTheme.cyan : Colors.orangeAccent;

    return Scaffold(
      appBar: AppBar(title: const Text('HUD Text')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(accent),
              const SizedBox(height: 16),
              if (_handoffRecord != null) ...[
                _buildLastTransferCard(),
                const SizedBox(height: 16),
              ],
              _buildSectionLabel('COMPOSER'),
              const SizedBox(height: 10),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'HUD copy',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${_textController.text.trim().length} chars',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.46),
                            fontSize: 12,
                            fontFamily: 'SF Mono',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111A31),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                        controller: _textController,
                        minLines: 10,
                        maxLines: 14,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          color: Colors.white,
                          height: 1.5,
                          fontSize: 15,
                        ),
                        cursorColor: HelixTheme.cyan,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          hintText:
                              'Write the text you want to stage on the HUD',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.32),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This utility is for staged reading cards, not live AI answers. One transfer at a time.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildSectionLabel('ACTION'),
              const SizedBox(height: 10),
              Center(
                child: AbsorbPointer(
                  absorbing: !_canSend,
                  child: Opacity(
                    opacity: _canSend ? 1 : 0.48,
                    child: GlowButton(
                      label: _isSending ? 'Sending...' : 'Send to Glasses',
                      icon: _isSending
                          ? Icons.schedule_send
                          : Icons.send_outlined,
                      color: _isConnected ? HelixTheme.cyan : Colors.blueGrey,
                      isLoading: _isSending,
                      onPressed: _sendText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(Color accent) {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Icon(
              _isConnected ? Icons.subject_rounded : Icons.portable_wifi_off,
              color: accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isConnected
                      ? _statusBody
                      : 'Connect the glasses first. Text transfer is disabled while the device is offline.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastTransferCard() {
    final record = _handoffRecord!;
    final accent = switch (record.status) {
      HandoffStatus.pending => Colors.orangeAccent,
      HandoffStatus.delivered => const Color(0xFF7CFFB2),
      HandoffStatus.failed => Colors.redAccent,
    };
    final status = switch (record.status) {
      HandoffStatus.pending => 'IN FLIGHT',
      HandoffStatus.delivered => 'DELIVERED',
      HandoffStatus.failed => 'FAILED',
    };

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionLabel('LAST HANDOFF'),
              const Spacer(),
              Text(
                status,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            record.preview,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${record.source} • ${record.note ?? 'Transfer updated'}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          color: HelixTheme.cyan.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
