#!/usr/bin/env bash
# helix-relay setup: creates .env with a fresh HELIX_RELAY_KEY (if missing), builds,
# and renders launchd plists. It does NOT run tailscale or install launchd jobs —
# it prints the exact commands for you to run.
set -euo pipefail

RELAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$RELAY_DIR"

command -v node >/dev/null || { echo "node not found (need Node >= 22.12)"; exit 1; }
command -v openssl >/dev/null || { echo "openssl not found"; exit 1; }
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 22 ]; then echo "Node >= 22.12 required (found $(node -v))"; exit 1; fi

# 1. .env + relay key
if [ ! -f .env ]; then
  cp env.example .env
  echo "Created .env from env.example"
fi
chmod 600 .env
if ! grep -Eq '^HELIX_RELAY_KEY=.{24,}$' .env; then
  KEY="$(openssl rand -hex 32)"
  if grep -q '^HELIX_RELAY_KEY=' .env; then
    # Replace the empty/short value in place (BSD + GNU sed compatible via temp file).
    tmp="$(mktemp)"
    sed "s/^HELIX_RELAY_KEY=.*/HELIX_RELAY_KEY=${KEY}/" .env > "$tmp" && mv "$tmp" .env
  else
    printf '\nHELIX_RELAY_KEY=%s\n' "$KEY" >> .env
  fi
  chmod 600 .env
  echo "Generated HELIX_RELAY_KEY in .env (copy it into the Helix phone apps' Relay key field)."
else
  echo "HELIX_RELAY_KEY already set in .env (left unchanged)."
fi

# 2. Install + build
npm ci
npm run build

# 3. Render launchd plists (not installed)
mkdir -p data/launchd
chmod 700 data
NODE_BIN="$(command -v node)"
sed -e "s|__NODE__|${NODE_BIN}|g" -e "s|__RELAY_DIR__|${RELAY_DIR}|g" \
  launchd/com.artjiang.helix-relay.plist > data/launchd/com.artjiang.helix-relay.plist
sed -e "s|__HOME__|${HOME}|g" -e "s|__PATH__|$(dirname "$NODE_BIN"):/usr/local/bin:/usr/bin:/bin|g" \
  launchd/com.artjiang.codex-proxy.plist > data/launchd/com.artjiang.codex-proxy.plist

cat <<EOF

Build OK. Next steps (run these yourself):

  # Expose the relay to your tailnet only (HTTPS on 443 -> loopback 8790):
  tailscale serve --bg --https=443 http://127.0.0.1:8790

  # Auto-start the relay at login (plist rendered, not installed):
  #   ${RELAY_DIR}/data/launchd/com.artjiang.helix-relay.plist
  cp "${RELAY_DIR}/data/launchd/com.artjiang.helix-relay.plist" ~/Library/LaunchAgents/
  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.artjiang.helix-relay.plist

  # Optional: auto-start codex-proxy (~/develop/codex-proxy/start.sh) at login:
  #   ${RELAY_DIR}/data/launchd/com.artjiang.codex-proxy.plist
  cp "${RELAY_DIR}/data/launchd/com.artjiang.codex-proxy.plist" ~/Library/LaunchAgents/
  launchctl bootstrap gui/\$(id -u) ~/Library/LaunchAgents/com.artjiang.codex-proxy.plist

  # Or run in the foreground:
  npm start
EOF
