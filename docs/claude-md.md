# CLAUDE.md, section by section

`CLAUDE.md` (copy at the repo root) is the one file that's always loaded into every
session, in full, before anything else. It's where standing preferences live — the things
that should hold true on every project, not just one. This redesign rewrote it from a
single sprawling communication-style block into four short sections, on the theory that a
file that's easy to skim actually gets followed where a wall of prose gets skipped.

## Explanation quality

Plain language first, technical backing after, kept compact. New terms get a half-sentence
definition the first time they matter. Every approach gets stated as what happens / what it
buys / what it costs, in that order — the trade-off is the part meant to be scrutinized, not
buried under function names as if a chain of identifiers were the explanation.

**Style-ownership split, resolved here:** response *shape* — length, structure, no
preamble — is owned by the `i-have-adhd` plugin, not restated in this section. This section
owns explanation *quality* only. Before this redesign, three sources instructed style and
two of them disagreed on length (this file said "no length limit," the plugin said
"~150–250 words"); splitting "shape" from "quality" into exactly one owner each removes the
conflict instead of picking a winner and hoping the loser stays quiet. A third, duplicate
copy of the plugin's length rule (a standalone memory file) was deleted outright. See
`docs/plugins.md` for the full resolution.

## Ground rules

Never assert external state that could have been checked with a live tool (library APIs via
context7, rendered UI via a browser, data via the project's real database) — say when a
claim is from memory instead. Detect the project's stack from its manifest before writing
code; never assume a framework. Flag test retargeting explicitly, as its own line, never
folded into "tests updated." Reviews check prior behavior, not only the spec — what did a
change remove or relocate that nobody asked about?

These four rules used to be injected fresh on every prompt by a general-purpose
`UserPromptSubmit` hook. That hook is retired; the rules now live here once, as the single
source of truth. Of the 3 wired hooks that remain (`docs/hooks.md`), `tooling-context.sh`
is the one that injects *live* tool health, and only on the specific tool calls that need
it, instead of restating a static checklist on every turn regardless of relevance.

## Models

The main/controlling thread always runs on Opus, regardless of task — brainstorming,
planning, review, spec/README writing all stay on the strongest model, since that's the
thread making judgment calls about what to delegate and how. The subagent model-tiering
table (haiku/sonnet/opus, by task complexity — reproduced in `docs/agents-and-commands.md`)
lives here now too. It used to be restated inside a subagent-dispatch review hook as
well as in the docs — one extra place that could drift from the real rule. That hook is
retired; this file is now the single source of truth for tiering.

## Verification

Closes every non-trivial task with an explicit verification step — a screenshot for UI
work, a test run for backend work, a DB query for data work, or a reviewer subagent for
code review — and requires stating explicitly when verification was skipped rather than
letting "looks right" stand in for it.

## What's deliberately not in here

**Memory** — a pointer to the persistent, file-based memory system outside this repo
(`~/.claude/projects/<project-hash>/memory/`): project-specific facts, decisions, and
feedback that should persist across sessions on that project but aren't relevant as a
general-purpose rule. Not included in this repo, since it's project state, not
configuration.

**Tool routing table** (task type → MCP server) — cut entirely, not just un-echoed. A
static "task type → tool" table goes stale the moment a server is added or dropped (this
redesign dropped seven of them — `docs/mcp-servers.md`), and it was previously restated a
third time inside a `UserPromptSubmit` hook on every single prompt. In its place,
`tooling-context.sh` (`docs/hooks.md`) injects *live* MCP health — computed from
`claude mcp list`, not hand-maintained — on the specific tool calls where it matters
(`brainstorming`, `writing-plans`, first `TodoWrite` of a session) instead of every prompt
regardless of relevance.
