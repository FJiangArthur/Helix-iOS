#!/usr/bin/env bash
# Main-branch commit gate. Blocks commits to main unless native gates and the
# live OpenAI smoke test pass with OPENAI_API_KEY from .env.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
force="${HELIX_COMMIT_GATE_FORCE:-0}"

if [[ "$branch" != "main" && "$force" != "1" ]]; then
  echo "Helix commit gate: branch '${branch:-detached}' is not main; running staged security gate only."
  bash scripts/security_gate.sh --staged
  exit 0
fi

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

load_openai_key_from_env_file() {
  local env_file="$PROJECT_ROOT/.env"
  local line key value
  [[ -f "$env_file" ]] || return 1

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="$(trim "$line")"
    [[ -z "$line" || "${line:0:1}" == "#" ]] && continue
    line="${line#export }"
    [[ "$line" == *"="* ]] || continue

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"
    if [[ "$key" == "OPENAI_API_KEY" ]]; then
      value="${value%\"}"
      value="${value#\"}"
      value="${value%\'}"
      value="${value#\'}"
      [[ -n "$value" ]] || return 1
      export OPENAI_API_KEY="$value"
      return 0
    fi
  done < "$env_file"

  return 1
}

echo "Helix main commit gate: running extensive validation."

if ! load_openai_key_from_env_file; then
  echo "FAIL: .env must contain OPENAI_API_KEY for commits to main." >&2
  exit 1
fi

bash scripts/security_gate.sh --staged
swift test --package-path NativeHelix --filter NativeConversationTests
bash scripts/run_native_swift_gate.sh
bash scripts/run_gate.sh

HELIX_RUN_LIVE_OPENAI_EVAL=1 \
HELIX_OPENAI_EVAL_MODEL="${HELIX_OPENAI_EVAL_MODEL:-gpt-4.1-mini}" \
swift test --package-path NativeHelix \
  --filter NativeConversationTests/testLiveOpenAIAnswerProviderWithEnvironmentKeyWhenRequested

echo "Helix main commit gate: all checks passed."
