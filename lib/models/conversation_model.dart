// ABOUTME: Conversation data models
// ABOUTME: Models for conversation sessions, messages, and metadata

/// Conversation session model
class Conversation {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final List<ConversationMessage> messages;
  final Map<String, dynamic>? metadata;

  Conversation({
    required this.id,
    required this.startTime,
    this.endTime,
    this.messages = const [],
    this.metadata,
  });

  Duration get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isActive => endTime == null;
}

/// Conversation message
class ConversationMessage {
  final String id;
  final String content;
  final DateTime timestamp;
  final String? speakerId;
  final MessageType type;

  ConversationMessage({
    required this.id,
    required this.content,
    required this.timestamp,
    this.speakerId,
    this.type = MessageType.transcript,
  });
}

enum MessageType {
  transcript,
  analysis,
  factCheck,
  insight,
  actionItem,
}

/// Conversation context for AI analysis
class ConversationContext {
  final String conversationId;
  final List<String> recentMessages;
  final Map<String, dynamic>? metadata;

  ConversationContext({
    required this.conversationId,
    this.recentMessages = const [],
    this.metadata,
  });
}

/// Conversation model (alias for compatibility)
class ConversationModel extends Conversation {
  ConversationModel({
    required super.id,
    required super.startTime,
    super.endTime,
    super.messages,
    super.metadata,
  });
}
