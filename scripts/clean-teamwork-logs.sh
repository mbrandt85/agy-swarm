#!/usr/bin/env bash
set -eo pipefail

# Determine repository root directory
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Identify target .agents directory
if [ -d "$REPO_ROOT/.agents" ]; then
    AGENTS_DIR="$REPO_ROOT/.agents"
elif [ "$(basename "$REPO_ROOT")" = ".agents" ]; then
    AGENTS_DIR="$REPO_ROOT"
elif [ -d ".agents" ]; then
    AGENTS_DIR=".agents"
else
    AGENTS_DIR="$(pwd)"
fi

# Remove teamwork preview directories, sentinel directory, and ORIGINAL_REQUEST.md
# Execute gracefully without failing if paths do not exist
rm -rf "$AGENTS_DIR"/teamwork_preview_* "$AGENTS_DIR/sentinel" "$AGENTS_DIR/ORIGINAL_REQUEST.md" 2>/dev/null || true

# Also clean up relative to current directory if invoked within repo root or subdirs
if [ "$AGENTS_DIR" != ".agents" ] && [ -d ".agents" ]; then
    rm -rf .agents/teamwork_preview_* .agents/sentinel .agents/ORIGINAL_REQUEST.md 2>/dev/null || true
fi

# Adhere to hook protocol by outputting {} on stdout
echo "{}"
exit 0
