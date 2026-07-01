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
# Also offers (y/n) to prepend justly-CLAUDE.md into your global ~/.claude/CLAUDE.md
# (the memory file Claude Code loads every session). It goes in as a marked block, so
# re-runs update it in place rather than duplicating it.
#
# Flags (skip prompts):
#   -g, --global         install to ~/.claude
#   -l, --local [DIR]    install to DIR/.claude (DIR defaults to current dir)
#   -y, --yes            overwrite differing files AND accept the CLAUDE.md prompt
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
  echo "Already installed — all ${#srcs[@]} file(s) match the latest version."
else
  do_copy=1
  if [ "${#changed[@]}" -gt 0 ]; then
    echo "Newer/different version available for ${#changed[@]} file(s): ${changed[*]}"
    if [ "$assume_yes" -ne 1 ]; then
      [ -e /dev/tty ] || { echo "Differs from installed. Re-run with --yes to overwrite." >&2; exit 1; }
      ans="$(prompt_tty "Overwrite your current version? [y/N]: ")"
      case "$ans" in y|Y|yes) ;; *) echo "Kept current version. Nothing changed."; do_copy=0 ;; esac
    fi
  fi
  if [ "$do_copy" -eq 1 ]; then
    mkdir -p "$base/agents" "$base/commands"
    for i in "${!srcs[@]}"; do cp -f "${srcs[$i]}" "${dsts[$i]}"; done
    echo "Installed to $base: ${#srcs[@]} file(s) (${missing} new, ${#changed[@]} updated, ${same} unchanged)."
  fi
fi

# Offer to prepend justly-CLAUDE.md into the global (~/.claude) CLAUDE.md that Claude Code
# loads every session. Wrapped in markers so re-runs replace the block instead of stacking.
srcmd="$src/justly-CLAUDE.md"
if [ -e "$srcmd" ]; then
  dest="$HOME/.claude/CLAUDE.md"
  begin="<!-- BEGIN justly-skilled (managed block — edits here are overwritten on re-run) -->"
  end="<!-- END justly-skilled -->"
  block="$(printf '%s\n%s\n%s' "$begin" "$(cat "$srcmd")" "$end")"

  cur=""
  if [ -e "$dest" ] && grep -qF "$begin" "$dest"; then
    cur="$(awk -v b="$begin" -v e="$end" 'index($0,b){f=1} f{print} index($0,e){f=0}' "$dest")"
  fi

  if [ "$cur" = "$block" ]; then
    echo "Global CLAUDE.md already current ($dest). Nothing to do."
  else
    verb="prepend justly-CLAUDE.md to"; [ -e "$dest" ] || verb="create"
    do_md="$assume_yes"
    if [ "$assume_yes" -ne 1 ] && [ -e /dev/tty ]; then
      ans="$(prompt_tty "Also ${verb} your global CLAUDE.md ($dest)? [y/N]: ")"
      case "$ans" in y|Y|yes) do_md=1 ;; *) do_md=0 ;; esac
    fi
    if [ "$do_md" = 1 ]; then
      mkdir -p "$HOME/.claude"
      if [ -e "$dest" ] && grep -qF "$begin" "$dest"; then
        # Update the existing block where it sits — keep anything above and below it.
        printf '%s\n' "$block" > "$tmp/claude-block.md"
        awk -v b="$begin" -v e="$end" -v bf="$tmp/claude-block.md" '
          index($0,b){ while ((getline line < bf) > 0) print line; close(bf); skip=1; next }
          skip && index($0,e){ skip=0; next }
          skip { next }
          { print }
        ' "$dest" > "$dest.tmp" && mv "$dest.tmp" "$dest"
        echo "Updated justly-skilled block in $dest (kept in place)."
      elif [ -e "$dest" ]; then
        # No block yet — prepend it above your existing content.
        rest="$(cat "$dest")"
        printf '%s\n\n%s\n' "$block" "$rest" > "$dest"
        echo "Prepended justly-skilled block to $dest."
      else
        printf '%s\n' "$block" > "$dest"
        echo "Created $dest with justly-skilled block."
      fi
    else
      echo "Skipped global CLAUDE.md."
    fi
  fi
fi
