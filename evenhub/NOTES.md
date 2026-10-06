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
- **Ruling: line width 54 characters, 9 full-screen lines — the G2 font is proportional and the SDK documents no metrics; in evenhub-simulator 0.9.5 a 30-character prose line measured ≈278 px (≈9.3 px/char, so ≈60 chars across 576 px) and ~10 lines fit in 288 px; the firmware wraps text itself, so this mainly decides how many caption lines we keep — cost if wrong: captions use slightly less of the screen, or the oldest caption line is clipped; tune `LINE_CHARS` on hardware.**
- **Ruling: layout changes (captions-only ↔ cue card ↔ menu/detail ↔ confirm) and any change of the context-menu labels are rebuilds; everything else is `textContainerUpgrade` — borders cannot be changed by an upgrade, and `menuObject` is only sent on create/rebuild, so a toggled label (Pause→Resume) must rebuild — cost if wrong: an extra flicker on toggles.**
- **Ruling: native context menu ids are stable: live items 1..n in `menu.json` order, idle items 101..; `display_off` is hidden on G2 — spec §4.3 says the system adds Display off/Brightness/Close itself — cost if wrong: if the OS does not add Display off, the wearer loses it on G2 (still reachable via the in-app menu, which keeps it). Observed: evenhub-simulator 0.9.5 shows only our items (no system Display off), so verify on hardware.**

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

## Cues, answers and app wiring (src/ai, src/app.ts)

- **Ruling: ANSWER cues come from a minimal detector (`?`-terminated or wh/auxiliary opener, ≥3 words) + one `gpt-4.1-mini` call (≤3 sentences), one answer in flight, and questions tagged `AudioSpeakerRole.Self` are not answered — Android reuses its existing QuestionDetector which does not exist here; the wearer rarely wants their own question answered — cost if wrong: if the Even role classifier mislabels the other speaker as self, their questions go unanswered (role `unknown` is still answered).**
- **Ruling: the cue engine and answers run only while Cues are on — the menu toggle "Cues: off" should silence the model calls too, not just hide results — cost if wrong: none.**
- **Ruling: with no API key a session still starts; the caption slot shows "Add your OpenAI key in / Helix Conversate on your phone", the mic stays closed, and saving a key mid-session arms audio — plan: "missing key shows a phone-page prompt and a lens line, never a crash" — cost if wrong: none.**
- **Ruling: render pipeline = one bridge call in flight, latest state wins; rebuilds and user-driven upgrades go immediately, caption/tick upgrades are spaced ≥300 ms; a failed create/rebuild/upgrade drops the cached page so the next render rebuilds — plan "render coalescing (latest state wins; upgrades ≥300 ms apart for captions)" — cost if wrong: a failing host is retried every 250 ms tick.**
- **Ruling: Blank → Menu (both full-screen) is an upgrade, not a rebuild — same layout and same `menuObject`, so a rebuild is unnecessary flicker — cost if wrong: none.**
- **Ruling: FOREGROUND_ENTER/EXIT never close the mic; both re-assert `audioControl(true)`, EXIT also forces a full rebuild; only SYSTEM_EXIT/ABNORMAL_EXIT close it; the phone WebView's `visibilitychange → visible` re-arms audio and rebuilds — this deviates from plan review focus 5 ("on FOREGROUND_EXIT stop audio") because evenhub-simulator 0.9.5 emits FOREGROUND_ENTER when the OS context menu opens over the app and FOREGROUND_EXIT when it closes, so the plan's mapping would kill captions every time the wearer used the native menu — cost if wrong: if on hardware FOREGROUND_EXIT really means "the wearer switched to another glasses app", the mic stays open (and audio is still billed to their key) until they return or the system exits the app.**

## Phone page (src/phone, src/main.ts)

- **Ruling: the bridge is used only if `waitForEvenAppBridge()` resolves within 2 s AND `window.flutter_inappwebview.callHandler` exists; otherwise the page runs bridge-less with `localStorage` — the SDK's bridge object can exist in a plain browser, but every native call then fails with "Flutter handler not available" — cost if wrong: if a host exposes the bridge without that global, the app silently runs phone-only; widen the check in `main.ts`.**
- **Ruling: the key field is `type=password`, cleared after save, never echoed back to the DOM, and its placeholder avoids the `sk-` prefix — keeps `grep -r "sk-" dist release` meaningful as a secret check — cost if wrong: none.**
- **Ruling: Prep Notes are edited as plain text (≤5000 chars, enforced by `maxlength` and again in `App.savePrepNote`); no TXT/PDF import in v0.1 — the plan's Task 7 lists list/add/edit/delete only — cost if wrong: paste-only import.**

## Input (src/g2/input.ts)

- **Ruling: an Even Hub event with no `eventType` is treated as CLICK — `CLICK_EVENT` is protobuf value 0 and proto3 JSON omits defaults; the SDK parses `{containerID}` to `eventType: undefined` — cost if wrong: some other untyped host push would act as SELECT (opens a cue; never ends a session, which needs BACK).**
- **Ruling: R1 vs glasses is read only from `Sys_ItemEvent.eventSource` (`TOUCH_EVENT_FROM_RING` → `R1`, anything else → `G2_TOUCHPAD`); text/list container events carry no source and count as `G2_TOUCHPAD` — the SDK README says source-aware pushes arrive as `sysEvent` — cost if wrong: ring gestures delivered only as text events are labelled G2_TOUCHPAD, which changes nothing but dedupe bookkeeping.**
- **Ruling: one gesture echoed as both a container event and a `sysEvent` (same intent, same source, different channel, < 100 ms) is collapsed in `InputAdapter`; cross-source echoes (ring + temple) are collapsed by the shared 250 ms `IntentDeduper` — the host's delivery pattern is undocumented; this makes double delivery harmless — cost if wrong: two genuine identical gestures < 100 ms apart on different channels count once.**
- **Ruling: LONG_PRESS opens the in-app Conversate menu (plan) while the OS context menu (`menuObject`) is also registered — the spec says the native menu opens on "tap+long-press", so both paths exist — cost if wrong: if the OS opens its context menu on the same long-press, both react; then drop LONG_PRESS→MENU (one line in `GESTURES`).**
- **Ruling: `ConversateSession.activateMenuItem(id)` (TS only) activates a `menu.json` item picked in the native menu as if the cursor were on it, closing any open in-app menu / display-off — the OS menu has no cursor; reusing `activate()` keeps effects identical to the vector-tested cursor path — cost if wrong: none for Android (TS-only addition).**
