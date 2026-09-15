#!/usr/bin/env bash
LOG_FILE=$(mktemp -t agy-test-XXXXXX.log)
EXIT_CODE=0

if [ "$1" == "--verbose" ] || [ "$CI" == "true" ]; then
    VERBOSE=true
else
    VERBOSE=false
fi

# Clean up log file only on success or if verbose output was already printed
cleanup() {
    if [ $EXIT_CODE -eq 0 ] || [ "$VERBOSE" = true ]; then
        rm -f "$LOG_FILE"
    fi
}
trap cleanup EXIT

echo "🔍 Detecting environment and running tests..."

if [ -f "pnpm-workspace.yaml" ]; then
    pnpm -r test --silent > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
elif [ -f "package.json" ]; then
    npm test -- --silent > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
elif [ -f "Cargo.toml" ]; then
    cargo test --workspace --quiet > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
elif [ -f "go.mod" ]; then
    go test ./... -v=false > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
elif [ -f "pom.xml" ]; then
    if [ -f "mvnw" ]; then
        ./mvnw test -q > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
    else
        mvn test -q > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
    fi
elif [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
    pytest -q --tb=short > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
elif [ -f "Makefile" ]; then
    make test > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
elif [ -f "CMakeLists.txt" ]; then
    ctest --output-on-failure > "$LOG_FILE" 2>&1 || EXIT_CODE=$?
else
    echo "[ERROR] No recognized test runner found."
    rm -f "$LOG_FILE"
    exit 1
fi

if [ $EXIT_CODE -eq 0 ]; then
    if [ "$VERBOSE" = true ]; then
        cat "$LOG_FILE"
    else
        echo "[PASS] BUILD & TESTS SUCCESSFUL."
    fi
    exit 0
fi

# ============================================================
# Failure Handling & Structured Extraction (FILE:LINE: REASON)
# ============================================================
echo "[FAIL] TEST FAILURES DETECTED! (Exit Code: $EXIT_CODE)"
echo "============================================================"

if [ "$VERBOSE" = true ]; then
    cat "$LOG_FILE"
    exit $EXIT_CODE
fi

extract_structured_failures() {
    local target_log="$1"
    if command -v python3 >/dev/null 2>&1; then
        python3 - "$target_log" << 'EOF'
import sys, re

log_file = sys.argv[1]
try:
    with open(log_file, "r", errors="replace") as f:
        content = f.read()
except Exception as e:
    sys.exit(0)

failures = []
seen = set()

# Pattern 1: Rust panics
for m in re.finditer(r"(?:panicked at '([^']*)', |panicked at )([a-zA-Z0-9_./-]+\.rs):(\d+)(?::\d+)?(?::\s*(.*))?", content):
    reason = (m.group(1) or m.group(4) or "Panic").strip()
    fpath, line = m.group(2), m.group(3)
    k = f"{fpath}:{line}"
    if k not in seen:
        seen.add(k)
        failures.append(f"{fpath}:{line}: Panic - {reason}")

# Pattern 2: Go test failures
for m in re.finditer(r"^\s*([a-zA-Z0-9_./-]+\.go):(\d+):\s*(.+)$", content, re.MULTILINE):
    fpath, line, reason = m.group(1), m.group(2), m.group(3).strip()
    k = f"{fpath}:{line}"
    if k not in seen:
        seen.add(k)
        failures.append(f"{fpath}:{line}: {reason}")

# Pattern 3: Pytest failure lines
for m in re.finditer(r"([a-zA-Z0-9_./-]+\.py):(\d+):\s*(?:in \S+\n\s*)?([A-Za-z]+Error:.*)", content):
    fpath, line, reason = m.group(1), m.group(2), m.group(3).strip()
    k = f"{fpath}:{line}"
    if k not in seen:
        seen.add(k)
        failures.append(f"{fpath}:{line}: {reason}")

for m in re.finditer(r"^FAILED\s+([a-zA-Z0-9_./-]+\.py)::(\S+)\s*(?:-\s*(.*))?$", content, re.MULTILINE):
    fpath, test_name, reason = m.group(1), m.group(2), (m.group(3) or f"Failed {test_name}").strip()
    k = f"{fpath}:{test_name}"
    if k not in seen:
        seen.add(k)
        failures.append(f"{fpath}:1: {reason}")

# Pattern 4: Node/Jest stack traces
for m in re.finditer(r"at\s+.*?\((/[^:\s)]+|[a-zA-Z0-9_./-]+\.[jt]sx?):(\d+):(?:\d+)\)", content):
    fpath, line = m.group(1), m.group(2)
    k = f"{fpath}:{line}"
    if k not in seen:
        seen.add(k)
        failures.append(f"{fpath}:{line}: Test failure assertion")

# Pattern 5: Standard compiler/linter/make/sh syntax: file:line: error
for m in re.finditer(r"^\s*([a-zA-Z0-9_./-]+\.[a-zA-Z0-9_-]+):(\d+)(?::\d+)?:\s*(?:(error|fatal|fail).*?:\s*)?(.*)$", content, re.MULTILINE | re.IGNORECASE):
    fpath, line, err_prefix, reason = m.group(1), m.group(2), m.group(3), m.group(4).strip()
    if any(fpath.endswith(ext) for ext in [".o", ".log", ".tmp", ".txt"]):
        continue
    if err_prefix or any(w in reason.lower() for w in ["fail", "error", "assert", "syntax"]):
        k = f"{fpath}:{line}"
        if k not in seen:
            seen.add(k)
            prefix = f"{err_prefix.capitalize()}: " if err_prefix else ""
            failures.append(f"{fpath}:{line}: {prefix}{reason}")

for f in failures[:5]:
    print(f)
EOF
    else
        awk '
            match($0, /([a-zA-Z0-9_.\/-]+\.[a-zA-Z0-9_-]+):([0-9]+): *(.*)/, m) {
                if ($0 ~ /(error|fail|assert|panic|syntax)/) {
                    print m[1] ":" m[2] ": " m[3]
                }
            }
        ' "$target_log" | head -n 5
    fi
}

echo "STRUCTURED FAILURES (FILE:LINE: REASON):"
STRUCTURED_OUTPUT=$(extract_structured_failures "$LOG_FILE")
if [ -n "$STRUCTURED_OUTPUT" ]; then
    echo "$STRUCTURED_OUTPUT"
else
    echo "NO_FILE_REF:1: Test command exited with code $EXIT_CODE"
fi

echo "------------------------------------------------------------"
echo "COMPACT FAILURE TRACE (< 40 lines):"
grep -iE -B 1 -A 3 "(fail|error|panic|exception|assert|traceback|syntax)" "$LOG_FILE" | head -n 18 || tail -n 18 "$LOG_FILE"
echo "============================================================"
echo "Full raw log: $LOG_FILE"

exit $EXIT_CODE
