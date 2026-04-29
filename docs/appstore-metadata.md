# App Store Connect Metadata - G1 AI Glasses Companion

Copy-paste content for App Store Connect submission fields.

## App Information

- **Name:** `G1 AI Glasses Companion` (30 char max)
- **Subtitle:** `Live Answers on Your HUD` (30 char max)
- **Primary Category:** Productivity
- **Secondary Category:** Utilities
- **Copyright:** `© 2026 Art Jiang`
- **Age Rating:** 4+

## URLs

- Privacy: `https://github.com/FJiangArthur/Helix-iOS/blob/main/docs/privacy.html`
- Support: `https://github.com/FJiangArthur/Helix-iOS/blob/main/docs/support.html`
- Marketing: `https://github.com/FJiangArthur/Helix-iOS/blob/main/docs/index.html`

## Promotional Text (170 chars max)

```
Real-time transcription, interview coaching, fact-checking, and private AI answers for smart glasses.
```

## Description (4000 chars max)

```
G1 AI Glasses Companion turns smart glasses into a private, real-time assistant for conversations, meetings, interviews, and daily context.

Listen with your iPhone, read concise answers on your glasses HUD, and keep useful context organized without accounts or tracking.

LIVE CONVERSATION ANSWERS
Capture speech in real time and get short, direct AI answers when questions come up. Use it for meetings, classes, interviews, hallway conversations, and quick follow-ups when reaching for your phone would break focus.

SMART GLASSES HUD
Send answers and useful context to your G1 glasses display. The app includes a rich bitmap HUD, text fallback, touchpad page scrolling, weather, time, calendar, and compact status widgets.

INTERVIEW COACH
Practice and answer with clearer structure. Interview mode can shape responses around Situation, Task, Action, and Result so your answer is easier to deliver under pressure.

QUIET FACT-CHECKING
When AI answers need grounding, the app can run a background fact-check and keep verification context available without interrupting the conversation.

PROJECT MEMORY
Save useful conversation context, project notes, action items, and memories so recurring work does not start from zero every time.

PRIVATE BY DESIGN
No account is required. API keys stay on your device in iOS Keychain. You choose the AI and transcription providers you want to use, and the app does not include ad tracking or analytics SDKs.

MODEL CHOICE
Connect OpenAI, Anthropic, DeepSeek, Qwen, Zhipu AI, SiliconFlow, or OpenRouter-compatible providers. Bring your own API key and switch providers from Settings.

Full HUD functionality requires compatible G1 smart glasses over Bluetooth. Core phone workflows, provider setup, transcription tests, and HUD previews are available without glasses.
```

## Keywords (100 chars max)

```
conversation,transcription,speech,bluetooth,meeting,interview,coach,notes,voice,wearable,assistant
```

## What's New

```
Improved live conversation restarts, clearer session reset behavior, and updated HUD and AI assistant presentation for a smoother smart-glasses workflow.
```

## Review Notes

```
This app is a companion for Even Realities G1 smart glasses. Full functionality requires paired glasses via Bluetooth. Without glasses, you can still test: (1) Home tab — tap the microphone to record and transcribe speech, then receive AI responses; (2) Settings — configure AI providers and enter API keys; (3) Glasses tab — preview HUD widgets and layout behavior. No login required. Free AI access: set Zhipu AI as provider and select glm-4-flash model (free, no API key charges).
```

## Privacy Label

**Collected (App Functionality, not linked to identity, not tracking):**
- Audio Data (User Content)
- Precise Location (only for HUD weather widget)

**Not collected:** contact info, health, financial, contacts, user
content, browsing/search history, identifiers, purchases, usage data,
diagnostics, sensitive info.

**Notes:**
- Third-party API calls to the user's chosen AI provider (OpenAI /
  Anthropic / DeepSeek / Qwen / Zhipu / SiliconFlow). Functional, not
  tracking.
- Speech recognition defaults to Apple on-device; cloud transcription
  only when user explicitly selects it in Settings.
- API keys stored locally in iOS Keychain (Secure Enclave). Never
  transmitted except to the user's chosen AI provider endpoint.
- No analytics SDKs, no ad IDs, no cross-app tracking, no account
  required.

## Screenshots

Current App Store screenshot set:

- `ios/fastlane/screenshots/en-US/01-live-conversation.png`
- `ios/fastlane/screenshots/en-US/02-smart-glasses-hud.png`
- `ios/fastlane/screenshots/en-US/03-interview-coach.png`
- `ios/fastlane/screenshots/en-US/04-fact-check.png`
- `ios/fastlane/screenshots/en-US/05-project-memory.png`

Each screenshot is 1290x2796 PNG, accepted by Apple for the iPhone 6.9"
display screenshot requirement. App Store Connect can scale these for
smaller iPhone display classes.

Suggested sequence: live conversation hero -> smart glasses HUD ->
interview coach -> fact-check -> project memory.

Tips: clean status bar (full battery, Wi-Fi, 9:41), dark theme, PNG
or JPEG without alpha, sRGB.
