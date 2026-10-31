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
- All state lives in the fork itself: branches, PRs, labels, issues. Keep no files
  between runs. A decision that changes nothing yet (e.g. "keep this branch for now")
  goes on the branch's PR as `status: parked` plus a line in its description.
- CLAUDE.md's hard rules apply: nothing upstream without per-item approval, no AI
  attribution anywhere.
- Never edit files in, or remove, a worktree that is in use (snapshot: `in use: yes`, a
  process's working directory is inside it). Report it instead.

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
   - fast-forward the mirror:
     `git push origin upstream/master:refs/heads/upstream-master` (refused if diverged:
     report that instead)
2. **After the user approves the item in this run.** Approval from earlier runs does not
   carry over.
   - set `status:` labels and edit descriptions on fork PRs
   - close fork PRs and fork issues
   - delete a branch, local and on origin. First check: no unpushed commits, not checked
     out in any worktree.
   - remove a finished worktree, then delete its branch. Only when the snapshot shows
     `dirty files: 0, in use: no, merged: yes`. Right before removing, re-check that
     `lsof -a -d cwd -Fn | grep -F <path>` prints nothing, then run
     `git worktree remove <path>`, `git branch -d <branch>` (`-D` if its fork PR was
     closed unmerged), `git push origin --delete <branch>`.
   - open a fork PR for a branch that has none
   - merge a fork PR into `master`: `gh pr merge <n> -R davidmasek/amperfy --merge`.
     Never squash: upstream-bound branches are cherry-picked from these commits.
   - drop a stash entry (stashes are shared by all worktrees and sessions): right before
     dropping, look up its current index with `git stash list --format='%gd %H %gs'`,
     then `git stash drop 'stash@{<n>}'` and check the SHA it prints. `drop <sha>` fails
     with "is not a stash reference".
   - start a worker (see Workers)
   - change CLAUDE.md, this skill or other agent setup: on a branch, as a fork PR
3. **Never, even if approved in passing:** push directly to `master` (it changes only by
   merging a fork PR), force-push, or anything on `BLeeEZ/amperfy` without CLAUDE.md's explicit per-PR approval.

After acting, report what you did. The user approves the result; follow-ups become
issues or wait for the next run.

## Procedure

1. Run `.claude/skills/fork-manager/snapshot.sh` and read its output.
2. For an open upstream PR or issue whose last comment is by someone else, read the
   thread: `gh pr view <n> --repo BLeeEZ/amperfy --comments` (or `gh issue view`). A
   thread whose last comment is the user's needs nothing.
3. Fast-forward the mirror if the snapshot says it is behind.
4. Write the overview (format below) and stop. Don't ask for approvals yet.
5. The user picks items. For a picked item, show its details and ask about its actions
   only: one `AskUserQuestion`, multiSelect, one option per action. A Routine item can be
   approved as a whole straight from the overview.
6. Do the approved ones and report each outcome. Record decisions that change nothing
   yet on the PR concerned (see Stance).

`gh` in this checkout may default to `BLeeEZ/amperfy`: pass `-R davidmasek/amperfy` to
every fork `gh` call, written out (zsh doesn't word-split `$R`).

## Overview format

At most about 6 numbered items, grouped. Each item must make sense to someone who has
forgotten the details: say what the thing is in plain words ("cache bitrate cap", not
"#12 vs sample-rate"), then the recommendation in one clause.

```
## Fork status <date>
**Needs your review** (decisions, or things worth looking at)
1. <what it is>: <recommended action>, because <reason>

**Routine** (done on a yes, nothing is lost)
2. <one kind of action>: <count and what it covers>

**Later**
3. <item>: <when, and why not now>
```

- **Needs your review**: choices, and actions whose result the user should look at
  (e.g. a new fork PR they'll read before anything goes upstream).
- **Routine**: actions needing no thought. Labels that follow from the facts, closing
  finished PRs, deleting branches whose work is merged or identical elsewhere, removing
  finished worktrees (`in use: no, merged: yes`, no dirty files), removing `ai-reported` from an issue a PR reproduced. Group by kind of action (one item for all
  PR and issue labels, one for all deletions), not by where the fact came from.
- **Later**: recommended, but not now, e.g. an upstream sync while several branches are
  in flight.
- Leave out what needs nothing: upstream threads the user answered last, branches under
  a day old in an active worktree.
- If the user has said something isn't a priority, propose `status: parked` with their
  reason, as Routine, instead of asking them to decide it.

Details for a picked item: the facts behind it (branches, PRs, commits, files), what
each action does, and what was checked ("no unpushed commits", "patch-identical to
master").

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
