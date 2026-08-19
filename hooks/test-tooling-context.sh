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

# Back up the live cache (if any) so this test run never poisons it, and
# restore it on any exit path — success, failure, or interrupt.
CACHE="$HOME/.claude/cache/mcp-health.txt"
CACHE_BACKUP=""
if [ -f "$CACHE" ]; then
  CACHE_BACKUP=$(mktemp "${TMPDIR:-/tmp}/mcp-health-backup.XXXXXX")
  cp -p "$CACHE" "$CACHE_BACKUP"
fi
restore_cache() {
  if [ -n "$CACHE_BACKUP" ] && [ -f "$CACHE_BACKUP" ]; then
    mv "$CACHE_BACKUP" "$CACHE"
    chmod 600 "$CACHE" 2>/dev/null
  elif [ -z "$CACHE_BACKUP" ]; then
    rm -f "$CACHE"
  fi
}
trap restore_cache EXIT INT TERM

# Seed a fake cache so tests never invoke the real 12s `claude mcp list`
mkdir -p "$HOME/.claude/cache"
printf 'context7: ✔\nchrome-devtools: ✔\n' > "$HOME/.claude/cache/mcp-health.txt"
chmod 600 "$HOME/.claude/cache/mcp-health.txt"
touch "$HOME/.claude/cache/mcp-health.txt"   # fresh mtime → no refresh
check "brainstorm trigger emits health" "MCP health" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:brainstorming"}}'
check "plan trigger emits reconciliation" "no MCPs needed" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
check "other skills emit nothing" "" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:systematic-debugging"}}'
check "first TodoWrite nudges" "First todo list" \
  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check "second TodoWrite is silent" "" \
  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check "malformed stdin exits silently" "" 'this is not json'
echo "== $pass passed, $fail failed"; exit $fail
