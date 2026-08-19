# Claude Code configuration

This repo documents how I have [Claude Code](https://claude.com/product/claude-code) (the
CLI) configured on my machine, why each piece is there, and how to rebuild the same setup
from scratch. It's not code for an app — it's a snapshot of tooling: a global preferences
file, event-driven shell hooks, two custom subagents, five plugins, and the MCP servers
that give Claude real access to a browser, a docs index, a database, etc. instead of
guessing from training data.

**`~/.claude` *is* the checkout.** This repo is a git-tracked clone of the actual
`~/.claude` directory on my machine (with a default-deny `.gitignore` allowlisting only the
config surface — `CLAUDE.md`, `settings.json`, `hooks/`, `agents/`, `commands/`, `docs/`,
`README.md`, itself), not a separate copy that gets manually re-synced. There's no copy
step between "change something in `~/.claude`" and "it shows up in this repo" — they're the
same files. Drift between the repo and the live machine (a problem the earlier version of
this setup had) shows up as `git status` in `~/.claude`, the same way any other tracked
directory reports an uncommitted change. That's the drift detector: run `git status` there,
commit or discard what it shows.

The point of writing this down at all is that a lot of it only works *because* it's
enforced mechanically. Telling Claude "always check docs before using an API" in a
preferences file is a suggestion it can rationalize its way out of on a busy turn. A hook
that injects live tool health right before the specific tool call that needs it, or a
subagent definition that simply inherits every tool by default, doesn't have that failure
mode.

## What's in here

| Path | What it is |
|---|---|
| `CLAUDE.md` | Global preferences file, loaded into every session in full — explanation quality, ground rules, model policy, verification expectation. Walkthrough: [`docs/claude-md.md`](docs/claude-md.md) |
| `settings.json` | Wires up the hooks below, lists enabled plugins, sets defaults (model, permissions, effort level) |
| `hooks/` | 3 event-driven shell scripts, wired into `settings.json`, that fire on specific tool calls or session events instead of every prompt — plus 2 test scripts for the logic-bearing ones. Explained in [`docs/hooks.md`](docs/hooks.md) |
| `agents/` | Two user-scoped subagent definitions (`implementer`, `reviewer`) that inherit every tool, including MCP, by default. Explained in [`docs/agents-and-commands.md`](docs/agents-and-commands.md) |
| `commands/` | Empty — the old `/spec` command was retired; see [`docs/agents-and-commands.md`](docs/agents-and-commands.md) for why. Kept in the `.gitignore` allowlist for future use |
| `docs/mcp-servers.md` | What each connected MCP server does, global vs. per-project, what got dropped and why, how to add your own |
| `docs/plugins.md` | Installed plugins, what got removed and why, how to install them |
| `docs/skills.md` | The specific skills in active rotation and what triggers each one |

**Not included, on purpose:** `settings.local.json` (per-project permission allowlists —
personal and not portable), and the raw `mcpServers` block from `~/.claude.json` (holds
API keys/tokens in `env`, and account/session state that isn't configuration).
`docs/mcp-servers.md` lists every server and how to re-register it with your own
credentials instead. Everything else outside the `.gitignore` allowlist (session history,
caches, backups, telemetry, etc.) is machine state, not configuration, and stays untracked.

## Replicating this setup

1. **Install Claude Code**, if you haven't: `npm install -g @anthropic-ai/claude-code` (or
   see [claude.com/product/claude-code](https://claude.com/product/claude-code) for other
   install methods).

2. **Copy the preferences file.**
   ```bash
   cp CLAUDE.md ~/.claude/CLAUDE.md
   ```
   Edit it to match how *you* want to work with Claude — this file is meant to be personal,
   not copied verbatim.

3. **Copy the hooks and wire them up.**
   ```bash
   cp hooks/*.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/*.sh
   ```
   Then merge the `hooks` block from `settings.json` into your own
   `~/.claude/settings.json` (don't overwrite the whole file if you already have one — see
   [`docs/hooks.md`](docs/hooks.md) for what each hook does and why it's shaped the way it
   is, so you can adapt it to your own workflow instead of mine).

4. **Install the plugins** — see [`docs/plugins.md`](docs/plugins.md) for the exact
   `/plugin marketplace add` + `/plugin install` commands. `superpowers` is the one
   everything else leans on (it's what makes skill-checking happen automatically); install
   it first.

5. **Register MCP servers** for the tools you actually use — see
   [`docs/mcp-servers.md`](docs/mcp-servers.md) for the full list and `claude mcp add`
   commands. You don't need all of them; register the ones matching your stack (a Postgres
   server is pointless if you don't touch Postgres, and should live in that project, not
   globally).

6. **Copy the subagents.**
   ```bash
   cp agents/*.md ~/.claude/agents/
   ```
   Neither carries `tools:` frontmatter, so each inherits whatever MCP servers you
   registered in step 5 automatically — no per-agent tool list to keep in sync.

7. **Start a new session** and sanity-check it: run `/mcp` to confirm the expected servers
   are listed as connected, and `/plugin` to confirm the expected plugins are enabled.

Everything here is user-scoped (`~/.claude/...`), so it applies across every project you
open Claude Code in. To scope any single piece to one repo only, drop the matching file
into that repo's `.claude/` directory instead of the home-directory one.
