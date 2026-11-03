#!/usr/bin/env bash
# Benchmark: runs the repo's eval suite with `claude plugin eval`, once with the skill and once without (the ablation),
# N runs per case, and writes a dated `## Results (measured YYYY-MM-DD)` block: pass rate and score (mean ± sd) with vs
# without the skill, spend and time per run, and a per-case table. badges.sh --from accepts benefit numbers only from
# such a block.
# BILLED: cases x runs x 2 agent runs plus judge calls on the user's account. Without --yes it only prints the plan
# (exit 3), so the agent can ask first. --json FILE re-renders an existing aggregate-result.json for free.
# Usage: bench.sh [REPO_DIR] [--runs N] [--case GLOB] [--out FILE] [--yes | --json FILE] [-- EXTRA EVAL FLAGS]
#   e.g. bench.sh . --yes -- --scaffold --allow-tools Bash Write Edit
set -uo pipefail
repo="."; runs=3; case_glob=""; out=""; go=""; json=""; extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs="${2:?}"; shift 2 ;;
    --case) case_glob="${2:?}"; shift 2 ;;
    --out) out="${2:?}"; shift 2 ;;
    --yes) go=1; shift ;;
    --json) json="${2:?}"; shift 2 ;;
    --) shift; extra=("$@"); break ;;
    -*) echo "unknown flag $1" >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done
[ -n "$json" ] && json="$(cd "$(dirname "$json")" && pwd)/$(basename "$json")"
cd "$repo" || exit 2
command -v jq >/dev/null || { echo "jq not found" >&2; exit 2; }
today="$(date +%F)"
out="${out:-evals/bench/$today.md}"

if [ -z "$json" ]; then
  cases=0
  for d in evals/*/; do
    [ -f "$d/case.yaml" ] || [ -f "$d/prompt.md" ] || continue
    case "$(basename "$d")" in results|bench) continue ;; esac
    [ -n "$case_glob" ] && case "$(basename "$d")" in $case_glob) ;; *) continue ;; esac
    cases=$((cases + 1))
  done
  [ "$cases" -gt 0 ] || { echo "no eval cases under evals/ (see references/testing.md, section 3)" >&2; exit 2; }
  echo "cases: $cases   runs each: $runs   arms: with + without the skill"
  if [ -z "$go" ]; then
    echo "PLAN $((cases * runs * 2)) claude plugin eval agent runs (plus judge calls) on your account. Re-run with --yes once the user agrees."
    exit 3
  fi
  command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 2; }
  work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
  json="$work/result.json"
  # --trust-plugin: this is the user's own repo and they agreed to the plan above. --threshold 0: low scores are data.
  claude plugin eval "$PWD" --runs "$runs" --ablation with-without --no-publish --threshold 0 --trust-plugin \
    ${case_glob:+--case "$case_glob"} --json "$json" ${extra[@]+"${extra[@]}"} >"$work/eval.log" 2>&1
  rc=$?
  [ -s "$json" ] || { tail -20 "$work/eval.log" >&2; echo "claude plugin eval wrote no result (exit $rc)" >&2; exit 2; }
fi
jq -e '.cases | length > 0' "$json" >/dev/null 2>&1 || { echo "$json: not a plugin eval result" >&2; exit 2; }

# stats ARM: runs pass_pct score_mean score_sd cost_mean secs_mean turns_mean (tab-separated; "n/a" when the arm is absent)
stats() {
  jq -r --arg arm "$1" '
    [.cases[].arms[$arm][]?] as $r | ($r | length) as $n
    | if $n == 0 then ["0","n/a","n/a","n/a","n/a","n/a","n/a"] else
      ($r | map(.score // 0)) as $s | ($s | add / $n) as $m
      | [ $n,
          ($r | map(if .passed then 1 else 0 end) | add * 100 / $n | round),
          ($m * 100 | round / 100),
          ($s | map(pow(. - $m; 2)) | add / $n | sqrt * 100 | round / 100),
          ($r | map(.costUsd // 0) | add / $n * 1000 | round / 1000),
          ($r | map(.durationSeconds // 0) | add / $n | round),
          ($r | map(.turns // 0) | add / $n * 10 | round / 10) ] | map(tostring) end | @tsv' "$json"
}
IFS=$'\t' read -r wn wpass wmean wsd wcost wsecs wturns <<<"$(stats with)"
IFS=$'\t' read -r on opass omean osd ocost osecs oturns <<<"$(stats without)"
# change A B KIND: pts (percentage points), abs (plain difference), rel (percent change)
change() {
  [ "$1" = n/a ] || [ "$2" = n/a ] && { echo ""; return; }
  awk -v a="$1" -v b="$2" -v k="$3" 'BEGIN {
    if (k == "pts") printf "%+d pts", a - b
    else if (k == "abs") printf "%+.2f", a - b
    else if (b + 0 != 0) printf "%+d%%", (a - b) * 100 / b }'
}
ncases="$(jq '.cases | length' "$json")"
runs="$(jq -r '.cases[0].runsPerCase // empty' "$json")"; runs="${runs:-?}"
pct() { [ "$1" = n/a ] && echo n/a || echo "$1%"; }
ver="$(jq -r '.claudeVersion // "?"' "$json")"
date_run="$(jq -r '(.startedAt // "")[0:10]' "$json")"; date_run="${date_run:-$today}"

block="$(
  echo "## Results (measured $date_run)"
  echo
  echo "Method: \`bench.sh\` ran \`claude plugin eval\` on $ncases cases, $runs runs each, with the skill and without it"
  echo "(claude $ver). Score is the share of graders passed per run; a run passes when every grader passes."
  echo
  echo "| | With the skill | Without | Change |"
  echo "|---|---:|---:|---:|"
  echo "| Runs passed | $(pct "$wpass") | $(pct "$opass") | $(change "$wpass" "$opass" pts) |"
  echo "| Score (mean ± sd) | $wmean ± $wsd | $omean ± $osd | $(change "$wmean" "$omean" abs) |"
  echo "| Spend per run (USD) | $wcost | $ocost | $(change "$wcost" "$ocost" rel) |"
  echo "| Time per run (s) | $wsecs | $osecs | $(change "$wsecs" "$osecs" rel) |"
  echo "| Turns per run | $wturns | $oturns | |"
  echo
  echo "| Case | Passed with | Passed without |"
  echo "|---|---:|---:|"
  jq -r '.cases[] | "| \(.name) | \([.arms.with[]? | select(.passed)] | length)/\(.arms.with // [] | length) | \(if .arms.without then "\([.arms.without[] | select(.passed)] | length)/\(.arms.without | length)" else "n/a" end) |"' "$json"
  [ "$on" = 0 ] && { echo; echo "No without-skill arm in this result, so there is nothing to compare: re-run with the ablation."; }
)"
mkdir -p "$(dirname "$out")"
printf '%s\n' "$block" >"$out"
printf '%s\n' "$block"
echo "---"
echo "BENCH with $(pct "$wpass") vs without $(pct "$opass") runs passed ($date_run) -> $out"
echo "Paste the block into the README; badges.sh --from $out --results '#results-measured-$date_run' takes its numbers."
