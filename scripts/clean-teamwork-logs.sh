#!/usr/bin/env bash
set -eo pipefail

# Resolve .agents directory across git roots, script locations, and parent directories
resolve_agents_dir() {
    local git_root
    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$git_root" ] && [ -d "$git_root/.agents" ]; then
        echo "$(cd "$git_root/.agents" >/dev/null 2>&1 && pwd || true)"
        return 0
    fi

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-}")" >/dev/null 2>&1 && pwd || true)"
    if [ -n "$script_dir" ] && [ -d "$script_dir/../.agents" ]; then
        echo "$(cd "$script_dir/../.agents" >/dev/null 2>&1 && pwd || true)"
        return 0
    fi

    local cur="$(pwd)"
    while [ "$cur" != "/" ] && [ "$cur" != "." ] && [ -n "$cur" ]; do
        if [ -d "$cur/.agents" ]; then
            echo "$(cd "$cur/.agents" >/dev/null 2>&1 && pwd || true)"
            return 0
        elif [ "$(basename "$cur")" = ".agents" ]; then
            echo "$(cd "$cur" >/dev/null 2>&1 && pwd || true)"
            return 0
        fi
        cur="$(dirname "$cur")"
    done

    if [ -d ".agents" ]; then
        echo "$(cd .agents >/dev/null 2>&1 && pwd || true)"
        return 0
    fi

    return 1
}

AGENTS_DIR="$(resolve_agents_dir 2>/dev/null || true)"

# Remove teamwork preview directories, sentinel directory, and ORIGINAL_REQUEST.md
# Execute gracefully without failing if paths do not exist.
# Hard guard: only delete inside a directory strictly named .agents.
if [ -n "$AGENTS_DIR" ] && [ -d "$AGENTS_DIR" ] && [ "$(basename "$AGENTS_DIR")" = ".agents" ]; then
    rm -rf "$AGENTS_DIR"/teamwork_preview_* "$AGENTS_DIR/sentinel" "$AGENTS_DIR/ORIGINAL_REQUEST.md" 2>/dev/null || true
fi

# Adhere to hook protocol by outputting {} on stdout
echo "{}"
exit 0
