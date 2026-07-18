#!/usr/bin/env bash
# Stop hook: напоминает обновить .claude/memory/project_state.md, если в сессии были коммиты.
# Stop срабатывает после КАЖДОГО ответа Claude — без sha-фильтра напоминание
# сыпалось бы после каждой реплики. Фильтр: HEAD сейчас vs HEAD на SessionStart.
#
# ВАЖНО: у Stop-хука stdout/stderr при exit 0 не показываются никому.
# Единственный видимый канал — JSON с полем systemMessage в stdout
# (его видит человек в UI). Никогда не блокирует (всегда exit 0).

set -uo pipefail

# session_id — из stdin-JSON хука; fallback на PPID (тот же, что в session-start.sh).
input=$(cat 2>/dev/null || true)
session_id=""
if command -v jq >/dev/null 2>&1; then
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
fi
[ -z "$session_id" ] && session_id="$PPID"

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root" || exit 0

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

session_start_file="$root/.claude/state/session-start-sha-$session_id"
[ -f "$session_start_file" ] || exit 0

session_start_sha=$(cat "$session_start_file" 2>/dev/null || echo "")
current_sha=$(git rev-parse HEAD 2>/dev/null || echo "")

if [ -n "$session_start_sha" ] && [ -n "$current_sha" ] && [ "$session_start_sha" != "$current_sha" ]; then
  short_start=$(git rev-parse --short "$session_start_sha" 2>/dev/null || echo "$session_start_sha")
  short_current=$(git rev-parse --short "$current_sha" 2>/dev/null || echo "$current_sha")
  msg="В этой сессии были коммиты ($short_start → $short_current). Если уходишь надолго — /handoff, чтобы обновить .claude/memory/project_state.md."
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg msg "$msg" '{systemMessage: $msg}'
  else
    printf '{"systemMessage": "%s"}\n' "$msg"
  fi
fi

exit 0
