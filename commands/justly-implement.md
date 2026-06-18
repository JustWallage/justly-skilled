---
description: Resolve essential questions, write a spec, then implement it in an isolated worktree with a bounded independent review loop, and open a PR
---

You are the implementor, running as the main thread. You resolve the genuinely-open questions, write a spec, get the spec validated to convergence by the `justly-solutions-architect` subagent, implement it in an isolated git worktree, get the code reviewed to convergence by the `justly-reviewer` subagent, and open a PR. You hold full tool access — dispatch the subagents yourself.

When you dispatch a subagent, its own definition file is loaded as its system prompt — it already holds its full rubric and output format. Your dispatch prompt must carry **only runtime args** (paths, branch/commit notes) and genuinely **task-specific** call-outs. Never restate the subagent's rubric or its verdict-line format — that lives in its system prompt and restating it only invites drift.

Input: $ARGUMENTS

The input is either a path to an existing spec document, or a written request (e.g. a ticket) describing what to build. If no input was given, ask for the request first.

## 1. Create the worktree (always, before any code or spec work)

Derive a kebab-slug from the request (short, descriptive, e.g. `tint-order-bulk-delete`). Create the worktree:

```
pnpm worktree <slug>
```

This forks a branch `<slug>` from `main` at `<repo-root>.worktrees/<slug>` and prints `Worktree ready: <path>`. Capture that absolute path — call it `$WT`. **All subsequent work — spec, code, commits, git commands — happens in `$WT`, on branch `<slug>`.** Use absolute paths under `$WT`, or run git as `git -C "$WT" …`.

❗️ You may **never** commit to `main`. Every commit and push is on branch `<slug>`, from `$WT` only.

## 2. Resolve the spec

- **If the input is a path to an existing spec file** → that is the spec. Copy/ensure it exists under `$WT`. Skip to step 7 (implement).
- **If the input is a written request** → resolve open questions (step 3), then write the spec (step 4).

## 3. Question gate — essential only

First explore the codebase (from `$WT`) and resolve everything you can yourself. Then ask the user — in **one** round via `AskUserQuestion`, each with a recommended answer — only about decisions that are **genuinely ambiguous and materially change the implementation**: conflicting readings of the ticket, missing acceptance criteria, scope boundaries, user-facing behavior choices, data-model/contract decisions with no single right answer.

Do **not** ask about:

- Naming, file placement, formatting, test layout.
- Anything a documented best practice already settles — pick the best-practice solution and move on.
- Anything resolvable by reading the codebase — read it instead.
- Anything with one clearly-correct answer.

If nothing is genuinely open, skip the questions entirely.

## 4. Write the spec

Write the spec to `$WT/docs/specs/<slug>/index.md`. Capture the original request verbatim, plus the requirements/behavior (including tests for new logic, unit/integration/e2e) — and **fold in every resolved decision** (both the ones the user made and the ones you made). Both subagents read only the spec and (for the reviewer) the diff, never this chat — so any decision not written into the spec is invisible to them. The spec must stand alone.

Do **not** post the decisions summary, ask for confirmation, or commit yet — the spec must pass architecture validation (step 5) first.

## 5. Architecture validation loop — before the user confirms

The spec must be validated as the *right solution* before the user is asked to confirm it. Validation docs are numbered: `$WT/docs/specs/<slug>/sa-validation-1.md`, `sa-validation-2.md`, … Loop, max **3** cycles:

1. Dispatch the `justly-solutions-architect` subagent via the Task tool (`subagent_type: justly-solutions-architect`). Pass runtime args only: the spec path, the validation-doc output path for this cycle (`sa-validation-N.md`), the worktree path `$WT` (instruct it to run all read/git commands from `$WT`), and any task-specific notes. It validates in a fresh isolated context against the spec + codebase.
2. Read the validation doc. Its last line is `VERDICT: APPROVED` or `VERDICT: CHANGES_REQUESTED`.
   1. If `APPROVED` → exit loop, go to step 6.
   2. If `CHANGES_REQUESTED` → resolve it:
      - For **open questions** the SA raised that genuinely need the user, batch them into **one** `AskUserQuestion` round (each with a recommended answer).
      - Revise the spec per the action list and the user's answers, folding every new decision into the spec.
      - Dispatch a **fresh** justly-solutions-architect for cycle N+1.
3. If you reach 3 cycles without `APPROVED` → stop looping. Summarize the outstanding architecture concerns to the user and let them decide whether to proceed, revise, or abort. Do not loop further.

Keep the SA honest about simplicity — it is chartered to flag over-engineering, not to request gold-plating. If it pushes complexity the spec's scope doesn't warrant, push back rather than inflating the spec.

## 6. Confirm + commit the spec

Once validation is `APPROVED` (or the user chose to proceed after the cap), post in the chat a **short but complete decisions summary** — one scannable bullet per decision that shaped the spec, each tagged `[user]` or `[AI]`:

```
Spec: docs/specs/<slug>/index.md  (branch <slug>)
Decisions:
- [user] <decision>
- [AI] <decision the user didn't have to make>
...
```

This lets the user review fast. Ask the user to confirm before you commit the spec and start implementation.

Commit the spec on branch `<slug>`.

## 7. Implement

Implement the feature per the spec, working in `$WT`:

- Simplest correct solution. Short and readable beats verbose or clever.
- No shortcuts, no hacky workarounds. This is an enterprise codebase.
- Match the surrounding code: naming, idioms, structure, comment density.
- Barely add comments — only inline when crucial for understanding.
- Implement the spec faithfully: every requirement covered, nothing extra invented.
- **Commit + push at logical checkpoints** (coherent units of work), always on branch `<slug>` from `$WT`. Never on `main`.

## 8. Verify

- Run `pnpm -F <packagename> run check` for each package you touched.
- Then run the root `pnpm check` to validate the complete project across all packages.
- Fix anything that fails before moving on. Do not proceed to review until checks pass.

## 9. Bounded review loop

Review docs are numbered: `$WT/docs/specs/<slug>/review-1.md`, `review-2.md`, … Loop, max **3** cycles:

1. Dispatch the `justly-reviewer` subagent via the Task tool (`subagent_type: justly-reviewer`). Pass runtime args only: the spec path, the review-doc output path for this cycle (`review-N.md`), the worktree path `$WT` (instruct it to run all git/read commands from `$WT` so `git diff main` sees the branch changes), and any task-specific call-outs. It reviews in a fresh isolated context against the diff — it never sees your reasoning.
2. Read the review doc. Its last line is `VERDICT: APPROVED` or `VERDICT: CHANGES_REQUESTED`.
   1. If `APPROVED` → exit loop.
   2. If `CHANGES_REQUESTED` → apply the feedback as code changes, re-verify (step 8), commit + push, then dispatch a **fresh** justly-reviewer for cycle N+1.
3. If you reach 3 cycles without `APPROVED` → stop looping. Report the outstanding findings to the user; do not loop further.

## 10. Open the PR

Once approved, **first commit + push the review and validation docs** so they land on the branch and are visible in the PR — these are easy to forget because they are not source code:

```
git -C "$WT" add docs/specs/<slug>
git -C "$WT" commit -m "docs: spec review for <slug>"
git -C "$WT" push
```

(If there is nothing to commit because they were already committed, that is fine — just confirm `git -C "$WT" status` is clean and the docs are pushed.)

Then ensure all code is committed and pushed on branch `<slug>`, and open a PR with `gh pr create` (base `main`, head `<slug>`). In the pr body include the final **short but complete decisions summary**. Do not run `gh pr create` until the review docs are confirmed pushed.

## 11. Report

Report: the worktree path and branch, the spec path, the decisions summary, how many architecture-validation cycles ran and the final verdict, what you implemented, how many review cycles ran and the final verdict (or outstanding findings if capped), and the PR URL.
