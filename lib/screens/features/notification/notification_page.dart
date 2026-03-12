import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../ble_manager.dart';
import '../../../services/proto.dart';
import '../../../theme/helix_theme.dart';
import '../../../widgets/glass_card.dart';
import '../../../widgets/glow_button.dart';
import 'notify_model.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late final TextEditingController _appIdentifierController;
  late final TextEditingController _appNameController;
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _messageController;
  late final TextEditingController _actionController;
  late final TextEditingController _dateController;

  late List<NotifyAppModel> _whitelistApps;
  bool _isUpdatingWhitelist = false;
  bool _isSending = false;

  bool get _isConnected => BleManager.get().isConnected;
  Color get _statusAccent =>
      _isConnected ? const Color(0xFFFFA726) : Colors.orangeAccent;
  bool get _canSend =>
      _isConnected &&
      !_isSending &&
      _titleController.text.trim().isNotEmpty &&
      _messageController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _appIdentifierController = TextEditingController(text: 'com.even.test');
    _appNameController = TextEditingController(text: 'Even');
    _titleController = TextEditingController(text: 'Even Realities');
    _subtitleController = TextEditingController(text: 'Notify');
    _messageController = TextEditingController(
      text: 'This notification stays on the notification channel.',
    );
    _actionController = TextEditingController();
    _dateController = TextEditingController();
    _whitelistApps = [
      NotifyAppModel('com.even.test', 'Even'),
      NotifyAppModel('com.google.android.youtube', 'YouTube'),
    ];
  }

  @override
  void dispose() {
    _appIdentifierController.dispose();
    _appNameController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _messageController.dispose();
    _actionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _syncWhitelist() async {
    if (!_isConnected || _isUpdatingWhitelist) return;

    _upsertCurrentApp();
    setState(() => _isUpdatingWhitelist = true);

    try {
      await Proto.sendNewAppWhiteListJson(
        NotifyWhitelistModel(_whitelistApps).toJson(),
      );
      _showSnackBar('Whitelist synced to glasses.');
    } catch (error) {
      _showSnackBar('Failed to sync whitelist: $error');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingWhitelist = false);
      }
    }
  }

  Future<void> _sendNotification() async {
    if (!_canSend) return;

    _upsertCurrentApp();
    setState(() => _isSending = true);

    try {
      await Proto.sendNewAppWhiteListJson(
        NotifyWhitelistModel(_whitelistApps).toJson(),
      );
      await Proto.sendNotify(_buildNotification().toMap());
      _showSnackBar('Notification sent.');
    } catch (error) {
      _showSnackBar('Failed to send notification: $error');
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _upsertCurrentApp() {
    final identifier = _appIdentifierController.text.trim();
    final displayName = _appNameController.text.trim();

    if (identifier.isEmpty || displayName.isEmpty) return;

    final updated = NotifyAppModel(identifier, displayName);
    final index = _whitelistApps.indexWhere(
      (app) => app.identifier == identifier,
    );

    setState(() {
      if (index == -1) {
        _whitelistApps = [..._whitelistApps, updated];
      } else {
        _whitelistApps = [
          ..._whitelistApps.sublist(0, index),
          updated,
          ..._whitelistApps.sublist(index + 1),
        ];
      }
    });
  }

  NotifyModel _buildNotification() {
    final now = DateTime.now();
    final unixSeconds = now.millisecondsSinceEpoch ~/ 1000;

    return NotifyModel(
      now.millisecondsSinceEpoch,
      _appIdentifierController.text.trim(),
      _titleController.text.trim(),
      _subtitleController.text.trim(),
      _messageController.text.trim(),
      unixSeconds,
      _appNameController.text.trim(),
      _actionController.text.trim(),
      _dateController.text.trim(),
    );
  }

  String get _payloadPreview =>
      const JsonEncoder.withIndent('  ').convert(_buildNotification().toMap());

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: HelixTheme.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),
              const SizedBox(height: 16),
              _buildSection(
                'Source App',
                'The glasses only surface notifications from whitelisted app identifiers.',
                [
                  _buildField(
                    controller: _appIdentifierController,
                    label: 'App identifier',
                    hintText: 'com.even.test',
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _appNameController,
                    label: 'Display name',
                    hintText: 'Even',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _whitelistApps.map((app) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          app.displayName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _buildActionRow(
                    label: _isUpdatingWhitelist
                        ? 'Syncing...'
                        : 'Sync whitelist',
                    icon: Icons.playlist_add_check_circle_outlined,
                    onPressed: !_isConnected || _isUpdatingWhitelist
                        ? null
                        : _syncWhitelist,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                'Notification Payload',
                'Text delivery stays on the notification channel and no longer reuses the overview/text-display screen codes.',
                [
                  _buildField(
                    controller: _titleController,
                    label: 'Title',
                    hintText: 'Even Realities',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _subtitleController,
                    label: 'Subtitle',
                    hintText: 'Notify',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _messageController,
                    label: 'Message',
                    hintText: 'Notification text',
                    minLines: 4,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _actionController,
                    label: 'Action (optional)',
                    hintText: 'Open app',
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _dateController,
                    label: 'Date (optional)',
                    hintText: '2026-03-11 10:41',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                'Preview',
                'This is the payload written into the `ncs_notification` JSON object.',
                [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: SelectableText(
                      _payloadPreview,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        height: 1.5,
                        fontFamily: 'SF Mono',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: AbsorbPointer(
                  absorbing: !_canSend,
                  child: Opacity(
                    opacity: _canSend ? 1 : 0.48,
                    child: GlowButton(
                      label: _isSending ? 'Sending...' : 'Send Notification',
                      icon: Icons.notifications_active_outlined,
                      color: _canSend
                          ? const Color(0xFFFFA726)
                          : Colors.blueGrey,
                      isLoading: _isSending,
                      onPressed: _sendNotification,
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

  Widget _buildHeroCard() {
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
              color: _statusAccent.withValues(alpha: 0.14),
              border: Border.all(color: _statusAccent.withValues(alpha: 0.24)),
            ),
            child: Icon(
              _isConnected
                  ? Icons.notifications_active
                  : Icons.notifications_off_outlined,
              color: _statusAccent,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'G1 Notification Channel',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusAccent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _isConnected ? 'ARMED' : 'OFFLINE',
                        style: TextStyle(
                          color: _statusAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isConnected
                      ? 'Connected. Sync the whitelist, preview the payload, and push a notification without touching the AI or text-display channels.'
                      : 'Connect the glasses first. Notification writes stay disabled while the hardware channel is offline.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String subtitle, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: _statusAccent.withValues(alpha: 0.88),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
        ),
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    int minLines = 1,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF111A31),
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.28)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _statusAccent.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isEnabled
              ? _statusAccent.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isEnabled
                ? _statusAccent.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isEnabled ? _statusAccent : Colors.white38,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isEnabled ? Colors.white : Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
