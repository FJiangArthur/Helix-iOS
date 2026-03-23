import 'web_search_tool.dart';

/// Dispatches tool calls to their implementations.
class ToolExecutor {
  static Future<String> execute(
    String toolName,
    Map<String, dynamic> arguments,
  ) async {
    switch (toolName) {
      case 'web_search':
        return WebSearchTool.execute(arguments);
      default:
        return 'Unknown tool: $toolName';
    }
  }
}
