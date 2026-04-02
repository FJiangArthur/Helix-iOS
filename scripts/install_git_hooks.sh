#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

chmod +x .githooks/pre-commit .githooks/pre-push scripts/security_gate.sh
git config core.hooksPath .githooks

echo "Installed git hooks from .githooks"
