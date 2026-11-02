#!/usr/bin/env bash
# Prints the centered badge row for a skill README, from live data only.
# Scorecard appears once it has a result; Best Practices once the project is registered.
# Benefit badges ("spend per run=−35%") must come from a measured, dated Results section: pass its anchor.
# Read-only: GETs to the Scorecard and Best Practices APIs. Prints HTML; writes nothing.
# Usage: badges.sh OWNER/REPO [--readiness N] [--license MIT] [--results '#results-measured-2026-11-01']
#                  [--benefit 'label=value'] ... [--benefit-alt 'Alt text for the last benefit']
set -uo pipefail
repo="${1:?usage: badges.sh OWNER/REPO [--readiness N] [--benefit 'label=value'] [--results '#anchor']}"; shift
readiness="" license="MIT" results="" benefits=() alts=()
while [ $# -gt 0 ]; do
  case "$1" in
    --readiness) readiness="$2"; shift 2 ;;
    --license) license="$2"; shift 2 ;;
    --results) results="$2"; shift 2 ;;
    --benefit) benefits+=("$2"); alts+=(""); shift 2 ;;
    --benefit-alt) alts[${#alts[@]}-1]="$2"; shift 2 ;;
    *) echo "unknown option $1" >&2; exit 2 ;;
  esac
done
if [ ${#benefits[@]} -gt 0 ] && [ -z "$results" ]; then
  echo "Benefit badges need --results '#anchor' pointing at the measured, dated Results section." >&2; exit 2
fi

# shields.io static badge escaping: '-' -> '--', '_' -> '__', then URL-encode.
enc() { jq -rn --arg s "$1" '$s | gsub("-"; "--") | gsub("_"; "__") | @uri'; }
badge() { echo "https://img.shields.io/badge/$(enc "$1")-$(enc "$2")-$3"; }
img() { printf '<img src="%s" alt="%s">' "$1" "$2"; }
link() { printf '  <a href="%s">%s</a>\n' "$1" "$2"; }

echo '<p align="center">'
echo "  $(img "$(badge 'Claude Code' 'skill + plugin' 7c5cfc)" 'Claude Code skill and plugin')"
for i in "${!benefits[@]}"; do
  label="${benefits[$i]%%=*}" value="${benefits[$i]#*=}"
  alt="${alts[$i]:-$label: $value}"
  link "$results" "$(img "$(badge "$label" "$value" 2da44e)" "$alt")"
done
[ -n "$readiness" ] && link "#score-any-skill-repo-0-100" "$(img "$(badge 'skill readiness' "$readiness/100" brightgreen)" "Skill readiness: $readiness/100")"
echo "  $(img "$(badge license "$license" blue)" "$license license")"
case "$license" in
  MIT|Apache-2.0|BSD-3-Clause|BSD-2-Clause|MPL-2.0|GPL-3.0|LGPL-3.0|ISC)
    link "https://opensource.org/license/$(tr '[:upper:]' '[:lower:]' <<<"$license")" \
      "$(img "https://img.shields.io/badge/Open%20Source-OSI%20approved%20license-3DA639?logo=opensourceinitiative&logoColor=white" "Open Source: OSI-approved $license license")" ;;
esac
echo "  $(img "$(badge privacy 'no tracking · no data collected' 7c5cfc)" 'Privacy: no tracking, no data collected')"
if curl -fsS -o /dev/null "https://api.scorecard.dev/projects/github.com/$repo" 2>/dev/null; then
  link "https://scorecard.dev/viewer/?uri=github.com/$repo" "$(img "https://api.scorecard.dev/projects/github.com/$repo/badge" 'OpenSSF Scorecard')"
else
  echo "  <!-- OpenSSF Scorecard: no result yet; add the scorecard workflow and re-run -->"
fi
gh_url="https://github.com/$repo"
bp=$(curl -fsS "https://www.bestpractices.dev/en/projects.json?url=$(jq -rn --arg u "$gh_url" '$u|@uri')" 2>/dev/null \
  | jq -r --arg u "$gh_url" '[.[] | select(.repo_url == $u or .homepage_url == $u)][0].id // empty')
if [ -n "$bp" ]; then
  link "https://www.bestpractices.dev/projects/$bp" "$(img "https://www.bestpractices.dev/projects/$bp/badge" 'OpenSSF Best Practices')"
else
  echo "  <!-- OpenSSF Best Practices: not registered; run bestpractices.sh $repo -->"
fi
echo '</p>'
