#!/bin/bash
# UserPromptSubmit hook — fires on every user turn at user scope.
# Stdout is appended to the prompt as additional context.
# Purpose: force the karpathy-guidelines skill + plain-language rule into
# view whenever a turn involves code, so they aren't silently skipped.

cat <<'EOF'

[Coding discipline — applies to this turn]
If this turn involves WRITING, REVIEWING, or REFACTORING code (Edit/Write to source,
a code-change plan, debugging a failure), then BEFORE producing code or a plan:
  1. Invoke the andrej-karpathy-skills:karpathy-guidelines skill (via the Skill tool)
     and treat its points as a checklist: surgical changes, surface assumptions,
     avoid overcomplication, define verifiable success criteria.
  2. Explain in Arnav's plain-language style (his CLAUDE.md rule): lead every decision
     with what actually happens / what it buys / what it costs. Never open with a raw
     code identifier, never drop an undefined internal term, never let a jargon-chain
     stand in for an explanation.

If the turn is purely conversational (no code, no plan, no debugging), skip this.
State "Using karpathy-guidelines" when you invoke it so it's visible.
EOF

exit 0
