#!/usr/bin/env bash
set -euo pipefail

# Generic worktree bootstrap. Creates a branch+worktree from main and copies the
# heavy, gitignored artifacts a fresh worktree needs (node_modules, env files, build
# output) so it's usable without a full reinstall. Anything that doesn't exist is skipped.

NAME=""
OPEN=false
for arg in "$@"; do
  case "$arg" in
    --open) OPEN=true ;;
    *) NAME="$arg" ;;
  esac
done
if [[ -z "$NAME" ]]; then
  echo "Usage: $0 <name> [--open]" >&2
  exit 1
fi

# Resolve main worktree root (not current worktree) so nesting + branch base are stable.
ROOT="$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")"
WORKTREE_PATH="$ROOT.worktrees/$NAME"
BRANCH="$NAME"

echo "Creating worktree '$WORKTREE_PATH' on branch '$BRANCH' (from main)..."
git worktree add "$WORKTREE_PATH" -b "$BRANCH" main

if [[ "$OPEN" == true ]]; then
  echo "Opening VSCode..."
  nohup code "$WORKTREE_PATH" >/dev/null 2>&1 &
  disown
fi

# Copy a path (file or dir) from ROOT into the worktree, preserving its relative
# location. Skips silently if the source doesn't exist.
copy_rel() {
  local rel="$1"
  local src="$ROOT/$rel"
  local dst="$WORKTREE_PATH/$rel"
  [[ -e "$src" ]] || return 0
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -R "$src" "$dst"
  echo "  copied $rel"
}

echo "Copying env files..."
# All nested .env and *.env files, excluding anything under node_modules.
while IFS= read -r f; do
  copy_rel "${f#"$ROOT/"}"
done < <(find "$ROOT" -type d -name node_modules -prune -o \
  -type f \( -name ".env" -o -name "*.env" \) -print)

echo "Copying node_modules + build output (dist, build, .svelte-kit)..."
# -prune stops descent into matched dirs, so nested copies aren't duplicated into an
# already-copied parent (e.g. a dist inside a node_modules is never reached).
while IFS= read -r d; do
  copy_rel "${d#"$ROOT/"}"
done < <(find "$ROOT" \
  -type d \( -name node_modules -o -name dist -o -name build -o -name ".svelte-kit" \) -prune -print)

echo ""
echo "Worktree ready: $WORKTREE_PATH"
