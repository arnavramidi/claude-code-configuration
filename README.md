# Claude Code configuration

This repo documents how I have [Claude Code](https://claude.com/product/claude-code) (the
CLI) configured on my machine, why each piece is there, and how to rebuild the same setup
from scratch. It's not code for an app — it's a snapshot of tooling: a global preferences
file, three shell hooks, four custom subagents, a slash command, a set of plugins, and the
MCP servers that give Claude real access to a browser, a database, docs, etc. instead of
guessing from training data.

The point of writing it down is that a lot of this only works *because* it's enforced
mechanically. Telling Claude "always check docs before using an API" in a preferences file
is a suggestion it can rationalize its way out of on a busy turn. A hook that injects that
reminder into every single prompt, or a subagent definition that simply doesn't have the
tool unless you grant it, doesn't have that failure mode.

## What's in here

| Path | What it is |
|---|---|
| `CLAUDE.md` | Global preferences file, loaded into every session in full — communication style, tool-routing rules, model policy. Walkthrough: [`docs/claude-md.md`](docs/claude-md.md) |
| `settings.json` | Wires up the hooks below, lists enabled plugins, sets defaults (model, theme, effort level) |
| `hooks/` | Three shell scripts that fire automatically on prompt submit / before subagent dispatch. Explained in [`docs/hooks.md`](docs/hooks.md) |
| `agents/` | Four user-scoped subagent definitions with explicit MCP tool grants (subagents get none by default). Explained in [`docs/agents-and-commands.md`](docs/agents-and-commands.md) |
| `commands/spec.md` | A custom `/spec` slash command that turns a short idea into a spec file + branch |
| `docs/mcp-servers.md` | What each connected MCP server does, global vs. per-project, how to add your own |
| `docs/plugins.md` | Installed plugins, where they came from, how to install them |
| `docs/skills.md` | The specific skills in active rotation and what triggers each one |

**Not included, on purpose:** `settings.local.json` (per-project permission allowlists —
personal and not portable), and the raw `mcpServers` block from `~/.claude.json` (holds
API keys/tokens in `env`). `docs/mcp-servers.md` lists every server and how to re-register
it with your own credentials instead.

## Replicating this setup

1. **Install Claude Code**, if you haven't: `npm install -g @anthropic-ai/claude-code` (or
   see [claude.com/product/claude-code](https://claude.com/product/claude-code) for other
   install methods).

2. **Copy the preferences file.**
   ```bash
   cp CLAUDE.md ~/.claude/CLAUDE.md
   ```
   Edit the "I am ___" line and communication-style section to match how *you* want to
   work with it — this file is meant to be personal, not copied verbatim.

3. **Copy the hooks and wire them up.**
   ```bash
   cp hooks/*.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/*.sh
   ```
   Then merge the `hooks` block from `settings.json` into your own
   `~/.claude/settings.json` (don't overwrite the whole file if you already have one — see
   [`docs/hooks.md`](docs/hooks.md) for what each hook does and why it's shaped the way it
   is, so you can adapt the checklists to your own stack instead of mine).

4. **Install the plugins** — see [`docs/plugins.md`](docs/plugins.md) for the exact
   `/plugin marketplace add` + `/plugin install` commands. `superpowers` is the one
   everything else leans on (it's what makes skill-checking happen automatically); install
   it first.

5. **Register MCP servers** for the tools you actually use — see
   [`docs/mcp-servers.md`](docs/mcp-servers.md) for the full list and `claude mcp add`
   commands. You don't need all of them; register the ones matching your stack (a
   Postgres server is pointless if you don't touch Postgres) and update the routing table
   in your copy of `CLAUDE.md` to match what you actually have connected — a hook that
   tells Claude to reach for a server you haven't installed just produces confused
   behavior.

6. **Copy the subagents and slash command.**
   ```bash
   cp agents/*.md ~/.claude/agents/
   cp commands/spec.md ~/.claude/commands/
   ```
   Edit the `tools:` frontmatter in each agent file to match the MCP server names you
   actually registered in step 5 — a grant for an MCP server you didn't install is a
   silent no-op.

7. **Start a new session** and sanity-check it: submit any prompt and confirm the tooling
   checklist shows up as context, then run `/plugin` and `/mcp` to confirm the expected
   plugins and servers are listed as connected.

Everything here is user-scoped (`~/.claude/...`), so it applies across every project you
open Claude Code in. To scope any single piece to one repo only, drop the matching file
into that repo's `.claude/` directory instead of the home-directory one.
