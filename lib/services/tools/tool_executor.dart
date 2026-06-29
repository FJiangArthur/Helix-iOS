import 'web_search_tool.dart';

typedef ToolExecutorOverride =
    Future<String> Function(String toolName, Map<String, dynamic> arguments);

/// Dispatches tool calls to their implementations.
class ToolExecutor {
  /// Eval/test seam for deterministic tool execution.
  static ToolExecutorOverride? overrideForTesting;

  static Future<String> execute(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    final override = overrideForTesting;
    if (override != null) {
      return override(toolName, arguments);
    }

    switch (toolName) {
      case 'web_search':
        return WebSearchTool.execute(arguments);
      default:
        return 'Unknown tool: $toolName';
    }
  }
}
