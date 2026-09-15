#!/usr/bin/env bash
set -eo pipefail

# Check if invoked as Antigravity hook (either via --hook or via stdin JSON payload)
IS_HOOK=false
TARGETS=("$@")

if [ "${1:-}" = "--hook" ]; then
    IS_HOOK=true
    shift
    TARGETS=("$@")
elif [ ! -t 0 ]; then
    # Read full stdin from hook pipe
    STDIN_INPUT=$(cat)
    if [[ "$STDIN_INPUT" == *"conversationId"* ]] || [[ "$STDIN_INPUT" == "{"* ]]; then
        IS_HOOK=true
        TARGET_FILE=$(echo "$STDIN_INPUT" | sed -n 's/.*"TargetFile":"\([^"]*\)".*/\1/p' || true)
        if [ -n "$TARGET_FILE" ] && [ -f "$TARGET_FILE" ]; then
            TARGETS=("$TARGET_FILE")
        fi
    fi
fi

log() {
    if [ "$IS_HOOK" = true ]; then
        echo "$@" >&2
    else
        echo "$@"
    fi
}

log "🧹 Running deterministic formatters and linters..."

EXIT_CODE=0
TARGETS=("$@")

# 1. Deterministic Formatting Triggers
if [ -f "package.json" ]; then
    if [ ${#TARGETS[@]} -gt 0 ]; then
        npx --no-install prettier --write "${TARGETS[@]}" > /dev/null 2>&1 || true
    else
        npm run format --if-present > /dev/null 2>&1 || npm run lint:fix --if-present > /dev/null 2>&1 || true
    fi
fi

if [ -f "Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
    cargo fmt --quiet > /dev/null 2>&1 || true
fi

if [ -f "go.mod" ] && command -v gofmt >/dev/null 2>&1; then
    if [ ${#TARGETS[@]} -gt 0 ]; then
        gofmt -w "${TARGETS[@]}" > /dev/null 2>&1 || true
    else
        gofmt -w . > /dev/null 2>&1 || true
    fi
fi

if command -v ruff >/dev/null 2>&1; then
    if [ ${#TARGETS[@]} -gt 0 ]; then
        ruff format "${TARGETS[@]}" > /dev/null 2>&1 || true
        ruff check --fix --quiet "${TARGETS[@]}" > /dev/null 2>&1 || true
    else
        ruff format . > /dev/null 2>&1 || true
        ruff check --fix --quiet . > /dev/null 2>&1 || true
    fi
elif command -v black >/dev/null 2>&1; then
    if [ ${#TARGETS[@]} -gt 0 ]; then
        black --quiet "${TARGETS[@]}" > /dev/null 2>&1 || true
    else
        black --quiet . > /dev/null 2>&1 || true
    fi
fi

if command -v shfmt >/dev/null 2>&1; then
    if [ ${#TARGETS[@]} -gt 0 ]; then
        shfmt -w "${TARGETS[@]}" > /dev/null 2>&1 || true
    else
        shfmt -w scripts/*.sh bootstrap.sh > /dev/null 2>&1 || true
    fi
fi

# 2. Lint Verification & Exit Code Enforcement
LINT_LOG=$(mktemp -t agy-lint-XXXXXX.log)
trap 'rm -f "$LINT_LOG"' EXIT

run_check() {
    local cmd="$1"
    if ! eval "$cmd" >> "$LINT_LOG" 2>&1; then
        EXIT_CODE=1
    fi
}

# Shell syntax validation for shell scripts
if [ -d "scripts" ]; then
    for sh_file in scripts/*.sh bootstrap.sh; do
        if [ -f "$sh_file" ]; then
            run_check "bash -n '$sh_file'"
        fi
    done
    if command -v shellcheck >/dev/null 2>&1; then
        run_check "shellcheck scripts/*.sh bootstrap.sh"
    fi
fi

# Language-specific linters
if [ -f "package.json" ]; then
    run_check "npm run lint --if-present"
fi

if [ -f "Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
    run_check "cargo clippy --quiet"
fi

if [ -f "go.mod" ] && command -v go >/dev/null 2>&1; then
    run_check "go vet ./..."
fi

if command -v ruff >/dev/null 2>&1; then
    run_check "ruff check ."
elif command -v flake8 >/dev/null 2>&1; then
    run_check "flake8 ."
fi

if [ -f "Makefile" ] && grep -q "^lint:" Makefile 2>/dev/null; then
    run_check "make lint"
fi

if [ $EXIT_CODE -ne 0 ]; then
    log "[FAIL] Lint or syntax checks detected errors!"
    log "============================================================"
    tail -n 25 "$LINT_LOG"
    log "============================================================"
    exit $EXIT_CODE
fi

log "[PASS] Code formatting applied and lint checks passed."
if [ "$IS_HOOK" = true ]; then
    echo "{}"
fi
exit 0
