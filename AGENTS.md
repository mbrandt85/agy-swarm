# Antigravity Agent Guidelines

Welcome to `agy-swarm`, a portable multi-agent orchestration boilerplate and ruleset for the Google Antigravity CLI.

## Architectural Guidelines & Repo Map
- Consult [ARCHITECTURE.md](file:///home/mbrandt/github/mbrandt85/agy-swarm/ARCHITECTURE.md) (< 40 lines) for structural boundaries, module roles, and primary entrypoints before crawling directories.
- Review [docs/adr/](file:///home/mbrandt/github/mbrandt85/agy-swarm/docs/adr/) for recorded architecture decisions.

## Subagent Swarm Roles & Model Tiering
Specialized subagents are defined in `.agents/agents/` using least-privilege toolsets and model tiering:
- **Investigator (`flash`)**: Read-only codebase explorer (`view_file`, `list_dir`, `grep_search`, `find_by_name`). Gathers context and maps references without modification permissions.
- **Tester (`flash`)**: Verification runner (`run_command`, `view_file`). Executes `scripts/agy-test-runner.sh` and `scripts/agy-lint-runner.sh` without file authoring privileges.
- **Coder (`pro`)**: Implementation specialist (`write_to_file`, `replace_file_content`, `run_command`, etc.). Authors minimal diffs and unit tests on high-tier reasoning.

## Deterministic Lifecycle Hooks
- Configured in `.agents/hooks.json`.
- `PostToolUse` triggers `scripts/agy-lint-runner.sh` on file writing/editing tools (`write_to_file`, `replace_file_content`, etc.) to format code deterministically and eliminate wasted agent reasoning tokens.

## Rules Index (`.agents/rules/`)
All agents must adhere to the rules in `.agents/rules/`:
1. **01-caveman-efficiency.md**: Minimize context tokens; never read unparsed test logs directly.
2. **02-language-en.md**: All code, comments, documentation, and commit messages MUST be English.
3. **03-architecture.md**: Respect module boundaries and consult `ARCHITECTURE.md` and `docs/adr/`.
4. **04-context-boundaries.md**: Respect `.antigravityignore`; never inspect lockfiles unless instructed.
5. **05-git-workflow.md**: Work in feature/fix branches; use Conventional Commits.
6. **06-qa-gates.md**: Verify changes with `scripts/agy-lint-runner.sh` and `scripts/agy-test-runner.sh`.

## Verification Gates
Before finishing any task:
1. Run `scripts/agy-lint-runner.sh` (must return exit code 0).
2. Run `scripts/agy-test-runner.sh` (must return exit code 0; outputs structured `FILE:LINE: REASON` on failure).
