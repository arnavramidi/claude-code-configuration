# Custom subagents and slash commands

## Subagents (`agents/`)

By default, a dispatched subagent (`Agent` tool, "Task" tool) starts with **no MCP access**
— it can read/write files and run shell commands, but it can't call `mcp__postgres__*`,
`mcp__github__*`, `mcp__context7__*`, etc. That's a problem for any task where the right
answer depends on real external state (the actual DB schema, the actual library version,
the actual rendered page) rather than a plausible guess.

The four files in `agents/` are user-scoped subagent definitions
(`~/.claude/agents/*.md`) that grant exactly the MCP tools each role needs, paired two
deep (implementer → reviewer) per domain:

| Subagent | Domain | Model default | Key MCP grants |
|---|---|---|---|
| `backend-implementer` | API/DB implementation | dispatcher sets per task | `postgres`, `context7`, `github`, `sentry`, `brave-search` |
| `code-reviewer` | Reviews backend work | `opus` | Same, read-only |
| `frontend-implementer` | UI implementation | dispatcher sets per task | `magic` (21st.dev), `context7`, `chrome-devtools`, `claude-in-chrome` |
| `frontend-reviewer` | Reviews frontend work | `opus` | Same, read-only |

Each file's frontmatter (`tools:`) is the actual permission grant — Claude Code enforces
it, it isn't just a suggestion in the prompt. The body is the subagent's system prompt: a
numbered checklist (verify schema → verify library docs → check related PRs → implement →
verify against production signal → report) that mirrors the `subagent-dispatch-audit.sh`
hook's expectations, so a dispatched subagent doesn't need the hook's reminder repeated
into its prompt — its own instructions already carry it.

Reviewers default to `opus` because review quality (catching a real bug vs. rubber
stamping) is judged to matter more than review cost. Implementers don't have a fixed
model — the dispatching agent is expected to pick `haiku`/`sonnet`/`opus` per the tiering
rule in `docs/hooks.md`.

## Slash commands (`commands/`)

`spec.md` is a custom `/spec` command (`~/.claude/commands/spec.md`). Given a short
feature idea, it: checks the working tree is clean, derives a title/slug/branch name,
switches to a new branch, asks clarifying questions (target users, persistence, external
integrations, UI constraints, scope boundaries) before writing anything, then drafts a
markdown spec file under `_specs/` using a project-local template
(`_specs/template.md` — not included here, since it's project-specific).

## Replicating

Copy `agents/*.md` to `~/.claude/agents/` and `commands/spec.md` to
`~/.claude/commands/` (or drop either into a project's `.claude/agents/` /
`.claude/commands/` to scope them to one repo instead of every session). No restart
needed — Claude Code picks up new agent/command files at the start of the next session.
