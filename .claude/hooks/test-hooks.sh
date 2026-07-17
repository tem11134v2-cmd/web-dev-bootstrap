#!/usr/bin/env bash
# test-hooks: smoke-тест обвязки хуков. Подаёт фикстурные JSON на stdin,
# проверяет exit-коды. Запуск: bash .claude/hooks/test-hooks.sh
# Работает в git-bash на Windows (все хуки зовутся через `bash`, exec-бит не нужен).
#
# Без jq guard-хуки (guard-rm, before-push) обязаны падать fail-closed (exit 2)
# на ЛЮБОЙ команде — тест это ожидает и помечает PASS* с предупреждением.

set -uo pipefail

dir="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$dir/../.." && pwd)"
pass=0
fail=0

have_jq=true
command -v jq >/dev/null 2>&1 || have_jq=false

mkjson() { # $1 = команда → JSON PreToolUse-фикстуры
  if [ "$have_jq" = true ]; then
    jq -n --arg c "$1" '{tool_name:"Bash", tool_input:{command:$c}}'
  else
    # без jq guard-хуки не дойдут до парсинга — содержимое не важно
    printf '{"tool_input":{"command":"noop"}}'
  fi
}

report() { # $1 = PASS|PASS*|FAIL, $2 = описание
  if [ "$1" = FAIL ]; then
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
  printf '%-5s %s\n' "$1" "$2"
}

run_guard() { # $1 = хук, $2 = ожидаемый exit (0|2), $3 = команда
  local hook="$1" want="$2" cmd="$3" got
  mkjson "$cmd" | bash "$dir/$hook" >/dev/null 2>&1
  got=$?
  if [ "$have_jq" = false ]; then
    if [ "$got" -eq 2 ]; then
      report "PASS*" "$hook :: [$cmd] — jq нет, fail-closed exit 2 (ожидаемо)"
    else
      report FAIL "$hook :: [$cmd] — jq нет, ожидали fail-closed 2, получили $got"
    fi
    return
  fi
  if [ "$got" -eq "$want" ]; then
    report PASS "$hook :: exit $got [$cmd]"
  else
    report FAIL "$hook :: ожидали $want, получили $got [$cmd]"
  fi
}

echo "== guard-rm.sh: опасные команды (ожидаем блок, exit 2) =="
run_guard guard-rm.sh 2 'rm -rf /'
run_guard guard-rm.sh 2 'rm -fr ~'
run_guard guard-rm.sh 2 'rm -f -r "$HOME"'
run_guard guard-rm.sh 2 'rm --recursive --force ./*'
run_guard guard-rm.sh 2 'rm -rf *'
run_guard guard-rm.sh 2 'git push --force origin main'
run_guard guard-rm.sh 2 'git push -f'
run_guard guard-rm.sh 2 'git push origin +main'
run_guard guard-rm.sh 2 'git clean -fdx'
run_guard guard-rm.sh 2 'git clean -f -d'
run_guard guard-rm.sh 2 'git reset --hard HEAD~1'
run_guard guard-rm.sh 2 'git checkout -- .'
run_guard guard-rm.sh 2 "find . -name '*.log' -delete"
run_guard guard-rm.sh 2 'Remove-Item -Recurse -Force C:\tmp\x'
run_guard guard-rm.sh 2 'rm node_modules -Recurse -Force'
run_guard guard-rm.sh 2 'rd /s /q build'
run_guard guard-rm.sh 2 'Clear-Content .env'

echo ""
echo "== guard-rm.sh: безопасные команды (ожидаем пропуск, exit 0) =="
run_guard guard-rm.sh 0 'rm -rf node_modules'
run_guard guard-rm.sh 0 'rm dist/output.txt'
run_guard guard-rm.sh 0 'git push origin main'
run_guard guard-rm.sh 0 'git push --force-with-lease origin main'
run_guard guard-rm.sh 0 'git status'
run_guard guard-rm.sh 0 'ls -la'
run_guard guard-rm.sh 0 'Get-Content package.json'
run_guard guard-rm.sh 0 'Remove-Item build\tmp.txt'

echo ""
echo "== before-push.sh =="
run_guard before-push.sh 0 'ls -la'
run_guard before-push.sh 0 'git status'
# git push зависит от окружения (gh-аккаунт, typecheck) — валиден и 0, и 2;
# проверяем, что хук не падает с другим кодом (синтаксис, jq и т.п.).
if [ "$have_jq" = true ]; then
  mkjson 'git push origin main' | bash "$dir/before-push.sh" >/dev/null 2>&1
  got=$?
  if [ "$got" -eq 0 ] || [ "$got" -eq 2 ]; then
    report PASS "before-push.sh :: exit $got [git push origin main] (0 или 2 — оба валидны)"
  else
    report FAIL "before-push.sh :: неожиданный exit $got [git push origin main]"
  fi
else
  run_guard before-push.sh 2 'git push origin main'
fi

echo ""
echo "== subagent-stop.sh (гейт typecheck/lint после субагента) =="
tmp_gate="$(mktemp -d)"

# 1) Нет package.json в корне гейта → тихий exit 0 (без jq — fail-closed exit 2)
printf '{}' | CLAUDE_PROJECT_DIR="$tmp_gate" bash "$dir/subagent-stop.sh" >/dev/null 2>&1
got=$?
if [ "$have_jq" = false ]; then
  if [ "$got" -eq 2 ]; then
    report "PASS*" "subagent-stop.sh :: jq нет, fail-closed exit 2 (ожидаемо)"
  else
    report FAIL "subagent-stop.sh :: jq нет, ожидали fail-closed 2, получили $got"
  fi
elif [ "$got" -eq 0 ]; then
  report PASS "subagent-stop.sh :: exit 0 без package.json"
else
  report FAIL "subagent-stop.sh :: ожидали 0 без package.json, получили $got"
fi

# 2) Обход SKIP_SUBAGENT_GATE=1 → exit 0 всегда (даже без jq)
printf '{}' | SKIP_SUBAGENT_GATE=1 CLAUDE_PROJECT_DIR="$tmp_gate" bash "$dir/subagent-stop.sh" >/dev/null 2>&1
got=$?
if [ "$got" -eq 0 ]; then
  report PASS "subagent-stop.sh :: exit 0 при SKIP_SUBAGENT_GATE=1"
else
  report FAIL "subagent-stop.sh :: SKIP_SUBAGENT_GATE=1, ожидали 0, получили $got"
fi

# 3) package.json с провальным typecheck → exit 2 (только если есть jq и pnpm;
#    без pnpm хук обязан тихо пропустить — это тоже проверяем)
if [ "$have_jq" = true ]; then
  printf '{"name":"gate-fixture","scripts":{"typecheck":"exit 1"}}' > "$tmp_gate/package.json"
  printf '{}' | CLAUDE_PROJECT_DIR="$tmp_gate" bash "$dir/subagent-stop.sh" >/dev/null 2>&1
  got=$?
  if command -v pnpm >/dev/null 2>&1; then
    if [ "$got" -eq 2 ]; then
      report PASS "subagent-stop.sh :: exit 2 на провальном typecheck"
    else
      report FAIL "subagent-stop.sh :: ожидали 2 на провальном typecheck, получили $got"
    fi
  else
    if [ "$got" -eq 0 ]; then
      report PASS "subagent-stop.sh :: pnpm нет — тихий exit 0"
    else
      report FAIL "subagent-stop.sh :: pnpm нет, ожидали 0, получили $got"
    fi
  fi
fi

command rm -rf "$tmp_gate"

echo ""
echo "== format.sh / session-start.sh / stop-reminder.sh (информационные, всегда exit 0) =="
sid="test-hooks-fixture"
state_file="$root/.claude/state/session-start-sha-$sid"

printf '{"tool_input":{"file_path":"no-such-file.xyz"}}' | bash "$dir/format.sh" >/dev/null 2>&1 \
  && report PASS "format.sh :: exit 0 на несуществующем файле" \
  || report FAIL "format.sh :: exit $? вместо 0"

printf '{"session_id":"%s"}' "$sid" | bash "$dir/session-start.sh" >/dev/null 2>&1 \
  && report PASS "session-start.sh :: exit 0" \
  || report FAIL "session-start.sh :: exit $? вместо 0"

if [ "$have_jq" = true ] && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  if [ -f "$state_file" ]; then
    report PASS "session-start.sh :: state-файл создан ($state_file)"
  else
    report FAIL "session-start.sh :: state-файл не создан ($state_file)"
  fi

  # HEAD не двигался — stop-reminder молчит
  out=$(printf '{"session_id":"%s"}' "$sid" | bash "$dir/stop-reminder.sh" 2>/dev/null)
  if [ $? -eq 0 ] && [ -z "$out" ]; then
    report PASS "stop-reminder.sh :: молчит, когда HEAD не двигался"
  else
    report FAIL "stop-reminder.sh :: ожидали пустой stdout/exit 0, получили: $out"
  fi

  # Подменяем sha — stop-reminder обязан выдать systemMessage-JSON
  printf 'deadbeef' > "$state_file"
  out=$(printf '{"session_id":"%s"}' "$sid" | bash "$dir/stop-reminder.sh" 2>/dev/null)
  if [ $? -eq 0 ] && printf '%s' "$out" | grep -q '"systemMessage"'; then
    report PASS "stop-reminder.sh :: systemMessage при сдвиге HEAD"
  else
    report FAIL "stop-reminder.sh :: нет systemMessage при сдвиге HEAD (вывод: $out)"
  fi
fi

# Прибираем фикстурный state-файл
[ -f "$state_file" ] && command rm -f "$state_file"

echo ""
echo "===================="
echo "PASS: $pass  FAIL: $fail"
if [ "$have_jq" = false ]; then
  echo "ПРЕДУПРЕЖДЕНИЕ: jq не установлен — guard-хуки в fail-closed режиме (блокируют ВСЁ)."
  echo "Установи jq: winget install jqlang.jq (Windows) / brew install jq (Mac)."
fi
[ "$fail" -eq 0 ] && exit 0 || exit 1
