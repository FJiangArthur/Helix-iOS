#!/bin/bash

# Pre-commit Security Check
# Lightweight security checks to run before committing code

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Running pre-commit security checks...${NC}"

FAILED=0

# Get staged files
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.dart$" || true)

if [ -z "$STAGED_DART_FILES" ]; then
    echo -e "${GREEN}✓${NC} No Dart files to check"
    exit 0
fi

# Check 1: Scan for potential secrets
echo -n "Checking for hardcoded secrets... "
if echo "$STAGED_DART_FILES" | xargs grep -EHni "api[_-]?key|password|secret|token|private[_-]?key" | grep -v "// NOSONAR\|// nosec" >/dev/null 2>&1; then
    echo -e "${RED}✗ FAILED${NC}"
    echo -e "${YELLOW}Warning: Potential secrets found in staged files:${NC}"
    echo "$STAGED_DART_FILES" | xargs grep -EHni "api[_-]?key|password|secret|token|private[_-]?key" | grep -v "// NOSONAR\|// nosec" || true
    echo ""
    echo -e "${YELLOW}If these are not actual secrets, add a comment: // nosec${NC}"
    FAILED=1
else
    echo -e "${GREEN}✓${NC}"
fi

# Check 2: Look for debug statements
echo -n "Checking for debug statements... "
if echo "$STAGED_DART_FILES" | xargs grep -Hn "^\s*print(\|debugPrint(" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo -e "${YELLOW}Debug statements found (consider removing for production):${NC}"
    echo "$STAGED_DART_FILES" | xargs grep -Hn "^\s*print(\|debugPrint(" || true
    # This is a warning, not a failure
else
    echo -e "${GREEN}✓${NC}"
fi

# Check 3: Look for insecure HTTP URLs
echo -n "Checking for insecure HTTP URLs... "
if echo "$STAGED_DART_FILES" | xargs grep -Hn "http://" | grep -v "localhost\|127.0.0.1\|///" >/dev/null 2>&1; then
    echo -e "${RED}✗ FAILED${NC}"
    echo -e "${YELLOW}Insecure HTTP URLs found (use HTTPS):${NC}"
    echo "$STAGED_DART_FILES" | xargs grep -Hn "http://" | grep -v "localhost\|127.0.0.1\|///" || true
    FAILED=1
else
    echo -e "${GREEN}✓${NC}"
fi

# Check 4: Look for potential SQL injection
echo -n "Checking for potential SQL injection... "
if echo "$STAGED_DART_FILES" | xargs grep -Hn "SELECT.*\+\|INSERT.*\+\|UPDATE.*\+\|DELETE.*\+" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo -e "${YELLOW}Potential SQL concatenation found (use parameterized queries):${NC}"
    echo "$STAGED_DART_FILES" | xargs grep -Hn "SELECT.*\+\|INSERT.*\+\|UPDATE.*\+\|DELETE.*\+" || true
    # This is a warning, not a failure
else
    echo -e "${GREEN}✓${NC}"
fi

# Check 5: Look for insecure random number generation
echo -n "Checking for weak random number generation... "
if echo "$STAGED_DART_FILES" | xargs grep -Hn "Random()" >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ WARNING${NC}"
    echo -e "${YELLOW}Potentially weak random number generation (consider Random.secure()):${NC}"
    echo "$STAGED_DART_FILES" | xargs grep -Hn "Random()" || true
    # This is a warning, not a failure
else
    echo -e "${GREEN}✓${NC}"
fi

echo ""

if [ $FAILED -ne 0 ]; then
    echo -e "${RED}Pre-commit security checks failed!${NC}"
    echo -e "${YELLOW}Please fix the issues above or use 'git commit --no-verify' to skip checks.${NC}"
    exit 1
else
    echo -e "${GREEN}All pre-commit security checks passed!${NC}"
    exit 0
fi
