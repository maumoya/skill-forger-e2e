#!/usr/bin/env bash
# Keyless lint for a skill repo: frontmatter, plugin JSON, eval layout, workflow pinning, risky patterns.
# Read-only. Prints FAIL/WARN lines, then PASS or the failure count. Exit 1 on any FAIL.
# Usage: lint_skill.sh [REPO_DIR]
set -uo pipefail
repo="${1:-.}"
cd "$repo" || { echo "no such dir: $repo" >&2; exit 2; }
fails=0; warns=0
fail() { echo "FAIL $*"; fails=$((fails+1)); }
warn() { echo "WARN $*"; warns=$((warns+1)); }

# frontmatter value of KEY in FILE (single line values)
fm() { awk -v k="$2" 'NR==1&&$0!="---"{exit} NR>1&&$0=="---"{exit} NR>1{ if (index($0, k": ")==1) { sub("^" k ": *", ""); print; exit } }' "$1"; }

# --- skills
shopt -s nullglob
skill_files=(skills/*/SKILL.md)
[ ${#skill_files[@]} -gt 0 ] || fail "no skills/<name>/SKILL.md found"
for f in "${skill_files[@]}"; do
  dir="$(basename "$(dirname "$f")")"
  [ "$(head -1 "$f")" = "---" ] || { fail "$f: no frontmatter (first line must be ---)"; continue; }
  name="$(fm "$f" name)"; desc="$(fm "$f" description)"
  [ -n "$name" ] || fail "$f: frontmatter has no name"
  [ "$name" = "$dir" ] || fail "$f: name '$name' does not match folder '$dir'"
  [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || fail "$f: name must be lowercase letters, digits, hyphens"
  [ ${#name} -le 64 ] || fail "$f: name longer than 64 chars"
  [[ "$name" == *claude* || "$name" == *anthropic* ]] && fail "$f: name must not contain claude or anthropic"
  [ -n "$desc" ] || fail "$f: frontmatter has no description"
  [ ${#desc} -le 1024 ] || fail "$f: description is ${#desc} chars (max 1024)"
  grep -qiE 'use (it )?when|when the user|trigger' <<<"$desc" || warn "$f: description does not say when to use it"
  body=$(awk 'c>=2{n++} /^---$/{c++} END{print n+0}' "$f")
  [ "$body" -le 500 ] || warn "$f: body is $body lines (keep under 500; move detail to references/)"
  grep -qE 'REPLACE|TRIGGER (ONE|TWO|THREE)|__[A-Z]+__' "$f" && warn "$f: template placeholders left"
  # links to this skill's own references/ and scripts/ must exist (./scripts/… is a user-project path, skipped)
  for ref in $(grep -oE '(^|[^./A-Za-z0-9_-])(references|scripts)/[A-Za-z0-9_.-]+' "$f" | sed -E 's/^[^rs]//' | sort -u); do
    [ -e "$(dirname "$f")/$ref" ] || fail "$f: links $ref but it does not exist"
  done
done

# --- plugin JSON
for j in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
  if [ ! -f "$j" ]; then warn "$j missing (needed for /plugin install)"; continue; fi
  jq empty "$j" 2>/dev/null || fail "$j is not valid JSON"
done
if [ -f .claude-plugin/plugin.json ] && [ -f .claude-plugin/marketplace.json ]; then
  pn=$(jq -r .name .claude-plugin/plugin.json 2>/dev/null)
  jq -e --arg n "$pn" '.plugins | any(.name == $n)' .claude-plugin/marketplace.json >/dev/null 2>&1 \
    || fail "marketplace.json has no plugin named '$pn'"
fi
if [ -f .claude-plugin/plugin.json ]; then
  jq -r .version .claude-plugin/plugin.json 2>/dev/null | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' || fail "plugin.json version is not X.Y.Z"
fi

# --- evals
if [ -d evals ]; then
  for c in evals/*/; do
    c="${c%/}"; cn="$(basename "$c")"
    [ -f "$c/case.yaml" ] || { fail "$c: no case.yaml"; continue; }
    grep -q '^schema_version:' "$c/case.yaml" || fail "$c/case.yaml: no schema_version"
    grep -qE "^name: *\"?$cn\"?$" "$c/case.yaml" || fail "$c/case.yaml: name must equal folder '$cn'"
    grep -q '^expected_outcome:' "$c/case.yaml" || fail "$c/case.yaml: no expected_outcome"
    [ -f "$c/prompt.md" ] || fail "$c: no prompt.md"
    g=("$c"/graders/*.md); [ ${#g[@]} -gt 0 ] || fail "$c: no graders/*.md"
    for gf in "${g[@]}"; do grep -q '^type:' "$gf" || fail "$gf: no type in frontmatter"; done
    s=$(sed -nE 's/^ *scaffold_script: *//p' "$c/case.yaml")
    [ -z "$s" ] || [ -f "$c/$s" ] || fail "$c: scaffold_script '$s' does not exist"
    grep -rl 'REPLACE' "$c" >/dev/null && warn "$c: template placeholders left"
  done
else
  warn "no evals/ folder (one case per promise, see references/testing.md)"
fi

# --- workflows
for w in .github/workflows/*.yml .github/workflows/*.yaml; do
  grep -qE '^permissions:' "$w" || fail "$w: no top-level permissions (use read-all)"
  while IFS= read -r line; do
    ref="${line##*@}"; ref="${ref%% *}"
    [[ "$line" == *slsa-framework/slsa-github-generator* ]] && continue
    [[ "$ref" =~ ^[0-9a-f]{40}$ ]] || fail "$w: action not pinned to a commit SHA: $(xargs <<<"$line")"
  done < <(grep -E '^[[:space:]]*-?[[:space:]]*uses:[[:space:]]*[^./[:space:]]' "$w")  # local ./ actions need no pin
done

# --- risky patterns (skill files and scripts)
scan=(); for d in skills scripts; do [ -d "$d" ] && scan+=("$d"); done
if [ ${#scan[@]} -gt 0 ]; then
  hits=$(grep -rnE '(curl|wget)[^|#]*\|\s*(sudo\s+)?(ba|z)?sh\b' "${scan[@]}")
  [ -z "$hits" ] || { sed 's/^/FAIL pipe-to-shell: /' <<<"$hits"; fails=$((fails+1)); }
  hits=$(grep -rnE '(sk-ant-|sk-)[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{30,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY' "${scan[@]}")
  [ -z "$hits" ] || { sed 's/^/FAIL secret-like string: /' <<<"$hits"; fails=$((fails+1)); }
  hits=$(grep -rnE '/(Users|home)/[a-z][a-z0-9_-]+/' "${scan[@]}")
  [ -z "$hits" ] || { sed 's/^/WARN personal absolute path: /' <<<"$hits"; warns=$((warns+1)); }
fi

for f in README.md LICENSE SECURITY.md; do [ -f "$f" ] || warn "$f missing"; done

if [ "$fails" -eq 0 ]; then echo "PASS ($warns warnings)"; exit 0; fi
echo "$fails FAIL, $warns WARN"; exit 1
