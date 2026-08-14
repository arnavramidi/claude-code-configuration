# Hooks

Hooks are shell scripts the Claude Code CLI runs automatically at specific points in a
session (e.g. every time you submit a prompt, or right before a tool call). They can't be
replicated by asking Claude to "remember" something — the harness runs them, not the
model — so they're the only reliable way to force a behavior to happen every single time.

All three hooks below live in `~/.claude/hooks/` and are wired up in the `hooks` block of
`settings.json` (copy at the repo root). They're user-scoped, so they apply to every
project, not just one repo.

## 1. `tooling-audit.sh` — `UserPromptSubmit`

**Fires:** on every prompt you submit, before Claude starts working on it.

**Mechanism:** its stdout is appended to the prompt as extra context. Claude sees it as a
system reminder attached to your message.

**What it does:** prints a checklist mapping task type → required tool, e.g. "UI work →
pull a real component pattern from the 21st.dev Magic MCP before writing JSX from
scratch" or "library API questions → look up version-pinned docs via context7 instead of
guessing from training data." The instruction to Claude is explicit: state which tools
you're using and why, and don't skip one silently.

**Why it exists:** without this, Claude tends to default to writing plausible-looking code
from memory instead of pulling real patterns/docs, especially for libraries that changed
between training cutoff and now.

## 2. `karpathy-reminder.sh` — `UserPromptSubmit`

**Fires:** on every prompt, same mechanism as above (stdout → prompt context).

**What it does:** if the turn involves writing, reviewing, or refactoring code, it tells
Claude to (a) invoke the `karpathy-guidelines` skill as a checklist — surgical changes,
surface assumptions, avoid overcomplication, define verifiable success criteria — and
(b) explain decisions in plain language (what happens / what it buys you / what it costs),
never leading with a raw function or variable name as if that were the explanation.

**Why it exists:** keeps explanations legible to someone who reviews and directs the code
without living in it day to day, and keeps changes minimal rather than opportunistic
rewrites.

## 3. `subagent-dispatch-audit.sh` — `PreToolUse` (matcher: `Task`)

**Fires:** right before Claude dispatches a subagent (the `Task` tool call).

**Mechanism:** different from the other two — this one reads the tool call's JSON off
stdin and returns structured JSON (`hookSpecificOutput.additionalContext`) rather than
plain stdout. That's the required shape for a `PreToolUse` hook that wants to inject
context without blocking the call.

**What it does:** reminds Claude that generic subagents (`general-purpose`, `claude`) have
**no MCP access** — so a prompt like "look up the schema yourself" silently fails; real
data/docs/API signatures have to be inlined into the dispatch prompt, or the task should go
to one of the user-scoped subagents in `agents/` that carry explicit MCP grants instead.
It also restates the model-tiering rule (below) so the dispatcher picks a model
deliberately instead of defaulting to one tier for everything.

**Model tiering rule enforced here:**
| Model | Use for |
|---|---|
| `haiku` | Mechanical edits, scaffolding, single-file changes with a clear spec, renames |
| `sonnet` | Multi-file edits, moderate reasoning, library integration, non-trivial tests |
| `opus` | Ambiguous specs, deep debugging, cross-cutting refactors, code review, architecture |

Bias up, not down, when uncertain. Reviewer subagents default to `opus`.

## 4. `Stop` and `Notification` hooks — macOS notifications

Not custom scripts — inline `osascript` commands in `settings.json`. `Stop` fires when
Claude finishes responding and posts a "Finished — ready for you" macOS notification
(subtitle = current directory name). `Notification` fires when Claude is blocked waiting
on you (e.g. a permission prompt) and posts the harness's notification message. Useful if
you run long agentic sessions in a background terminal tab and don't want to babysit it.
