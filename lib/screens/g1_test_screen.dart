import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../ble_manager.dart';
import '../services/dashboard_service.dart';
import '../services/handoff_memory.dart';
import '../services/hud_widget_registry.dart';
import '../services/settings_manager.dart';
import '../services/text_service.dart';
import '../theme/helix_theme.dart';
import '../utils/i18n.dart';
import '../widgets/glass_card.dart';
import '../widgets/glow_button.dart';
import 'even_features_screen.dart';
import 'hud_widgets_screen.dart';

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
  bool _hasScannedOnce = false;
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
      setState(() {
        isScanning = false;
        _hasScannedOnce = true;
      });
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
      SnackBar(content: Text(tr('Last handoff sent to the glasses.', '上次交接已发送到眼镜。'))),
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
          _buildMicSourceSection(),
          const SizedBox(height: 16),
          _buildGlassesSettings(),
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
                      isConnected ? tr('G1 Ready', 'G1 就绪') : tr('Waiting for Glasses', '等待眼镜连接'),
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
                  isConnected ? tr('ONLINE', '在线') : tr('OFFLINE', '离线'),
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
                ? tr('The glasses are available for HUD utilities and cockpit handoff. Open Utilities to push text, notifications, or display tests.',
                     '眼镜已就绪，可用于 HUD 工具和座舱交接。打开工具集可推送文本、通知或显示测试。')
                : tr('Scan for nearby glasses, pick a pair, and return here once the hardware channel is ready for utility workflows.',
                     '扫描附近的眼镜，选择一对，待硬件通道就绪后返回此处进行工具操作。'),
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

  Widget _buildMicSourceSection() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(tr('MIC SOURCE', '麦克风源')),
          const SizedBox(height: 12),
          ...['phone', 'glasses', 'auto'].map((source) {
            final isSelected = SettingsManager.instance.preferredMicSource == source;
            final label = switch (source) {
              'phone' => tr('Phone only', '仅手机'),
              'glasses' => tr('Glasses mic', '眼镜麦克风'),
              'auto' => tr('Auto (glasses when connected)', '自动（连接时用眼镜）'),
              _ => source,
            };
            final icon = switch (source) {
              'phone' => Icons.phone_iphone,
              'glasses' => Icons.visibility,
              'auto' => Icons.auto_awesome,
              _ => Icons.mic,
            };
            return RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  Icon(icon, color: isSelected ? HelixTheme.cyan : Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                  )),
                ],
              ),
              value: source,
              groupValue: SettingsManager.instance.preferredMicSource,
              activeColor: HelixTheme.cyan,
              onChanged: (v) async {
                if (v != null) {
                  await SettingsManager.instance.update((s) => s.preferredMicSource = v);
                  setState(() {});
                }
              },
            );
          }),
          const Divider(color: Colors.white12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Noise reduction', '降噪'), style: const TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: Text(
              tr('RNNoise denoising for glasses mic', '眼镜麦克风 RNNoise 降噪'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
            ),
            value: SettingsManager.instance.noiseReduction,
            activeColor: HelixTheme.cyan,
            onChanged: (v) async {
              await SettingsManager.instance.update((s) => s.noiseReduction = v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassesSettings() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(tr('GLASSES SETTINGS', '眼镜设置')),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              tr('Auto-connect', '自动连接'),
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              tr('Connect when glasses are in range', '眼镜在范围内时自动连接'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            value: SettingsManager.instance.autoConnect,
            activeColor: HelixTheme.cyan,
            onChanged: (v) async {
              await SettingsManager.instance.update((s) => s.autoConnect = v);
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('HUD Brightness', 'HUD 亮度'),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Slider(
                value: SettingsManager.instance.hudBrightness,
                activeColor: HelixTheme.cyan,
                inactiveColor: Colors.white.withValues(alpha: 0.15),
                onChanged: (v) async {
                  await SettingsManager.instance
                      .update((s) => s.hudBrightness = v);
                  setState(() {});
                },
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.dashboard_customize,
              color: HelixTheme.cyan,
              size: 20,
            ),
            title: Text(
              tr('HUD Widgets', 'HUD 小组件'),
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              '${SettingsManager.instance.hudWidgetConfigs.where((c) => c.enabled).length} widgets · ${HudWidgetRegistry.instance.pageCount} pages',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HudWidgetsScreen()),
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
          _buildSectionLabel(tr('CONNECTION FLOW', '连接流程')),
          const SizedBox(height: 12),
          Text(
            isScanning
                ? tr('Scanning now. Nearby pairs will appear below as soon as the BLE discovery stream reports them.',
                     '正在扫描。附近的配对设备将在 BLE 发现流报告后立即显示在下方。')
                : tr('Start a scan to discover available left/right G1 pairs and connect directly into the utilities deck.',
                     '开始扫描以发现可用的左/右 G1 配对，并直接连接到工具面板。'),
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
                  child: Text(
                    tr('Stop Scan', '停止扫描'),
                    style: const TextStyle(color: HelixTheme.cyan),
                  ),
                ),
              ],
            )
          else
            GlowButton(
              label: tr('Scan for Glasses', '扫描眼镜'),
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
      return Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Icon(
                  Icons.bluetooth_disabled_rounded,
                  size: 42,
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                const SizedBox(height: 12),
                Text(
                  tr('No pairs discovered yet', '尚未发现配对设备'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tr('Run a scan and stay close to the glasses. Paired channels will show up here when both sides are visible.',
                     '运行扫描并靠近眼镜。当两侧都可见时，配对通道将显示在此处。'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          if (_hasScannedOnce) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HelixTheme.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: HelixTheme.amber.withValues(alpha: 0.24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: HelixTheme.amber.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr("Can't find your glasses?",
                             '找不到你的眼镜？'),
                          style: TextStyle(
                            color: HelixTheme.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('If your G1 is connected to the Even official app, close it first. Only one app can connect to the glasses at a time.',
                             '如果你的 G1 已连接到 Even 官方应用，请先关闭该应用。同一时间只能有一个应用连接眼镜。'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel(tr('AVAILABLE PAIRS', '可用配对')),
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
          _buildSectionLabel(tr('SYSTEM SNAPSHOT', '系统快照')),
          const SizedBox(height: 14),
          _buildInfoRow(
            Icons.battery_full_rounded,
            tr('Battery path', '电池路径'),
            tr('Connected', '已连接'),
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildInfoRow(Icons.bluetooth_rounded, tr('BLE channel', 'BLE 通道'), tr('Active', '活跃')),
          const Divider(color: Colors.white12, height: 24),
          _buildInfoRow(Icons.hearing_rounded, tr('Microphone route', '麦克风路由'), tr('Ready', '就绪')),
        ],
      ),
    );
  }

  Widget _buildDashboardDebugCard() {
    final lastTriggeredAt = _dashboardState.lastTriggeredAt;
    final lastTrigger =
        _dashboardState.lastTriggerLabel ?? tr('No tilt trigger yet', '尚无倾斜触发');
    final lastObserved =
        _dashboardState.lastObservedEventLabel ??
        tr('No device-order event observed', '未观察到设备顺序事件');
    final lastObservedHex =
        _dashboardState.lastObservedEventHex ?? tr('Waiting for hardware event', '等待硬件事件');
    final snapshotText = _dashboardState.lastSnapshotText.trim().isEmpty
        ? tr('Snapshot not resolved yet.', '快照尚未解析。')
        : _dashboardState.lastSnapshotText.trim();

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionLabel(tr('TILT DASHBOARD', '倾斜仪表板')),
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
            tr('Last trigger', '上次触发'),
            lastTriggeredAt == null
                ? lastTrigger
                : '${_formatTime(lastTriggeredAt)} • $lastTrigger',
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildInfoRow(Icons.sensors_rounded, tr('Observed event', '观察到的事件'), lastObserved),
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
            tr('Last resolved snapshot', '上次解析的快照'),
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
            label: tr('Preview Dashboard', '预览仪表板'),
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
      HandoffStatus.delivered => tr('DELIVERED', '已送达'),
      HandoffStatus.failed => tr('FAILED', '失败'),
      HandoffStatus.pending => tr('IN FLIGHT', '传输中'),
      null => tr('NO HANDOFF YET', '暂无交接'),
    };

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionLabel(tr('LAST HANDOFF', '上次交接')),
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
              tr('No HUD handoff has been recorded in this session yet. Send a response or open HUD Text to stage one.',
                 '本次会话尚未记录 HUD 交接。发送响应或打开 HUD 文本以准备一个。'),
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
                        label: tr('Push Last Handoff', '推送上次交接'),
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
          _buildSectionLabel(tr('UTILITY DECK', '工具面板')),
          const SizedBox(height: 12),
          Text(
            tr('Launch focused tools for HUD text, notifications, and display-level testing without leaving the device console.',
               '启动专用工具进行 HUD 文本、通知和显示级测试，无需离开设备控制台。'),
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
            label: tr('Open Utilities', '打开工具'),
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
        label: Text(tr('Disconnect', '断开连接')),
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
