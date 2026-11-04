#!/usr/bin/env bash
# OpenSSF Scorecard feedback: the live score, every check below 10 sorted by points to gain, and the fix for each.
# Read-only: one GET to the public Scorecard API. Nothing is written or stored.
# Usage: scorecard.sh OWNER/REPO
set -uo pipefail
repo="${1:?usage: scorecard.sh OWNER/REPO}"

json=$(curl -fsS "https://api.scorecard.dev/projects/github.com/$repo" 2>/dev/null) || {
  echo "No Scorecard result for $repo yet."
  echo "Fix: add .github/workflows/scorecard.yml (templates/repo/.github/workflows/), push to main, wait for the run."
  exit 1
}

hint() {
  case "$1" in
    Code-Review) echo "merge every change through a PR that someone else approves; solo: ask a collaborator to review, or accept this one" ;;
    Branch-Protection) echo "owner runs: gh api -X POST repos/$repo/rulesets --input templates/ruleset-main.json (ruleset 'Protect main': PR, 1 review, CodeQL required, no force push or delete)" ;;
    CII-Best-Practices) echo "register at bestpractices.dev and reach passing: run scripts/bestpractices.sh $repo" ;;
    Signed-Releases) echo "tag a release (git tag vX.Y.Z && git push --tags) so the SLSA release workflow signs it" ;;
    Packaging) echo "publish a GitHub release from a workflow (the release workflow does it on a tag)" ;;
    Pinned-Dependencies) echo "pin every action and container to a full commit SHA; run lint_skill.sh to find unpinned uses (the SLSA generator must stay on a tag: accept that one)" ;;
    Token-Permissions) echo "put 'permissions: read-all' at the top of every workflow; grant write per job only" ;;
    Dependency-Update-Tool) echo "add .github/dependabot.yml (github-actions ecosystem)" ;;
    Security-Policy) echo "add SECURITY.md with a private reporting path, and turn that path on (owner runs): gh api -X PUT repos/$repo/private-vulnerability-reporting" ;;
    SAST) echo "add the CodeQL workflow and let it run on every PR" ;;
    Dangerous-Workflow) echo "no pull_request_target with checkout of PR code; no untrusted \${{ github.event.* }} in run: lines" ;;
    Binary-Artifacts) echo "remove committed binaries (.exe, .jar, .so...) or build them in CI" ;;
    Vulnerabilities) echo "update the dependencies named in the reason (OSV)" ;;
    Fuzzing) echo "usually not applicable to a skill repo; accept it unless the scripts parse untrusted input" ;;
    Maintained) echo "comes on its own: needs a repo older than 90 days with recent commits" ;;
    Contributors) echo "comes with outside contributors from several organizations; cannot be forced" ;;
    CI-Tests) echo "run tests or the linter in CI on every PR" ;;
    License) echo "add a LICENSE file at the repo root" ;;
    *) echo "see https://github.com/ossf/scorecard/blob/main/docs/checks.md" ;;
  esac
}

jq -r '"Scorecard \(.score)/10 for \(.repo.name) (scanned \(.date[:10]))"' <<<"$json"
# Ship bar: a release needs 7.3 or more (readiness.sh --ship enforces it).
jq -r 'if .score >= 7.3 then "Ship bar 7.3: met" else "Ship bar 7.3: NOT met, \((7.3 - .score) * 10 | round / 10) to go; fix the top rows below" end' <<<"$json"
# Checks that only time or outside people can move go last.
later() { case "$1" in Maintained|Contributors|Fuzzing) echo 1 ;; *) echo 0 ;; esac; }
echo "gain  check                  reason -> fix   (fixable now first)"
jq -r '.checks[] | select(.score >= 0 and .score < 10) | "\(10 - .score)\t\(.name)\t\(.reason)"' <<<"$json" |
  while IFS=$'\t' read -r gain name reason; do printf '%s\t%s\t%s\t%s\n' "$(later "$name")" "$gain" "$name" "$reason"; done |
  sort -t$'\t' -k1,1n -k2,2nr | while IFS=$'\t' read -r _ gain name reason; do
    printf '+%-4s %-22s %s\n      -> %s\n' "$gain" "$name" "$reason" "$(hint "$name")"
    jq -r --arg n "$name" '.checks[] | select(.name == $n) | .details[]? | select(startswith("Warn"))' <<<"$json" | head -3 | sed 's/^/      /'
  done
na=$(jq -r '[.checks[] | select(.score < 0) | .name] | join(", ")' <<<"$json")
[ -n "$na" ] && echo "not scored yet: $na (usually needs a release)"
echo "Viewer: https://scorecard.dev/viewer/?uri=github.com/$repo"
# Profile tables: the default badge is too small to read in a narrow column; use the short live one.
echo "Profile badge: [![OpenSSF](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.securityscorecards.dev%2Fprojects%2Fgithub.com%2F${repo%%/*}%2F${repo#*/}&query=%24.score&label=OpenSSF&color=2da44e)](https://scorecard.dev/viewer/?uri=github.com/$repo)"
echo "Badge: [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/$repo/badge)](https://scorecard.dev/viewer/?uri=github.com/$repo)"
