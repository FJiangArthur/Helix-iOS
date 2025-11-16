#!/bin/bash
# Check test coverage against minimum threshold

set -e

# Configuration
MIN_COVERAGE=80  # Minimum coverage percentage required
COVERAGE_FILE="coverage/lcov.info"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "📊 Checking test coverage..."

# Check if coverage file exists
if [ ! -f "$COVERAGE_FILE" ]; then
  echo -e "${RED}❌ Coverage file not found: $COVERAGE_FILE${NC}"
  echo "Run './scripts/run_tests_with_coverage.sh' first"
  exit 1
fi

# Check if lcov is installed
if ! command -v lcov &> /dev/null; then
  echo -e "${YELLOW}⚠️  lcov not installed. Cannot calculate coverage percentage.${NC}"
  echo "Install lcov to enable coverage checks:"
  echo "  macOS: brew install lcov"
  echo "  Linux: sudo apt-get install lcov"
  exit 0
fi

# Calculate coverage percentage
COVERAGE_SUMMARY=$(lcov --summary "$COVERAGE_FILE" 2>&1)
COVERAGE_PERCENT=$(echo "$COVERAGE_SUMMARY" | grep -o '[0-9.]*%' | head -1 | sed 's/%//')

echo -e "\nCurrent coverage: ${YELLOW}${COVERAGE_PERCENT}%${NC}"
echo -e "Minimum required: ${YELLOW}${MIN_COVERAGE}%${NC}\n"

# Compare coverage with minimum
if (( $(echo "$COVERAGE_PERCENT >= $MIN_COVERAGE" | bc -l) )); then
  echo -e "${GREEN}✅ Coverage meets minimum requirement${NC}"
  exit 0
else
  echo -e "${RED}❌ Coverage below minimum requirement${NC}"
  echo -e "${RED}   Missing: $(echo "$MIN_COVERAGE - $COVERAGE_PERCENT" | bc)%${NC}"

  # Show uncovered files
  echo -e "\n${YELLOW}Files with low coverage:${NC}"
  lcov --list "$COVERAGE_FILE" | grep -v "100.0%" | head -20

  exit 1
fi
