# Product Overview

## What is Helix?

Helix is a companion app for Even Realities G1 smart glasses that provides real-time conversation intelligence. It listens to conversations, detects questions, generates AI answers, and displays them on the glasses HUD — all hands-free.

## Core User Flows

### 1. Live Conversation Mode
1. User taps **Listen** on phone (or triggers via glasses button)
2. App transcribes speech in real-time (Apple Speech or OpenAI)
3. When a question is detected, AI generates a concise answer
4. Answer streams to glasses HUD (paginated, scrollable via touchpad)
5. Background fact-check runs automatically on every response
6. User can scroll pages with left/right touchpad on glasses

### 2. Text Query Mode
1. User types a question in the "Ask anything" text field
2. AI responds with a concise answer (configurable sentence limit)
3. Response shown on phone and optionally sent to glasses
4. Follow-up chips generated for continued conversation

### 3. Interview Coach Mode
- Switches prompt to interview-focused coaching
- Outputs directly speakable text (no "you could say" phrasing)
- STAR framework guidance built into prompt

### 4. Passive Listener Mode
- Silently monitors conversation
- Only intervenes for facts, corrections, or key context
- Minimal, non-intrusive answers

## Configuration

| Setting | Default | Range |
|---------|---------|-------|
| Max Response Sentences | 3 | 1-10 |
| Transcription Backend | OpenAI | OpenAI / Apple Cloud / Apple On-Device |
| HUD Render Path | Bitmap | Bitmap / Text (fallback) |
| Auto-detect Questions | On | On / Off |
| Auto-answer | On | On / Off |

## Supported AI Providers

| Provider | Models |
|----------|--------|
| OpenAI | gpt-4.1, gpt-4.1-mini, gpt-4.1-nano, gpt-realtime |
| Anthropic | claude-sonnet-4, claude-haiku-4 |
| DeepSeek | deepseek-chat, deepseek-reasoner |
| Qwen | qwen-turbo, qwen-plus, qwen-max |
| Zhipu | glm-4-flash, glm-4 |

## Hardware Support

- **Glasses**: Even Realities G1 (BLE dual connection L/R)
- **Phone**: iOS 15+, iPhone with BLE 5.0
- **Mic Sources**: Phone mic (default), glasses mic, auto-detect
