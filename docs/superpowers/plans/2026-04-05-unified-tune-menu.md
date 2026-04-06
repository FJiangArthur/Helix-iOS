# Unified Tune Menu & Mode System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify settings/tune/mode into a single-source-of-truth profile system with custom system prompts, collapsible Automation/Output Tools sections, and web search toggle.

**Architecture:** `AssistantProfile` becomes the single control surface. Mode chips map to profiles. `ConversationMode` enum reduced to `{ general, interview }` as an internal engine abstraction. `answerAll` boolean replaces the old `passive`/`proactive` mode split. Custom system prompt overrides the persona portion of the LLM prompt while rules stay fixed.

**Tech Stack:** Flutter/Dart, SharedPreferences, GetX streams, platform channels

**Spec:** `docs/superpowers/specs/2026-04-05-unified-tune-menu-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/models/assistant_profile.dart` | Modify | Add `systemPrompt`, `showWebSearch`, `technical` profile, `engineMode` getter |
| `lib/services/settings_manager.dart` | Modify | Add `answerAll`, migration logic, deprecate `conversationMode` |
| `lib/services/conversation_engine.dart` | Modify | Enum to 2 values, replace proactive guards, split prompts, rename methods |
| `lib/services/evenai.dart` | Modify | Flash text keyed on `answerAll` |
| `lib/utils/conversation_mode_labels.dart` | Modify | Add new profile labels, keep historical fallbacks |
| `lib/screens/home_screen.dart` | Modify | Profile-driven mode chips, Tune restructure, system prompt editor, sync |
| `lib/screens/settings_screen.dart` | Modify | Remove duplicate Conversation toggles |
| `lib/screens/conversation_history_screen.dart` | Modify | Add colors for new profiles, keep historical fallbacks |
| `lib/services/conversation_context.dart` | Delete | Dead code (duplicate ConversationTurn, stale prompts) |
| `lib/main.dart` | Modify | Restore engine mode from profile on init |
| `test/services/conversation_engine_modes_test.dart` | Modify | Rewrite passive tests for answerAll |
| `test/services/conversation_engine_proactive_test.dart` | Modify | Rewrite for answerAll-driven on-demand |
| `test/screens/home_screen_test.dart` | Modify | Assert on profile ID instead of mode enum |
| `test/services/live_activity_service_test.dart` | Modify | Update mock mode stream |

---

### Task 1: Update AssistantProfile Model

**Files:**
- Modify: `lib/models/assistant_profile.dart`

- [ ] **Step 1: Add new fields to AssistantProfile**

```dart
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
```

- [ ] **Step 2: Add `technical` to defaults and add `engineMode` getter**

```dart
  /// Maps profile ID to the internal ConversationMode name.
  /// Only 'interview' and 'technical' use interview mode; all others use general.
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
```

- [ ] **Step 3: Update `fromMap`, `toMap`, `copyWith`**

In `fromMap`, add:
```dart
      showWebSearch: map['showWebSearch'] as bool? ?? true,
      systemPrompt: map['systemPrompt'] as String?,
```

In `toMap`, add:
```dart
    'showWebSearch': showWebSearch,
    if (systemPrompt != null) 'systemPrompt': systemPrompt,
```

In `copyWith`, add parameters and assignments:
```dart
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
```

Note: `clearSystemPrompt` flag is needed because `copyWith(systemPrompt: null)` would keep the old value due to the `??` pattern. Setting `clearSystemPrompt: true` explicitly clears it.

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze lib/models/assistant_profile.dart`
Expected: 0 errors, 0 warnings

- [ ] **Step 5: Commit**

```bash
git add lib/models/assistant_profile.dart
git commit -m "feat: add systemPrompt, showWebSearch, technical profile to AssistantProfile"
```

---

### Task 2: Update SettingsManager — Add `answerAll` and Migration

**Files:**
- Modify: `lib/services/settings_manager.dart`

- [ ] **Step 1: Add `answerAll` field, deprecate `conversationMode` and `autoAnswerQuestions`**

At line 57, replace `autoAnswerQuestions` with `answerAll`:

```dart
  /// When true, auto-answers detected questions and sends to glasses HUD.
  /// Replaces the old autoAnswerQuestions + passive mode.
  bool answerAll = false;

  /// @deprecated Use answerAll instead. Kept for migration only.
  @Deprecated('Use answerAll instead')
  String conversationMode = 'general';
```

Remove the `autoAnswerQuestions` field (line 57) and its getter/setter in the engine (will be done in Task 4).

- [ ] **Step 2: Add migration logic in `initialize()`**

After loading existing values (around line 302), add migration:

```dart
    // --- Migration: passive/proactive mode → answerAll toggle ---
    final legacyMode = prefs.getString('conversationMode') ?? 'general';
    final migrated = prefs.getBool('_modeToAnswerAllMigrated') ?? false;
    if (!migrated) {
      if (legacyMode == 'passive') {
        answerAll = true;
        assistantProfileId = prefs.getString('assistantProfileId') ?? 'general';
      } else if (legacyMode == 'proactive') {
        answerAll = false;
        assistantProfileId = prefs.getString('assistantProfileId') ?? 'general';
      } else {
        // general/interview: preserve autoAnswerQuestions as answerAll
        answerAll = prefs.getBool('autoAnswerQuestions') ?? true;
      }
      await prefs.setBool('_modeToAnswerAllMigrated', true);
      await prefs.setBool('answerAll', answerAll);
    } else {
      answerAll = prefs.getBool('answerAll') ?? false;
    }
```

- [ ] **Step 3: Update `save()` method**

Replace the `autoAnswerQuestions` and `conversationMode` persistence lines (around line 420-421) with:

```dart
    await prefs.setBool('answerAll', answerAll);
    // conversationMode no longer persisted — driven by profile
```

Remove:
```dart
    await prefs.setBool('autoAnswerQuestions', autoAnswerQuestions);
    await prefs.setString('conversationMode', conversationMode);
```

- [ ] **Step 4: Add `effectiveEngineMode` computed getter**

```dart
  /// Returns the ConversationMode name derived from the active profile.
  String get effectiveEngineMode =>
      resolveAssistantProfile().engineModeName;
```

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/services/settings_manager.dart`
Expected: 0 errors. There will be compile errors in other files referencing `autoAnswerQuestions` — those are fixed in Task 4.

- [ ] **Step 6: Commit**

```bash
git add lib/services/settings_manager.dart
git commit -m "feat: add answerAll setting with passive/proactive migration"
```

---

### Task 3: Update ConversationEngine — Enum, Guards, Prompts

**Files:**
- Modify: `lib/services/conversation_engine.dart`

- [ ] **Step 1: Change ConversationMode enum (line 2827)**

```dart
enum ConversationMode { general, interview }
```

This will cause compile errors everywhere `passive`/`proactive` are referenced — fix them in the following steps.

- [ ] **Step 2: Replace `autoAnswerQuestions` with `answerAll`**

At lines 106-108, change:
```dart
  bool get answerAll => SettingsManager.instance.answerAll;
  set answerAll(bool v) => SettingsManager.instance.answerAll = v;
```

Remove the old `autoAnswerQuestions` getter/setter (lines 106-108).

- [ ] **Step 3: Replace proactive guards with `answerAll`**

**Line 236** — `start()`:
```dart
    // Old: if (_mode == ConversationMode.proactive) {
    if (!answerAll) {
      _sessionContextManager.startSession();
    }
```

**Line 516** — `onTranscriptionUpdate()`:
```dart
    // Old: if (autoDetectQuestions && _mode != ConversationMode.proactive) {
    if (autoDetectQuestions && answerAll) {
      _scheduleTranscriptAnalysis();
    }
```

**Line 649** — `onTranscriptionFinalized()`:
```dart
    // Old: if (autoDetectQuestions && _mode != ConversationMode.proactive) {
    if (autoDetectQuestions && answerAll) {
      _scheduleTranscriptAnalysis(immediate: true);
    }
```

**Line 774** — `_onSilenceDetected()`:
```dart
    // Old: if (_mode == ConversationMode.proactive) return;
    if (!answerAll) return;
```

**Line 1074** — `triggerProactiveAnalysis()` → rename to `triggerOnDemandAnalysis()`:
```dart
  Future<void> triggerOnDemandAnalysis() async {
    // Old: if (!_isActive || _mode != ConversationMode.proactive) return;
    if (!_isActive || answerAll) return;
```

**Line 1888** — `_runManualContextualQa()` finally block:
```dart
      // Old: _mode != ConversationMode.proactive
      if (_isActive && autoDetectQuestions && answerAll) {
        _scheduleTranscriptAnalysis();
      }
```

**Line 1487** — `_onQuestionDetected()`:
```dart
      // Old: if (autoAnswerQuestions) {
      if (answerAll) {
```

**Line 2076** — `_generateResponse()`:
```dart
      // Old: if (_mode == ConversationMode.proactive) {
      if (!answerAll) {
        _trackProactiveAnswer(finalResponse);
      }
```

- [ ] **Step 4: Remove passive/proactive prompt cases and split into persona/rules**

Replace the entire `_getSystemPrompt()` method (lines 2299-2388) with:

```dart
  String _getSystemPrompt() {
    final isChinese = _language == 'zh';
    final langInstruction = isChinese
        ? '\n\nIMPORTANT: Always respond in Chinese (中文). Use natural, conversational Chinese.'
        : '';
    final profile = _activeAssistantProfile();
    final profileInstruction = profile.promptDirective(isChinese: isChinese);
    final maxSentences = SettingsManager.instance.maxResponseSentences;

    final persona = profile.systemPrompt?.trim().isNotEmpty == true
        ? profile.systemPrompt!.trim()
        : _defaultPersona(isChinese);
    final rules = _modeRules(isChinese, maxSentences);

    // For interview/technical profiles, always prepend STAR coaching context
    final interviewPrefix = (profile.engineModeName == 'interview')
        ? _interviewCoachingPrefix(isChinese)
        : '';

    final kbContext = _getKbContext();
    final contextBlock = kbContext.isNotEmpty ? '\n\n$kbContext' : '';
    return '$interviewPrefix$persona\n\n$rules$langInstruction\n\n$profileInstruction$contextBlock';
  }

  String _defaultPersona(bool isChinese) {
    if (isChinese) {
      return '你是智能眼镜上的对话伙伴，帮助用户进行更好的对话。';
    }
    return 'You are a conversation companion on smart glasses helping the user have better conversations.';
  }

  String _interviewCoachingPrefix(bool isChinese) {
    if (isChinese) {
      return '你是智能眼镜上的面试教练。直接给出用户应该说的话。\n\n';
    }
    return 'You are an interview coach on smart glasses. Output exactly what the user should say.\n\n';
  }

  String _modeRules(bool isChinese, int maxSentences) {
    if (isChinese) {
      return '规则：最多$maxSentences句话。直接给出答案，禁止说"你可以说"或"这是建议"。用自然口语，不用列表格式。';
    }
    return 'Rules: Max $maxSentences sentences. Give the answer directly — never write "you could say" or "here\'s a suggestion". Use natural spoken language, no lists or formatting.';
  }
```

- [ ] **Step 5: Update the on-demand analysis system prompt**

In `triggerOnDemandAnalysis()` (formerly `triggerProactiveAnalysis()`), the method still uses `_getSystemPrompt()` which now returns the correct prompt. The JSON preamble instruction is in the user message (line 1103-1104), not the system prompt, so it continues to work.

No changes needed to the method body beyond the rename and guard change done in Step 3.

- [ ] **Step 6: Remove all remaining `ConversationMode.passive`/`ConversationMode.proactive` references**

Search for any remaining references and update switch statements. The `_buildSystemPrompt` switch is already replaced. The `mode: _mode.name` in ConversationTurn history (line 2086) keeps working since `_mode` is now always `general` or `interview`.

- [ ] **Step 7: Update `forceQuestionAnalysis` to route correctly**

The method at line 2775 currently calls `_runManualContextualQa()`. It should also call `triggerOnDemandAnalysis()` when not in answerAll mode:

```dart
  Future<void> forceQuestionAnalysis() async {
    if (!answerAll) {
      await triggerOnDemandAnalysis();
    } else {
      await _runManualContextualQa();
    }
  }
```

- [ ] **Step 8: Run analyzer**

Run: `flutter analyze lib/services/conversation_engine.dart`
Expected: 0 errors

- [ ] **Step 9: Commit**

```bash
git add lib/services/conversation_engine.dart
git commit -m "feat: reduce ConversationMode to general/interview, replace proactive guards with answerAll"
```

---

### Task 4: Update EvenAI Flash Text

**Files:**
- Modify: `lib/services/evenai.dart`

- [ ] **Step 1: Replace mode check with answerAll check (line 275)**

```dart
  static void _triggerManualQuestionDetection() {
    if (!SettingsManager.instance.answerAll) {
      _flashFeedback('Q&A REFRESH...');
    } else {
      _flashFeedback('Q&A...');
    }
    unawaited(ConversationEngine.instance.forceQuestionAnalysis());
  }
```

Add import if not present: `import 'settings_manager.dart';`

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/services/evenai.dart`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/evenai.dart
git commit -m "fix: key EvenAI flash text on answerAll instead of proactive mode"
```

---

### Task 5: Update Mode Labels and History Screen

**Files:**
- Modify: `lib/utils/conversation_mode_labels.dart`
- Modify: `lib/screens/conversation_history_screen.dart`

- [ ] **Step 1: Update conversation_mode_labels.dart**

```dart
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
```

- [ ] **Step 2: Update conversation_history_screen.dart `_modeColor()`**

Add new cases and keep historical fallbacks:

```dart
      case 'professional':
        return HelixTheme.cyan; // same family as general
      case 'social':
        return const Color(0xFF00FF88);
      case 'technical':
        return HelixTheme.purple; // same family as interview
      // Historical fallbacks
      case 'passive':
      case 'answer all':
        return const Color(0xFF00FF88);
      case 'proactive':
      case 'answer on-demand':
        return HelixTheme.amber;
```

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze lib/utils/conversation_mode_labels.dart lib/screens/conversation_history_screen.dart`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add lib/utils/conversation_mode_labels.dart lib/screens/conversation_history_screen.dart
git commit -m "feat: add profile labels and history colors for professional/social/technical"
```

---

### Task 6: Delete Dead Code — conversation_context.dart

**Files:**
- Delete: `lib/services/conversation_context.dart`

- [ ] **Step 1: Verify no imports exist**

Run: `grep -r "conversation_context" lib/`
Expected: no matches (already verified — file is dead code, `ConversationTurn` is redefined in `conversation_engine.dart`)

- [ ] **Step 2: Delete the file**

```bash
rm lib/services/conversation_context.dart
```

- [ ] **Step 3: Run analyzer**

Run: `flutter analyze`
Expected: 0 errors

- [ ] **Step 4: Commit**

```bash
git add -u lib/services/conversation_context.dart
git commit -m "chore: remove dead conversation_context.dart (superseded by conversation_engine)"
```

---

### Task 7: Update main.dart — Restore Engine Mode from Profile on Init

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add mode restoration after SettingsManager init (after line 31)**

```dart
  // Initialize settings first (loads persisted preferences)
  await SettingsManager.instance.initialize();

  // Restore engine mode from the active assistant profile
  final engineModeName = SettingsManager.instance.effectiveEngineMode;
  ConversationEngine.instance.setMode(
    ConversationMode.values.byName(engineModeName),
  );
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/main.dart`
Expected: 0 errors

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "fix: restore engine mode from active profile on app init"
```

---

### Task 8: Update Home Screen — Profile-Driven Mode Chips and Sync

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Update `_selectAssistantProfile` to also set engine mode (line 3103)**

```dart
  Future<void> _selectAssistantProfile(AssistantProfile profile) async {
    setState(() => _assistantProfileId = profile.id);
    await SettingsManager.instance.update((settings) {
      settings.assistantProfileId = profile.id;
    });
    // Sync engine mode from profile
    _engine.setMode(
      ConversationMode.values.byName(profile.engineModeName),
    );
  }
```

- [ ] **Step 2: Replace `_buildModeSelector` to iterate profiles instead of enum (line 718)**

Replace the entire `_buildModeSelector()` method:

```dart
  Widget _buildModeSelector() {
    final profiles = SettingsManager.instance.assistantProfiles;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: profiles.map((profile) {
        final isSelected = profile.id == _assistantProfileId;
        final color = _profileColor(profile.id);
        return GestureDetector(
          onTap: () => _selectProfileChip(profile),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.32)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              profile.name,
              style: TextStyle(
                color: isSelected
                    ? color
                    : Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _selectProfileChip(AssistantProfile profile) {
    if (profile.id == _assistantProfileId) return;
    _modeSwitchController
      ..reset()
      ..forward();
    _selectAssistantProfile(profile);
  }
```

- [ ] **Step 3: Replace `_modeColor` and `_modeLabel` with profile-based helpers**

Replace `_modeColor(ConversationMode mode)` (line 3410) with:

```dart
  Color _profileColor(String profileId) {
    switch (profileId) {
      case 'general':
        return HelixTheme.cyan;
      case 'professional':
        return HelixTheme.cyan;
      case 'interview':
        return HelixTheme.purple;
      case 'technical':
        return HelixTheme.purple;
      case 'social':
        return const Color(0xFF00FF88);
      default:
        return HelixTheme.cyan;
    }
  }
```

Update all callers of `_modeColor(_currentMode)` to `_profileColor(_assistantProfileId)`. The main call sites are:
- Line 508: `color: modeColor` in the Control Deck — change to `final modeColor = _profileColor(_assistantProfileId);`
- Line 1055: `_modeColor(_currentMode)` in the Tune sheet border — change to `_profileColor(_assistantProfileId)`

Remove `_modeLabel()` — no longer needed since chips now use `profile.name` directly.

- [ ] **Step 4: Update `_selectMode` to route through profile selection (line 758)**

Replace with a no-op or remove — mode selection now happens via `_selectProfileChip()`. If `_selectMode` is called elsewhere, redirect:

```dart
  void _selectMode(ConversationMode mode) {
    // Deprecated: mode selection now goes through profile chips.
    // Find the first profile matching this engine mode and select it.
    final profiles = SettingsManager.instance.assistantProfiles;
    final match = profiles.firstWhere(
      (p) => p.engineModeName == mode.name,
      orElse: () => profiles.first,
    );
    _selectProfileChip(match);
  }
```

- [ ] **Step 5: Update remaining switch statements on `_currentMode`**

The `_getSuggestions()` method (line 2884) and `_getAskHint()` method (line 3274) switch on `_currentMode`. Since `_currentMode` is now always `general` or `interview`, remove the `passive`/`proactive` cases:

In `_getSuggestions()`:
```dart
      case ConversationMode.general:
        // ... existing general suggestions
      case ConversationMode.interview:
        // ... existing interview suggestions
```

In `_getAskHint()`:
```dart
      case ConversationMode.general:
        // ... existing general hint
      case ConversationMode.interview:
        // ... existing interview hint
```

- [ ] **Step 6: Update `_assistantProfile` getter used for modeColor in overview**

Find the overview section that uses `modeColor` (around line 461-470) and ensure it reads from `_profileColor(_assistantProfileId)` instead of `_modeColor(_currentMode)`.

- [ ] **Step 7: Run analyzer**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: 0 errors

- [ ] **Step 8: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: replace mode chips with profile-driven chips, sync profile/mode selection"
```

---

### Task 9: Restructure Tune Sheet — Automation and Output Tools Sections

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add collapsible section state to `_openAssistantSetupSheet` (line 1035)**

Add local state variables at the top of the method:
```dart
    var automationExpanded = true;
    var outputToolsExpanded = false;
```

- [ ] **Step 2: Replace the existing AUTO SURFACES and TOOLING sections with new structure**

Remove the existing "AUTO SURFACES" section (lines 1307-1382) and "TOOLING" section (lines 1170-1304).

Replace with two collapsible sections:

```dart
                        // --- AUTOMATION section ---
                        _buildCollapsibleSectionHeader(
                          title: _tr(
                            en: 'AUTOMATION',
                            zh: '自动化',
                            ja: 'オートメーション',
                            ko: '자동화',
                            es: 'AUTOMATIZACION',
                            ru: 'АВТОМАТИЗАЦИЯ',
                          ),
                          expanded: automationExpanded,
                          onTap: () => setSheetState(() => automationExpanded = !automationExpanded),
                        ),
                        if (automationExpanded) ...[
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-auto-detect-toggle'),
                            title: _tr(en: 'Auto Detect Questions', zh: '自动检测问题'),
                            description: _tr(
                              en: 'Listen for questions in conversations.',
                              zh: '在对话中监听问题。',
                            ),
                            value: SettingsManager.instance.autoDetectQuestions,
                            onTap: () async {
                              final next = !SettingsManager.instance.autoDetectQuestions;
                              await SettingsManager.instance.update((s) {
                                s.autoDetectQuestions = next;
                              });
                              setSheetState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-auto-insights-toggle'),
                            title: _tr(en: 'Auto Insights', zh: '自动洞察'),
                            description: _tr(
                              en: 'Surfaces conversation overview and insights on your phone.',
                              zh: '在手机上自动展示对话概览和洞察。',
                            ),
                            value: sheetAutoShowSummary,
                            onTap: () async {
                              final nextValue = !sheetAutoShowSummary;
                              setSheetState(() => sheetAutoShowSummary = nextValue);
                              await SettingsManager.instance.update((s) {
                                s.autoShowSummary = nextValue;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-proactive-followups-toggle'),
                            title: _tr(en: 'Proactive Follow-ups', zh: '主动追问'),
                            description: _tr(
                              en: 'Suggests follow-up questions to ask the other side.',
                              zh: '自动建议向对方提问的后续问题。',
                            ),
                            value: sheetAutoShowFollowUps,
                            onTap: () async {
                              final nextValue = !sheetAutoShowFollowUps;
                              setSheetState(() => sheetAutoShowFollowUps = nextValue);
                              await SettingsManager.instance.update((s) {
                                s.autoShowFollowUps = nextValue;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-answer-all-toggle'),
                            title: _tr(en: 'Auto-Answer to Glasses', zh: '自动回答到眼镜'),
                            description: _tr(
                              en: 'Auto-answers detected questions and sends to glasses HUD.',
                              zh: '自动回答检测到的问题并发送到眼镜HUD。',
                            ),
                            value: SettingsManager.instance.answerAll,
                            enabled: SettingsManager.instance.autoDetectQuestions,
                            onTap: () async {
                              final next = !SettingsManager.instance.answerAll;
                              await SettingsManager.instance.update((s) {
                                s.answerAll = next;
                                // Turning answer ON implicitly enables detection
                                if (next && !s.autoDetectQuestions) {
                                  s.autoDetectQuestions = true;
                                }
                              });
                              setSheetState(() {});
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        // --- OUTPUT TOOLS section ---
                        _buildCollapsibleSectionHeader(
                          title: _tr(
                            en: 'OUTPUT TOOLS',
                            zh: '输出工具',
                            ja: '出力ツール',
                            ko: '출력 도구',
                            es: 'HERRAMIENTAS',
                            ru: 'ИНСТРУМЕНТЫ',
                          ),
                          expanded: outputToolsExpanded,
                          onTap: () => setSheetState(() => outputToolsExpanded = !outputToolsExpanded),
                        ),
                        if (outputToolsExpanded) ...[
                          const SizedBox(height: 8),
                          // Existing tooling toggles: Summary Tool, Follow-up Suggestions,
                          // Fact Check, Action Items — keep as-is from existing code
                          // ADD Web Search toggle after Fact Check:
                          AssistantSettingsToggleTile(
                            key: const Key('home-setup-tool-websearch-toggle'),
                            title: _tr(en: 'Web Search', zh: '网络搜索'),
                            description: _tr(
                              en: 'Use OpenAI Search API for fact-checking and grounding.',
                              zh: '使用OpenAI搜索API进行事实核查和信息验证。',
                            ),
                            value: sheetProfile.showWebSearch,
                            enabled: sheetProfile.showFactCheck,
                            onTap: () async {
                              final updated = sheetProfile.copyWith(
                                showWebSearch: !sheetProfile.showWebSearch,
                              );
                              setSheetState(() => sheetProfile = updated);
                              await SettingsManager.instance.saveAssistantProfile(updated);
                            },
                          ),
                        ],
```

- [ ] **Step 3: Add `_buildCollapsibleSectionHeader` helper method**

```dart
  Widget _buildCollapsibleSectionHeader({
    required String title,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Icon(
            expanded ? Icons.expand_less : Icons.expand_more,
            size: 18,
            color: Colors.white.withValues(alpha: 0.42),
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 4: Add `enabled` parameter to AssistantSettingsToggleTile**

Check if `AssistantSettingsToggleTile` already supports an `enabled` parameter. If not, find its definition and add:

```dart
  final bool enabled;
```

With default `true`, and when `false`, gray out the tile and ignore taps.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: 0 errors

- [ ] **Step 6: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: restructure Tune sheet with Automation and Output Tools collapsible sections"
```

---

### Task 10: Add System Prompt Editor to Tune Sheet

**Files:**
- Modify: `lib/screens/home_screen.dart`

- [ ] **Step 1: Add "Customize Prompt" row in Tune sheet (after Response Length slider)**

```dart
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _showSystemPromptEditor(sheetProfile);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.edit_note_rounded, size: 20, color: Colors.white.withValues(alpha: 0.72)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _tr(en: 'Customize Prompt', zh: '自定义提示词'),
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.88),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (sheetProfile.systemPrompt != null &&
                                          sheetProfile.systemPrompt!.trim().isNotEmpty)
                                        Text(
                                          sheetProfile.systemPrompt!.trim().length > 40
                                              ? '${sheetProfile.systemPrompt!.trim().substring(0, 40)}...'
                                              : sheetProfile.systemPrompt!.trim(),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.48),
                                            fontSize: 11,
                                          ),
                                        )
                                      else
                                        Text(
                                          _tr(en: 'Using default prompt', zh: '使用默认提示词'),
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.38),
                                            fontSize: 11,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 18, color: Colors.white.withValues(alpha: 0.42)),
                              ],
                            ),
                          ),
                        ),
```

- [ ] **Step 2: Add `_showSystemPromptEditor` method**

```dart
  void _showSystemPromptEditor(AssistantProfile profile) {
    final controller = TextEditingController(text: profile.systemPrompt ?? '');
    final maxChars = 2000;

    // Default persona for placeholder
    final isChinese = SettingsManager.instance.language == 'zh';
    final defaultPersona = isChinese
        ? '你是智能眼镜上的对话伙伴，帮助用户进行更好的对话。'
        : 'You are a conversation companion on smart glasses helping the user have better conversations.';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HelixTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(en: 'Custom System Prompt', zh: '自定义系统提示词'),
                      style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tr(
                        en: 'Customize how the AI responds. Rules (sentence limit, format) are always enforced.',
                        zh: '自定义AI的回复风格。规则（句数限制、格式）始终生效。',
                      ),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.52), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    // Starter template chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTemplateChip('Keep it brief', '简短回答', controller, setSheetState),
                        _buildTemplateChip('Explain like I\'m 5', '像跟5岁小孩解释', controller, setSheetState),
                        _buildTemplateChip('Technical detail', '技术细节', controller, setSheetState),
                        _buildTemplateChip('Translate to Spanish', '翻译成西班牙语', controller, setSheetState),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 8,
                      maxLength: maxChars,
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: defaultPersona,
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.22)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: HelixTheme.cyan.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (controller.text.trim().isNotEmpty)
                          TextButton(
                            onPressed: () {
                              controller.clear();
                              setSheetState(() {});
                            },
                            child: Text(
                              _tr(en: 'Reset to default', zh: '恢复默认'),
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.52)),
                            ),
                          ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: () async {
                            final text = controller.text.trim();
                            final updated = text.isEmpty
                                ? profile.copyWith(clearSystemPrompt: true)
                                : profile.copyWith(systemPrompt: text);
                            await SettingsManager.instance.saveAssistantProfile(updated);
                            if (mounted) setState(() {});
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: HelixTheme.cyan),
                          child: Text(_tr(en: 'Save', zh: '保存')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTemplateChip(
    String enLabel,
    String zhLabel,
    TextEditingController controller,
    StateSetter setSheetState,
  ) {
    final label = _isChinese ? zhLabel : enLabel;
    return GestureDetector(
      onTap: () {
        controller.text = _isChinese ? zhLabel : enLabel;
        setSheetState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.68), fontSize: 12),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Add systemPrompt and showWebSearch to `_showProfileEditor` save**

In the profile editor save button (around line 991), update the `copyWith` call:

```dart
                              final updated = profile.copyWith(
                                name: nameController.text.trim().isEmpty
                                    ? profile.name
                                    : nameController.text.trim(),
                                description:
                                    descriptionController.text.trim().isEmpty
                                    ? profile.description
                                    : descriptionController.text.trim(),
                                answerStyle:
                                    answerStyleController.text.trim().isEmpty
                                    ? profile.answerStyle
                                    : answerStyleController.text.trim(),
                                showSummaryTool: showSummaryTool,
                                showFollowUps: showFollowUps,
                                showFactCheck: showFactCheck,
                                showActionItems: showActionItems,
                                showWebSearch: showWebSearch,
                              );
```

Add `showWebSearch` local state variable alongside the others (around line 808):
```dart
    var showWebSearch = profile.showWebSearch;
```

And add the toggle in the editor (after action items toggle, around line 971):
```dart
                    const SizedBox(height: 8),
                    buildToggle(
                      'Web Search',
                      'OpenAI Search for fact-checking',
                      showWebSearch,
                      (v) => setSheetState(() => showWebSearch = v),
                    ),
```

- [ ] **Step 4: Run analyzer**

Run: `flutter analyze lib/screens/home_screen.dart`
Expected: 0 errors

- [ ] **Step 5: Commit**

```bash
git add lib/screens/home_screen.dart
git commit -m "feat: add system prompt editor and web search toggle to Tune sheet"
```

---

### Task 11: Remove Duplicate Settings from Settings Page

**Files:**
- Modify: `lib/screens/settings_screen.dart`

- [ ] **Step 1: Remove the Conversation section (lines 451-466)**

Remove:
```dart
              const SizedBox(height: 20),
              _buildSection(tr('Conversation', '对话'), Icons.chat, [
                _buildToggle(
                  tr('Auto-detect Questions', '自动检测问题'),
                  tr('Listen for questions in conversations', '在对话中监听问题'),
                  _settings.autoDetectQuestions,
                  (v) => _settings.update((s) => s.autoDetectQuestions = v),
                ),
                const SizedBox(height: 8),
                _buildToggle(
                  tr('Auto-answer', '自动回答'),
                  tr('Answer detected questions automatically', '自动回答检测到的问题'),
                  _settings.autoAnswerQuestions,
                  (v) => _settings.update((s) => s.autoAnswerQuestions = v),
                ),
              ]),
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/screens/settings_screen.dart`
Expected: 0 errors (the `autoAnswerQuestions` reference is gone)

- [ ] **Step 3: Commit**

```bash
git add lib/screens/settings_screen.dart
git commit -m "feat: remove duplicate conversation toggles from settings page (moved to Tune)"
```

---

### Task 12: Update Tests — Modes and Proactive

**Files:**
- Modify: `test/services/conversation_engine_modes_test.dart`
- Modify: `test/services/conversation_engine_proactive_test.dart`
- Modify: `test/screens/home_screen_test.dart`
- Modify: `test/services/live_activity_service_test.dart`

- [ ] **Step 1: Update modes test — replace passive with answerAll=false**

In `test/services/conversation_engine_modes_test.dart`, rewrite group B3:

```dart
  group('B3 - Answer All off (on-demand mode)', () {
    test('no auto-detection when answerAll is off', () async {
      engine.autoDetectQuestions = true;
      engine.answerAll = false;
      engine.start(mode: ConversationMode.general);

      engine.onTranscriptionFinalized(
        'What do you think about artificial intelligence?',
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // With answerAll off, auto-detection scheduling is skipped
      expect(recorder.questionDetections, isEmpty);
    });

    test('manual askQuestion still works when answerAll is off', () async {
      engine.answerAll = false;
      engine.start(mode: ConversationMode.general);
      provider.enqueueStreamResponse(
        const FakeStreamResponse(['AI is fascinating.']),
      );

      await engine.askQuestion('What is AI?');
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(engine.history, isNotEmpty);
      final lastTurn = engine.history.last;
      expect(lastTurn.content, contains('AI'));
    });

    test(
      'manual contextual Q&A works when answerAll is off',
      () async {
        engine.autoDetectQuestions = false;
        engine.answerAll = false;
        engine.start(mode: ConversationMode.general);
        engine.onTranscriptionFinalized('We are reviewing the launch plan.');
        engine.onTranscriptionFinalized('What is the rollout plan?');

        provider.enqueueStreamResponse(
          const FakeStreamResponse(['Ship the beta next week.']),
        );

        final responseFuture = waitForStream<String>(
          engine.aiResponseStream,
          predicate: (value) => value.contains('beta next week'),
          timeout: const Duration(seconds: 5),
        );

        await engine.forceQuestionAnalysis();
        final response = await responseFuture;
        expect(response, contains('beta next week'));
      },
    );
  });
```

- [ ] **Step 2: Update proactive test — replace mode with answerAll=false**

In `test/services/conversation_engine_proactive_test.dart`, update all tests to use:
```dart
      engine.answerAll = false;
      engine.start(mode: ConversationMode.general);
```
instead of:
```dart
      engine.start(mode: ConversationMode.proactive);
```

And replace `engine.triggerProactiveAnalysis()` with `engine.triggerOnDemandAnalysis()`.

- [ ] **Step 3: Update home_screen_test.dart (line 543)**

Replace:
```dart
    expect(ConversationEngine.instance.mode, ConversationMode.proactive);
```
With an assertion on profile ID:
```dart
    expect(SettingsManager.instance.assistantProfileId, isNotEmpty);
```

- [ ] **Step 4: Update live_activity_service_test.dart (line 57)**

Replace:
```dart
        modeController.add(ConversationMode.proactive);
```
With:
```dart
        modeController.add(ConversationMode.general);
```

- [ ] **Step 5: Run all tests**

Run: `flutter test test/`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add test/services/conversation_engine_modes_test.dart test/services/conversation_engine_proactive_test.dart test/screens/home_screen_test.dart test/services/live_activity_service_test.dart
git commit -m "test: rewrite mode/proactive tests for answerAll-driven approach"
```

---

### Task 13: Full Validation Gate

**Files:** None (validation only)

- [ ] **Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: 0 errors

- [ ] **Step 2: Run all tests**

Run: `flutter test test/`
Expected: All tests pass

- [ ] **Step 3: Run full validation gate**

Run: `bash scripts/run_gate.sh`
Expected: All gates pass (required since conversation_engine.dart was modified)

- [ ] **Step 4: Build for simulator**

Run: `flutter build ios --simulator --no-codesign`
Expected: Build succeeds

- [ ] **Step 5: Commit any fixes from validation**

If any fixes were needed, commit them:
```bash
git add -A
git commit -m "fix: address validation gate issues"
```
