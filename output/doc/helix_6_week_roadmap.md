# Helix 6-Week Roadmap

Generated and refreshed from repository inspection on 2026-03-18.

## Planning Basis

- The current product surface is already broader than the older top-level docs imply: onboarding, Assistant, Glasses, History, Record, Settings, file management, provider configuration, native iOS speech, BLE integration, and dashboard handoff are all present in the repo.
- The most current near-term work is concentrated in the recent realtime transcription and realtime conversation specs under `docs/superpowers`.
- The older `PLAN.md` and `todo.md` still point to unresolved recording UI and waveform work, but they refer to an older `ConversationTab` shape that no longer matches the active `RecordingScreen` path.
- The Assistant surface already contains dormant building blocks for richer UI and tooling, including assistant profiles, quick-ask presets, summary toggles, follow-up toggles, response tool widgets, and insight extraction helpers.
- The Home screen now also has a viable loadout and setup surface for assistant tooling, so the remaining Week 3 work is about reliability and polish, not inventing a new UI path.
- History sessions can already be summarized into reusable metadata, so the roadmap can now include copyable review briefs and signal counts without introducing a new persistence layer.
- The next six weeks should harden and verify the current stack. This repo is already built around singleton services, platform channels, and native iOS dependencies, so a major architecture rewrite would add risk without helping the beta path.

## Constraints to Honor

- Keep Flutter UI, native iOS speech/BLE code, and existing service singletons working incrementally.
- Resolve audio session conflicts before adding more product scope. The recording flow already defers `flutter_sound` initialization to avoid clashes with live speech recognition.
- Reconcile stale planning docs with the current code before execution starts, or the team risks delivering against the wrong surface.
- Build a Flutter-aware verification path. The current GitHub workflow is generic Xcode only, and the repo has no `integration_test/` directory.

## Milestones

### Milestone 1 - Repo Truth Locked and Transcription Stable

**Target:** End of Week 2

- Reconcile older planning docs with the current app surface and produce one active backlog.
- Stabilize transcription backend and microphone source switching across OpenAI, Apple Cloud, Apple On-Device, glasses mic, and phone mic paths.
- Establish a repeatable local and CI verification baseline for analyze, test, and build.

**Acceptance criteria**

- Old `ConversationTab` planning is mapped to the current `RecordingScreen` and Assistant flows or explicitly retired.
- Permission, missing-key, auth, and fallback failures surface clearly to the user and do not silently fail.
- `transcriptionBackend`, `transcriptionModel`, and `preferredMicSource` are validated on the intended paths.
- The team has one agreed verification entry point for lint, test, and build.

### Milestone 2 - Realtime Assistant Loop Reliable

**Target:** End of Week 4

- Harden `openaiRealtime` conversation mode so transcript and AI response streams stay coherent.
- Improve HUD delivery, dashboard handoff, and history persistence around the realtime path.
- Package session metadata into a copyable review brief in History so saved sessions include summary, action items, and verification signals.
- Surface dormant assistant tooling on the Home screen: follow-up chips, summary access, response actions, insight cards, and a visible setup/loadout surface that matches the existing settings and profile model.
- Finish the unresolved recording-tab stabilization work so Record, Assistant, and History behave like one product.

**Acceptance criteria**

- Realtime transcript events and AI response events run through one stable session without duplicate downstream LLM calls.
- The Assistant tab exposes response tools, insight-driven UI, and setup/loadout controls that are powered by the existing conversation engine and settings model rather than hardcoded placeholder content.
- Glasses delivery, dashboard tilt, and reconnect behavior recover cleanly from native or provider failures.
- Audio files, transcripts, and saved turns have a clear lifecycle and retention rule.
- The highest-risk realtime and recording flows have targeted test coverage or scripted manual QA.

### Milestone 3 - Beta Ready Build and Release Gate

**Target:** End of Week 6

- Tighten CI and release verification.
- Polish onboarding, settings diagnostics, and user-facing failure states.
- Run simulator, device, and glasses-hardware validation and cut a beta candidate.

**Acceptance criteria**

- Flutter analyze, Flutter test, and at least one iOS or macOS build pass in the supported environment.
- No open P0 or P1 issues remain across Assistant, Glasses, History, Record, and Settings.
- Hardware validation covers glasses mic, phone mic, reconnect, offline fallback, and provider auth failure paths.
- Release notes, known issues, and a go or no-go checklist are published.

## Week-by-Week Plan

| Week | Focus | Weekly goals | Deliverables |
| --- | --- | --- | --- |
| 1 | Repo truth and release scope | Reconcile current code against older docs, confirm active surfaces, map native iOS dependencies, and define the beta scope | Repo truth matrix, active backlog, verification checklist |
| 2 | Transcription stabilization | Validate backend switching, mic source fallback, permission flow, missing key handling, and auth/network recovery | Stable transcription settings flow, fallback test notes, Milestone 1 evidence |
| 3 | Realtime conversation reliability and assistant tooling | Harden `openaiRealtime`, verify transcript plus AI response routing, tighten status transitions, and surface summary, follow-up, insight, and setup/loadout tooling on the Assistant tab | Realtime conversation beta path, assistant response tools and setup loadout, targeted tests or QA scripts |
| 4 | Recording, history, and persistence | Align Record, Assistant, and History around one session lifecycle, resolve stale `ConversationTab` work, package review briefs in History, and clean up retention rules | Recording-tab stabilization, history consistency fixes, copyable review brief, Milestone 2 evidence |
| 5 | CI, UX polish, and operations | Improve onboarding and settings diagnostics, add release-facing instrumentation, and replace or extend the generic Xcode workflow with Flutter-aware checks | Flutter-aware CI plan or workflow, polished setup diagnostics, beta readiness checklist |
| 6 | Regression and beta cut | Run simulator, device, and hardware validation, burn down blockers, and prepare TestFlight release notes and go/no-go review | Beta release candidate, regression report, go or no-go summary |

## Dependencies

- Even Realities glasses hardware is required for BLE mic, HUD, dashboard tilt, and handoff validation.
- OpenAI API access with realtime quota is required for the primary transcription and live conversation paths.
- Xcode, CocoaPods, Flutter, and a writable toolchain environment are required for end-to-end build verification.
- Product decisions are needed on beta scope, especially whether `openaiRealtime` ships broadly or behind a controlled rollout.
- QA coverage needs both simulator and on-device passes because the highest-risk flows cross Flutter, native iOS, and hardware boundaries.

## Risks

- Planning drift: older docs still target `ConversationTab`, while the current code centers on `RecordingScreen` and `ConversationListeningSession`.
- Audio stack fragility: the app already documents audio-session conflicts between `flutter_sound` and speech recognition, so changes in one path can break another.
- Dormant feature drift: summary, follow-up, and response-action settings already exist in the repo, so leaving them disconnected from the Home screen creates UX inconsistency and raises support cost.
- Hardware dependence: a large share of user value depends on glasses connectivity and native platform channels that cannot be fully covered by the current test suite.
- Verification gap: CI is not yet Flutter-aware and there is no `integration_test/` suite, so regressions can slip through unless week 1 and week 5 close that gap.
- Documentation drift: top-level architecture docs describe future phases that are already partially implemented, which can distort planning if left uncorrected.

## Recommended Execution Order

- Start with repo-truth cleanup and verification because every later week depends on knowing which flows are current and how they are validated.
- Stabilize transcription before realtime conversation polish because the realtime path depends on the same native speech and mic-source plumbing.
- Resolve recording and history lifecycle issues before the beta cut so support and QA have one consistent mental model for saved sessions.
