---
name: project_state
description: Активная фаза/спека, блокеры, журнал сессий, история завершённого
type: project
---

<!--
Универсальный шаблон состояния проекта.

- Для самого `web-dev-bootstrap` (когда в нём идёт рефакторинг) — «Active phase» = имя фазы.
  Раздел «Completed phases history» хранит выполненные фазы со ссылкой на `_BUILD/changelog.md`.
- Для сайта, клонировавшего bootstrap (`gh repo create --template`) — стереть содержимое и
  заполнить под свой проект: «Active phase» = текущая спека (00–13), «Completed phases history»
  переименовать в «Completed specs history».

Обновляется триггерами из CLAUDE.md: после спеки/фазы, при `/handoff`, при изменении блокеров.
-->

# Project state

## Active phase

**Bootstrap-refactor v3.0 — Phase 6 (Multi-Claude handoff + HOW-TO-START + claude-md-template).** Финальная фаза рефакторинга. Целевой тег после фазы — `v3.0`. ТЗ: `_BUILD/v3/01-bootstrap-refactor.md` (раздел «Фаза 6», строки ~1052+). Feature-ветка: `feat/v3.0-handoff-protocol`.

## Active spec

- File: N/A (bootstrap-refactor идёт по фазам, не по спекам)
- Status: in progress
- Started: 2026-04-29

## Blockers

— нет

## Next 1-3 steps

1. Создать `.claude/commands/{handoff,resume,catchup}.md` (slash-команды для multi-Claude протокола).
2. Создать `.claude/hooks/stop-reminder.sh` + патч `session-start.sh` (запись sha в `/tmp/.claude-session-start-sha`) + регистрация в `.claude/settings.json` под `Stop`.
3. Финал: HOW-TO-START.md (§§ 1–7, 10), `claude-md-template.md` пересинхронизация с CLAUDE.md, секция `Multi-Claude protocol` в корневом CLAUDE.md, changelog `v3.0`, тег.

## Session log

(новые записи добавляются сверху командой `/handoff`)

<!--
Формат записи:

### Session YYYY-MM-DD HH:MM — короткая суть

**Done in this session:**
- что сделано
- файлы тронуты — точные пути

**Open at handoff:**
- что осталось — конкретно

**Uncommitted changes:** нет / есть (перечислить)

**Resume hint:** короткая подсказка для следующей сессии

---
-->

## Completed phases history

Подробности каждой фазы — `_BUILD/changelog.md`.

- **2026-04-28** — Фаза 5 (push-based deploy + standalone + раздельные SSH-ключи) — done, тег `v3.0-deploy`. PR [#12](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/12), 9 атомарных коммитов. C-level backlog Фазы 1 (Caddy в `specs/01b` + `specs/14-migrate`, nginx-секции в `docs/performance.md` + `specs/11-performance.md`) закрыт здесь же. ⚠️ Реальный push-based деплой на live-VPS ещё не обкатан — фаза покрыта письменной верификацией и rollback-планом, первый реальный run будет happen-after-merge.
- **2026-04-28** — Фаза 4 (Next.js 16 паттерны: Server Actions, `use cache`, опциональный PPR, OKLCH в Tailwind v4) — done, тег `v3.0-next16`. PR [#11](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/11), 5 атомарных коммитов.
- **2026-04-28** — Фаза 3 (Cloudflare Turnstile в формах + Content Collections для MDX) — done, тег `v2.4`. PR [#10](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/10), 3 атомарных коммита.
- **2026-04-28** — Фаза 2 (Biome заменил ESLint+Prettier, pnpm заменил npm, mise заменил nvm, schema-dts для типобезопасных JSON-LD) — done, тег `v2.3-dx`. PR [#9](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/9), 8 атомарных коммитов.
- **2026-04-28** — Фаза 1 (Caddy вместо nginx+certbot, авто-HTTPS из коробки, multi-site через `Caddyfile.d/`) — done, тег `v2.3-caddy`. PR [#8](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/8), 11 атомарных коммитов.
- **2026-04-28** — Фаза 0 (P0 hotfix bundle, 12 точечных правок без архитектурных изменений) — done, тег `v2.2.2`. PR [#6](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/6), 12 атомарных коммитов.
