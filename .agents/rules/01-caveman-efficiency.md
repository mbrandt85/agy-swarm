# Caveman Efficiency & Token Minimization
- NEVER read raw, unoptimized build or test logs directly.
- ALWAYS run tests via `scripts/agy-test-runner.sh` and linting via `scripts/agy-lint-runner.sh`.
- Deterministic lifecycle hooks (`.agents/hooks.json`) auto-format code upon writing; do not waste reasoning tokens on manual formatting.
- Restrict file inspection strictly to files relevant to the active task.
- Limit manual log inspection to a maximum of 40 lines at a time.
