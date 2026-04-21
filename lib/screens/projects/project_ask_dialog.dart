// ABOUTME: Inline query dialog that streams an answer grounded in project docs.

import 'package:flutter/material.dart';

import '../../services/llm/llm_provider.dart';
import '../../services/llm/llm_service.dart';
import '../../services/projects/project_context_formatter.dart';
import '../../services/projects/project_rag_service.dart';
import '../../services/settings_manager.dart';

class ProjectAskDialog extends StatefulWidget {
  const ProjectAskDialog({super.key, required this.projectId});
  final String projectId;
  @override
  State<ProjectAskDialog> createState() => _ProjectAskDialogState();
}

class _ProjectAskDialogState extends State<ProjectAskDialog> {
  final _ctrl = TextEditingController();
  String _answer = '';
  bool _busy = false;
  List<RetrievedChunk> _citations = const [];

  Future<void> _ask() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _busy = true;
      _answer = '';
      _citations = const [];
    });
    try {
      final rag = await ProjectRagService.instance
          .retrieve(projectId: widget.projectId, query: q);
      const basePrompt = 'You are Helix, answering questions about the '
          "user's project documents. Be concise.";
      final systemPrompt =
          ProjectContextFormatter.prepend(basePrompt, rag.chunks);
      _citations = rag.chunks;

      await for (final chunk in LlmService.instance.streamResponse(
        systemPrompt: systemPrompt,
        messages: [ChatMessage(role: 'user', content: q)],
        temperature: SettingsManager.instance.temperature,
        model: SettingsManager.instance.resolvedSmartModel,
      )) {
        if (!mounted) return;
        setState(() => _answer += chunk);
      }
    } catch (e) {
      if (mounted) setState(() => _answer = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ask this project'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(hintText: 'Your question'),
              autofocus: true,
              onSubmitted: (_) => _ask(),
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_answer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(_answer),
              ),
            if (_citations.isNotEmpty) ...[
              const Divider(),
              const Text('Sources',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              for (var i = 0; i < _citations.length; i++)
                Text('[${i + 1}] ${_citations[i].documentFilename}'
                    '${_citations[i].pageStart != null ? ' p.${_citations[i].pageStart}' : ''}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
        FilledButton(onPressed: _busy ? null : _ask, child: const Text('Ask')),
      ],
    );
  }
}
