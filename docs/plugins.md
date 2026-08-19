# Plugins

Plugins are installed bundles of skills, subagents, and slash commands, pulled from a
"marketplace" (a GitHub repo that lists installable plugins). They're managed with
`/plugin` inside a session, or by hand-editing `enabledPlugins` in `settings.json`.

## Kept

| Plugin | Marketplace | Why |
|---|---|---|
| `superpowers` | `claude-plugins-official` | The process spine — `brainstorming`, `writing-plans`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`, `finishing-a-development-branch`, `using-git-worktrees`, `writing-skills`, and the meta-skill `using-superpowers` that makes all the others get invoked instead of skipped |
| `frontend-design` | `claude-plugins-official` | The remaining source of design/layout direction now that the UI component-retrieval MCP is gone — see `docs/mcp-servers.md` for why that was dropped |
| `andrej-karpathy-skills` | `karpathy-skills` (community, `forrestchang/andrej-karpathy-skills`) | Small (~900 chars, one skill) and referenced by existing feedback memory |
| `i-have-adhd` | `i-have-adhd` (community, `ayghri/i-have-adhd`) | Kept, with the response-style ownership conflict below resolved |
| `warp` | `claude-code-warp` (community, `warpdotdev/claude-code-warp`) | Confirmed in active use (Warp terminal integration) |

## Removed

Confirmed against `~/.claude/backups/settings.json.pre-redesign-20260819` — the actual
live `enabledPlugins` block immediately before this redesign's plugin cleanup ran, which
is the ground truth for "what was really installed," not just what an earlier version of
this repo's docs claimed:

| Plugin | Why |
|---|---|
| `huggingface-skills` | Was `true`. 26 skills (~3,200 tokens measured), the largest single block of loaded context, with no ML work in the current project rotation. Also bundled its own `huggingface` MCP server, which reported "needs authentication" — removing the plugin was itself a precondition for a clean `claude mcp list` (criterion 1). |
| `rust-analyzer-lsp` | Was `true` — a live, enabled plugin, not a stale doc entry. Removed during this redesign; confirmed not in use. |
| `learning-output-style` | Was already `false`. A disabled entry left in `enabledPlugins` is pure noise, so the entry itself was deleted rather than kept around at `false`. |

`enabledPlugins` in `settings.json` now carries exactly the five kept entries above, all
`true` — no disabled entries left in the file.

## Documentation corrections (not removed by this redesign — never actually live)

The very first version of this repo's docs (committed before this redesign project began)
also listed `code-review@claude-plugins-official` (enabled) and
`explanatory-output-style@claude-plugins-official` (disabled) as installed. Neither one is
in the pre-redesign backup referenced above — meaning the repo and the machine had already
drifted apart on these two entries *before* this redesign started, independent of anything
Task 3 did. `code-review` is a slash command backed by a built-in skill now, not a
marketplace plugin (see `docs/skills.md`), and `explanatory-output-style` simply isn't
present at all. Neither row belongs in the "Removed" table above, since this redesign
didn't remove either one — the earlier documentation was just wrong by the time this
project touched the file. Listed here so the correction is explicit rather than a silent
disappearance.

## Style-ownership conflict, resolved

Three sources used to instruct response style, and two disagreed on length: `CLAUDE.md`
("stay technical, no length limit"), the `i-have-adhd` plugin ("~150–250 words, cap lists
at five"), and a memory file duplicating the plugin's rule. Resolution: **the `i-have-adhd`
plugin owns response shape** (length, structure, no preamble). **`CLAUDE.md` owns
explanation quality** (plain language first, define terms on first use, state trade-offs as
what-happens / what-it-buys / what-it-costs). `CLAUDE.md`'s style section was cut down to
explanation quality only, and the duplicate memory file was deleted.

## Marketplaces referenced

Three non-default marketplaces are registered under `extraKnownMarketplaces` in
`settings.json`:

- `claude-code-warp` → `github:warpdotdev/claude-code-warp`
- `karpathy-skills` → `github:forrestchang/andrej-karpathy-skills`
- `i-have-adhd` → `github:ayghri/i-have-adhd`

The official marketplace (`claude-plugins-official`) is bundled with Claude Code and
doesn't need to be added by hand.

## Replicating

```bash
# Add a community marketplace once
/plugin marketplace add warpdotdev/claude-code-warp
/plugin marketplace add forrestchang/andrej-karpathy-skills
/plugin marketplace add ayghri/i-have-adhd

# Install plugins (official marketplace plugins don't need the add step above)
/plugin install superpowers@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
/plugin install warp@claude-code-warp
/plugin install andrej-karpathy-skills@karpathy-skills
/plugin install i-have-adhd@i-have-adhd
```
