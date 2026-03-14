import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ble_manager.dart';
import '../services/dashboard_service.dart';
import '../services/handoff_memory.dart';
import '../services/text_service.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glow_button.dart';
import 'even_features_screen.dart';

/// Glasses connection and management screen
class G1TestScreen extends StatefulWidget {
  const G1TestScreen({super.key});

  @override
  State<G1TestScreen> createState() => _G1TestScreenState();
}

class _G1TestScreenState extends State<G1TestScreen> {
  Timer? scanTimer;
  StreamSubscription<HandoffRecord?>? _handoffSub;
  StreamSubscription<DashboardDebugState>? _dashboardSub;
  bool isScanning = false;
  HandoffRecord? _lastHandoff;
  DashboardDebugState _dashboardState = DashboardService.instance.state;

  @override
  void initState() {
    super.initState();
    _lastHandoff = HandoffMemory.instance.current;
    BleManager.get().setMethodCallHandler();
    BleManager.get().startListening();
    BleManager.get().onStatusChanged = _refreshPage;
    _handoffSub = HandoffMemory.instance.stream.listen((record) {
      if (!mounted) return;
      setState(() => _lastHandoff = record);
    });
    _dashboardSub = DashboardService.instance.stream.listen((state) {
      if (!mounted) return;
      setState(() => _dashboardState = state);
    });
  }

  void _refreshPage() => setState(() {});

  Future<void> _startScan() async {
    setState(() => isScanning = true);
    await BleManager.get().startScan();
    scanTimer?.cancel();
    scanTimer = Timer(15.seconds, () {
      _stopScan();
    });
  }

  Future<void> _stopScan() async {
    if (isScanning) {
      await BleManager.get().stopScan();
      setState(() => isScanning = false);
    }
  }

  Future<void> _pushLastHandoff() async {
    final record = _lastHandoff;
    if (record == null || record.text.trim().isEmpty || !_isConnected) {
      return;
    }

    await TextService.get.startSendText(
      record.text.trim(),
      source: 'g1_console.replay',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Last handoff sent to the glasses.')),
    );
  }

  String get _connectionStatus => BleManager.get().getConnectionStatus();
  bool get _isConnected => BleManager.get().isConnected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeroCard(),
          const SizedBox(height: 16),
          if (_isConnected) ...[
            _buildTelemetryCard(),
            const SizedBox(height: 16),
            _buildDashboardDebugCard(),
            const SizedBox(height: 16),
            _buildLastHandoffCard(),
            const SizedBox(height: 16),
            _buildUtilityLauncher(),
            const SizedBox(height: 16),
            _buildDisconnectCard(),
          ] else ...[
            _buildConnectionWorkflow(),
            const SizedBox(height: 16),
            _buildPairedList(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    final isConnected = _isConnected;
    final accent = isConnected ? HelixTheme.cyan : Colors.orangeAccent;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: isConnected
                        ? [HelixTheme.cyan, const Color(0xFF00FF88)]
                        : [const Color(0xFFFFA726), const Color(0xFFFF7043)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  isConnected ? Icons.visibility_rounded : Icons.sensors_off,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected ? 'G1 Ready' : 'Waiting for Glasses',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _connectionStatus,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Text(
                  isConnected ? 'ONLINE' : 'OFFLINE',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isConnected
                ? 'The glasses are available for HUD utilities and cockpit handoff. Open Utilities to push text, notifications, or display tests.'
                : 'Scan for nearby glasses, pick a pair, and return here once the hardware channel is ready for utility workflows.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionWorkflow() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('CONNECTION FLOW'),
          const SizedBox(height: 12),
          Text(
            isScanning
                ? 'Scanning now. Nearby pairs will appear below as soon as the BLE discovery stream reports them.'
                : 'Start a scan to discover available left/right G1 pairs and connect directly into the utilities deck.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          if (isScanning)
            Column(
              children: [
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: HelixTheme.cyan,
                    strokeWidth: 2.2,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _stopScan,
                  child: const Text(
                    'Stop Scan',
                    style: TextStyle(color: HelixTheme.cyan),
                  ),
                ),
              ],
            )
          else
            GlowButton(
              label: 'Scan for Glasses',
              icon: Icons.bluetooth_searching_rounded,
              onPressed: _startScan,
            ),
        ],
      ),
    );
  }

  Widget _buildPairedList() {
    final glasses = BleManager.get().getPairedGlasses();

    if (glasses.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.bluetooth_disabled_rounded,
              size: 42,
              color: Colors.white.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 12),
            const Text(
              'No pairs discovered yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Run a scan and stay close to the glasses. Paired channels will show up here when both sides are visible.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.58),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('AVAILABLE PAIRS'),
        const SizedBox(height: 10),
        ...glasses.map(
          (g) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildGlassesCard(g),
          ),
        ),
      ],
    );
  }

  Widget _buildGlassesCard(Map<String, String> glasses) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () async {
          final channelNumber = glasses['channelNumber']!;
          await BleManager.get().connectToGlasses("Pair_$channelNumber");
          _refreshPage();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: HelixTheme.cyan.withValues(alpha: 0.14),
                  border: Border.all(
                    color: HelixTheme.cyan.withValues(alpha: 0.22),
                  ),
                ),
                child: const Icon(
                  Icons.bluetooth_connected_rounded,
                  color: HelixTheme.cyan,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pair ${glasses['channelNumber']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'L: ${glasses['leftDeviceName']}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'R: ${glasses['rightDeviceName']}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.28),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('SYSTEM SNAPSHOT'),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.battery_full_rounded,
            'Battery path',
            'Connected',
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildInfoRow(Icons.bluetooth_rounded, 'BLE channel', 'Active'),
          const Divider(color: Colors.white12, height: 24),
          _buildInfoRow(Icons.hearing_rounded, 'Microphone route', 'Ready'),
        ],
      ),
    );
  }

  Widget _buildDashboardDebugCard() {
    final lastTriggeredAt = _dashboardState.lastTriggeredAt;
    final lastTrigger =
        _dashboardState.lastTriggerLabel ?? 'No tilt trigger yet';
    final lastObserved =
        _dashboardState.lastObservedEventLabel ??
        'No device-order event observed';
    final lastObservedHex =
        _dashboardState.lastObservedEventHex ?? 'Waiting for hardware event';
    final snapshotText = _dashboardState.lastSnapshotText.trim().isEmpty
        ? 'Snapshot not resolved yet.'
        : _dashboardState.lastSnapshotText.trim();

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionLabel('TILT DASHBOARD'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: HelixTheme.cyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: HelixTheme.cyan.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  _dashboardState.renderPath.label.toUpperCase(),
                  style: const TextStyle(
                    color: HelixTheme.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.gesture_rounded,
            'Last trigger',
            lastTriggeredAt == null
                ? lastTrigger
                : '${_formatTime(lastTriggeredAt)} • $lastTrigger',
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildInfoRow(Icons.sensors_rounded, 'Observed event', lastObserved),
          const SizedBox(height: 10),
          Text(
            lastObservedHex,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 12,
              fontFamily: 'SF Mono',
              height: 1.4,
            ),
          ),
          if (_dashboardState.lastBlockedReason != null) ...[
            const SizedBox(height: 12),
            Text(
              _dashboardState.lastBlockedReason!,
              style: TextStyle(
                color: Colors.orangeAccent.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Last resolved snapshot',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF111A31),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              snapshotText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: 'Preview Dashboard',
            icon: Icons.dashboard_customize_outlined,
            color: HelixTheme.cyan,
            onPressed: () async {
              await DashboardService.instance.previewDashboard();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLastHandoffCard() {
    final record = _lastHandoff;
    final accent = switch (record?.status) {
      HandoffStatus.delivered => const Color(0xFF7CFFB2),
      HandoffStatus.failed => Colors.redAccent,
      HandoffStatus.pending => Colors.orangeAccent,
      null => Colors.white54,
    };
    final statusLabel = switch (record?.status) {
      HandoffStatus.delivered => 'DELIVERED',
      HandoffStatus.failed => 'FAILED',
      HandoffStatus.pending => 'IN FLIGHT',
      null => 'NO HANDOFF YET',
    };

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionLabel('LAST HANDOFF'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.22)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (record == null)
            Text(
              'No HUD handoff has been recorded in this session yet. Send a response or open HUD Text to stage one.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.66),
                fontSize: 13,
                height: 1.45,
              ),
            )
          else ...[
            Text(
              record.preview,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${record.source} • ${record.note ?? 'Transfer updated'}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: AbsorbPointer(
                    absorbing: !_isConnected,
                    child: Opacity(
                      opacity: _isConnected ? 1 : 0.48,
                      child: GlowButton(
                        label: 'Push Last Handoff',
                        icon: Icons.playlist_add_check_circle_outlined,
                        color: HelixTheme.cyan,
                        onPressed: () {
                          _pushLastHandoff();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: HelixTheme.cyan, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.68),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildUtilityLauncher() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('UTILITY DECK'),
          const SizedBox(height: 12),
          Text(
            'Launch focused tools for HUD text, notifications, and display-level testing without leaving the device console.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _UtilityChip(label: 'HUD Text', color: HelixTheme.cyan),
              _UtilityChip(label: 'Notifications', color: Color(0xFFFFA726)),
              _UtilityChip(label: 'BMP Canvas', color: Color(0xFF7CFFB2)),
            ],
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: 'Open Utilities',
            icon: Icons.auto_awesome_rounded,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FeaturesPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: TextButton.icon(
        onPressed: () async {
          await BleManager.get().disconnect();
          _refreshPage();
        },
        icon: const Icon(Icons.bluetooth_disabled_rounded, size: 18),
        label: const Text('Disconnect'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: HelixTheme.cyan.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }

  @override
  void dispose() {
    scanTimer?.cancel();
    _handoffSub?.cancel();
    _dashboardSub?.cancel();
    isScanning = false;
    BleManager.get().onStatusChanged = null;
    super.dispose();
  }
}

class _UtilityChip extends StatelessWidget {
  const _UtilityChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
