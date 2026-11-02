#!/usr/bin/env bash
# Scaffold a new skill repo from templates/repo. Writes only inside TARGET_DIR. No network.
# Usage: new_skill.sh SKILL_NAME TARGET_DIR "Owner Name" [GITHUB_USER] ["One-sentence description."]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
name="${1:?usage: new_skill.sh SKILL_NAME TARGET_DIR \"Owner Name\" [GITHUB_USER] [DESCRIPTION]}"
target="${2:?missing TARGET_DIR}"
owner="${3:?missing \"Owner Name\"}"
gh_user="${4:-OWNER}"
desc="${5:-REPLACE: what this skill does and for whom, in one sentence.}"

if ! [[ "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || [ ${#name} -gt 64 ]; then
  echo "name must be lowercase letters, digits and single hyphens, at most 64 chars: $name" >&2; exit 1
fi
if [[ "$name" == *claude* || "$name" == *anthropic* ]]; then
  echo "name must not contain 'claude' or 'anthropic': $name" >&2; exit 1
fi
if [ -e "$target" ] && [ -n "$(ls -A "$target" 2>/dev/null)" ]; then
  echo "target exists and is not empty: $target" >&2; exit 1
fi

title="$(awk -F- -v OFS=' ' '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}' <<<"$name")"

mkdir -p "$target"
cp -R "$here/../templates/repo/." "$target/"
mv "$target/skills/__NAME__" "$target/skills/$name"

export S_NAME="$name" S_TITLE="$title" S_OWNER="$owner" S_GH="$gh_user" S_DESC="$desc" S_YEAR="$(date +%Y)"
find "$target" -type f ! -path '*/.git/*' -print0 | while IFS= read -r -d '' f; do
  # JSON files get quotes and backslashes in the owner and description escaped
  case "$f" in *.json) export S_JSON=1 ;; *) export S_JSON=0 ;; esac
  perl -pi -e 'BEGIN { sub v { my $s = $ENV{$_[0]}; if ($ENV{S_JSON}) { $s =~ s/(["\\])/\\$1/g } $s } }
    s/__NAME__/v("S_NAME")/ge; s/__TITLE__/v("S_TITLE")/ge; s/__OWNER__/v("S_OWNER")/ge; s/__GH__/v("S_GH")/ge; s/__DESCRIPTION__/v("S_DESC")/ge; s/__YEAR__/v("S_YEAR")/ge' "$f"
done
# copied after the substitution so the linter keeps its own placeholder patterns
mkdir -p "$target/scripts"
cp "$here/lint_skill.sh" "$target/scripts/lint_skill.sh"
chmod +x "$target/scripts/lint_skill.sh"

[ -d "$target/.git" ] || git -C "$target" init -q -b main
echo "created $target (skill: $name)"
echo "next: fill the REPLACE markers, then run: bash $target/scripts/lint_skill.sh $target"
