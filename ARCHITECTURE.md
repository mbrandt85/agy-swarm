# Architecture Map: agy-swarm

A portable, token-optimized multi-agent orchestration blueprint for Antigravity CLI.

## Directory Structure
- `.agents/`: Native Antigravity configurations, rules, skills, agents, and hooks.
  - `rules/`: Governance rules (efficiency, language, boundaries, QA).
  - `skills/`: Extensible domain-specific agent skills.
  - `agents/`: Subagent swarm role templates (Investigator, Tester, Coder).
  - `hooks.json`: Deterministic lifecycle hooks (post-edit formatting/linting).
- `docs/adr/`: Architecture Decision Records tracking major structural choices.
- `scripts/`: Standardized, token-efficient CLI runners.
  - `scripts/agy-lint-runner.sh`: Auto-formatter and lint gate.
  - `scripts/agy-test-runner.sh`: Structured test runner (< 40 line traces).
- `bootstrap.sh`: Universal installation script for target repositories.

## Module Boundaries & Invariants
- **English Only**: All code, docs, rules, and commit messages must be in English.
- **Customization Root**: All native agent configs reside in `.agents/`.
- **Token Efficiency**: Agents execute `scripts/agy-*-runner.sh`; never crawl unparsed logs.
- **Least Privilege**: Subagents use tiered models (Flash for inspection/tests, Pro for coding).

## Key Entry Points
- `bootstrap.sh`: Deploys blueprint into target repos (`curl -sL <url>/bootstrap.sh | bash`).
- `scripts/agy-lint-runner.sh`: Runs linters/formatters with deterministic exit codes.
- `scripts/agy-test-runner.sh`: Runs environment test suite with structured error reporting.
