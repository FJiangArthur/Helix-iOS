# Helix Roadmap Doc Spec

## Target

Create a client-ready `.docx` roadmap for the Helix app that is grounded in repository evidence, not assumptions. The roadmap must cover six weeks and include milestones, weekly goals, clear deliverables, dependencies, and risks.

## Repository Inputs Reviewed

- `README.md`
- `PLAN.md`
- `BUILD_STATUS.md`
- `todo.md`
- `docs/Architecture.md`
- `docs/TechnicalSpecs.md`
- `docs/TESTING_STRATEGY.md`
- `docs/superpowers/specs/2026-03-15-realtime-transcription-design.md`
- `docs/superpowers/specs/2026-03-17-realtime-conversation-mode-design.md`
- `docs/superpowers/plans/2026-03-15-realtime-transcription.md`
- `docs/superpowers/plans/2026-03-17-realtime-conversation-mode.md`
- `.github/workflows/objective-c-xcode.yml`
- `lib/main.dart`
- `lib/app.dart`
- `lib/screens/home_screen.dart`
- `lib/screens/recording_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/widgets/home_assistant_modules.dart`
- `lib/models/assistant_profile.dart`
- `lib/services/conversation_engine.dart`
- `lib/services/conversation_listening_session.dart`
- `lib/services/settings_manager.dart`
- `lib/services/implementations/audio_service_impl.dart`
- `lib/services/dashboard_service.dart`
- `lib/ble_manager.dart`
- `lib/services/llm/llm_service.dart`
- `ios/Runner/OpenAIRealtimeTranscriber.swift`
- `ios/Runner/SpeechStreamRecognizer.swift`
- `ios/Runner/AppDelegate.swift`

## Hard Constraints

- Keep the roadmap tied to the current repo surface: Assistant, Glasses, History, Record, Settings, onboarding, native iOS speech, BLE, and LLM integrations.
- Call out that summary, follow-up, response-tool, and setup/loadout affordances already exist in the repo model, widget layer, and settings layer, and that the Home screen is now expected to surface them consistently.
- Reflect active TODOs and planning drift:
  - `PLAN.md` and `todo.md` still center on an older `ConversationTab` integration track.
  - `docs/superpowers` shows newer realtime transcription and realtime conversation work.
- Respect architecture constraints already visible in code:
  - Flutter app with iOS and macOS targets.
  - Singleton service pattern across `SettingsManager`, `LlmService`, `ConversationEngine`, `DashboardService`, and `BleManager`.
  - Native iOS platform-channel dependency for glasses, speech, and realtime audio features.
  - Existing audio session conflict risk between `flutter_sound` recording and speech recognition.
- Keep the final document scannable with headings, bullets, and a simple week-by-week table.
- Keep all document text ASCII-friendly.

## Output Requirements

- Final artifact: `output/doc/helix_6_week_roadmap.docx`
- Intermediate render source: `tmp/docs/helix_roadmap/helix_6_week_roadmap.html`
- Human-readable source copy: `output/doc/helix_6_week_roadmap.md`
- Support files:
  - `output/doc/spec.md`
  - `output/doc/plans.md`
  - `output/doc/implement.md`
  - `output/doc/documentation.md`

## Verification Requirements

- Attempt repo verification commands for tests, lint, typecheck, and build.
- Record environment blockers explicitly if a command cannot run.
- Validate the generated `.docx` by reconverting it to text and, if possible, generating previews.

## Non-Goals

- No product redesign or architecture rewrite inside this task.
- No speculative roadmap items that are not supported by the current repo state.
