#!/usr/bin/env bash
# repo_hygiene.sh - nothing left pending or insecure on the GitHub repo.
# Lists what the repo page nags about plus what it hides behind tabs:
#   open PRs, branches pushed but never opened as a PR ("Compare & pull request" banner),
#   open Dependabot, code-scanning and secret-scanning alerts, Dependabot alerts or secret
#   scanning switched off, and workflows whose latest run on the default branch failed.
# The "Draft a release" / "publish this Action" banner and repo settings are repo_guard.sh's job.
# Read-only: it only calls GET endpoints. Exit 0 = clean, 1 = something is pending.
# Usage: repo_hygiene.sh OWNER/REPO [--quiet]
set -uo pipefail
slug=""; quiet=0
for a in "$@"; do
  case "$a" in
    --quiet) quiet=1 ;;
    */*) [ -d "$a" ] || slug="$a" ;;
  esac
done
[ -n "$slug" ] || { echo "usage: repo_hygiene.sh OWNER/REPO [--quiet]" >&2; exit 2; }
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || { echo "FAIL gh not installed or not signed in" >&2; exit 2; }
n=0
say() { [ "$quiet" = 1 ] || echo "$@"; }
pend() { n=$((n+1)); say "PENDING $1"; [ -n "${2:-}" ] && say "        -> $2"; }
ok() { say "ok      $1"; }

def=$(gh repo view "$slug" --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null); def=${def:-main}

# 1. open pull requests
prs=$(gh pr list -R "$slug" --state open --json number,title,isDraft -q '.[] | "#\(.number) \(.title)\(if .isDraft then " (draft)" else "" end)"' 2>/dev/null)
if [ -n "$prs" ]; then while IFS= read -r p; do pend "open PR $p" "merge it or close it with a reason"; done <<<"$prs"; else ok "no open PRs"; fi

# 2. branches pushed but never opened as a PR (the "Compare & pull request" banner)
found=0
while IFS= read -r b; do
  [ -z "$b" ] || [ "$b" = "$def" ] && continue
  ahead=$(gh api "repos/$slug/compare/$def...$b" -q .ahead_by 2>/dev/null || echo 0)
  [ "${ahead:-0}" -gt 0 ] || continue
  any=$(gh pr list -R "$slug" --head "$b" --state all --json number -q 'length' 2>/dev/null || echo 0)
  if [ "${any:-0}" -eq 0 ]; then found=1; pend "branch $b is $ahead commit(s) ahead with no PR" "open a PR for it, or say why it stays a branch"; fi
done < <(gh api --paginate "repos/$slug/branches" -q '.[].name' 2>/dev/null)
[ $found -eq 0 ] && ok "every branch ahead of $def has a PR"

# 3. security alerts and switches
dep=$(gh api "repos/$slug/vulnerability-alerts" -i 2>/dev/null | head -1 | awk '{print $2}')
[ "$dep" = "204" ] && ok "Dependabot alerts on" || pend "Dependabot alerts are off" "gh api -X PUT repos/$slug/vulnerability-alerts"
for kind in dependabot code-scanning secret-scanning; do
  out=$(gh api "repos/$slug/$kind/alerts?state=open&per_page=100" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then
    if [ "$kind" = secret-scanning ]; then pend "secret scanning is off or unreadable" "Settings > Code security: turn on secret scanning and push protection"
    elif [ "$kind" = code-scanning ] && grep -q 'no analysis' <<<"$out"; then pend "no code-scanning analysis yet" "push codeql.yml to $def"
    else say "skip    $kind alerts unreadable (${out:0:80})"; fi
    continue
  fi
  c=$(jq 'length' <<<"$out" 2>/dev/null || echo 0)
  if [ "${c:-0}" -gt 0 ]; then
    jq -r '.[] | "#\(.number) \(.rule.description // .security_advisory.summary // .secret_type_display_name // "alert")"' <<<"$out" | head -10 |
      while IFS= read -r l; do pend "$kind alert $l" "fix it, or dismiss it with a written reason"; done
    n=$((n+c))
  else ok "0 open $kind alerts"; fi
done

# 4. workflows whose latest run on the default branch failed
bad=$(gh run list -R "$slug" -b "$def" -L 50 --json workflowName,conclusion,status,url \
  -q 'group_by(.workflowName)[] | .[0] | select(.status=="completed" and (.conclusion=="failure" or .conclusion=="timed_out" or .conclusion=="startup_failure")) | "\(.workflowName) \(.url)"' 2>/dev/null)
if [ -n "$bad" ]; then while IFS= read -r l; do pend "latest $def run failed: $l" "open the log, fix, re-run"; done <<<"$bad"; else ok "latest run of every workflow on $def passed"; fi

say "RESULT $n pending"
[ $n -eq 0 ]
