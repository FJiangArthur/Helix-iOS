#!/usr/bin/env bash
# scripts/fetch_fonts.sh — download the Warm Linen variable fonts for the Android app.
#
# Pulls the upright variable TTFs for Fraunces and Inter (italics skipped, ~1.3 MB
# total) from the Google Fonts GitHub repo into android/app/src/main/res/font/,
# plus the matching SIL Open Font License texts into
# android/app/src/main/assets/licenses/ (OFL requires shipping the license).
#
# Usage: bash scripts/fetch_fonts.sh
# Idempotent: re-running overwrites the files. Prints sha256 for each download.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FONT_DIR="$PROJECT_ROOT/android/app/src/main/res/font"
LICENSE_DIR="$PROJECT_ROOT/android/app/src/main/assets/licenses"
BASE_URL="https://raw.githubusercontent.com/google/fonts/main/ofl"

mkdir -p "$FONT_DIR" "$LICENSE_DIR"

# name|remote path (URL-encoded)|local destination
DOWNLOADS=(
  "Fraunces variable TTF|fraunces/Fraunces%5BSOFT%2CWONK%2Copsz%2Cwght%5D.ttf|$FONT_DIR/fraunces_variable.ttf"
  "Inter variable TTF|inter/Inter%5Bopsz%2Cwght%5D.ttf|$FONT_DIR/inter_variable.ttf"
  "Fraunces OFL|fraunces/OFL.txt|$LICENSE_DIR/OFL-Fraunces.txt"
  "Inter OFL|inter/OFL.txt|$LICENSE_DIR/OFL-Inter.txt"
)

sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

for entry in "${DOWNLOADS[@]}"; do
  IFS='|' read -r label remote dest <<< "$entry"
  url="$BASE_URL/$remote"
  echo "Fetching $label"
  echo "  $url"
  tmp="$dest.part"
  curl -fL --retry 3 --retry-delay 2 -o "$tmp" "$url"
  mv "$tmp" "$dest"
  size=$(wc -c < "$dest" | tr -d ' ')
  echo "  -> $dest ($size bytes)"
  echo "  sha256 $(sha256_of "$dest")"
done

echo
echo "Font files:"
ls -la "$FONT_DIR"
echo "License files:"
ls -la "$LICENSE_DIR"
