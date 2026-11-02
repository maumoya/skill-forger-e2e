#!/usr/bin/env bash
# Add the missing ship pieces (plugin JSON, workflows, SECURITY.md, evals, llms.txt...) to an existing skill repo.
# Never overwrites: a file that already exists is skipped. Writes only inside REPO_DIR. No network.
# Usage: retrofit.sh REPO_DIR "Owner Name" [GITHUB_USER] [--dry-run]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
dry=0; pos=()
for a in "$@"; do [ "$a" = --dry-run ] && dry=1 || pos+=("$a"); done
repo="${pos[0]:?usage: retrofit.sh REPO_DIR \"Owner Name\" [GITHUB_USER] [--dry-run]}"
owner="${pos[1]:?missing \"Owner Name\"}"
gh_user="${pos[2]:-OWNER}"
[ -d "$repo" ] || { echo "no such dir: $repo" >&2; exit 1; }
repo="$(cd "$repo" && pwd)"

shopt -s nullglob
skills=("$repo"/skills/*/SKILL.md)
[ ${#skills[@]} -gt 0 ] || { echo "no skills/<name>/SKILL.md in $repo (start with new_skill.sh instead)" >&2; exit 1; }
[ ${#skills[@]} -eq 1 ] || echo "note: ${#skills[@]} skills found, using the first for names: ${skills[0]}"
name="$(basename "$(dirname "${skills[0]}")")"
desc="$(awk 'NR>1&&$0=="---"{exit} NR>1&&index($0,"description: ")==1{sub("^description: *","");print;exit}' "${skills[0]}")"
desc="${desc:-REPLACE: what this skill does and for whom, in one sentence.}"

# render the template for this skill into a scratch dir, then copy only what the repo lacks
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
bash "$here/new_skill.sh" "$name" "$tmp/r" "$owner" "$gh_user" "$desc" >/dev/null

has_evals=0; for c in "$repo"/evals/*/case.yaml; do has_evals=1; done
added=(); skipped=()
while IFS= read -r -d '' src; do
  rel="${src#"$tmp/r/"}"
  case "$rel" in
    .git/*|skills/*) continue ;;                       # the user's skill is theirs
    evals/*) [ $has_evals -eq 1 ] && continue ;;        # keep their eval suite as is
  esac
  if [ -e "$repo/$rel" ]; then skipped+=("$rel"); continue; fi
  added+=("$rel")
  [ $dry -eq 1 ] && continue
  mkdir -p "$(dirname "$repo/$rel")"
  cp -p "$src" "$repo/$rel"
done < <(find "$tmp/r" -type f -print0 | sort -z)

verb=added; [ $dry -eq 1 ] && verb="would add"
for f in "${added[@]+"${added[@]}"}"; do echo "$verb $f"; done
for f in "${skipped[@]+"${skipped[@]}"}"; do echo "kept  $f (exists)"; done
echo "${#added[@]} $verb, ${#skipped[@]} kept"
if [ ${#added[@]} -gt 0 ] && [ $dry -eq 0 ]; then
  echo "next: fill any REPLACE markers, then run: bash $repo/scripts/lint_skill.sh $repo"
fi
