#!/usr/bin/env bash
file=$(jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0
[ ! -f "$file" ] && exit 0

case "$file" in
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.mdx|*.css)
    ;;
  *)
    exit 0
    ;;
esac

root="$(cd "$(dirname "$0")/../.." && pwd)"
[ ! -f "$root/package.json" ] && exit 0

cd "$root" || exit 0
if [ -x "node_modules/.bin/prettier" ]; then
  node_modules/.bin/prettier --write --log-level=silent "$file" 2>/dev/null || true
fi

exit 0
