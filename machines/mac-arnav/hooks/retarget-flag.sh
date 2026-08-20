#!/bin/bash
# retarget-flag.sh — PostToolUse on Edit|Write.
# If the touched file is a test file, remind the model to flag retargeting explicitly.
# Exits 0 on every path.
set -u
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
case "$FILE" in
  *.test.*|*.spec.*|*__tests__*)
    jq -cn '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"Existing test modified — if expectations were rewritten to match new behavior, state that explicitly in the summary as a retargeted test, never folded into \"tests updated\"."}}' 2>/dev/null
    ;;
esac
exit 0
