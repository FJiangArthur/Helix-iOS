class AssistantProfile {
  const AssistantProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.answerStyle,
    this.showSummaryTool = true,
    this.showFollowUps = true,
    this.showFactCheck = true,
    this.showActionItems = true,
  });

  final String id;
  final String name;
  final String description;
  final String answerStyle;
  final bool showSummaryTool;
  final bool showFollowUps;
  final bool showFactCheck;
  final bool showActionItems;

  static const List<AssistantProfile> defaults = [
    AssistantProfile(
      id: 'general',
      name: 'General',
      description: 'Balanced everyday assistant for mixed conversations.',
      answerStyle: 'Brief, useful, and adaptable.',
    ),
    AssistantProfile(
      id: 'professional',
      name: 'Professional',
      description: 'Focused on meetings, decisions, and action items.',
      answerStyle: 'Clear, direct, and business-ready.',
    ),
    AssistantProfile(
      id: 'social',
      name: 'Social',
      description: 'Optimized for rapport, flow, and memorable follow-ups.',
      answerStyle: 'Warm, natural, and conversational.',
      showFactCheck: false,
    ),
    AssistantProfile(
      id: 'interview',
      name: 'Interview',
      description: 'Optimized for concise, persuasive speaking support.',
      answerStyle: 'Confident, structured, and evidence-backed.',
    ),
  ];

  factory AssistantProfile.fromMap(Map<String, dynamic> map) {
    return AssistantProfile(
      id: map['id'] as String? ?? 'general',
      name: map['name'] as String? ?? 'General',
      description:
          map['description'] as String? ??
          'Balanced everyday assistant for mixed conversations.',
      answerStyle:
          map['answerStyle'] as String? ?? 'Brief, useful, and adaptable.',
      showSummaryTool: map['showSummaryTool'] as bool? ?? true,
      showFollowUps: map['showFollowUps'] as bool? ?? true,
      showFactCheck: map['showFactCheck'] as bool? ?? true,
      showActionItems: map['showActionItems'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'answerStyle': answerStyle,
    'showSummaryTool': showSummaryTool,
    'showFollowUps': showFollowUps,
    'showFactCheck': showFactCheck,
    'showActionItems': showActionItems,
  };

  AssistantProfile copyWith({
    String? id,
    String? name,
    String? description,
    String? answerStyle,
    bool? showSummaryTool,
    bool? showFollowUps,
    bool? showFactCheck,
    bool? showActionItems,
  }) {
    return AssistantProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      answerStyle: answerStyle ?? this.answerStyle,
      showSummaryTool: showSummaryTool ?? this.showSummaryTool,
      showFollowUps: showFollowUps ?? this.showFollowUps,
      showFactCheck: showFactCheck ?? this.showFactCheck,
      showActionItems: showActionItems ?? this.showActionItems,
    );
  }

  String promptDirective({required bool isChinese}) {
    if (isChinese) {
      return '''
当前助手档案：
- 名称：$name
- 用途：$description
- 回答风格：$answerStyle
- 工具偏好：摘要=${showSummaryTool ? '开' : '关'}，追问=${showFollowUps ? '开' : '关'}，核实=${showFactCheck ? '开' : '关'}，行动项=${showActionItems ? '开' : '关'}

请在不改变事实的前提下，优先遵循这个档案的语气、关注点和输出风格。''';
    }

    return '''
Active assistant profile:
- Name: $name
- Purpose: $description
- Answer style: $answerStyle
- Tool preferences: summary=${showSummaryTool ? 'on' : 'off'}, follow-ups=${showFollowUps ? 'on' : 'off'}, fact-check=${showFactCheck ? 'on' : 'off'}, action-items=${showActionItems ? 'on' : 'off'}

Keep responses aligned with this profile's tone, priorities, and output style without changing the facts.''';
  }

  static AssistantProfile fallback([String id = 'general']) {
    return defaults.firstWhere(
      (profile) => profile.id == id,
      orElse: () => defaults.first,
    );
  }

  static List<AssistantProfile> normalize(List<AssistantProfile> profiles) {
    final ordered = <AssistantProfile>[];
    for (final builtin in defaults) {
      final override = profiles.where((profile) => profile.id == builtin.id);
      if (override.isNotEmpty) {
        ordered.add(override.first);
      } else {
        ordered.add(builtin);
      }
    }
    for (final profile in profiles) {
      if (ordered.every((existing) => existing.id != profile.id)) {
        ordered.add(profile);
      }
    }
    return ordered;
  }
}
