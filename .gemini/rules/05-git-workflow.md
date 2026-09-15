# Git Lifecycle & Commits
- NEVER commit or push directly to `main` or `master`.
- Always create a dedicated branch: `feature/<name>` or `fix/<name>`.
- Use Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
- Always inspect `git diff` before staging to verify no debug artifacts or temp files remain.
