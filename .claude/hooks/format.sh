#!/usr/bin/env bash
# format: PostToolUse hook (matcher: Edit|Write|MultiEdit).
# Прогоняет Biome по изменённому файлу. Информационный хук: без jq или Biome
# молча пропускает (fail-closed здесь не нужен — ничего не защищает).

set -uo pipefail

command -v jq >/dev/null 2>&1 || exit 0

file=$(jq -r '.tool_input.file_path // empty' 2>/dev/null)
[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.mdx|*.css)
    ;;
  *)
    exit 0
    ;;
esac

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
[ ! -f "$root/package.json" ] && exit 0

cd "$root" || exit 0
if [ -x "node_modules/.bin/biome" ]; then
  node_modules/.bin/biome check --write --no-errors-on-unmatched "$file" 2>/dev/null || true
fi

exit 0
