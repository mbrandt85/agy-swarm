#!/usr/bin/env bash
set -e

REPO_OWNER="mbrandt85"
REPO_NAME="agy-swarm"
BRANCH="main"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}}"

echo "🚀 Bootstrapping Antigravity Swarm blueprint into $(pwd)..."

# Helper function to prevent overwriting existing files
download_if_not_exists() {
  local url="$1"
  local dest="$2"
  if [ -f "$dest" ]; then
    echo "  ↳ [SKIPPED] $dest already exists."
  else
    curl -sL "$url" -o "$dest"
  fi
}

# 1. Create directory structures for native .agents/
mkdir -p .agents/rules \
         .agents/skills/template-skill \
         .agents/agents \
         .agents/templates \
         docs/adr \
         scripts

# 2. Download token exclusion boundaries
echo "  ↳ Installing .antigravityignore..."
download_if_not_exists "${BASE_URL}/.antigravityignore" .antigravityignore

# 3. Download architecture map and agent guides
echo "  ↳ Installing ARCHITECTURE.md, AGENTS.md, and PROJECT.md..."
download_if_not_exists "${BASE_URL}/ARCHITECTURE.md" ARCHITECTURE.md
download_if_not_exists "${BASE_URL}/AGENTS.md" AGENTS.md
download_if_not_exists "${BASE_URL}/PROJECT.md" PROJECT.md
download_if_not_exists "${BASE_URL}/.agents/templates/progress.md" .agents/templates/progress.md

# 4. Download deterministic lifecycle hooks
echo "  ↳ Installing .agents/hooks.json..."
download_if_not_exists "${BASE_URL}/.agents/hooks.json" .agents/hooks.json

# 5. Download governance rules
echo "  ↳ Installing governance rules..."
RULES=(
  "01-caveman-efficiency.md"
  "02-language-en.md"
  "03-architecture.md"
  "04-context-boundaries.md"
  "05-git-workflow.md"
  "06-qa-gates.md"
)
for rule in "${RULES[@]}"; do
  download_if_not_exists "${BASE_URL}/.agents/rules/${rule}" ".agents/rules/${rule}"
done

# 6. Download subagent swarm role templates (least-privilege & model tiering)
echo "  ↳ Installing subagent templates..."
SUBAGENTS=(
  "investigator.md"
  "tester.md"
  "coder.md"
)
for agent in "${SUBAGENTS[@]}"; do
  download_if_not_exists "${BASE_URL}/.agents/agents/${agent}" ".agents/agents/${agent}"
done

# 7. Download skills template and included skills
echo "  ↳ Installing skill definitions..."
mkdir -p .agents/skills/take-notes
download_if_not_exists "${BASE_URL}/.agents/skills/template-skill/SKILL.md" .agents/skills/template-skill/SKILL.md
download_if_not_exists "${BASE_URL}/.agents/skills/take-notes/SKILL.md" .agents/skills/take-notes/SKILL.md

# 8. Download ADR scaffold & test/lint runners
echo "  ↳ Installing ADR scaffolding and scripts..."
download_if_not_exists "${BASE_URL}/docs/adr/0001-record-architecture-decisions.md" docs/adr/0001-record-architecture-decisions.md
download_if_not_exists "${BASE_URL}/docs/adr/0002-antigravity-native-standardization.md" docs/adr/0002-antigravity-native-standardization.md
download_if_not_exists "${BASE_URL}/scripts/agy-test-runner.sh" scripts/agy-test-runner.sh
download_if_not_exists "${BASE_URL}/scripts/agy-lint-runner.sh" scripts/agy-lint-runner.sh
download_if_not_exists "${BASE_URL}/scripts/clean-teamwork-logs.sh" scripts/clean-teamwork-logs.sh

chmod +x scripts/*.sh

echo ""
echo "✅ Antigravity Swarm blueprint installed successfully!"
echo "   - Customizations: .agents/ (rules, skills, agents, hooks.json)"
echo "   - Token Guards:   .antigravityignore (< 40 line traces)"
echo "   - Architecture:   ARCHITECTURE.md (< 40 lines), AGENTS.md, PROJECT.md"
echo "   - Automation:     scripts/agy-test-runner.sh, scripts/agy-lint-runner.sh"
