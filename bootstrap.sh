#!/usr/bin/env bash
set -e

REPO_OWNER="mbrandt85"
REPO_NAME="agy-swarm"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}"

echo "🚀 Bootstrapping Antigravity Swarm blueprint into $(pwd)..."

mkdir -p .gemini/rules .gemini/skills/template-skill docs/adr scripts

curl -sL "${BASE_URL}/.gemini/.geminiignore" -o .gemini/.geminiignore
for rule in 01-caveman-efficiency.md 02-language-en.md 03-architecture.md 04-context-boundaries.md 05-git-workflow.md 06-qa-gates.md; do
  curl -sL "${BASE_URL}/.gemini/rules/${rule}" -o ".gemini/rules/${rule}"
done

curl -sL "${BASE_URL}/docs/adr/0001-record-architecture-decisions.md" -o docs/adr/0001-record-architecture-decisions.md
curl -sL "${BASE_URL}/scripts/agy-test-runner.sh" -o scripts/agy-test-runner.sh
curl -sL "${BASE_URL}/scripts/agy-lint-runner.sh" -o scripts/agy-lint-runner.sh

chmod +x scripts/*.sh

echo "✅ Blueprint installed successfully."
