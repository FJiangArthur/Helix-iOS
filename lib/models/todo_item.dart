// ABOUTME: Simple model for a to-do item, mapping to the Todos drift table.
// ABOUTME: Supports both manually created and AI-extracted to-dos.

class TodoItemModel {
  final String id;
  final String? conversationId;
  final String content;
  final bool isCompleted;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String source; // 'auto' or 'manual'

  const TodoItemModel({
    required this.id,
    this.conversationId,
    required this.content,
    this.isCompleted = false,
    this.dueDate,
    required this.createdAt,
    this.completedAt,
    this.source = 'auto',
  });
}
