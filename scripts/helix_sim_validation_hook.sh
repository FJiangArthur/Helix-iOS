#!/bin/bash
# helix_sim_validation_hook.sh
# PostToolUse hook: reminds to run validation when lib/ or ios/ files change
set -euo pipefail

INPUT=$(cat)

# Extract file path from tool input (handles Write, Edit, NotebookEdit)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check if the changed file is in lib/ or ios/
if echo "$FILE_PATH" | grep -qE '(lib/|ios/)'; then
  cat <<HOOK_EOF
{
  "systemMessage": "Code change detected in validated path (lib/ or ios/). Before completing this task: (1) Run 'bash scripts/run_gate.sh' for code quality gates. (2) Invoke the ios-sim-validation skill for the full 6-gate simulator validation protocol. See docs/SIMULATOR_VALIDATION_PROTOCOL.md for details."
}
HOOK_EOF
fi

exit 0
