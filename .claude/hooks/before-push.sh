#!/usr/bin/env bash
# before-push: PreToolUse hook (matcher: Bash|PowerShell).
# 1) Блокирует `git push` / `gh pr` / `gh repo`, если активный gh-аккаунт
#    не совпадает с владельцем remote-а (несколько gh-логинов = риск push не туда).
# 2) Гейт перед `git push`: pnpm typecheck (+ pnpm lint, если скрипт есть).
#    Обход осознанно: SKIP_PUSH_GATE=1 git push ...
# fail-closed: без jq вход не разобрать — блокируем.

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "before-push: guard disabled: install jq (fail-closed — команда заблокирована)" >&2
  exit 2
fi

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

is_git_push=false
if echo "$cmd" | grep -Eq '(^|[[:space:];&|`(]+)git[[:space:]]+push([[:space:]]|$)'; then
  is_git_push=true
fi

# Только push-подобные команды. Консервативно, по границам слов —
# чтобы не ловить false positives ("grep git push" и т.п.).
if [ "$is_git_push" = false ] && \
   ! echo "$cmd" | grep -Eq '(^|[[:space:];&|`(]+)gh[[:space:]]+(pr[[:space:]]+(create|merge|review|edit|close|reopen)|repo[[:space:]]+(create|edit|delete|fork|sync|archive))([[:space:]]|$)'; then
  exit 0
fi

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root" || exit 0

# --- 1. gh-аккаунт vs владелец remote ---------------------------------------
if command -v gh >/dev/null 2>&1; then
  gh_user=$(gh api user --jq .login 2>/dev/null || true)
  remote_url=$(git remote get-url origin 2>/dev/null || true)
  if [ -n "$gh_user" ] && [ -n "$remote_url" ]; then
    owner=$(echo "$remote_url" | sed -nE 's#.*[/:]([^/:]+)/[^/]+(\.git)?$#\1#p')
    if [ -n "$owner" ] && [ "$gh_user" != "$owner" ]; then
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
  fi
fi

# --- 2. Гейт typecheck/lint перед git push -----------------------------------
# Обход: SKIP_PUSH_GATE=1 в самой команде или в окружении.
if [ "$is_git_push" = true ] \
   && [ "${SKIP_PUSH_GATE:-0}" != "1" ] \
   && ! printf '%s' "$cmd" | grep -q 'SKIP_PUSH_GATE=1' \
   && [ -f "$root/package.json" ] \
   && command -v pnpm >/dev/null 2>&1; then

  has_typecheck=$(jq -r '.scripts.typecheck // empty' "$root/package.json" 2>/dev/null)
  has_lint=$(jq -r '.scripts.lint // empty' "$root/package.json" 2>/dev/null)

  if [ -n "$has_typecheck" ]; then
    if ! out=$(pnpm typecheck 2>&1); then
      {
        echo "BLOCKED by before-push: pnpm typecheck провален — пушить нечего чинить на CI."
        echo "$out" | tail -30
        echo ""
        echo "Почини ошибки и повтори push. Обход (осознанно): SKIP_PUSH_GATE=1 git push ..."
      } >&2
      exit 2
    fi
  fi

  if [ -n "$has_lint" ]; then
    if ! out=$(pnpm lint 2>&1); then
      {
        echo "BLOCKED by before-push: pnpm lint провален."
        echo "$out" | tail -30
        echo ""
        echo "Почини ошибки и повтори push. Обход (осознанно): SKIP_PUSH_GATE=1 git push ..."
      } >&2
      exit 2
    fi
  fi
fi

exit 0
