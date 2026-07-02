# justly-skilled

AI coding is great for speed, but fails on trust — unreviewed output means shipping on faith.

This simple skill inserts two independent verification gates: a spec review and code review, each runs in fresh context. The HITL step happens _after_ the review loops, so many were solved before you see them.

Used to build [JustWallage/news](https://github.com/JustWallage/news)!

## The solution

Minimalistic agentic code implementation loop skill.
- User provides request
- LLM Sets up worktree
- LLM asks you to clarify the genuine open ends
- LLM Writes spec file
- Subagent Solution Architect review loop, runs with new context, loops until spec APPROVED (max 3x)
- LLM Writes summary of all decisions (AI + User made)
- LLM Asks user for confirmation / Changes
- LLM Implements code
- Subagent Code review loop, runs with new context, loops until code APPROVED (max 3x)

## Installation

Recommended version (micro):

```bash
curl -fsSL https://raw.githubusercontent.com/JustWallage/justly-skilled/main/scripts/install-micro.sh | bash
```

Full (verbose) variants instead:

```bash
curl -fsSL https://raw.githubusercontent.com/JustWallage/justly-skilled/main/scripts/install.sh | bash
```

**Re-run to update.** It compares your installed files to the latest: if they already
match it says so and does nothing; if they differ it lists them and asks before
overwriting.

**Global CLAUDE.md.** After installing, it also asks (y/n) whether to prepend
`justly-CLAUDE.md` into your global `~/.claude/CLAUDE.md` — the memory file Claude Code
loads in every session, across all projects (created if you don't have one). It's
written as a marked block, so re-running updates that block in place and leaves the rest
of your CLAUDE.md untouched. `--yes` accepts this prompt too.

## Deploy (manual)

- Agents → `~/.claude/agents/` or `<package>/.claude/agents/`
- Command → `~/.claude/commands/` or `<package>/.claude/commands/`
- Script → `<repo-root>/scripts/new-worktree.sh`, then wire `package.json`:

  ```json
  "scripts": { "worktree": "bash scripts/new-worktree.sh" }
  ```

## new-worktree.sh

Generic. `pnpm worktree <slug> [--open]` forks branch `<slug>` from `main` into
`<repo-root>.worktrees/<slug>`, then copies the gitignored artifacts a fresh worktree needs:

- all nested `.env` / `*.env` files (excludes `node_modules`)
- all nested `node_modules`, `dist`, `build`, `.svelte-kit`

Anything that doesn't exist is skipped. Run `pnpm install` in the worktree afterward to resync.
