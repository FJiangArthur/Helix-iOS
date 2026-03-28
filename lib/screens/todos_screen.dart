// ABOUTME: To-do list screen with reactive updates from drift.
// ABOUTME: Supports manual creation, completion toggle, swipe-to-delete, and AI-extracted badges.

import 'package:flutter/material.dart';

import '../services/database/helix_database.dart';
import '../services/todo_service.dart';
import '../theme/helix_theme.dart';
import '../widgets/glass_card.dart';

class TodosScreen extends StatefulWidget {
  const TodosScreen({super.key});

  @override
  State<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends State<TodosScreen> {
  final TodoService _todoService = TodoService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HelixTheme.background,
      appBar: AppBar(
        title: const Text('To-dos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: HelixTheme.cyan),
            onPressed: () => _showAddTodoDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<Todo>>(
        stream: _todoService.watchTodos(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: HelixTheme.cyan),
            );
          }

          final todos = snapshot.data ?? [];

          if (todos.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: todos.length,
            itemBuilder: (context, index) => _buildTodoTile(todos[index]),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: HelixTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No to-dos yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add one manually, or let the AI extract action items from your conversations.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoTile(Todo todo) {
    final isCompleted = todo.isCompleted;
    final isAuto = todo.source == 'auto';
    final hasConversation = todo.conversationId != null;

    final dueDate = todo.dueDate != null
        ? DateTime.fromMillisecondsSinceEpoch(todo.dueDate!)
        : null;
    final isOverdue =
        dueDate != null && !isCompleted && dueDate.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey(todo.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: HelixTheme.error.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete_outline, color: HelixTheme.error),
        ),
        confirmDismiss: (_) async {
          await _todoService.deleteTodo(todo.id);
          return false; // stream rebuild handles removal
        },
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Opacity(
            opacity: isCompleted ? 0.5 : 1.0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                GestureDetector(
                  onTap: () => _todoService.toggleComplete(todo.id),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2, right: 12),
                    child: Icon(
                      isCompleted
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: isCompleted
                          ? HelixTheme.cyan
                          : HelixTheme.textMuted,
                      size: 22,
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        todo.content,
                        style: TextStyle(
                          color: isCompleted
                              ? HelixTheme.textMuted
                              : HelixTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                          decoration: isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: HelixTheme.textMuted,
                        ),
                      ),
                      if (dueDate != null || isAuto) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (isAuto) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      HelixTheme.purple.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'AI',
                                  style: TextStyle(
                                    color: HelixTheme.purple,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (dueDate != null)
                              Text(
                                _formatShortDate(dueDate),
                                style: TextStyle(
                                  color: isOverdue
                                      ? HelixTheme.error
                                      : HelixTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Conversation link icon
                if (hasConversation && !isCompleted)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: Icon(
                      Icons.link,
                      size: 16,
                      color: HelixTheme.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddTodoDialog(BuildContext context) {
    final contentController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: HelixTheme.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: HelixTheme.borderSubtle),
              ),
              title: const Text(
                'New To-do',
                style: TextStyle(
                  color: HelixTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: contentController,
                    autofocus: true,
                    maxLines: 3,
                    minLines: 1,
                    style: const TextStyle(
                      color: HelixTheme.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'What do you need to do?',
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
                        builder: (context, child) {
                          return Theme(
                            data: HelixTheme.darkTheme.copyWith(
                              colorScheme: const ColorScheme.dark(
                                primary: HelixTheme.cyan,
                                surface: HelixTheme.surfaceRaised,
                                onSurface: HelixTheme.textPrimary,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: HelixTheme.surfaceInteractive,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: HelixTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: HelixTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              selectedDate != null
                                  ? _formatLongDate(selectedDate!)
                                  : 'Due date (optional)',
                              style: TextStyle(
                                color: selectedDate != null
                                    ? HelixTheme.textPrimary
                                    : HelixTheme.textMuted,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (selectedDate != null)
                            GestureDetector(
                              onTap: () =>
                                  setDialogState(() => selectedDate = null),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: HelixTheme.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: HelixTheme.textMuted),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final text = contentController.text.trim();
                    if (text.isEmpty) return;
                    _todoService.addTodo(text, dueDate: selectedDate);
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      color: HelixTheme.cyan,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

  String _formatLongDate(DateTime d) =>
      '${_months[d.month - 1]} ${d.day}, ${d.year}';
}
