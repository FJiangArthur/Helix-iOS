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
    this.showWebSearch = true,
    this.systemPrompt,
  });

  final String id;
  final String name;
  final String description;
  final String answerStyle;
  final bool showSummaryTool;
  final bool showFollowUps;
  final bool showFactCheck;
  final bool showActionItems;
  final bool showWebSearch;
  final String? systemPrompt;

  String get engineModeName {
    switch (id) {
      case 'interview':
      case 'technical':
        return 'interview';
      default:
        return 'general';
    }
  }

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
    AssistantProfile(
      id: 'technical',
      name: 'Technical',
      description: 'Technical interviews: code, system design, problem-solving.',
      answerStyle: 'Precise, structured, and implementation-focused.',
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
      showWebSearch: map['showWebSearch'] as bool? ?? true,
      systemPrompt: map['systemPrompt'] as String?,
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
    'showWebSearch': showWebSearch,
    if (systemPrompt != null) 'systemPrompt': systemPrompt,
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
    bool? showWebSearch,
    String? systemPrompt,
    bool clearSystemPrompt = false,
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
      showWebSearch: showWebSearch ?? this.showWebSearch,
      systemPrompt: clearSystemPrompt ? null : (systemPrompt ?? this.systemPrompt),
    );
  }

  String promptDirective({required bool isChinese}) {
    if (isChinese) {
      return '档案：$name — $answerStyle';
    }

    return 'Profile: $name — $answerStyle';
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
