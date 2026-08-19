# Hooks

Hooks are shell scripts the Claude Code CLI runs automatically at specific points in a
session (e.g. right before a tool call, or when a response finishes). They can't be
replicated by asking Claude to "remember" something — the harness runs them, not the
model — so they're the only reliable way to force a behavior to happen every single time.

`~/.claude/hooks/` holds 3 wired hooks (`tooling-context.sh`, `retarget-flag.sh`,
`ntfy-notify.sh`) plus 2 test scripts for the two logic-bearing ones
(`test-tooling-context.sh`, `test-retarget-flag.sh`) — 5 files total, 3 of which are
actually referenced in the `hooks` block of `settings.json` (copy at the repo root).
They're user-scoped, so the 3 wired hooks apply to every project, not just one repo. This
redesign moved every hook from `UserPromptSubmit` (fires on every prompt, whether relevant
or not) to event-specific triggers (`PreToolUse` on the specific tool call that needs the
nudge, `PostToolUse` on the specific edit that needs the flag) — cheaper per session and
harder to tune out.

**Verified fact governing every hook here:** a `PreToolUse` hook's plain stdout never
reaches the model. Only structured JSON on stdout —
`{"hookSpecificOutput":{"hookEventName":"...","additionalContext":"..."}}` — actually gets
injected as context. This was live-verified on 2026-08-19: a hook that just `echo`ed text
produced no visible effect on the model's context at all. Every hook below that needs to
say something to Claude emits this JSON shape and nothing else.

## 1. `tooling-context.sh` — `PreToolUse` (matchers: `Skill`, `TodoWrite`)

**Fires on three triggers**, all `PreToolUse`:

1. `Skill` invoked as `superpowers:brainstorming` — before design work starts, inject live
   MCP health so proposals get shaped around servers that actually work.
2. `Skill` invoked as `superpowers:writing-plans` — before a plan gets written, inject the
   same health table plus a reminder to do per-task tool reconciliation (state which live
   tool verifies each task, or explicitly say "no MCPs needed, because...").
3. `TodoWrite` — on the *first* todo list of a session only (guarded by a marker file, see
   below), a lighter nudge to check the cached health table before assuming an MCP works.

**One caveat, verified 2026-08-19:** the `Skill` matcher does **not** fire when a skill is
invoked as a slash command (e.g. typing `/spec` rather than the model calling the `Skill`
tool with `brainstorming`). The `TodoWrite` trigger is the designed fallback for that case
— most real work eventually writes a todo list even when it entered through a slash
command, so the nudge still lands, just later.

**Cache contract:** live MCP health is expensive to compute on every trigger (`claude mcp
list` takes several seconds), so it's cached to `~/.claude/cache/mcp-health.txt` with a
1-hour TTL. The cache holds **only** `name: symbol` lines (e.g. `context7: ✔`) — never the
raw `claude mcp list` output, because that output prints API keys and connection strings
in plaintext for stdio/HTTP servers. The parser is a strict `sed` allowlist: `-n` plus a
trailing `/p` means only lines that fully match the `name: symbol` pattern are ever
written; anything else (banner text, blank lines, malformed rows) is silently dropped, not
passed through. The cache file is `chmod 600`.

**JSON-only rule:** every code path in this script that wants to reach the model emits the
structured `hookSpecificOutput.additionalContext` JSON described above via a shared `emit`
function, and the script `exit 0`s on every path (including when nothing needs to be said)
so it never blocks a tool call.

**Marker files:** the `TodoWrite` trigger only fires once per session — it touches
`${TMPDIR:-/tmp}/claude-hook-markers/tooling-nudge-<session_id>` and checks for that file's
existence before emitting again. Markers older than 2 days are pruned on every run so the
directory doesn't grow unbounded.

## 2. `retarget-flag.sh` — `PostToolUse` (matcher: `Edit|Write`)

**Fires:** right after an `Edit` or `Write` call completes, but only acts when the touched
file path matches a test-file pattern (`*.test.*`, `*.spec.*`, `__tests__/`).

**What it does:** injects one line of `additionalContext`: *"existing test modified — if
expectations were rewritten to match new behavior, state that explicitly in the summary as
a retargeted test, never folded into 'tests updated.'"*

**Why it exists:** a prior real failure was an agent quietly rewriting a test's
expectations to match new (wrong) behavior and reporting "tests updated" as if that were a
pass. Asking the same agent to self-report that after the fact is the honor system this
whole hook file exists to avoid — an event-triggered reminder at the moment of the edit
does better than a rule stated once in a prompt and hoped to be remembered.

## 3. `ntfy-notify.sh` — `Notification` and `Stop`

**Fires:** `Notification` when Claude is blocked waiting on you (e.g. a permission
prompt); `Stop` when Claude finishes responding.

**What it does:** pushes a phone notification via ntfy.sh *and* a macOS desktop banner via
`osascript`, both carrying the harness's notification message (or a generic fallback like
"Claude Code: Stop" if none is given). This replaces an earlier version that used inline
`osascript` commands directly in `settings.json` — those examples are gone; the
notification logic now lives in this one script so both channels (phone + desktop) stay in
sync instead of drifting apart.

**Topic storage, corrected 2026-08-19:** the ntfy.sh topic is **not** baked into the
script. It's read at runtime from `~/.claude/ntfy-topic` (plain text, one line, `chmod
600`, untracked — excluded by the repo's default-deny `.gitignore`) via `TOPIC=$(cat
"$HOME/.claude/ntfy-topic" 2>/dev/null); [ -z "$TOPIC" ] && exit 0`. ntfy.sh topics are
unauthenticated pub/sub — anyone who knows the topic string can publish or subscribe to
it — so a topic baked into a script in a *public* repo is a live leak, not just a stale
credential. The original topic was committed in plaintext in an earlier version of this
script; it was rotated on 2026-08-19 (new value lives only in the untracked topic file) and
scrubbed from this repo's git history as part of that fix.

**Why it exists:** useful if you run long agentic sessions in a background terminal tab and
don't want to babysit it — the phone push means you don't have to be at the desk to notice
Claude is blocked or done.

## Hook wiring reference

| Hook | Event | Matcher |
|---|---|---|
| `tooling-context.sh` | `PreToolUse` | `Skill`, `TodoWrite` |
| `retarget-flag.sh` | `PostToolUse` | `Edit\|Write` |
| `ntfy-notify.sh` | `Notification` | — |
| `ntfy-notify.sh` | `Stop` | — |

`test-tooling-context.sh` and `test-retarget-flag.sh` are the test scripts for the two
logic-bearing hooks above — not wired into `settings.json` themselves, run by hand or in CI
to check the JSON-emission and marker-file behavior before trusting a change to either
script.
