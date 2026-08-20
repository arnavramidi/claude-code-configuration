# Second machine: shared Mac, user `arnav`

This folder is the Claude Code setup as it actually runs on the **shared MacBook Pro under
the `arnav` account**, added on 2026-08-19. The repo root describes the **other machine**
(user `arnavramidi`).

Nothing at the repo root was changed to add this. Both configurations sit side by side so
they can be compared directly.

**Not included, deliberately:** the auto-mode block from `settings.json` (it describes a
work project's data locations and trust boundaries), and `settings.local.json` (per-machine
permission grants — personal and not portable). Both stay untracked on the machine.

---

## Where the two machines agree

Both run the same core redesign: the per-prompt tooling lecture is gone, replaced by
event-driven checks; four stale subagents collapsed to `implementer` + `reviewer` with no
`tools:` frontmatter; the test-retargeting flag fires on edits to test files; `CLAUDE.md`
is short and names no dead tools; the model stays `opus[1m]` at `effortLevel: high`; and
the plugin set is trimmed to the same four essentials (`superpowers`, `frontend-design`,
`andrej-karpathy-skills`, `warp`).

## Where they differ, and why

| | Repo root (`arnavramidi`) | This folder (`arnav`) |
|---|---|---|
| **Design tool (21st.dev)** | Dropped entirely | **Kept connected.** Arnav chose to keep it and rotate the key |
| **UI rule** | None — the mandate was removed | **Declaration rule added:** if work creates or reshapes UI, state whether patterns were sourced from a live tool or written from scratch, and why. Either answer is fine; silence is not |
| **Plan-time tool guidance** | Names job types → tools ("context7 for library APIs, a browser for rendered UI, the project's real database for data claims") | **Judgment framing, no tool-to-job map.** Each server already ships its own description; a hand-maintained map is what went stale last time and would need editing every time a tool is added or swapped |
| **Response shape** | Delegated to the `i-have-adhd` plugin | **Kept in `CLAUDE.md`.** That plugin isn't installed here, and it only activates via a separate opt-in flag file, so the delegation would have dangled |
| **Notifications** | `ntfy-notify.sh` (phone push + desktop) | **Inline `osascript` desktop banners, unchanged.** The ntfy script exits silently without a `~/.claude/ntfy-topic` file, which doesn't exist here — adopting it verbatim would have removed the working desktop banners |
| **Terminal/UI prefs** | Not carried | Keeps `tui: fullscreen`, `theme`, `skipDangerousModePermissionPrompt`, `skipWorkflowUsageWarning` |
| **`~/.claude` as a git checkout** | Yes | **Not yet.** Deferred deliberately; this machine's config is a snapshot here instead |

## Three fixes made here that the root version still has

1. **Server-name parsing.** The health-table parser used `^([^:]+):`, which stops at the
   first colon — so `plugin:huggingface-skills:huggingface-skills` rendered as a row named
   just `plugin`, and any two bundled servers would collapse into the same anonymous row.
   Changed to a greedy match on `": "` (colon-space), which server names don't contain.
   Verified against real output.

2. **The test suite polluted the live cache.** `test-tooling-context.sh` wrote its fixture
   table straight into `~/.claude/cache/mcp-health.txt` with a fresh timestamp, so for up
   to an hour after any test run a real session would read fake tool status as live. Caught
   by an end-to-end canary. The test now saves and restores the real cache via an `EXIT`
   trap.

3. **The health cache was shared across projects.** It was one file with a one-hour TTL,
   but project-scoped servers only exist inside their own project — `patchright` and `figma`
   are registered in `job-apply-agent` and nowhere else. So planning work in that project
   cached seven servers, and switching to any other project within the hour would still
   report `patchright` and `figma` as available when they were unreachable: a stale list
   asserting something untrue about tooling, which is the exact defect this redesign exists
   to remove. The cache is now keyed on a hash of the session's working directory, pruned
   after two days like the marker files, and `claude mcp list` is run *from* that directory
   so project scope resolves correctly. The injected table names the directory it reflects
   and says so explicitly. Verified: home reports 5 servers, `job-apply-agent` reports 7,
   from separate cache files.

## Corrections to the root docs, as they apply to this machine

- `docs/plugins.md` says `code-review` and `explanatory-output-style` were "never actually
  live." On this machine both **were** installed, and `code-review` was enabled. Its
  practical conclusion still holds — `/code-review` exists as a CLI built-in (confirmed in
  the 2.1.236 binary alongside `ultrareview`), so dropping the marketplace plugin costs
  nothing.
- `docs/claude-md.md` justifies deleting the Memory section partly because its path was
  wrong. On this machine the path (`-Users-arnav`) was correct. The section was still
  removed — file-based memory loads natively — but as redundant, not broken.
- The spec's memory prune targets 10 files; only 2 existed here. This machine's index was
  already under the size target.
- `karpathy-reminder.sh` existed and was wired on this machine (it did not on the other),
  costing an extra ~222 tokens on every single prompt. Removed.

## Verification run on this machine (2026-08-19)

- Both hook test suites: 17 checks, all passing (including four asserting that one project's
  cached server list never leaks into another's).
- Live connections: 5 registered, 4 connected, design tool failed pending key rotation.
- Fresh session lists `implementer` and `reviewer`; the four old agents are gone.
- End-to-end canary through a real session confirmed both the brainstorm and plan triggers
  inject the live table with real data.
- Measured before/after: ~714 tokens per prompt (~28,500 per 40-turn session) down to ~60
  tokens at two moments, plus 25 unused skill descriptions no longer loaded.
