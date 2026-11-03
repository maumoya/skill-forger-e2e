#!/usr/bin/env bash
# Live install test from the public repo, the way a stranger would install it.
# Free part: in a throwaway Claude config, `claude plugin marketplace add OWNER/REPO` + `claude plugin install`,
# then checks a SKILL.md landed and prints the component inventory and token cost. Never touches your own config.
# Billed part (opt-in, --trigger): one `claude -p` run with the installed plugin that checks the phrase loads the skill.
# --npx: test the other install path instead, `npx skills add OWNER/REPO` (skills.sh, 75+ agents), in a throwaway
# HOME and project with telemetry off, then lint the installed copy. Free. Needs node.
# Usage: install_test.sh OWNER/REPO [PLUGIN_NAME] [--trigger "phrase a user would type"]
#        install_test.sh OWNER/REPO --npx [--agent claude-code]
set -uo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
# pinned skills CLI (a release at least two weeks old); bump on purpose, never @latest
SKILLS_CLI="skills@1.7.4"
slug=""; plugin=""; trigger=""; npx_mode=""; agent="claude-code"
while [ $# -gt 0 ]; do
  case "$1" in
    --trigger) trigger="${2:?--trigger needs a phrase}"; shift 2 ;;
    --npx) npx_mode=1; shift ;;
    --agent) agent="${2:?--agent needs a name}"; shift 2 ;;
    *) if [ -z "$slug" ]; then slug="$1"; else plugin="$1"; fi; shift ;;
  esac
done
[[ "$slug" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { echo "usage: install_test.sh OWNER/REPO [PLUGIN_NAME] [--trigger \"phrase\"]" >&2; exit 2; }

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
cfg="$work/config"; mkdir -p "$cfg" "$work/project"
pass=0; fails=0
ok()   { echo "PASS $*"; pass=$((pass+1)); }
bad()  { echo "FAIL $*"; fails=$((fails+1)); }

if [ -n "$npx_mode" ]; then
  command -v npx >/dev/null || { echo "npx not found (install Node.js)" >&2; exit 2; }
  cd "$work/project" && git init -q . 2>/dev/null
  out="$(HOME="$work" DO_NOT_TRACK=1 DISABLE_TELEMETRY=1 npm_config_cache="$work/.npm" npm_config_update_notifier=false \
    npx -y "$SKILLS_CLI" add "$slug" --agent "$agent" --skill '*' --yes --copy 2>&1)"
  if [ $? -eq 0 ]; then ok "npx $SKILLS_CLI add $slug --agent $agent"
  else bad "npx $SKILLS_CLI add $slug: $(grep -v '^npm notice' <<<"$out" | tail -3 | paste -sd' ' -)"; echo "RESULT $pass passed, $fails failed"; exit 1; fi
  # each agent keeps project skills in its own dot folder; find wherever this one put them
  shopt -s nullglob; skills=()
  for f in "$work"/project/.*/skills/*/SKILL.md "$work"/project/skills/*/SKILL.md; do skills+=("$f"); done
  if [ ${#skills[@]} -gt 0 ]; then
    ok "installed ${#skills[@]} skill(s): $(for f in "${skills[@]}"; do basename "$(dirname "$f")"; done | paste -sd, -)"
    lint="$here/lint_skill.sh"; root="$(dirname "$(dirname "$(dirname "${skills[0]}")")")"
    lout="$(bash "$lint" "$root" 2>&1)"
    if [ $? -eq 0 ]; then ok "lint on the installed copy: no FAIL"
    else bad "lint on the installed copy:"; { grep '^FAIL' <<<"$lout" || tail -2 <<<"$lout"; } | sed 's/^/  /'; fi
  else bad "no SKILL.md landed in the project (agent $agent)"; fi
  echo "RESULT $pass passed, $fails failed"
  [ $fails -eq 0 ]; exit
fi

command -v claude >/dev/null || { echo "claude CLI not found" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq not found" >&2; exit 2; }

cd "$work/project" || exit 2
add="$(CLAUDE_CONFIG_DIR="$cfg" claude plugin marketplace add "$slug" --json 2>&1)"
mkt="$(tail -1 <<<"$add" | jq -r 'select(.outcome=="ok") | .marketplace' 2>/dev/null)"
if [ -z "$mkt" ]; then bad "marketplace add $slug: $(tail -2 <<<"$add" | paste -sd' ' -)"; echo "RESULT $pass passed, $fails failed"; exit 1; fi
ok "marketplace add $slug (marketplace: $mkt)"

mfile="$cfg/plugins/marketplaces/$mkt/.claude-plugin/marketplace.json"
[ -n "$plugin" ] || plugin="$(jq -r '.plugins[0].name // empty' "$mfile" 2>/dev/null)"
[ -n "$plugin" ] || { bad "no plugin name given and none found in marketplace.json"; echo "RESULT $pass passed, $fails failed"; exit 1; }

inst="$(CLAUDE_CONFIG_DIR="$cfg" claude plugin install "$plugin@$mkt" --json 2>&1 | tail -1)"
if [ "$(jq -r '.outcome' <<<"$inst" 2>/dev/null)" = ok ]; then ok "install $plugin@$mkt"
else bad "install $plugin@$mkt: $({ jq -r '.message' 2>/dev/null || cat; } <<<"$inst" | tail -2)"; echo "RESULT $pass passed, $fails failed"; exit 1; fi

pdir="$(find "$cfg/plugins/cache/$mkt/$plugin" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
shopt -s nullglob; skills=("$pdir"/skills/*/SKILL.md)
if [ ${#skills[@]} -gt 0 ]; then ok "installed ${#skills[@]} skill(s): $(for f in "${skills[@]}"; do basename "$(dirname "$f")"; done | paste -sd, -)"
else bad "no skills/<name>/SKILL.md in the installed plugin"; fi

echo "--- plugin details"
CLAUDE_CONFIG_DIR="$cfg" claude plugin details "$plugin@$mkt" 2>&1 | sed -n '1,20p'

if [ -n "$trigger" ] && [ ${#skills[@]} -gt 0 ]; then
  sname="$(basename "$(dirname "${skills[0]}")")"
  echo "--- trigger check (billed: one short claude -p run on your account)"
  claude plugin list 2>/dev/null | grep -q "$plugin" && echo "note: $plugin is also installed in your own config, so a load may come from there"
  log="$work/trigger.jsonl"
  claude -p "$trigger" --plugin-dir "$pdir" --output-format stream-json --verbose \
    --max-turns 2 --allowed-tools Skill >"$log" 2>"$work/trigger.err" || true
  hit="$(jq -r 'select(.type=="assistant") | .message.content[]? | select(.type=="tool_use" and .name=="Skill") | .input.skill // .input.command // empty' "$log" 2>/dev/null | head -1)"
  if [ -n "$hit" ] && [[ "$hit" == *"$sname"* ]]; then ok "trigger \"$trigger\" loaded skill $hit"
  elif [ -n "$hit" ]; then bad "trigger \"$trigger\" loaded a different skill: $hit"
  elif [ ! -s "$log" ]; then bad "trigger run produced no output: $(head -3 "$work/trigger.err")"
  else bad "trigger \"$trigger\" did not load $sname (tighten the description's trigger phrases)"; fi
fi

echo "RESULT $pass passed, $fails failed"
[ $fails -eq 0 ]
