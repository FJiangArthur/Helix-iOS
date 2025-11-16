#!/usr/bin/env bash
#
# Run Dart/Flutter analyzer to check for linting errors
#
# Usage:
#   ./scripts/lint.sh           # Run analyzer with standard output
#   ./scripts/lint.sh --strict  # Treat warnings as errors (CI mode)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Dart/Flutter Analyzer ===${NC}"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.." || exit 1

# Check if --strict flag is provided
STRICT_MODE=false
if [[ "$1" == "--strict" ]]; then
  STRICT_MODE=true
  echo -e "${YELLOW}Running in strict mode (warnings treated as errors)${NC}"
  echo ""
fi

# Run Flutter analyzer
echo "Analyzing Dart code..."
echo ""

if [[ "$STRICT_MODE" == true ]]; then
  # In strict mode, fail on warnings
  if flutter analyze --fatal-infos --fatal-warnings; then
    echo ""
    echo -e "${GREEN}✓ No issues found${NC}"
    exit 0
  else
    echo ""
    echo -e "${RED}✗ Analyzer found issues${NC}"
    exit 1
  fi
else
  # Normal mode - only fail on errors
  if flutter analyze; then
    echo ""
    echo -e "${GREEN}✓ Analysis complete${NC}"
    exit 0
  else
    echo ""
    echo -e "${RED}✗ Analyzer found errors${NC}"
    exit 1
  fi
fi
