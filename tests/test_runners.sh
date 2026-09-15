#!/usr/bin/env bash
set -e

# Guard against infinite recursion when testing cache runner inside test suite
if [ "${AGY_TEST_NESTED:-0}" = "1" ]; then
    exit 0
fi

echo "🧪 Running agy-swarm test suite..."

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

# 1. Architecture Map Line Count Verification (< 40 lines) & PROJECT.md
ARCH_LINES=$(wc -l < ARCHITECTURE.md | tr -d ' ')
if [ "$ARCH_LINES" -ge 40 ]; then
    echo "ARCHITECTURE.md:1: error: ARCHITECTURE.md exceeds 40 lines ($ARCH_LINES lines found)"
    exit 1
fi
[ -f PROJECT.md ] || {
    echo "PROJECT.md:1: error: Missing PROJECT.md template"
    exit 1
}
echo "  ✓ ARCHITECTURE.md line count check passed ($ARCH_LINES lines < 40) and PROJECT.md present"

# 2. JSON Validation
for json_file in .agents/hooks.json; do
    if [ -f "$json_file" ]; then
        jq . "$json_file" >/dev/null || {
            echo "$json_file:1: error: Invalid JSON syntax"
            exit 1
        }
    else
        echo "$json_file:1: error: Missing required hook file"
        exit 1
    fi
done
echo "  ✓ hooks.json syntax validation passed"

# 3. Subagent Frontmatter & Least Privilege Validation
for agent in investigator tester coder; do
    agent_file=".agents/agents/${agent}.md"
    if [ ! -f "$agent_file" ]; then
        echo "$agent_file:1: error: Missing subagent definition"
        exit 1
    fi
    grep -q "name: ${agent}" "$agent_file" || { echo "$agent_file:1: error: Missing name"; exit 1; }
    grep -q "model:" "$agent_file" || { echo "$agent_file:1: error: Missing model"; exit 1; }
    grep -q "tools:" "$agent_file" || { echo "$agent_file:1: error: Missing tools"; exit 1; }
    grep -q "subagent: true" "$agent_file" || { echo "$agent_file:1: error: Missing subagent: true"; exit 1; }
done
echo "  ✓ Subagent role templates verified"

# 4. Rules Integrity Check
for rule in 01-caveman-efficiency.md 02-language-en.md 03-architecture.md 04-context-boundaries.md 05-git-workflow.md 06-qa-gates.md; do
    if [ ! -f ".agents/rules/${rule}" ]; then
        echo ".agents/rules/${rule}:1: error: Missing governance rule"
        exit 1
    fi
done
echo "  ✓ Governance rules integrity verified"

# 5. Test Structured Failure Extraction & Line Truncation
TEMP_MOCK_LOG=$(mktemp -t mock-test-log-XXXXXX.log)
cat << 'EOF' > "$TEMP_MOCK_LOG"
Running tests...
foo_test.go:42: assertion failure: expected 10, got 20
FAILED tests/test_core.py::test_calc - AssertionError: 5 != 10
tests/test_core.py:18: AssertionError: 5 != 10
thread 'main' panicked at 'vector index out of bounds', src/parser.rs:99:12
at Object.<anonymous> (/workspace/src/app.test.ts:77:15)
Makefile:25: error: build failed
Random trailing logs...
EOF

# Test python extractor directly
EXTRACTED=$(python3 - "$TEMP_MOCK_LOG" << 'EOF'
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

failures = []
for m in re.finditer(r"(?:panicked at '([^']*)', |panicked at )([a-zA-Z0-9_./-]+\.rs):(\d+)", content):
    failures.append(f"{m.group(2)}:{m.group(3)}: Panic - {m.group(1)}")
for m in re.finditer(r"^\s*([a-zA-Z0-9_./-]+\.go):(\d+):\s*(.+)$", content, re.MULTILINE):
    failures.append(f"{m.group(1)}:{m.group(2)}: {m.group(3)}")
for m in re.finditer(r"([a-zA-Z0-9_./-]+\.py):(\d+):\s*(AssertionError:.*)", content):
    failures.append(f"{m.group(1)}:{m.group(2)}: {m.group(3)}")
for m in re.finditer(r"at\s+.*?\((/[^:\s)]+|[a-zA-Z0-9_./-]+\.[jt]sx?):(\d+):(?:\d+)\)", content):
    failures.append(f"{m.group(1)}:{m.group(2)}: Test failure assertion")

for f in failures:
    print(f)
EOF
)

rm -f "$TEMP_MOCK_LOG"

echo "$EXTRACTED" | grep -q "src/parser.rs:99: Panic - vector index out of bounds" || {
    echo "tests/test_runners.sh:1: error: Rust panic parser failed"
    exit 1
}
echo "$EXTRACTED" | grep -q "foo_test.go:42: assertion failure: expected 10, got 20" || {
    echo "tests/test_runners.sh:1: error: Go test parser failed"
    exit 1
}
echo "$EXTRACTED" | grep -q "tests/test_core.py:18: AssertionError: 5 != 10" || {
    echo "tests/test_runners.sh:1: error: Pytest parser failed"
    exit 1
}
echo "$EXTRACTED" | grep -q "/workspace/src/app.test.ts:77: Test failure assertion" || {
    echo "tests/test_runners.sh:1: error: TS/Jest parser failed"
    exit 1
}
echo "  ✓ Structured failure parsing verified for Go, Pytest, Rust, and TS/Jest"

# 6. Test scripts/agy-lint-runner.sh
scripts/agy-lint-runner.sh >/dev/null 2>&1 || {
    echo "scripts/agy-lint-runner.sh:1: error: Lint runner failed on clean repository"
    exit 1
}
echo "if broken_syntax" > scripts/tmp_broken.sh
if scripts/agy-lint-runner.sh >/dev/null 2>&1; then
    rm -f scripts/tmp_broken.sh
    echo "scripts/agy-lint-runner.sh:1: error: Lint runner failed to exit non-zero on syntax error"
    exit 1
fi
rm -f scripts/tmp_broken.sh
echo "  ✓ agy-lint-runner.sh clean run & failure exit code enforcement verified"

# 7. Test bootstrap.sh syntax & end-to-end execution
bash -n bootstrap.sh || {
    echo "bootstrap.sh:1: error: Syntax error in bootstrap.sh"
    exit 1
}
BOOTSTRAP_TMP=$(mktemp -d)
(
    cd "$BOOTSTRAP_TMP"
    BASE_URL="file://${REPO_DIR}" bash "${REPO_DIR}/bootstrap.sh" >/dev/null 2>&1
    [ -f .antigravityignore ] || exit 1
    [ -f ARCHITECTURE.md ] || exit 1
    [ -f AGENTS.md ] || exit 1
    [ -f PROJECT.md ] || exit 1
    [ -f .agents/hooks.json ] || exit 1
    [ -f .agents/rules/01-caveman-efficiency.md ] || exit 1
    [ -f .agents/agents/investigator.md ] || exit 1
    [ -x scripts/agy-test-runner.sh ] || exit 1
    [ -x scripts/agy-lint-runner.sh ] || exit 1
) || {
    echo "bootstrap.sh:1: error: End-to-end bootstrap execution failed"
    rm -rf "$BOOTSTRAP_TMP"
    exit 1
}
rm -rf "$BOOTSTRAP_TMP"
echo "  ✓ bootstrap.sh end-to-end installation verified"

# 8. Test SHA cache: write then skip
CACHE_TMP=$(mktemp -d)
(
    cp -r "$REPO_DIR/." "$CACHE_TMP/"
    cd "$CACHE_TMP"
    # Remove any stale cache to ensure first run writes one
    rm -f .agy-test-cache
    # First run — must succeed and write the cache file
    AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh > /dev/null 2>&1
    [ -f .agy-test-cache ] || { echo "tests/test_runners.sh:1: error: Cache file not written after green run"; exit 1; }
    # Second run — SHA unchanged — must print [SKIP] and exit 0
    OUTPUT=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
    echo "$OUTPUT" | grep -q "\[SKIP\]" || { echo "tests/test_runners.sh:1: error: Cache skip not triggered on unchanged tree"; exit 1; }
)
EXIT_CACHE=$?
rm -rf "$CACHE_TMP"
[ $EXIT_CACHE -eq 0 ] || exit 1
echo "  ✓ SHA cache write and skip behaviour verified"

# 9. Verify .agy-test-cache is listed in .antigravityignore and .gitignore
grep -q "\.agy-test-cache" "$REPO_DIR/.antigravityignore" || {
    echo ".antigravityignore:1: error: .agy-test-cache not listed in .antigravityignore"
    exit 1
}
grep -q "\.agy-test-cache" "$REPO_DIR/.gitignore" || {
    echo ".gitignore:1: error: .agy-test-cache not listed in .gitignore"
    exit 1
}
echo "  ✓ .agy-test-cache present in .antigravityignore and .gitignore"

# 10. Verify progress.md template exists with required sections
PROGRESS_TMPL="$REPO_DIR/.agents/templates/progress.md"
[ -f "$PROGRESS_TMPL" ] || {
    echo ".agents/templates/progress.md:1: error: Progress template file missing"
    exit 1
}
for section in "## Phase" "## Active Agents" "## Completed" "## Blockers" "## ETA"; do
    grep -qF "$section" "$PROGRESS_TMPL" || {
        echo ".agents/templates/progress.md:1: error: Missing section '$section'"
        exit 1
    }
done
echo "  ✓ progress.md template exists with all required sections"

# 11. Verify hooks.json contains auto-commit-on-green-tests hook
grep -q "auto-commit-on-green-tests" "$REPO_DIR/.agents/hooks.json" || {
    echo ".agents/hooks.json:1: error: auto-commit-on-green-tests hook missing"
    exit 1
}
echo "  ✓ auto-commit-on-green-tests hook present in hooks.json"

echo "🎉 All test checks passed successfully!"

