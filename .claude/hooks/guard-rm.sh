#!/usr/bin/env bash
cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

if echo "$cmd" | grep -Eq 'rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+)?(-[a-zA-Z]*[fF][a-zA-Z]*[[:space:]]+)?(/|~|\$HOME|\*)([[:space:]]|$|/)'; then
  echo "BLOCKED by guard-rm: refusing destructive rm on /, ~, \$HOME, or glob." >&2
  exit 2
fi

if echo "$cmd" | grep -Eq '(^|[;&|][[:space:]]*)git[[:space:]]+push[[:space:]]+[^"'"'"']*--force'; then
  echo "BLOCKED by guard-rm: refusing git push --force (use regular push)." >&2
  exit 2
fi

exit 0
