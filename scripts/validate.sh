#!/usr/bin/env bash
#
# Comprehensive validation script for CI/CD
# Checks formatting, linting, and runs tests
#
# Usage:
#   ./scripts/validate.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Code Quality Validation Suite        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Navigate to project root
cd "$(dirname "$0")/.." || exit 1

# Track overall success
ALL_CHECKS_PASSED=true

# Step 1: Check code formatting
echo -e "${BLUE}[1/4] Checking code formatting...${NC}"
if ./scripts/format.sh --check; then
  echo -e "${GREEN}✓ Formatting check passed${NC}"
else
  echo -e "${RED}✗ Formatting check failed${NC}"
  ALL_CHECKS_PASSED=false
fi
echo ""

# Step 2: Run linter
echo -e "${BLUE}[2/4] Running linter (strict mode)...${NC}"
if ./scripts/lint.sh --strict; then
  echo -e "${GREEN}✓ Linting passed${NC}"
else
  echo -e "${RED}✗ Linting failed${NC}"
  ALL_CHECKS_PASSED=false
fi
echo ""

# Step 3: Check for outdated dependencies
echo -e "${BLUE}[3/4] Checking dependencies...${NC}"
if flutter pub outdated --exit-if-newer; then
  echo -e "${GREEN}✓ All dependencies are up to date${NC}"
else
  echo -e "${YELLOW}⚠ Some dependencies have newer versions available${NC}"
  echo "  (This is a warning only, not failing the build)"
fi
echo ""

# Step 4: Run tests
echo -e "${BLUE}[4/4] Running tests...${NC}"
if flutter test; then
  echo -e "${GREEN}✓ All tests passed${NC}"
else
  echo -e "${RED}✗ Tests failed${NC}"
  ALL_CHECKS_PASSED=false
fi
echo ""

# Final summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
if [[ "$ALL_CHECKS_PASSED" == true ]]; then
  echo -e "${GREEN}║  ✓ ALL VALIDATION CHECKS PASSED       ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
  exit 0
else
  echo -e "${RED}║  ✗ VALIDATION FAILED                   ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Please fix the issues above and run './scripts/validate.sh' again${NC}"
  exit 1
fi
