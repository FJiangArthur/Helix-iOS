// ABOUTME: Project detail — documents list, upload, active-for-live toggle,
// ABOUTME: settings sheet, and "Ask this project" query box.
// ABOUTME: Placeholder — Task 14 fills this in.

import 'package:flutter/material.dart';

class ProjectDetailScreen extends StatelessWidget {
  const ProjectDetailScreen({super.key, required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project')),
      body: const Center(child: Text('Project detail — coming in next task')),
    );
  }
}
