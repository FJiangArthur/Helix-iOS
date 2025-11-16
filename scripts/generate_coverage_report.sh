#!/bin/bash
# Generate detailed coverage reports in multiple formats

set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "📊 Generating coverage reports..."

# Check if coverage file exists
if [ ! -f coverage/lcov.info ]; then
  echo "Running tests with coverage first..."
  ./scripts/run_tests_with_coverage.sh
fi

# Create reports directory
mkdir -p coverage/reports

# Generate HTML report
if command -v genhtml &> /dev/null; then
  echo -e "${BLUE}Generating HTML report...${NC}"
  genhtml coverage/lcov.info \
    --output-directory coverage/html \
    --title "Helix iOS Test Coverage" \
    --show-details \
    --legend \
    --branch-coverage \
    --function-coverage

  echo -e "${GREEN}✅ HTML report: coverage/html/index.html${NC}"
fi

# Generate detailed summary
if command -v lcov &> /dev/null; then
  echo -e "${BLUE}Generating detailed summary...${NC}"

  # Overall summary
  lcov --summary coverage/lcov.info > coverage/reports/summary.txt

  # Per-file coverage
  lcov --list coverage/lcov.info > coverage/reports/file_coverage.txt

  echo -e "${GREEN}✅ Summary reports generated${NC}"
fi

# Generate badge data
if command -v lcov &> /dev/null; then
  COVERAGE_PERCENT=$(lcov --summary coverage/lcov.info 2>&1 | grep -o '[0-9.]*%' | head -1 | sed 's/%//')

  # Determine badge color
  if (( $(echo "$COVERAGE_PERCENT >= 90" | bc -l) )); then
    COLOR="brightgreen"
  elif (( $(echo "$COVERAGE_PERCENT >= 75" | bc -l) )); then
    COLOR="green"
  elif (( $(echo "$COVERAGE_PERCENT >= 50" | bc -l) )); then
    COLOR="yellow"
  else
    COLOR="red"
  fi

  # Create badge JSON
  cat > coverage/reports/badge.json <<EOF
{
  "schemaVersion": 1,
  "label": "coverage",
  "message": "${COVERAGE_PERCENT}%",
  "color": "${COLOR}"
}
EOF

  echo -e "${GREEN}✅ Badge data: coverage/reports/badge.json${NC}"
fi

# Print summary
echo -e "\n${BLUE}Coverage Summary:${NC}"
cat coverage/reports/summary.txt

echo -e "\n${GREEN}✅ Coverage reports generated successfully${NC}"
echo "View HTML report: coverage/html/index.html"
