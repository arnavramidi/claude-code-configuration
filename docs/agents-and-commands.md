# Custom subagents and slash commands

## Subagents (`agents/`)

**Inheritance note, docs-verified 2026-08-19:** when a subagent definition's frontmatter
has no `tools:` key at all, it inherits *every* tool available to the dispatching session,
including MCP tools (`mcp__context7__*`, `mcp__postgres__*`, etc.) — not none. The earlier
version of this repo said the opposite (subagents get no MCP access by default) and built
four separate agent files around working around that, which was based on a stale
assumption. Omitting `tools:` is itself the grant; it doesn't need to be spelled out.

Four subagents collapsed to two once that was corrected. The old frontend/backend split
existed only to hand out different MCP grants via `tools:` — with inheritance-by-default,
that frontmatter had inverted into a cage instead of a grant, and the split bought nothing.
What genuinely differs between a UI review and a backend review is the rubric, which is a
paragraph inside the prompt, not a reason for a separate file.

| Subagent | Role | Model | Tools |
|---|---|---|---|
| `implementer` | Detects the project's real stack from its manifest, verifies recent library APIs via context7, implements, verifies against the real running system (browser for UI, tests for backend/library, live DB query for data work), flags any test retargeting | dispatcher sets per task (see tiering below) | no `tools:` frontmatter — inherits everything |
| `reviewer` | Reviews implementation against acceptance criteria **and** prior behavior — the second question is explicit: *what did this change remove or relocate that nobody asked about?* Treats test retargeting as a finding, not a footnote. Applies the domain rubric the diff calls for (UI: a11y/keyboard/responsive/console; backend: schema/API contract/error handling) | `opus` (fixed) | no `tools:` frontmatter — inherits everything, kept read-only by convention |

Both agents open by reading the project manifest (`package.json` / `pyproject.toml` /
`Cargo.toml`) and adapting to what's actually there — neither names a specific framework in
its instructions, so they don't go stale when the stack changes.

**Model tiering** (which model the dispatcher should pick for `implementer` — `reviewer`
stays fixed at `opus`) lives in `CLAUDE.md`'s Models section, not in a hook or duplicated
here — see `docs/claude-md.md`. One place to look instead of three is the point; repeating
the table here would just recreate the drift risk this redesign exists to close.

## Slash commands (`commands/`)

Empty as of this redesign. `spec.md` (the old custom `/spec` command) is **retired**: its
job — turning a short idea into a plan before writing code — is now covered by the
`superpowers:brainstorming` → `superpowers:writing-plans` skill pair, and `/spec`'s own
`_specs/` convention depended on a project-local template file that was never actually
checked into any project, so the command silently failed its own documented workflow. The
directory stays in the allowlist (`.gitignore`) for future use even though it ships empty.

## Replicating

Copy `agents/*.md` to `~/.claude/agents/` (or drop either file into a project's
`.claude/agents/` to scope it to one repo instead of every session). No restart needed —
Claude Code picks up new agent files at the start of the next session.
