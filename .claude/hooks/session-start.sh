#!/usr/bin/env bash
# session-start: информационные проверки при старте сессии Claude.
# Никогда не блокирует (всегда exit 0).
# ВАЖНО: весь вывод — в stdout. У SessionStart-хука stdout попадает в контекст
# Claude; stderr при exit 0 не видит никто.

set -uo pipefail

# session_id — из stdin-JSON хука; fallback на PPID, если jq недоступен.
input=$(cat 2>/dev/null || true)
session_id=""
if command -v jq >/dev/null 2>&1; then
  session_id=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
fi
[ -z "$session_id" ] && session_id="$PPID"

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root" || exit 0

# Не git-репо — выходим.
git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# Фиксируем HEAD на старте сессии, чтобы stop-reminder.sh видел коммиты сессии.
# .claude/state/ в .gitignore; файл на session_id изолирует параллельные сессии.
state_dir="$root/.claude/state"
mkdir -p "$state_dir" 2>/dev/null || true
git rev-parse HEAD 2>/dev/null > "$state_dir/session-start-sha-$session_id" || true

warnings=()

# 1. Ветка отстала от upstream.
# fetch под timeout 10 и без интерактивных промптов — машины бывают за прокси,
# старт сессии не должен виснуть.
fetch_ok=false
if command -v timeout >/dev/null 2>&1; then
  GIT_TERMINAL_PROMPT=0 timeout 10 git fetch origin --quiet 2>/dev/null && fetch_ok=true
else
  GIT_TERMINAL_PROMPT=0 git fetch origin --quiet 2>/dev/null && fetch_ok=true
fi
if [ "$fetch_ok" = true ]; then
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)
  if [ -n "$upstream" ]; then
    behind=$(git rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)
    if [ "$behind" -gt 0 ] 2>/dev/null; then
      branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
      warnings+=("Branch '$branch' is behind '$upstream' by $behind commit(s). Suggest: git pull")
    fi
  fi
fi

# 2. Uncommitted changes.
dirty=$(git status --porcelain 2>/dev/null | head -10)
if [ -n "$dirty" ]; then
  count=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  warnings+=("Uncommitted changes ($count file(s)):
$dirty")
fi

# 3. Активный gh-аккаунт vs владелец remote.
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
  echo "[session-start hook]"
  for w in "${warnings[@]}"; do
    echo "  - $w"
  done
fi

exit 0
