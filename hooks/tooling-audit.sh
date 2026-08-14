#!/bin/bash
# UserPromptSubmit hook — fires on every user turn at user scope.
# Stdout is appended to the prompt as additional context.

cat <<'EOF'

[Tooling audit — applies to this turn]
Before producing code or a plan, decide which of these MUST be used and STATE which you're using and why:

UI / component work:
  - mcp__magic__21st_magic_component_builder or _inspiration → pull a real 21st.dev pattern. Do NOT write JSX from scratch.
  - frontend-design skill → for layout/aesthetic principles after you have a pattern.
  - mcp__chrome-devtools__take_screenshot + list_console_messages → verify after implementing. Iterate until clean.

Library APIs (Next 16, Prisma 7, Tailwind v4, react-player v3, React 19, etc.):
  - mcp__context7__resolve-library-id then get-library-docs → pinned to package.json version. Training data is suspect for breaking-change versions.

Browser automation / verification:
  - mcp__claude-in-chrome__* → drive my existing tab group (preferred — does not spawn new browsers).
  - mcp__playwright__* → only for headless E2E suites.

Backend / data:
  - mcp__postgres__* → read queries, schema inspection.
  - mcp__github__* → PR/issue ops, code search across repos.
  - mcp__sentry__* → correlate code changes with production errors.
  - mcp__vercel__* → build/deploy state.
  - mcp__linear__* → task ops.
  - mcp__supabase__* → auth/storage if applicable.

Complex features (touching >3 files):
  - superpowers:brainstorming → Q&A spec doc first.
  - superpowers:writing-plans → turn the spec into a task plan.
  - superpowers:subagent-driven-development → dispatch per-task subagents with two-stage review.

Subagent dispatch:
  - Subagents have NO MCP access by default. Inline real component code, real API signatures, and real data — never tell a subagent "look up X."
  - Prefer user-level subagents in ~/.claude/agents/ (frontend-implementer, frontend-reviewer, backend-implementer, code-reviewer) which DO have explicit MCP grants.

If any tool is skipped without a stated reason, the output is mediocre by definition. Do not skip silently.
EOF

exit 0
