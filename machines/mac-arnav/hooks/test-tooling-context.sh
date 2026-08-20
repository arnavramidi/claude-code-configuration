#!/bin/bash
# Regression test for tooling-context.sh. Run: bash test-tooling-context.sh
set -u
H="$HOME/.claude/hooks/tooling-context.sh"
MD="${TMPDIR:-/tmp}/claude-hook-markers"
CACHE_DIR="$HOME/.claude/cache/mcp-health"
pass=0; fail=0

# Fixture caches are keyed on fake directory paths, so they can never collide with
# or overwrite a real project's cached health. Removed on exit.
DIR_A="/tmp/test-tooling-context-alpha"
DIR_B="/tmp/test-tooling-context-beta"
key() { printf '%s' "$1" | shasum | cut -c1-12; }
CACHE_A="$CACHE_DIR/$(key "$DIR_A").txt"
CACHE_B="$CACHE_DIR/$(key "$DIR_B").txt"
cleanup() { rm -f "$CACHE_A" "$CACHE_B"; }
trap cleanup EXIT

mkdir -p "$CACHE_DIR"
printf 'context7: ✔\nplugin:some-plugin:some-server: !\n' > "$CACHE_A"
printf 'patchright: ✔\n' > "$CACHE_B"
touch "$CACHE_A" "$CACHE_B"   # fresh mtime → no ~12s refresh
rm -f "$MD/tooling-nudge-testsess"

check() { # $1 desc, $2 expected-grep (empty = expect no output), $3 stdin
  out=$(printf '%s' "$3" | bash "$H")
  if [ -z "$2" ]; then
    [ -z "$out" ] && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1 (got: $out)"; fail=$((fail+1)); }
  else
    printf '%s' "$out" | grep -q "$2" && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null \
      && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1 (got: $out)"; fail=$((fail+1)); }
  fi
}
refute() { # $1 desc, $2 string that must NOT appear, $3 stdin
  out=$(printf '%s' "$3" | bash "$H")
  printf '%s' "$out" | grep -q "$2" && { echo "FAIL: $1 (leaked: $2)"; fail=$((fail+1)); } \
    || { echo "PASS: $1"; pass=$((pass+1)); }
}

BS_A="{\"session_id\":\"testsess\",\"cwd\":\"$DIR_A\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"superpowers:brainstorming\"}}"
BS_B="{\"session_id\":\"testsess\",\"cwd\":\"$DIR_B\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"superpowers:brainstorming\"}}"
WP_A="{\"session_id\":\"testsess\",\"cwd\":\"$DIR_A\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"superpowers:writing-plans\"}}"

check  "brainstorm trigger emits health"        "tool-connection health"  "$BS_A"
check  "brainstorm trigger carries UI rule"     "sourced patterns"        "$BS_A"
check  "health names the directory it reflects" "alpha"                   "$BS_A"
check  "plan trigger allows 'none needed'"      "no tools needed"         "$WP_A"
check  "plan trigger carries UI rule"           "sourced patterns"        "$WP_A"
check  "dir A shows dir A's servers"            "context7"                "$BS_A"
check  "dir B shows dir B's servers"            "patchright"              "$BS_B"
refute "dir B does NOT leak dir A's servers"    "context7"                "$BS_B"
refute "dir A does NOT leak dir B's servers"    "patchright"              "$BS_A"
check  "other skills emit nothing"              ""  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:systematic-debugging"}}'
check  "first TodoWrite nudges"                 "First todo list"  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check  "second TodoWrite is silent"             ""  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check  "malformed stdin exits silently"         ""  'this is not json'
echo "== $pass passed, $fail failed"; exit $fail
