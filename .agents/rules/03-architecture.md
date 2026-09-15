# Architecture Standards & Boundaries
- Consult `ARCHITECTURE.md` (< 40 lines) for primary module boundaries and entrypoints before directory crawling.
- Consult `docs/adr/` before introducing new structural dependencies or systemic design changes.
- Strictly respect module and package boundaries.
- Keep business logic isolated from external framework adapters.
