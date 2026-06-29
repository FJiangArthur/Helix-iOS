#!/usr/bin/env bash
# Prepare local YouTube-derived eval audio.
#
# The source list intentionally lives outside this script. Create:
#   test/fixtures/latency_corpus/youtube_manifest.local.json
#
# Schema:
# [
#   {
#     "id": "llm-qa-01",
#     "sourceUrl": "https://www.youtube.com/watch?v=...",
#     "license": "Creative Commons or user-authorized",
#     "notes": "LLM Q&A clip",
#     "start": "00:02:10",
#     "duration": 30,
#     "expectedMarkers": ["transformer", "tokens"]
#   }
# ]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CORPUS_DIR="$PROJECT_ROOT/test/fixtures/latency_corpus"
MANIFEST="${HELIX_YOUTUBE_AUDIO_MANIFEST:-$CORPUS_DIR/youtube_manifest.local.json}"
OUT_MANIFEST="$CORPUS_DIR/manifest.json"

log() { printf "\033[1;36mINFO\033[0m %s\n" "$1"; }
fail() { printf "\033[0;31mFAIL\033[0m %s\n" "$1" >&2; exit 1; }

command -v yt-dlp >/dev/null || fail "yt-dlp is required (brew install yt-dlp)"
command -v ffmpeg >/dev/null || fail "ffmpeg is required (brew install ffmpeg)"
command -v ffprobe >/dev/null || fail "ffprobe is required (brew install ffmpeg)"
command -v python3 >/dev/null || fail "python3 is required"

[[ -f "$MANIFEST" ]] || fail "Missing $MANIFEST. Copy youtube_manifest.example.json and fill in user-authorized/CC sources."

mkdir -p "$CORPUS_DIR"

python3 - "$MANIFEST" "$CORPUS_DIR" <<'PY'
import json, pathlib, sys
manifest = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
items = json.loads(manifest.read_text())
if not isinstance(items, list) or not items:
    raise SystemExit("manifest must be a non-empty JSON list")
for item in items:
    for key in ("id", "sourceUrl", "license"):
        if not str(item.get(key, "")).strip():
            raise SystemExit(f"manifest item missing {key}: {item}")
    license_text = str(item.get("license", "")).lower()
    if "creative commons" not in license_text and "authorized" not in license_text:
        raise SystemExit(f"{item['id']} must declare Creative Commons or user-authorized license")
    safe = str(item["id"]).replace("/", "-")
    item["wav"] = str(out / f"{safe}.wav")
print(json.dumps(items))
PY

ITEMS_JSON="$(python3 - "$MANIFEST" "$CORPUS_DIR" <<'PY'
import json, pathlib, sys
items = json.loads(pathlib.Path(sys.argv[1]).read_text())
out = pathlib.Path(sys.argv[2])
for item in items:
    safe = str(item["id"]).replace("/", "-")
    item["wav"] = str(out / f"{safe}.wav")
print(json.dumps(items))
PY
)"

python3 - "$ITEMS_JSON" <<'PY' | while IFS=$'\t' read -r id url start duration wav; do
import json, sys
for item in json.loads(sys.argv[1]):
    print("\t".join([
        str(item["id"]),
        str(item["sourceUrl"]),
        str(item.get("start", "00:00:00")),
        str(item.get("duration", 30)),
        str(item["wav"]),
    ]))
PY
  log "Downloading $id"
  tmp="${wav%.wav}.source.%(ext)s"
  yt-dlp --quiet --no-playlist --extract-audio --audio-format m4a \
    --output "$tmp" "$url"
  src="$(ls "${wav%.wav}.source."* | head -1)"
  ffmpeg -y -loglevel error -ss "$start" -t "$duration" \
    -i "$src" -ar 16000 -ac 1 -sample_fmt s16 "$wav"
  rm -f "$src"
done

python3 - "$MANIFEST" "$CORPUS_DIR" > "$OUT_MANIFEST" <<'PY'
import json, pathlib, subprocess, sys
manifest = pathlib.Path(sys.argv[1])
out = pathlib.Path(sys.argv[2])
items = json.loads(manifest.read_text())
clips = []
for item in items:
    wav = out / f"{str(item['id']).replace('/', '-')}.wav"
    if not wav.exists():
        continue
    duration = float(subprocess.check_output([
        "ffprobe", "-v", "quiet", "-show_entries", "format=duration",
        "-of", "csv=p=0", str(wav)
    ]).decode().strip())
    clips.append({
        "name": item["id"],
        "file": wav.name,
        "durationSeconds": duration,
        "sizeBytes": wav.stat().st_size,
        "sampleRate": 16000,
        "channels": 1,
        "bitDepth": 16,
        "kind": item.get("kind", "qa"),
        "license": item.get("license", ""),
        "notes": item.get("notes", ""),
        "expectedMarkers": item.get("expectedMarkers", []),
    })
print(json.dumps({
    "version": 2,
    "description": "Local YouTube eval audio manifest. WAV files are not committed.",
    "expectedCount": len(clips),
    "clips": clips,
}, indent=2))
PY

log "Wrote $OUT_MANIFEST"
find "$CORPUS_DIR" -maxdepth 1 -name "*.wav" -print
