#!/bin/bash
# Read-only snapshot of the fork's state for the fork-manager skill.
# Usage: .claude/skills/fork-manager/snapshot.sh   (from any worktree of the repo)
# Fetches origin and upstream; changes nothing else.
set -u
FORK=davidmasek/amperfy
UPSTREAM=BLeeEZ/amperfy
ME=$(gh api user --jq .login 2>/dev/null || echo davidmasek)

git fetch --quiet --prune origin
git fetch --quiet upstream

echo "# Fork snapshot $(date '+%Y-%m-%d %H:%M')"
echo
echo "## master vs upstream/master"
read -r behind ahead < <(git rev-list --left-right --count upstream/master...master)
echo "local master: $behind behind, $ahead ahead upstream/master"
read -r b2 a2 < <(git rev-list --left-right --count origin/master...master)
echo "local master vs origin/master: $b2 behind, $a2 ahead"
echo "Upstream commits not in master (newest first, max 15):"
git log --oneline --no-merges -15 master..upstream/master | sed 's/^/  /'
echo "Fork-only commits on master:"
git log --oneline --no-merges upstream/master..master | sed 's/^/  /'

echo
echo "## Local branches"
echo "branch | last commit | origin | vs master (behind/ahead) | merged into | checked out at"
git for-each-ref --sort=-committerdate refs/heads --format='%(refname:short)|%(committerdate:relative)|%(upstream:short)|%(upstream:track)' |
while IFS='|' read -r br date up track; do
  [ "$br" = master ] && continue
  # Backup status on origin, independent of the configured tracking ref (a branch can
  # track upstream/master and still exist nowhere on origin).
  if ! git show-ref --quiet "refs/remotes/origin/$br"; then origin="NOT ON ORIGIN"
  elif [ "$up" = "origin/$br" ]; then origin="origin ${track:-[in sync]}"
  else
    read -r ob oa < <(git rev-list --left-right --count "origin/$br...$br")
    origin="origin (not tracked; $oa unpushed, $ob behind)"
  fi
  [ -n "$up" ] && [ "$up" != "origin/$br" ] && origin="$origin; tracks $up $track"
  read -r mb ma < <(git rev-list --left-right --count "master...$br")
  merged=""
  git merge-base --is-ancestor "$br" master && merged="master "
  git merge-base --is-ancestor "$br" upstream/master && merged="${merged}upstream"
  wt=$(git worktree list --porcelain | awk -v b="branch refs/heads/$br" '/^worktree /{w=$2} $0==b{print w}')
  echo "$br | $date | $origin | $mb/$ma | ${merged:--} | ${wt:--}"
done
echo "(merged = ancestor check; a squash-merged branch shows '-'. Check the PR state instead.)"

echo
echo "## Remote branches on origin with no local branch"
for r in $(git for-each-ref --format='%(refname:short)' refs/remotes/origin | grep -v -e '^origin$' -e '^origin/HEAD$' -e '^origin/master$'); do
  git show-ref --quiet "refs/heads/${r#origin/}" || echo "  $r ($(git log -1 --format=%cr "$r"))"
done

echo
echo "## Worktrees"
git worktree list | sed 's/^/  /'
for w in $(git worktree list --porcelain | awk '/^worktree /{print $2}'); do
  n=$(git -C "$w" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" != 0 ] && echo "  DIRTY ($n files): $w"
done

echo
echo "## Fork PRs ($FORK)"
gh pr list --repo "$FORK" --state all --limit 30 \
  --json number,title,headRefName,state,isDraft,updatedAt \
  --jq '.[] | "#\(.number) [\(.state)\(if .isDraft then ",draft" else "" end)] \(.headRefName) — \(.title) (updated \(.updatedAt[:10]))"'

echo
echo "## My upstream PRs ($UPSTREAM, author $ME)"
gh pr list --repo "$UPSTREAM" --author "$ME" --state all --limit 30 \
  --json number,title,headRefName,state,isDraft,updatedAt,reviewDecision \
  --jq '.[] | "#\(.number) [\(.state)\(if .isDraft then ",draft" else "" end)\(if (.reviewDecision // "") != "" then ","+.reviewDecision else "" end)] \(.headRefName) — \(.title) (updated \(.updatedAt[:10]))"'
echo "Open ones, latest comment or review:"
for n in $(gh pr list --repo "$UPSTREAM" --author "$ME" --state open --json number --jq '.[].number'); do
  gh pr view "$n" --repo "$UPSTREAM" --json comments,reviews \
    --jq '[(.comments[]|{a:.author.login,t:.createdAt,b:.body}),(.reviews[]|{a:.author.login,t:.submittedAt,b:.body})] | sort_by(.t) | last // empty | "  #'"$n"' \(.a) \(.t[:10]): \(.b[:200]|gsub("\n";" "))"'
done

echo
echo "## My upstream issues"
gh issue list --repo "$UPSTREAM" --author "$ME" --state all --limit 20 \
  --json number,title,state,updatedAt,comments \
  --jq '.[] | "#\(.number) [\(.state)] \(.title) (\(.comments|length) comments, updated \(.updatedAt[:10]))"'

echo
since=$(date -v-14d +%Y-%m-%d 2>/dev/null || date -d '14 days ago' +%Y-%m-%d)
echo "## Upstream activity since $since"
echo "Issues opened or updated:"
gh issue list --repo "$UPSTREAM" --state all --search "updated:>=$since" --limit 25 \
  --json number,title,state,labels \
  --jq '.[] | "  #\(.number) [\(.state)] \(.title) \([.labels[].name]|join(","))"'
echo "PRs by others, opened or updated:"
gh pr list --repo "$UPSTREAM" --state all --search "updated:>=$since -author:$ME" --limit 25 \
  --json number,title,state,author \
  --jq '.[] | "  #\(.number) [\(.state)] \(.title) (@\(.author.login))"'
