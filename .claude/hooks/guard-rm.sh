#!/usr/bin/env bash
# guard-rm: PreToolUse hook (matcher: Bash|PowerShell). Блокирует деструктивные команды.
# fail-closed: без jq вход хука не разобрать — блокируем всё, а не пропускаем всё.
# Проверка обвязки: bash .claude/hooks/test-hooks.sh

set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "guard-rm: guard disabled: install jq (fail-closed — команда заблокирована)" >&2
  exit 2
fi

cmd=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$cmd" ] && exit 0

block() {
  {
    echo "BLOCKED by guard-rm: $1"
    echo "  command: $cmd"
  } >&2
  exit 2
}

# Снимаем кавычки, чтобы ловить rm -rf "$HOME", "./*" и т.п.
nq=$(printf '%s' "$cmd" | tr -d "\"'")

# --- rm на опасную цель: /, /*, ~, $HOME, *, ./* ---------------------------
# Флаги не проверяем: rm по опасной цели опасен в любом порядке флагов
# (-rf, -fr, -f -r, --recursive --force) и даже без них.
if printf '%s' "$nq" | grep -Eq '(^|[[:space:];&|(`])rm[[:space:]]'; then
  if printf '%s' "$nq" | grep -Eq '(^|[[:space:]])(/\*|\./\*|/|~|\$HOME|\*)(/|[[:space:]]|;|$)'; then
    block "rm по /, ~, \$HOME или глобу (*, ./*) запрещён"
  fi
fi

# --- git push --force / -f / +refspec (force-with-lease разрешён) -----------
pushseg=$(printf '%s' "$nq" | grep -Eo 'git[[:space:]]+push[^;|&]*' || true)
if [ -n "$pushseg" ]; then
  seg=$(printf '%s' "$pushseg" | sed -E 's/--force-with-lease(=[^[:space:]]+)?//g; s/--force-if-includes//g')
  if printf '%s' "$seg" | grep -Eq '(^|[[:space:]])(--force|-[a-zA-Z]*f[a-zA-Z]*)([[:space:]]|$)'; then
    block "git push --force/-f запрещён (безопасная альтернатива: --force-with-lease)"
  fi
  if printf '%s' "$seg" | grep -Eq '[[:space:]]\+[^[:space:]]'; then
    block "git push с +refspec (push origin +main) — это тот же force push"
  fi
fi

# --- git clean -fd / -fdx (в любом порядке, раздельно или слитно) -----------
cleanseg=$(printf '%s' "$nq" | grep -Eo 'git[[:space:]]+clean[^;|&]*' || true)
if [ -n "$cleanseg" ]; then
  if printf '%s' "$cleanseg" | grep -Eq '(^|[[:space:]])(--force|-[a-zA-Z]*f[a-zA-Z]*)' \
     && printf '%s' "$cleanseg" | grep -Eq '(^|[[:space:]])-[a-zA-Z]*d'; then
    block "git clean -fd/-fdx удаляет неотслеживаемые файлы безвозвратно"
  fi
fi

# --- git reset --hard / git checkout -- . -----------------------------------
if printf '%s' "$nq" | grep -Eq 'git[[:space:]]+reset[^;|&]*--hard'; then
  block "git reset --hard стирает незакоммиченные изменения"
fi
if printf '%s' "$nq" | grep -Eq 'git[[:space:]]+checkout[[:space:]][^;|&]*--[[:space:]]+\.([[:space:]]|;|$)'; then
  block "git checkout -- . стирает незакоммиченные изменения"
fi

# --- find ... -delete --------------------------------------------------------
if printf '%s' "$nq" | grep -Eq '(^|[[:space:];&|(`])find[[:space:]][^;|&]*-delete'; then
  block "find -delete — массовое удаление, сделай сперва find без -delete и покажи список"
fi

# --- PowerShell: Remove-Item/rm/ri -Recurse -Force ---------------------------
# Одинарный дефис отличает PS-флаги от bash long-форм (--recursive/--force не матчатся).
if printf '%s' "$nq" | grep -Eiq '(^|[[:space:];&|(])(remove-item|rm|ri)[[:space:]]'; then
  if printf '%s' "$nq" | grep -Eiq '(^|[[:space:]])-recurse([[:space:]:]|$)' \
     && printf '%s' "$nq" | grep -Eiq '(^|[[:space:]])-force([[:space:]:]|$)'; then
    block "Remove-Item -Recurse -Force (или алиас rm/ri) запрещён"
  fi
fi

# --- rd /s | rmdir /s (cmd-стиль) --------------------------------------------
if printf '%s' "$nq" | grep -Eiq '(^|[[:space:];&|(])(rd|rmdir)[[:space:]]+/s'; then
  block "rd /s — рекурсивное удаление каталога"
fi

# --- Clear-Content на .env ---------------------------------------------------
if printf '%s' "$nq" | grep -Eiq '(^|[[:space:];&|(])(clear-content|clc)[[:space:]][^;|&]*\.env'; then
  block "Clear-Content на .env-файл — потеря секретов"
fi

exit 0
