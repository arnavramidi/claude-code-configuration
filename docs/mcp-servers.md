# MCP servers

MCP (Model Context Protocol) servers give Claude Code tools beyond its built-ins — talking
to a real database, a real browser, a real docs index, instead of guessing from training
data. Each one is registered once (globally, or per-project) and then Claude can call its
tools like any other tool, subject to your permission settings.

Registered in `~/.claude.json` under `mcpServers` (that file also holds account/session
state, so it isn't included in this repo — see [Replicating this setup](../README.md) for
how to add servers yourself). Config values (API keys, tokens) live in each server's `env`
block and are **not** reproduced here.

## Global servers (available in every project)

| Server | Transport | What it's for |
|---|---|---|
| `github` | HTTP (GitHub's hosted MCP) | PR/issue ops, code search across repos — routed ahead of the raw `gh` CLI for anything structured |
| `chrome-devtools` | stdio (`npx`) | Screenshot + console-log verification of UI work; spins up its own Chrome profile |
| `claude-in-chrome` | browser extension, not a config entry | Drives your **existing** Chrome tab group instead of a spare profile — preferred over chrome-devtools when you're already looking at the page |
| `playwright` | stdio (`npx`) | Headless E2E test suites |
| `context7` | HTTP | Version-pinned library docs (React, Next.js, Prisma, Tailwind, etc.) — used instead of trusting training data on anything with recent breaking changes |
| `sentry` | HTTP | Production error lookup, to correlate a code change with a live issue |
| `vercel` | HTTP | Build/deploy state |
| `linear` | SSE | Task tracker ops |
| `magic` (21st.dev) | stdio (`npx`) | Pulls real, existing UI component patterns instead of having Claude invent JSX from scratch |
| `brave-search` | stdio (`npx`) | General web search, used as a fallback when context7 has no entry for a library |

## Per-project servers (added inside a specific repo, not globally)

| Server | What it's for |
|---|---|
| `postgres` | Read queries + schema inspection against that project's dev DB |
| `supabase` | Auth/storage ops, for projects built on Supabase |
| `figma` | Design-to-code / code-to-design sync for projects with a Figma source of truth |
| `patchright` | A stealth-patched Playwright fork, for projects where browser automation needs to avoid bot detection (e.g. an already-authenticated scraping/automation flow) |

Per-project servers are added the same way as global ones, just without `-s user` (see
below) — Claude Code scopes them to the directory you're in when you register them.

## Adding a server yourself

```bash
# Global (every project)
claude mcp add --transport http context7 https://mcp.context7.com/mcp -s user

# stdio server needing an npx package + API key
claude mcp add --transport stdio magic -s user -- npx -y @21st-dev/magic-mcp \
  --env API_KEY=your-key-here

# Project-scoped (no -s user — defaults to the current directory)
claude mcp add --transport stdio postgres -- npx -y @modelcontextprotocol/server-postgres \
  "postgresql://user:pass@localhost/dbname"
```

Run `claude mcp list` to see what's registered and `/mcp` inside a session to check
connection status. Most of the hosted HTTP/SSE servers above (`github`, `context7`,
`sentry`, `vercel`, `linear`) walk you through an OAuth login on first use — no manual key
needed. The `npx`-based stdio servers (`magic`, `brave-search`, `chrome-devtools`,
`playwright`) need their own API keys where the underlying service requires one (Magic,
Brave Search); check each project's docs for the exact env var name.
