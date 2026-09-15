# Antigravity CLI Swarm Blueprint

A portable, token-optimized multi-agent orchestration boilerplate and ruleset designed natively for **Google Antigravity CLI** (with backward compatibility for Gemini CLI).

## Quick Bootstrap

Run this command inside any target repository to install the blueprint:

```bash
curl -sL https://raw.githubusercontent.com/mbrandt85/agy-swarm/main/bootstrap.sh | bash
```

## Core Features & Architecture

### 1. Token-Guard Ignore Protection (`.antigravityignore` & `.geminiignore`)
Aggressively excludes lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `Cargo.lock`, `go.sum`), heavy binary and vector assets (`*.svg`, images, video), minified code, test fixtures, and build artifacts. Prevents accidental ingestion of massive dependency trees into the agent context window.

### 2. Native Customization Hierarchy (`.agents/`)
Organizes all customizations natively discovered by the Antigravity CLI:
- `.agents/rules/`: Core operational and governance rules.
- `.agents/skills/`: Domain-specific skill blueprints.
- `.agents/agents/`: Specialized subagent role templates.
- `.agents/hooks.json`: Lifecycle automation hooks.
- `AGENTS.md` / `GEMINI.md`: Root-level agent directives and invariants.
- `.gemini/`: Full backward-compatible mirror for legacy Gemini CLI workflows.

### 3. Deterministic Lifecycle Hooks (`.agents/hooks.json`)
Configures deterministic automation on the `PostToolUse` lifecycle event for file-writing tools (`write_to_file`, `replace_file_content`, etc.). Automatically executes `scripts/agy-lint-runner.sh` after file writes, guaranteeing consistent code formatting without wasting agent reasoning tokens.

### 4. Model Tiering & Least-Privilege Subagent Swarm
Provides specialized role templates in `.agents/agents/`:
- **Investigator (`flash`)**: Read-only codebase explorer (`view_file`, `list_dir`, `grep_search`, `find_by_name`). Gathers context and maps dependencies without modification privileges.
- **Tester (`flash`)**: Runner-only verification specialist (`run_command`, `view_file`). Executes tests and inspects traces without authoring capabilities.
- **Coder (`pro`)**: Implementation specialist with full authoring tools (`write_to_file`, `replace_file_content`, `run_command`). Employs high-tier reasoning for surgical diffs and unit test authoring.

### 5. Compact Architecture Map (`ARCHITECTURE.md`)
Maintains a standardized, concise repo map under 40 lines. Clearly delineates module boundaries, directory roles, and execution entry points so agents avoid broad recursive directory crawling.

### 6. Structured Test & Lint Runners
- **`scripts/agy-test-runner.sh`**: Auto-detects project testing environments (Cargo, Go, npm/pnpm, pytest, make, ctest). On failure, parses output into machine-readable format (`FILE:LINE: REASON`) with a compact stack trace under 40 lines.
- **`scripts/agy-lint-runner.sh`**: Deterministically triggers formatters (prettier, cargo fmt, gofmt, ruff, black, shfmt) and enforces non-zero exit codes on lint or syntax failures.

### 7. Governance & Quality Gates
- **English-Only**: Strict English requirement across code, comments, documentation, and commit messages.
- **Mandatory QA Gates**: Changes must pass `scripts/agy-lint-runner.sh` and `scripts/agy-test-runner.sh` prior to task completion.
- **ADR Repository**: Built-in Architecture Decision Records scaffold in `docs/adr/`.
