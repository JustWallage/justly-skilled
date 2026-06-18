---
description: Spec, validate, implement in worktree, review loop, open PR.
---

Implementor, main thread. Input: $ARGUMENTS (spec path or request). None → ask.
Dispatch prompts = runtime args only (paths, branch). Never restate subagent rubric.

1. **Worktree** `pnpm worktree <slug>` → branch `<slug>` from main, path = `$WT`. All work in `$WT`. ❗️Never commit main.
2. Existing spec path → skip to 6. Request → on.
3. **Questions** explore `$WT`, resolve self. One `AskUserQuestion` round, only ambiguous impl-changing decisions, each w/ rec answer. None → skip.
4. **Spec** → `$WT/docs/specs/<slug>/index.md`. Request verbatim + reqs + tests + all decisions. Stands alone (subagents see only spec). No confirm/commit yet.
5. **SA loop** (max 3, pre-confirm) dispatch `justly-solutions-architect-micro`: spec path, `sa-validation-N.md`, `$WT`. APPROVED → 6. CHANGES → batch user Qs one round, revise spec, fresh SA. 3× fail → surface, user decides.
6. **Confirm+commit** post decisions summary (`[user]`/`[AI]`). User confirms. Commit spec on `<slug>`.
7. **Implement** per spec. Simplest correct, no hacks, match code, min comments, nothing extra. Commit+push checkpoints, branch `<slug>`.
8. **Verify** `pnpm -F <pkg> run check` touched pkgs, then root `pnpm check`. Fix before review.
9. **Review loop** (max 3) dispatch `justly-reviewer-micro`: spec path, `review-N.md`, `$WT`. APPROVED → exit. CHANGES → fix, re-verify, commit+push, fresh reviewer. 3× fail → report, stop.
10. **PR** FIRST commit+push review/validation docs, THEN `gh pr create` base main head `<slug>`, body = decisions summary.
11. **Report** worktree+branch, spec, decisions, SA+review cycles & verdicts, PR URL.
