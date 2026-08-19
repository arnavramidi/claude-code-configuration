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
