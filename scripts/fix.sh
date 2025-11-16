#!/usr/bin/env bash
#
# Automatically fix formatting and linting issues
#
# Usage:
#   ./scripts/fix.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Auto-fix Code Issues ===${NC}"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.." || exit 1

# Step 1: Format code
echo -e "${YELLOW}Step 1: Formatting code...${NC}"
./scripts/format.sh
echo ""

# Step 2: Fix imports
echo -e "${YELLOW}Step 2: Organizing imports...${NC}"
echo "Running dart fix --apply..."
dart fix --apply lib/ test/ || true
echo -e "${GREEN}✓ Applied automated fixes${NC}"
echo ""

# Step 3: Run analyzer to check remaining issues
echo -e "${YELLOW}Step 3: Checking for remaining issues...${NC}"
if flutter analyze; then
  echo ""
  echo -e "${GREEN}✓ All auto-fixable issues have been resolved!${NC}"
  echo ""
  echo "Your code is now properly formatted and passes all linting rules."
else
  echo ""
  echo -e "${YELLOW}⚠ Some issues require manual fixing${NC}"
  echo ""
  echo "Please review the analyzer output above and fix any remaining issues manually."
  exit 1
fi
