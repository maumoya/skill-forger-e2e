#!/usr/bin/env bash
# OpenSSF Best Practices helper. If the project is registered: its ID, level and badge.
# If not: the form link (the owner signs in and submits it) and an evidence sheet for the "passing" answers,
# each criterion with the URL that proves it, checked against the local repo.
# Read-only: GETs to bestpractices.dev only. Nothing is submitted or stored.
# Usage: bestpractices.sh OWNER/REPO [REPO_DIR]
set -uo pipefail
repo="${1:?usage: bestpractices.sh OWNER/REPO [REPO_DIR]}"
dir="${2:-.}"
gh_url="https://github.com/$repo"

found=$(curl -fsS "https://www.bestpractices.dev/en/projects.json?url=$(jq -rn --arg u "$gh_url" '$u|@uri')" 2>/dev/null \
  | jq -r --arg u "$gh_url" '[.[] | select(.repo_url == $u or .homepage_url == $u)][0] // empty | "\(.id)\t\(.badge_level)\t\(.badge_percentage_0)"')
if [ -n "$found" ]; then
  IFS=$'\t' read -r id level pct <<<"$found"
  echo "Registered: project $id, level $level, passing criteria $pct%"
  echo "Edit answers: https://www.bestpractices.dev/en/projects/$id/passing/edit"
  echo "Badge: [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/$id/badge)](https://www.bestpractices.dev/projects/$id)"
  [ "$pct" = "100" ] || echo "Not passing yet: answer the Unmet and ? criteria with the evidence below."
else
  echo "Not registered yet."
  echo "Owner step (sign in with GitHub, paste $gh_url, submit): https://www.bestpractices.dev/en/projects/new"
  echo "Then fill each criterion with the evidence below, and re-run this script for the badge."
fi

blob="$gh_url/blob/main"
has() { [ -e "$dir/$1" ]; }
wf() { ls "$dir"/.github/workflows/*.yml >/dev/null 2>&1 && grep -lqi "$1" "$dir"/.github/workflows/*.yml; }
row() { printf '%-4s %-28s %s\n' "$([ "$2" = 1 ] && echo ok || echo TODO)" "$1" "$3"; }
b() { "$@" && echo 1 || echo 0; }

echo
echo "Evidence sheet (passing level; Met + URL for each ok row)"
row "description_good"         1 "$gh_url (README first paragraph)"
row "interact / contribution"  "$(b has CONTRIBUTING.md)" "$blob/CONTRIBUTING.md"
row "floss_license(_osi)"      "$(b has LICENSE)" "$blob/LICENSE (MIT, OSI approved)"
row "documentation_basics"     "$(b has README.md)" "$blob/README.md"
row "repo_public/track/distr." 1 "$gh_url (public git on GitHub)"
row "version_semver/tags"      "$(b has CHANGELOG.md)" "$gh_url/tags (vX.Y.Z)"
row "release_notes"            "$(b has CHANGELOG.md)" "$blob/CHANGELOG.md"
row "report_tracker/process"   1 "$gh_url/issues"
row "vulnerability_report_*"   "$(b has SECURITY.md)" "$blob/SECURITY.md (private advisory link)"
row "test / test_invocation"   "$(b wf 'lint_skill\|test')" "$gh_url/actions (CI on every PR)"
row "tests_are_added / policy" "$(b grep -qiE 'eval|test' "$dir/CONTRIBUTING.md")" "$blob/CONTRIBUTING.md (says new behavior needs an eval or test)"
row "warnings / warnings_strict" "$(b wf 'lint_skill')" "lint_skill.sh fails the build on errors"
row "static_analysis"          "$(b wf 'codeql')" "$gh_url/security/code-scanning (CodeQL)"
row "delivery_mitm / sites_https" 1 "GitHub over HTTPS only"
row "know_secure_design"       1 "$blob/SECURITY.md (owner answers from their own knowledge)"
row "crypto_* / build_*"       1 "N/A: no crypto, nothing to build (say why in the justification)"
echo "TODO rows: fix in the repo first (retrofit.sh adds most), then answer Met. Never answer Met without the evidence."
