#!/usr/bin/env bash
set -eo pipefail

# Resolve .agents directory across script locations, current directory ancestors, and git roots
resolve_agents_dir() {
    # 1. If script is located in <project>/scripts/clean-teamwork-logs.sh, co-located .agents takes precedence
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE:-$0}")" >/dev/null 2>&1 && pwd || true)"
    if [ -n "$script_dir" ] && [ -d "$script_dir/../.agents" ]; then
        echo "$(cd "$script_dir/../.agents" >/dev/null 2>&1 && pwd || true)"
        return 0
    fi

    # 2. Check current working directory and ancestors (closest first)
    local cur="$(pwd)"
    while [ "$cur" != "/" ] && [ "$cur" != "." ] && [ -n "$cur" ]; do
        if [ "$(basename "$cur")" = ".agents" ]; then
            echo "$(cd "$cur" >/dev/null 2>&1 && pwd || true)"
            return 0
        elif [ -d "$cur/.agents" ]; then
            echo "$(cd "$cur/.agents" >/dev/null 2>&1 && pwd || true)"
            return 0
        fi
        cur="$(dirname "$cur")"
    done

    # 3. Fallback to git root of current repository if within one
    local git_root
    git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -n "$git_root" ] && [ -d "$git_root/.agents" ]; then
        echo "$(cd "$git_root/.agents" >/dev/null 2>&1 && pwd || true)"
        return 0
    fi

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
    chmod -R u+w "$AGENTS_DIR"/teamwork_preview_* "$AGENTS_DIR/sentinel" 2>/dev/null || true
    rm -rf "$AGENTS_DIR"/teamwork_preview_* "$AGENTS_DIR/sentinel" "$AGENTS_DIR/ORIGINAL_REQUEST.md" 2>/dev/null || true
fi

# Adhere to hook protocol by outputting {} on stdout
echo "{}"
exit 0
