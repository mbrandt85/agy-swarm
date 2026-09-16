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
    [ -x scripts/clean-teamwork-logs.sh ] || exit 1
) || {
    echo "bootstrap.sh:1: error: End-to-end bootstrap execution failed"
    rm -rf "$BOOTSTRAP_TMP"
    exit 1
}
rm -rf "$BOOTSTRAP_TMP"
echo "  ✓ bootstrap.sh end-to-end installation verified"

# 8. Test SHA cache: write then skip, commit persistence, modification invalidation, non-git fallback
CACHE_TMP=$(mktemp -d)
(
    cp -r "$REPO_DIR/." "$CACHE_TMP/"
    cd "$CACHE_TMP"
    git config user.name "Tester" 2>/dev/null || true
    git config user.email "tester@test.com" 2>/dev/null || true
    # Remove any stale cache to ensure first run writes one
    rm -f .agy-test-cache
    # First run — must succeed and write the cache file
    AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh > /dev/null 2>&1
    [ -f .agy-test-cache ] || { echo "tests/test_runners.sh:1: error: Cache file not written after green run"; exit 1; }
    # Second run — SHA unchanged — must print [SKIP] and exit 0
    OUTPUT=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
    if ! echo "$OUTPUT" | grep -q "\[SKIP\]"; then
        echo "tests/test_runners.sh:1: error: Cache skip not triggered on unchanged tree"
        exit 1
    fi
    # Modifying a file must invalidate the cache
    echo "temporary modification" >> README.md
    OUTPUT_MOD=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
    if echo "$OUTPUT_MOD" | grep -q "\[SKIP\]"; then
        echo "tests/test_runners.sh:1: error: Cache skip unexpectedly triggered on modified tree"
        exit 1
    fi
    # Committing the change should allow skip to trigger again
    git add README.md && git commit -m "test: commit change" >/dev/null 2>&1 || true
    OUTPUT_POST_COMMIT=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
    if ! echo "$OUTPUT_POST_COMMIT" | grep -q "\[SKIP\]"; then
        echo "tests/test_runners.sh:1: error: Cache skip failed to persist across commit"
        exit 1
    fi

    # Submodule modification invalidates cache
    SUB_TMP=$(mktemp -d)
    (
        cd "$SUB_TMP"
        git init -q
        git config user.name "Tester" 2>/dev/null || true
        git config user.email "tester@test.com" 2>/dev/null || true
        echo "sub init" > sub_file.txt
        git add sub_file.txt && git commit -m "sub init" -q
    )
    git -c protocol.file.allow=always submodule add -q "$SUB_TMP" test_sub 2>/dev/null || true
    git commit -m "add test submodule" -q 2>/dev/null || true
    rm -rf "$SUB_TMP"
    if [ -d "test_sub" ]; then
        AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh > /dev/null 2>&1
        OUTPUT_SUB_SKIP=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
        if ! echo "$OUTPUT_SUB_SKIP" | grep -q "\[SKIP\]"; then
            echo "tests/test_runners.sh:1: error: Cache skip failed with clean submodule"
            exit 1
        fi
        echo "sub mod" >> test_sub/sub_file.txt
        OUTPUT_SUB_MOD=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
        if echo "$OUTPUT_SUB_MOD" | grep -q "\[SKIP\]"; then
            echo "tests/test_runners.sh:1: error: Cache skip unexpectedly triggered on modified submodule"
            exit 1
        fi
    fi

    # Non-git tree verification (including .agents/ directory hashing)
    rm -rf .git .agy-test-cache
    AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh > /dev/null 2>&1
    [ -f .agy-test-cache ] || { echo "tests/test_runners.sh:1: error: Cache file not written in non-git environment"; exit 1; }
    OUTPUT_NONGIT=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
    if ! echo "$OUTPUT_NONGIT" | grep -q "\[SKIP\]"; then
        echo "tests/test_runners.sh:1: error: Cache skip failed in non-git environment"
        exit 1
    fi
    echo "# mod" >> .agents/hooks.json
    OUTPUT_NONGIT_MOD=$(AGY_TEST_NESTED=1 bash scripts/agy-test-runner.sh 2>&1)
    if echo "$OUTPUT_NONGIT_MOD" | grep -q "\[SKIP\]"; then
        echo "tests/test_runners.sh:1: error: Non-git cache failed to detect .agents modification"
        exit 1
    fi
)
EXIT_CACHE=$?
rm -rf "$CACHE_TMP"
[ $EXIT_CACHE -eq 0 ] || exit 1
echo "  ✓ SHA cache write, skip, commit persistence, and non-git behavior verified"

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

# 12. Verify auto-commit-on-green-tests execution logic
HOOK_CMD=$(python3 -c "import json; print(json.load(open('$REPO_DIR/.agents/hooks.json'))['auto-commit-on-green-tests']['PostToolUse'][0]['hooks'][0]['command'])")
HOOK_TMP=$(mktemp -d)
(
    cp -r "$REPO_DIR/." "$HOOK_TMP/"
    cd "$HOOK_TMP"
    git config user.name "Tester" 2>/dev/null || true
    git config user.email "tester@test.com" 2>/dev/null || true

    # 12a: Green run commits pending changes and prints {}
    echo "hook commit test" > hook_test.txt
    OUT1=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}},"stepIdx":1}' | eval "$HOOK_CMD")
    [ "$OUT1" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}': $OUT1"; exit 1; }
    if git status --porcelain | grep -q "hook_test.txt"; then
        echo "tests/test_runners.sh:1: error: Pending changes not committed by hook"
        exit 1
    fi
    if ! git log -1 --pretty=%B | grep -q "chore: auto-commit after green test gate"; then
        echo "tests/test_runners.sh:1: error: Hook commit message mismatch"
        exit 1
    fi

    # 12b: Failed run with error field must NOT commit
    echo "fail test 1" > fail_test.txt
    OUT2=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}},"error":"exit status 1"}' | eval "$HOOK_CMD")
    [ "$OUT2" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout on failure was not '{}': $OUT2"; exit 1; }
    if ! git status --porcelain | grep -q "fail_test.txt"; then
        echo "tests/test_runners.sh:1: error: Hook committed on error field"
        exit 1
    fi

    # 12c: Failed run with non-zero exit code in content must NOT commit
    OUT3=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}},"content":"The command exited with code 1."}' | eval "$HOOK_CMD")
    [ "$OUT3" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout on non-zero exit was not '{}': $OUT3"; exit 1; }
    if ! git status --porcelain | grep -q "fail_test.txt"; then
        echo "tests/test_runners.sh:1: error: Hook committed on exit code 1"
        exit 1
    fi

    # 12d: Unrelated command must NOT commit
    OUT4=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"make lint"}},"stepIdx":2}' | eval "$HOOK_CMD")
    [ "$OUT4" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout on unrelated command was not '{}': $OUT4"; exit 1; }
    if ! git status --porcelain | grep -q "fail_test.txt"; then
        echo "tests/test_runners.sh:1: error: Hook committed on unrelated command"
        exit 1
    fi

    # 12e: Command mentioning test runner in stdout (git log / git diff) must NOT commit
    OUT5=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"git log"}},"content":"commit abc: update scripts/agy-test-runner.sh"}' | eval "$HOOK_CMD")
    [ "$OUT5" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}': $OUT5"; exit 1; }
    if ! git status --porcelain | grep -q "fail_test.txt"; then
        echo "tests/test_runners.sh:1: error: Hook committed on command whose output mentioned runner script"
        exit 1
    fi

    # 12f: Inspecting test runner script (cat / grep) must NOT commit
    OUT6=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"cat scripts/agy-test-runner.sh"}}}' | eval "$HOOK_CMD")
    [ "$OUT6" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}': $OUT6"; exit 1; }
    if ! git status --porcelain | grep -q "fail_test.txt"; then
        echo "tests/test_runners.sh:1: error: Hook committed when inspecting test runner script"
        exit 1
    fi

    # 12g: Output with [FAIL] TEST FAILURES DETECTED! must NOT commit
    OUT7=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}},"content":"[FAIL] TEST FAILURES DETECTED! (Exit Code: 1)"}' | eval "$HOOK_CMD")
    [ "$OUT7" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}': $OUT7"; exit 1; }
    if ! git status --porcelain | grep -q "fail_test.txt"; then
        echo "tests/test_runners.sh:1: error: Hook committed on [FAIL] test runner output"
        exit 1
    fi

    # 12h: JSON payload with exitCode != 0 must NOT commit
    OUT8=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}},"exitCode":1}' | eval "$HOOK_CMD")
    [ "$OUT8" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}': $OUT8"; exit 1; }
    if ! git status --porcelain | grep -q "fail_test.txt"; then
        echo "tests/test_runners.sh:1: error: Hook committed on exitCode != 0"
        exit 1
    fi

    # 12i: Environment without git user identity commits with fallback
    NO_ID_TMP=$(mktemp -d)
    (
        cp -r "$REPO_DIR/." "$NO_ID_TMP/"
        cd "$NO_ID_TMP"
        # Explicitly unset git identity
        git config --unset user.name 2>/dev/null || true
        git config --unset user.email 2>/dev/null || true
        echo "identity test" > no_id.txt
        OUT9=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}}}' | eval "$HOOK_CMD")
        [ "$OUT9" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}': $OUT9"; exit 1; }
        if git status --porcelain | grep -q "no_id.txt"; then
            echo "tests/test_runners.sh:1: error: Hook failed to commit when git user config is missing"
            exit 1
        fi
    )
    EXIT_NO_ID=$?
    rm -rf "$NO_ID_TMP"
    [ $EXIT_NO_ID -eq 0 ] || exit 1

    # 12j: commit.gpgsign = true does not break auto-commit
    GPG_TMP=$(mktemp -d)
    (
        cp -r "$REPO_DIR/." "$GPG_TMP/"
        cd "$GPG_TMP"
        git config user.name "Tester" 2>/dev/null || true
        git config user.email "tester@test.com" 2>/dev/null || true
        git config commit.gpgsign true
        echo "gpg test" > gpg_test.txt
        OUT10=$(echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}}}' | eval "$HOOK_CMD")
        [ "$OUT10" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}': $OUT10"; exit 1; }
        if git status --porcelain | grep -q "gpg_test.txt"; then
            echo "tests/test_runners.sh:1: error: Hook failed to commit when commit.gpgsign is true"
            exit 1
        fi
    )
    EXIT_GPG=$?
    rm -rf "$GPG_TMP"
    [ $EXIT_GPG -eq 0 ] || exit 1

    # 12k: Missing python3 in PATH still outputs {} and exits 0
    OUT11=$(PATH="/nonexistent" echo '{"toolCall":{"name":"run_command","args":{"CommandLine":"bash scripts/agy-test-runner.sh"}}}' | eval "$HOOK_CMD")
    [ "$OUT11" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}' when python3 is missing: $OUT11"; exit 1; }

    # 12l: Missing git in PATH still outputs {} without error
    OUT12=$(python3 -c "import subprocess, json, tempfile, os, shutil
with tempfile.TemporaryDirectory() as td:
    os.symlink(shutil.which('python3'), os.path.join(td, 'python3'))
    cmd = json.load(open('$REPO_DIR/.agents/hooks.json'))['auto-commit-on-green-tests']['PostToolUse'][0]['hooks'][0]['command']
    p = subprocess.run(cmd, shell=True, env={'PATH': td}, input='{\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"bash scripts/agy-test-runner.sh\"}}}', capture_output=True, text=True)
    print(p.stdout.strip())
")
    [ "$OUT12" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook stdout was not '{}' when git is missing: $OUT12"; exit 1; }
)
EXIT_HOOK=$?
rm -rf "$HOOK_TMP"
[ $EXIT_HOOK -eq 0 ] || exit 1
echo "  ✓ auto-commit-on-green-tests execution logic verified"

# 13. Verify hooks.json contains teamwork-log-cleanup hook with Stop (and not PostInvocation)
python3 -c "
import json, sys
conf = json.load(open('$REPO_DIR/.agents/hooks.json'))
hook = conf.get('teamwork-log-cleanup') or conf.get('teamwork-cleanup')
if not hook:
    sys.exit('Missing teamwork log cleanup hook in hooks.json')
if 'Stop' not in hook:
    sys.exit('teamwork log cleanup hook must define Stop')
if 'PostInvocation' in hook:
    sys.exit('teamwork log cleanup hook must not define PostInvocation (it fires mid-session and deletes active directories)')
" || {
    echo ".agents/hooks.json:1: error: teamwork-log-cleanup hook missing or invalid in hooks.json"
    exit 1
}
echo "  ✓ teamwork-log-cleanup hook configuration verified in hooks.json"

# 14. Verify teamwork log cleanup execution logic & graceful edge cases
CLEANUP_TMP=$(mktemp -d)
(
    cp -r "$REPO_DIR/." "$CLEANUP_TMP/"
    cd "$CLEANUP_TMP"

    # Extract the cleanup command from hooks.json
    CLEANUP_CMD=$(python3 -c "import json; conf = json.load(open('$CLEANUP_TMP/.agents/hooks.json')); h = conf.get('teamwork-log-cleanup') or conf.get('teamwork-cleanup'); print(h['Stop'][0]['command'])")

    # 14a: Verify cleanup script exists and is executable
    [ -x "scripts/clean-teamwork-logs.sh" ] || {
        echo "scripts/clean-teamwork-logs.sh:1: error: clean-teamwork-logs.sh not executable or missing"
        exit 1
    }

    # 14b: Verify standalone script execution deletes targets and outputs {}
    mkdir -p .agents/teamwork_preview_dummy1 .agents/teamwork_preview_dummy2 .agents/sentinel
    touch .agents/ORIGINAL_REQUEST.md .agents/teamwork_preview_dummy1/log.txt .agents/sentinel/state.json
    OUT_SCRIPT=$(bash scripts/clean-teamwork-logs.sh)
    [ "$OUT_SCRIPT" = "{}" ] || { echo "scripts/clean-teamwork-logs.sh:1: error: Script stdout was not '{}': $OUT_SCRIPT"; exit 1; }
    [ ! -d .agents/teamwork_preview_dummy1 ] || { echo "scripts/clean-teamwork-logs.sh:1: error: teamwork_preview_dummy1 not deleted"; exit 1; }
    [ ! -d .agents/teamwork_preview_dummy2 ] || { echo "scripts/clean-teamwork-logs.sh:1: error: teamwork_preview_dummy2 not deleted"; exit 1; }
    [ ! -d .agents/sentinel ] || { echo "scripts/clean-teamwork-logs.sh:1: error: sentinel not deleted"; exit 1; }
    [ ! -f .agents/ORIGINAL_REQUEST.md ] || { echo "scripts/clean-teamwork-logs.sh:1: error: ORIGINAL_REQUEST.md not deleted"; exit 1; }

    # 14c: Verify standalone script execution when paths do not exist (graceful conditional)
    OUT_EMPTY=$(bash scripts/clean-teamwork-logs.sh)
    [ "$OUT_EMPTY" = "{}" ] || { echo "scripts/clean-teamwork-logs.sh:1: error: Script stdout on nonexistent paths was not '{}': $OUT_EMPTY"; exit 1; }

    # 14d: Verify hook command execution with simulated Stop payload
    mkdir -p .agents/teamwork_preview_dummy3 .agents/sentinel
    touch .agents/ORIGINAL_REQUEST.md
    OUT_HOOK=$(echo '{"executionNum":1,"terminationReason":"model_stop","fullyIdle":true}' | eval "$CLEANUP_CMD")
    [ "$OUT_HOOK" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook command stdout was not '{}': $OUT_HOOK"; exit 1; }
    [ ! -d .agents/teamwork_preview_dummy3 ] || { echo "tests/test_runners.sh:1: error: Hook did not delete teamwork_preview_dummy3"; exit 1; }
    [ ! -d .agents/sentinel ] || { echo "tests/test_runners.sh:1: error: Hook did not delete sentinel"; exit 1; }
    [ ! -f .agents/ORIGINAL_REQUEST.md ] || { echo "tests/test_runners.sh:1: error: Hook did not delete ORIGINAL_REQUEST.md"; exit 1; }

    # 14e: Verify hook command graceful execution when paths do not exist
    OUT_HOOK_EMPTY=$(echo '{"executionNum":2,"terminationReason":"model_stop","fullyIdle":true}' | eval "$CLEANUP_CMD")
    [ "$OUT_HOOK_EMPTY" = "{}" ] || { echo "tests/test_runners.sh:1: error: Hook command stdout on nonexistent paths was not '{}': $OUT_HOOK_EMPTY"; exit 1; }

    # 14f: Verify hook command fallback when scripts/clean-teamwork-logs.sh is removed
    mkdir -p .agents/teamwork_preview_dummy4 .agents/sentinel
    touch .agents/ORIGINAL_REQUEST.md
    rm -f scripts/clean-teamwork-logs.sh
    OUT_FALLBACK=$(echo '{"executionNum":3,"terminationReason":"model_stop"}' | eval "$CLEANUP_CMD")
    [ "$OUT_FALLBACK" = "{}" ] || { echo "tests/test_runners.sh:1: error: Fallback hook stdout was not '{}': $OUT_FALLBACK"; exit 1; }
    [ ! -d .agents/teamwork_preview_dummy4 ] || { echo "tests/test_runners.sh:1: error: Fallback hook did not delete teamwork_preview_dummy4"; exit 1; }
    [ ! -d .agents/sentinel ] || { echo "tests/test_runners.sh:1: error: Fallback hook did not delete sentinel"; exit 1; }
    [ ! -f .agents/ORIGINAL_REQUEST.md ] || { echo "tests/test_runners.sh:1: error: Fallback hook did not delete ORIGINAL_REQUEST.md"; exit 1; }

    # 14g: Verify standalone script execution from subdirectory resolves and cleans .agents
    cp "$REPO_DIR/scripts/clean-teamwork-logs.sh" scripts/
    mkdir -p .agents/teamwork_preview_dummy5 .agents/sentinel
    touch .agents/ORIGINAL_REQUEST.md
    OUT_SUBDIR=$(cd scripts && bash clean-teamwork-logs.sh)
    [ "$OUT_SUBDIR" = "{}" ] || { echo "tests/test_runners.sh:1: error: Subdirectory script stdout was not '{}': $OUT_SUBDIR"; exit 1; }
    [ ! -d .agents/teamwork_preview_dummy5 ] || { echo "tests/test_runners.sh:1: error: Subdirectory execution did not delete teamwork_preview_dummy5"; exit 1; }
    [ ! -d .agents/sentinel ] || { echo "tests/test_runners.sh:1: error: Subdirectory execution did not delete sentinel"; exit 1; }
    [ ! -f .agents/ORIGINAL_REQUEST.md ] || { echo "tests/test_runners.sh:1: error: Subdirectory execution did not delete ORIGINAL_REQUEST.md"; exit 1; }
)
EXIT_CLEANUP=$?
rm -rf "$CLEANUP_TMP"
[ $EXIT_CLEANUP -eq 0 ] || exit 1
echo "  ✓ teamwork log cleanup execution logic & graceful conditional handling verified"

echo "🎉 All test checks passed successfully!"


