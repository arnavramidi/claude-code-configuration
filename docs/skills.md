# Skills

A skill is a packaged set of instructions for handling one kind of task — a checklist, a
process, a review rubric. Claude loads a skill's full instructions into the turn when it
decides the skill applies, instead of improvising. Skills come from installed plugins (see
`plugins.md`) or can be hand-written project-local files under `.claude/skills/`.

The skill that matters most here is `superpowers:using-superpowers` — it's the one that
makes Claude *check for a relevant skill before responding at all*, including before
clarifying questions. Without it, skills exist but get silently skipped because "this
looks like a simple question." It's injected at session start via the `SessionStart` hook
that ships with the `superpowers` plugin itself (not one of the 3 wired custom hooks in
this repo — that one comes bundled with the plugin).

## Skills actually in rotation on this setup

| Skill | Source | When it fires |
|---|---|---|
| `superpowers:brainstorming` | `superpowers` plugin | Before any creative/feature work — Q&A to pin down intent and design before a single line of code |
| `superpowers:writing-plans` | `superpowers` plugin | Turning an agreed spec into a concrete, reviewable task plan |
| `superpowers:subagent-driven-development` | `superpowers` plugin | Executing a multi-task plan by dispatching per-task subagents with two-stage review |
| `superpowers:systematic-debugging` | `superpowers` plugin | Any bug/test-failure/unexpected-behavior, before proposing a fix |
| `superpowers:test-driven-development` | `superpowers` plugin | Writing tests before implementation code |
| `superpowers:verification-before-completion` | `superpowers` plugin | Before claiming anything is "done" — run the actual verification command first |
| `superpowers:receiving-code-review` | `superpowers` plugin | Reading feedback critically rather than agreeing and implementing on autopilot |
| `superpowers:using-git-worktrees` | `superpowers` plugin | Isolating feature work from the current workspace |
| `frontend-design` | `frontend-design` plugin | Aesthetic/layout direction for new or reshaped UI — the primary source of design guidance now that no component-retrieval MCP is registered (`docs/mcp-servers.md`) |
| `andrej-karpathy-skills:karpathy-guidelines` | `andrej-karpathy-skills` plugin | On demand, when writing/reviewing/refactoring code — no longer force-injected on every prompt by a dedicated hook. The explanation-quality rules that hook used to repeat now live directly in `CLAUDE.md` (`docs/claude-md.md`) instead of being restated by a second mechanism |

## Replicating

Skills arrive with their plugin — install the plugin (`docs/plugins.md`) and its skills
become available automatically; no separate step. To write a project-local skill instead
of relying on a plugin, use the `superpowers:writing-skills` skill itself, which walks
through the checklist for making a new skill discoverable and testing that it actually
fires when it should.
