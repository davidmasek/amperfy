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
- All state lives on GitHub: PRs, labels, issues, the log issue. Keep no local files
  between runs.
- CLAUDE.md's hard rules apply: nothing upstream without per-item approval, no AI
  attribution anywhere.
- Never edit files in, or remove, another session's worktree. Report it instead.

## Conventions you enforce

- **Every branch has a fork PR.** Its description says what the branch is for. Draft
  while in progress. Kinds of branches:
  - Feature or fix: PR into `master`.
  - Benchmark or experiment: draft PR into `master`, never merged; closed when done.
  - Upstream-bound (cherry-picked onto `upstream/master`): PR into `upstream-master`, the
    fork's mirror of `upstream/master`. Its diff is exactly what the upstream PR would be.
    Never merge these; the description links the fork PR of the original branch.
  - Only exception: a branch being worked on right now that is less than a day old.
  Flag any other branch without a PR: propose a PR or deleting the branch.
- **Every open fork PR has exactly one `status:` label.** Closed and merged PRs need
  none; their branches get deleted.

  | Label | Meaning |
  |---|---|
  | `status: wip` | Being worked on now |
  | `status: parked` | Keep, not now |
  | `status: fork-only` | Stays in the fork on purpose |
  | `status: upstreaming` | Upstream PR open or planned |
  | `status: done` | Merged where it was going; close the PR |
  | `status: dropped` | Abandoned or superseded; close the PR |

  Flag missing labels and labels that contradict the facts (`wip` with no commits for a
  month, `upstreaming` with the upstream PR merged). Other labels can be added freely
  when a need shows up; `status:` labels on issues are fine too (e.g. `parked`).
- **Fork issues** hold work without a branch: bugs, ideas, upstream issues worth doing.
  Issues labelled `ai-reported` were filed by an agent and are unconfirmed: list them
  until the user confirms (removes the label) or closes them. A PR that resolves an
  issue says `Fixes #N`.
- **Referring to upstream items:** write `` `upstream#564` `` (in backticks). GitHub
  doesn't link code spans, so upstream gets no "mentioned" notice, and the snapshot
  still tracks the item. A plain link is fine where notifying upstream is intended.
- **Upstream:** track only the user's own upstream PRs and issues and the upstream items
  fork PRs or issues refer to. Don't survey upstream generally.
- **Deleting branches** loses nothing that matters: a closed PR keeps its history and
  has a "Restore branch" button. The repo deletes a PR's branch on `origin` when it
  merges; local branches and branches of closed-unmerged PRs are yours to clean up.

The issue tracker is GitHub issues on the fork. If it moves (e.g. to Linear), this
section and the snapshot's "Open fork issues" are what change.

## What you may do

1. **Without approval:**
   - report
   - comment on the log issue (see Procedure)
   - fast-forward the mirror:
     `git push origin upstream/master:refs/heads/upstream-master` (refused if diverged:
     report that instead)
2. **After the user approves the item in this run.** Approval from earlier runs does not
   carry over.
   - set `status:` labels and edit descriptions on fork PRs
   - close fork PRs and fork issues
   - delete a branch, local and on origin. First check: no unpushed commits, not checked
     out in any worktree.
   - open a fork PR for a branch that has none
   - start a worker (see Workers)
   - change CLAUDE.md, this skill or other agent setup: on a branch, as a fork PR
3. **Never, even if approved in passing:** push to `master` (the user merges fork PRs),
   force-push, or anything on `BLeeEZ/amperfy` without CLAUDE.md's explicit per-PR approval.

After acting, report what you did. The user approves the result; follow-ups become
issues or wait for the next run.

## Procedure

1. Run `.claude/skills/fork-manager/snapshot.sh` and read its output. "Last run" gives
   the date of the previous run; compare it with each item's updated date for "since
   last run".
2. Read the log issue's last comment for pending questions and earlier decisions.
3. For an open upstream PR with a new comment by someone else, read the thread:
   `gh pr view <n> --repo BLeeEZ/amperfy --comments`.
4. Fast-forward the mirror if the snapshot says it is behind.
5. Write the report (format below).
6. Ask which proposed actions to do: one `AskUserQuestion`, multiSelect, one option per
   action (split into several questions if there are more than 4).
7. Do the approved ones and report each outcome.
8. Comment on the log issue: date, what changed, what the user decided, what you did,
   open questions. No server URLs, usernames or anything from `.env.local`; the fork is
   public.

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
