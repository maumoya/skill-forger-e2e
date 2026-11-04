#!/usr/bin/env bash
# Marketplace readiness for a repo that ships an action.yml. Read-only.
# Offline: the action.yml rules from lint_skill.sh (name, description < 125 chars, quoting, branding).
# Online (with OWNER/REPO, needs gh): repo public, listing name free or already ours,
# the latest release tag carries the same action.yml as this checkout (the Marketplace reads the tag),
# and that tag is signed and Verified. --listed also requires the listing page to be live.
# Prints FAIL/WARN/OK lines, then PASS or the failure count. Exit 1 on any FAIL.
# Usage: marketplace_check.sh [REPO_DIR] [OWNER/REPO] [--listed]
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo_dir="."; slug_repo=""; listed=0
for a in "$@"; do
  case "$a" in
    --listed) listed=1 ;;
    */*) if [ -d "$a" ]; then repo_dir="$a"; else slug_repo="$a"; fi ;;
    *) repo_dir="$a" ;;
  esac
done
cd "$repo_dir" || { echo "no such dir: $repo_dir" >&2; exit 2; }
fails=0; warns=0
fail() { echo "FAIL $*"; fails=$((fails+1)); }
warn() { echo "WARN $*"; warns=$((warns+1)); }
ok() { echo "OK   $*"; }

af=""; for f in action.yml action.yaml; do [ -f "$f" ] && { af="$f"; break; }; done
[ -n "$af" ] || { echo "FAIL no action.yml or action.yaml at the root: nothing to list"; exit 1; }

# --- offline: reuse the linter's action.yml section so the rules live in one place
while IFS= read -r line; do
  case "$line" in FAIL*) echo "$line"; fails=$((fails+1)) ;; WARN*) echo "$line"; warns=$((warns+1)) ;; esac
done < <(bash "$here/lint_skill.sh" . | grep -E '^(FAIL|WARN) (action\.ya?ml|both action|action file)')
[ "$fails" -eq 0 ] && ok "$af: name, description, branding and runs pass the Marketplace rules"

# --- the action is tested in CI: one passing `uses: ./` run and one failing run asserted as failure
shopt -s nullglob; wfs=(.github/workflows/*.yml .github/workflows/*.yaml)
if [ ${#wfs[@]} -gt 0 ] && grep -lqE '^\s*-?\s*uses:\s*\./?\s*$' "${wfs[@]}" && grep -lqE '= failure|== .failure.' "${wfs[@]}"; then
  ok "CI self-tests the action (uses: ./ and a run asserted as failure)"
else
  fail "CI does not self-test the action: add a 'uses: ./' job on a passing input and one asserted as failure"
fi
# --- one version everywhere: plugin.json, CHANGELOG, README and llms.txt @vX.Y.Z examples
v=$(jq -r '.version // empty' .claude-plugin/plugin.json 2>/dev/null)
if [ -n "$v" ]; then
  grep -qE "^## \[?v?${v//./\\.}\]?( |$)" CHANGELOG.md 2>/dev/null || fail "CHANGELOG.md has no '## $v' entry (bump it with plugin.json)"
  stale=$(grep -ohE '@v[0-9]+\.[0-9]+\.[0-9]+' README.md llms.txt 2>/dev/null | sort -u | grep -vxF "@v$v" | tr '\n' ' ')
  [ -z "$stale" ] || fail "README/llms.txt pin $stale but plugin.json is $v"
fi

# --- online
if [ -n "$slug_repo" ]; then
  command -v gh >/dev/null || { fail "gh not installed (needed for the online checks)"; slug_repo=""; }
fi
if [ -n "$slug_repo" ]; then
  vis=$(gh api "repos/$slug_repo" -q .visibility 2>/dev/null)
  if [ "$vis" = "public" ]; then ok "repo is public"; else fail "repo visibility is '${vis:-unknown}' (the Marketplace lists public repos only)"; fi

  name=$(sed -nE 's/^name: *//p' "$af" | head -1 | sed -E "s/^[\"'](.*)[\"']\$/\\1/")
  slug=$(tr '[:upper:]' '[:lower:]' <<<"$name" | sed -E 's/[^a-z0-9]+/-/g; s/^-+|-+$//g')
  url="https://github.com/marketplace/actions/$slug"
  page=$(curl -sL --max-time 20 -w '\n%{http_code}' "$url"); code="${page##*$'\n'}"
  if [ "$code" = "404" ]; then
    if [ "$listed" -eq 1 ]; then fail "not listed yet: $url is 404"; else ok "listing name '$slug' is free"; fi
  elif [ "$code" = "200" ] && grep -qi "$slug_repo" <<<"$page"; then
    ok "listed: $url"
  elif [ "$code" = "200" ]; then
    fail "the name '$name' is taken by another action ($url); rename it in $af"
  else
    warn "could not read $url (HTTP $code)"
  fi

  tag=$(gh api "repos/$slug_repo/releases/latest" -q .tag_name 2>/dev/null)
  if [ -z "$tag" ]; then
    warn "no release yet: the listing is created from a release (see references/packaging.md)"
  else
    remote=$(gh api "repos/$slug_repo/contents/$af?ref=$tag" -q .content 2>/dev/null | base64 -d 2>/dev/null)
    if [ -z "$remote" ]; then fail "$tag has no $af (the Marketplace reads the tag)"
    elif [ "$remote" = "$(cat "$af")" ]; then ok "$tag carries this $af"
    else warn "$tag carries a different $af than this checkout: a fix only reaches the Marketplace with a new release"; fi

    obj=$(gh api "repos/$slug_repo/git/ref/tags/$tag" -q '.object.type+" "+.object.sha' 2>/dev/null)
    if [ "${obj%% *}" = "tag" ]; then
      v=$(gh api "repos/$slug_repo/git/tags/${obj#* }" -q .verification.verified 2>/dev/null)
      if [ "$v" = "true" ]; then ok "$tag is signed and Verified"; else fail "$tag is signed but not Verified on GitHub (add the key as a signing key)"; fi
    else
      warn "$tag is a lightweight tag (sign it: git tag -s)"
    fi
  fi
fi

if [ "$fails" -eq 0 ]; then echo "PASS ($warns warnings)"; exit 0; fi
echo "$fails FAIL, $warns WARN"; exit 1
