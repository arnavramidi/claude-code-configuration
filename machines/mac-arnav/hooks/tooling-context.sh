#!/bin/bash
# tooling-context.sh — event-driven tooling context.
# Fires on PreToolUse:Skill (brainstorming / writing-plans) and PreToolUse:TodoWrite.
# CONTRACT: emits JSON additionalContext only (plain stdout never reaches the model);
# exits 0 on every path; never emits raw `claude mcp list` output (it contains API keys).
# Reports which servers are ALIVE. Deliberately does not map tools to job types —
# each server ships its own description, and a hand-maintained map goes stale.
# Health is cached PER WORKING DIRECTORY: project-scoped servers only exist inside
# their own project, so one shared cache would advertise tools that aren't reachable.
set -u
INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || exit 0
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || exit 0
SKILL=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // ""' 2>/dev/null) || exit 0
SESSION_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // ""' 2>/dev/null) || SESSION_CWD=""
[ -z "$SESSION_CWD" ] && SESSION_CWD="$PWD"

MARKER_DIR="${TMPDIR:-/tmp}/claude-hook-markers"
mkdir -p "$MARKER_DIR" 2>/dev/null
find "$MARKER_DIR" -type f -mtime +2 -delete 2>/dev/null

CACHE_DIR="$HOME/.claude/cache/mcp-health"
mkdir -p "$CACHE_DIR" 2>/dev/null
find "$CACHE_DIR" -type f -mtime +2 -delete 2>/dev/null
CACHE_KEY=$(printf '%s' "$SESSION_CWD" | shasum 2>/dev/null | cut -c1-12)
[ -z "$CACHE_KEY" ] && CACHE_KEY="default"
CACHE="$CACHE_DIR/$CACHE_KEY.txt"
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
    # Must run from the session's directory — project-scoped servers are only
    # visible from inside their own project.
    # Parse to name+status ONLY — raw output prints API keys in plaintext.
    # Strict allowlist (-n plus trailing /p): only fully-matching lines survive.
    # Greedy (.+) before ": " keeps colons inside plugin server names intact.
    ( cd "$SESSION_CWD" 2>/dev/null || cd "$HOME"
      claude mcp list 2>/dev/null \
        | sed -nE 's/^(.+): .+ - (✔|✘|!).*$/\1: \2/p' ) > "$CACHE.tmp" 2>/dev/null \
      && mv "$CACHE.tmp" "$CACHE"
    chmod 600 "$CACHE" 2>/dev/null
  fi
}

health_block() {
  if [ -s "$CACHE" ]; then
    printf 'Live tool-connection health in %s (✔ connected, ✘ failed, ! needs auth; cached ≤1h):\n%s\n\nThis reflects THIS directory only — project-scoped servers do not exist outside their own project.' \
      "$(basename "$SESSION_CWD")" "$(cat "$CACHE")"
  else
    printf 'Live tool-connection health: unavailable — do not assert any server is reachable without trying it.'
  fi
}

UI_RULE='If the work creates or reshapes UI, state whether you sourced patterns from a live tool or wrote from scratch, and why. Either answer is acceptable; silently skipping the question is not.'

case "$TOOL_NAME" in
  Skill)
    case "$SKILL" in
      superpowers:brainstorming|brainstorming)
        refresh_cache_if_stale
        emit "$(health_block)

Shape proposals around tools that are actually alive. Do not design an approach around a server marked ✘ or !.
$UI_RULE"
        ;;
      superpowers:writing-plans|writing-plans)
        refresh_cache_if_stale
        emit "$(health_block)

Per-task tool reconciliation: for each task, judge whether a live tool would make the result more accurate or better than working from memory. State which tool and why, or state 'no tools needed, because <reason>'. 'None needed' is a first-class valid answer — do not attach tool steps to tasks that do not benefit from them.
$UI_RULE"
        ;;
    esac
    ;;
  TodoWrite)
    MARKER="$MARKER_DIR/tooling-nudge-$SESSION_ID"
    if [ ! -f "$MARKER" ]; then
      touch "$MARKER" 2>/dev/null
      emit "First todo list this session: check the cached tool-health table for this directory before assuming a server is reachable, and verify external claims with live tools rather than memory."
    fi
    ;;
esac
exit 0
