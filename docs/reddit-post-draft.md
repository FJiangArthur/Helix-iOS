# Reddit Post Draft — r/EvenRealities

---

**Title:** I built an open-source AI companion app for the G1 — live transcription, real-time AI answers on the HUD, interview coaching, fact-checking, and 6 AI providers to choose from (free options included)

---

Hey everyone,

I've been wearing my G1s daily and wanted more out of the conversation experience, so I built **Even Companion** — a free, open-source iOS app that turns the G1 into a real-time AI assistant.

I just shipped the latest build to TestFlight and wanted to share what it does.

## What it does

**Live conversation mode.** Start a recording, and the app transcribes your conversation in real time. When it detects a question, it generates an AI answer and streams it directly to your G1 HUD. You scroll pages with the touchpad. After every AI response, a background fact-check runs automatically so you know if something needs a correction.

**Interview coaching.** Switch to Interview mode and the AI coaches you using the STAR framework (Situation, Task, Action, Result). Responses are phrased as directly speakable output — no "you could say..." — just the words you'd actually say out loud. Useful for job interview prep or any high-stakes conversation where you want structured thinking in your line of sight.

**Session Prep (new).** Paste your prep material before a conversation — a job description, resume, meeting notes, customer history, whatever. The app grounds every AI response in YOUR material, surfacing specific facts when they're relevant to the question being asked. Prep auto-clears when the conversation ends so it never bleeds into your next one.

**Bitmap HUD dashboard.** When you're not in a conversation, the G1 displays a live dashboard: clock, weather, stock ticker, calendar events, phone notifications, battery — all rendered as crisp bitmap graphics. Multiple layout presets (Classic, Minimal, Dense, Conversation). It refreshes on a smart interval and uses delta-diffing so only changed pixels get pushed over BLE.

**Real-time translation.** Enable live translation in Settings and foreign-language segments get translated on the fly.

## AI providers — pick your own

You bring your own API key. Six providers supported:

| Provider | Models | Cost |
|----------|--------|------|
| OpenAI | gpt-4.1, gpt-4.1-mini, gpt-4.1-nano | Paid |
| Anthropic | Claude Sonnet 4, Claude Haiku 4 | Paid |
| DeepSeek | deepseek-chat, deepseek-reasoner | Cheap |
| Qwen | qwen-turbo, qwen-plus, qwen-max | Paid |
| Zhipu AI | GLM-4-Flash, GLM-4.5-Flash, GLM-4.7-Flash | **Free** |
| SiliconFlow | Multiple models | **Free tier** |

**No credit card needed** if you go with Zhipu or SiliconFlow. The free models are surprisingly capable for live conversation use.

## Transcription backends

Four options, configurable in Settings:

- **Apple Cloud** (recommended for reliability — continuous conversation)
- **Apple On-Device** (fully offline, no data leaves your phone)
- **OpenAI Realtime** (lowest latency, requires OpenAI key)
- **Whisper** (batch mode, good for short segments)

## Privacy

- Speech recognition can run fully on-device (Apple On-Device backend)
- API keys stored in iOS Keychain
- No accounts, no analytics, no tracking
- Session prep text is sent to your configured LLM provider only — never to us
- Open source: you can read every line of code

## What's coming next

Working on improving question detection speed and response latency. Also exploring a document library feature (upload PDFs, have the AI reference them during live conversations) but only if users actually want it — so let me know.

## How to get it

The app is free on TestFlight. Drop a comment or DM me and I'll send the link. Source code is on GitHub.

Requirements: iPhone (iOS 17+), Even Realities G1 glasses, and an API key from any of the supported providers (or use a free one).

Would love feedback from other G1 owners. What conversation scenarios do you use your glasses for? What would make this more useful for you?

---

*Built by a solo dev who wears G1s every day and got tired of pulling out the phone mid-conversation.*
