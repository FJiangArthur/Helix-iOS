#!/usr/bin/env bash
# Helix conversation-quality eval gate.
#
# Normal usage:
#   HELIX_RUN_CONVERSATION_EVAL=1 bash scripts/run_gate.sh
#
# Useful direct modes:
#   HELIX_EVAL_ALLOW_SCHEMA_ONLY=1 scripts/run_conversation_eval_gate.sh --schema-only
#   HELIX_EVAL_KEEP_SIMULATOR=1 scripts/run_conversation_eval_gate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

REPORT_DIR="${HELIX_EVAL_REPORT_DIR:-/tmp/Helix-QA}"
BUNDLE_ID="${HELIX_EVAL_BUNDLE_ID:-com.artjiang.helix}"
SCHEMA_ONLY=0

log() { printf "\033[1;36mINFO\033[0m %s\n" "$1"; }
pass() { printf "  \033[0;32mPASS\033[0m %s\n" "$1"; }
fail() { printf "  \033[0;31mFAIL\033[0m %s\n" "$1" >&2; }

if [[ "${1:-}" == "--deterministic-only" ]]; then
  fail "--deterministic-only is banned in the strict conversation eval gate"
  exit 1
fi

if [[ "${1:-}" == "--schema-only" ]]; then
  if [[ "${HELIX_EVAL_ALLOW_SCHEMA_ONLY:-0}" != "1" ]]; then
    fail "--schema-only requires HELIX_EVAL_ALLOW_SCHEMA_ONLY=1 and is not a strict gate"
    exit 1
  fi
  SCHEMA_ONLY=1
fi

mkdir -p "$REPORT_DIR"
rm -f "$REPORT_DIR/helix_eval_report.json" "$REPORT_DIR/helix_eval_report.md"

if [[ -z "${HELIX_TEST_OPENAI_KEY:-}" && -n "${OPENAI_API_KEY:-}" ]]; then
  export HELIX_TEST_OPENAI_KEY="$OPENAI_API_KEY"
fi

log "Checking strict eval guardrails"
if grep -R "class _EvalProvider\\|id => 'helix_eval'\\|ToolExecutor.overrideForTesting" \
  lib/services/conversation_eval_gate.dart test/services/conversation_eval_gate_test.dart >/dev/null 2>&1; then
  fail "Strict conversation eval must not use deterministic eval providers or fake tool overrides"
  exit 1
fi
pass "No deterministic eval provider or fake tool override found in strict eval harness"

log "Running conversation eval schema/key-failure tests"
flutter test test/services/conversation_eval_gate_test.dart --reporter compact
pass "Conversation eval schema/key-failure tests passed"

if [[ "$SCHEMA_ONLY" == "1" ]]; then
  log "Skipping simulator eval by request"
  exit 0
fi

if [[ "${HELIX_EVAL_SKIP_SIMULATOR:-0}" == "1" ]]; then
  fail "HELIX_EVAL_SKIP_SIMULATOR is banned in the strict conversation eval gate"
  exit 1
fi

if [[ -z "${HELIX_TEST_OPENAI_KEY:-}" ]]; then
  fail "HELIX_TEST_OPENAI_KEY or OPENAI_API_KEY is required for simulator audio transcription eval"
  exit 1
fi

if [[ ! -f test/fixtures/latency_corpus/youtube_manifest.local.json && \
      ! -f test/fixtures/latency_corpus/youtube_manifest.json ]]; then
  fail "Strict eval requires a YouTube audio manifest under test/fixtures/latency_corpus"
  exit 1
fi

first_sorted_match() {
  local dir="$1"
  shift
  local match=""
  local first=""
  [[ -d "$dir" ]] || return 1
  while IFS= read -r match; do
    if [[ -z "$first" ]]; then
      first="$match"
    fi
  done < <(find "$dir" -maxdepth 1 "$@" -print 2>/dev/null | sort)
  [[ -n "$first" ]] || return 1
  printf "%s\n" "$first"
}

find_audio_fixture() {
  local candidate
  candidate="$(first_sorted_match test/fixtures/latency_corpus -name "*.wav" || true)"
  if [[ -n "$candidate" ]]; then
    printf "%s\n" "$candidate"
    return 0
  fi
  return 1
}

AUDIO_FILE="$(find_audio_fixture || true)"
if [[ -z "$AUDIO_FILE" || ! -f "$AUDIO_FILE" ]]; then
  fail "No YouTube eval WAV found. Run scripts/setup_youtube_eval_audio.sh with an authorized/Creative Commons manifest"
  exit 1
fi
log "Using eval audio fixture: $AUDIO_FILE"

pick_runtime() {
  xcrun simctl list runtimes | awk '/^iOS/ && $NF ~ /^com\.apple\.CoreSimulator\.SimRuntime\./ {print $NF}' | tail -1
}

pick_device_type() {
  local candidate
  local preferred
  for preferred in "iPhone 17 Pro" "iPhone 16 Pro" "iPhone 15 Pro"; do
    candidate="$(xcrun simctl list devicetypes | awk -v preferred="$preferred" '
      index($0, preferred " (") == 1 {
        sub(/^.*\(/, "")
        sub(/\).*$/, "")
        print
        exit
      }
    ')"
    if [[ -n "$candidate" ]]; then
      printf "%s\n" "$candidate"
      return 0
    fi
  done
  xcrun simctl list devicetypes | awk '/^iPhone/ {
    sub(/^.*\(/, "")
    sub(/\).*$/, "")
    print
    exit
  }'
}

RUNTIME="${HELIX_EVAL_RUNTIME:-$(pick_runtime)}"
DEVICE_TYPE="${HELIX_EVAL_DEVICE_TYPE:-$(pick_device_type)}"
if [[ -z "$RUNTIME" || -z "$DEVICE_TYPE" ]]; then
  fail "Could not resolve an available iOS simulator runtime/device type"
  exit 1
fi

SIM_UDID="$(xcrun simctl create "Helix-QA-$(date +%H%M%S)" "$DEVICE_TYPE" "$RUNTIME")"
log "Created dedicated simulator: $SIM_UDID ($DEVICE_TYPE, $RUNTIME)"

cleanup() {
  if [[ "${HELIX_EVAL_KEEP_SIMULATOR:-0}" != "1" && -n "${SIM_UDID:-}" ]]; then
    xcrun simctl shutdown "$SIM_UDID" >/dev/null 2>&1 || true
    xcrun simctl delete "$SIM_UDID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

xcrun simctl boot "$SIM_UDID" >/dev/null
xcrun simctl privacy "$SIM_UDID" grant microphone "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl privacy "$SIM_UDID" grant speech-recognition "$BUNDLE_ID" >/dev/null 2>&1 || true

GIT_SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
log "Building simulator app with HELIX_EVAL_GATE enabled"
flutter build ios --simulator --no-codesign \
  --dart-define=HELIX_EVAL_GATE=true \
  --dart-define=HELIX_EVAL_GIT_SHA="$GIT_SHA" \
  --dart-define=HELIX_EVAL_SIMULATOR_UDID="$SIM_UDID" \
  --dart-define=HELIX_EVAL_OPENAI_MODEL="${HELIX_EVAL_OPENAI_MODEL:-gpt-4.1-mini}"

APP_PATH="$(find build/ios/iphonesimulator -maxdepth 2 -name "*.app" -print | head -1)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  fail "Could not find built simulator .app under build/ios/iphonesimulator"
  exit 1
fi

xcrun simctl install "$SIM_UDID" "$APP_PATH"
CONTAINER="$(xcrun simctl get_app_container "$SIM_UDID" "$BUNDLE_ID" data)"
mkdir -p "$CONTAINER/Documents/eval_audio"
cp "$AUDIO_FILE" "$CONTAINER/Documents/eval_audio/$(basename "$AUDIO_FILE")"

HELIX_TEST_OPENAI_KEY="$HELIX_TEST_OPENAI_KEY" python3 - <<'PY' > "$CONTAINER/Documents/helix_eval_config.json"
import json, os
print(json.dumps({"apiKey": os.environ.get("HELIX_TEST_OPENAI_KEY", "")}))
PY

rm -f "$CONTAINER/Documents/helix_eval_report.json" "$CONTAINER/Documents/helix_eval_report.md"
log "Launching eval app"
xcrun simctl launch "$SIM_UDID" "$BUNDLE_ID" >/dev/null

REPORT_JSON="$CONTAINER/Documents/helix_eval_report.json"
for _ in $(seq 1 120); do
  if [[ -s "$REPORT_JSON" ]] && grep -q '"overall"' "$REPORT_JSON"; then
    break
  fi
  sleep 1
done

if [[ ! -s "$REPORT_JSON" ]]; then
  fail "Simulator eval report was not written within 120s"
  exit 1
fi

cp "$REPORT_JSON" "$REPORT_DIR/helix_eval_report.json"
if [[ -f "$CONTAINER/Documents/helix_eval_report.md" ]]; then
  cp "$CONTAINER/Documents/helix_eval_report.md" "$REPORT_DIR/helix_eval_report.md"
fi

python3 - "$REPORT_DIR/helix_eval_report.json" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
print("\nHelix Conversation Eval")
print(f"Overall: {data['overall']}")
print(f"Report: {path}")
print("")
print(f"{'ID':<4} {'Area':<20} {'Status':<8} {'Latency':>8}  Actual")
print("-" * 78)
for check in data.get("checks", []):
    actual = str(check.get("actual", "")).replace("\n", " ")
    if len(actual) > 72:
        actual = actual[:69] + "..."
    if check.get("reportOnly"):
        suffix = " (report)"
    elif check.get("latencyReportOnly"):
        suffix = " (latency)"
    else:
        suffix = ""
    print(f"{check['id']:<4} {check['area']:<20} {check['status'] + suffix:<8} {check['latencyMs']:>7}ms  {actual}")
sys.exit(0 if data.get("overall") == "PASS" else 1)
PY
