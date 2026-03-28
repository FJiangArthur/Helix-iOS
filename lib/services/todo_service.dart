// ABOUTME: Singleton service managing the to-do lifecycle.
// ABOUTME: Delegates all persistence to TodoDao. Supports manual and AI-extracted to-dos.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';
import 'database/helix_database.dart';
import 'database/todo_dao.dart';

class TodoService {
  static TodoService? _instance;
  static TodoService get instance => _instance ??= TodoService._();
  TodoService._();

  static const _uuid = Uuid();

  TodoDao get _dao => HelixDatabase.instance.todoDao;

  /// Add a manually created to-do.
  Future<void> addTodo(String content, {DateTime? dueDate}) async {
    final now = DateTime.now();
    final entry = TodosCompanion(
      id: Value(_uuid.v4()),
      content: Value(content),
      source: const Value('manual'),
      createdAt: Value(now.millisecondsSinceEpoch),
      dueDate: dueDate != null
          ? Value(dueDate.millisecondsSinceEpoch)
          : const Value.absent(),
    );
    await _dao.insertTodo(entry);
    appLogger.i('[TodoService] Added manual todo: ${content.substring(0, content.length.clamp(0, 40))}');
  }

  /// Add auto-extracted to-dos from the AI pipeline (batch insert).
  ///
  /// Each item in [items] should contain at least a `content` key.
  /// Optional keys: `dueDate` (ISO 8601 string).
  Future<void> addExtractedTodos(
    String conversationId,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return;

    for (final item in items) {
      final content = item['content'] as String? ?? '';
      if (content.isEmpty) continue;

      DateTime? dueDate;
      if (item['dueDate'] != null) {
        dueDate = DateTime.tryParse(item['dueDate'] as String);
      }

      final entry = TodosCompanion(
        id: Value(_uuid.v4()),
        conversationId: Value(conversationId),
        content: Value(content),
        source: const Value('auto'),
        createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        dueDate: dueDate != null
            ? Value(dueDate.millisecondsSinceEpoch)
            : const Value.absent(),
      );
      await _dao.insertTodo(entry);
    }
    appLogger.i(
      '[TodoService] Added ${items.length} extracted todo(s) for conversation $conversationId',
    );
  }

  /// Toggle to-do completion state.
  Future<void> toggleComplete(String todoId) async {
    await _dao.toggleTodoComplete(todoId);
    appLogger.d('[TodoService] Toggled todo $todoId');
  }

  /// Delete a to-do.
  Future<void> deleteTodo(String todoId) async {
    await _dao.deleteTodo(todoId);
    appLogger.d('[TodoService] Deleted todo $todoId');
  }

  /// Watch all to-dos (incomplete first, then by creation date).
  Stream<List<Todo>> watchTodos() {
    return _dao.watchTodos();
  }

  /// Get all incomplete to-dos.
  Future<List<Todo>> getIncompleteTodos() {
    return _dao.getIncompleteTodos();
  }
}
