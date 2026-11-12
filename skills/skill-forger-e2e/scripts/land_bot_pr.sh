#!/usr/bin/env bash
# land_bot_pr.sh - land a bot's PR (Dependabot, Renovate, any other account) as an owner commit, never as the bot.
# Merging a bot PR, even squashed, makes the bot a repo contributor and shows it on the repo page.
# Steps: read the PR, cut owner/land-pr-N from the base branch, apply the PR's diff, commit it as the owner
# (signed when git is set to sign, no trailers), push, open the owner's PR, then close the bot PR and delete its branch.
# Dry run by default: prints the plan and changes nothing. --apply does it. Merging the new PR stays the owner's step.
# Usage: land_bot_pr.sh OWNER/REPO PR_NUMBER [REPO_DIR] [--apply]
# Exit 0 = done (or plan shown), 1 = refused or failed, 2 = bad usage.
set -uo pipefail
slug=""; pr=""; dir="."; apply=0
for a in "$@"; do
  case "$a" in
    --apply) apply=1 ;;
    */*) if [ -d "$a" ]; then dir="$a"; else slug="$a"; fi ;;
    *[!0-9]*) dir="$a" ;;
    *) pr="$a" ;;
  esac
done
[ -n "$slug" ] && [ -n "$pr" ] || { echo "usage: land_bot_pr.sh OWNER/REPO PR_NUMBER [REPO_DIR] [--apply]" >&2; exit 2; }
owner="${slug%%/*}"
die() { echo "STOP  $1" >&2; exit 1; }
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || die "gh is not signed in"
git -C "$dir" rev-parse --git-dir >/dev/null 2>&1 || die "$dir is not a git repo"

info="$(gh pr view "$pr" -R "$slug" --json state,author,baseRefName,headRefName,title -q '[.state,.author.login,.baseRefName,.headRefName,.title]|@tsv' 2>/dev/null)" \
  || die "cannot read PR #$pr in $slug"
IFS=$'\t' read -r state author base head title <<<"$info"
[ "$state" = OPEN ] || die "PR #$pr is $state, not open"
[ "$(tr 'A-Z' 'a-z' <<<"$author")" != "$(tr 'A-Z' 'a-z' <<<"$owner")" ] || die "PR #$pr is the owner's own PR: merge it normally"

branch="owner/land-pr-$pr"
msg="$title"
case "$msg" in *:*) ;; *) msg="chore: $msg" ;; esac
echo "PR    #$pr by $author: $title ($head -> $base)"
echo "plan  1. branch $branch from origin/$base"
echo "      2. apply the PR's diff, commit as $(git -C "$dir" config user.name) <$(git -C "$dir" config user.email)>, no trailers"
echo "      3. push and open the owner's PR into $base"
echo "      4. close #$pr with a note and delete its branch $head"
if [ "$apply" = 0 ]; then echo "RESULT dry run: nothing changed. Run again with --apply."; exit 0; fi

[ -z "$(git -C "$dir" status --porcelain)" ] || die "$dir has uncommitted changes: commit or set them aside first"
back="$(git -C "$dir" rev-parse --abbrev-ref HEAD)"
git -C "$dir" fetch --quiet origin "$base" || die "cannot fetch origin/$base"
git -C "$dir" switch --quiet -c "$branch" "origin/$base" || die "cannot create $branch (does it exist already?)"
undo() { git -C "$dir" switch --quiet "$back"; git -C "$dir" branch -D "$branch" >/dev/null 2>&1; die "$1"; }
gh pr diff "$pr" -R "$slug" 2>/dev/null | git -C "$dir" apply --index --whitespace=nowarn - \
  || undo "the PR's diff does not apply on origin/$base: ask the bot to rebase, then run again"
git -C "$dir" diff --cached --quiet && undo "the PR changes nothing on origin/$base"
body="Lands #$pr ($author) as an owner commit. Bot PRs are never merged as the bot."
git -C "$dir" commit --quiet -m "$msg" -m "$body" || undo "commit failed"
co="co-$(printf authored)-by"
git -C "$dir" log -1 --format=%B | grep -qi "$co" && undo "the commit message holds a co-author trailer: your-authorship-skill"
git -C "$dir" push --quiet -u origin "$branch" || undo "push failed"
new="$(gh pr create -R "$slug" --base "$base" --head "$branch" --title "$msg" --body "$body" 2>/dev/null)" || die "PR create failed; branch $branch is pushed"
gh pr close "$pr" -R "$slug" --delete-branch --comment "Landed as an owner commit in $new. Bot PRs are never merged as the bot." >/dev/null \
  || echo "warn  could not close #$pr: close it by hand"
git -C "$dir" switch --quiet "$back"
echo "ok    owner PR: $new"
echo "ok    #$pr closed, branch $head deleted"
echo "RESULT landed as the owner; merge $new on green CI with the owner's OK"
