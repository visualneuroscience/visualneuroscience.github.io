#!/usr/bin/env bash
# Usage: make-thumbnail.sh mdi:<icon> | ms:<icon> [name]
# mdi: https://pictogrammers.com/library/mdi/   ms: https://fonts.google.com/icons
# Writes <name>.svg (default: the icon name) next to this script.
set -euo pipefail
[ $# -ge 1 ] || { sed -n 2,4p "$0"; exit 1; }

set_name=${1%%:*} icon=${1#*:}
case $set_name in
  mdi) url=https://cdn.jsdelivr.net/npm/@mdi/svg@7.4.47/svg/$icon.svg src="Material Design Icons (Pictogrammers)" ;;
  ms) url=https://cdn.jsdelivr.net/npm/@material-symbols/svg-400@0.40.2/outlined/$icon.svg src="Material Symbols (Google)" ;;
  *) echo "Icon must start with mdi: or ms:" >&2; exit 1 ;;
esac

out=$(dirname "$0")/${2:-$icon}.svg
[ ! -e "$out" ] || { echo "$out already exists" >&2; exit 1; }
svg=$(curl -sf "$url") || { echo "Icon not found: $url" >&2; exit 1; }

cat > "$out" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 160" preserveAspectRatio="xMidYMid slice">
  <defs>
    <pattern id="grid" width="16" height="16" patternUnits="userSpaceOnUse">
      <path d="M16 0H0V16" fill="none" stroke="#17181b" stroke-opacity="0.07" stroke-width="1"/>
    </pattern>
  </defs>
  <rect width="480" height="160" fill="#efebe2"/>
  <rect width="480" height="160" fill="url(#grid)"/>
  <circle cx="240" cy="80" r="50" fill="none" stroke="#17181b" stroke-opacity="0.15" stroke-width="1.5"/>
  <circle cx="240" cy="80" r="70" fill="none" stroke="#17181b" stroke-opacity="0.08" stroke-width="1.5"/>
  <!-- "$icon" icon from $src, Apache License 2.0 -->
  <svg x="206" y="46" width="68" height="68" $(grep -o 'viewBox="[^"]*"' <<<"$svg")>
    <path fill="#d9230f"$(grep -o ' d="[^"]*"' <<<"$svg" | head -1)/>
  </svg>
</svg>
EOF
echo "Created $out"
