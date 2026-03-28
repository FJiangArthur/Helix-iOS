/// LLM prompt templates for the V2.2 cloud processing pipeline.
///
/// Each method returns a carefully crafted prompt that requests structured
/// JSON output from the LLM. All prompts have Chinese variants controlled
/// by the [chinese] flag.
class PipelinePrompts {
  PipelinePrompts._();

  // ---------------------------------------------------------------------------
  // Combined (short conversation) prompt
  // ---------------------------------------------------------------------------

  /// Combined analysis prompt for short conversations (<500 words).
  /// Returns JSON with all pipeline outputs in a single call.
  static String combinedAnalysis(String transcript, {bool chinese = false}) {
    if (chinese) {
      return '''分析以下对话并返回纯JSON（不要使用markdown代码块，不要添加任何额外文本）：

$transcript

严格按以下格式返回：
{
  "title": "简短标题（10字以内）",
  "topics": [
    {
      "label": "话题名称",
      "summary": "该话题的简短总结（1-2句）",
      "segmentIndices": [0, 1, 2]
    }
  ],
  "summary": "对话整体总结（2-3句话概括要点）",
  "sentiment": "positive 或 neutral 或 negative",
  "toneAnalysis": {
    "dominant": "友好/紧张/专业/随意/热情/严肃",
    "confidence": 0.8
  },
  "facts": [
    {
      "category": "preference/relationship/habit/opinion/goal/biographical/skill",
      "content": "用第三人称描述的关于用户的事实",
      "quote": "原文中的相关引用",
      "confidence": 0.8
    }
  ],
  "actionItems": [
    {
      "content": "待办事项描述",
      "dueDate": null
    }
  ]
}

规则：
- topics: 识别对话中的主要话题，segmentIndices 是该话题涵盖的段落索引（从0开始）
- facts: 只提取对话中明确提到的个人信息、偏好、习惯等，不要推测
- actionItems: 只提取对话中明确提到要做的事情
- 如果某个字段没有相关内容，使用空数组 []
- sentiment 只能是 positive、neutral 或 negative 之一
- 必须返回有效的JSON''';
    }
    return '''Analyze this conversation and return pure JSON (no markdown code blocks, no extra text):

$transcript

Return strictly in this format:
{
  "title": "Short descriptive title (under 10 words)",
  "topics": [
    {
      "label": "Topic name",
      "summary": "Brief summary of this topic (1-2 sentences)",
      "segmentIndices": [0, 1, 2]
    }
  ],
  "summary": "Overall conversation summary capturing the key points (2-3 sentences)",
  "sentiment": "positive or neutral or negative",
  "toneAnalysis": {
    "dominant": "friendly/tense/professional/casual/enthusiastic/serious",
    "confidence": 0.8
  },
  "facts": [
    {
      "category": "preference/relationship/habit/opinion/goal/biographical/skill",
      "content": "Fact about the user stated in third person",
      "quote": "Exact quote from transcript supporting this fact",
      "confidence": 0.8
    }
  ],
  "actionItems": [
    {
      "content": "Action item description",
      "dueDate": null
    }
  ]
}

Rules:
- topics: Identify main discussion topics. segmentIndices are zero-based indices of transcript lines belonging to that topic.
- facts: Only extract facts explicitly stated in the conversation — preferences, relationships, habits, opinions, goals, biographical details, or skills. Do not speculate.
- actionItems: Only extract tasks or commitments explicitly mentioned. Include a dueDate (ISO 8601) if one is mentioned, otherwise null.
- Use empty arrays [] for fields with no relevant content.
- sentiment must be exactly one of: positive, neutral, negative.
- Return valid JSON only.''';
  }

  // ---------------------------------------------------------------------------
  // Topic segmentation
  // ---------------------------------------------------------------------------

  /// Topic segmentation prompt for longer conversations.
  /// Returns a JSON array of topics with label, summary, and segment indices.
  static String topicSegmentation(String transcript, {bool chinese = false}) {
    if (chinese) {
      return '''将以下对话按话题进行分段，返回纯JSON（不要使用markdown代码块）。

每一行都有一个从0开始的索引号。

$transcript

返回格式：
{
  "topics": [
    {
      "label": "话题名称",
      "summary": "该话题的简短总结（1-2句）",
      "segmentIndices": [0, 1, 2, 3]
    }
  ]
}

规则：
- 每个话题应包含连续的或主题相关的段落索引
- 一个段落可以属于多个话题（如果它是过渡性的）
- 话题名称应简洁明了（5个字以内）
- 按对话中出现的顺序排列话题
- 返回有效的JSON''';
    }
    return '''Segment this conversation by topic. Return pure JSON (no markdown code blocks).

Each line is numbered starting from 0.

$transcript

Return format:
{
  "topics": [
    {
      "label": "Topic name",
      "summary": "Brief summary of this topic (1-2 sentences)",
      "segmentIndices": [0, 1, 2, 3]
    }
  ]
}

Rules:
- Each topic should contain consecutive or thematically related segment indices.
- A segment may belong to multiple topics if it is transitional.
- Topic labels should be concise (under 5 words).
- Order topics by their appearance in the conversation.
- Return valid JSON only.''';
  }

  // ---------------------------------------------------------------------------
  // Summarization
  // ---------------------------------------------------------------------------

  /// Summarization prompt that incorporates previously identified topics.
  /// Returns JSON with a title, overall summary, and per-topic summaries.
  static String summarization(
    String transcript,
    List<Map<String, dynamic>> topics, {
    bool chinese = false,
  }) {
    final topicsJson = topics
        .map((t) => '  - ${t['label']}: segments ${t['segmentIndices']}')
        .join('\n');

    if (chinese) {
      return '''根据以下对话和已识别的话题生成总结。返回纯JSON（不要使用markdown代码块）。

对话内容：
$transcript

已识别的话题：
$topicsJson

返回格式：
{
  "title": "简短标题（10字以内）",
  "summary": "对话整体总结（2-3句话概括主要内容和结论）",
  "topicSummaries": {
    "话题名称": "该话题的详细总结（1-2句）"
  }
}

规则：
- 标题要简洁有力，概括对话主题
- 整体总结要涵盖最重要的信息和结论
- 每个话题的总结应独立可读
- 返回有效的JSON''';
    }
    return '''Generate a summary based on this conversation and its identified topics. Return pure JSON (no markdown code blocks).

Conversation:
$transcript

Identified topics:
$topicsJson

Return format:
{
  "title": "Short descriptive title (under 10 words)",
  "summary": "Overall conversation summary covering key points and conclusions (2-3 sentences)",
  "topicSummaries": {
    "Topic name": "Detailed summary for this topic (1-2 sentences)"
  }
}

Rules:
- The title should be concise and capture the essence of the conversation.
- The overall summary should cover the most important information and outcomes.
- Each topic summary should be self-contained and readable on its own.
- Return valid JSON only.''';
  }

  // ---------------------------------------------------------------------------
  // Tone / sentiment analysis
  // ---------------------------------------------------------------------------

  /// Tone and sentiment analysis prompt.
  /// Returns JSON with overall sentiment and detailed tone breakdown.
  static String toneAnalysis(String transcript, {bool chinese = false}) {
    if (chinese) {
      return '''分析以下对话的语气和情感。返回纯JSON（不要使用markdown代码块）。

$transcript

返回格式：
{
  "sentiment": "positive 或 neutral 或 negative",
  "toneAnalysis": {
    "dominant": "友好/紧张/专业/随意/热情/严肃/幽默/焦虑",
    "secondary": "次要语气（可选）",
    "confidence": 0.8,
    "shifts": [
      {
        "fromTone": "起始语气",
        "toTone": "转变后的语气",
        "atSegment": 5,
        "reason": "语气转变的原因"
      }
    ]
  }
}

规则：
- sentiment 只能是 positive、neutral 或 negative 之一
- dominant 是整体最主要的语气
- confidence 范围 0.0-1.0
- shifts 只在语气有明显变化时才包含，没有变化则为空数组
- 返回有效的JSON''';
    }
    return '''Analyze the tone and sentiment of this conversation. Return pure JSON (no markdown code blocks).

$transcript

Return format:
{
  "sentiment": "positive or neutral or negative",
  "toneAnalysis": {
    "dominant": "friendly/tense/professional/casual/enthusiastic/serious/humorous/anxious",
    "secondary": "secondary tone (optional)",
    "confidence": 0.8,
    "shifts": [
      {
        "fromTone": "initial tone",
        "toTone": "shifted tone",
        "atSegment": 5,
        "reason": "Brief reason for the shift"
      }
    ]
  }
}

Rules:
- sentiment must be exactly one of: positive, neutral, negative.
- dominant is the overall primary tone of the conversation.
- confidence range is 0.0-1.0.
- Only include shifts if there are clear tone changes; use an empty array otherwise.
- Return valid JSON only.''';
  }

  // ---------------------------------------------------------------------------
  // Fact extraction
  // ---------------------------------------------------------------------------

  /// Fact extraction prompt. Includes existing confirmed facts so the LLM
  /// can avoid extracting duplicates.
  static String factExtraction(
    String transcript,
    List<String> existingFacts, {
    bool chinese = false,
  }) {
    final existingSection = existingFacts.isEmpty
        ? ''
        : chinese
            ? '\n已知事实（不要重复提取这些）：\n${existingFacts.map((f) => '  - $f').join('\n')}\n'
            : '\nAlready known facts (do NOT extract duplicates of these):\n${existingFacts.map((f) => '  - $f').join('\n')}\n';

    if (chinese) {
      return '''从以下对话中提取关于说话者的个人事实。返回纯JSON（不要使用markdown代码块）。
$existingSection
$transcript

返回格式：
{
  "facts": [
    {
      "category": "preference/relationship/habit/opinion/goal/biographical/skill",
      "content": "用第三人称描述的事实（例如：'用户喜欢喝咖啡'）",
      "quote": "对话中支持该事实的原文引用",
      "confidence": 0.8
    }
  ]
}

类别说明：
- preference: 喜好和偏好（食物、音乐、工具等）
- relationship: 人际关系（家人、朋友、同事等）
- habit: 日常习惯和例行活动
- opinion: 对事物的看法和观点
- goal: 目标和计划
- biographical: 个人信息（职业、住址、教育等）
- skill: 技能和专长

规则：
- 只提取对话中明确提到或强烈暗示的事实
- 不要推测或过度解读
- confidence: 0.9+ 表示明确陈述，0.7-0.9 表示强烈暗示，0.5-0.7 表示可能的推断
- 不要重复已知事实列表中的内容
- 如果没有可提取的事实，返回空数组
- 返回有效的JSON''';
    }
    return '''Extract personal facts about the speakers from this conversation. Return pure JSON (no markdown code blocks).
$existingSection
$transcript

Return format:
{
  "facts": [
    {
      "category": "preference/relationship/habit/opinion/goal/biographical/skill",
      "content": "Fact stated in third person (e.g., 'The user enjoys coffee')",
      "quote": "Exact quote from the transcript supporting this fact",
      "confidence": 0.8
    }
  ]
}

Category definitions:
- preference: Likes and preferences (food, music, tools, etc.)
- relationship: Interpersonal relationships (family, friends, colleagues, etc.)
- habit: Daily routines and regular activities
- opinion: Views and opinions on topics
- goal: Goals, plans, and aspirations
- biographical: Personal information (occupation, location, education, etc.)
- skill: Skills and areas of expertise

Rules:
- Only extract facts explicitly stated or strongly implied in the conversation.
- Do not speculate or over-interpret.
- confidence: 0.9+ for explicit statements, 0.7-0.9 for strong implications, 0.5-0.7 for possible inferences.
- Do NOT duplicate any fact from the already-known list above.
- If no facts can be extracted, return an empty array.
- Return valid JSON only.''';
  }

  // ---------------------------------------------------------------------------
  // Action item detection
  // ---------------------------------------------------------------------------

  /// Action item / todo detection prompt.
  /// Returns a JSON array of action items with optional due dates.
  static String actionItemDetection(String transcript, {bool chinese = false}) {
    if (chinese) {
      return '''从以下对话中提取待办事项和行动项。返回纯JSON（不要使用markdown代码块）。

$transcript

返回格式：
{
  "actionItems": [
    {
      "content": "待办事项的清晰描述",
      "dueDate": "2024-01-15 或 null（如果没有提到截止日期）",
      "assignee": "负责人（如果提到的话，否则为 null）",
      "priority": "high/medium/low"
    }
  ]
}

规则：
- 只提取对话中明确提到的任务、承诺或计划
- 包括明确的承诺（"我会..."、"我们需要..."、"别忘了..."）
- 不要将一般性讨论误解为待办事项
- dueDate 使用 ISO 8601 格式（YYYY-MM-DD），没有明确日期则为 null
- priority: high 表示紧急或有截止日期，medium 为默认，low 表示不急
- 如果没有行动项，返回空数组
- 返回有效的JSON''';
    }
    return '''Extract action items and todos from this conversation. Return pure JSON (no markdown code blocks).

$transcript

Return format:
{
  "actionItems": [
    {
      "content": "Clear description of the action item",
      "dueDate": "2024-01-15 or null if no deadline mentioned",
      "assignee": "Person responsible if mentioned, otherwise null",
      "priority": "high/medium/low"
    }
  ]
}

Rules:
- Only extract tasks, commitments, or plans explicitly mentioned in the conversation.
- Include explicit commitments ("I will...", "We need to...", "Don't forget to...").
- Do not interpret general discussion as action items.
- dueDate in ISO 8601 format (YYYY-MM-DD) if mentioned, null otherwise.
- priority: high for urgent or deadline-bound items, medium as default, low for non-urgent.
- If there are no action items, return an empty array.
- Return valid JSON only.''';
  }
}
