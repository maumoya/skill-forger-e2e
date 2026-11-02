#!/usr/bin/env bash
# Make a 1280x640 README header (also the GitHub social preview size): SVG always, PNG when Chrome is found.
# Left: mark, OWNER/REPO, two-line headline, two-line tagline, 3 chips, trust pills (OSI open source, no tracking).
# Right: a terminal card (lines from --line) or a screenshot (--image), and an optional author photo (square PNG, a round cut-out looks best).
# Writes only OUT_DIR/header.svg and OUT_DIR/header.png. No network.
# Usage: make_header.sh OUT_DIR --repo OWNER/REPO --head "Line one." --head2 "Line two." \
#   [--sub "Tagline line one"] [--sub2 "line two"] [--chip "a" --chip "b" --chip "c"] \
#   [--line '$ command' --line '✓ result' --line 'SCORE 100/100'] [--image shot.png] [--photo me.png] \
#   [--by "Your Name" --handle "@you"] [--mark "SF"] [--license "Open Source · MIT"] [--privacy "No tracking · no data collected"] \
#   [--no-trust] [--bg1 '#1B1240' --bg2 '#3A1670' --accent '#C9B8FF']
set -euo pipefail
out="${1:?usage: make_header.sh OUT_DIR --repo OWNER/REPO --head TEXT [options]}"; shift
repo=""; head1=""; head2=""; sub1=""; sub2=""; chips=(); lines=(); image=""; photo=""; by=""; handle=""; mark=""
license="Open Source · MIT"; privacy="No tracking · no data collected"; trust=1
bg1="#1B1240"; bg2="#3A1670"; accent="#C9B8FF"
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;      --head) head1="$2"; shift 2 ;;   --head2) head2="$2"; shift 2 ;;
    --sub) sub1="$2"; shift 2 ;;       --sub2) sub2="$2"; shift 2 ;;    --chip) chips+=("$2"); shift 2 ;;
    --line) lines+=("$2"); shift 2 ;;  --image) image="$2"; shift 2 ;;  --photo) photo="$2"; shift 2 ;;
    --by) by="$2"; shift 2 ;;          --handle) handle="$2"; shift 2 ;; --mark) mark="$2"; shift 2 ;;
    --license) license="$2"; shift 2 ;; --privacy) privacy="$2"; shift 2 ;; --no-trust) trust=0; shift ;;
    --bg1) bg1="$2"; shift 2 ;;        --bg2) bg2="$2"; shift 2 ;;      --accent) accent="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] && [ -n "$head1" ] || { echo "--repo and --head are required" >&2; exit 2; }
for f in "$image" "$photo"; do [ -z "$f" ] || [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }; done
[[ "$repo" == */* ]] && { owner="${repo%%/*}/"; name="${repo#*/}"; } || { owner=""; name="$repo"; }
[ -n "$mark" ] || mark="$(tr '[:lower:]' '[:upper:]' <<<"${name:0:1}")"

esc() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' <<<"$1"; }
len() { printf %s "$1" | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }
datauri() { local t; case "$1" in *.png) t=png ;; *.jpg|*.jpeg) t=jpeg ;; *.webp) t=webp ;; *.gif) t=gif ;; *) t=png ;; esac
  printf 'data:image/%s;base64,%s' "$t" "$(base64 < "$1" | tr -d '\n')"; }
for h in "$head1" "$head2"; do [ "$(len "$h")" -le 19 ] || echo "warn: headline over 19 chars may overflow: $h" >&2; done
for s in "$sub1" "$sub2"; do [ "$(len "$s")" -le 46 ] || echo "warn: tagline line over 46 chars may overflow: $s" >&2; done
for l in "${lines[@]:0:6}"; do [ "$(len "$l")" -le 32 ] || echo "warn: card line over 32 chars may overflow: $l" >&2; done

F="-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
M="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
svg="$(cat <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1280 640" width="1280" height="640">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="$bg1"/><stop offset="1" stop-color="$bg2"/></linearGradient>
    <linearGradient id="badge" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#6D5DFC"/><stop offset="1" stop-color="#C04CF0"/></linearGradient>
    <radialGradient id="glow" cx="0.78" cy="0.45" r="0.5"><stop offset="0" stop-color="#8B5CF6" stop-opacity="0.45"/><stop offset="1" stop-color="#8B5CF6" stop-opacity="0"/></radialGradient>
    <filter id="sh" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="18" stdDeviation="22" flood-color="#000" flood-opacity="0.45"/></filter>
    <clipPath id="card"><rect x="720" y="150" width="480" height="340" rx="28"/></clipPath>
    <filter id="ps" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="8" stdDeviation="10" flood-color="#0B0620" flood-opacity="0.45"/></filter>
  </defs>
  <rect width="1280" height="640" fill="url(#bg)"/>
  <rect width="1280" height="640" fill="url(#glow)"/>
  <g font-family="$F">
    <rect x="80" y="92" width="72" height="72" rx="18" fill="url(#badge)"/>
    <text x="116" y="141" font-size="$([ ${#mark} -gt 1 ] && echo 30 || echo 38)" font-weight="800" fill="#FFFFFF" text-anchor="middle">$(esc "$mark")</text>
    <text x="172" y="143" font-size="40" font-weight="700" fill="#FFFFFF"><tspan fill="$accent" font-weight="500">$(esc "$owner")</tspan>$(esc "$name")</text>
    <text x="80" y="262" font-size="66" font-weight="800" fill="#FFFFFF">$(esc "$head1")</text>
    <text x="80" y="340" font-size="66" font-weight="800" fill="$accent">$(esc "$head2")</text>
    <text x="80" y="404" font-size="26" fill="#D8D2F5">$(esc "$sub1")</text>
    <text x="80" y="440" font-size="26" fill="#D8D2F5">$(esc "$sub2")</text>
EOF
)"
# chips: width from the character count, three fixed colours
colors=("#22C55E" "#60A5FA" "#FBBF24"); x=80; i=0
for c in "${chips[@]:0:3}"; do
  w=$(( $(len "$c") * 10 + 36 ))
  svg+="
    <rect x=\"$x\" y=\"490\" width=\"$w\" height=\"40\" rx=\"20\" fill=\"${colors[$i]}\"/><text x=\"$((x + w / 2))\" y=\"517\" font-size=\"20\" font-weight=\"600\" fill=\"#1B1240\" text-anchor=\"middle\">$(esc "$c")</text>"
  x=$((x + w + 14)); i=$((i + 1))
done
if [ "$trust" = 1 ]; then
  lw=$(( $(len "$license") * 10 + 66 )); px=$((80 + lw + 14)); pw=$(( $(len "$privacy") * 10 + 66 ))
  svg+="
    <rect x=\"80\" y=\"546\" width=\"$lw\" height=\"40\" rx=\"20\" fill=\"#FFFFFF\"/>
    <g transform=\"translate(92 551) scale(1.25)\"><path fill=\"#3DA639\" d=\"M11.959.447A11.938 11.938 0 000 12.407c0 5.576 3.874 10.097 7.783 11.114.193.05.392-.05.467-.234l2.771-6.822a.396.396 0 00-.246-.528C9.365 15.47 8.53 14.32 8.48 12.4c-.024-1.828 1.5-3.45 3.561-3.447 1.931.003 3.479 1.632 3.479 3.453 0 .966-.203 1.687-.575 2.238-.371.552-.922.951-1.695 1.239a.396.396 0 00-.23.515l2.685 6.903a.396.396 0 00.465.24C20.163 22.534 24 18.062 24 12.406 24 5.804 18.603.447 11.959.447z\"/></g>
    <text x=\"130\" y=\"573\" font-size=\"20\" font-weight=\"600\" fill=\"#1E1B3A\">$(esc "$license")</text>
    <rect x=\"$px\" y=\"546\" width=\"$pw\" height=\"40\" rx=\"20\" fill=\"#FFFFFF\"/>
    <g transform=\"translate($((px + 12)) 552)\"><path d=\"M14 1 L26 5.5 V14 C26 21 20.5 26 14 28 C7.5 26 2 21 2 14 V5.5 Z\" fill=\"#7C5CFC\"/><path d=\"M8.5 14.5 L12.5 18.5 L19.5 10.5\" fill=\"none\" stroke=\"#FFFFFF\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/></g>
    <text x=\"$((px + 50))\" y=\"573\" font-size=\"20\" font-weight=\"600\" fill=\"#1E1B3A\">$(esc "$privacy")</text>"
fi
# right side: screenshot card, or a terminal card
if [ -n "$image" ]; then
  svg+="
    <g filter=\"url(#sh)\"><rect x=\"720\" y=\"150\" width=\"480\" height=\"340\" rx=\"28\" fill=\"#0B0620\"/></g>
    <image x=\"720\" y=\"150\" width=\"480\" height=\"340\" preserveAspectRatio=\"xMidYMid slice\" clip-path=\"url(#card)\" href=\"$(datauri "$image")\"/>"
elif [ ${#lines[@]} -gt 0 ]; then
  svg+="
    <g filter=\"url(#sh)\"><rect x=\"720\" y=\"150\" width=\"480\" height=\"340\" rx=\"28\" fill=\"#120B2E\"/></g>
    <rect x=\"720.5\" y=\"150.5\" width=\"479\" height=\"339\" rx=\"28\" fill=\"none\" stroke=\"#3B2F6B\"/>
    <circle cx=\"756\" cy=\"184\" r=\"7\" fill=\"#FF5F57\"/><circle cx=\"778\" cy=\"184\" r=\"7\" fill=\"#FEBC2E\"/><circle cx=\"800\" cy=\"184\" r=\"7\" fill=\"#28C840\"/>"
  y=264
  for l in "${lines[@]:0:6}"; do
    case "$l" in
      '$'*)    fill="$accent"; weight=600 ;;
      ✓*)      fill="#4ADE80"; weight=500 ;;
      ✗*|!*)   fill="#F87171"; weight=500 ;;
      SCORE*)  fill="#FBBF24"; weight=800 ;;
      *)       fill="#D8D2F5"; weight=400 ;;
    esac
    svg+="
    <text x=\"752\" y=\"$y\" font-family=\"$M\" font-size=\"22\" font-weight=\"$weight\" fill=\"$fill\">$(esc "$l")</text>"
    y=$((y + 40))
  done
fi
svg+="
  </g>"
if [ -n "$by" ]; then
  bx=$([ -n "$photo" ] && echo 1028 || echo 1200)
  svg+="
  <text x=\"$bx\" y=\"112\" text-anchor=\"end\" font-family=\"$F\" font-size=\"22\" fill=\"#D8D2F5\">by <tspan font-weight=\"700\" fill=\"#FFFFFF\">$(esc "$by")</tspan>$([ -n "$handle" ] && echo " · $(esc "$handle")")</text>"
fi
if [ -n "$photo" ]; then
  svg+="
  <image x=\"1040\" y=\"28\" width=\"210\" height=\"210\" filter=\"url(#ps)\" href=\"$(datauri "$photo")\"/>"
fi
svg+="
</svg>"

mkdir -p "$out"
printf '%s\n' "$svg" > "$out/header.svg"
echo "wrote $out/header.svg"

# PNG through headless Chrome; without it, keep the SVG (GitHub renders it, but social previews need a PNG)
chrome=""
for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium" \
         "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)"; do
  [ -n "$c" ] && [ -x "$c" ] && { chrome="$c"; break; }
done
if [ -z "$chrome" ]; then echo "no Chrome found: kept the SVG only (render header.png by hand for the social preview)"; exit 0; fi
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
abs="$(cd "$out" && pwd)"
printf '<!doctype html><html><body style="margin:0;background:#000"><img src="file://%s/header.svg" width="1280" height="640" style="display:block"></body></html>' "$abs" > "$tmp/h.html"
"$chrome" --headless=new --disable-gpu --hide-scrollbars --allow-file-access-from-files --user-data-dir="$tmp/profile" \
  --window-size=1280,640 --screenshot="$abs/header.png" "file://$tmp/h.html" >/dev/null 2>&1 \
  && echo "wrote $out/header.png (1280x640)" || echo "Chrome failed: kept the SVG only"
