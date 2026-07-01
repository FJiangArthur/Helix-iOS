#!/bin/bash
# helix_sim_validation_hook.sh
# PostToolUse hook: reminds to run validation when NativeHelix or iOS files change
set -euo pipefail

INPUT=$(cat)

# Extract file path from tool input (handles Write, Edit, NotebookEdit)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check if the changed file is in NativeHelix/ or ios/
if echo "$FILE_PATH" | grep -qE '(NativeHelix/|ios/)'; then
  cat <<HOOK_EOF
{
  "systemMessage": "Code change detected in validated path (NativeHelix/ or ios/). Before completing this task: (1) Run 'bash scripts/run_gate.sh'. (2) Build, install, launch, and screenshot a dedicated Helix-QA iOS simulator when app UI/runtime behavior changed. See docs/SIMULATOR_VALIDATION_PROTOCOL.md for details."
}
HOOK_EOF
fi

exit 0
