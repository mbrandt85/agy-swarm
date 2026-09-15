#!/usr/bin/env bash
LOG_FILE=$(mktemp -t agy-test-XXXXXX.log)
EXIT_CODE=0

if [ "$1" == "--verbose" ] || [ "$CI" == "true" ]; then
    VERBOSE=true
else
    VERBOSE=false
fi

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
elif [ -f "pytest.ini" ] || [ -f "requirements.txt" ]; then
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
    rm -f "$LOG_FILE"
    exit 0
else
    echo "[FAIL] TEST FAILURES DETECTED!"
    echo "============================================================"
    if [ "$VERBOSE" = true ]; then
        cat "$LOG_FILE"
    else
        grep -iE -B 2 -A 5 "(fail|error|exception|traceback|expected|actual|panic)" "$LOG_FILE" | tail -n 40
        echo "------------------------------------------------------------"
        echo "Full log: $LOG_FILE"
    fi
    exit $EXIT_CODE
fi
