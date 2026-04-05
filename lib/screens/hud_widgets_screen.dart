import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/hud_widget_config.dart';
import '../services/bitmap_hud/bitmap_hud_service.dart';
import '../services/bitmap_hud/bitmap_renderer.dart';
import '../services/bitmap_hud/display_constants.dart';
import '../services/bitmap_hud/enhanced_layout_presets.dart';
import '../services/bitmap_hud/hud_layout_presets.dart';
import '../services/dashboard_service.dart';
import '../services/hud_widget_registry.dart';
import '../services/hud_widgets/todos_widget.dart';
import '../services/settings_manager.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';

class HudWidgetsScreen extends StatefulWidget {
  const HudWidgetsScreen({super.key});

  @override
  State<HudWidgetsScreen> createState() => _HudWidgetsScreenState();
}

class _HudWidgetsScreenState extends State<HudWidgetsScreen> {
  final _settings = SettingsManager.instance;
  final _registry = HudWidgetRegistry.instance;
  late List<HudWidgetConfig> _configs;
  StreamSubscription? _settingsSub;

  // Todo management
  final _todoController = TextEditingController();

  // Bitmap preview
  ui.Image? _previewImage;
  bool _loadingPreview = false;

  @override
  void initState() {
    super.initState();
    _reloadConfigs();
    _settingsSub = _settings.onSettingsChanged.listen((_) {
      if (mounted) {
        _reloadConfigs();
        setState(() {});
      }
    });
    // Ensure todos are loaded for the todo manager UI
    _registry.refreshWidget('todos').then((_) {
      if (mounted) setState(() {});
    });
  }

  void _reloadConfigs() {
    _configs = List.from(_settings.hudWidgetConfigs)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _todoController.dispose();
    _previewImage?.dispose();
    super.dispose();
  }

  Future<void> _saveConfigs() async {
    // Update sort orders based on list position
    for (var i = 0; i < _configs.length; i++) {
      _configs[i].sortOrder = i;
    }
    await _settings.update((s) => s.hudWidgetConfigs = List.from(_configs));
    _registry.updateConfigs(_configs);
  }

  int get _enabledCount => _configs.where((c) => c.enabled).length;

  Future<void> _refreshPreview() async {
    if (_loadingPreview) return;
    setState(() => _loadingPreview = true);
    try {
      final service = BitmapHudService.instance;
      final image = await BitmapRenderer.renderToImage(
        service.activeLayout,
        service.zoneWidgets,
      );
      _previewImage?.dispose();
      if (mounted) {
        setState(() {
          _previewImage = image;
          _loadingPreview = false;
        });
      } else {
        image.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Widget _buildBitmapPreview() {
    final isBitmapMode = _settings.hudRenderPath == 'bitmap' ||
        _settings.hudRenderPath == 'enhanced';
    if (!isBitmapMode) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.visibility, color: HelixTheme.cyan, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Glasses Preview',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _refreshPreview,
                  icon: _loadingPreview
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54))
                      : const Icon(Icons.refresh, size: 14),
                  label: const Text('Refresh'),
                  style: TextButton.styleFrom(
                    foregroundColor: HelixTheme.cyan,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: AspectRatio(
                aspectRatio: G1Display.width.toDouble() / G1Display.height,
                child: _previewImage != null
                    ? CustomPaint(
                        painter: _GlassesPreviewPainter(_previewImage!),
                        size: Size.infinite,
                      )
                    : Center(
                        child: Text(
                          'Tap Refresh to preview',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${G1Display.width}x${G1Display.height} · 1-bit · green micro-LED',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      appBar: AppBar(
        title: const Text('HUD Widgets'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // HUD Mode Selector (3-way)
          _buildHudModeSelector(),
          // Bitmap layout picker (when bitmap mode active)
          if (_settings.hudRenderPath == 'bitmap') _buildLayoutPicker(),
          // Enhanced layout picker (when enhanced mode active)
          if (_settings.hudRenderPath == 'enhanced')
            _buildEnhancedLayoutPicker(),
          // Bitmap preview
          _buildBitmapPreview(),
          // Summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.dashboard_customize,
                  color: HelixTheme.cyan,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _summaryText(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () {
                    DashboardService.instance.previewDashboard();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dashboard sent to glasses'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.preview, size: 16),
                  label: const Text('Preview'),
                  style: TextButton.styleFrom(foregroundColor: HelixTheme.cyan),
                ),
              ],
            ),
          ),
          // Widget list (text mode) or stock ticker settings (bitmap mode)
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _configs.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _configs.removeAt(oldIndex);
                  _configs.insert(newIndex, item);
                });
                _saveConfigs();
              },
              itemBuilder: (context, index) {
                final config = _configs[index];
                return _buildWidgetTile(config, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetTile(HudWidgetConfig config, int index) {
    final widget = _registry.getWidget(config.widgetId);
    final lines = widget?.renderLines() ?? [];
    final preview = lines.isNotEmpty ? lines.first : 'No data';
    final isTodo = config.widgetId == 'todos';

    return GlassCard(
      key: ValueKey(config.widgetId),
      child: Column(
        children: [
          Row(
            children: [
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 12),
              // Icon
              Icon(
                widget?.icon ?? Icons.widgets,
                color: config.enabled
                    ? HelixTheme.cyan
                    : Colors.white.withValues(alpha: 0.3),
                size: 22,
              ),
              const SizedBox(width: 12),
              // Name + preview
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget?.displayName ?? config.widgetId,
                      style: TextStyle(
                        color: config.enabled
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (config.enabled)
                      Text(
                        preview,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Toggle
              Switch(
                value: config.enabled,
                activeTrackColor: HelixTheme.cyan,
                onChanged: (value) {
                  setState(() => config.enabled = value);
                  _saveConfigs();
                },
              ),
            ],
          ),
          // Todo management section
          if (isTodo && config.enabled) ...[
            const SizedBox(height: 8),
            _buildTodoManager(),
          ],
          // Weather location info
          if (config.widgetId == 'weather' && config.enabled) ...[
            const SizedBox(height: 4),
            Text(
              'Using device location for weather',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          ],
          // News feed info
          if (config.widgetId == 'news' && config.enabled) ...[
            const SizedBox(height: 4),
            Text(
              'Source: BBC World News',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _summaryText() {
    final path = _settings.hudRenderPath;
    if (path == 'enhanced') {
      return 'Enhanced HUD · ${_settings.enhancedLayoutPreset.replaceAll('_', ' ')} layout';
    } else if (path == 'bitmap') {
      return 'Bitmap HUD · ${_settings.bitmapLayoutPreset} layout';
    }
    return '$_enabledCount widgets enabled · ${_registry.pageCount} pages';
  }

  Widget _buildHudModeSelector() {
    final current = _settings.hudRenderPath;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.display_settings, color: HelixTheme.cyan, size: 20),
                const SizedBox(width: 12),
                const Text(
                  'HUD Display Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildModeChip('text', 'Text', Icons.text_fields, current),
                const SizedBox(width: 8),
                _buildModeChip('bitmap', 'Bitmap', Icons.grid_view, current),
                const SizedBox(width: 8),
                _buildModeChip(
                  'enhanced',
                  'Enhanced',
                  Icons.auto_awesome,
                  current,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _modeDescription(current),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChip(
    String value,
    String label,
    IconData icon,
    String current,
  ) {
    final selected = current == value;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          await _settings.update((s) => s.hudRenderPath = value);
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? HelixTheme.cyan
                  : Colors.white.withValues(alpha: 0.15),
              width: selected ? 2 : 1,
            ),
            color: selected
                ? HelixTheme.cyan.withValues(alpha: 0.15)
                : Colors.transparent,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? HelixTheme.cyan : Colors.white54,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? HelixTheme.cyan : Colors.white70,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeDescription(String mode) {
    return switch (mode) {
      'text' => 'Text-only display (24 chars × 5 lines)',
      'bitmap' => 'Graphical dashboard with charts & icons',
      'enhanced' =>
        'Data-dense display with progress rings, charts & multi-widget layouts',
      _ => '',
    };
  }

  Widget _buildLayoutPicker() {
    final presets = HudLayoutPresets.all();
    final current = _settings.bitmapLayoutPreset;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: presets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final preset = presets[index];
            final selected = preset.id == current;
            return GestureDetector(
              onTap: () async {
                await _settings.update((s) => s.bitmapLayoutPreset = preset.id);
                setState(() {});
              },
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? HelixTheme.cyan
                        : Colors.white.withValues(alpha: 0.15),
                    width: selected ? 2 : 1,
                  ),
                  color: selected
                      ? HelixTheme.cyan.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _layoutIcon(preset.id),
                      color: selected ? HelixTheme.cyan : Colors.white54,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.name,
                      style: TextStyle(
                        color: selected ? HelixTheme.cyan : Colors.white70,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _layoutIcon(String presetId) {
    return switch (presetId) {
      'classic' => Icons.grid_view,
      'minimal' => Icons.view_agenda,
      'dense' => Icons.dashboard,
      'conversation' => Icons.mic,
      _ => Icons.view_module,
    };
  }

  Widget _buildEnhancedLayoutPicker() {
    final presets = EnhancedLayoutPresets.all();
    final current = _settings.enhancedLayoutPreset;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: presets.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final preset = presets[index];
            final selected = preset.id == current;
            return GestureDetector(
              onTap: () async {
                await _settings.update(
                  (s) => s.enhancedLayoutPreset = preset.id,
                );
                setState(() {});
              },
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? HelixTheme.cyan
                        : Colors.white.withValues(alpha: 0.15),
                    width: selected ? 2 : 1,
                  ),
                  color: selected
                      ? HelixTheme.cyan.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.05),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _enhancedLayoutIcon(preset.id),
                      color: selected ? HelixTheme.cyan : Colors.white54,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preset.name,
                      style: TextStyle(
                        color: selected ? HelixTheme.cyan : Colors.white70,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  IconData _enhancedLayoutIcon(String presetId) {
    return switch (presetId) {
      'command_center' => Icons.space_dashboard,
      'cockpit' => Icons.flight_takeoff,
      'focus' => Icons.center_focus_strong,
      _ => Icons.auto_awesome,
    };
  }

  Widget _buildTodoManager() {
    final todosWidget = _registry.getWidget('todos');
    if (todosWidget is! TodosWidget) return const SizedBox.shrink();

    return Column(
      children: [
        // Add todo input
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _todoController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add a todo...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                onSubmitted: (text) async {
                  if (text.trim().isEmpty) return;
                  await TodosWidget.addTodo(text.trim());
                  _todoController.clear();
                  await _registry.refreshWidget('todos');
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              iconSize: 20,
              onPressed: () async {
                final text = _todoController.text.trim();
                if (text.isEmpty) return;
                await TodosWidget.addTodo(text);
                _todoController.clear();
                await _registry.refreshWidget('todos');
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Todo list
        ...List.generate(TodosWidget.cachedTodos.length, (i) {
          final todo = TodosWidget.cachedTodos[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await TodosWidget.toggleTodo(i);
                    await _registry.refreshWidget('todos');
                    if (mounted) setState(() {});
                  },
                  child: Icon(
                    todo['done'] == true
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: HelixTheme.cyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    todo['text'] as String? ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(
                        alpha: todo['done'] == true ? 0.4 : 0.8,
                      ),
                      decoration: todo['done'] == true
                          ? TextDecoration.lineThrough
                          : null,
                      fontSize: 13,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  onPressed: () async {
                    await TodosWidget.removeTodo(i);
                    await _registry.refreshWidget('todos');
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _GlassesPreviewPainter extends CustomPainter {
  _GlassesPreviewPainter(this.image);
  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    // Map white to green to simulate G1 micro-LED display
    final greenPaint = Paint()
      ..colorFilter = const ColorFilter.matrix(<double>[
        0, 0, 0, 0, 0,     // R = 0
        1, 0, 0, 0, 0,     // G = source R (white R=1 -> G=1)
        0, 0, 0, 0, 0,     // B = 0
        0, 0, 0, 1, 0,     // A = source A
      ]);

    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, src, dst, greenPaint);
  }

  @override
  bool shouldRepaint(_GlassesPreviewPainter old) => old.image != image;
}
