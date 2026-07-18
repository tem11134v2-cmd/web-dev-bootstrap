---
name: project_state
description: Активная фаза/спека, блокеры, Task ledger, журнал сессий
type: project
---

<!--
Чистый шаблон состояния проекта. Спека 00-brief нулевым шагом заполняет его
под новый проект: реальное имя, Active phase = 00-brief, пустой Session log.

Правило ротации: Session log храни ≤15 записей; старше — переноси в
`memory/archive/session-log-YYYY-MM.md` (папку создать при первом переносе).

Обновляется триггерами из CLAUDE.md: после спеки/фазы, при `/handoff`,
при изменении блокеров.
-->

# Project state

## Active phase

**Не начато.** Первая спека — `specs/00-brief.md` (она же обнуляет этот файл под проект).

## Active spec

- File: —
- Status: —
- Started/Finished: —

## Blockers

— нет

## Next 1-3 steps

1. Запустить `specs/00-brief.md`.

## Task ledger

Для оркестраторных волн (см. `docs/orchestration.md`): оркестратор ведёт таблицу задач волны. В интерактивном режиме можно не вести.

| Задача | Агент/модель | Статус | Верификация | Коммиты |
|---|---|---|---|---|

## Session log

(новые записи добавляются сверху командой `/handoff`; ≤15 записей, старше — в `memory/archive/session-log-YYYY-MM.md`)

## Completed specs history

(спека — дата — тег/PR)
