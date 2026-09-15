# 2. Antigravity Native Standardization & Efficiency Architecture
Date: 2026-09-15
Status: Accepted

## Context
As multi-agent workflows scale, token consumption from unparsed logs, recursive directory traversals, and redundant model formatting calls creates significant latency and cost overhead. Antigravity CLI introduces native support for `.agents/`, deterministic lifecycle hooks, and subagent swarm definitions.

## Decision
1. Standardize project-level agent configuration in `.agents/` (`rules/`, `skills/`, `agents/`, `hooks.json`, root `AGENTS.md`) while preserving `.gemini/` for backward compatibility.
2. Implement `.antigravityignore` and `.geminiignore` with aggressive token guards blocking lockfiles, heavy static assets, and test snapshots.
3. Establish deterministic `PostToolUse` lifecycle hooks in `.agents/hooks.json` to auto-format and validate code after file modifications.
4. Define least-privilege, model-tiered subagent templates: Investigator (`flash`, read-only), Tester (`flash`, runner-only), and Coder (`pro`, authoring).
5. Maintain a concise `ARCHITECTURE.md` repository map under 40 lines.
6. Provide structured test failure extraction (`FILE:LINE: REASON`) and compact traces (< 40 lines) in `scripts/agy-test-runner.sh`.
