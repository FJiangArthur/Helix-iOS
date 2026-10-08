# helix-relay

Small Node 22 / TypeScript / Fastify service that runs on your Mac and feeds the Helix G1 (Android) and
G2 (Even Hub) apps: Omi to-dos and memories, news (Finnhub + RSS), your imported X posts (Omi MCP),
a 3-line LLM briefing, due-time reminders, and a streaming "Ask" endpoint backed by the local codex-proxy.

The HTTP API is normative in [`conversate-core/CONTRACT-0.3.md` §7](../../conversate-core/CONTRACT-0.3.md);
canonical responses are `conversate-core/fixtures/relay-*.json`, and `test/contract.test.ts` checks the
relay's real output against them.

## Setup

```bash
cd relay/helix-relay
./setup.sh          # creates .env with a random HELIX_RELAY_KEY, npm ci, build, renders launchd plists
$EDITOR .env        # add OMI_DEV_KEY, OMI_MCP_KEY, FINNHUB_KEY, RSS_FEEDS
npm start           # or install the rendered launchd plist (setup.sh prints the commands)
tailscale serve --bg --https=443 http://127.0.0.1:8790
```

The template is `env.example` (no leading dot: the repo security gate rejects any tracked `.env*` path).
The apps then use `HELIX_RELAY_URL=https://<mac>.<tailnet>.ts.net` plus the key from `.env`.
codex-proxy must be running on `127.0.0.1:8787` for the briefing/ranking and `/ask`
(`~/develop/codex-proxy/start.sh`, or the rendered `com.artjiang.codex-proxy.plist`).

| Variable | Purpose |
|---|---|
| `HELIX_RELAY_KEY` | Required bearer key (≥ 24 chars). |
| `HOST` / `PORT` | Bind, default `127.0.0.1:8790`. |
| `OMI_DEV_KEY` | Omi developer API (`omi_dev_…`): action items, memories. |
| `OMI_MCP_KEY` | Omi MCP (`omi_mcp_…`): `get_x_posts`. |
| `FINNHUB_KEY` | Finnhub general news. |
| `RSS_FEEDS` | Comma-separated RSS/Atom URLs. |
| `CODEX_PROXY_URL` / `CODEX_PROXY_KEY` | OpenAI-compatible LLM, default `http://127.0.0.1:8787/v1`; `gpt-5.4` (`gpt-5.5` for `deep`). |
| `RELAY_TZ` | Time zone for "Due 2pm" text and the daily briefing (default: system). |

## Endpoints

All need `Authorization: Bearer $HELIX_RELAY_KEY` except `GET /health`; a bad key gets
`401 {"error":"unauthorized"}`. CORS preflight is answered for any origin.

- `GET /health` → `{"ok":true,"version":"0.3.0"}`
- `GET /dashboard` → `{generatedAt, briefing[], news[], x[], todos[], omi[]}` (also `GET /news`, `/x`, `/todos`, `/omi/memories`)
- `PATCH /todos/:id` `{"completed":bool}` → Omi PATCH → `{"ok":true,"todo":{…}}` (429 + `Retry-After` while Omi rate-limits)
- `GET /reminders?since=<epochMs>` → open to-dos due by now+10 min and after `since`, plus today's briefing headline on every call (id `r-brief-YYYY-MM-DD`, dedupe by id)
- `POST /ask` `{"question","context"?,"deep"?}` → `text/event-stream` of `{"delta"}` … `{"done":true}` or `{"error":"upstream error"}` (details logged server-side only), with a `: ping` comment every 15 s until the first delta; the upstream request is aborted when the client disconnects

## Jobs

On startup and every 15 minutes: fetch Omi action items + memories, Finnhub + RSS news, Omi MCP X posts;
one `gpt-5.4` triage call ranks news by your Omi memories, writes ≤ 3 briefing lines, and extracts due times
for to-dos whose text implies one (validated JSON; on failure the raw data and a deterministic briefing are
kept). A failing source keeps its last good value (empty on a cold cache) and never breaks `/dashboard`.
Omi 429s are honoured per rate-limit bucket via `Retry-After`; Omi's `developer_memory_access_not_ready` 403 is
treated as "no memories". The cache lives in `data/cache.json` (git-ignored, mode 600).

## Security notes

- **Tailnet only.** The relay binds to loopback; `tailscale serve` (not `funnel`) publishes it to your tailnet
  over HTTPS. Never port-forward it or use Tailscale Funnel.
- **The bearer key is the only auth.** Treat it like a password; it is compared in constant time.
  **Rotate** it by deleting the `HELIX_RELAY_KEY=` line from `.env`, rerunning `./setup.sh`, restarting the
  relay (`launchctl kickstart -k gui/$(id -u)/com.artjiang.helix-relay`), and pasting the new key into both apps.
- Upstream keys (Omi, Finnhub) live only in `.env` (chmod 600, git-ignored); they are never sent to clients or logged.
- codex-proxy has no auth of its own; keep it on `127.0.0.1`.

## Development

```bash
npm ci
npm test        # tsc --noEmit + vitest (upstreams mocked with undici MockAgent)
npm run build
```
