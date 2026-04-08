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
