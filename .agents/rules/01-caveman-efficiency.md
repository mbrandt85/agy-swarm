# Caveman Efficiency & Token Minimization
- NEVER read raw, unoptimized build or test logs directly.
- ALWAYS run tests via `scripts/agy-test-runner.sh` and linting via `scripts/agy-lint-runner.sh`.
- Deterministic lifecycle hooks (`.agents/hooks.json`) auto-format code upon writing; do not waste reasoning tokens on manual formatting.
- Restrict file inspection strictly to files relevant to the active task.
- Limit manual log inspection to a maximum of 40 lines at a time.

## Compact Handoffs ("Caveman Context")
- `progress.md` sections must stay within the line limits defined in `.agents/templates/progress.md`. No prose, no history, no summaries — one concept per line.
- When briefing a new agent, pass ONLY the relevant interface contracts (function signatures, API shapes, file paths). Never dump full file contents into a handoff.
- Completed items older than the current session MUST be pruned from `progress.md`. Keep only what the next agent needs to continue.
- BRIEFING.md files must stay under 40 lines. If a briefing exceeds 40 lines, it is a sign you are passing too much context — cut it.
