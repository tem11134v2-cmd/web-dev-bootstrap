#!/usr/bin/env bash
# Stop hook: reminds to update .claude/memory/project_state.md if commits were made this session.
# Stop event fires at the end of EVERY Claude response — without the sha-diff filter,
# the user would see the reminder after every reply (spam). Filter ensures it shows
# only when HEAD actually moved compared to session start.
#
# Never blocks (exit 0 always). Prints reminder to stderr so Claude sees it.

set -uo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root" || exit 0

# Skip if not a git repo.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

session_start_file="/tmp/.claude-session-start-sha-$PPID"
[ -f "$session_start_file" ] || exit 0

session_start_sha=$(cat "$session_start_file" 2>/dev/null || echo "")
current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")

if [ -n "$session_start_sha" ] && [ -n "$current_sha" ] && [ "$session_start_sha" != "$current_sha" ]; then
  short_start=$(git rev-parse --short "$session_start_sha" 2>/dev/null || echo "$session_start_sha")
  short_current=$(git rev-parse --short "$current_sha" 2>/dev/null || echo "$current_sha")
  {
    echo "[stop-reminder]"
    echo "  В этой сессии были коммиты ($short_start → $short_current)."
    echo "  Если уходишь надолго — /handoff, чтобы обновить .claude/memory/project_state.md."
  } >&2
fi

exit 0
