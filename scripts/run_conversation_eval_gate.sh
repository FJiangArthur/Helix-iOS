#!/usr/bin/env bash
# Legacy Flutter conversation-quality eval gate.
#
# The Swift-native rewrite validates conversation behavior through
# NativeHelix package tests and the native eval report harness. This script is
# intentionally retained only as a guardrail so older automation fails loudly
# instead of rebuilding the retired Flutter shell.

set -euo pipefail

fail() { printf "  \033[0;31mFAIL\033[0m %s\n" "$1" >&2; }
info() { printf "  \033[0;36mINFO\033[0m %s\n" "$1"; }

fail "The Flutter conversation eval harness is retired for the Swift-native rewrite."
info "Run the mandatory native gate instead:"
printf "  bash scripts/run_gate.sh\n"
info "For the opt-in live OpenAI smoke test:"
printf "  HELIX_RUN_LIVE_OPENAI_EVAL=1 OPENAI_API_KEY=... swift test --package-path NativeHelix --filter NativeConversationTests/testLiveOpenAIAnswerProviderWithEnvironmentKeyWhenRequested\n"

exit 1
