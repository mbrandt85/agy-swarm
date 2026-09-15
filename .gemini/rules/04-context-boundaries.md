# Context Boundaries
- NEVER inspect generated lockfiles (`package-lock.json`, `pnpm-lock.yaml`, `Cargo.lock`, `go.sum`) unless explicitly instructed to debug dependency resolution.
- Do not traverse outside the active workspace or target module boundaries.
