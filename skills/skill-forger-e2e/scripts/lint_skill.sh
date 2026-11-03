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
  # a description that narrates the steps lets the model act on it and skip the body
  steps=$(grep -oiwE 'then|first|finally|afterwards|step [0-9]+|phase [0-9]+' <<<"$desc" | wc -l | tr -d ' ')
  [ "$steps" -lt 2 ] || warn "$f: description reads like a workflow ($steps step words); say what and when, keep the steps in the body"
  grep -qE '^(I|I'"'"'m|We|You) |(^|[^A-Za-z])(I can|you can|we can)([^A-Za-z]|$)' <<<"$desc" \
    && warn "$f: description is not in the third person"
  # Agent Skills spec fields (agentskills.io/specification)
  compat="$(fm "$f" compatibility)"
  [ ${#compat} -le 500 ] || fail "$f: compatibility is ${#compat} chars (max 500)"
  fmk=$(awk 'NR==1{next} /^---$/{exit} /^[A-Za-z_-]+:/{sub(/:.*/, ""); print}' "$f")
  for k in $fmk; do
    case "$k" in
      name|description|license|compatibility|metadata|allowed-tools) ;;  # in the spec
      argument-hint|disable-model-invocation|user-invocable|model|effort|context|agent|hooks|paths|shell|when_to_use|version) ;;  # Claude Code extras
      *) warn "$f: frontmatter key '$k' is not in the Agent Skills spec (other agents ignore it; put custom keys under metadata:)" ;;
    esac
  done
  if grep -q '^metadata:' "$f"; then
    meta=$(awk 'NR==1{next} /^---$/{exit}
      /^metadata:/ { m=1; v=$0; sub(/^metadata: */, "", v); if (v != "" && v != "{}") print "inline"; next }
      m && /^[^ ]/ { m=0 }
      m && /^ +- / { print "list"; next }
      m && /^ +[^ :]+: *$/ { print "nested"; next }
      m && /^ +[^ :]+: +[0-9.]+ *$/ { print "number"; next }' "$f" | sort -u)
    for bad in $meta; do
      case "$bad" in
        number) warn "$f: metadata has an unquoted number; quote it, the spec wants string values" ;;
        *) fail "$f: metadata must be a map of key: \"string\" pairs ($bad value found)" ;;
      esac
    done
  fi
  if grep -q '^allowed-tools: *$' "$f"; then
    warn "$f: allowed-tools is a YAML list; the spec wants one space-separated string (Read Bash(git:*))"
  fi
  body=$(awk 'c>=2{n++} /^---$/{c++} END{print n+0}' "$f")
  [ "$body" -le 500 ] || warn "$f: body is $body lines (keep under 500; move detail to references/)"
  btok=$(( $(awk 'c>=2{print} /^---$/{c++}' "$f" | wc -c) / 4 ))
  [ "$btok" -le 5000 ] || warn "$f: body is about $btok tokens (the spec recommends under 5000; move detail to references/)"
  # references stay one level deep: a reference that links another reference is a chain
  for r in "$(dirname "$f")"/references/*.md; do
    for l in $(grep -oE '\]\([^)#: ]+\.md' "$r" | sed 's/^](//' | sort -u); do
      [ -e "$(dirname "$r")/$l" ] || [ -e "$(dirname "$f")/$l" ] || continue
      warn "$r links $l; keep references one level deep (link it from SKILL.md instead)"
    done
  done
  grep -qE 'REPLACE|TRIGGER (ONE|TWO|THREE)|__[A-Z]+__' "$f" && warn "$f: template placeholders left"
  # links to this skill's own references/ and scripts/ must exist (./scripts/… is a user-project path, skipped)
  for ref in $(grep -oE '(^|[^./A-Za-z0-9_-])(references|scripts)/[A-Za-z0-9_.-]+' "$f" | sed -E 's/^[^rs]//' | sort -u); do
    [ -e "$(dirname "$f")/$ref" ] || fail "$f: links $ref but it does not exist"
  done
done
# the spec's reference validator, when installed (pip install skills-ref)
if command -v skills-ref >/dev/null 2>&1; then
  for f in "${skill_files[@]}"; do
    out="$(skills-ref validate "$(dirname "$f")" 2>&1)" || fail "skills-ref validate $(dirname "$f"): $(head -3 <<<"$out" | xargs)"
  done
fi

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

# --- action.yml (the Marketplace checks these only at release time, from the tag; catch them in the PR)
# value of top-level KEY, or of KEY one level under PARENT
yv() { awk -v k="$2" -v p="${3:-}" '
  /^[^ #]/ { inp = (p != "" && index($0, p ":") == 1) }
  { hit = (p == "") ? (index($0, k ":") == 1) : (inp && $0 ~ "^  " k ":") }
  hit { sub("^ *" k ": *", ""); sub(/ +#.*$/, ""); print; exit }' "$1"; }
unq() { sed -E "s/^\"(.*)\"\$/\\1/; s/^'(.*)'\$/\\1/" <<<"$1"; }
[ -f action.yml ] && [ -f action.yaml ] && fail "both action.yml and action.yaml at the root (keep one)"
for a in action.yml action.yaml; do
  [ -f "$a" ] || continue
  for k in name description; do
    v="$(yv "$a" "$k")"
    [ -n "$v" ] || { fail "$a: no $k (the Marketplace needs it)"; continue; }
    [[ "$v" =~ ^[\"\'] || "$v" != *": "* ]] || fail "$a: $k has an unquoted ': ' (invalid YAML); wrap it in double quotes"
  done
  d="$(unq "$(yv "$a" description)")"
  [ ${#d} -lt 125 ] || fail "$a: description is ${#d} chars (the Marketplace needs under 125)"
  [ -n "$(yv "$a" author)" ] || warn "$a: no author (shown on the Marketplace listing)"
  [ -n "$(yv "$a" using runs)" ] || fail "$a: no runs.using"
  [ -n "$(unq "$(yv "$a" icon branding)")" ] || fail "$a: no branding.icon (a Feather icon name, e.g. check-circle)"
  color="$(unq "$(yv "$a" color branding)")"
  [[ "$color" =~ ^(white|black|yellow|blue|green|orange|red|purple|gray-dark)$ ]] \
    || fail "$a: branding.color '$color' is not one of white black yellow blue green orange red purple gray-dark"
  nested=$(find . -mindepth 2 \( -name .git -o -name node_modules \) -prune -o \( -name action.yml -o -name action.yaml \) -print | head -3 | xargs)
  [ -z "$nested" ] || warn "action file below the root ($nested): only the root one can be listed on the Marketplace"
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
