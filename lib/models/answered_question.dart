/// Tracks a question that has been answered during a proactive session.
///
/// Used by [SessionContextManager] to avoid repeating answers for the same
/// question and to build a "previously answered" summary for the LLM.
class AnsweredQuestion {
  final String question;
  final String answer;
  final DateTime timestamp;
  final String questionExcerpt;
  final String action; // 'answer', 'fact_check', or 'insight'

  AnsweredQuestion({
    required this.question,
    required this.answer,
    required this.timestamp,
    this.questionExcerpt = '',
    this.action = 'answer',
  });

  Map<String, dynamic> toJson() => {
    'question': question,
    'answer': answer,
    'timestamp': timestamp.toIso8601String(),
    'questionExcerpt': questionExcerpt,
    'action': action,
  };

  factory AnsweredQuestion.fromJson(Map<String, dynamic> json) {
    return AnsweredQuestion(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? (DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now())
          : DateTime.now(),
      questionExcerpt: json['questionExcerpt'] as String? ?? '',
      action: json['action'] as String? ?? 'answer',
    );
  }
}
