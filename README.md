# justly-skilled

Source of truth for the `justly-*` Claude Code skill bundle. Edit here, then copy out to
`~/.claude` (global) or any package's `.claude`.

## Layout

```
agents/
  justly-reviewer.md             # reviews code against the spec after implementation
  justly-solutions-architect.md  # validates the spec (the design) before implementation
commands/
  justly-implement.md            # /justly-implement — full spec→validate→build→review→PR flow
scripts/
  new-worktree.sh                # bootstraps an isolated worktree (used by `pnpm worktree`)
```

The flow: `/justly-implement` writes a spec, loops it past `justly-solutions-architect`
until the design is approved, implements, then loops the code past `justly-reviewer` until
approved, then opens a PR. Each subagent's `.md` is its system prompt (full rubric + verdict
format) — the command passes only runtime args, never restates the rubric.

## Deploy

- Agents → `~/.claude/agents/` or `<package>/.claude/agents/`
- Command → `~/.claude/commands/` or `<package>/.claude/commands/`
- Script → `<repo-root>/scripts/new-worktree.sh`, then wire `package.json`:

  ```json
  "scripts": { "worktree": "bash scripts/new-worktree.sh" }
  ```

Subagents are referenced by `subagent_type` matching the agent's `name:` frontmatter — keep
filename and `name:` in sync when renaming.

## Flavor

These copies are pnpm-flavored: the command uses `pnpm worktree` + `pnpm check`, the reviewer
runs `pnpm check`. GraphQL codegen was removed — re-add a `graphql:build` step per package if
that package needs it. For a non-pnpm repo, swap those commands for that repo's equivalents.

## new-worktree.sh

Generic. `pnpm worktree <slug> [--open]` forks branch `<slug>` from `main` into
`<repo-root>.worktrees/<slug>`, then copies the gitignored artifacts a fresh worktree needs:

- all nested `.env` / `*.env` files (excludes `node_modules`)
- all nested `node_modules`, `dist`, `build`, `.svelte-kit`

Anything that doesn't exist is skipped — nothing is hard-coded, so it drops onto any repo.
It copies `node_modules` rather than reinstalling; if the worktree's deps drift from `main`,
run `pnpm install` in the worktree afterward to resync.
