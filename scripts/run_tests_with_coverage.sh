#!/bin/bash
# Run tests with coverage reporting

set -e

echo "🧪 Running tests with coverage..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Clean previous coverage data
echo -e "${BLUE}Cleaning previous coverage data...${NC}"
rm -rf coverage/
mkdir -p coverage

# Run unit tests with coverage
echo -e "${BLUE}Running unit tests...${NC}"
flutter test \
  --coverage \
  --coverage-path=coverage/lcov.info \
  --reporter expanded

# Check if coverage was generated
if [ ! -f coverage/lcov.info ]; then
  echo "❌ Coverage file not generated"
  exit 1
fi

echo -e "${GREEN}✅ Tests completed with coverage${NC}"

# Generate HTML coverage report if genhtml is available
if command -v genhtml &> /dev/null; then
  echo -e "${BLUE}Generating HTML coverage report...${NC}"
  genhtml coverage/lcov.info \
    --output-directory coverage/html \
    --title "Helix iOS Coverage" \
    --show-details \
    --legend

  echo -e "${GREEN}✅ HTML coverage report generated at coverage/html/index.html${NC}"

  # Open coverage report if on macOS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    open coverage/html/index.html
  fi
else
  echo "ℹ️  genhtml not found. Install lcov to generate HTML reports:"
  echo "   macOS: brew install lcov"
  echo "   Linux: sudo apt-get install lcov"
fi

# Display coverage summary if lcov is available
if command -v lcov &> /dev/null; then
  echo -e "${BLUE}Coverage Summary:${NC}"
  lcov --summary coverage/lcov.info
fi

echo -e "${GREEN}✅ Coverage analysis complete${NC}"
