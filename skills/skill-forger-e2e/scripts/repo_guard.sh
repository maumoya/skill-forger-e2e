#!/usr/bin/env bash
# Repo guard: the GitHub-side settings every skill repo needs, checked on every run (new skill, retrofit or a
# small improvement PR). Lists what is missing; with --apply it fixes what one API call can fix.
# Checks: ruleset on the default branch (PR + CodeQL), the CodeQL check name the ruleset waits for exists,
# private vulnerability reporting, description, 5+ topics, a release, and an action.yml that is not listed yet.
# Usage: repo_guard.sh OWNER/REPO [repo-dir] [--apply]
# --apply writes two repo settings (ruleset, reporting). Everything else is printed as the next command.
set -uo pipefail
slug="${1:?usage: repo_guard.sh OWNER/REPO [repo-dir] [--apply]}"; shift
dir="."; apply=0
for a in "$@"; do case "$a" in --apply) apply=1 ;; *) dir="$a" ;; esac; done
here="$(cd "$(dirname "$0")/.." && pwd)"
command -v gh >/dev/null && gh auth status >/dev/null 2>&1 || { echo "gh is not signed in: cannot check $slug"; exit 2; }
miss=0
ok()  { echo "OK   $1"; }
bad() { echo "MISS $1"; echo "     fix: $2"; miss=$((miss+1)); }

def=$(gh api "repos/$slug" -q .default_branch 2>/dev/null) || { echo "cannot read $slug"; exit 2; }
has_ruleset() {
  gh api "repos/$slug/rules/branches/$def" 2>/dev/null | jq -e 'any(.[]; .type=="pull_request") and any(.[]; .type=="required_status_checks" and any(.parameters.required_status_checks[]; .context=="CodeQL"))' >/dev/null 2>&1
}
# A ruleset that waits for a check nobody posts blocks every merge: the CodeQL job must be named "CodeQL".
codeql_named=0
grep -lqsE '^[[:space:]]+name:[[:space:]]*CodeQL[[:space:]]*$' "$dir"/.github/workflows/*.yml 2>/dev/null && codeql_named=1
if [ "$codeql_named" = 1 ]; then ok "a workflow job is named CodeQL (the check the ruleset requires)"
else bad "no workflow job is named CodeQL" "add 'name: CodeQL' to the analyze job in .github/workflows/codeql.yml and merge it BEFORE adding the ruleset"; fi

if has_ruleset; then ok "ruleset on $def: PR + CodeQL"
elif [ "$apply" = 1 ] && [ "$codeql_named" = 1 ]; then
  gh api -X POST "repos/$slug/rulesets" --input "$here/templates/ruleset-main.json" >/dev/null 2>&1 && has_ruleset \
    && ok "ruleset on $def: added" || bad "ruleset on $def: could not add" "gh api -X POST repos/$slug/rulesets --input $here/templates/ruleset-main.json"
else bad "$def is not protected (no ruleset with PR + CodeQL)" "repo_guard.sh $slug $dir --apply"; fi

pvr() { [ "$(gh api "repos/$slug/private-vulnerability-reporting" -q .enabled 2>/dev/null)" = "true" ]; }
if pvr; then ok "private vulnerability reporting on"
elif [ "$apply" = 1 ]; then
  gh api -X PUT "repos/$slug/private-vulnerability-reporting" >/dev/null 2>&1 && pvr \
    && ok "private vulnerability reporting: turned on" || bad "private vulnerability reporting: could not turn on" "gh api -X PUT repos/$slug/private-vulnerability-reporting"
else bad "private vulnerability reporting is off" "repo_guard.sh $slug $dir --apply"; fi

meta=$(gh api "repos/$slug" 2>/dev/null)
[ -n "$(jq -r '.description // ""' <<<"$meta")" ] && ok "description set" \
  || bad "no repo description" "gh repo edit $slug --description \"<what + who, 350 chars or less>\""
nt=$(jq -r '.topics | length' <<<"$meta" 2>/dev/null || echo 0)
[ "${nt:-0}" -ge 5 ] && ok "$nt topics" || bad "only ${nt:-0} topics (need 5+)" "gh repo edit $slug --add-topic a,b,c,d,e"

tag=$(gh release view -R "$slug" --json tagName -q .tagName 2>/dev/null || true)
if [ -n "$tag" ]; then ok "latest release $tag"
else bad "no release yet" "bump the version in one PR, merge, then: git tag -s vX.Y.Z -m vX.Y.Z && git push origin vX.Y.Z"; fi

if [ -f "$dir/action.yml" ] || [ -f "$dir/action.yaml" ]; then
  if [ -n "$tag" ] && bash "$here/scripts/marketplace_check.sh" "$dir" "$slug" --listed >/dev/null 2>&1; then ok "action listed on the GitHub Marketplace"
  else bad "action.yml is not listed on the GitHub Marketplace" "marketplace_check.sh $dir $slug, then publish from the release (references/packaging.md), then --listed"; fi
fi

if [ "$miss" -eq 0 ]; then echo "PASS repo guard: nothing missing"; exit 0; fi
echo "FAIL repo guard: $miss missing. Close them in this session; they are not follow-ups."; exit 1
