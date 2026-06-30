# justly-skilled

Minimalistic agentic code implementation loop skill.
- User provides your request
- LLM Sets up worktree
- LLM asks you to clarify the genuine open ends
- LLM Writes spec file
- Subagent Solution Architect review loop, runs with new context, loops until spec APPROVED (max 3x)
- LLM Writes summary of all decisions (AI + User made)
- LLM Asks user for confirmation / Changes
- LLM Implements code
- Subagent Code review loop, runs with new context, loops until code APPROVED (max 3x)

## Installation

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
