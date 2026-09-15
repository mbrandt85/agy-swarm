## 2026-09-15T22:56:30Z

<original_task>
# Teamwork Project Prompt — Draft

> Status: Launched
> Goal: Craft prompt → get user approval → delegate to teamwork_preview
> Requested team: small focused team

This is a single self-contained set of changes; keep it small and focused.
Implement three workflow efficiency improvements in the `agy-swarm` repository.

Working directory: /home/mbrandt/github/mbrandt85/agy-swarm
Integrity mode: development

## Requirements

### R1. Auto-commit hook
Add a `PostToolUse` hook in `.agents/hooks.json` named `auto-commit-on-green-tests`. It should run `git add -A && git commit -m "chore: auto-commit after green test gate"` only if the test runner script (`scripts/agy-test-runner.sh`) just ran and exited with code 0. It must output `{}` on stdout to satisfy the Antigravity hook protocol.

### R2. Structured progress.md template
Create `.agents/templates/progress.md` with sections for Phase, Active Agents, Completed, Blockers, and ETA. Add a rule to `AGENTS.md` instructing agents to maintain this file at the repo root and keep it machine-readable.

### R3. Cached test baseline
Update `scripts/agy-test-runner.sh` to cache the test state in `.agy-test-cache` after a fully green run (e.g., using a SHA of the files). On the next run, if the state hasn't changed, skip the test suite and exit 0. Ensure `.agy-test-cache` is added to `.antigravityignore` and `.gitignore`.

## Acceptance Criteria

### Verification
- [ ] `make test` executes and exits 0.
- [ ] `make lint` executes and exits 0.
- [ ] `scripts/agy-test-runner.sh` skips tests when run twice in a row with no file changes.
</original_task>
