#!/bin/bash
# Regression test for retarget-flag.sh. Run: bash test-retarget-flag.sh
set -u
H="$HOME/.claude/hooks/retarget-flag.sh"
pass=0; fail=0
check() {
  out=$(printf '%s' "$3" | bash "$H")
  if [ -z "$2" ]; then
    [ -z "$out" ] && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1"; fail=$((fail+1)); }
  else
    printf '%s' "$out" | grep -q "$2" && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1"; fail=$((fail+1)); }
  fi
}
check "flags .spec.ts edit" "retargeted test" '{"tool_name":"Edit","tool_input":{"file_path":"/x/app/queue.spec.ts"}}'
check "flags __tests__ write" "retargeted test" '{"tool_name":"Write","tool_input":{"file_path":"/x/__tests__/queue.tsx"}}'
check "ignores source file" "" '{"tool_name":"Edit","tool_input":{"file_path":"/x/app/queue.ts"}}'
check "malformed stdin silent" "" 'not json'
echo "== $pass passed, $fail failed"; exit $fail
