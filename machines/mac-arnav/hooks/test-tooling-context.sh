#!/bin/bash
# Regression test for tooling-context.sh. Run: bash test-tooling-context.sh
set -u
H="$HOME/.claude/hooks/tooling-context.sh"
MD="${TMPDIR:-/tmp}/claude-hook-markers"
pass=0; fail=0
check() { # $1 desc, $2 expected-grep (empty means expect no output), $3 stdin
  out=$(printf '%s' "$3" | bash "$H")
  if [ -z "$2" ]; then
    [ -z "$out" ] && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1 (got: $out)"; fail=$((fail+1)); }
  else
    printf '%s' "$out" | grep -q "$2" && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null \
      && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1 (got: $out)"; fail=$((fail+1)); }
  fi
}
rm -f "$MD/tooling-nudge-testsess"
# Seed a fake cache so tests never invoke the real ~12s `claude mcp list`.
# The real cache is saved first and restored on exit — a test run must never
# leave fixture data where a real session would read it as live tool health.
CACHE="$HOME/.claude/cache/mcp-health.txt"
mkdir -p "$HOME/.claude/cache"
SAVED=""
if [ -f "$CACHE" ]; then SAVED=$(mktemp); cp -p "$CACHE" "$SAVED"; fi
restore_cache() {
  if [ -n "$SAVED" ]; then cp -p "$SAVED" "$CACHE"; rm -f "$SAVED"; else rm -f "$CACHE"; fi
}
trap restore_cache EXIT
printf 'context7: ✔\nplugin:some-plugin:some-server: !\n' > "$CACHE"
touch "$CACHE"   # fresh mtime → no refresh
check "brainstorm trigger emits health" "tool-connection health" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:brainstorming"}}'
check "brainstorm trigger carries UI rule" "sourced patterns" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:brainstorming"}}'
check "plan trigger allows 'none needed'" "no tools needed" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
check "plan trigger carries UI rule" "sourced patterns" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
check "other skills emit nothing" "" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:systematic-debugging"}}'
check "first TodoWrite nudges" "First todo list" \
  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check "second TodoWrite is silent" "" \
  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check "malformed stdin exits silently" "" 'this is not json'
echo "== $pass passed, $fail failed"; exit $fail
