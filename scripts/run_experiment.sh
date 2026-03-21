#!/usr/bin/env bash
# run_experiment.sh — Run audio transcription experiments.
#
# Usage:
#   ./scripts/run_experiment.sh          # Run all Dart simulation tests
#   ./scripts/run_experiment.sh --setup  # Download audio fixtures first
#   ./scripts/run_experiment.sh --info   # Dump fixture metadata
#
# For native experiments, the app must be running on a device/simulator.
# Use AudioExperimentHarness.runNativeExperiment() from the app.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURE_DIR="$PROJECT_DIR/test/fixtures/audio"

log() { printf '\033[1;34m▸\033[0m %s\n' "$1"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$1"; }
err() { printf '\033[1;31m✗\033[0m %s\n' "$1" >&2; }

run_setup() {
  log "Setting up audio fixtures…"
  "$SCRIPT_DIR/setup_audio_fixtures.sh"
}

run_dart_tests() {
  log "Running experiment Dart tests…"
  cd "$PROJECT_DIR"
  flutter test test/services/audio_experiment_test.dart --reporter expanded
}

run_info() {
  if [[ ! -f "$FIXTURE_DIR/manifest.json" ]]; then
    err "No manifest found. Run: $0 --setup"
    exit 1
  fi

  log "Audio fixture metadata:"
  echo ""

  if command -v jq &>/dev/null; then
    jq -r '.[] | "  \(.name)\n    duration: \(.durationSeconds)s | size: \(.sizeBytes / 1024 | floor)KB | category: \(.category // "unknown")\(.groundTruth // "" | if . != "" then "\n    ground truth: \(.)" else "" end)\n"' "$FIXTURE_DIR/manifest.json"
  else
    # Fallback: just cat the manifest
    cat "$FIXTURE_DIR/manifest.json"
  fi

  local count
  count=$(ls -1 "$FIXTURE_DIR"/*.wav 2>/dev/null | wc -l | tr -d ' ')
  ok "$count audio fixture(s) available"
}

case "${1:-test}" in
  --setup)
    run_setup
    ;;
  --info)
    run_info
    ;;
  test|*)
    run_dart_tests
    ;;
esac
