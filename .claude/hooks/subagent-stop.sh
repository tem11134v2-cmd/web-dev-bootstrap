#!/usr/bin/env bash
# subagent-stop: SubagentStop hook.
# Гейт после каждого субагента (см. docs/orchestration.md § Гейты):
# если в корне проекта есть package.json со скриптом typecheck — прогоняет
# `pnpm typecheck` (и `pnpm lint`, если скрипт есть). Провал → exit 2 с
# выжимкой ошибок — субагент чинит ДО передачи отчёта оркестратору.
# Нет package.json или pnpm — тихий exit 0 (bootstrap-репо, не-Node проект).
# Обход осознанно: SKIP_SUBAGENT_GATE=1
# fail-closed: без jq package.json не разобрать — блокируем.

set -uo pipefail

# Обход-рубильник работает и без jq — это escape hatch.
if [ "${SKIP_SUBAGENT_GATE:-0}" = "1" ]; then
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "subagent-stop: guard disabled: install jq (fail-closed — гейт блокирует)" >&2
  exit 2
fi

root="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
cd "$root" || exit 0

# Не Node-проект / bootstrap-репо / pnpm не установлен — гейтить нечего.
[ -f "$root/package.json" ] || exit 0
command -v pnpm >/dev/null 2>&1 || exit 0

has_typecheck=$(jq -r '.scripts.typecheck // empty' "$root/package.json" 2>/dev/null)
has_lint=$(jq -r '.scripts.lint // empty' "$root/package.json" 2>/dev/null)

if [ -n "$has_typecheck" ]; then
  if ! out=$(pnpm typecheck 2>&1); then
    {
      echo "BLOCKED by subagent-stop: pnpm typecheck провален — почини до передачи отчёта оркестратору."
      echo "$out" | tail -30
      echo ""
      echo "Обход (осознанно): SKIP_SUBAGENT_GATE=1"
    } >&2
    exit 2
  fi
fi

if [ -n "$has_lint" ]; then
  if ! out=$(pnpm lint 2>&1); then
    {
      echo "BLOCKED by subagent-stop: pnpm lint провален — почини до передачи отчёта оркестратору."
      echo "$out" | tail -30
      echo ""
      echo "Обход (осознанно): SKIP_SUBAGENT_GATE=1"
    } >&2
    exit 2
  fi
fi

exit 0
