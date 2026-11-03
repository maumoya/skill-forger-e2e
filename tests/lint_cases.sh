#!/usr/bin/env bash
# Self-test for lint_skill.sh: builds small broken skill repos and checks the linter names each problem.
# Usage: bash tests/lint_cases.sh   (exit 1 on any miss)
set -uo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
lint="$here/skills/skill-forger-e2e/scripts/lint_skill.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
pass=0; miss=0

# repo NAME with SKILL.md frontmatter FM (lines) and BODY; prints its path
mkrepo() {
  local d="$tmp/$1"; mkdir -p "$d/skills/$1"
  printf -- '---\n%s\n---\n%s\n' "$2" "${3:-Do the thing.}" > "$d/skills/$1/SKILL.md"
  echo "$d"
}
# expect REPO PATTERN LABEL: lint output must match PATTERN
expect() {
  # capture first: grep -q exits early and pipefail would count the SIGPIPE as a miss
  local out; out="$(bash "$lint" "$1" 2>&1)"
  if grep -qE "$2" <<<"$out"; then pass=$((pass+1)); else echo "MISS $3: no line matching /$2/"; miss=$((miss+1)); fi
}
# clean REPO PATTERN LABEL: lint output must NOT match PATTERN
clean() {
  local out; out="$(bash "$lint" "$1" 2>&1)"
  if grep -qE "$2" <<<"$out"; then echo "MISS $3: unexpected /$2/"; miss=$((miss+1)); else pass=$((pass+1)); fi
}

ok_desc='description: Turns notes into tasks. Use when the user says "make tasks".'

# --- spec fields
r=$(mkrepo compat-long "name: compat-long
$ok_desc
compatibility: $(printf 'x%.0s' $(seq 1 510))")
expect "$r" '^FAIL .*compatibility is 510 chars' "compatibility over 500"

r=$(mkrepo odd-key "name: odd-key
$ok_desc
owner: me")
expect "$r" "^WARN .*key 'owner' is not in the Agent Skills spec" "unknown frontmatter key"

r=$(mkrepo cc-keys "name: cc-keys
$ok_desc
license: MIT
argument-hint: <file>
disable-model-invocation: true")
clean "$r" 'not in the Agent Skills spec' "spec and Claude Code keys pass"

r=$(mkrepo meta-list "name: meta-list
$ok_desc
metadata:
  - author")
expect "$r" '^FAIL .*metadata must be a map.*list' "metadata as a list"

r=$(mkrepo meta-num "name: meta-num
$ok_desc
metadata:
  author: me
  version: 1.0")
expect "$r" '^WARN .*unquoted number' "metadata unquoted number"

r=$(mkrepo meta-ok "name: meta-ok
$ok_desc
metadata:
  author: \"me\"
  version: \"1.0\"")
clean "$r" 'metadata' "metadata map of strings passes"

r=$(mkrepo tools-list "name: tools-list
$ok_desc
allowed-tools:
  - Read")
expect "$r" '^WARN .*allowed-tools is a YAML list' "allowed-tools as a list"

r=$(mkrepo bad--name "name: bad--name
$ok_desc")
expect "$r" '^FAIL .*lowercase letters, digits, hyphens' "consecutive hyphens"

# --- description hygiene
r=$(mkrepo workflow-desc 'name: workflow-desc
description: First reads the file, then splits it, finally writes tasks. Use when the user says "tasks".')
expect "$r" '^WARN .*reads like a workflow' "description narrates steps"

r=$(mkrepo first-person 'name: first-person
description: I can turn notes into tasks. Use when the user says "tasks".')
expect "$r" '^WARN .*third person' "first-person description"

# --- size and structure
r=$(mkrepo big-body "name: big-body
$ok_desc" "$(head -c 24000 /dev/zero | tr '\0' 'a')")
expect "$r" '^WARN .*about [0-9]+ tokens' "body over 5000 tokens"

r=$(mkrepo ref-chain "name: ref-chain
$ok_desc" "Read [a](references/a.md).")
mkdir -p "$r/skills/ref-chain/references"
echo 'See [b](b.md).' > "$r/skills/ref-chain/references/a.md"
echo 'Leaf.' > "$r/skills/ref-chain/references/b.md"
expect "$r" '^WARN .*keep references one level deep' "reference links another reference"

# --- this repo stays clean
expect "$here" '^PASS' "skill-forger-e2e itself passes"

echo "lint cases: $pass passed, $miss missed"
[ "$miss" -eq 0 ]
