# Omi → Helix live transcript relay

Cloudflare Worker that receives Omi's real-time transcript webhook and lets the
Helix Android app long-poll for new segments.

## Deploy (once)

```bash
cd android/relay/omi-relay
npx wrangler login
npx wrangler deploy
```

Note the printed URL, e.g. `https://omi-helix-relay.<you>.workers.dev`.

## Wire up

1. Pick a secret token (>= 16 random chars), e.g. `openssl rand -hex 16`.
2. Omi app → Settings → Developer Mode → **Real-Time Transcript Webhook**:
   `https://omi-helix-relay.<you>.workers.dev/hook/<token>/transcript`
3. Helix → Settings → Omi connection → **Live transcript relay**:
   `https://omi-helix-relay.<you>.workers.dev/feed/<token>`
4. Tap **Start live** in Helix; speak near the Omi device.

The token is the only auth — treat both URLs as secrets.
