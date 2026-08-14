# Plugins

Plugins are installed bundles of skills, subagents, and slash commands, pulled from a
"marketplace" (a GitHub repo that lists installable plugins). They're managed with
`/plugin` inside a session, or by hand-editing `enabledPlugins` in `settings.json`.

## Installed

| Plugin | Marketplace | Status | What it provides |
|---|---|---|---|
| `superpowers` | `claude-plugins-official` | on | The process skills this setup leans on hardest: `brainstorming` (Q&A spec before any creative work), `writing-plans`, `subagent-driven-development`, `systematic-debugging`, `test-driven-development`, `verification-before-completion`, `finishing-a-development-branch`, `using-git-worktrees`, `writing-skills`, and the meta-skill `using-superpowers` that makes all the others get invoked instead of skipped |
| `code-review` | `claude-plugins-official` | on | The `/code-review` slash command — reviews a diff or PR at a chosen effort level, can post inline PR comments or apply fixes directly |
| `frontend-design` | `claude-plugins-official` | on | Aesthetic/layout guidance for UI work — used after pulling a real component pattern, not instead of one |
| `andrej-karpathy-skills` | `karpathy-skills` (community, `forrestchang/andrej-karpathy-skills`) | on | `karpathy-guidelines` — a checklist against common LLM coding failure modes (overcomplication, non-surgical changes, unstated assumptions, unverifiable "done") |
| `huggingface-skills` | `claude-plugins-official` | on | The full Hugging Face Hub skill set — CLI, model/dataset lookup, SageMaker deployment, training, Spaces, ZeroGPU, etc. Only relevant on ML-adjacent projects |
| `warp` | `claude-code-warp` (community, `warpdotdev/claude-code-warp`) | on | Warp terminal integration |
| `explanatory-output-style` | `claude-plugins-official` | **off** | Built-in alternate response style; disabled here in favor of the CLAUDE.md communication rules below |
| `learning-output-style` | `claude-plugins-official` | **off** | Same — disabled in favor of custom rules |

## Marketplaces referenced

Two non-default marketplaces are registered under `extraKnownMarketplaces` in
`settings.json`:

- `claude-code-warp` → `github:warpdotdev/claude-code-warp`
- `karpathy-skills` → `github:forrestchang/andrej-karpathy-skills`

The official marketplace (`claude-plugins-official`) is bundled with Claude Code and
doesn't need to be added by hand.

## Replicating

```bash
# Add a community marketplace once
/plugin marketplace add warpdotdev/claude-code-warp
/plugin marketplace add forrestchang/andrej-karpathy-skills

# Install plugins (official marketplace plugins don't need the add step above)
/plugin install superpowers@claude-plugins-official
/plugin install code-review@claude-plugins-official
/plugin install frontend-design@claude-plugins-official
/plugin install huggingface-skills@claude-plugins-official
/plugin install warp@claude-code-warp
/plugin install andrej-karpathy-skills@karpathy-skills
```

Then toggle any of them off with `/plugin` → select → disable, the same way
`explanatory-output-style` and `learning-output-style` are turned off here.
