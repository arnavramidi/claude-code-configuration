#!/bin/bash
# PreToolUse hook for the Task tool — fires before every subagent dispatch.
# Reads the tool input from stdin (JSON) and emits structured JSON output
# that adds context to the dispatching (parent) agent.

# Drain stdin so the parent process doesn't block.
input=$(cat)

cat <<'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "[Subagent dispatch audit]\n\nMCP ACCESS: Generic subagents (general-purpose, claude) have NO access to mcp__magic__*, mcp__context7__*, mcp__chrome-devtools__*, mcp__claude-in-chrome__*, mcp__postgres__*, mcp__github__*, mcp__sentry__*, mcp__vercel__*, mcp__linear__*, mcp__supabase__*, or mcp__brave-search__*. The user-level subagents (frontend-implementer, frontend-reviewer, backend-implementer, code-reviewer) DO have explicit MCP grants — prefer them.\n\nFor any Task dispatch where MCP content is relevant, verify the prompt contains: (1) actual component code from a Magic pull, not a description; (2) version-pinned API signatures from context7, not training-data guesses; (3) real DB schema/sample rows from mcp__postgres__* if data is involved; (4) explicit acceptance criteria the subagent can verify without browsing. If MCP content is NOT relevant to the task, skip it — don't force MCP use for tasks that don't need it.\n\nMODEL TIERING (Arnav's rule, 2026-05-28):\n- model: haiku → tasks Haiku can finish easily: mechanical edits, scaffolding, single-file changes with clear specs, renames, simple refactors, well-bounded test writing.\n- model: sonnet → tasks that would stress Haiku in any way: multi-file edits, moderate reasoning, library API integration, non-trivial tests, debugging with a clear hypothesis.\n- model: opus → tasks that present any difficulty even to Sonnet: ambiguous specs, deep debugging, cross-cutting refactors, code review of complex changes, architectural decisions.\nBias UP not down when uncertain. Reviewer subagents stay on opus by default. State the tier choice and one-line reason in the dispatch announcement."
  }
}
EOF

exit 0
