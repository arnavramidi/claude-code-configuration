# Claude Code Setup Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the per-turn static tooling hooks with event-driven live-state hooks, shrink the MCP/plugin inventory to what works, collapse four stale agents into two stack-agnostic ones, rewrite CLAUDE.md, prune memory, and make `~/.claude` the git checkout of `claude-code-configuration`.

**Architecture:** Live machine changes first (secrets, MCP registrations, plugins, hooks, agents, CLAUDE.md, memory), then the repo clone is synced to match the machine, then `~/.claude` adopts the repo as its own checkout so `git status` becomes the drift detector.

**Tech Stack:** bash hooks (jq), Claude Code settings.json hook wiring, git, gh CLI. No application code.

**Spec:** `docs/superpowers/specs/2026-08-19-claude-setup-redesign-design.md` (rev 2, evidence-verified)

## Global Constraints

- **BLOCKING:** no commit or push anywhere until Task 1 (secret hygiene) is complete.
- Hooks reach the model ONLY via JSON `hookSpecificOutput.additionalContext`. Plain stdout goes to the debug log. Never `echo` context.
- Never write raw `claude mcp list` output anywhere the model or git can see it — it prints API keys in plaintext. Cache parsed name+status only, `chmod 600`.
- Nothing blocks: every new hook exits 0 on every path, including parse failures. A broken hook must print nothing and let work continue.
- `job-apply-agent` and every other project repo is out of scope. Only `~/.claude`, `~/claude-code-configuration`, and GitHub repo settings are touched.
- Machine paths are literal: user is `arnavramidi` (not `arnav`).
- The four old agent names (`frontend-implementer`, `frontend-reviewer`, `backend-implementer`, `code-reviewer`) and the two old audit hooks must not survive anywhere: machine, repo, or docs.

---

### Task 1: Secret hygiene (blocking precondition)

**Files:**
- Modify: `~/.claude/settings.json` (delete the `autoMode` key)
- Modify: `docs/superpowers/specs/2026-08-19-claude-setup-redesign-design.md` (redact one line)
- Git surgery: squash the two unpushed commits on `redesign/2026-08-19-setup-overhaul`

**Interfaces:**
- Produces: a settings.json and a branch history that are safe to publish. Every later task assumes this.

- [ ] **Step 1: Back up and strip `autoMode` from live settings**

```bash
cp ~/.claude/settings.json ~/.claude/backups/settings.json.pre-redesign-$(date +%Y%m%d)
python3 - <<'EOF'
import json
p = "/Users/arnavramidi/.claude/settings.json"
s = json.load(open(p))
s.pop("autoMode", None)
json.dump(s, open(p, "w"), indent=2)
EOF
```

`~/.claude/backups/` is outside the future gitignore allowlist, so the backup can never be committed.

- [ ] **Step 2: Verify the strip**

Run: `python3 -c "import json; s=json.load(open('/Users/arnavramidi/.claude/settings.json')); print('autoMode' in s)"`
Expected: `False`

- [ ] **Step 3: Redact the client-data specifics in the spec**

In `docs/superpowers/specs/2026-08-19-claude-setup-redesign-design.md`, §5c "Blocking precondition" paragraph: replace the parenthetical that names a specific CSV filename and row count with the generic phrase `real client claims data from a work project`. The precondition's meaning survives; the identifying detail does not.

- [ ] **Step 4: Squash the unpushed branch history so the redacted string never publishes**

The identifying string exists only in the two unpushed commits on this branch (verified 2026-08-19: a pickaxe search for the identifying filename token matches only `9c90bdd`; the branch has never been pushed).

```bash
cd ~/claude-code-configuration
git add docs/superpowers/specs/2026-08-19-claude-setup-redesign-design.md
git reset --soft main
git commit -m "Add setup-redesign spec (rev 2, evidence-verified, redacted)"
```

- [ ] **Step 5: Verify history is clean**

Run a pickaxe search (`git log --all -S <identifying-filename-token> --oneline | wc -l`) and a second one for the row-count token. Both must return `0`.
Expected: `0` and `0`

- [ ] **Step 6: Record the one manual item**

Add to the final report for Arnav: **rotate the 21st.dev API key at https://21st.dev/mcp** — the dead key was printed by `claude mcp list` and lives in `~/.claude.json`; local deletion (Task 2) does not rotate it at the provider.

---

### Task 2: MCP inventory cleanup (11 → 4 global)

**Files:**
- Modify: `~/.claude.json` (via `claude mcp remove`, never by hand-editing)

**Interfaces:**
- Produces: exactly four global servers — `context7`, `chrome-devtools`, `playwright`, `consensus` — all reporting Connected. Task 4's health cache and criterion 1 depend on this.

- [ ] **Step 1: Remove the seven dropped registrations**

```bash
for s in magic postgres linear sentry vercel github brave-search; do
  claude mcp remove "$s"
done
```

If any name errors with "No MCP server found", check `claude mcp list` for its actual scope (`-s user` vs `-s local`) and re-run with that flag. `huggingface` is plugin-bundled and is removed by Task 3, not here.

- [ ] **Step 2: Verify (criterion 1, partial)**

Run: `claude mcp list`
Expected: exactly `context7`, `chrome-devtools`, `playwright`, `consensus`, plus `plugin:huggingface-skills` (goes away in Task 3). All four keepers show `✔ Connected`. Nothing shows `✘` .

---

### Task 3: Plugin cleanup

**Files:**
- Modify: `~/.claude/settings.json` (`enabledPlugins` block)

**Interfaces:**
- Produces: `enabledPlugins` containing exactly five true entries: `frontend-design@claude-plugins-official`, `superpowers@claude-plugins-official`, `warp@claude-code-warp`, `andrej-karpathy-skills@karpathy-skills`, `i-have-adhd@i-have-adhd`. Task 9 copies this file into the repo.

- [ ] **Step 1: Remove the three entries**

```bash
python3 - <<'EOF'
import json
p = "/Users/arnavramidi/.claude/settings.json"
s = json.load(open(p))
for k in ["huggingface-skills@claude-plugins-official",
          "rust-analyzer-lsp@claude-plugins-official",
          "learning-output-style@claude-plugins-official"]:
    s["enabledPlugins"].pop(k, None)
json.dump(s, open(p, "w"), indent=2)
EOF
```

- [ ] **Step 2: Verify the plugin MCP and skills are gone (criterion 1, complete)**

Run: `claude mcp list` — expected: exactly the four keepers, all `✔ Connected`, no `plugin:` entries, nothing failing or unauthenticated.
Run: `echo "List every skill name you can invoke, one per line, nothing else" | claude -p --model haiku | grep -ci huggingface` — expected: `0`.

---

### Task 4: `tooling-context.sh` — the event-driven hook

**Files:**
- Create: `~/.claude/hooks/tooling-context.sh`
- Modify: `~/.claude/settings.json` (hooks block)
- Delete: `~/.claude/hooks/tooling-audit.sh`, `~/.claude/hooks/subagent-dispatch-audit.sh`
- Test: `~/.claude/hooks/test-tooling-context.sh` (kept next to the hook; it is the regression test)

**Interfaces:**
- Consumes: hook stdin JSON with `session_id`, `tool_name`, `tool_input.skill`.
- Produces: JSON `{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:"…"}}` on the three trigger paths, nothing otherwise. Cache file `~/.claude/cache/mcp-health.txt` (mode 600, `name: ✔|✘|!` lines). Marker dir `$TMPDIR/claude-hook-markers/`.

- [ ] **Step 1: Write the failing test**

Create `~/.claude/hooks/test-tooling-context.sh`:

```bash
#!/bin/bash
# Regression test for tooling-context.sh. Run: bash test-tooling-context.sh
set -u
H="$HOME/.claude/hooks/tooling-context.sh"
MD="${TMPDIR:-/tmp}/claude-hook-markers"
pass=0; fail=0
check() { # $1 desc, $2 expected-grep (empty means expect no output), $3 stdin
  out=$(printf '%s' "$3" | bash "$H")
  if [ -z "$2" ]; then
    [ -z "$out" ] && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1 (got: $out)"; fail=$((fail+1)); }
  else
    printf '%s' "$out" | grep -q "$2" && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null \
      && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1 (got: $out)"; fail=$((fail+1)); }
  fi
}
rm -f "$MD/tooling-nudge-testsess"
# Seed a fake cache so tests never invoke the real 12s `claude mcp list`
mkdir -p "$HOME/.claude/cache"
printf 'context7: ✔\nchrome-devtools: ✔\n' > "$HOME/.claude/cache/mcp-health.txt"
touch "$HOME/.claude/cache/mcp-health.txt"   # fresh mtime → no refresh
check "brainstorm trigger emits health" "MCP health" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:brainstorming"}}'
check "plan trigger emits reconciliation" "no MCPs needed" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:writing-plans"}}'
check "other skills emit nothing" "" \
  '{"session_id":"testsess","tool_name":"Skill","tool_input":{"skill":"superpowers:systematic-debugging"}}'
check "first TodoWrite nudges" "First todo list" \
  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check "second TodoWrite is silent" "" \
  '{"session_id":"testsess","tool_name":"TodoWrite","tool_input":{}}'
check "malformed stdin exits silently" "" 'this is not json'
echo "== $pass passed, $fail failed"; exit $fail
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash ~/.claude/hooks/test-tooling-context.sh`
Expected: every check FAILs (hook does not exist yet).

- [ ] **Step 3: Write the hook**

Create `~/.claude/hooks/tooling-context.sh`:

```bash
#!/bin/bash
# tooling-context.sh — event-driven tooling context (spec Section 1, rev 2).
# Fires on PreToolUse:Skill (brainstorming / writing-plans) and PreToolUse:TodoWrite.
# CONTRACT: emits JSON additionalContext only (plain stdout never reaches the model);
# exits 0 on every path; never emits raw `claude mcp list` output (it contains API keys).
set -u
INPUT=$(cat)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null) || exit 0
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null) || exit 0
SKILL=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // ""' 2>/dev/null) || exit 0

MARKER_DIR="${TMPDIR:-/tmp}/claude-hook-markers"
mkdir -p "$MARKER_DIR" 2>/dev/null
find "$MARKER_DIR" -type f -mtime +2 -delete 2>/dev/null

CACHE="$HOME/.claude/cache/mcp-health.txt"
CACHE_TTL=3600

emit() {
  jq -cn --arg ctx "$1" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",additionalContext:$ctx}}' 2>/dev/null
  exit 0
}

refresh_cache_if_stale() {
  local now mtime age=999999
  now=$(date +%s)
  [ -f "$CACHE" ] && mtime=$(stat -f %m "$CACHE" 2>/dev/null) && age=$((now - mtime))
  if [ "$age" -ge "$CACHE_TTL" ]; then
    mkdir -p "$(dirname "$CACHE")" 2>/dev/null
    # Parse to name+status ONLY — the raw output prints API keys in plaintext.
    claude mcp list 2>/dev/null \
      | grep -E ' - (✔|✘|!)' \
      | sed -E 's/^([^:]+):.* - (✔|✘|!).*/\1: \2/' > "$CACHE.tmp" 2>/dev/null \
      && mv "$CACHE.tmp" "$CACHE"
    chmod 600 "$CACHE" 2>/dev/null
  fi
}

health_block() {
  if [ -s "$CACHE" ]; then
    printf 'Live MCP health (✔ connected, ✘ failed, ! needs auth; cached ≤1h):\n%s' "$(cat "$CACHE")"
  else
    printf 'Live MCP health: unavailable — do not assert any MCP is reachable without trying it.'
  fi
}

case "$TOOL_NAME" in
  Skill)
    case "$SKILL" in
      superpowers:brainstorming|brainstorming)
        refresh_cache_if_stale
        emit "$(health_block)

Shape proposals around tools that are actually alive. Do not design an approach around a server marked ✘ or !."
        ;;
      superpowers:writing-plans|writing-plans)
        refresh_cache_if_stale
        emit "$(health_block)

Per-task tool reconciliation: for each task, state which live tool verifies it — context7 for library APIs, a browser for rendered UI, the project's real database for data claims — or state 'no MCPs needed, because <reason>'. That is a first-class valid answer; do not attach tool steps to tasks that do not need them."
        ;;
    esac
    ;;
  TodoWrite)
    MARKER="$MARKER_DIR/tooling-nudge-$SESSION_ID"
    if [ ! -f "$MARKER" ]; then
      touch "$MARKER" 2>/dev/null
      emit "First todo list this session: if any task assumes an MCP, check the cached health table at ~/.claude/cache/mcp-health.txt before relying on it, and verify external claims with live tools rather than memory."
    fi
    ;;
esac
exit 0
```

Then: `chmod +x ~/.claude/hooks/tooling-context.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash ~/.claude/hooks/test-tooling-context.sh`
Expected: `== 6 passed, 0 failed`

- [ ] **Step 5: Verify cache refresh + permissions against the real `claude mcp list`**

```bash
rm -f ~/.claude/cache/mcp-health.txt
printf '%s' '{"session_id":"t2","tool_name":"Skill","tool_input":{"skill":"superpowers:brainstorming"}}' \
  | bash ~/.claude/hooks/tooling-context.sh | jq -r '.hookSpecificOutput.additionalContext'
ls -l ~/.claude/cache/mcp-health.txt
grep -c 'sk_\|api\|key\|npx\|http' ~/.claude/cache/mcp-health.txt || true
```

Expected: a ~12 s run, then a four-line health table in the context; file mode `-rw-------`; the grep finds 0 lines (no URLs, commands, or keys survived parsing — only `name: status`).

- [ ] **Step 6: Rewire settings.json and delete the old hooks**

```bash
python3 - <<'EOF'
import json
p = "/Users/arnavramidi/.claude/settings.json"
s = json.load(open(p))
h = s["hooks"]
h.pop("UserPromptSubmit", None)
h["PreToolUse"] = [
  {"matcher": "Skill",     "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/tooling-context.sh"}]},
  {"matcher": "TodoWrite", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/tooling-context.sh"}]},
]
json.dump(s, open(p, "w"), indent=2)
EOF
rm ~/.claude/hooks/tooling-audit.sh ~/.claude/hooks/subagent-dispatch-audit.sh
```

(`Notification` and `Stop` ntfy entries are untouched.)

- [ ] **Step 7: End-to-end canary through a real session**

Run: `echo "Invoke the Skill tool with skill superpowers:brainstorming, then quote verbatim any hook-injected context you received about MCP health. Do not act on the skill instructions further." | claude -p --model haiku`
Expected: the reply quotes the health table lines. This proves the wiring, not just the script.

- [ ] **Step 8: Probe the slash-command ambiguity (spec's open verify item)**

Run: `printf '/simplify\n' | claude -p --model haiku 2>&1 | head -20`, then check whether a fresh fire marker appeared: `ls "${TMPDIR:-/tmp}/claude-hook-markers/"`.
Record the answer either way in the final report — if slash commands bypass the `Skill` matcher, the TodoWrite trigger is the accepted fallback (spec says low-stakes).

---

### Task 5: `retarget-flag.sh` — test-retargeting event hook

**Files:**
- Create: `~/.claude/hooks/retarget-flag.sh`
- Modify: `~/.claude/settings.json` (add `PostToolUse` block)
- Test: `~/.claude/hooks/test-retarget-flag.sh`

**Interfaces:**
- Consumes: PostToolUse stdin JSON with `tool_input.file_path`.
- Produces: JSON `additionalContext` when the path matches `*.test.*`, `*.spec.*`, or `*__tests__*`; nothing otherwise.

- [ ] **Step 1: Write the failing test**

Create `~/.claude/hooks/test-retarget-flag.sh`:

```bash
#!/bin/bash
set -u
H="$HOME/.claude/hooks/retarget-flag.sh"
pass=0; fail=0
check() {
  out=$(printf '%s' "$3" | bash "$H")
  if [ -z "$2" ]; then
    [ -z "$out" ] && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1"; fail=$((fail+1)); }
  else
    printf '%s' "$out" | grep -q "$2" && { echo "PASS: $1"; pass=$((pass+1)); } || { echo "FAIL: $1"; fail=$((fail+1)); }
  fi
}
check "flags .spec.ts edit" "retargeted test" '{"tool_name":"Edit","tool_input":{"file_path":"/x/app/queue.spec.ts"}}'
check "flags __tests__ write" "retargeted test" '{"tool_name":"Write","tool_input":{"file_path":"/x/__tests__/queue.tsx"}}'
check "ignores source file" "" '{"tool_name":"Edit","tool_input":{"file_path":"/x/app/queue.ts"}}'
check "malformed stdin silent" "" 'not json'
echo "== $pass passed, $fail failed"; exit $fail
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash ~/.claude/hooks/test-retarget-flag.sh` — expected: 4 FAILs.

- [ ] **Step 3: Write the hook**

Create `~/.claude/hooks/retarget-flag.sh`:

```bash
#!/bin/bash
# retarget-flag.sh — spec §3 rule 2, enforced by event.
# PostToolUse on Edit|Write: if the touched file is a test file, remind the model
# to flag retargeting explicitly. Exits 0 on every path.
set -u
INPUT=$(cat)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0
case "$FILE" in
  *.test.*|*.spec.*|*__tests__*)
    jq -cn '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:"Existing test modified — if expectations were rewritten to match new behavior, state that explicitly in the summary as a retargeted test, never folded into \"tests updated\"."}}' 2>/dev/null
    ;;
esac
exit 0
```

Then: `chmod +x ~/.claude/hooks/retarget-flag.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash ~/.claude/hooks/test-retarget-flag.sh` — expected: `== 4 passed, 0 failed`

- [ ] **Step 5: Wire it**

```bash
python3 - <<'EOF'
import json
p = "/Users/arnavramidi/.claude/settings.json"
s = json.load(open(p))
s["hooks"]["PostToolUse"] = [
  {"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "$HOME/.claude/hooks/retarget-flag.sh"}]}
]
json.dump(s, open(p, "w"), indent=2)
EOF
```

---

### Task 6: Collapse four agents to two

**Files:**
- Create: `~/.claude/agents/implementer.md`, `~/.claude/agents/reviewer.md`
- Delete: `~/.claude/agents/frontend-implementer.md`, `~/.claude/agents/frontend-reviewer.md`, `~/.claude/agents/backend-implementer.md`, `~/.claude/agents/code-reviewer.md`

**Interfaces:**
- Produces: agents named `implementer` and `reviewer`, no `tools:` frontmatter (inherit everything — verified in docs 2026-08-19), no framework names. Task 9 copies them into the repo; the final report's dispatch examples use these names.

- [ ] **Step 1: Write `~/.claude/agents/implementer.md`** (complete file):

```markdown
---
name: implementer
description: Implements tasks in any stack. Detects the project's real stack from its manifest before writing code, verifies recent library APIs against context7, and verifies results against the real running system. Dispatcher MUST set `model` (haiku/sonnet/opus) per task complexity per Arnav's tiering rule in CLAUDE.md.
---

You are an implementer. You inherit every tool available to the session, including MCP tools — use what the task needs, skip what it doesn't, and say which.

For every task:

1. **Detect the stack first.** Read `package.json` / `pyproject.toml` / `Cargo.toml` — whichever exists — before writing any code. Adapt to what is actually there. Never assume a framework the manifest does not show.

2. **Verify recent-major library APIs.** For any library at a version likely past training data, resolve version-pinned docs via `mcp__context7__resolve-library-id` then `mcp__context7__query-docs`. State which versions you verified.

3. **Implement.** Follow the project's existing conventions: imports, file layout, naming, comment density.

4. **Verify against the real system.** UI work → load it in a browser (chrome-devtools, or claude-in-chrome from the main thread) and check rendering plus console output. Backend or library work → run the tests. Data work → query the project's real database if one is registered for that project. State what you verified and how.

5. **Flag test retargeting.** If you rewrote or deleted an existing test to fit new behavior, say so explicitly in your report — one line of its own, never folded into "tests updated."

6. **Report.** What changed, what you verified (with evidence), what you skipped and why. Never claim success without the verification step's output.
```

- [ ] **Step 2: Write `~/.claude/agents/reviewer.md`** (complete file):

```markdown
---
name: reviewer
description: Reviews implementation work against acceptance criteria AND prior behavior. Stack-agnostic — detects the project's stack before applying any framework rubric. Pair with implementer for two-stage review.
model: opus
---

You are a code reviewer. You inherit every tool available to the session; keep your usage read-only.

For every review:

1. **Detect the stack.** Read the manifest first. Apply the rubric that fits what is actually there — never assume a framework.

2. **Check against acceptance criteria.** If they are not in your prompt, ask for them.

3. **Check against prior behavior.** Read the diff against what existed before and answer explicitly: *what did this change remove or relocate that nobody asked about?* A faithful build of a wrong spec still fails this question. A deleted page, route, command, or persistent surface replaced by a lesser one is a Blocker unless the criteria explicitly called for the removal.

4. **Treat test retargeting as a finding.** Any existing test rewritten or deleted to accommodate the change gets its own line in your report — retargeting converts a regression into a passing build unless someone explicitly approved the behavior change.

5. **Apply the domain rubric the diff calls for:**
   - UI: accessibility (WCAG 2.1 AA), keyboard navigation, responsive layout, console errors, rendered verification via a browser.
   - Backend/data: schema assumptions vs. the project's real database, API contract changes, error handling, version-pinned framework usage (verify via context7 when unsure).

6. **Report:** Blockers / Removed-or-relocated (step 3 findings) / Drift / Polish / Approved. Cite file paths and line numbers.
```

- [ ] **Step 3: Delete the four old agents**

```bash
rm ~/.claude/agents/frontend-implementer.md ~/.claude/agents/frontend-reviewer.md \
   ~/.claude/agents/backend-implementer.md ~/.claude/agents/code-reviewer.md
```

- [ ] **Step 4: Verify criterion 6 (no absent tooling, no assumed stack)**

Run: `grep -iE 'prisma|next\.js|nextjs|postgres|magic|21st|brave|sentry|vercel|linear' ~/.claude/agents/*.md`
Expected: no matches.
Run: `echo "Use the Agent tool with subagent_type implementer, prompt: read this project's manifest and name its stack in one line. Report the agent's reply verbatim." | claude -p --model haiku` from inside `~/.claude` (a repo with no package.json)
Expected: the agent reports no manifest found / adapts, without erroring on missing tools.

---

### Task 7: CLAUDE.md rewrite

**Files:**
- Replace: `~/.claude/CLAUDE.md` (complete new content below; old file is ~3,900 bytes, new ~1,800)

**Interfaces:**
- Produces: the single global CLAUDE.md. Task 9 copies it into the repo root (same file serves both roles once `~/.claude` is the checkout).

- [ ] **Step 1: Write the complete new file**

```markdown
# Working with Arnav (loaded every session)

I'm technical but I vibe-code — explain so I can scrutinize decisions without decoding jargon.

## Explanation quality
- Lead with plain language: what will happen, what it gets me, what it risks. Technical backing after, kept compact.
- Never explain a decision as a chain of code identifiers. Say what each step does in plain words; name the function only as evidence.
- Every approach: what happens / what it buys me / what it costs — the trade-off is the part I care about most.
- Define a term the first time it matters. Response *shape* (length, structure, lists) is owned by the i-have-adhd plugin — don't re-derive it here.

## Ground rules
- Never assert external state that could have been looked up: library APIs via context7, rendered UI via a browser, data via the project's real database. If no tool can check it, say you're asserting from memory.
- Detect the stack from the project manifest before writing code; never assume a framework.
- Rewriting or deleting an existing test to fit new behavior is a flagged event — one explicit line in the summary, never "tests updated."
- Reviews check prior behavior, not only the spec: what did this change remove or relocate that nobody asked about?

## Models
- Main thread stays Opus regardless of task: brainstorming, planning, review, specs.
- Subagent tiering: **haiku** = mechanical edits, scaffolding, clear single-file specs; **sonnet** = multi-file edits, moderate reasoning, library API integration, hypothesis-driven debugging; **opus** = ambiguous specs, deep debugging, cross-cutting refactors, complex review. Bias UP when uncertain. Reviewer subagents stay opus.

## Verification
End any non-trivial task with real verification: UI → browser/screenshot; backend or library → test run; data → live query against the project's real database; otherwise a reviewer subagent. If verification is skipped, state why explicitly.
```

- [ ] **Step 2: Verify criterion 3 against the new file**

Run: `grep -iE 'mcp__|magic|21st|postgres|brave|sentry|vercel|linear|supabase|figma' ~/.claude/CLAUDE.md`
Expected: no matches (context7 / chrome named only as principles, not `mcp__` routes — the grep confirms no dead tool routes survive).
Run: `wc -c ~/.claude/CLAUDE.md` — expected: ≤ 2,000 bytes.

---

### Task 8: Memory prune

**Files:**
- Create: `~/.claude/projects/-Users-arnavramidi/memory/archive/` (move 10 files in)
- Delete: `~/.claude/projects/-Users-arnavramidi/memory/feedback_lead_with_the_point.md`
- Replace: `~/.claude/projects/-Users-arnavramidi/memory/MEMORY.md`

**Interfaces:**
- Produces: MEMORY.md ≤ ~800 tok indexing only active work + all kept feedback/reference files. The proposed archive list goes verbatim in the final report; **Arnav vetoes rather than selects** (spec §5b) — restoring a file is `mv archive/<f> .` plus re-adding its index line.

- [ ] **Step 1: Archive shipped/abandoned/obsolete files**

```bash
M=~/.claude/projects/-Users-arnavramidi/memory
mkdir -p $M/archive
for f in project_secureframe_salesroom.md project_spec_b_expanded_scope.md \
         project_subagent_worktree_bootstrap.md project_handshake_rater_phase5.md \
         project_handshake_rater_phase5b.md project_dynamo_log_report_assessment.md \
         project_emerging_risks_rater.md project_daily_todo_app.md \
         feedback_use_mcps_first.md feedback_magic_for_mockups.md; do
  mv $M/$f $M/archive/
done
rm $M/feedback_lead_with_the_point.md   # third copy of style rules; i-have-adhd plugin owns shape (spec §4)
```

Rationale per file: salesroom/spec-B/worktree-bootstrap/dynamo/emerging-risks/daily-todo = shipped; handshake 5/5b = abandoned or dormant since May; `feedback_use_mcps_first` was explicitly scoped to the Sales Room project; `feedback_magic_for_mockups` mandates the removed Magic MCP. Kept deliberately: `feedback_subagent_mcp_perms` (the permission-prompt constraint is still true even though inheritance changed) and `project_quant_baseline_exam` (sittings pending).

- [ ] **Step 2: Rewrite MEMORY.md**

Keep one line per remaining file (9 project/user + 10 feedback + 8 reference = 27 lines), each trimmed to `- [Title](file.md) — hook of ≤12 words`. Drop every date, status narrative, and second clause from the current lines; the detail lives in the files.

- [ ] **Step 3: Verify**

Run: `wc -c ~/.claude/projects/-Users-arnavramidi/memory/MEMORY.md`
Expected: ≤ 3,400 bytes (~850 tok). Also `ls $M/archive | wc -l` → `10`.

---

### Task 9: Sync the repo clone to match the machine

**Files (all in `~/claude-code-configuration`, branch `redesign/2026-08-19-setup-overhaul`):**
- Replace: `settings.json`, `CLAUDE.md` (copy from `~/.claude` — Task 1 already stripped autoMode)
- Create: `hooks/tooling-context.sh`, `hooks/test-tooling-context.sh`, `hooks/retarget-flag.sh`, `hooks/test-retarget-flag.sh`, `hooks/ntfy-notify.sh`, `agents/implementer.md`, `agents/reviewer.md`, `.gitignore`
- Delete: `hooks/tooling-audit.sh`, `hooks/subagent-dispatch-audit.sh`, `hooks/karpathy-reminder.sh` (referenced but never existed on the machine), `agents/frontend-implementer.md`, `agents/frontend-reviewer.md`, `agents/backend-implementer.md`, `agents/code-reviewer.md`, `commands/spec.md` (retired: superseded by brainstorming → writing-plans; its `_specs/` convention and missing template conflict with the superpowers path — spec §5c decision, resolved here as retire)
- Modify: `docs/mcp-servers.md`, `docs/hooks.md`, `docs/agents-and-commands.md`, `docs/plugins.md`, `docs/claude-md.md`, `README.md`

**Interfaces:**
- Consumes: the finished machine state from Tasks 1–8.
- Produces: a pushed branch whose tree byte-for-byte matches the desired machine state for every allowlisted path. Task 10 adopts it.

- [ ] **Step 1: Copy machine state into the clone**

```bash
R=~/claude-code-configuration
cp ~/.claude/settings.json ~/.claude/CLAUDE.md $R/
cp ~/.claude/hooks/tooling-context.sh ~/.claude/hooks/test-tooling-context.sh \
   ~/.claude/hooks/retarget-flag.sh ~/.claude/hooks/test-retarget-flag.sh \
   ~/.claude/hooks/ntfy-notify.sh $R/hooks/
cp ~/.claude/agents/implementer.md ~/.claude/agents/reviewer.md $R/agents/
rm $R/hooks/tooling-audit.sh $R/hooks/subagent-dispatch-audit.sh $R/hooks/karpathy-reminder.sh
rm $R/agents/frontend-implementer.md $R/agents/frontend-reviewer.md \
   $R/agents/backend-implementer.md $R/agents/code-reviewer.md
rm $R/commands/spec.md && rmdir $R/commands
```

- [ ] **Step 2: Write `.gitignore` (default-deny — must exist before Task 10's first `git add` in `~/.claude`)**

```gitignore
# Default-deny: ~/.claude is the working tree; only the config surface is tracked.
/*
!/.gitignore
!/CLAUDE.md
!/settings.json
!/README.md
!/hooks
!/agents
!/commands
!/docs
```

(Un-ignoring a directory re-includes its contents; no `/**` lines needed. `commands/` stays allowlisted for future use even though it ships empty.)

- [ ] **Step 3: Update the six docs**

- `docs/mcp-servers.md`: global inventory = `context7`, `chrome-devtools`, `playwright`, `consensus` (add consensus — live but previously undocumented). Per-project section: `postgres` (register inside a repo with a real DB and a maintained server — the archived reference server has a known SQL-injection issue), `supabase` (Tauri to-do app), `patchright` (job-apply-agent). Removed-and-why table for the seven dropped servers (one line each, from spec §2). Delete the figma row entirely.
- `docs/hooks.md`: document `tooling-context.sh` (three triggers, cache contract, JSON-only rule, marker files), `retarget-flag.sh`, `ntfy-notify.sh` (replaces the osascript examples — delete those). State the verified fact: PreToolUse plain stdout never reaches the model.
- `docs/agents-and-commands.md`: two agents, inheritance note (no `tools:` = inherit all, verified in docs 2026-08-19), tiering lives in CLAUDE.md, `commands/spec.md` retired with one-line reason.
- `docs/plugins.md`: keep/remove table matching spec §4, including the criterion-1 dependency note on huggingface-skills.
- `docs/claude-md.md`: describe the new file's two sections and the style-ownership split (plugin owns shape, CLAUDE.md owns explanation quality).
- `README.md`: update the top-level description — `~/.claude` IS the checkout; `git status` is the drift detector; no copy step exists.

- [ ] **Step 4: Verify no stale references anywhere in the tree**

Run: `grep -rniE 'tooling-audit|subagent-dispatch-audit|karpathy-reminder|frontend-implementer|frontend-reviewer|backend-implementer|code-reviewer|magic|21st|figma' --include='*.md' --include='*.sh' --include='*.json' --exclude-dir=superpowers ~/claude-code-configuration`
Expected: no matches (`docs/superpowers/` — the specs and plans — is excluded as historical record).

- [ ] **Step 5: Commit and push the branch**

```bash
cd ~/claude-code-configuration
git add -A
git commit -m "Implement setup redesign: event hooks, 2 agents, 4 MCPs, CLAUDE.md rewrite"
git push -u origin redesign/2026-08-19-setup-overhaul
```

Pre-push gate: grep the history for the two redacted client-data tokens (see the private incident note in the SDD ledger), plus `sk_` and `api[_-]?key` markers → expected `0` (criterion 5).

---

### Task 10: Migrate `~/.claude` to the checkout, retire the duplicates, final verification

**Files:**
- Create: `~/.claude/.git` (init + adopt the pushed branch)
- Delete: `~/claude-code-configuration` (the working clone — after merge)
- GitHub: archive `claude-code-setup`; merge branch to `main`

**Interfaces:**
- Consumes: the pushed branch from Task 9.
- Produces: success criteria 1–6 all green, recorded in the final report.

- [ ] **Step 1: Merge the branch to main and push (still in the old clone)**

```bash
cd ~/claude-code-configuration
git checkout main && git merge --no-ff redesign/2026-08-19-setup-overhaul \
  -m "Setup redesign: event-driven hooks, minimal MCP inventory, stack-agnostic agents"
git push origin main
```

- [ ] **Step 2: Initialize `~/.claude` as the checkout**

```bash
cd ~/.claude
git init -b main
git remote add origin https://github.com/arnavramidi/claude-code-configuration.git
git fetch origin
git show origin/main:.gitignore > .gitignore   # allowlist in place BEFORE anything else
```

- [ ] **Step 3: Pre-flight diff — machine must already match the repo**

```bash
cd ~/.claude
git ls-tree -r origin/main --name-only | while read -r f; do
  git show "origin/main:$f" | diff -q - "$f" >/dev/null 2>&1 || echo "DIFFERS: $f"
done
```

Expected: `DIFFERS` only for `README.md` and `docs/*` (repo-only documentation the machine never carried — plus nothing else). Any other line means Task 9 missed a copy: **stop and fix Task 9 before proceeding**, never force past it.

- [ ] **Step 4: Adopt**

```bash
cd ~/.claude
git reset origin/main          # index = repo; working tree untouched
git checkout -- README.md docs # take the repo-only paths
git status                     # criterion 4: expect "nothing to commit, working tree clean"
```

- [ ] **Step 5: Retire the duplicates**

```bash
rm -rf ~/claude-code-configuration
gh repo archive arnavramidi/claude-code-setup --yes
```

(Archiving is reversible via `gh repo unarchive`; `rm -rf` of the clone is safe because Step 1 pushed everything — verify `git -C ~/.claude status` is clean first.)

- [ ] **Step 6: Run all six success criteria and record results**

| # | Check | Command |
|---|---|---|
| 1 | zero failing/unauth servers | `claude mcp list` |
| 2 | four-source context ≤2,500 tok | recompute: tooling-context fires × sizes + `wc -c MEMORY.md`/4; per-turn and per-dispatch = 0 by construction |
| 3 | no dead-tool references | Task 9 Step 4 grep, re-run against `~/.claude` |
| 4 | `git status` clean, repo == machine | Task 10 Step 4 output + `git ls-remote origin main` sha matches local |
| 5 | history free of secrets/client data | `git -C ~/.claude log -p` piped through grep for the two redacted client-data tokens (see the private incident note in the SDD ledger), plus `sk_` and `api[_-]?key` markers → 0 |
| 6 | agents clean in non-Next repo | Task 6 Step 4 outputs |

- [ ] **Step 7: Final report to Arnav**

Must contain: the six criteria results; the memory archive list (10 files) for veto; the slash-command probe answer (Task 4 Step 8); the one manual item (rotate the 21st.dev key at the provider); and the note that a **new session** is required for the hook/plugin changes to fully load.

---

## Self-review notes

- Spec coverage: §1 → Task 4; §2 → Tasks 2–3; §3 → Task 5 + agent/CLAUDE.md text (Tasks 6–7); §4 → Tasks 3, 6; §5a → Task 7; §5b → Task 8; §5c → Tasks 9–10; blocking precondition → Task 1; `commands/spec.md` decision → resolved as retire (Task 9); consensus + ntfy documentation → Task 9 Step 3.
- Deliberate deviation from none: the spec's open decision on `commands/spec.md` is closed as "retire" because its template dependency (`_specs/template.md`) exists in no repo and superpowers owns the spec path.
- Type/name consistency: hook filenames, agent names (`implementer`, `reviewer`), cache path, and marker dir are identical across Tasks 4, 5, 6, 9, 10.
