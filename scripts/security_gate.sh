#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---repo}"

case "$MODE" in
  --repo|--staged) ;;
  *)
    echo "Usage: bash scripts/security_gate.sh [--repo|--staged]" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

pass() { printf "  ${GREEN}PASS${NC} %s\n" "$1"; }
fail() { printf "  ${RED}FAIL${NC} %s\n" "$1"; }
info() { printf "  ${CYAN}INFO${NC} %s\n" "$1"; }

FAILURES=0

TEXT_FILE_PATTERN='\.(dart|swift|m|mm|h|json|ya?ml|md|sh|rb|py|txt|plist)$'
DISALLOWED_PATH_PATTERN='(^|/)(\.env(\.[^/]+)?|.*\.pem$|.*\.p8$|.*\.key$|.*\.mobileprovision$|GoogleService-Info\.plist$|firebase.*\.json$|ios/fastlane/api_key\.json$|llm_config\.local\.json$)'
SECRET_PATTERN='(sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{20,}|-----BEGIN (RSA|EC|OPENSSH|PRIVATE KEY)-----)'

read_mode_file() {
  local file="$1"
  if [[ "$MODE" == "--staged" ]]; then
    git show ":$file" 2>/dev/null || true
  else
    cat "$file" 2>/dev/null || true
  fi
}

content_matches() {
  local file="$1"
  local pattern="$2"
  read_mode_file "$file" | LC_ALL=C grep -nE "$pattern" || true
}

FILES=()
while IFS= read -r -d '' file; do
  FILES+=("$file")
done < <(
  if [[ "$MODE" == "--staged" ]]; then
    git diff --cached --name-only --diff-filter=ACMR -z
  else
    git ls-files -z
  fi
)

if [[ ${#FILES[@]} -eq 0 ]]; then
  info "No files in scope for $MODE scan"
  exit 0
fi

printf "\nSecurity gate (%s)\n" "$MODE"

# 1. Disallowed tracked/staged file paths.
path_hits=()
for file in "${FILES[@]}"; do
  if [[ "$file" =~ $DISALLOWED_PATH_PATTERN ]]; then
    path_hits+=("$file")
  fi
done

if [[ ${#path_hits[@]} -eq 0 ]]; then
  pass "No disallowed secret-bearing file paths in scope"
else
  fail "Disallowed secret-bearing file paths detected"
  printf '    %s\n' "${path_hits[@]}"
  FAILURES=$((FAILURES + 1))
fi

# 2. High-confidence secret content.
secret_hits=()
for file in "${FILES[@]}"; do
  if [[ ! "$file" =~ $TEXT_FILE_PATTERN ]]; then
    continue
  fi

  matches="$(content_matches "$file" "$SECRET_PATTERN")"
  if [[ -n "$matches" ]]; then
    secret_hits+=("$file")
    printf '%s\n' "$matches" | sed "s|^|    $file:|"
  fi
done

if [[ ${#secret_hits[@]} -eq 0 ]]; then
  pass "No high-confidence secret strings detected"
else
  fail "High-confidence secret strings detected"
  FAILURES=$((FAILURES + 1))
fi

# 3. Dart release logging policy.
dart_policy_file="lib/utils/app_logger.dart"
dart_policy_content="$(read_mode_file "$dart_policy_file")"
if grep -q 'HELIX_FORCE_SANITIZED_LOGS' <<<"$dart_policy_content" \
  && grep -q 'kReleaseMode' <<<"$dart_policy_content" \
  && grep -q 'Level.warning' <<<"$dart_policy_content"; then
  pass "Dart logger enforces sanitized release/TestFlight logging"
else
  fail "Dart logger policy is missing sanitized release/TestFlight enforcement"
  FAILURES=$((FAILURES + 1))
fi

# 4. Fastlane release gating.
fastlane_file="ios/fastlane/Fastfile"
fastlane_content="$(read_mode_file "$fastlane_file")"
if grep -q 'scripts/security_gate.sh' <<<"$fastlane_content" \
  && grep -q 'HELIX_FORCE_SANITIZED_LOGS=true' <<<"$fastlane_content"; then
  pass "Fastlane release flow enforces security gate and sanitized logging"
else
  fail "Fastlane release flow is missing security gate or sanitized logging define"
  FAILURES=$((FAILURES + 1))
fi

# 5. Sensitive log regressions.
declare -a RULES=(
  'lib/services/buzz/buzz_service.dart|Question:'
  'lib/services/buzz/buzz_search_service.dart|results for "\$query"'
  'lib/services/cloud_pipeline_service.dart|Raw response \(first 500 chars\):'
  'lib/services/cloud_pipeline_service.dart|Skipping duplicate fact: \$content'
  'lib/services/cloud_pipeline_service.dart|Failed to insert topic "\$label"'
  'lib/services/conversation_engine.dart|Progressive finalize:'
  'lib/services/conversation_engine.dart|STAR coaching triggered for:'
  'lib/services/conversation_engine.dart|\[FactCheck\] Correction:'
  'lib/services/facts/fact_service.dart|Search failed for "\$query"'
)

rule_hits=0
for rule in "${RULES[@]}"; do
  file="${rule%%|*}"
  pattern="${rule#*|}"

  in_scope=false
  if [[ "$MODE" == "--repo" ]]; then
    in_scope=true
  else
    for candidate in "${FILES[@]}"; do
      if [[ "$candidate" == "$file" ]]; then
        in_scope=true
        break
      fi
    done
  fi

  if [[ "$in_scope" == false ]]; then
    continue
  fi

  matches="$(content_matches "$file" "$pattern")"
  if [[ -n "$matches" ]]; then
    if [[ $rule_hits -eq 0 ]]; then
      fail "Sensitive Dart log regressions detected"
      FAILURES=$((FAILURES + 1))
    fi
    rule_hits=$((rule_hits + 1))
    printf '%s\n' "$matches" | sed "s|^|    $file:|"
  fi
done

if [[ $rule_hits -eq 0 ]]; then
  pass "Sensitive Dart log regressions not detected"
fi

# 6. Sensitive native log regressions.
declare -a NATIVE_RULES=(
  'ios/Runner/OpenAIRealtimeTranscriber.swift|\bprint\('
  'ios/Runner/OpenAIRealtimeTranscriber.swift|API error: \(errorMsg\)'
  'ios/Runner/WhisperBatchTranscriber.swift|\bprint\('
  'ios/Runner/WhisperBatchTranscriber.swift|transcript='
  'ios/Runner/WhisperBatchTranscriber.swift|HTTP .*: \$\(body\)'
)

native_hits=0
for rule in "${NATIVE_RULES[@]}"; do
  file="${rule%%|*}"
  pattern="${rule#*|}"

  in_scope=false
  if [[ "$MODE" == "--repo" ]]; then
    in_scope=true
  else
    for candidate in "${FILES[@]}"; do
      if [[ "$candidate" == "$file" ]]; then
        in_scope=true
        break
      fi
    done
  fi

  if [[ "$in_scope" == false ]]; then
    continue
  fi

  matches="$(content_matches "$file" "$pattern")"
  if [[ -n "$matches" ]]; then
    if [[ $native_hits -eq 0 ]]; then
      fail "Sensitive native log regressions detected"
      FAILURES=$((FAILURES + 1))
    fi
    native_hits=$((native_hits + 1))
    printf '%s\n' "$matches" | sed "s|^|    $file:|"
  fi
done

if [[ $native_hits -eq 0 ]]; then
  pass "Sensitive native log regressions not detected"
fi

if [[ "$FAILURES" -ne 0 ]]; then
  exit 1
fi
