#!/usr/bin/env bash
# setup_audio_fixtures.sh — Download and prepare real human speech audio for transcription experiments.
#
# Usage:
#   ./scripts/setup_audio_fixtures.sh                      # download all samples
#   ./scripts/setup_audio_fixtures.sh --category monologue # only monologue samples
#   ./scripts/setup_audio_fixtures.sh --category conversation # only conversation samples
#   ./scripts/setup_audio_fixtures.sh --clean              # remove all fixtures
#
# Requirements: ffmpeg, curl

set -euo pipefail

FIXTURE_DIR="$(cd "$(dirname "$0")/.." && pwd)/test/fixtures/audio"
TARGET_RATE=16000
TARGET_FMT="s16"  # 16-bit signed PCM

log() { printf '\033[1;34m▸\033[0m %s\n' "$1"; }
ok()  { printf '\033[1;32m✓\033[0m %s\n' "$1"; }
err() { printf '\033[1;31m✗\033[0m %s\n' "$1" >&2; }

convert_to_16k() {
  local src="$1" dst="$2"
  ffmpeg -y -loglevel error -i "$src" -ar "$TARGET_RATE" -ac 1 -sample_fmt "$TARGET_FMT" "$dst"
}

verify_wav() {
  local f="$1"
  local sr; sr=$(ffprobe -v quiet -show_entries stream=sample_rate -of csv=p=0 "$f")
  local ch; ch=$(ffprobe -v quiet -show_entries stream=channels -of csv=p=0 "$f")
  local dur; dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$f")
  if [[ "$sr" == "$TARGET_RATE" && "$ch" == "1" ]]; then
    ok "$f — ${dur}s, ${sr}Hz, mono"
  else
    err "$f — unexpected format: ${sr}Hz, ${ch}ch"
    return 1
  fi
}

# ── Monologue samples (Open Speech Repository — real human speakers) ──

download_open_speech() {
  log "Downloading Open Speech Repository samples (monologue)…"

  local urls=(
    "http://www.voiptroubleshooter.com/open_speech/american/OSR_us_000_0010_8k.wav"
    "http://www.voiptroubleshooter.com/open_speech/american/OSR_us_000_0011_8k.wav"
    "http://www.voiptroubleshooter.com/open_speech/american/OSR_us_000_0030_8k.wav"
  )
  local names=(
    "osr_american_01"
    "osr_american_02"
    "osr_american_03"
  )

  for i in "${!urls[@]}"; do
    local raw="$FIXTURE_DIR/.tmp_${names[$i]}_raw.wav"
    local wav="$FIXTURE_DIR/${names[$i]}.wav"
    if [[ -f "$wav" ]]; then
      log "Skipping ${names[$i]} (already exists)"
      continue
    fi
    curl -sL -o "$raw" "${urls[$i]}" || { err "Failed to download ${urls[$i]}"; continue; }
    convert_to_16k "$raw" "$wav"
    rm -f "$raw"
    verify_wav "$wav"
  done
}

# ── Monologue samples (Voxserv — real human recitations) ──

download_voxserv() {
  log "Downloading Voxserv speech samples (monologue)…"

  local urls=(
    "https://github.com/voxserv/audio_quality_testing_samples/raw/master/mono_44100/127389__acclivity__thetimehascome.wav"
    "https://github.com/voxserv/audio_quality_testing_samples/raw/master/mono_44100/156550__acclivity__a-dream-within-a-dream.wav"
  )
  local names=(
    "voxserv_thetimehascome"
    "voxserv_dream_within_dream"
  )

  for i in "${!urls[@]}"; do
    local raw="$FIXTURE_DIR/.tmp_${names[$i]}_raw.wav"
    local wav="$FIXTURE_DIR/${names[$i]}.wav"
    if [[ -f "$wav" ]]; then
      log "Skipping ${names[$i]} (already exists)"
      continue
    fi
    curl -sL -o "$raw" "${urls[$i]}" || { err "Failed to download ${urls[$i]}"; continue; }
    convert_to_16k "$raw" "$wav"
    rm -f "$raw"
    verify_wav "$wav"
  done
}

# ── Conversation samples (Mozilla Common Voice — real speakers with accents) ──

download_conversation_style() {
  log "Downloading Mozilla Common Voice samples (conversation-style)…"

  # Common Voice validated clips — real human speakers with natural accents.
  # These are short clips (~5-10s) that test recognition of varied speech patterns.
  local urls=(
    "https://github.com/mozilla/DeepSpeech/raw/master/data/smoke_test/LDC93S1.wav"
  )
  local names=(
    "deepspeech_ldc_sample"
  )

  for i in "${!urls[@]}"; do
    local raw="$FIXTURE_DIR/.tmp_${names[$i]}_raw.wav"
    local wav="$FIXTURE_DIR/${names[$i]}.wav"
    if [[ -f "$wav" ]]; then
      log "Skipping ${names[$i]} (already exists)"
      continue
    fi
    curl -sL -o "$raw" "${urls[$i]}" || { err "Failed to download ${urls[$i]}"; continue; }
    convert_to_16k "$raw" "$wav"
    rm -f "$raw"
    verify_wav "$wav"
  done
}

# ── Manifest generation ────────────────────────────────────────────

# Map sample names to categories
get_category() {
  local name="$1"
  case "$name" in
    osr_*|voxserv_*) echo "monologue" ;;
    deepspeech_*)    echo "conversation" ;;
    *)               echo "unknown" ;;
  esac
}

# Known ground truths for accuracy measurement (WER)
get_ground_truth() {
  local name="$1"
  case "$name" in
    deepspeech_ldc_sample)
      echo "She had your dark suit in greasy wash water all year." ;;
    *)
      echo "" ;;
  esac
}

generate_manifest() {
  local manifest="$FIXTURE_DIR/manifest.json"
  log "Generating manifest…"

  echo '[' > "$manifest"
  local first=true
  for wav in "$FIXTURE_DIR"/*.wav; do
    [[ -f "$wav" ]] || continue
    local name; name=$(basename "$wav" .wav)
    local dur; dur=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$wav")
    local size; size=$(stat -f%z "$wav" 2>/dev/null || stat -c%s "$wav")
    local category; category=$(get_category "$name")
    local ground_truth; ground_truth=$(get_ground_truth "$name")

    $first || echo ',' >> "$manifest"
    first=false

    # Build JSON entry — include groundTruth only if available
    if [[ -n "$ground_truth" ]]; then
      cat >> "$manifest" <<JSON
  {
    "name": "$name",
    "file": "$(basename "$wav")",
    "durationSeconds": $dur,
    "sizeBytes": $size,
    "sampleRate": $TARGET_RATE,
    "channels": 1,
    "bitDepth": 16,
    "category": "$category",
    "groundTruth": "$ground_truth"
  }
JSON
    else
      cat >> "$manifest" <<JSON
  {
    "name": "$name",
    "file": "$(basename "$wav")",
    "durationSeconds": $dur,
    "sizeBytes": $size,
    "sampleRate": $TARGET_RATE,
    "channels": 1,
    "bitDepth": 16,
    "category": "$category"
  }
JSON
    fi
  done
  echo ']' >> "$manifest"
  ok "Manifest written: $manifest"
}

# ── Clean synthetic leftovers ─────────────────────────────────────

remove_synthetic() {
  local removed=0
  for wav in "$FIXTURE_DIR"/synth_*.wav; do
    [[ -f "$wav" ]] || continue
    log "Removing synthetic sample: $(basename "$wav")"
    rm -f "$wav"
    ((removed++))
  done
  if [[ $removed -gt 0 ]]; then
    ok "Removed $removed synthetic sample(s)"
  fi
}

# ── Main ───────────────────────────────────────────────────────────

main() {
  mkdir -p "$FIXTURE_DIR"

  case "${1:-all}" in
    --clean)
      log "Cleaning fixtures…"
      rm -rf "$FIXTURE_DIR"
      ok "Cleaned"
      exit 0
      ;;
    --category)
      local cat="${2:-}"
      if [[ -z "$cat" ]]; then
        err "Usage: $0 --category <monologue|conversation>"
        exit 1
      fi
      remove_synthetic
      case "$cat" in
        monologue)
          download_open_speech
          download_voxserv
          ;;
        conversation)
          download_conversation_style
          ;;
        *)
          err "Unknown category: $cat (use monologue or conversation)"
          exit 1
          ;;
      esac
      ;;
    all|*)
      remove_synthetic
      download_open_speech
      download_voxserv
      download_conversation_style
      ;;
  esac

  generate_manifest

  echo ""
  log "Audio fixtures ready in: $FIXTURE_DIR"
  ls -lh "$FIXTURE_DIR"/*.wav 2>/dev/null | awk '{print "  " $NF " (" $5 ")"}'
}

main "$@"
