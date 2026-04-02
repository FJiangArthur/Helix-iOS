#!/usr/bin/env bash
# scripts/run_gate.sh — Helix-iOS Pre-Release Quality Gate
# Usage: bash scripts/run_gate.sh
# Exit code 0 = all gates pass, 1 = at least one failure
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MIN_COVERAGE=60
MAX_CRITICAL_TODOS=5
CRITICAL_FILES=(
  "lib/services/conversation_engine.dart"
  "lib/services/conversation_listening_session.dart"
  "lib/services/recording_coordinator.dart"
)

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

pass() { printf "  ${GREEN}PASS${NC} %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${NC} %s\n" "$1"; }
info() { printf "  ${CYAN}INFO${NC} %s\n" "$1"; }

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
FAILURES=0
GATE_START=$(date +%s)

gate_start_time() { date +%s; }
gate_elapsed() {
  local start=$1
  local end
  end=$(date +%s)
  echo "$(( end - start ))s"
}

# ---------------------------------------------------------------------------
# Ensure we are in the project root
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

printf "\n${BOLD}========================================${NC}\n"
printf "${BOLD} Helix-iOS Pre-Release Quality Gate${NC}\n"
printf "${BOLD}========================================${NC}\n"
printf " Started: %s\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"

# ===== Gate 1: Security =====
printf "${BOLD}[1/7] Security Gate${NC}\n"
t=$(gate_start_time)
if bash scripts/security_gate.sh --repo; then
  pass "Security gate passed"
else
  fail "Security gate failed"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

# ===== Gate 2: Static Analysis =====
printf "${BOLD}[2/7] Static Analysis${NC}\n"
t=$(gate_start_time)
ANALYZE_OUTPUT=$(flutter analyze --no-fatal-infos 2>&1) || true
ANALYZE_ERRORS=$(echo "$ANALYZE_OUTPUT" | grep -c "error •" || true)

if [ "$ANALYZE_ERRORS" -eq 0 ]; then
  pass "flutter analyze — 0 errors"
else
  fail "flutter analyze — $ANALYZE_ERRORS error(s) found"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

# ===== Gate 3: Unit Tests =====
printf "${BOLD}[3/7] Unit Tests${NC}\n"
t=$(gate_start_time)
if flutter test test/ --reporter expanded 2>&1; then
  pass "All unit tests passed"
else
  fail "Unit tests had failures"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

# ===== Gate 4: Test Coverage =====
printf "${BOLD}[4/7] Test Coverage (>= ${MIN_COVERAGE}%%)${NC}\n"
t=$(gate_start_time)
if flutter test --coverage test/ 2>&1; then
  if command -v lcov &>/dev/null; then
    COVERAGE_SUMMARY=$(lcov --summary coverage/lcov.info 2>&1 || true)
    COVERAGE_PCT=$(echo "$COVERAGE_SUMMARY" | grep -oP 'lines\.*:\s*\K[0-9]+(\.[0-9]+)?' || echo "0")
    # Handle case where grep returns nothing
    if [ -z "$COVERAGE_PCT" ]; then
      COVERAGE_PCT="0"
    fi
    COVERAGE_INT=${COVERAGE_PCT%.*}
    if [ "$COVERAGE_INT" -ge "$MIN_COVERAGE" ]; then
      pass "Line coverage: ${COVERAGE_PCT}% (threshold: ${MIN_COVERAGE}%)"
    else
      fail "Line coverage: ${COVERAGE_PCT}% (below threshold: ${MIN_COVERAGE}%)"
      FAILURES=$((FAILURES + 1))
    fi
  else
    info "lcov not installed — skipping coverage percentage check"
    info "Install with: brew install lcov"
    pass "Coverage data generated at coverage/lcov.info (manual review needed)"
  fi
else
  fail "Coverage test run failed"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

# ===== Gate 5: iOS Simulator Build =====
printf "${BOLD}[5/7] iOS Simulator Build${NC}\n"
t=$(gate_start_time)
if flutter build ios --simulator --no-codesign 2>&1; then
  pass "iOS simulator build succeeded"
else
  fail "iOS simulator build failed"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

# ===== Gate 6: Critical TODOs =====
printf "${BOLD}[6/7] Critical TODOs (threshold: ${MAX_CRITICAL_TODOS})${NC}\n"
t=$(gate_start_time)
TODO_COUNT=0
for f in "${CRITICAL_FILES[@]}"; do
  if [ -f "$f" ]; then
    FILE_TODOS=$(grep -c "TODO" "$f" 2>/dev/null || true)
    TODO_COUNT=$((TODO_COUNT + FILE_TODOS))
    if [ "$FILE_TODOS" -gt 0 ]; then
      info "$f — $FILE_TODOS TODO(s)"
    fi
  else
    info "$f — file not found (skipped)"
  fi
done

if [ "$TODO_COUNT" -le "$MAX_CRITICAL_TODOS" ]; then
  pass "Critical TODOs: $TODO_COUNT (threshold: $MAX_CRITICAL_TODOS)"
else
  fail "Critical TODOs: $TODO_COUNT (exceeds threshold: $MAX_CRITICAL_TODOS)"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

# ===== Gate 7: Analyzer Warnings (threshold: 10) =====
MAX_WARNINGS=10
printf "${BOLD}[7/7] Analyzer Warnings (threshold: ${MAX_WARNINGS})${NC}\n"
t=$(gate_start_time)
ANALYZE_WARNINGS=$(echo "$ANALYZE_OUTPUT" | grep -c "warning •" || true)
ANALYZE_INFOS=$(echo "$ANALYZE_OUTPUT" | grep -c "info •" || true)
if [ "$ANALYZE_WARNINGS" -le "$MAX_WARNINGS" ]; then
  pass "$ANALYZE_WARNINGS warning(s), $ANALYZE_INFOS info(s) (warning threshold: $MAX_WARNINGS)"
else
  fail "$ANALYZE_WARNINGS warning(s) exceeds threshold of $MAX_WARNINGS"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
GATE_END=$(date +%s)
TOTAL_ELAPSED=$(( GATE_END - GATE_START ))

printf "${BOLD}========================================${NC}\n"
printf "${BOLD} Summary${NC}\n"
printf "${BOLD}========================================${NC}\n"
printf " Finished: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
printf " Total runtime: %ds\n" "$TOTAL_ELAPSED"
echo ""

if [ "$FAILURES" -eq 0 ]; then
  printf "  ${GREEN}${BOLD}ALL GATES PASSED${NC}\n\n"
  exit 0
else
  printf "  ${RED}${BOLD}%d GATE(S) FAILED${NC}\n\n" "$FAILURES"
  exit 1
fi
