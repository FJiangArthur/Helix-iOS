# Conversate contract 0.3 — modes, display controls, dashboard panels, Ask, relay API

Normative for both apps (Android `conversate/`, G2 `evenhub/src/core/`). Vectors in `vectors/session-pickers.json`
and `vectors/session-panels.json` are the arbiter. Plan: `/Users/artjiang/.claude/plans/pasted-content-id-1f34-right-now-atomic-crown.md`.

## 1. Menu (`menu.json` v2)
- `idle` and `live` lists as in the file. Toggle items unchanged. New ids: `ask`, `news`, `x`, `todos`, `omi`, `mode`, `display`.
- G2's native context menu keeps its 10-item cap: it shows the first 10 live (or idle) items; everything stays reachable from the in-app menu.

## 2. Overlay stack
Child screens opened from a menu (`mode`, `display`, panels, `ask`) remember the menu they came from (kind + cursor).
BACK in a child returns to that menu with the **same cursor**. BACK in a menu behaves as before.

## 3. Mode picker (`mode`)
- Screen: `Menu(title "MODE", items = pickers.mode labels, cursor = index of current mode)`.
- Current mode is session state `mode` (default `PHONE_MIC`), settable by `setMode(id)` from the phone.
- SELECT → effect `SetMode:<ID>`, session `mode` updates, returns to the parent menu.
- BACK → parent menu, no effect.

## 4. Display controls (`display`)
- Screen: `Menu(title "DISPLAY", items = rendered labels, cursor 0)`; label `{v}` = current value.
- Prefs gain `captionLines` (default 5, values 2–5) and `brightness` (default 3, values 1–4); `cueSeconds` = `cueDurationMillis / 1000`; `captions` = `captionsOn` (`on`/`off`).
- SELECT cycles the item to the next value in `values` (wrapping) → effect `SetPref:<id>=<value>`, stays in the picker, label updates, cursor unchanged.
- `captionLines` caps the caption rows drawn in Live (captions-only and pending-count layouts); the cue card layout is unchanged.
- `brightness` 1–4: G1 sends `G1CommandEncoder.brightness(level*10 + (level==4?2:0))` i.e. 10/20/30/42; G2 uses text `textColor` = level.

## 5. Dashboard panels (`news`, `x`, `todos`, `omi`)
- Opening emits `RequestPanel:<kind>` (app refreshes data, may call `setPanelRows` later).
- Rows: `{id, title, detail, done?}` supplied via `setPanelRows(kind, rows)`; titles are pre-truncated by the app's composer.
- Screen: `Panel(title = panels.<kind>.title, items, cursor)` where items = row titles; for `todos` each item is `"[ ] <title>"` or `"[x] <title>"`. Empty → items `["Nothing here"]` (cursor 0, SELECT no-op).
- NEXT/PREV move the cursor (clamped). Rows replaced by `setPanelRows` keep the cursor clamped.
- SELECT on `todos` → flips `done` locally, effect `ToggleTodo:<id>=<true|false>`, stays.
- SELECT on other kinds → `PanelDetail(title = row title, text = row detail, page 0)`, paged like Prep Note; NEXT/PREV page; BACK → the panel (cursor kept).
- BACK in a panel → parent menu.

## 6. Ask (`ask`)
- SELECT `ask` → effect `AskListen`, screen `Ask` (lens text "Ask: listening…").
- The app feeds the next final transcript segment(s) via `onAskText(text)` → effect `AskQuestion:<text>` and the overlay closes to where the menu was opened from (the menu itself is closed too).
- BACK while listening → effect `AskCancel`, back to the parent menu.
- The answer is delivered as an `ANSWER` cue through the normal cue path (live) or shown as `AnswerCard` when not live (G1 Display-only / idle): session `showAnswer(cue)` sets an overlay `CueDetail`.
- `showAnswer` while the `Ask` overlay is open first cancels it (effect `AskCancel`) so the app always releases a mic it opened for Ask.
- Display-only mode: glasses Ask opens the mic for that one utterance only (explicit wearer action), then closes it.
- No relay configured: Ask falls back to the app's own configured AI provider (G2: the user's OpenAI key; Android: the active answer provider). A configured-but-failing relay shows "Ask failed" and does not fall back.
- Cancelling an Ask (BACK while listening, or a newer Ask) aborts only the glasses Ask's own request; a phone Ask is never aborted by the glasses.

## 7. Relay API (`relay/helix-relay`, reached at `HELIX_RELAY_URL`, e.g. `https://<mac>.<tailnet>.ts.net`)
All requests: `Authorization: Bearer <HELIX_RELAY_KEY>`; missing/wrong key → `401 {"error":"unauthorized"}`.
Titles ≤ 60 chars, details ≤ 600 chars (relay truncates). Times ISO-8601 UTC.

| Method | Path | Response |
|---|---|---|
| GET | `/health` (no auth) | `{"ok":true,"version":"0.3.0"}` |
| GET | `/dashboard` | see `fixtures/relay-dashboard.json` |
| PATCH | `/todos/:id` body `{"completed":bool}` | `{"ok":true,"todo":{…}}` |
| GET | `/reminders?since=<epochMs>` | see `fixtures/relay-reminders.json`; due/overdue to-dos with `since < dueAt <= now+10min`, plus **today's briefing on every call** with a per-day id `r-brief-YYYY-MM-DD` (relay time zone) — clients dedupe by id |
| POST | `/ask` body `{"question":str,"context"?:str,"deep"?:bool}` | `text/event-stream`: `data: {"delta":"…"}` …, `data: {"done":true}`; on failure `data: {"error":"upstream error"}` (details logged server-side only); a `: ping` comment every 15 s until the first delta |

CORS: relay answers preflight for any origin with `Access-Control-Allow-Headers: authorization, content-type`
(the bearer key is the protection; the relay is only reachable inside the user's tailnet).

## 8. Client robustness
- Every relay request has a 15 s timeout (Ask: 15 s to first byte, then no limit while pings/deltas arrive).
- A 200 response that is not the expected JSON is a relay error ("Unexpected relay response"), never a crash.
- App startup never waits on the relay: the UI renders first, relay data fills in later.
