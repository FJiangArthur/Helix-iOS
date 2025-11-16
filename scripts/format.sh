#!/usr/bin/env bash
#
# Format all Dart code in the project using dart format
#
# Usage:
#   ./scripts/format.sh          # Format all Dart files
#   ./scripts/format.sh --check  # Check formatting without making changes
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Dart Code Formatter ===${NC}"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.." || exit 1

# Check if --check flag is provided
CHECK_ONLY=false
if [[ "$1" == "--check" ]]; then
  CHECK_ONLY=true
  echo -e "${YELLOW}Running in check mode (no files will be modified)${NC}"
  echo ""
fi

# Format Dart code
if [[ "$CHECK_ONLY" == true ]]; then
  echo "Checking Dart code formatting..."

  # dart format with --output=none and --set-exit-if-changed
  if dart format --output=none --set-exit-if-changed lib/ test/ 2>&1; then
    echo -e "${GREEN}✓ All Dart files are properly formatted${NC}"
    exit 0
  else
    echo -e "${RED}✗ Some Dart files need formatting${NC}"
    echo ""
    echo "Run './scripts/format.sh' to fix formatting issues"
    exit 1
  fi
else
  echo "Formatting Dart code..."

  # Format with line length of 120 (matching analysis_options.yaml)
  dart format --line-length=120 lib/ test/

  echo ""
  echo -e "${GREEN}✓ Dart code formatting complete${NC}"
fi
