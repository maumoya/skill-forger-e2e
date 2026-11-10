#!/usr/bin/env bash
# Make the README demo video card: a <=10 s GIF, under 5 MB, the same clip as the portfolio site.
# Input: a video file (mp4, mov, webm, gif) or a web page URL (recorded with headless Chrome + record_page.mjs).
# Writes only OUT_GIF. Local only: no uploads. Needs ffmpeg; a URL also needs Chrome and node 22+.
# Usage: make_demo.sh INPUT OUT_GIF [--seconds 8] [--start 0] [--width 720] [--size 1200x760]
#   INPUT    demo.mp4 | https://example.com | http://localhost:5173 | file:///abs/path/demo.html
#   OUT_GIF  assets/demo.gif (put it under the header: <img src="assets/demo.gif" width="720" alt="…">)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
in="${1:?usage: make_demo.sh INPUT OUT_GIF [--seconds N] [--start S] [--width W] [--size WxH]}"
gif="${2:?usage: make_demo.sh INPUT OUT_GIF [--seconds N] [--start S] [--width W] [--size WxH]}"; shift 2
secs=8; start=0; width=720; size=1200x760
while [ $# -gt 0 ]; do
  case "$1" in
    --seconds) secs="$2"; shift 2 ;;
    --start) start="$2"; shift 2 ;;
    --width) width="$2"; shift 2 ;;
    --size) size="$2"; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
for n in "$secs" "$start" "$width"; do [[ "$n" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { echo "not a number: $n" >&2; exit 2; }; done
[[ "$size" =~ ^[0-9]+x[0-9]+$ ]] || { echo "--size must be WxH" >&2; exit 2; }
awk -v s="$secs" 'BEGIN{exit !(s<=10)}' || { echo "--seconds must be 10 or less (a card, not a video)" >&2; exit 2; }
command -v ffmpeg >/dev/null || { echo "needs ffmpeg (brew install ffmpeg)" >&2; exit 1; }
tmp="$(mktemp -d)"; trap '[ -n "${cpid:-}" ] && { kill "$cpid"; wait "$cpid"; } 2>/dev/null; rm -rf "$tmp"' EXIT
mkdir -p "$(dirname "$gif")"

src="$in"
if [[ "$in" =~ ^(https?|file):// ]]; then
  command -v node >/dev/null || { echo "a URL needs node 22+ (built-in WebSocket)" >&2; exit 1; }
  chrome=""
  for c in "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" "/Applications/Chromium.app/Contents/MacOS/Chromium" \
           "$(command -v google-chrome 2>/dev/null)" "$(command -v chromium 2>/dev/null)" "$(command -v chromium-browser 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { chrome="$c"; break; }
  done
  [ -n "$chrome" ] || { echo "a URL needs Chrome or Chromium" >&2; exit 1; }
  port=$((9300 + RANDOM % 600))
  "$chrome" --headless=new --disable-gpu --hide-scrollbars --remote-debugging-port="$port" \
    --user-data-dir="$tmp/profile" about:blank >/dev/null 2>&1 & cpid=$!
  for _ in $(seq 50); do curl -fsS "http://127.0.0.1:$port/json/version" >/dev/null 2>&1 && break; sleep 0.2; done
  mkdir "$tmp/frames"
  node "$here/record_page.mjs" "$port" "$in" "$tmp/frames" "$secs" "${size%x*}" "${size#*x}"
  # each frame lasts until the next one arrives; the last one until the end (a still page sends one frame)
  node -e '
    const fs = require("fs"); const [d, end] = process.argv.slice(1); const t = JSON.parse(fs.readFileSync(d + "/times.json"));
    const t0 = t[0] ?? 0; let s = "";
    t.forEach((x, i) => { s += `file '\''${d}/f${String(i).padStart(5, "0")}.jpg'\''\nduration ${Math.max((t[i + 1] ?? t0 + +end) - x, 0.02).toFixed(3)}\n`; });
    // concat drops the last duration unless the last file is listed once more
    if (t.length) s += `file '\''${d}/f${String(t.length - 1).padStart(5, "0")}.jpg'\''\n`;
    fs.writeFileSync(d + "/list.txt", s);' "$tmp/frames" "$secs"
  [ -f "$tmp/frames/f00000.jpg" ] || { echo "Chrome sent no frames: is the page reachable?" >&2; exit 1; }
  ffmpeg -loglevel error -y -f concat -safe 0 -i "$tmp/frames/list.txt" -fps_mode vfr -pix_fmt yuv420p "$tmp/clip.mp4"
  src="$tmp/clip.mp4"; start=0
else
  [ -f "$in" ] || { echo "no such file: $in" >&2; exit 2; }
fi

# palette GIF; if it is over 5 MB, retry smaller (fewer frames and colors, no dither)
encode() { # FPS COLORS DITHER WIDTH
  ffmpeg -loglevel error -y -ss "$start" -t "$secs" -i "$src" -vf \
    "fps=$1,scale=$4:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=$2:stats_mode=diff[p];[b][p]paletteuse=dither=$3:diff_mode=rectangle" \
    "$gif"
}
bytes() { wc -c < "$gif" | tr -d ' '; }
encode 12 128 bayer:bayer_scale=4 "$width"
[ "$(bytes)" -le 5242880 ] || encode 10 64 none "$width"
[ "$(bytes)" -le 5242880 ] || encode 10 64 none $((width * 3 / 4))
kb=$(( $(bytes) / 1024 ))
[ "$(bytes)" -le 5242880 ] || { echo "still ${kb} KB: shorten --seconds or lower --width" >&2; exit 1; }
echo "wrote $gif (${kb} KB, ${secs} s)"
