---
created: 2026-04-08T03:45:43.947Z
title: Q&A button on live session triggers "Assistant Request failed"
area: general
files:
  - lib/services/conversation_engine.dart
  - lib/services/llm/llm_service.dart
---

## Problem

Pressing the Q&A button while a live session is active immediately returns "Assistant Request failed". Observed on hardware 2026-04-07.

Suspected cause: Q&A path conflicts with the active ConversationEngine session — possibly trying to acquire a resource (LLM client, audio session, or context manager) that the live session already holds, or sending a malformed request because the engine is in `liveListening` mode.

## Solution

TBD. Investigation steps:
1. Reproduce in debug build, capture the actual error from LlmService
2. Check Q&A handler entry point — does it gate on engine mode?
3. Verify whether the failure is at the LLM request layer or earlier (context assembly, prompt construction)

## Progress 2026-04-07

Static audit done. Findings:

- The `[Error]`-as-text-delta convention is used by every provider
  (`anthropic_provider.dart`, `openai_compatible_provider.dart`,
  `openai_provider.dart`). On error, the provider yields a single
  `'[Error] <reason>'` text delta then closes the stream.
- `ConversationEngine._generateResponse` (line 2049) catches it via
  `responseText.isEmpty && text.startsWith('[Error]')` and forwards to
  `ProviderErrorState.fromException(text)`.
- `ProviderErrorState.fromException` (lib/services/provider_error_state.dart:38)
  pattern-matches against the lowercased raw text. Patterns covered:
  auth, rate limit, network, 502/503/504. **Falls through to UNKNOWN
  for: HTTP 400/401/404/500, "No choices in response", "Unexpected
  error", and any provider-specific JSON error shapes.**
- The diagnostic `[ProviderErrorState] UNKNOWN bucket: raw="..."` log is
  in place — it will reveal which fallthrough branch the live-session
  Q&A is hitting once a hardware repro is captured.

**Diagnostic expanded** (commit pending): the engine-side
`[ConversationEngine] _generateResponse received [Error]` log now also
captures `mode`, `isActive`, `glassesConnected`, `webSearchEnabled`,
`msgCount`, and `round` — answers the "Q&A path conflicts with active
session?" hypothesis directly when the next repro is captured.

**Next step:** wait for a hardware repro, grep the device console for
`[ConversationEngine] _generateResponse received [Error]` and
`[ProviderErrorState] UNKNOWN bucket`, then either extend the pattern
list in `provider_error_state.dart` or fix the upstream provider call
that's producing the error.
