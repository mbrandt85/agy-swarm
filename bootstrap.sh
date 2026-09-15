#!/usr/bin/env bash
set -e

REPO_OWNER="mbrandt85"
REPO_NAME="agy-swarm"
BRANCH="main"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}}"

echo "🚀 Bootstrapping Antigravity Swarm blueprint into $(pwd)..."

# 1. Create directory structures for native .agents/
mkdir -p .agents/rules \
         .agents/skills/template-skill \
         .agents/agents \
         docs/adr \
         scripts

# 2. Download token exclusion boundaries
echo "  ↳ Installing .antigravityignore..."
curl -sL "${BASE_URL}/.antigravityignore" -o .antigravityignore

# 3. Download architecture map and agent guides
echo "  ↳ Installing ARCHITECTURE.md, AGENTS.md, and PROJECT.md..."
curl -sL "${BASE_URL}/ARCHITECTURE.md" -o ARCHITECTURE.md
curl -sL "${BASE_URL}/AGENTS.md" -o AGENTS.md
curl -sL "${BASE_URL}/PROJECT.md" -o PROJECT.md

# 4. Download deterministic lifecycle hooks
echo "  ↳ Installing .agents/hooks.json..."
curl -sL "${BASE_URL}/.agents/hooks.json" -o .agents/hooks.json

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
  curl -sL "${BASE_URL}/.agents/rules/${rule}" -o ".agents/rules/${rule}"
done

# 6. Download subagent swarm role templates (least-privilege & model tiering)
echo "  ↳ Installing subagent templates..."
SUBAGENTS=(
  "investigator.md"
  "tester.md"
  "coder.md"
)
for agent in "${SUBAGENTS[@]}"; do
  curl -sL "${BASE_URL}/.agents/agents/${agent}" -o ".agents/agents/${agent}"
done

# 7. Download skills template
echo "  ↳ Installing skill definitions..."
curl -sL "${BASE_URL}/.agents/skills/template-skill/SKILL.md" -o .agents/skills/template-skill/SKILL.md

# 8. Download ADR scaffold & test/lint runners
echo "  ↳ Installing ADR scaffolding and scripts..."
curl -sL "${BASE_URL}/docs/adr/0001-record-architecture-decisions.md" -o docs/adr/0001-record-architecture-decisions.md
curl -sL "${BASE_URL}/docs/adr/0002-antigravity-native-standardization.md" -o docs/adr/0002-antigravity-native-standardization.md
curl -sL "${BASE_URL}/scripts/agy-test-runner.sh" -o scripts/agy-test-runner.sh
curl -sL "${BASE_URL}/scripts/agy-lint-runner.sh" -o scripts/agy-lint-runner.sh

chmod +x scripts/*.sh

echo ""
echo "✅ Antigravity Swarm blueprint installed successfully!"
echo "   - Customizations: .agents/ (rules, skills, agents, hooks.json)"
echo "   - Token Guards:   .antigravityignore (< 40 line traces)"
echo "   - Architecture:   ARCHITECTURE.md (< 40 lines), AGENTS.md, PROJECT.md"
echo "   - Automation:     scripts/agy-test-runner.sh, scripts/agy-lint-runner.sh"
