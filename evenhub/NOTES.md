# Even Hub app — implementation notes and rulings

Format: **Ruling: what — why — cost if wrong.**

## Toolchain

- **Ruling: pin TypeScript 5.9, Vite 6, Vitest 3, evenhub-cli 0.1.14, SDK 0.0.16 exactly — the plan names TS 5 / Vite 6 and npm's latest are TS 7 / Vite 8 / Vitest 5 — cost if wrong: none functional; bump later.**
- **Ruling: `@evenrealities/evenhub-simulator` is not a dependency (run it with `npx`) — it is a native GUI app with a large binary and is only needed for manual preview — cost if wrong: one extra `npx` download.**

## Rendering (src/g2)

- **Ruling: page validation = SDK `validateEvenHubPageContainer` + our own `validatePage` checks — the SDK validator only checks z-order, menu and brightness; event-capture count, canvas bounds, text bytes and list sizes are firmware rules it does not check — cost if wrong: none (stricter).**
- **Ruling: text containers are capped at 999 UTF-8 bytes at create/rebuild (not 1000 chars), list items at 63 bytes — the evenhub-simulator changelog says it mirrors firmware with "text container bytes limit to 999" and "list item text size maximum 63 bytes and 20 items" — cost if wrong: a few characters of headroom lost.**
- **Ruling: menus (in-app Conversate menu, Prep Note picker) are a text container with a `>` cursor, not a native list container — a native list owns its own selection on the glasses and only reports it on click (`List_ItemEvent.currentSelectItemIndex`), so the session's cursor (which the shared vectors test) would desync from what is drawn; text + `textContainerUpgrade` keeps the session authoritative and makes cursor moves flicker-free — cost if wrong: the menu looks less native; switching to a list is local to `render.ts`.**
- **Ruling: cue detail and Prep Note view are paginated by us (8 lines + `[p/n]` footer), not native text scrolling — the session owns `page` and NEXT/PREV are our scroll events — cost if wrong: if the firmware also scrolls an overflowing container we never overflow it, so no conflict.**
- **Ruling: line width estimated at 44 characters, 9 full-screen lines — the G2 font is proportional and the SDK documents no metrics; the firmware wraps text itself, so this only decides how many caption lines we keep — cost if wrong: captions use slightly less of the screen than possible, or the oldest caption line is clipped; tune `LINE_CHARS` after a simulator/hardware look.**
- **Ruling: layout changes (captions-only ↔ cue card ↔ menu/detail ↔ confirm) and any change of the context-menu labels are rebuilds; everything else is `textContainerUpgrade` — borders cannot be changed by an upgrade, and `menuObject` is only sent on create/rebuild, so a toggled label (Pause→Resume) must rebuild — cost if wrong: an extra flicker on toggles.**
- **Ruling: native context menu ids are stable: live items 1..n in `menu.json` order, idle items 101..; `display_off` is hidden on G2 — spec §4.3 says the system adds Display off/Brightness/Close itself — cost if wrong: if the OS does not add Display off, the wearer loses it on G2 (still reachable via the in-app menu, which keeps it).**

## Audio and transcription (src/audio)

Verified 2026-10-05 against developers.openai.com (guides/realtime-transcription,
guides/realtime-websocket, reference realtime client events): GA interface uses
`session.update` with `session.type: "transcription"` and `session.audio.input.{format,transcription,turn_detection,noise_reduction}`;
`audio/pcm` is 24 kHz only; there is no `transcription_session.update` any more;
server events are `conversation.item.input_audio_transcription.delta` (`item_id`, `delta`)
and `.completed` (`item_id`, `transcript`); `gpt-4o-mini-transcribe` is still in the model enum.

- **Ruling: use the GA Realtime interface and drop the plan's `openai-beta.realtime-v1` subprotocol — the plan's beta subprotocol selects the older beta event shapes (`transcription_session.update`, `input_audio_format: "pcm16"`) that the current reference no longer documents — cost if wrong: the socket rejects the session; the supervisor then falls back to chunked REST after two failures, so captions degrade (3 s finals only) rather than stop.**
- **Ruling: connect to `wss://api.openai.com/v1/realtime?intent=transcription` — the current guide shows no transcription URL; `?intent=transcription` is the documented transcription entry point in earlier docs and community use — cost if wrong: same fallback as above. Not tested against the live API.**
- **Ruling: the user's own API key goes in the `openai-insecure-api-key.<key>` subprotocol from the phone WebView — OpenAI recommends short-lived tokens minted by a server, but this app has no server and the key never leaves the user's phone except to api.openai.com — cost if wrong: a key exposed to the WebView's JS context (same trust boundary as the settings page that stores it).**
- **Ruling: server VAD (threshold 0.5, prefix 300 ms, silence 500 ms), `language: "en"`, `noise_reduction: null` — glasses audio is already processed by the Even app, and Helix sends raw audio to the remote (no extra DSP) — cost if wrong: segment boundaries a little late/early; tune constants.**
- **Ruling: 16→24 kHz linear resampler in exact thirds; the output sample that needs the next frame's first input is held back, so a 1600-sample frame yields 2399 then 2400 — avoids drift and extrapolation at frame edges — cost if wrong: none audible.**
- **Ruling: speaker role per segment = majority `AudioSpeakerRole` over the segment's `audio_start_ms..audio_end_ms` of appended audio — the realtime API knows nothing of Even's role tags, VAD events give the time span — cost if wrong: a segment straddling speakers gets the majority role; role is informational only in v0.1.**
- **Ruling: a realtime connection reports at most one failure (error event or close, whichever first) and the supervisor reconnects once, then switches to `ChunkedTranscriber` for the rest of the app run — plan says "if the socket fails twice" — cost if wrong: a flaky network permanently degrades to chunked until the app restarts.**

## Input (src/g2/input.ts)

- **Ruling: an Even Hub event with no `eventType` is treated as CLICK — `CLICK_EVENT` is protobuf value 0 and proto3 JSON omits defaults; the SDK parses `{containerID}` to `eventType: undefined` — cost if wrong: some other untyped host push would act as SELECT (opens a cue; never ends a session, which needs BACK).**
- **Ruling: R1 vs glasses is read only from `Sys_ItemEvent.eventSource` (`TOUCH_EVENT_FROM_RING` → `R1`, anything else → `G2_TOUCHPAD`); text/list container events carry no source and count as `G2_TOUCHPAD` — the SDK README says source-aware pushes arrive as `sysEvent` — cost if wrong: ring gestures delivered only as text events are labelled G2_TOUCHPAD, which changes nothing but dedupe bookkeeping.**
- **Ruling: one gesture echoed as both a container event and a `sysEvent` (same intent, same source, different channel, < 100 ms) is collapsed in `InputAdapter`; cross-source echoes (ring + temple) are collapsed by the shared 250 ms `IntentDeduper` — the host's delivery pattern is undocumented; this makes double delivery harmless — cost if wrong: two genuine identical gestures < 100 ms apart on different channels count once.**
- **Ruling: LONG_PRESS opens the in-app Conversate menu (plan) while the OS context menu (`menuObject`) is also registered — the spec says the native menu opens on "tap+long-press", so both paths exist — cost if wrong: if the OS opens its context menu on the same long-press, both react; then drop LONG_PRESS→MENU (one line in `GESTURES`).**
- **Ruling: `ConversateSession.activateMenuItem(id)` (TS only) activates a `menu.json` item picked in the native menu as if the cursor were on it, closing any open in-app menu / display-off — the OS menu has no cursor; reusing `activate()` keeps effects identical to the vector-tested cursor path — cost if wrong: none for Android (TS-only addition).**
