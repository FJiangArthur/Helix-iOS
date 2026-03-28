import 'package:drift/drift.dart';

import 'helix_database.dart';

part 'todo_dao.g.dart';

@DriftAccessor(tables: [Todos])
class TodoDao extends DatabaseAccessor<HelixDatabase>
    with _$TodoDaoMixin {
  TodoDao(super.db);

  /// Insert a new todo.
  Future<void> insertTodo(TodosCompanion entry) {
    return into(todos).insert(entry);
  }

  /// Update an existing todo.
  Future<bool> updateTodo(TodosCompanion entry) {
    return (update(todos)..where((t) => t.id.equals(entry.id.value)))
        .write(entry)
        .then((rows) => rows > 0);
  }

  /// Toggle the completed state.
  Future<void> toggleTodoComplete(String id) async {
    final todo =
        await (select(todos)..where((t) => t.id.equals(id))).getSingle();
    final now = DateTime.now().millisecondsSinceEpoch;
    await (update(todos)..where((t) => t.id.equals(id))).write(
      TodosCompanion(
        isCompleted: Value(!todo.isCompleted),
        completedAt:
            !todo.isCompleted ? Value(now) : const Value(null),
      ),
    );
  }

  /// Delete a todo by id.
  Future<int> deleteTodo(String id) {
    return (delete(todos)..where((t) => t.id.equals(id))).go();
  }

  /// Stream of all todos, incomplete first then by creation date.
  Stream<List<Todo>> watchTodos() {
    return (select(todos)
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Get all incomplete todos.
  Future<List<Todo>> getIncompleteTodos() {
    return (select(todos)
          ..where((t) => t.isCompleted.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }
}
