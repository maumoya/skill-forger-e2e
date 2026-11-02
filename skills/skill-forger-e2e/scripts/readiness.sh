#!/usr/bin/env bash
# Ship-readiness score 0-100 for a skill repo, plus a shields.io badge.
# Read-only. Local checks always run; GitHub checks (topics, description, Scorecard) run when OWNER/REPO is given.
# Skipped checks are left out and the score is scaled to what was checked.
# Usage: readiness.sh [REPO_DIR] [OWNER/REPO] [--min N] [--markdown]
#   --min N      exit 1 when the score is below N (for CI)
#   --markdown   print a Markdown table (for a PR comment or job summary)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="."; slug=""; min=0; md=0
while [ $# -gt 0 ]; do
  case "$1" in
    --min) min="${2:-0}"; shift 2 ;;
    --markdown) md=1; shift ;;
    */*) if [ -d "$1" ]; then repo="$1"; else slug="$1"; fi; shift ;;
    *) repo="$1"; shift ;;
  esac
done
[[ "$min" =~ ^[0-9]+$ ]] || { echo "--min must be a number" >&2; exit 2; }
cd "$repo" || { echo "no such dir: $repo" >&2; exit 2; }

got=0; max=0; rows=()
# check POINTS LABEL OK(0/1/skip) [HINT]
check() {
  local pts="$1" label="$2" ok="$3" hint="${4:-}"
  if [ "$ok" = skip ]; then rows+=("skip|$pts|$label|$hint"); return; fi
  max=$((max+pts))
  if [ "$ok" = 1 ]; then got=$((got+pts)); rows+=("ok|$pts|$label|"); else rows+=("miss|$pts|$label|$hint"); fi
}
yes() { "$@" >/dev/null 2>&1 && echo 1 || echo 0; }

shopt -s nullglob
lint_out="$(bash "$here/lint_skill.sh" . 2>/dev/null)"; lint_rc=$?
check 15 "lint passes (no FAIL)" "$([ $lint_rc -eq 0 ] && echo 1 || echo 0)" "run lint_skill.sh and fix each FAIL"
check 5 "lint has 0 warnings" "$(grep -q '^WARN' <<<"$lint_out" && echo 0 || echo 1)" "fix the WARN lines from lint_skill.sh"
check 10 "plugin.json + marketplace.json" "$(yes test -f .claude-plugin/plugin.json -a -f .claude-plugin/marketplace.json)" "add .claude-plugin/ (retrofit.sh)"
check 10 "README shows both install paths" "$(grep -q 'plugin marketplace add' README.md 2>/dev/null && grep -q 'npx skills add' README.md 2>/dev/null && echo 1 || echo 0)" "add /plugin and npx skills install lines"
check 5 "README has a picture" "$(yes grep -qiE '\.(png|gif|svg|jpe?g|webp)' README.md)" "add a screenshot or demo GIF near the top"
cases=(evals/*/case.yaml)
check 10 "at least 1 eval case" "$([ ${#cases[@]} -ge 1 ] && echo 1 || echo 0)" "add evals/<case>/ (see references/testing.md)"
check 5 "3+ eval cases" "$([ ${#cases[@]} -ge 3 ] && echo 1 || echo 0)" "cover trigger, happy path and a failure case"
check 5 "LICENSE" "$(yes test -f LICENSE)" "add a LICENSE"
check 5 "SECURITY.md" "$(yes test -f SECURITY.md)" "add SECURITY.md"
check 3 "llms.txt" "$(yes test -f llms.txt)" "add llms.txt for AI discovery"
check 2 "CHANGELOG.md" "$(yes test -f CHANGELOG.md)" "add CHANGELOG.md"
wf=(.github/workflows/*.yml .github/workflows/*.yaml)
check 5 "CI runs the linter" "$([ ${#wf[@]} -gt 0 ] && grep -lq 'lint_skill.sh\|skill-forger-e2e' "${wf[@]}" 2>/dev/null && echo 1 || echo 0)" "add a lint workflow or the GitHub Action"
check 5 "OpenSSF Scorecard workflow" "$([ ${#wf[@]} -gt 0 ] && grep -lq 'scorecard-action' "${wf[@]}" 2>/dev/null && echo 1 || echo 0)" "add .github/workflows/scorecard.yml"
check 3 "Dependabot" "$(yes test -f .github/dependabot.yml)" "add .github/dependabot.yml"
check 2 "release workflow" "$([ ${#wf[@]} -gt 0 ] && grep -lqi 'release' "${wf[@]}" 2>/dev/null && echo 1 || echo 0)" "add a tag-triggered release workflow"

if [ -n "$slug" ] && command -v gh >/dev/null; then
  meta="$(gh repo view "$slug" --json description,repositoryTopics 2>/dev/null)"
  if [ -n "$meta" ]; then
    topics=$(jq '.repositoryTopics | length' <<<"$meta" 2>/dev/null || echo 0)
    check 4 "5+ GitHub topics" "$([ "${topics:-0}" -ge 5 ] && echo 1 || echo 0)" "gh repo edit $slug --add-topic ..."
    check 2 "GitHub description set" "$([ -n "$(jq -r '.description // ""' <<<"$meta")" ] && echo 1 || echo 0)" "gh repo edit $slug --description ..."
  else
    check 4 "5+ GitHub topics" skip "repo not found or gh not signed in"
    check 2 "GitHub description set" skip "repo not found or gh not signed in"
  fi
  sc=$(curl -fsS "https://api.securityscorecards.dev/projects/github.com/$slug" 2>/dev/null | jq -r '.score // empty' 2>/dev/null)
  if [ -n "$sc" ]; then
    check 4 "Scorecard score >= 5 (now $sc)" "$(awk -v s="$sc" 'BEGIN{print (s>=5)?1:0}')" "fix the lowest Scorecard checks"
  else
    check 4 "Scorecard score >= 5" skip "no Scorecard result yet"
  fi
else
  check 10 "GitHub topics, description, Scorecard" skip "pass OWNER/REPO to check"
fi

score=$(( max > 0 ? (got*100 + max/2) / max : 0 ))
if   [ $score -ge 90 ]; then color=brightgreen
elif [ $score -ge 75 ]; then color=green
elif [ $score -ge 50 ]; then color=yellow
else color=red; fi
badge="https://img.shields.io/badge/skill%20readiness-${score}%2F100-${color}"

if [ $md -eq 1 ]; then
  echo "### Skill readiness: $score/100"; echo
  echo "| | Check | Points | Fix |"; echo "|---|---|---|---|"
  for r in "${rows[@]}"; do
    IFS='|' read -r st pts label hint <<<"$r"
    case $st in ok) mark="✅" ;; miss) mark="❌" ;; *) mark="➖" ;; esac
    echo "| $mark | $label | $pts | $hint |"
  done
  echo; echo "Badge: \`![skill readiness]($badge)\`"
else
  for r in "${rows[@]}"; do
    IFS='|' read -r st pts label hint <<<"$r"
    printf '%-4s %2s  %-38s %s\n' "$st" "$pts" "$label" "$hint"
  done
  echo "SCORE $score/100 ($got of $max points checked)"
  echo "BADGE ![skill readiness]($badge)"
fi
[ $score -ge "$min" ] || { echo "score $score is below --min $min" >&2; exit 1; }
