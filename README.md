# agy-swarm

A lightweight multi-agent orchestration boilerplate and ruleset for the Google Antigravity CLI (`agy`).

## Why

AI coding agents left on their own tend to:
- Ingest massive lockfiles, bundles, and test fixtures, burning context and money.
- Waste expensive reasoning models (`pro`) on mechanical tasks like searching files or running tests.
- Spin in circles reading thousand-line test logs without identifying root causes.
- Waste turns and tokens trying to format code manually.

`agy-swarm` turns your repository into an organized, token-efficient multi-agent environment with model tiering, strict context boundaries, and automated quality gates.

## What It Does

- **Model Tiering & Least Privilege**:
  - `investigator` (`flash`): Read-only explorer. Finds files, symbols, and context without edit permissions.
  - `coder` (`pro`): Authoring specialist. Writes minimal diffs and unit tests.
  - `tester` (`flash`): Runner-only. Runs tests and lints without write access.
- **Context Boundaries (`.antigravityignore`)**: Blocks lockfiles, snapshots, build outputs, and minified bundles from entering the agent's context.
- **Deterministic Hooks (`.agents/hooks.json`)**: Formats code automatically on file save (`PostToolUse`) with zero reasoning tokens spent.
- **Structured Error Parsing (`scripts/agy-test-runner.sh`)**: Extracts test failures into `FILE:LINE: REASON` format and caps output at 40 lines so agents fix bugs in a single turn.
- **Dual-Document Governance**:
  - `ARCHITECTURE.md`: Permanent, concise repo map (< 40 lines) to prevent directory crawling.
  - `PROJECT.md`: Living state file for feature inventories and milestone tracking during swarms (`/teamwork-preview`).

## Quickstart

Install the boilerplate into your current repository:

```bash
curl -sL https://raw.githubusercontent.com/mbrandt85/agy-swarm/main/bootstrap.sh | bash
```

Run Antigravity:

```bash
agy
```

Use slash commands or let agents work autonomously:
- `/teamwork-preview` — Run multi-agent orchestrator against `PROJECT.md`.
- `/plan` — Plan out milestones before execution.
- `/boost` — Run deep multi-perspective reasoning and verification.

## Verification

```bash
make test  # Runs full test suite
make lint  # Runs formatters and shell syntax checks
```

## Structure

```
.agents/
  agents/        # Role definitions (investigator, coder, tester)
  rules/         # Operational rules (token economy, language, QA gates)
  skills/        # Extensible domain skills
  hooks.json     # PostToolUse lint/format hook
scripts/
  agy-test-runner.sh
  agy-lint-runner.sh
AGENTS.md        # Global agent guidelines
ARCHITECTURE.md  # Static repo map (< 40 lines)
PROJECT.md       # Living milestone and sprint tracker
bootstrap.sh     # Installer
```

## License

MIT
