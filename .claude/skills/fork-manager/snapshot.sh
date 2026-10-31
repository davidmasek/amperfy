#!/bin/bash
# Read-only snapshot of the fork's state for the fork-manager skill.
# Usage: .claude/skills/fork-manager/snapshot.sh   (from any worktree of the repo)
# Fetches origin and upstream; changes nothing else.
set -u
FORK=davidmasek/amperfy
UPSTREAM=BLeeEZ/amperfy
MIRROR=upstream-master # fork branch kept equal to upstream/master
ME=$(gh api user --jq .login)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git fetch --quiet --prune origin
git fetch --quiet upstream

gh pr list --repo "$FORK" --state all --limit 200 \
  --json number,headRefName,baseRefName,state,isDraft,labels,title,updatedAt,body >"$tmp/fork_prs.json"
gh pr list --repo "$UPSTREAM" --author "$ME" --state all --limit 100 \
  --json number,headRefName,state,isDraft,title,updatedAt,closedAt,reviewDecision >"$tmp/up_prs.json"
gh issue list --repo "$FORK" --state open --limit 200 \
  --json number,title,labels,updatedAt,body,closedByPullRequestsReferences >"$tmp/fork_issues.json"

# "#5 open/draft status: wip" for each fork PR whose head is branch $1, newest first.
fork_prs_for() {
  jq -r --arg b "$1" '[.[] | select(.headRefName == $b)] | sort_by(-.number)
    | map("#\(.number) \(.state | ascii_downcase)\(if .isDraft then "/draft" else "" end)"
        + (if .baseRefName != "master" then " →" + .baseRefName else "" end)
        + (if .state == "OPEN" then " " + ([.labels[].name | select(startswith("status:"))] | join(",") | if . == "" then "NO STATUS" else . end) else "" end))
    | join("; ")' "$tmp/fork_prs.json"
}
up_prs_for() {
  jq -r --arg b "$1" '[.[] | select(.headRefName == $b)] | sort_by(-.number)
    | map("#\(.number) \(.state | ascii_downcase)") | join("; ")' "$tmp/up_prs.json"
}

echo "# Fork snapshot $(date '+%Y-%m-%d %H:%M')"

echo
echo "## Last run"
log=$(gh issue list --repo "$FORK" --label fork-manager-log --state open --json number --jq '.[0].number // empty')
if [ -z "$log" ]; then
  echo "NO LOG ISSUE (label fork-manager-log)"
else
  last=$(gh issue view "$log" --repo "$FORK" --json comments --jq '.comments | last | .createdAt // empty')
  echo "log issue #$log, last run: ${last:-none}"
fi

echo
echo "## origin/master vs upstream/master"
read -r behind ahead < <(git rev-list --left-right --count upstream/master...origin/master)
read -r ob oa < <(git rev-list --left-right --count origin/master...master)
echo "origin/master: $behind behind, $ahead ahead upstream/master"
echo "local master: $ob behind, $oa ahead origin/master"
if git show-ref --quiet "refs/remotes/origin/$MIRROR"; then
  read -r mb ma < <(git rev-list --left-right --count "upstream/master...origin/$MIRROR")
  if [ "$mb$ma" = 00 ]; then echo "origin/$MIRROR: in sync with upstream/master"
  elif [ "$ma" = 0 ]; then echo "origin/$MIRROR: $mb behind upstream/master (fast-forward possible)"
  else echo "origin/$MIRROR: DIVERGED ($ma commits not in upstream/master)"; fi
else
  echo "origin/$MIRROR: MISSING"
fi
echo "Upstream commits not in origin/master (max 20):"
git log --oneline --no-merges -20 origin/master..upstream/master | sed 's/^/  /'
echo "Fork-only commits on origin/master touching more than CLAUDE.md:"
git log --oneline --no-merges upstream/master..origin/master -- . ':!CLAUDE.md' | sed 's/^/  /'
git diff --name-only upstream/master...origin/master | sort >"$tmp/fork_files"
git diff --name-only origin/master...upstream/master | sort >"$tmp/up_files"
echo "Files changed on both sides since the fork point (merge conflict risk):"
comm -12 "$tmp/fork_files" "$tmp/up_files" | sed 's/^/  /'

echo
echo "## Local branches"
echo "branch | last commit | on origin | origin/master behind/ahead | fork PR | upstream PR | worktree"
git for-each-ref --sort=-committerdate refs/heads --format='%(refname:short)|%(committerdate:relative)' |
  while IFS='|' read -r br date; do
    [ "$br" = master ] && continue
    if ! git show-ref --quiet "refs/remotes/origin/$br"; then
      origin="NOT ON ORIGIN"
    else
      read -r rb ra < <(git rev-list --left-right --count "origin/$br...$br")
      if [ "$ra$rb" = 00 ]; then origin="in sync"; else origin="$ra unpushed, $rb behind"; fi
    fi
    read -r mb ma < <(git rev-list --left-right --count "origin/master...$br")
    fpr=$(fork_prs_for "$br")
    upr=$(up_prs_for "$br")
    wt=$(git worktree list --porcelain | awk -v b="branch refs/heads/$br" '/^worktree /{w=$2} $0==b{print w}')
    echo "$br | $date | $origin | $mb/$ma | ${fpr:-NO PR} | ${upr:--} | ${wt:--}"
  done

echo
echo "## Open fork PRs"
jq -r 'map(select(.state == "OPEN")) | sort_by(-.number)[]
  | "#\(.number)\(if .isDraft then " draft" else "" end) [\([.labels[].name | select(startswith("status:"))] | join(",") | if . == "" then "NO STATUS" else . end)] \(.headRefName) → \(.baseRefName) — \(.title) (updated \(.updatedAt[:10]))"' \
  "$tmp/fork_prs.json"

echo
echo "## origin branches whose fork PR is closed or merged (delete candidates)"
jq -r 'map(select(.state != "OPEN"))[] | "\(.headRefName)|#\(.number) \(.state | ascii_downcase)"' "$tmp/fork_prs.json" |
  while IFS='|' read -r br pr; do
    git show-ref --quiet "refs/remotes/origin/$br" && ! jq -e --arg b "$br" 'any(.[]; .headRefName == $b and .state == "OPEN")' "$tmp/fork_prs.json" >/dev/null &&
      echo "  $br ($pr)"
  done

echo
echo "## origin branches with no local branch and no fork PR"
for r in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin); do
  b=${r#origin/}
  case "$b" in origin | HEAD | master | "$MIRROR") continue ;; esac
  git show-ref --quiet "refs/heads/$b" && continue
  [ -n "$(fork_prs_for "$b")" ] && continue
  printf '%s ' "$b"
done
echo

echo
echo "## Worktrees"
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r w; do
  n=$(git -C "$w" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "  $w ($(git -C "$w" branch --show-current 2>/dev/null)) dirty files: $n"
done

echo
echo "## Open fork issues"
jq -r 'map(select(any(.labels[]; .name == "fork-manager-log") | not)) | sort_by(-.number)[]
  | "#\(.number) [\([.labels[].name] | join(","))] \(.title) (updated \(.updatedAt[:10]))\(if (.closedByPullRequestsReferences | length) > 0 then " — linked PR " + ([.closedByPullRequestsReferences[] | "#\(.number)"] | join(",")) else "" end)"' \
  "$tmp/fork_issues.json"

echo
echo "## My upstream PRs"
echo "Open:"
jq -r 'map(select(.state == "OPEN"))[] | "  #\(.number)\(if .isDraft then " draft" else "" end) \(.headRefName) — \(.title) (updated \(.updatedAt[:10]), review: \(.reviewDecision // "none"))"' "$tmp/up_prs.json"
for n in $(jq -r 'map(select(.state == "OPEN"))[].number' "$tmp/up_prs.json"); do
  gh pr view "$n" --repo "$UPSTREAM" --json comments,reviews \
    --jq '[(.comments[] | {a: .author.login, t: .createdAt, b: .body}), (.reviews[] | {a: .author.login, t: .submittedAt, b: .body})]
      | sort_by(.t) | last // empty | "    #'"$n"' last comment: \(.a) \(.t[:10]): \(.b[:200] | gsub("\n"; " "))"'
done
since=$(date -v-60d +%Y-%m-%d 2>/dev/null || date -d '60 days ago' +%Y-%m-%d)
echo "Closed or merged since $since:"
jq -r --arg s "$since" 'map(select(.state != "OPEN" and (.closedAt // "")[:10] >= $s))[] | "  #\(.number) \(.state | ascii_downcase) \(.headRefName) — \(.title)"' "$tmp/up_prs.json"

echo
echo "## My open upstream issues"
gh issue list --repo "$UPSTREAM" --author "$ME" --state open --limit 50 \
  --json number,title,updatedAt,comments \
  --jq '.[] | "  #\(.number) \(.title) (\(.comments | length) comments, updated \(.updatedAt[:10]))"'

echo
echo "## Upstream items referenced from open fork PRs and issues"
echo "(forms: upstream#N, $UPSTREAM#N, or a github.com/$UPSTREAM/... URL)"
jq -r '.[] | select(.state == "OPEN" or .state == null) | .body // ""' "$tmp/fork_prs.json" "$tmp/fork_issues.json" |
  grep -oE "(upstream#|$UPSTREAM#|$UPSTREAM/pull/|$UPSTREAM/issues/)[0-9]+" | grep -oE '[0-9]+$' | sort -un |
  while read -r n; do
    gh api "repos/$UPSTREAM/issues/$n" \
      --jq '"  #\(.number) \(if .pull_request then "PR" else "issue" end) \(.state)\(if .pull_request.merged_at then "/merged" else "" end) — \(.title)"'
  done
