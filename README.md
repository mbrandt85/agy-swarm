# Antigravity CLI Swarm Blueprint (`agy-swarm`)

> **A portable, token-optimized multi-agent orchestration boilerplate and ruleset for Google Antigravity CLI.**  
> *Transform any codebase into an autonomous, model-tiered multi-agent workspace with deterministic quality gates and living sprint planning.*

---

## ⚡ The Problem: Why Swarms Need Guardrails

Standard AI coding agents left to themselves quickly exhaust context windows, inflate API costs, and enter trial-and-error spirals:
1. **Context Flooding**: Agents greedily ingest 50,000-line lockfiles, minified bundles, vector assets, and snapshots into their working memory.
2. **Model Overkill**: Expensive frontier reasoning models (`Pro`) are wasted performing mechanical greps, file searches, and lint checks.
3. **Log Churning & Hallucination**: Unparsed test runners dump 3,000 lines of terminal stack traces into context, causing agents to blindly churn fixes across multiple turns.
4. **Wasted Reasoning on Formatting**: Agents spend tool calls and tokens manually re-reading files to verify indentation, trailing commas, or syntax rules.

`agy-swarm` solves this by enforcing **least-privilege model tiering**, **aggressive ignore boundaries**, **deterministic lifecycle hooks**, and **structured QA gates** right out of the box.

---

## 🏗️ Swarm Architecture & Workflow

```text
                     User Request / Sprint Goal
                                 │
                                 ▼
                     Project Orchestrator
                (PROJECT.md & ARCHITECTURE.md)
                                 │
         ┌───────────────────────┼───────────────────────┐
         ▼                       ▼                       ▼
   Investigator                Coder                   Tester
  [Flash / Read-Only]     [Pro / Authoring]     [Flash / Runner-Only]
  • Pinpoint search       • High-tier reasoning • Executes test runners
  • Gathers references    • Surgical code diffs • Structured failure parsing
  • Maps dependencies     • Unit test authoring • Fast pass/fail gates
                                 │
                                 ▼
                         PostToolUse Hook
                  (Deterministic Auto-Formatting)
```

---

## 🚀 Quick Bootstrap

### 1. Install into Any Target Repository
Run the zero-touch bootstrap script in your project root:

```bash
curl -sL https://raw.githubusercontent.com/mbrandt85/agy-swarm/main/bootstrap.sh | bash
```

### 2. Start an Autonomous Swarm Session
Launch the Antigravity CLI:

```bash
agy
```

Inside Antigravity, trigger multi-agent orchestration:
- `/teamwork-preview` — Deploy autonomous orchestrator and subagent teams against [`PROJECT.md`](PROJECT.md).
- `/boost` — Engage deep reasoning with multi-perspective verification and QA gates.
- `/plan` — Generate step-by-step milestone decomposition prior to coding.

---

## 🧩 Core Capabilities

### 1. Model Tiering & Least-Privilege Subagents (`.agents/agents/`)
Each subagent is provisioned with strictly scoped tools and optimal model tiers:

| Role | Model Tier | Permitted Tools | Purpose |
| :--- | :---: | :--- | :--- |
| **Investigator** | `flash` | `view_file`, `list_dir`, `grep_search`, `find_by_name` | Rapid, low-cost context exploration without edit privileges. |
| **Tester** | `flash` | `run_command`, `view_file` | Fast test verification without code authoring privileges. |
| **Coder** | `pro` | `write_to_file`, `replace_file_content`, `run_command`, `grep_search` | Surgical diffs, refactoring, and unit tests with high reasoning. |

### 2. Dual-Document Governance
- **[`ARCHITECTURE.md`](ARCHITECTURE.md)** *(Static Repo Map, < 40 lines)*: Fixed structural map defining directory roles, module boundaries, and entry points. Eliminates blind recursive directory scans (`list_dir`).
- **[`PROJECT.md`](PROJECT.md)** *(Living State Document)*: Maintained by the orchestrator. Features a live milestone table (`PLANNED`, `IN_PROGRESS`, `DONE`, `BLOCKED`), feature inventory, and inter-module interface contracts.

### 3. Aggressive Context Isolation (`.antigravityignore`)
Blocks agents from polluting their context window with:
- Package lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `Cargo.lock`, `go.sum`, `poetry.lock`)
- Heavy media and vectors (`*.svg`, images, video)
- Build artifacts, bytecode, and vendor directories (`dist/`, `build/`, `target/`, `node_modules/`, `__pycache__/`)
- Test fixtures and snapshots (`__snapshots__/`, `testdata/`, `fixtures/`)

### 4. Deterministic Lifecycle Automation (`.agents/hooks.json`)
A native `PostToolUse` lifecycle hook intercepts file-writing actions (`write_to_file`, `replace_file_content`) and triggers [`scripts/agy-lint-runner.sh`](scripts/agy-lint-runner.sh).
- Automatically formats code via detected project formatters (`prettier`, `cargo fmt`, `gofmt`, `ruff`, `black`, `shfmt`).
- Emits `{}` JSON output back to the Antigravity engine without wasting LLM reasoning cycles.

### 5. Machine-Readable QA Gates
- **[`scripts/agy-test-runner.sh`](scripts/agy-test-runner.sh)**: Auto-detects project testing environments (Go, Pytest, Cargo, Jest/Node, Maven, CTest). On failure, parses output into standardized `FILE:LINE: REASON` lines and truncates traces to < 40 lines so agents identify the root cause in a single turn.
- **[`scripts/agy-lint-runner.sh`](scripts/agy-lint-runner.sh)**: Enforces syntax and lint validations with non-zero exit codes.

---

## 📂 Repository Layout

```text
agy-swarm/
├── .agents/
│   ├── agents/            # Subagent swarm role templates (Investigator, Tester, Coder)
│   ├── rules/             # Operational rules (token economy, language, boundaries, QA)
│   ├── skills/            # Extensible domain skills (template-skill)
│   └── hooks.json         # PostToolUse auto-linting and formatting hook
├── docs/adr/              # Architecture Decision Records
├── scripts/
│   ├── agy-lint-runner.sh # Deterministic formatter and syntax gate
│   └── agy-test-runner.sh # Structured test runner with compact traces (< 40 lines)
├── tests/
│   └── test_runners.sh    # Test suite verifying bootstrap, rules, and runners
├── .antigravityignore     # Token-guard ignore boundary
├── AGENTS.md              # Global agent guidelines and invariants
├── ARCHITECTURE.md        # Static repo map (< 40 lines)
├── PROJECT.md             # Living sprint state & milestone registry
├── bootstrap.sh           # Zero-touch installer for target repositories
└── Makefile               # make test & make lint entrypoints
```

---

## 🧪 Verification

Run the test suite to verify blueprint integrity:

```bash
make test  # Validates JSON schemas, subagent specs, line limits, and bootstrap e2e
make lint  # Runs deterministic formatters and shell syntax checks
```

---

## 📄 License
MIT
