# Claude Code setup redesign — design

**Date:** 2026-08-19
**Status:** approved (rev 2 — full adversarial re-examination with on-machine evidence, same day), ready for implementation planning
**Scope:** Arnav's global Claude Code configuration (`~/.claude/`) and the
`claude-code-configuration` repo that documents it.

---

## 1. Why

The setup was designed in early 2026 around a premise that no longer holds: that the model
would skip available tools under time pressure unless mechanically reminded every turn. Two
things changed. The product grew features that replace parts of the setup, and the setup
itself drifted out of sync with the machine it describes.

The audit that triggered this redesign found three classes of problem.

### 1.1 The config instructs Claude to use tools that do not work

`claude mcp list` on 2026-08-19:

| Server | State |
|---|---|
| `magic` (21st.dev) | API key reset — cannot connect |
| `postgres` | "connected" to the literal placeholder `postgresql://user:pass@host:5432/dbname` |
| `linear` | HTTP 404 — registered on `/sse`, a transport that reached end-of-life April 2026 |
| `sentry`, `vercel`, `huggingface` | never authenticated |
| `github`, `brave-search` | running `@modelcontextprotocol/server-*`, archived May 2025 |

`tooling-audit.sh` fires on every prompt and opens by mandating the Magic MCP. That server
has been dead for an unknown period. Six of the ten servers the hook names cannot serve a
request.

### 1.2 One hook teaches something factually false

`subagent-dispatch-audit.sh` asserts that generic subagents have no MCP access. Subagents
now inherit all tools available to the main conversation, including MCP tools, unless
narrowed. The four custom agent definitions were built around that obsolete constraint:
their `tools:` frontmatter, written as a grant, now functions as a restriction. As written,
`frontend-implementer` cannot use WebSearch, WebFetch, TodoWrite, or the Skill tool.

### 1.3 Cost is concentrated where it does least good

Measured, per 40-turn session:

| Source | Cost |
|---|---|
| `tooling-audit.sh` (~492 tok × 40) | ~19,700 tok |
| `subagent-dispatch-audit.sh` (~442 tok × ~5 dispatches) | ~2,200 tok |
| `huggingface-skills` (26 skill descriptions, no ML work in rotation) | ~2,000–3,000 tok |
| `MEMORY.md` index (38 files, much of it shipped work) | ~1,860 tok |

### 1.4 Repo and machine disagree

`karpathy-reminder.sh` is committed and referenced in the repo's `settings.json` but does
not exist on disk. The repo declares `model: sonnet`; the machine runs `opus[1m]`. The repo
documents `osascript` notification hooks; the machine runs `ntfy-notify.sh`. Live but
undocumented: `i-have-adhd`, `rust-analyzer-lsp`, the `consensus` MCP. Documented but never
registered: `supabase`, `figma`, `patchright`. `CLAUDE.md` points memory at
`~/.claude/projects/-Users-arnav/`; the real path is `-Users-arnavramidi`.

Two repos — `claude-code-setup` and `claude-code-configuration` — carry ~90% identical
content and disagree with each other.

---

## 2. Evidence from real work

The redesign is grounded in two of Arnav's repos rather than in principle.

### 2.1 Token discipline does not predict satisfaction

Identical measurements across a project Arnav is happy with and one he is not:

| | salesroom (happy) | job-apply-agent (unhappy) |
|---|---|---|
| components (non-test) | 81 | 38 |
| arbitrary `text-[Npx]` | 2.3 / component | 4.7 / component |
| raw palette utilities | 6.3 / component | 10.9 / component |
| brand-token uses | 0.05 / component | 2.4 / component |
| shadcn/ui primitives | 13 | 0 |

The project Arnav likes barely uses its own design tokens. The project he dislikes uses them
48× more per component and has the richer token file. **Design-token drift is real but is
not the cause of his dissatisfaction**, so a token lint was considered and rejected.

### 2.2 The real failure was product judgment, and the heavy process did not catch it

`job-apply-agent/docs/2026-08-12-old-vs-new-ui-ledger.md` records Arnav's actual complaints:
*"you got rid of the pending queue"* and *"the all-jobs list is garbage."* Neither is about
appearance. A structural rework deleted a persistent, URL-addressable queue page and replaced
it with a 288px popover that closes on outside click, and swapped a curated top-5 live ledger
on Home for a ~4,400-row list with many deliberately inert rows.

That rework ran the full pipeline: a brainstorm spec, an SDD ledger, 22 commits, 35 files,
+1,882/−991 lines. Tests passed — the e2e specs were *retargeted* from the queue page to the
popover in `e5b675a`, so they went green by agreeing with the change.

Two general lessons, both adopted below:

- A reviewer that checks work against the spec cannot catch a wrong spec. It approves a
  faithful build of the wrong thing.
- A test rewritten to match new behavior converts a regression into a passing build.

### 2.3 The custom agents are aimed at a stack Arnav does not use

`job-apply-agent` is TypeScript: Hono, better-sqlite3, patchright, Google Gemini, Vite 8,
React 19, Tailwind v4, TypeScript 6.0, oxlint, vitest. `backend-implementer` opens by
mandating Postgres schema inspection and Prisma 7 / Next.js 16 verification. Dispatched
there it performs worse than a generic agent. The repo also has no project-level
`CLAUDE.md`, so every rule applied to it is global and stack-blind.

Corollary: the very recent majors in that stack make `context7` the highest-value MCP in
the setup, not an optional one.

---

## 3. Design

### Section 1 — Enforcement architecture

**Principle: enforcement fires on events, never per turn, and reports live state rather than
asserting static policy.**

The current hook is 500 tokens of instruction and zero tokens of fact. It tells Claude what
it *should* do and nothing about what is *true*. That inversion is the core defect: Claude
cannot know which MCPs are alive, and static text cannot report it. This is an information
problem, not a discipline problem, and it is the one thing here that genuinely requires a
hook.

**One script, `tooling-context.sh`, wired to three matchers:**

| Trigger | Content | Blocks? |
|---|---|---|
| `PreToolUse` → `Skill`, filtered to `superpowers:brainstorming` | live MCP health only (~60 tok) | no |
| `PreToolUse` → `Skill`, filtered to `superpowers:writing-plans` | live MCP health + per-task tool reconciliation (~250 tok) | no |
| First `TodoWrite` of a session | one-line nudge (~80 tok) | no |

Rationale for the split by content, not just timing:

- **Brainstorm-time** shapes what gets *proposed*. Knowing Magic is dead prevents designing
  an approach around pulling six 21st.dev patterns, and prevents offering mockups that
  cannot be sourced. By plan time this is too late — the design is already agreed.
- **Plan-time** shapes *per-task assignment*: which step needs context7, which needs a schema
  read, which needs nothing. This is where the old hook's substantive content now lives.
- **First TodoWrite** covers real multi-step work that skipped both. Pure conversation never
  produces a todo list, so this never fires on chat.

**Verified mechanics (live experiment + docs, 2026-08-19).** Plain stdout from a
`PreToolUse` hook never reaches the model — it goes to the debug log. JSON
`hookSpecificOutput.additionalContext` reaches the model verbatim (confirmed by a canary
experiment in a throwaway project, corroborated by the hooks reference; also supported on
`PostToolUse`). **Every trigger MUST therefore emit JSON `additionalContext`** — a plain
`echo` port of the old hook would silently do nothing.

**Live state is cached, and never injected raw.** `claude mcp list` takes ~12 s measured
(it health-checks every server) and **prints API keys in plaintext**. `tooling-context.sh`
caches a *parsed* name + status table — never the raw output — to a `chmod 600` file with
a 1-hour TTL; all three triggers read the cache, and the brainstorm trigger refreshes it
when stale (one accepted ~12 s stall per hour, at brainstorm time).

**"First TodoWrite of a session" is tracked by a per-session marker file** keyed on the
session id supplied to the hook on stdin. No per-session hook directory is documented, so
markers are written to `$TMPDIR/claude-hook-markers/<session_id>`, and each run deletes
markers older than two days so they cannot accumulate.

**"No MCPs needed, because X" is a first-class valid answer** at the plan trigger. Without
this the reconciliation degrades into tool-theater — tool steps attached to tasks that do
not need them, which is the current disease relocated into a document.

**Nothing blocks.** A blocking gate was designed and rejected. Two variants were considered
and dropped:

- *Gate the Write call.* Rejected on quality, not efficiency: by the time Claude has drafted
  150 lines of JSX, that draft anchors it. Forcing a pattern pull afterwards produces a
  patch-up of the guess rather than a clean use of the pattern. The gate would fire at the
  exact moment it can no longer produce the intended outcome.
- *Block the plan-file write if it lacks a tooling section.* Rejected on risk. Hooks that
  only print fail safe — a broken script prints nothing and work continues. A blocking hook
  with a buggy matcher jams the session. It was also the least valuable of the three, since
  the earlier triggers already put the tooling picture in view.

**Deleted:** `tooling-audit.sh`, `subagent-dispatch-audit.sh`.

**Result:** ~22,000 tok/session → ~500 tok/session. The two per-turn/per-dispatch audit
scripts are replaced by two event-driven ones: `tooling-context.sh` (this section) and the
test-retargeting hook (§3 rule 2, ~40 tok only when an existing test is edited).

**To verify during implementation, not assume:** whether the `Skill` matcher fires when a
skill is invoked as a slash command rather than through the Skill tool — the docs are
explicitly ambiguous on this (checked 2026-08-19). If it does not, the TodoWrite trigger
still covers the work. Arnav does not use `/brainstorm`, so this is low-stakes either way.

### Section 2 — MCP inventory

Global registrations drop from 11 to 4.

**Keep globally:** `context7`, `chrome-devtools`, `playwright`, `consensus`.
(`claude-in-chrome` is the Chrome extension, not a config entry.)

**Drop, replaced by native tools:**

- `github` → the `gh` CLI. The registered server is the archived reference implementation.
  Every GitHub operation in the audit — repo listing, cloning, tree reads — was done with
  `gh` without a server, OAuth, or a tool slot. The MCP's advantage is structured PR-review
  calls, which `gh api` covers.
- `brave-search` → native `WebSearch` / `WebFetch`. Archived package; all searches during
  the audit used the native tools successfully.

**Drop, broken or unused:** `linear` (dead transport, no evidence of use), `sentry` and
`vercel` (never authenticated, no matching project), `huggingface` (never authenticated).

**Remove globally, re-register per project:** `postgres`. It is pointed at a placeholder
connection string, so any "schema verified" claim it could support is fiction. It is also
the archived reference server with a known SQL-injection issue. It belongs inside a repo
that has a database, with a real URL and a maintained server.

**Documentation corrections:** drop `figma` (no evidence of use); make `supabase` a real
per-project registration (the Tauri to-do app uses it); keep `patchright` as a per-project
note (job-apply-agent depends on it).

**Magic (21st.dev):** dropped as a global mandate. Retrieval is not what fixes Arnav's UI
complaints (§2.1, §2.2), and an external pattern source imports a foreign design vocabulary
into a themed codebase. If component retrieval is wanted later, shadcn's own MCP
(`pnpm dlx shadcn@latest mcp init --client claude`) reads the project's own
`components.json` and registries, so it does not introduce outside tokens.

### Section 3 — Avoiding confidently-wrong large changes

Constraints set by Arnav, which rule out the obvious mechanisms:

- No mid-build checkpoints. Work must complete without him popping in to review.
- Specs are skimmed or unread, so "write the removal in the spec" is not a mechanism.
- Global fixes only; `job-apply-agent` is evidence, not scope, and must not be edited.

Accepted trade-off, stated plainly: with no checkpoint and no spec reading, nothing can ask
"is this right?" before it lands. These rules reduce the blast radius and close the specific
holes that let §2.2 happen; they do not reduce risk to zero.

**Considered and rejected:** an *additive-by-default* rule (never delete a working surface
during a rework) — rejected by Arnav. A design-token lint — rejected on evidence (§2.1).

**Adopted:**

1. **Reviewers check against prior behavior, not only the spec.** The review rubric gains a
   second question: *what did this change remove or relocate that nobody asked about?* This
   requires reading the diff against prior behavior, not just the acceptance criteria. It is
   the only mechanism that can catch a faithful build of a wrong spec, and it costs Arnav
   nothing.
2. **Test retargeting is a flagged event — enforced by a hook, not by honor.** A
   `PostToolUse` hook matching Edit/Write on existing test files (`*.test.*`, `*.spec.*`,
   `__tests__/`) injects one line via `additionalContext`: *"existing test modified — if
   expectations were rewritten to match new behavior, state that explicitly in the summary
   as a retargeted test, never folded into 'tests updated'."* Costs ~40 tok per test edit.
   Rationale: the §2.2 failure was an agent quietly retargeting tests; asking that same
   agent to self-report is the honor system this spec argues against (§ Section 1).
   Adjacent to the existing `prove_the_guard_fails` memory.
   Rules 1 and 3 stay prompt text deliberately: they are role rubrics with no event to
   attach to, and each lives in exactly one file (the reviewer and implementer agents).
3. **Agents detect the stack instead of assuming one.** Agent instructions begin by reading
   `package.json` (or the equivalent manifest) and adapting, rather than naming Prisma,
   Next.js, or Postgres up front.

### Section 4 — Subagents and plugins

**Four custom subagents collapse to two:** one `implementer`, one `reviewer`.

The frontend/backend split existed because each role needed different MCP grants, and
enumerating `tools:` was the only way to give a subagent MCP access. Subagents now inherit
by default, so the split buys nothing and the frontmatter has inverted into a cage. What
genuinely differs between the pairs is the review rubric — accessibility and visual checks
versus schema and API checks — which is a paragraph, not a separate file.

Both new agents:

- carry **no `tools:` frontmatter** (inherit everything)
- **read the manifest first** and adapt to the real stack (§3 rule 3)
- name no specific framework in their instructions

The reviewer additionally keeps `model: opus` and gains the prior-behavior question (§3
rule 1) and the test-retargeting flag (§3 rule 2).

Accepted cost: a specialized prompt focuses better than a general one. Two files that stay
accurate beat four that go stale, which is the failure being cleaned up.

**Plugins:**

| Plugin | Action | Why |
|---|---|---|
| `superpowers` | keep | the process spine |
| `frontend-design` | keep | the remaining source of design direction now that Magic is gone |
| `andrej-karpathy-skills` | keep | ~900 chars, one skill, referenced by existing feedback memory |
| `i-have-adhd` | keep | with the style conflict below resolved |
| `warp` | keep | confirmed in use |
| `huggingface-skills` | **remove** | 26 skills (~3,200 tok measured), largest block in session context, no ML work in rotation; also bundles an MCP server that reports "needs authentication," so removal is a dependency of success criterion 1 |
| `rust-analyzer-lsp` | **remove** | confirmed not in use |
| `learning-output-style` | **remove entry** | already `false`; a disabled entry is noise |

**Style-ownership conflict, resolved.** Three sources currently instruct response style and
two disagree on length: `CLAUDE.md` ("stay technical, no length limit"), the `i-have-adhd`
plugin ("~150–250 words, cap lists at five"), and `feedback_lead_with_the_point.md`
(duplicate of the plugin).

Resolution: **the ADHD plugin owns response shape** (length, structure, no preamble).
**`CLAUDE.md` owns explanation quality** (plain language first, define terms on first use,
state trade-offs as what-happens / what-it-buys / what-it-costs). The `CLAUDE.md` style
section is cut to explanation quality only, and `feedback_lead_with_the_point.md` is deleted
as a third copy.

### Section 5 — CLAUDE.md, memory, and repo sync

**5a. CLAUDE.md rewrite** — target ~1,800 bytes, from ~3,900.

Removed:

- *Tool routing table.* Static list of ten servers, now reported live by the hooks. Keeping
  both guarantees one is stale. Replaced by the principle in one line: never assert external
  state that could have been looked up — library APIs via context7, rendered UI via a
  browser, schema via the real database.
- *Memory section.* File-based memory is a native harness feature with its own loaded
  instructions. The section duplicates it and its path is wrong.
- *Communication style,* cut to explanation quality only (see §4).

Retained: main thread stays Opus; the verification expectation, **reworded to principle
form** ("verify against the real database / the rendered UI / a test run") — as currently
written it names `mcp__postgres__*`, which §2 removes globally, and would violate success
criterion 3 on day one.

Added: the subagent model-tiering table, relocated from the deleted dispatch hook; the three
rules from §3.

**5b. Memory prune** — index target under ~800 tok, from ~1,860.

Rule rather than a 38-file review: project memories for shipped or abandoned work move to an
`archive/` subfolder that `MEMORY.md` does not index. The index retains active projects plus
all `feedback` and `reference` files, which stay durable regardless of age. Implementation
proposes the archive list; Arnav vetoes rather than selects.

**5c. Repo/machine coupling.**

`~/.claude` becomes the git checkout itself, with `claude-code-configuration` as its remote.
`git status` becomes the drift detector and there is no copy step to forget. This is the only
option considered where drift cannot occur silently.

Migration order, explicit (state verified 2026-08-19: `~/.claude` is not yet a git repo;
`claude-code-setup` is not yet archived):

1. `git init` in `~/.claude`, add the `claude-code-configuration` remote, write the
   default-deny `.gitignore` **before** the first `git add`, reconcile against the remote.
2. Delete the `~/claude-code-configuration` working clone once merged — one local checkout
   only, or a third copy of the truth replaces the two being eliminated.
3. Archive `claude-code-setup` on GitHub.
4. Verify whether `CLAUDE.md` double-loads when the working directory is `~/.claude` itself
   (its user-global and project roles collapse into one file there). Harmless if it does,
   but it should be known, not assumed.

`.gitignore` is **default-deny**: ignore everything, then explicitly allow `CLAUDE.md`,
`settings.json`, `hooks/`, `agents/`, `commands/`, `docs/`, `README.md`. Files added to
`~/.claude` later cannot leak by default.

`claude-code-setup` is archived on GitHub. Two ~90% identical repos is the mechanism that
produced two versions of the truth.

**Two live pieces the repo does not currently carry, which the sync must pick up:**

- `hooks/ntfy-notify.sh` — the real `Stop` and `Notification` handlers. The repo documents
  `osascript` inline commands that were replaced. Retained as-is and documented.
- The `consensus` MCP registration, live but absent from `docs/mcp-servers.md`.

**`commands/spec.md` needs a decision during implementation.** Its Step 5 references
`@_specs/template.md`, a project-local file that is not present in any current repo, and it
writes specs to `_specs/` while `superpowers:brainstorming` writes to
`docs/superpowers/specs/`. Either reconcile it with the superpowers path convention or
retire it as superseded by `brainstorming` → `writing-plans`.

**Blocking precondition — secret hygiene.** The live `settings.json` contains an
`autoMode.environment` block describing a work project that processes real client data. That is
client-adjacent work data and must be stripped, or the block excluded, before anything is
committed or pushed.
Separately, the dead 21st.dev API key in `~/.claude.json` should be rotated at the provider
rather than merely replaced locally.

---

## 4. Out of scope

- Any edit to the `job-apply-agent` repo, including its missing project `CLAUDE.md`. Arnav
  will handle that separately on another machine.
- Adding shadcn primitives to `job-apply-agent` (a multi-day migration, and the least
  connected to his actual complaints).
- Per-project `postgres` / `supabase` registrations. Documented here; performed inside those
  repos when the work occurs.
- A design-token lint (rejected on evidence, §2.1).
- Additive-by-default surface preservation (rejected by Arnav, §3).
- Mid-build screenshot checkpoints (rejected by Arnav, §3).

## 5. Success criteria

1. `claude mcp list` reports zero failing or unauthenticated servers, including
   plugin-bundled ones (removing `huggingface-skills` is a dependency of this criterion).
2. Session context from the four §1.3 sources only (per-turn hook, per-dispatch hook,
   huggingface skill descriptions, MEMORY.md index) drops from ~25,000 tok to under
   ~2,500 tok per 40-turn session: ~500 tooling-context, ≤800 MEMORY.md, zero per-turn and
   per-dispatch. SessionStart payloads from kept plugins (superpowers ~800 tok,
   `i-have-adhd` ~1,650 tok, measured 2026-08-19) are explicitly out of scope — they are
   owned by plugins this redesign chose to keep.
3. No hook, agent, or `CLAUDE.md` line names a tool that is not registered and connected.
4. `git status` in `~/.claude` is clean, and the GitHub repo's contents match the machine
   file-for-file for every allowlisted path.
5. `git log -p` over the new repo contains no credentials and no client work data.
6. Both new subagents run cleanly in a non-Next.js, non-Prisma repo without referencing
   absent tooling.
