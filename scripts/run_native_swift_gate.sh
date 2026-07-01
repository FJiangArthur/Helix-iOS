#!/usr/bin/env bash
# Native headless framework validation gate for the Helix rewrite.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_DIR="$PROJECT_ROOT/NativeHelix"

if [[ ! -f "$PACKAGE_DIR/Package.swift" ]]; then
  echo "FAIL NativeHelix/Package.swift not found" >&2
  exit 1
fi

echo "Native Helix headless framework gate"
echo "Package: $PACKAGE_DIR"
swift build --package-path "$PACKAGE_DIR" --target HelixRuntime
swift test --package-path "$PACKAGE_DIR"
