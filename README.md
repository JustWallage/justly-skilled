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
  install-micro.sh               # curl|bash installer — lean *-micro variants (default)
  install.sh                     # curl|bash installer — full variants
  new-worktree.sh                # bootstraps an isolated worktree (used by `pnpm worktree`)
```

The flow: `/justly-implement` writes a spec, loops it past `justly-solutions-architect`
until the design is approved, implements, then loops the code past `justly-reviewer` until
approved, then opens a PR. Each subagent's `.md` is its system prompt (full rubric + verdict
format) — the command passes only runtime args, never restates the rubric.

## Install (agents + commands)

No clone needed — downloads the repo tarball and copies the `.md` files in. Default
installs the lean `*-micro` variants:

```bash
curl -fsSL https://raw.githubusercontent.com/JustWallage/justly-skilled/main/scripts/install-micro.sh | bash
```

Full (verbose) variants instead:

```bash
curl -fsSL https://raw.githubusercontent.com/JustWallage/justly-skilled/main/scripts/install.sh | bash
```

Both prompt for global (`~/.claude`) vs local (current project's `.claude`). Flags skip
the prompts:

```bash
... | bash -s -- --global         # ~/.claude
... | bash -s -- --local [DIR]     # DIR/.claude (default: cwd)
... | bash -s -- --global --yes    # also overwrite differing files without asking
```

**Re-run to update.** It compares your installed files to the latest: if they already
match it says so and does nothing; if they differ it lists them and asks before
overwriting (`--yes` to skip the prompt).

Copies, not symlinks — a committed copy travels correctly on clone, but a committed
symlink stores an absolute path and dangles on teammates' machines.

## Deploy (manual)

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
