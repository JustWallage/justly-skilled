#!/usr/bin/env bash
# Install the FULL justly-* agents + commands into ~/.claude (global) or a project's
# .claude (local). No clone required — downloads this repo's tarball from GitHub.
# For the lean variants use install-micro.sh (the default installer).
#
#   curl -fsSL https://raw.githubusercontent.com/JustWallage/justly-skilled/main/scripts/install.sh | bash
#
# Re-run to update: if your installed files already match, it says so and does nothing;
# if they differ, it asks before overwriting.
#
# Flags (skip prompts):
#   -g, --global         install to ~/.claude
#   -l, --local [DIR]    install to DIR/.claude (DIR defaults to current dir)
#   -y, --yes            overwrite differing files without asking
#   -h, --help           show this

MICRO=0   # 1 = only *-micro.md ; 0 = only the full versions

set -euo pipefail

REPO="JustWallage/justly-skilled"
BRANCH="main"
TARBALL="https://github.com/${REPO}/archive/refs/heads/${BRANCH}.tar.gz"

mode=""; dir="$PWD"; assume_yes=0

while [ $# -gt 0 ]; do
  case "$1" in
    -g|--global) mode="global"; shift ;;
    -l|--local)  mode="local"; shift
                 if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then dir="$1"; shift; fi ;;
    -y|--yes)    assume_yes=1; shift ;;
    -h|--help)   grep '^#' "$0" | sed '1d;s/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

prompt_tty() {  # $1 = prompt text -> echoes the reply
  printf '%s' "$1" > /dev/tty
  local reply; read -r reply < /dev/tty; echo "$reply"
}

if [ -z "$mode" ]; then
  if [ ! -e /dev/tty ]; then
    echo "No terminal for prompt. Re-run with --global or --local <dir>." >&2; exit 1
  fi
  ans="$(prompt_tty "Install to:
  [g] global  (~/.claude)
  [l] local   ($dir/.claude)
Choice [g/l]: ")"
  case "$ans" in
    g|G|global) mode="global" ;;
    l|L|local)  mode="local" ;;
    *) echo "Cancelled." >&2; exit 1 ;;
  esac
fi

[ "$mode" = "global" ] && base="$HOME/.claude" || base="${dir%/}/.claude"

command -v curl >/dev/null || { echo "curl required" >&2; exit 1; }
command -v tar  >/dev/null || { echo "tar required" >&2; exit 1; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
echo "Downloading ${REPO}@${BRANCH}..."
curl -fsSL "$TARBALL" | tar -xz -C "$tmp"
src="$(find "$tmp" -maxdepth 1 -type d -name 'justly-skilled-*' | head -1)"
[ -n "$src" ] || { echo "extract failed" >&2; exit 1; }

# Build the (source -> dest) file list for this variant.
srcs=(); dsts=()
for sub in agents commands; do
  for f in "$src/$sub"/*.md; do
    [ -e "$f" ] || continue
    b="$(basename "$f")"
    case "$b" in
      *-micro.md) [ "$MICRO" = 1 ] || continue ;;
      *)          [ "$MICRO" = 0 ] || continue ;;
    esac
    srcs+=("$f"); dsts+=("$base/$sub/$b")
  done
done
[ "${#srcs[@]}" -gt 0 ] || { echo "no files matched variant" >&2; exit 1; }

# Compare against what's already installed.
changed=(); missing=0; same=0
for i in "${!srcs[@]}"; do
  d="${dsts[$i]}"
  if [ ! -e "$d" ]; then missing=$((missing+1))
  elif cmp -s "${srcs[$i]}" "$d"; then same=$((same+1))
  else changed+=("$(basename "$d")"); fi
done

if [ "${#changed[@]}" -eq 0 ] && [ "$missing" -eq 0 ]; then
  echo "Already installed — all ${#srcs[@]} file(s) match the latest version. Nothing to do."
  exit 0
fi

if [ "${#changed[@]}" -gt 0 ]; then
  echo "Newer/different version available for ${#changed[@]} file(s): ${changed[*]}"
  if [ "$assume_yes" -ne 1 ]; then
    [ -e /dev/tty ] || { echo "Differs from installed. Re-run with --yes to overwrite." >&2; exit 1; }
    ans="$(prompt_tty "Overwrite your current version? [y/N]: ")"
    case "$ans" in y|Y|yes) ;; *) echo "Kept current version. Nothing changed."; exit 0 ;; esac
  fi
fi

mkdir -p "$base/agents" "$base/commands"
for i in "${!srcs[@]}"; do cp -f "${srcs[$i]}" "${dsts[$i]}"; done
echo "Installed to $base: ${#srcs[@]} file(s) (${missing} new, ${#changed[@]} updated, ${same} unchanged)."
