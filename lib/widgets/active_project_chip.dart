// ABOUTME: Compact chip showing the active-for-live project; taps open picker.

import 'package:flutter/material.dart';

import '../services/database/helix_database.dart';
import '../services/projects/active_project_controller.dart';
import '../services/projects/projects_service.dart';
import '../theme/helix_theme.dart';

class ActiveProjectChip extends StatelessWidget {
  const ActiveProjectChip({super.key});

  @override
  Widget build(BuildContext context) {
    // Gracefully no-op if the controller hasn't been loaded yet (e.g. in
    // widget tests that don't run main.dart). Production always calls
    // ActiveProjectController.load() in main() before runApp.
    final ActiveProjectController controller;
    try {
      controller = ActiveProjectController.instance;
    } on StateError {
      return const SizedBox.shrink();
    }

    return StreamBuilder<String?>(
      stream: controller.activeProjectStream,
      initialData: controller.activeProjectId,
      builder: (ctx, activeSnap) {
        final activeId = activeSnap.data;
        return StreamBuilder<List<Project>>(
          stream: ProjectsService.instance.watchProjects(),
          initialData: const [],
          builder: (ctx, projSnap) {
            final projects = projSnap.data ?? const [];
            Project? active;
            if (activeId != null) {
              final found =
                  projects.where((p) => p.id == activeId).toList();
              active = found.isNotEmpty ? found.single : null;
            }
            final label = active == null
                ? 'No project'
                : 'Project: ${active.name}';
            return GestureDetector(
              onTap: () => _showPicker(context, projects, activeId),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: active != null
                          ? HelixTheme.cyan
                          : HelixTheme.textMuted.withValues(alpha: 0.3)),
                  color: active != null
                      ? HelixTheme.cyan.withValues(alpha: 0.08)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        active != null ? Icons.star : Icons.star_border,
                        size: 16,
                        color: active != null
                            ? HelixTheme.cyan
                            : HelixTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(label,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showPicker(
      BuildContext context, List<Project> projects, String? activeId) async {
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear),
              title: const Text('No project'),
              trailing: activeId == null ? const Icon(Icons.check) : null,
              onTap: () async {
                await ActiveProjectController.instance.setActive(null);
                if (context.mounted) Navigator.pop(ctx);
              },
            ),
            const Divider(height: 1),
            for (final p in projects)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.name),
                trailing:
                    p.id == activeId ? const Icon(Icons.check) : null,
                onTap: () async {
                  await ActiveProjectController.instance.setActive(p.id);
                  if (context.mounted) Navigator.pop(ctx);
                },
              ),
            if (projects.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                    'No projects yet. Create one in the Projects tab.'),
              ),
          ],
        ),
      ),
    );
  }
}
