#!/usr/bin/env bash
#
# md2org.sh — convert every Markdown file (.md) in this project tree to
# Org-mode (.org), in place. Drop it in the project root and run it.
#
# Requires: pandoc
#
set -euo pipefail

# Default target = the directory this script lives in, so it converts the
# project it's dropped into no matter where you invoke it from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
KEEP_MD=0      # 1 = keep the original .md next to the new .org
KEEP_IDS=0     # 1 = keep pandoc's :CUSTOM_ID: drawers under each heading

usage() {
  cat <<'EOF'
Usage: md2org.sh [options]

Converts every .md under the script's directory into .org, in place.

  -d, --dir DIR   Convert this directory instead (default: script's own dir)
      --keep-md   Keep each .md alongside the generated .org
      --keep-ids  Keep pandoc's :CUSTOM_ID: drawers under each heading
  -h, --help      Show this help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir)   ROOT="$2"; shift 2 ;;
    --keep-md)  KEEP_MD=1; shift ;;
    --keep-ids) KEEP_IDS=1; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if ! command -v pandoc >/dev/null 2>&1; then
  echo "error: 'pandoc' is required but not installed." >&2
  echo "  on Arch/CachyOS:  sudo pacman -S pandoc" >&2
  exit 1
fi

# Drop pandoc's :CUSTOM_ID: drawers, but keep any genuine PROPERTIES drawers.
strip_ids() {
  awk '
    /^:PROPERTIES:$/ { buf=$0; in_drawer=1; has_id=0; next }
    in_drawer {
      buf = buf ORS $0
      if ($0 ~ /^:CUSTOM_ID:/) has_id=1
      if ($0 ~ /^:END:$/) { in_drawer=0; if (!has_id) print buf; next }
      next
    }
    { print }
  '
}

converted=0; failed=0; failed_list=""
while IFS= read -r -d '' md; do
  org="${md%.*}.org"
  if pandoc -f gfm -t org --wrap=preserve "$md" 2>/dev/null \
       | { if [ "$KEEP_IDS" -eq 1 ]; then cat; else strip_ids; fi; } > "$org.tmp"; then
    mv "$org.tmp" "$org"
    converted=$((converted + 1))
    [ "$KEEP_MD" -eq 0 ] && rm -f "$md"
  else
    rm -f "$org.tmp"
    failed=$((failed + 1))
    failed_list="$failed_list"$'\n'"  $md"
  fi
done < <(find "$ROOT" -type f -name '*.md' -not -path '*/.git/*' -print0)

echo ">> done: $converted converted, $failed failed"
[ "$failed" -gt 0 ] && printf 'failed files:%s\n' "$failed_list" >&2
