#!/usr/bin/env bash
# before-push: PreToolUse hook on Bash. Blocks `git push` / `gh pr` / `gh repo`
# when the active gh account does not match the current repo's owner. Prevents
# pushing to the wrong account when multiple gh logins are active.

set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && exit 0

# Only act on push-like commands. Be conservative: match the verbs explicitly
# at word boundaries to avoid false positives ("grep git push" etc.).
if ! echo "$cmd" | grep -Eq '(^|[[:space:];&|`(]+)(git[[:space:]]+push|gh[[:space:]]+pr[[:space:]]+(create|merge|review|edit|close|reopen)|gh[[:space:]]+repo[[:space:]]+(create|edit|delete|fork|sync|archive))([[:space:]]|$)'; then
  exit 0
fi

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root" || exit 0

if ! command -v gh >/dev/null 2>&1; then
  exit 0
fi

gh_user=$(gh api user --jq .login 2>/dev/null || true)
remote_url=$(git remote get-url origin 2>/dev/null || true)

if [ -z "$gh_user" ] || [ -z "$remote_url" ]; then
  exit 0
fi

owner=$(echo "$remote_url" | sed -nE 's#.*[/:]([^/:]+)/[^/]+(\.git)?$#\1#p')
if [ -z "$owner" ]; then
  exit 0
fi

if [ "$gh_user" != "$owner" ]; then
  cat >&2 <<EOF
BLOCKED by before-push: gh account mismatch.
  active gh account: $gh_user
  origin owner:      $owner
  command:           $cmd

This push would target a repo you may not have rights to (or worse, the wrong account).
Switch first:  gh auth switch -h github.com -u $owner
Then retry the push.
EOF
  exit 2
fi

exit 0
