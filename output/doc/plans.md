# Helix Roadmap Delivery Plan

## Milestone 1 - Repo Truth Locked and Transcription Stable

**Target date:** End of Week 2

### Scope

- Reconcile stale planning docs with the current app surface.
- Stabilize the transcription matrix already implied by `SettingsManager`, `ConversationListeningSession`, and native iOS speech code.
- Build a repeatable verification baseline for Flutter plus iOS native paths.

### Acceptance Criteria

- One agreed backlog maps old `ConversationTab` work to the current `RecordingScreen` and Assistant flows.
- `transcriptionBackend` and `preferredMicSource` settings are validated across OpenAI, Apple Cloud, Apple On-Device, glasses mic, and phone mic paths.
- Permission, missing API key, auth failure, and fallback behavior produce user-facing errors instead of silent failure.
- Local verification entry points for analyze, test, and build are documented and runnable in the intended environment.

## Milestone 2 - Realtime Assistant Loop Reliable

**Target date:** End of Week 4

### Scope

- Harden `openaiRealtime` conversation mode and keep transcript and AI response streams coherent.
- Improve HUD delivery, dashboard handoff, and history persistence.
- Expose the existing assistant tooling model on the Home screen so summary, follow-up, insight, and setup/loadout behaviors are productized instead of remaining dormant widgets or settings.
- Finish or retire the unresolved recording UI work so the recording tab is aligned with the current architecture.

### Acceptance Criteria

- Realtime transcript events and AI response events share one stable session without duplicate downstream LLM calls.
- The Home screen surfaces response tools, follow-up chips, insight cards, and setup/loadout controls that align with `AssistantProfile`, `SettingsManager`, and `ConversationEngine`.
- Dashboard, HUD handoff, and glasses answer delivery recover cleanly from disconnects and provider failures.
- Record, Assistant, and History flows share a clear lifecycle for audio files, transcripts, and saved turns.
- The highest-risk surfaces have test coverage or manual QA scripts that match the real app, not stale docs.

## Milestone 3 - Beta Ready Build and Release Gate

**Target date:** End of Week 6

### Scope

- Tighten CI and release verification.
- Polish onboarding, settings, diagnostics, and user-facing failure states.
- Run simulator, device, and hardware validation and prepare a TestFlight candidate.

### Acceptance Criteria

- Flutter analyze, Flutter test, and at least one iOS or macOS build pass in the supported environment.
- No open P0 or P1 issues across Assistant, Glasses, History, Record, and Settings.
- Hardware validation covers glasses mic, phone mic, reconnect, offline fallback, and provider auth failure paths.
- Release notes, known issues, and a go or no-go checklist are published.

## Week-by-Week Execution Plan

### Week 1

- Build a repo-truth inventory for current screens, services, native bridges, and stale docs.
- Decide which parts of `PLAN.md` and `todo.md` still matter and which should be retired.
- Produce the first verification checklist and environment requirements.

### Week 2

- Finish transcription backend stabilization and microphone source fallback testing.
- Fix the most obvious permission, startup, and fallback regressions.
- Lock Milestone 1 acceptance evidence.

### Week 3

- Harden realtime conversation mode and end-to-end transcript plus response routing.
- Validate status transitions, provider error handling, and glasses streaming behavior.
- Productize the Home loadout and assistant setup controls so tool preferences can be tuned in-flow.
- Add targeted tests or scripted QA around the realtime path.

### Week 4

- Align recording, history, and assistant session persistence.
- Resolve record-tab drift from the older `ConversationTab` plan.
- Lock Milestone 2 acceptance evidence.

### Week 5

- Improve onboarding, settings UX, diagnostics, and CI coverage.
- Replace or extend the generic Xcode GitHub workflow with Flutter-aware checks.
- Prepare beta support assets: release notes skeleton, test matrix, bug triage view.

### Week 6

- Run regression passes on simulator, local device, and glasses hardware.
- Burn down release blockers and produce the go or no-go summary.
- Cut the beta candidate and capture follow-up work for the next cycle.
