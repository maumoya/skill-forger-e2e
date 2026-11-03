#!/usr/bin/env bash
# Measured trigger test: runs every query in evals/triggers.json through `claude -p` with the repo's plugin loaded,
# several times each, and reports recall (should-trigger queries that loaded the skill), the false-trigger rate
# (should-not queries that loaded it), and both again for the holdout queries alone.
# BILLED: runs x queries short `claude -p` runs on the user's account. Without --yes it only prints the plan and the
# run count (exit 3), so the agent can ask first.
# Usage: trigger_test.sh [REPO_DIR] [--runs N] [--yes] [--min-recall 0.8] [--max-false 0.2]
set -uo pipefail
repo="."; runs=3; go=""; min_recall=0.8; max_false=0.2
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs="${2:?}"; shift 2 ;;
    --yes) go=1; shift ;;
    --min-recall) min_recall="${2:?}"; shift 2 ;;
    --max-false) max_false="${2:?}"; shift 2 ;;
    -*) echo "unknown flag $1" >&2; exit 2 ;;
    *) repo="$1"; shift ;;
  esac
done
cd "$repo" || exit 2
command -v jq >/dev/null || { echo "jq not found" >&2; exit 2; }
tf=evals/triggers.json
[ -f "$tf" ] || { echo "no $tf (see references/testing.md, section 2)" >&2; exit 2; }
jq -e '.skill and (.queries | length > 0)' "$tf" >/dev/null 2>&1 || { echo "$tf: needs .skill and .queries" >&2; exit 2; }
skill="$(jq -r .skill "$tf")"
n="$(jq '.queries | length' "$tf")"
total=$((n * runs))

echo "skill: $skill   queries: $n ($(jq '[.queries[] | select(.trigger)] | length' "$tf") should, $(jq '[.queries[] | select(.trigger | not)] | length' "$tf") should not, $(jq '[.queries[] | select(.holdout)] | length' "$tf") holdout)   runs each: $runs"
if [ -z "$go" ]; then
  echo "PLAN $total short claude -p runs (max 2 turns each) on your account. Re-run with --yes once the user agrees."
  exit 3
fi
command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 2; }
claude plugin list 2>/dev/null | grep -q "$skill" && echo "note: $skill is also installed in your own config, so a load may come from there"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
results="$work/results.tsv"   # trigger  holdout  hits  text
: >"$results"
for i in $(seq 0 $((n - 1))); do
  q="$(jq -r ".queries[$i].text" "$tf")"
  want="$(jq -r ".queries[$i].trigger" "$tf")"
  hold="$(jq -r ".queries[$i].holdout // false" "$tf")"
  hits=0
  for r in $(seq 1 "$runs"); do
    out="$work/q$i-r$r.json"
    claude -p "$q" --plugin-dir "$PWD" --output-format stream-json --verbose \
      --max-turns 2 --allowed-tools Skill >"$out" 2>/dev/null || true
    jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill // .input.command // empty' "$out" 2>/dev/null \
      | grep -q "$skill" && hits=$((hits + 1))
  done
  printf '%s\t%s\t%s\t%s\n' "$want" "$hold" "$hits" "$q" >>"$results"
  if [ "$want" = true ]; then mark=$([ $hits -eq "$runs" ] && echo ok || echo MISS)
  else mark=$([ $hits -eq 0 ] && echo ok || echo FALSE); fi
  printf '%-5s %s/%s  %s%s\n' "$mark" "$hits" "$runs" "$([ "$hold" = true ] && echo '[holdout] ')" "$q"
done

# rate SET WANT: share of runs that loaded the skill, over queries with trigger=WANT in SET (all|train|holdout)
rate() {
  awk -F'\t' -v set="$1" -v want="$2" -v runs="$runs" '
    $1==want && (set=="all" || (set=="holdout") == ($2=="true")) { h+=$3; t+=runs }
    END { if (t) printf "%.2f", h/t; else printf "n/a" }' "$results"
}
echo "---"
for set in all train holdout; do
  echo "$set: recall $(rate $set true)   false-trigger rate $(rate $set false)"
done
recall="$(rate all true)"; false_rate="$(rate all false)"
echo "TRIGGERS recall $recall, false $false_rate over $total runs ($(date +%F))"
awk -v r="$recall" -v f="$false_rate" -v mr="$min_recall" -v mf="$max_false" \
  'BEGIN { exit !((r=="n/a" || r+0>=mr+0) && (f=="n/a" || f+0<=mf+0)) }' \
  || { echo "below target (recall >= $min_recall, false <= $max_false): fix the description using the train queries only, then re-run" >&2; exit 1; }
