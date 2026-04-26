#!/usr/bin/env bash
# session-start: informational checks at the beginning of a Claude session.
# Never blocks (exit 0 always). Prints warnings to stderr so Claude sees them.

set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root" || exit 0

# Skip if not a git repo.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

warnings=()

# 1. Branch behind upstream
if git fetch origin --quiet 2>/dev/null; then
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -n "$upstream" ]; then
    behind=$(git rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)
    if [ "$behind" -gt 0 ] 2>/dev/null; then
      branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
      warnings+=("Branch '$branch' is behind '$upstream' by $behind commit(s). Suggest: git pull")
    fi
  fi
fi

# 2. Uncommitted changes
dirty=$(git status --porcelain 2>/dev/null | head -10)
if [ -n "$dirty" ]; then
  count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  warnings+=("Uncommitted changes ($count file(s)):
$dirty")
fi

# 3. gh active account vs remote owner mismatch
if command -v gh >/dev/null 2>&1; then
  gh_user=$(gh api user --jq .login 2>/dev/null || true)
  remote_url=$(git remote get-url origin 2>/dev/null || true)
  if [ -n "$gh_user" ] && [ -n "$remote_url" ]; then
    owner=$(echo "$remote_url" | sed -nE 's#.*[/:]([^/:]+)/[^/]+(\.git)?$#\1#p')
    if [ -n "$owner" ] && [ "$gh_user" != "$owner" ]; then
      warnings+=("gh active account is '$gh_user' but origin owner is '$owner'. Push will fail. Switch: gh auth switch -h github.com -u $owner")
    fi
  fi
fi

if [ ${#warnings[@]} -gt 0 ]; then
  {
    echo "[session-start hook]"
    for w in "${warnings[@]}"; do
      echo "  - $w"
    done
  } >&2
fi

exit 0
