import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hud_widget_config.dart';
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
          // Summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.dashboard_customize,
                    color: HelixTheme.cyan, size: 18),
                const SizedBox(width: 8),
                Text(
                  '$_enabledCount widgets enabled · ${_registry.pageCount} pages',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
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
                  style: TextButton.styleFrom(
                    foregroundColor: HelixTheme.cyan,
                  ),
                ),
              ],
            ),
          ),
          // Widget list
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
        ...List.generate(
          TodosWidget.cachedTodos.length,
          (i) {
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
          },
        ),
      ],
    );
  }
}
