// ABOUTME: Data model for a citation reference in Buzz AI answers.
// ABOUTME: Links to a source conversation segment or confirmed fact.

/// A reference to a source conversation or fact used in a Buzz answer.
class BuzzCitation {
  final String id;
  final String sourceType; // 'conversation' or 'fact'
  final String sourceId; // conversation ID or fact ID
  final String excerpt; // relevant quote
  final String label; // display label e.g. "Mar 15, 2:34 PM" or "Fact: preference"
  final DateTime? timestamp;

  const BuzzCitation({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.excerpt,
    required this.label,
    this.timestamp,
  });
}
