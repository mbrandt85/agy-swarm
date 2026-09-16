#!/usr/bin/env bash
set -eo pipefail

# Resolve .agents directory across git roots, script locations, and parent directories
resolve_agents_dir() {
    local git_root
    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$git_root" ] && [ -d "$git_root/.agents" ]; then
        echo "$git_root/.agents"
        return 0
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    if [ -d "$script_dir/../.agents" ]; then
        echo "$(cd "$script_dir/../.agents" >/dev/null 2>&1 && pwd)"
        return 0
    fi

    local cur="$(pwd)"
    while [ "$cur" != "/" ] && [ "$cur" != "." ] && [ -n "$cur" ]; do
        if [ -d "$cur/.agents" ]; then
            echo "$cur/.agents"
            return 0
        elif [ "$(basename "$cur")" = ".agents" ]; then
            echo "$cur"
            return 0
        fi
        cur="$(dirname "$cur")"
    done

    if [ -d ".agents" ]; then
        echo ".agents"
    else
        echo "$(pwd)"
    fi
}

AGENTS_DIR="$(resolve_agents_dir)"

# Remove teamwork preview directories, sentinel directory, and ORIGINAL_REQUEST.md
# Execute gracefully without failing if paths do not exist
if [ -n "$AGENTS_DIR" ] && [ -d "$AGENTS_DIR" ]; then
    rm -rf "$AGENTS_DIR"/teamwork_preview_* "$AGENTS_DIR/sentinel" "$AGENTS_DIR/ORIGINAL_REQUEST.md" 2>/dev/null || true
fi

# Also clean up relative to current directory if invoked within repo root or subdirs
if [ "$AGENTS_DIR" != ".agents" ] && [ -d ".agents" ]; then
    rm -rf .agents/teamwork_preview_* .agents/sentinel .agents/ORIGINAL_REQUEST.md 2>/dev/null || true
fi

# Adhere to hook protocol by outputting {} on stdout
echo "{}"
exit 0
