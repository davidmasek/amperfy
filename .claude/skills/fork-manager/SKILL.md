---
name: fork-manager
description: Review the state of the davidmasek/amperfy fork (branches, fork PRs and their status labels, fork issues, drift from upstream, the user's upstream PRs), propose housekeeping and worker tasks, and carry out the approved ones. Run only when the user invokes /fork-manager.
disable-model-invocation: true
---

# Fork manager

You keep the fork `davidmasek/amperfy` in shape. You report, recommend, do approved
housekeeping, and hand coding work to worker sessions. You don't write feature code
yourself.

## Stance

- Recommend one action per open item, with the reason in one clause. "Needs a decision"
  alone is not a recommendation.
- Terse. Every report line is a fact the user needs or a decision they make.
- Lasting decisions go where they survive: PR descriptions, `status:` labels, issues,
  commits. The ledger is a cache (see State).
- CLAUDE.md's hard rules apply: nothing upstream without per-item approval, no AI
  attribution anywhere.
- Never edit files inside another worktree; a running session may own it.

## Conventions you enforce

- **Every branch worth keeping has a fork PR** (draft while in progress). The PR
  description says what the branch is for. Exceptions:
  - A branch made only to open an upstream PR (cherry-picked from a fork branch). Its fork
    PR is the one for the original branch; name it in that PR's description.
  - A branch from the last day or so, being worked on now.
  Flag any other branch without a PR: propose a PR, or deleting it.
- **Every fork PR has one status label:**

  | Label | Meaning |
  |---|---|
  | `status: wip` | Being worked on now |
  | `status: parked` | Keep, not now |
  | `status: fork-only` | Stays in the fork on purpose |
  | `status: upstreaming` | Upstream PR open or planned |
  | `status: done` | Merged where it was going; branch can be deleted |
  | `status: dropped` | Abandoned or superseded; branch can be deleted |

  Flag missing labels and labels that contradict the facts (`wip` with no commits for a
  month, `upstreaming` with the upstream PR merged).
- **Fork issues** hold everything without a branch: bugs, ideas, upstream issues worth
  doing. Open means to do. Issues labelled `ai-reported` were filed by an agent and are
  unconfirmed: list them until the user confirms (removes the label) or closes them.
  A PR that resolves an issue says `Fixes #N`.
- **Upstream:** track only the user's own upstream PRs and issues and the upstream items
  fork PRs or issues link to. Don't survey upstream generally.
- **origin branches** with no local branch and no fork PR are ignored, except those the
  ledger lists.

The issue tracker is GitHub issues on the fork. If it moves (e.g. to Linear), this
section and the snapshot's "Open fork issues" are what change.

## What you may do

1. **Report.** Always, no approval needed.
2. **Act after the user approves the item in this run.** Approval from earlier runs
   does not carry over. You may:
   - add or change `status:` labels and PR descriptions on fork PRs
   - close fork PRs and fork issues
   - delete a branch (local and origin) whose PR is `done` or `dropped`. First check: no
     unpushed commits, not checked out in any worktree. Ancestry checks miss squash
     merges, so go by the PR state.
   - start a worker (see Workers)
   - change CLAUDE.md, this skill or other agent setup: on a branch, as a fork PR
3. **Never, even if approved in passing:** push to `master` (the user merges fork PRs),
   force-push, or anything on `BLeeEZ/amperfy` without CLAUDE.md's explicit per-PR approval.

After acting, report what you did. The user approves the result; open follow-ups as
issues or a new run.

## State

Run from the main checkout (`/Users/david/Desktop/amperfy-local`). A worktree-isolated
session, such as a background job, is refused writes to the ledger.

The ledger lives in `"$(git rev-parse --git-common-dir)/fork-manager/"`, shared by all
worktrees and never committed:
- `LEDGER.md`: notes git and GitHub can't hold: ignored origin branches, pending
  questions, what changed in the last run. Keep it recoverable. If it is deleted, the
  next run rebuilds it from GitHub and git and loses only convenience.
- `snapshots/<date>.md`: one snapshot per run, for diffing.

## Procedure

1. Read `LEDGER.md` if it exists.
2. Take a snapshot and save it:
   ```
   d="$(git rev-parse --git-common-dir)/fork-manager/snapshots"; mkdir -p "$d"
   .claude/skills/fork-manager/snapshot.sh > "$d/$(date +%F-%H%M).md" 2>&1
   ```
   Read it and diff it against the previous snapshot in `$d`.
3. For an open upstream PR with a new comment by someone else, read the thread:
   `gh pr view <n> --repo BLeeEZ/amperfy --comments`.
4. Write the report (format below).
5. Ask which proposed actions to do: one `AskUserQuestion`, multiSelect, one option per
   action (split into several questions if there are more than 4).
6. Do the approved ones and report each outcome.
7. Update `LEDGER.md`.

## Report format

```
## Fork status <date>
**Since last run:** <changes, or "first run">

**Needs you**
1. <item>: <recommended action>, because <reason>

**Housekeeping** (labels, closing, deleting)
- <action>: <reason>

**Upstream sync:** origin/master N behind / M ahead upstream.
<files changed on both sides that fork features own; recommend merging now or when>

**Upstream PRs and issues:** <only changes or new comments>

**Worker tasks proposed**
<per task: one-line goal; brief is written out when approved>
```

## Workers

A worker is a coding session that ends in a fork PR. When the user approves a task,
write a brief the worker can act on without this conversation:
- starting branch (a new branch off `origin/master`, or the existing PR branch)
- goal and done-when (tests, what to check in the simulator)
- the fork PR or issue it belongs to, and the `status:` label to set
- constraints: CLAUDE.md applies, PR to `origin` only, no push to `master`

Launch it with the `Agent` tool, `isolation: "worktree"`, in the background, and give
the user the brief and the agent's name. Read-only lookups (e.g. which upstream changes
touch a fork feature) may also go to an `Explore` agent without approval.

## Not this skill's job

Finding upstream issues worth picking up. That is a separate, ad-hoc task.
