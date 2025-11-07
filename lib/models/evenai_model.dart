/// Model for Even AI conversation items
class EvenaiModel {
  final String title;
  final String content;
  final DateTime createdTime;

  EvenaiModel({
    required this.title,
    required this.content,
    required this.createdTime,
  });

  /// Create from JSON
  factory EvenaiModel.fromJson(Map<String, dynamic> json) {
    return EvenaiModel(
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      createdTime: DateTime.parse(json['createdTime'] ?? DateTime.now().toIso8601String()),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'createdTime': createdTime.toIso8601String(),
    };
  }
}