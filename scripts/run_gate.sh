#!/usr/bin/env bash
# scripts/run_gate.sh — Helix native headless framework quality gate
# Usage: bash scripts/run_gate.sh
# Exit code 0 = all gates pass, 1 = at least one failure
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

pass() { printf "  ${GREEN}PASS${NC} %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${NC} %s\n" "$1"; }
info() { printf "  ${CYAN}INFO${NC} %s\n" "$1"; }

FAILURES=0
GATE_START=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

gate_start_time() { date +%s; }
gate_elapsed() {
  local start=$1
  local end
  end=$(date +%s)
  echo "$(( end - start ))s"
}

printf "\n${BOLD}========================================${NC}\n"
printf "${BOLD} Helix Native Headless Quality Gate${NC}\n"
printf "${BOLD}========================================${NC}\n"
printf " Started: %s\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"

printf "${BOLD}[1/4] Security Gate${NC}\n"
t=$(gate_start_time)
if bash scripts/security_gate.sh --repo; then
  pass "Security gate passed"
else
  fail "Security gate failed"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

printf "${BOLD}[2/4] Native Headless Boundary${NC}\n"
t=$(gate_start_time)
if grep -R "^[[:space:]]*import SwiftUI" NativeHelix/Sources --exclude-dir=.build >/dev/null 2>&1; then
  fail "SwiftUI import found under NativeHelix/Sources"
  grep -R "^[[:space:]]*import SwiftUI" NativeHelix/Sources --exclude-dir=.build || true
  FAILURES=$((FAILURES + 1))
else
  pass "No SwiftUI imports under NativeHelix/Sources"
fi

if [[ -d NativeHelix/Sources/HelixUI || -d NativeHelix/Sources/HelixApp ]]; then
  fail "UI/App targets are not allowed in the headless native package"
  FAILURES=$((FAILURES + 1))
else
  pass "No HelixUI or HelixApp source targets"
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

printf "${BOLD}[3/4] Native Swift Package${NC}\n"
t=$(gate_start_time)
if bash scripts/run_native_swift_gate.sh 2>&1; then
  pass "Native Swift package gate passed"
else
  fail "Native Swift package gate failed"
  FAILURES=$((FAILURES + 1))
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

printf "${BOLD}[4/4] Retired Eval Boundary${NC}\n"
t=$(gate_start_time)
if [[ "${HELIX_RUN_CONVERSATION_EVAL:-0}" = "1" ]]; then
  fail "HELIX_RUN_CONVERSATION_EVAL uses the retired conversation harness and is disabled for headless native work"
  FAILURES=$((FAILURES + 1))
else
  pass "Retired conversation eval is disabled by default"
fi
info "Elapsed: $(gate_elapsed "$t")"
echo ""

GATE_END=$(date +%s)
TOTAL_ELAPSED=$(( GATE_END - GATE_START ))

printf "${BOLD}========================================${NC}\n"
printf "${BOLD} Summary${NC}\n"
printf "${BOLD}========================================${NC}\n"
printf " Finished: %s\n" "$(date '+%Y-%m-%d %H:%M:%S')"
printf " Total runtime: %ds\n" "$TOTAL_ELAPSED"
echo ""

if [[ "$FAILURES" -eq 0 ]]; then
  printf "  ${GREEN}${BOLD}ALL GATES PASSED${NC}\n\n"
  exit 0
else
  printf "  ${RED}${BOLD}%d GATE(S) FAILED${NC}\n\n" "$FAILURES"
  exit 1
fi
