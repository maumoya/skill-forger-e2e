#!/usr/bin/env bash
# owner_only.sh - one author, the owner. Checks everything that can add a second name to a repo:
#   1. every commit on every branch and tag on GitHub is authored by the owner (no bot, no AI, no other identity)
#   2. no commit message carries a co-author trailer
#   3. no open PR by a bot or another account waits to be merged as that account
#   4. no branch of an already merged PR is still on GitHub (it keeps old commits alive after a history fix)
#   5. GitHub deletes the head branch after every merge (delete_branch_on_merge), so 4 cannot happen again
#   6. the GitHub contributor API lists the owner only
# The repo page's "Contributors" sidebar is cached apart from the API: after a history fix it can lag ~24 h.
# Read-only except --apply, which only switches on delete_branch_on_merge. Never deletes a branch or rewrites history.
# Owner identity: GitHub login from OWNER/REPO; names from FORGE_OWNER_NAMES (comma list), else git config
# user.name plus the GitHub profile name. Emails OWNER@users.noreply.github.com and ID+OWNER@... always count.
# Usage: owner_only.sh OWNER/REPO [REPO_DIR] [--apply] [--no-fetch]
# Exit 0 = owner only, 1 = a second author or a way in exists, 2 = cannot check.
set -uo pipefail
slug=""; dir="."; apply=0; fetch=1
for a in "$@"; do
  case "$a" in
    --apply) apply=1 ;;
    --no-fetch) fetch=0 ;;
    */*) if [ -d "$a" ]; then dir="$a"; else slug="$a"; fi ;;
    *) dir="$a" ;;
  esac
done
[ -n "$slug" ] || { echo "usage: owner_only.sh OWNER/REPO [REPO_DIR] [--apply] [--no-fetch]" >&2; exit 2; }
owner="${slug%%/*}"; lc() { tr 'A-Z' 'a-z'; }
n=0
ok()   { echo "ok    $1"; }
miss() { n=$((n+1)); echo "MISS  $1"; [ -n "${2:-}" ] && echo "      fix: $2"; }

gh_ok=0; command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && gh_ok=1

# who counts as the owner
names="${FORGE_OWNER_NAMES:-}"
if [ -z "$names" ]; then
  names="$(git -C "$dir" config user.name 2>/dev/null)"
  [ "$gh_ok" = 1 ] && names="$names,$(gh api "users/$owner" -q '.name // ""' 2>/dev/null)"
fi
names="$(tr ',' '\n' <<<"$names" | sed 's/^ *//;s/ *$//' | grep -v '^$' | lc | sort -u)"
is_owner() { # NAME EMAIL
  local nm em; nm="$(lc <<<"$1")"; em="$(lc <<<"$2")"
  case "$em" in *'[bot]'*|*noreply@anthropic.com|*noreply@openai.com) return 1 ;; esac
  case "$nm" in *'[bot]'*) return 1 ;; esac
  case "$em" in "$(lc <<<"$owner")@users.noreply.github.com"|*"+$(lc <<<"$owner")@users.noreply.github.com") return 0 ;; esac
  grep -qxF "$nm" <<<"$names"
}

# 1 + 2: history of every branch and tag on GitHub
if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
  remote="$(git -C "$dir" remote | grep -x origin || git -C "$dir" remote | head -1)"
  if [ "$fetch" = 1 ] && [ -n "$remote" ]; then
    git -C "$dir" fetch --quiet --prune --tags "$remote" 2>/dev/null || echo "skip  fetch failed: checking the refs already here"
  fi
  refs=(--all); [ -n "$remote" ] && refs=("--remotes=$remote" --tags)
  others="$(git -C "$dir" log "${refs[@]}" --format='%an%x09%ae' 2>/dev/null | sort -u | while IFS=$'\t' read -r nm em; do
    is_owner "$nm" "$em" || echo "$nm <$em>"; done)"
  if [ -z "$others" ]; then ok "every commit on every branch and tag is authored by the owner"
  else
    while IFS= read -r who; do
      c="$(git -C "$dir" log "${refs[@]}" --format='%an <%ae>' 2>/dev/null | grep -cxF "$who")"
      where="$(git -C "$dir" log "${refs[@]}" --format='%h %an <%ae>' 2>/dev/null | grep -F " $who" | head -1 | cut -d' ' -f1)"
      on="$( { git -C "$dir" branch -r --contains "$where" 2>/dev/null; git -C "$dir" tag --contains "$where" 2>/dev/null; } | sed 's/^ *//' | head -3 | paste -sd, -)"
      if [ -n "$on" ] && ! grep -qvE '^(origin/)?(dependabot|renovate)/' <<<"$(tr ',' '\n' <<<"$on")"; then
        miss "$c commit(s) authored by $who, only on bot PR branch $on" "land it as the owner with land_bot_pr.sh (it closes the PR and deletes that branch)"
      else
        miss "$c commit(s) authored by $who (first: $where, on: ${on:-unknown})" \
          "back up (git clone --mirror), re-author to the owner (git filter-repo --mailmap or rebase --reset-author), force-push on the owner's OK, re-sign tags"
      fi
    done <<<"$others"
  fi
  co="co-$(printf authored)-by:"
  trail="$(git -C "$dir" log "${refs[@]}" --format='%h%x09%B' 2>/dev/null | grep -iE "$co" | grep -vi "$owner@users.noreply.github.com" | wc -l | tr -d ' ')"
  if [ "${trail:-0}" -eq 0 ]; then ok "no co-author trailer on any branch or tag"
  else miss "$trail co-author trailer line(s) in commit messages" "your-authorship-skill, then reword those commits (backed up, on the owner's OK)"; fi
else
  echo "skip  $dir is not a git repo: history not checked"
fi

if [ "$gh_ok" = 0 ]; then echo "skip  gh not signed in: GitHub checks skipped"; echo "RESULT $n miss(es)"; [ $n -eq 0 ] && exit 0 || exit 1; fi
def="$(gh api "repos/$slug" -q .default_branch 2>/dev/null)" || { echo "cannot read $slug" >&2; exit 2; }

# 3: open PRs that would add another author if merged as is
bots="$(gh pr list -R "$slug" --state open --json number,title,author \
  -q ".[] | select((.author.login | ascii_downcase) != \"$(lc <<<"$owner")\") | \"#\(.number) by \(.author.login): \(.title)\"" 2>/dev/null)"
if [ -z "$bots" ]; then ok "no open PR by a bot or another account"
else
  while IFS= read -r p; do
    num="${p%% *}"; num="${num#\#}"
    miss "open PR $p" "never merge it as that account: land_bot_pr.sh $slug $num $dir --apply"
  done <<<"$bots"
fi

# 4: branches of merged PRs still on GitHub
stale=0
while IFS= read -r b; do
  [ -z "$b" ] || [ "$b" = "$def" ] && continue
  m="$(gh pr list -R "$slug" --head "$b" --state merged --json number -q '.[0].number // empty' 2>/dev/null)"
  [ -n "$m" ] || continue
  stale=1
  miss "branch $b (PR #$m merged) is still on GitHub and keeps its old commits reachable" \
    "back it up (git clone --mirror), then on the owner's OK: git push origin --delete $b"
done < <(gh api --paginate "repos/$slug/branches" -q '.[].name' 2>/dev/null)
[ $stale -eq 0 ] && ok "no branch of a merged PR left on GitHub"

# 5: GitHub deletes head branches after a merge
dbm() { [ "$(gh api "repos/$slug" -q .delete_branch_on_merge 2>/dev/null)" = true ]; }
if dbm; then ok "GitHub deletes the head branch after every merge"
elif [ "$apply" = 1 ]; then
  gh api -X PATCH "repos/$slug" -F delete_branch_on_merge=true >/dev/null 2>&1 && dbm \
    && ok "delete head branch after merge: turned on" \
    || miss "delete head branch after merge: could not turn on" "gh api -X PATCH repos/$slug -F delete_branch_on_merge=true"
else miss "merged PR branches stay on GitHub (delete_branch_on_merge off)" "owner_only.sh $slug $dir --apply"; fi

# 6: GitHub contributor API
api="$(gh api "repos/$slug/contributors?anon=1" -q '.[] | (.login // .name // "anonymous")' 2>/dev/null | grep -vixF "$owner" | paste -sd, -)"
if [ -z "$api" ]; then ok "GitHub contributor API lists $owner only (the repo page can lag ~24 h after a history fix)"
else miss "GitHub contributor API also lists: $api" "fix the history above; if the API and every ref are clean but the page still shows 2 after 24 h, ask GitHub Support to recompute it"; fi

echo "RESULT $n miss(es)"
[ $n -eq 0 ]
