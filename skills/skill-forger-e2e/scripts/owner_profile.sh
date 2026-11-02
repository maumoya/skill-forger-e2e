#!/usr/bin/env bash
# Drafts the README "About the author" section from the owner's public GitHub profile, plus interview
# questions for what the profile does not say. The owner reviews and edits it before it is published.
# Privacy: read-only GETs to the public GitHub API through gh. Prints to the terminal only;
# nothing is saved, cached or sent anywhere. Only what the owner approves ends up in their README.
# Usage: owner_profile.sh GITHUB_USER [PROJECT_NAME] [--name "Full Legal Name"]
set -uo pipefail
user="${1:?usage: owner_profile.sh GITHUB_USER [PROJECT_NAME] [--name \"Full Name\"]}"; shift
project="this project" name=""
[ $# -gt 0 ] && [ "${1#--}" = "$1" ] && { project="$1"; shift; }
[ "${1:-}" = "--name" ] && name="${2:-}"

p=$(gh api "users/$user" 2>/dev/null) || { echo "GitHub user $user not found (or gh not signed in)." >&2; exit 1; }
s=$(gh api "users/$user/social_accounts" 2>/dev/null || echo '[]')
field() { jq -r --arg k "$1" '.[$k] // "" | tostring' <<<"$p"; }
[ -n "$name" ] || name=$(field name); [ -n "$name" ] || name="$user"
bio=$(field bio) blog=$(field blog) twitter=$(field twitter_username)
linkedin=$( (jq -r '.[] | select(.provider == "linkedin") | .url' <<<"$s"; grep -o 'https://[a-z.]*linkedin.com/in/[^ ]*' <<<"$blog") | head -1)
[ "$blog" = "$linkedin" ] && blog=""

echo "== Public profile (GitHub, read now, not stored)"
printf '%-9s %s\n' name "$(field name)" bio "$bio" location "$(field location)" company "$(field company)" \
  website "$blog" linkedin "${linkedin:-none}" x "${twitter:+https://x.com/$twitter}"
jq -r '.[] | select(.provider != "linkedin" and .provider != "twitter") | "\(.provider)  \(.url)"' <<<"$s"

echo
echo "== Draft for the README (edit, then paste above ## License)"
echo
echo "## About the author"
echo
echo "Hi, I'm **$name** ([@$user](https://github.com/$user)). I built $project because WHY_YOU_BUILT_IT."
[ -n "$bio" ] && { echo; echo "$bio"; }
links=()
[ -n "$linkedin" ] && links+=("[LinkedIn]($linkedin)")
[ -n "$blog" ] && links+=("[website]($blog)")
links+=("[GitHub](https://github.com/$user)")
others=$(gh api "users/$user/repos?per_page=100&type=owner" 2>/dev/null | jq -r --arg me "$project" --arg u "$user" \
  '[.[] | select((.fork | not) and .name != $me and .name != $u and .description != null)] | sort_by(.pushed_at) | reverse | sort_by(-.stargazers_count) | .[:3][]
   | "- [\(.name)](\(.html_url)): \(.description)"')
[ -n "$others" ] && { echo; echo "More of my work:"; echo; echo "$others"; }
echo
echo "Say hi or follow my work on $(IFS='|'; sed 's/|/ · /g' <<<"${links[*]}")."

echo
echo "== Interview (ask the owner; replace WHY_YOU_BUILT_IT and add only what they approve)"
n=0; q() { n=$((n + 1)); echo "$n. $1"; }
q "In one sentence: why did you build $project? What problem did it solve for you?"
q "Your role or title, as you want it shown (e.g. founder, engineer, student)?"
q "One portfolio link to feature (site, case study, other project)?"
[ -z "$linkedin" ] && q "LinkedIn URL? (none on your GitHub profile)"
q "Name to credit exactly (legal name for the copyright line)?"
q "A photo for the header byline (make_header.sh --photo me.png --by \"Name\" --handle \"@$user\")?"
q "Anything above you do NOT want public? (personal accounts, location)"
