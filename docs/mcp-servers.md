# MCP servers

MCP (Model Context Protocol) servers give Claude Code tools beyond its built-ins — talking
to a real database, a real browser, a real docs index, instead of guessing from training
data. Each one is registered once (globally, or per-project) and then Claude can call its
tools like any other tool, subject to your permission settings.

Registered in `~/.claude.json` under `mcpServers` (that file also holds account/session
state, so it isn't included in this repo — see [Replicating this setup](../README.md) for
how to add servers yourself). Config values (API keys, tokens) live in each server's `env`
block and are **not** reproduced here.

Global registrations dropped from 11 to 4 in this redesign — see the removed-and-why table
below for why each one left.

## Global servers (available in every project)

| Server | Transport | What it's for |
|---|---|---|
| `context7` | HTTP | Version-pinned library docs (React, Next.js, Prisma, Tailwind, etc.) — used instead of trusting training data on anything with recent breaking changes |
| `chrome-devtools` | stdio (`npx`) | Screenshot + console-log verification of UI work; spins up its own Chrome profile |
| `playwright` | stdio (`npx`) | Headless E2E test suites |
| `consensus` | HTTP | Academic paper search (consensus.app) — cited findings for research-backed claims |

Live status as of this writing: all four registered servers show `✔ Connected` via
`claude mcp list`.

**`claude-in-chrome`** isn't in the table above because it isn't a `claude mcp` config
entry at all — it's a browser extension. It drives your **existing** Chrome tab group
instead of spinning up a spare profile, and is preferred over `chrome-devtools` when
you're already looking at the page.

## Per-project servers (added inside a specific repo, not globally)

| Server | What it's for |
|---|---|
| `postgres` | Read queries + schema inspection — register **inside a repo with a real database and a maintained server**, not globally. The archived reference implementation has a known SQL-injection issue, and a global registration with a placeholder connection string can't back a real "schema verified" claim |
| `supabase` | Auth/storage ops — registered in the Tauri to-do app project, which is actually built on Supabase |
| `patchright` | A stealth-patched Playwright fork, for projects where browser automation needs to avoid bot detection — registered in the job-apply-agent project, which depends on it |

Per-project servers are added the same way as global ones, just without `-s user` (see
below) — Claude Code scopes them to the directory you're in when you register them.

## Removed and why

| Server | Why it's gone |
|---|---|
| `github` | Replaced by the `gh` CLI. The registered server was the archived reference implementation; every GitHub operation attempted during the audit (repo listing, cloning, tree reads) worked fine with `gh` and no server, OAuth, or tool slot. `gh api` covers the structured PR-review calls the MCP offered. |
| `brave-search` | Replaced by native `WebSearch` / `WebFetch`. Archived package; every search during the audit used the native tools successfully. |
| `linear` | Dead transport, no evidence of use. |
| `sentry` | Never authenticated, no matching project. |
| `vercel` | Never authenticated, no matching project. |
| `huggingface` | Never authenticated. Also a dependency removal: it shipped bundled with the `huggingface-skills` plugin, and that plugin's removal (see `docs/plugins.md`) was itself a precondition for a clean `claude mcp list` (criterion 1). |
| UI component-retrieval MCP (third-party design-tool integration) | Dropped as a global mandate. Component retrieval wasn't what fixed the actual UI complaints from real work, and pulling patterns from an external index imports a foreign design vocabulary into an already-themed codebase. If retrieval is wanted later, shadcn's own MCP (`pnpm dlx shadcn@latest mcp init --client claude`) reads the project's own `components.json` and registries instead of an outside source. |

One more inventory row is gone too — a design-tool-sync server with no evidence it was ever
used, dropped as a documentation correction rather than a formal removal.

## Adding a server yourself

```bash
# Global (every project)
claude mcp add --transport http context7 https://mcp.context7.com/mcp -s user

# Project-scoped (no -s user — defaults to the current directory)
claude mcp add --transport stdio postgres -- npx -y @modelcontextprotocol/server-postgres \
  "postgresql://user:pass@localhost/dbname"
```

Run `claude mcp list` to see what's registered and `/mcp` inside a session to check
connection status. The hosted HTTP servers above (`context7`, `consensus`) walk you through
an OAuth login or need no key at all on first use. The `npx`-based stdio servers
(`chrome-devtools`, `playwright`) need their own API keys only if the underlying service
requires one; check each project's docs for the exact env var name.
