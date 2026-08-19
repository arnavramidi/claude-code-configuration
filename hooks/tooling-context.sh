#!/bin/bash
# tooling-context.sh — event-driven tooling context (spec Section 1, rev 2).
# Fires on PreToolUse:Skill (brainstorming / writing-plans) and PreToolUse:TodoWrite.
# CONTRACT: emits JSON additionalContext only (plain stdout never reaches the model);
# exits 0 on every path; never emits raw `claude mcp list` output (it contains API keys).
set -u
INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || exit 0
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || exit 0
SKILL=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // ""' 2>/dev/null) || exit 0

MARKER_DIR="${TMPDIR:-/tmp}/claude-hook-markers"
mkdir -p "$MARKER_DIR" 2>/dev/null
find "$MARKER_DIR" -type f -mtime +2 -delete 2>/dev/null

CACHE="$HOME/.claude/cache/mcp-health.txt"
CACHE_TTL=3600

emit() {
  jq -cn --arg ctx "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}' 2>/dev/null
  exit 0
}

refresh_cache_if_stale() {
  local now mtime age=999999
  now=$(date +%s)
  [ -f "$CACHE" ] && mtime=$(stat -f %m "$CACHE" 2>/dev/null) && age=$((now - mtime))
  if [ "$age" -ge "$CACHE_TTL" ]; then
    mkdir -p "$(dirname "$CACHE")" 2>/dev/null
    # Parse to name+status ONLY — the raw output prints API keys in plaintext.
    # -n plus a trailing /p means only lines that fully match are ever printed;
    # anything that doesn't match (blank lines, banner text, malformed rows) is
    # dropped, never passed through unmodified.
    claude mcp list 2>/dev/null \
      | sed -nE 's/^(.*): .* - (✔|✘|!).*$/\1: \2/p' > "$CACHE.tmp" 2>/dev/null \
      && mv "$CACHE.tmp" "$CACHE"
    chmod 600 "$CACHE" 2>/dev/null
  fi
}

health_block() {
  if [ -s "$CACHE" ]; then
    printf 'Live MCP health (✔ connected, ✘ failed, ! needs auth; cached ≤1h):\n%s' "$(cat "$CACHE")"
  else
    printf 'Live MCP health: unavailable — do not assert any MCP is reachable without trying it.'
  fi
}

case "$TOOL_NAME" in
  Skill)
    case "$SKILL" in
      superpowers:brainstorming|brainstorming)
        refresh_cache_if_stale
        emit "$(health_block)

Shape proposals around tools that are actually alive. Do not design an approach around a server marked ✘ or !."
        ;;
      superpowers:writing-plans|writing-plans)
        refresh_cache_if_stale
        emit "$(health_block)

Per-task tool reconciliation: for each task, state which live tool verifies it — context7 for library APIs, a browser for rendered UI, the project's real database for data claims — or state 'no MCPs needed, because <reason>'. That is a first-class valid answer; do not attach tool steps to tasks that do not need them."
        ;;
    esac
    ;;
  TodoWrite)
    MARKER="$MARKER_DIR/tooling-nudge-$SESSION_ID"
    if [ ! -f "$MARKER" ]; then
      touch "$MARKER" 2>/dev/null
      emit "First todo list this session: if any task assumes an MCP, check the cached health table at ~/.claude/cache/mcp-health.txt before relying on it, and verify external claims with live tools rather than memory."
    fi
    ;;
esac
exit 0
