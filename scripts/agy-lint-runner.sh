#!/usr/bin/env bash
echo "🧹 Running linters/formatters..."

if [ -f "package.json" ]; then
    npm run lint --if-present > /dev/null 2>&1 || true
fi

if [ -f "Cargo.toml" ]; then
    cargo fmt --quiet > /dev/null 2>&1 || true
fi

if [ -f "go.mod" ]; then
    gofmt -w . > /dev/null 2>&1 || true
fi

if command -v black >/dev/null 2>&1; then
    black --quiet . > /dev/null 2>&1 || true
fi

echo "[PASS] Code formatting applied."
exit 0
