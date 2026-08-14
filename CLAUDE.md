# Tooling discipline (loaded every Claude Code session)

I am Arnav. The tools listed below are MCPs, plugins, and skills I have installed and
expect Claude to use by default — not as a last resort. Skipping them produces mediocre
output. (The per-turn "Tooling audit" hook enforces *stating which tools you'll use before
code or a plan*; this file is the reference behind it.)

## Communication style

I'm technical but I vibe-code — explain so I can follow along and scrutinize decisions
without decoding jargon. This governs ALL explanations, especially when presenting
approaches/trade-offs.

- **Outcome-first, detail on tap.** Lead every decision with plain language: what will
  actually happen, what it gets me, and what it risks. Then give the technical backing,
  kept compact, so I can verify it. Don't bury the point under machinery.
- **Function and file names are evidence, not the explanation.** Never explain a decision
  as a chain of code identifiers (e.g. `parseX() → matchY() → fillZ()`). Say what each step
  *does* in plain words first; name the function only to back it up. If a sentence is just
  an arrow-chain of identifiers, rewrite it.
- **Every approach gets: what happens (plain) / what it buys me / what it costs.** In that
  order. The trade-off is the part I care about most — make it legible.
- **Define a term the first time it matters**, in half a sentence. Don't assume I remember
  an internal name from earlier or know our own codebase's vocabulary cold.
- Stay technical enough that I can push back on the decision — the goal is fewer words I
  have to decode, not less substance.

## Tool routing table

| Task | First reach | Fallback |
|---|---|---|
| New UI component | `mcp__magic__21st_magic_component_builder` | `frontend-design` skill |
| Component inspiration / browse patterns | `mcp__magic__21st_magic_component_inspiration` | — |
| Refine existing component | `mcp__magic__21st_magic_component_refiner` | — |
| Logo lookup | `mcp__magic__logo_search` | — |
| Visual verification | `mcp__chrome-devtools__take_screenshot` | `mcp__claude-in-chrome__*` |
| User-tab interaction | `mcp__claude-in-chrome__*` | `mcp__playwright__*` |
| Headless E2E | `mcp__playwright__*` | — |
| Library API lookup | `mcp__context7__get-library-docs` | web search only if context7 has no entry |
| Postgres read query | `mcp__postgres__query` | Bash + psql |
| GitHub PR/issue ops | `mcp__github__*` | `gh` CLI |
| Sentry error lookup | `mcp__sentry__*` | — |
| Vercel build/deploy state | `mcp__vercel__*` | — |
| Linear task ops | `mcp__linear__*` | — |
| Supabase auth/storage | `mcp__supabase__*` | — |
| General web search | `mcp__brave-search__brave_web_search` | WebSearch |
| Brainstorm a feature | `superpowers:brainstorming` | — |
| Plan implementation | `superpowers:writing-plans` | — |
| Multi-task feature | `superpowers:subagent-driven-development` | — |

## Models (main thread)

- The main thread / controller stays **Opus** regardless of task: brainstorming, planning,
  review, writing specs/READMEs.
- Subagent model tiering (haiku/sonnet/opus) and MCP-access rules are enforced by the
  `subagent-dispatch-audit` hook at dispatch time — not repeated here.

## Memory

Memory files live in `~/.claude/projects/-Users-arnav/memory/` (user profile, project
context, CRM API ref, Velora contact corrections, feedback files). Read them at session
start before answering questions about my projects. Append to them when learning durable
facts about my projects or preferences.

## Verification expectation

At the end of any non-trivial task, Claude must verify by one of:
- Screenshot via `mcp__chrome-devtools__*` for UI work
- Test run via Bash for backend/library work
- DB query via `mcp__postgres__*` for data work
- Spawning a reviewer subagent for code review

If verification is skipped, state why explicitly.
