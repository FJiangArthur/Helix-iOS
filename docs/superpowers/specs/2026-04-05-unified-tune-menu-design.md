# Unified Tune Menu & Mode System Design

**Date:** 2026-04-05
**Status:** Approved
**Scope:** Unify settings/tune/mode architecture into single-source-of-truth profile system

## Problem

Settings controlling conversation behavior are scattered across three places:

1. **Control Deck mode chips** — General, Interview, Answer All, Answer On-demand
2. **Tune sheet (Assistant Setup)** — Profile selector, Auto Insights, Auto Follow-ups, Tooling toggles
3. **Settings page** — Auto-detect Questions, Auto-answer

This causes confusion: overlapping controls, out-of-sync state, and modes (`passive`/`proactive`) that are really behavioral toggles masquerading as conversation contexts.

## Design

### 1. Mode & Profile Unification

Profile selection becomes the single source of truth. Mode chips become profile chips.

| Profile ID | Chip Label | Engine Mode | Prompt Style |
|------------|-----------|-------------|--------------|
| `general` | General | `general` | Balanced, adaptive |
| `professional` | Professional | `general` | Clear, direct, business-ready |
| `social` | Social | `general` | Warm, natural, conversational |
| `interview` | Interview | `interview` | STAR framework, confident, structured |
| `technical` | Technical | `interview` | Code-focused, precise, problem-solving |

- `professional`, `social` use `general` engine logic — only prompt personality differs
- `interview`, `technical` share `interview` engine mode (STAR coaching, behavioral detection)
- `ConversationMode` enum reduced to `{ general, interview }` — two real engine behaviors
- `passive`/`proactive` removed from enum entirely

**Sync mechanism:** Selecting a mode chip calls `_selectAssistantProfile(profile)` which persists via `SettingsManager.assistantProfileId` and calls `_engine.setMode()`. Both Tune sheet profile strip and mode chips converge on the same method.

### 2. Tune Menu Restructure

The Tune sheet (opened by the Tune button on the Control Deck) becomes the single control center.

**Top level (always visible):**
- Profile selector strip (synced with mode chips)
- Preset selector strip
- Loadout preview card
- Response Length slider
- "Customize Prompt" row → opens full-screen editor

**Collapsible section: AUTOMATION**

| Toggle | Setting Key | Description |
|--------|------------|-------------|
| Auto Detect Questions | `autoDetectQuestions` | Listens for questions in conversation |
| Auto Insights | `autoShowSummary` | Passively surfaces overview/insights on phone |
| Proactive Follow-ups | `autoShowFollowUps` | Auto-shows follow-up questions to ask the other side |
| Auto-Answer to Glasses | `answerAll` | Auto-answers detected questions and sends to glasses HUD |

**Dependency:** Auto-Answer to Glasses requires Auto Detect Questions. If detection is OFF, answer toggle is grayed out. Turning answer ON implicitly enables detection.

**Collapsible section: OUTPUT TOOLS**

| Toggle | Source | Description |
|--------|--------|-------------|
| Summary Tool | `profile.showSummaryTool` | Manual summary actions |
| Follow-up Suggestions | `profile.showFollowUps` | Contextual next questions appended to answers |
| Fact Check | `profile.showFactCheck` | Verification actions for risky answers |
| Web Search | `profile.showWebSearch` | OpenAI Search API for fact-checking and grounding |
| Action Items | `profile.showActionItems` | Extracted tasks on Home |

**Dependency:** Web Search requires Fact Check. If fact check is OFF, web search is grayed out.

**Settings page cleanup:** Remove "Auto-detect Questions" and "Auto-answer" from Settings > Conversation section.

### 3. Custom System Prompt

Add `systemPrompt` field (nullable String) to `AssistantProfile`.

**Prompt architecture — split into persona (overridable) and rules (fixed):**

```
final persona = profile.systemPrompt ?? _defaultPersona(mode, isChinese);
final rules = _modeRules(mode, isChinese, maxSentences);  // always appended
final profileSuffix = profile.promptDirective(isChinese: isChinese);
return '$persona\n\n$rules$langInstruction\n\n$profileSuffix$contextBlock';
```

- Users customize the AI personality without breaking output format constraints
- Rules footer always appended: max sentences, no "you could say", speakable text only
- For `interview`/`technical` profiles: STAR coaching prompt always prepended before custom override

**UX:**
- "Customize Prompt" row in Tune sheet shows first ~40 chars preview when set
- Full-screen editor with: multi-line text field, starter template chips ("Keep it brief", "Explain like I'm 5", "Technical detail", "Translate to Spanish"), 2000 char limit with counter, "Reset to default" button
- Placeholder text shows the default persona so users know what they're overriding
- Per-profile: each profile can have its own custom prompt
- When `systemPrompt` is null: default built-in prompt used (zero-regression path)

### 4. Engine Migration

**Enum change:**
```dart
// Old
enum ConversationMode { general, interview, passive, proactive }
// New
enum ConversationMode { general, interview }
```

**Proactive mode → `answerOnDemand` setting:**

All 8 engine guards replaced. `answerOnDemand` is derived as `!answerAll` (not a separate setting):

| Behavior | Old guard | New guard |
|----------|-----------|-----------|
| Skip auto-detect scheduling | `_mode != .proactive` | `answerAll` |
| Suppress silence suggestions | `_mode == .proactive` | `!answerAll` |
| Start SessionContextManager | `_mode == .proactive` | `!answerAll` |
| Gate triggerProactiveAnalysis | `_mode == .proactive` | `!answerAll` |
| Track answered questions | `_mode == .proactive` | `!answerAll` |

`triggerProactiveAnalysis()` renamed to `triggerOnDemandAnalysis()`.

**Passive mode → removed.** Zero engine guards existed; only a unique system prompt.

**answerAll toggle:** When ON, auto-answers detected questions and sends to glasses HUD. Replaces `autoAnswerQuestions` from Settings page.

**Data migration** in `SettingsManager.initialize()`:
- `conversationMode == 'passive'` → `answerAll = true`, `assistantProfileId = 'general'`
- `conversationMode == 'proactive'` → `answerAll = false` (on-demand via Q&A button), `assistantProfileId = 'general'`
- Old `conversationMode` field deprecated

**App init fix:** After SettingsManager loads in `main.dart`, restore engine mode from profile:
```dart
final mode = SettingsManager.instance.resolveAssistantProfile().resolvedEngineMode;
ConversationEngine.instance.setMode(mode);
```

### 5. Data Flow & Persistence

**Settings orthogonal to profile (global):**

| Setting | Persisted in | Notes |
|---------|-------------|-------|
| `answerAll` | SharedPreferences | When ON, auto-answers + sends to glasses |
| `autoDetectQuestions` | SharedPreferences | |
| `autoShowSummary` | SharedPreferences | |
| `autoShowFollowUps` | SharedPreferences | |

**Note:** `answerOnDemand` is not a persisted toggle — it is the inverse of `answerAll`. When `answerAll` is OFF, the user is in on-demand mode and uses the Q&A button. No separate setting needed.

**Settings per-profile:**

| Setting | Persisted in |
|---------|-------------|
| `systemPrompt` | Profile JSON |
| `showSummaryTool` | Profile JSON |
| `showFollowUps` | Profile JSON |
| `showFactCheck` | Profile JSON |
| `showWebSearch` | Profile JSON |
| `showActionItems` | Profile JSON |

### 6. Web Search Tool

New `showWebSearch` boolean on `AssistantProfile` (default: true).

- Uses OpenAI Search API for fact-checking and answer grounding
- Gated behind Fact Check toggle — Web Search requires Fact Check enabled
- Toggle is per-profile but quick-accessible from Output Tools section in Tune sheet

## Files Impacted

| File | Change |
|------|--------|
| `lib/models/assistant_profile.dart` | Add `systemPrompt`, `conversationMode`, `showWebSearch` fields; add `technical` default profile; add `resolvedEngineMode` getter |
| `lib/services/conversation_engine.dart` | Enum to 2 values; replace 8 proactive guards with `answerOnDemand`; split prompt into persona/rules; rename `triggerProactiveAnalysis` |
| `lib/services/settings_manager.dart` | Add `answerAll`; migration logic; deprecate `conversationMode` raw field |
| `lib/screens/home_screen.dart` | Mode chips → profile chips; Tune menu restructure (Automation/Output Tools sections); system prompt editor; remove `_currentMode` independence |
| `lib/screens/settings_screen.dart` | Remove Auto-detect and Auto-answer from Conversation section |
| `lib/services/evenai.dart` | Flash text keyed on `answerOnDemand` instead of mode |
| `lib/utils/conversation_mode_labels.dart` | Update labels for new profile IDs |
| `lib/screens/conversation_history_screen.dart` | Add `professional`/`social`/`technical` colors; keep `passive`/`proactive` fallbacks for historical rows |
| `lib/services/conversation_context.dart` | Delete (dead code) |
| `lib/main.dart` | Add engine mode restoration from profile on init |
| Tests (4 files) | Rewrite proactive/passive tests for settings-driven approach |

## Edge Cases

- **Answer All OFF mid-conversation:** In-flight answers still deliver; new questions stop auto-answering but remain visible with manual "Answer" affordance
- **Profile switch mid-conversation:** Session continues; only next AI call uses new prompt
- **Auto Detect OFF + Answer All ON:** Answer All grayed out; turning Answer All ON implicitly enables detection
- **All toggles OFF:** Pure transcription mode — subtle hint: "Manual Q&A mode"
- **Interview/Technical custom prompt:** STAR coaching always prepended; user adds to it, can't replace it
- **Historical data:** Database rows with `mode = 'passive'/'proactive'` kept readable via display-layer fallbacks in history screen

## Migration Risks

1. **Persisted `conversationMode` values:** Migration in `initialize()` maps old values to new settings
2. **Test rework:** `conversation_engine_proactive_test.dart` (276 lines) needs full rewrite
3. **SessionContextManager:** Called unconditionally on `start()` — no behavioral harm, slight memory increase in long sessions
4. **User-written prompts:** Rules footer always appended to prevent format regression; 2000 char limit
5. **`evenai.dart` flash text:** One-line change, easy to miss — must be in diff review
