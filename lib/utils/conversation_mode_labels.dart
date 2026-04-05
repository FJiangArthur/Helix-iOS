import '../services/conversation_engine.dart';

String conversationModeLabel(ConversationMode mode, {bool uppercase = false}) {
  return storedConversationModeLabel(mode.name, uppercase: uppercase);
}

String storedConversationModeLabel(String? mode, {bool uppercase = false}) {
  final label = switch ((mode ?? '').trim().toLowerCase()) {
    'interview' => 'Interview',
    'technical' => 'Technical',
    'professional' => 'Professional',
    'social' => 'Social',
    'general' || '' => 'General',
    // Historical fallbacks for database rows
    'passive' => 'Answer All',
    'proactive' => 'Answer On-demand',
    final other when other.isNotEmpty =>
      other[0].toUpperCase() + other.substring(1),
    _ => 'General',
  };
  return uppercase ? label.toUpperCase() : label;
}
