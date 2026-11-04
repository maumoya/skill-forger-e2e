#!/usr/bin/env bash
# Ship-readiness score 0-100 for a skill repo, plus a shields.io badge.
# Read-only. Local checks always run; GitHub checks (topics, description, Scorecard) run when OWNER/REPO is given.
# Skipped checks are left out and the score is scaled to what was checked.
# Ship gates (marked GATE): Scorecard >= 7.3, Best Practices passing, private vulnerability reporting on, a ruleset on
# main that requires a PR and CodeQL. They need OWNER/REPO and gh signed in.
# Usage: readiness.sh [REPO_DIR] [OWNER/REPO] [--min N] [--ship] [--markdown]
#   --min N      exit 1 when the score is below N (for CI)
#   --ship       exit 1 when any GATE is missed or could not be checked (run before every release tag)
#   --markdown   print a Markdown table (for a PR comment or job summary)
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="."; slug=""; min=0; md=0; ship=0
while [ $# -gt 0 ]; do
  case "$1" in
    --min) min="${2:-0}"; shift 2 ;;
    --markdown) md=1; shift ;;
    --ship) ship=1; shift ;;
    */*) if [ -d "$1" ]; then repo="$1"; else slug="$1"; fi; shift ;;
    *) repo="$1"; shift ;;
  esac
done
[[ "$min" =~ ^[0-9]+$ ]] || { echo "--min must be a number" >&2; exit 2; }
cd "$repo" || { echo "no such dir: $repo" >&2; exit 2; }

got=0; max=0; rows=(); blocked=()
# check POINTS LABEL OK(0/1/skip) [HINT]
check() {
  local pts="$1" label="$2" ok="$3" hint="${4:-}"
  if [ "$ok" = skip ]; then rows+=("skip|$pts|$label|$hint"); return; fi
  max=$((max+pts))
  if [ "$ok" = 1 ]; then got=$((got+pts)); rows+=("ok|$pts|$label|"); else rows+=("miss|$pts|$label|$hint"); fi
}
yes() { "$@" >/dev/null 2>&1 && echo 1 || echo 0; }
# gate: a check that blocks a release under --ship when it is missed or skipped.
gate() { [ "$3" = 1 ] || blocked+=("$2"); check "$1" "GATE $2" "$3" "${4:-}"; }

shopt -s nullglob
lint_out="$(bash "$here/lint_skill.sh" . 2>/dev/null)"; lint_rc=$?
check 15 "lint passes (no FAIL)" "$([ $lint_rc -eq 0 ] && echo 1 || echo 0)" "run lint_skill.sh and fix each FAIL"
check 5 "lint has 0 warnings" "$(grep -q '^WARN' <<<"$lint_out" && echo 0 || echo 1)" "fix the WARN lines from lint_skill.sh"
check 10 "plugin.json + marketplace.json" "$(yes test -f .claude-plugin/plugin.json -a -f .claude-plugin/marketplace.json)" "add .claude-plugin/ (retrofit.sh)"
check 10 "README shows both install paths" "$(grep -q 'plugin marketplace add' README.md 2>/dev/null && grep -q 'npx skills add' README.md 2>/dev/null && echo 1 || echo 0)" "add /plugin and npx skills install lines"
check 3 "README has a header banner" "$(yes grep -qiE 'header[^)\" ]*\.(png|svg)' README.md)" "make_header.sh writes assets/header.svg + .png; put it first in the README"
check 2 "README has a demo video card" "$(yes grep -qiE '\.(gif|mp4|webm)|demo[^)\" ]*\.svg' README.md)" "a <=10 s demo GIF under the header, the same clip as the portfolio site"
cases=(evals/*/case.yaml)
check 3 "README has a badge row" "$(yes grep -qiE 'shields\.io|/badge' README.md)" "add a centered badge row under the header (see Phase 6)"
check 2 "README has About the author" "$(yes grep -qiE '^#+ *about the author' README.md)" "owner_profile.sh drafts it from the owner's GitHub profile"
check 10 "at least 1 eval case" "$([ ${#cases[@]} -ge 1 ] && echo 1 || echo 0)" "add evals/<case>/ (see references/testing.md)"
check 5 "3+ eval cases" "$([ ${#cases[@]} -ge 3 ] && echo 1 || echo 0)" "cover trigger, happy path and a failure case"
check 5 "trigger set (evals/triggers.json)" "$([ -f evals/triggers.json ] && ! grep -q REPLACE evals/triggers.json && echo 1 || echo 0)" "list should and should-not queries, then run trigger_test.sh"
check 5 "LICENSE" "$(yes test -f LICENSE)" "add a LICENSE"
check 5 "SECURITY.md" "$(yes test -f SECURITY.md)" "add SECURITY.md"
check 3 "llms.txt" "$(yes test -f llms.txt)" "add llms.txt for AI discovery"
check 2 "CHANGELOG.md" "$(yes test -f CHANGELOG.md)" "add CHANGELOG.md"
wf=(.github/workflows/*.yml .github/workflows/*.yaml)
check 5 "CI runs the linter" "$([ ${#wf[@]} -gt 0 ] && grep -lq 'lint_skill.sh\|skill-forger-e2e' "${wf[@]}" 2>/dev/null && echo 1 || echo 0)" "add a lint workflow or the GitHub Action"
check 5 "OpenSSF Scorecard workflow" "$([ ${#wf[@]} -gt 0 ] && grep -lq 'scorecard-action' "${wf[@]}" 2>/dev/null && echo 1 || echo 0)" "add .github/workflows/scorecard.yml"
check 3 "Dependabot" "$(yes test -f .github/dependabot.yml)" "add .github/dependabot.yml"
check 2 "release workflow" "$([ ${#wf[@]} -gt 0 ] && grep -lqi 'release' "${wf[@]}" 2>/dev/null && echo 1 || echo 0)" "add a tag-triggered release workflow"
check 3 "CodeQL workflow" "$([ ${#wf[@]} -gt 0 ] && grep -lq 'codeql-action' "${wf[@]}" 2>/dev/null && echo 1 || echo 0)" "add .github/workflows/codeql.yml (templates/repo/.github/workflows/)"
noperm=0; unpinned=0
for f in ${wf[@]+"${wf[@]}"}; do
  grep -qE '^permissions: *read-all' "$f" || noperm=$((noperm+1))
  unpinned=$((unpinned + $(grep -E '^\s*-?\s*uses:\s*[^.][^@]*@' "$f" | grep -vE '@[0-9a-f]{40}( |$)' | grep -vc 'slsa-github-generator')))
done
check 3 "every workflow has permissions: read-all" "$([ ${#wf[@]} -gt 0 ] && [ $noperm -eq 0 ] && echo 1 || echo 0)" "$noperm workflow(s) lack a top-level 'permissions: read-all'"
check 3 "every action pinned to a commit SHA" "$([ ${#wf[@]} -gt 0 ] && [ $unpinned -eq 0 ] && echo 1 || echo 0)" "$unpinned uses: line(s) on a tag; pin each to its full SHA (# vX comment)"
v=$(jq -r '.version // empty' .claude-plugin/plugin.json 2>/dev/null)
stale=$(grep -ohE '@v[0-9]+\.[0-9]+\.[0-9]+' README.md llms.txt 2>/dev/null | sort -u | grep -vxF "@v$v" | tr '\n' ' ')
check 3 "version ${v:-?} in CHANGELOG, README, llms.txt" "$([ -n "$v" ] && grep -qE "^## \[?v?${v//./\\.}\]?( |$)" CHANGELOG.md 2>/dev/null && [ -z "$stale" ] && echo 1 || echo 0)" "bump plugin.json, CHANGELOG, README @vX example and llms.txt together${stale:+ (stale: $stale)}"
if [ -f action.yml ] || [ -f action.yaml ]; then
  selftest=0
  [ ${#wf[@]} -gt 0 ] && grep -lqE '^\s*-?\s*uses:\s*\./?\s*$' "${wf[@]}" 2>/dev/null && grep -lqE '= failure|== .failure.' "${wf[@]}" 2>/dev/null && selftest=1
  check 3 "CI self-tests action.yml (pass + fail)" "$selftest" "a 'uses: ./' job on a passing input and one asserted outcome == 'failure'"
else
  check 3 "root action.yml (GitHub Marketplace)" 0 "no action.yml = not on the Marketplace; design a real CI check (references/packaging.md)"
fi
# Marketing: results as percentages, the hero result as a card.
rawsize=$(grep -oE 'img\.shields\.io/badge/[^)" ]*[0-9]+(\.[0-9]+)?(%20)?(GiB|GB|MiB|MB|KiB|KB)' README.md 2>/dev/null | wc -l | tr -d ' ')
check 2 "benefit badges in %, not raw sizes" "$([ "$rawsize" -eq 0 ] && echo 1 || echo 0)" "say '19% of the disk freed (6% → 25% free)', not GiB"
check 2 "README hero result card (SVG)" "$(yes grep -qiE '(card|hero)[^)\" ]*\.svg' README.md)" "a big green SVG card with the measured result, under the header"

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
    gate 8 "Scorecard >= 7.3 (now $sc)" "$(awk -v s="$sc" 'BEGIN{print (s>=7.3)?1:0}')" "scorecard.sh $slug lists each fix"
  else
    gate 8 "Scorecard >= 7.3" skip "no Scorecard result yet: push scorecard.yml to main"
  fi
  bp=$(curl -fsS "https://www.bestpractices.dev/en/projects.json?url=$(jq -rn --arg u "https://github.com/$slug" '$u|@uri')" 2>/dev/null \
    | jq -r --arg u "https://github.com/$slug" '[.[] | select(.repo_url == $u or .homepage_url == $u)][0].id // empty' 2>/dev/null)
  lvl=""; [ -n "$bp" ] && lvl=$(curl -fsS "https://www.bestpractices.dev/projects/$bp.json" 2>/dev/null | jq -r '.badge_level // empty' 2>/dev/null)
  gate 5 "Best Practices passing (${lvl:-not registered})" "$(grep -qxE 'passing|silver|gold' <<<"$lvl" && echo 1 || echo 0)" "bestpractices.sh $slug: fill the form to 100% of passing, add the badge"
  if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    pvr=$(gh api "repos/$slug/private-vulnerability-reporting" --jq .enabled 2>/dev/null)
    gate 3 "private vulnerability reporting on" "$([ "$pvr" = true ] && echo 1 || echo 0)" "owner runs: gh api -X PUT repos/$slug/private-vulnerability-reporting"
    def=$(gh repo view "$slug" --json defaultBranchRef --jq .defaultBranchRef.name 2>/dev/null)
    rules=$(gh api "repos/$slug/rules/branches/${def:-main}" 2>/dev/null)
    rs=0; jq -e 'any(.[]; .type=="pull_request") and any(.[]; .type=="required_status_checks" and any(.parameters.required_status_checks[]; .context=="CodeQL"))' <<<"$rules" >/dev/null 2>&1 && rs=1
    gate 3 "ruleset on ${def:-main}: PR + CodeQL" "$rs" "owner runs: gh api -X POST repos/$slug/rulesets --input <skill>/templates/ruleset-main.json"
  else
    gate 3 "private vulnerability reporting on" skip "gh not signed in"
    gate 3 "ruleset on main: PR + CodeQL" skip "gh not signed in"
  fi
else
  check 10 "GitHub topics, description" skip "pass OWNER/REPO to check"
  gate 22 "Scorecard, Best Practices, reporting, ruleset" skip "pass OWNER/REPO to check the ship gates"
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
  echo; [ ${#blocked[@]} -eq 0 ] && echo "Ship gates: all met" || echo "Ship gates not met: ${#blocked[@]}"
  echo; echo "Badge: \`![skill readiness]($badge)\`"
else
  for r in "${rows[@]}"; do
    IFS='|' read -r st pts label hint <<<"$r"
    printf '%-4s %2s  %-38s %s\n' "$st" "$pts" "$label" "$hint"
  done
  echo "SCORE $score/100 ($got of $max points checked)"
  [ ${#blocked[@]} -eq 0 ] && echo "GATES all met" || echo "GATES ${#blocked[@]} not met: $(printf '%s; ' "${blocked[@]}")"
  echo "BADGE ![skill readiness]($badge)"
fi
[ $score -ge "$min" ] || { echo "score $score is below --min $min" >&2; exit 1; }
[ $ship -eq 0 ] || [ ${#blocked[@]} -eq 0 ] || { echo "--ship: ${#blocked[@]} ship gate(s) not met; do not tag" >&2; exit 1; }
