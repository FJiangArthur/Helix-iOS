// ABOUTME: Bottom sheet for per-project RAG tuning (chunk size, topK, threshold).

import 'package:flutter/material.dart';

import '../../services/database/helix_database.dart';
import '../../services/projects/projects_service.dart';

class ProjectSettingsSheet extends StatefulWidget {
  const ProjectSettingsSheet({super.key, required this.project});
  final Project project;

  @override
  State<ProjectSettingsSheet> createState() => _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends State<ProjectSettingsSheet> {
  late int _chunk;
  late int _overlap;
  late int _topK;
  late double _threshold;

  @override
  void initState() {
    super.initState();
    _chunk = widget.project.chunkSizeTokens;
    _overlap = widget.project.chunkOverlapTokens;
    _topK = widget.project.retrievalTopK;
    _threshold = widget.project.retrievalMinSimilarity;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Project settings',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _Slider(
            label: 'Chunk size (tokens)',
            value: _chunk.toDouble(),
            min: 200,
            max: 2000,
            divisions: 36,
            onChanged: (v) => setState(() => _chunk = v.round()),
          ),
          _Slider(
            label: 'Chunk overlap (tokens)',
            value: _overlap.toDouble(),
            min: 0,
            max: 400,
            divisions: 40,
            onChanged: (v) => setState(() => _overlap = v.round()),
          ),
          _Slider(
            label: 'Top-K results',
            value: _topK.toDouble(),
            min: 1,
            max: 15,
            divisions: 14,
            onChanged: (v) => setState(() => _topK = v.round()),
          ),
          _Slider(
            label:
                'Similarity threshold (${_threshold.toStringAsFixed(2)})',
            value: _threshold,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: (v) => setState(() => _threshold = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: () => setState(() {
                  _chunk = 800;
                  _overlap = 100;
                  _topK = 5;
                  _threshold = 0.3;
                }),
                child: const Text('Reset to defaults'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await ProjectsService.instance.updateProject(
                    id: widget.project.id,
                    chunkSizeTokens: _chunk,
                    chunkOverlapTokens: _overlap,
                    retrievalTopK: _topK,
                    retrievalMinSimilarity: _threshold,
                  );
                  if (!mounted) return;
                  navigator.pop();
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}'),
        Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged),
      ],
    );
  }
}
