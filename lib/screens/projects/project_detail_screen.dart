// ABOUTME: Project detail — documents list, upload, active-for-live toggle,
// ABOUTME: settings sheet, and "Ask this project" query box.

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/database/helix_database.dart';
import '../../services/projects/active_project_controller.dart';
import '../../services/projects/document_ingest_service.dart';
import '../../services/projects/openai_embeddings_client.dart';
import '../../services/projects/projects_service.dart';
import '../../services/settings_manager.dart';
import 'project_ask_dialog.dart';
import 'project_settings_sheet.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Future<void> _upload(String projectId) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      withData: false,
    );
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.single;
    final path = f.path;
    if (path == null) return;

    final apiKey = await SettingsManager.instance.getApiKey('openai') ?? '';
    final ingest = DocumentIngestService(
      embeddingClientFactory: () => OpenAiEmbeddingsClient(
        apiKey: apiKey,
        model: 'text-embedding-3-small',
      ),
    );
    try {
      await for (final event in ingest.ingestDocument(
        projectId: projectId,
        filePath: path,
        filename: f.name,
      )) {
        if (!mounted) continue;
        if (event is IngestFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ingest failed: ${event.error}')));
        } else if (event is IngestCompleted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Document ready.')));
        }
      }
    } finally {
      ingest.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Project>>(
      stream: ProjectsService.instance.watchProjects(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final projects = snap.data!;
        final match =
            projects.where((p) => p.id == widget.projectId).toList();
        if (match.isEmpty) {
          return const Scaffold(
              body: Center(child: Text('Project not found')));
        }
        final project = match.single;
        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                tooltip: 'Ask this project',
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => ProjectAskDialog(projectId: project.id),
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.tune),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ProjectSettingsSheet(project: project),
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await ProjectsService.instance.softDelete(project.id);
                  if (!mounted) return;
                  navigator.pop();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _ActiveForLiveTile(project: project),
              Expanded(child: _DocumentsList(projectId: project.id)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _upload(project.id),
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload'),
          ),
        );
      },
    );
  }
}

class _ActiveForLiveTile extends StatelessWidget {
  const _ActiveForLiveTile({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: ActiveProjectController.instance.activeProjectStream,
      initialData: ActiveProjectController.instance.activeProjectId,
      builder: (_, snap) {
        final isActive = snap.data == project.id;
        return ListTile(
          leading: Icon(isActive ? Icons.star : Icons.star_border,
              color: isActive ? Colors.amber : null),
          title: Text(isActive
              ? 'Active for live session'
              : 'Use for live session'),
          trailing: Switch(
            value: isActive,
            onChanged: (v) => ActiveProjectController.instance
                .setActive(v ? project.id : null),
          ),
        );
      },
    );
  }
}

class _DocumentsList extends StatelessWidget {
  const _DocumentsList({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ProjectDocument>>(
      stream: HelixDatabase.instance.projectDao
          .watchDocumentsForProject(projectId),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!;
        if (docs.isEmpty) {
          return const Center(
              child: Text('No documents. Tap Upload to add one.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i];
            return ListTile(
              leading: Icon(d.contentType == 'pdf'
                  ? Icons.picture_as_pdf
                  : Icons.description),
              title: Text(d.filename),
              subtitle: Text('Status: ${d.ingestStatus}'
                  '${d.pageCount != null ? '  ·  ${d.pageCount} pages' : ''}'
                  '${d.ingestError != null ? '\n${d.ingestError}' : ''}'),
              isThreeLine: d.ingestError != null,
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () =>
                    HelixDatabase.instance.projectDao.softDeleteDocument(d.id),
              ),
            );
          },
        );
      },
    );
  }
}
