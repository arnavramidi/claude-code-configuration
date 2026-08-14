# CLAUDE.md, section by section

`CLAUDE.md` (copy at the repo root) is the one file that's always loaded into every
session, in full, before anything else. It's where standing preferences live — the things
that should hold true on every project, not just one. Everything else in this repo (hooks,
skills, agents) exists to make sure the rules in this file actually get *followed*, not
just stated once and forgotten.

## Communication style

The core rule: explanations lead with plain language — what will actually happen, what it
gets you, what it risks — *then* the technical detail to back it up. Code identifiers
(function/file names) are cited as evidence for a claim, never used as a stand-in for the
claim itself ("it calls `parseX()` then `matchY()`" is not an explanation of what
happened). New terms get a half-sentence definition the first time they matter, since
familiarity with the codebase's internal vocabulary isn't assumed.

This rule is echoed by the `karpathy-reminder.sh` hook on every code-touching turn, so it
can't quietly lapse over a long session.

## Tool routing table

A task → tool lookup table (UI work → the Magic MCP; library docs → context7; Postgres
reads → the postgres MCP; etc., full list in `mcp-servers.md`). This is the same table
the `tooling-audit.sh` hook injects on every prompt — the file is the source of truth,
the hook is what prevents it from being skipped under time pressure.

## Model policy for the main thread

The main/controlling session always runs on Opus, regardless of task — brainstorming,
planning, review, spec/README writing all stay on the strongest model, since that's the
thread making judgment calls about what to delegate and how. Subagent model tiering
(haiku/sonnet/opus) is a separate policy, enforced by `subagent-dispatch-audit.sh` at
dispatch time rather than restated here.

## Memory

A pointer to a persistent, file-based memory system outside this repo
(`~/.claude/projects/<project-hash>/memory/`) — project-specific facts, decisions, and
feedback that should persist across sessions on that project but aren't relevant as a
general-purpose rule. Not included in this repo since it's project state, not
configuration.

## Verification expectation

Closes every non-trivial task with an explicit verification step — a screenshot for UI
work, a test run for backend work, a DB query for data work, or a reviewer subagent for
code review — and requires stating explicitly when verification was skipped rather than
letting "looks right" stand in for it.
