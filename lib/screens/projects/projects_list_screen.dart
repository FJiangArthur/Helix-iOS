// ABOUTME: Projects tab — list active projects and recently-deleted.

import 'package:flutter/material.dart';

import '../../services/database/helix_database.dart';
import '../../services/projects/projects_service.dart';
import '../../theme/helix_theme.dart';
import '../../utils/i18n.dart';
import 'project_detail_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  bool _showDeleted = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                        value: false, label: Text(tr('Active', '当前'))),
                    ButtonSegment(
                        value: true,
                        label: Text(tr('Recently deleted', '回收站'))),
                  ],
                  selected: {_showDeleted},
                  onSelectionChanged: (s) =>
                      setState(() => _showDeleted = s.first),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: tr('New project', '新建项目'),
                icon: const Icon(Icons.add),
                onPressed: () => _showNewProjectDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Project>>(
            stream: _showDeleted
                ? ProjectsService.instance.watchRecentlyDeleted()
                : ProjectsService.instance.watchProjects(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    _showDeleted
                        ? tr('No deleted projects.', '没有已删除的项目。')
                        : tr('No projects yet. Tap + to create one.',
                            '还没有项目，点击 + 创建一个。'),
                    style: const TextStyle(color: HelixTheme.textMuted),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = items[i];
                  return _ProjectCard(
                    project: p,
                    deleted: _showDeleted,
                    onTap: _showDeleted
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) =>
                                  ProjectDetailScreen(projectId: p.id),
                            )),
                    onUndo: _showDeleted
                        ? () async => ProjectsService.instance.undoDelete(p.id)
                        : null,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showNewProjectDialog(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('New project', '新建项目')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: tr('Project name', '项目名称')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('Cancel', '取消'))),
          TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, controller.text.trim()),
              child: Text(tr('Create', '创建'))),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ProjectsService.instance.createProject(name: name);
    }
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.deleted,
    this.onTap,
    this.onUndo,
  });
  final Project project;
  final bool deleted;
  final VoidCallback? onTap;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: deleted ? HelixTheme.surface.withOpacity(0.5) : HelixTheme.surface,
      child: ListTile(
        title: Text(project.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(project.description ?? '',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: onTap,
        trailing: deleted
            ? TextButton(onPressed: onUndo, child: Text(tr('Undo', '撤销')))
            : const Icon(Icons.chevron_right, color: HelixTheme.textMuted),
      ),
    );
  }
}
