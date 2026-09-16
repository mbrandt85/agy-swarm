# Project: <project_name>

A living project state document and milestone registry for Antigravity swarms and teamwork orchestration.

## Architecture & Overview
Define the high-level system architecture, core domain goals, and structural choices here.

## Code Layout
- Implementation: `src/` (or designated application directories)
- Test Suites: `tests/`
- Automation & QA: `scripts/`
- Decisions & Architecture: `docs/adr/`

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Initial Foundation | Project scaffolding, core boundaries, and verification gates | M1 | requirements |
| 2 | Teamwork Log Cleanup | Automatic cleanup of teamwork agent logs via lifecycle hooks | M2 | requirements |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|--------------|--------|
| 1 | M1 - Foundation | Baseline scaffolding and QA runner validation | none | COMPLETE |
| 2 | M2 - Teamwork Cleanup | Automatic cleanup hook and script for teamwork logs | M1 | COMPLETE |

## Interface Contracts
### <module_a> <-> <module_b>
- Document public API signatures, schemas, IPC contracts, and failure modes here.
