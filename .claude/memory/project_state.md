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

**Bootstrap-refactor v3.0 — done.** Все 7 фаз закрыты (тег `v3.0` на `origin/main`). Bootstrap зафиксирован на v3.0. Следующий трек — ТЗ-2 (миграция живых проектов на v3.0) — запускается **в папках конкретных старых сайтов**, а не в bootstrap'е.

## Active spec

- File: N/A
- Status: refactor done
- Started/Finished: 2026-04-28 → 2026-04-29

## Blockers

— нет

## Next 1-3 steps

1. **Запустить ТЗ-2** в папке конкретного старого проекта: открой Claude-чат в `~/projects/{site}`, скажи: «Прочитай файл `~/ClaudeCode/web-dev-bootstrap/_BUILD/v3/02-migrate-existing-project.md` и выполни его на этом проекте. Сначала покажи план миграции, жди подтверждения.»
2. **Outstanding после v3.0** (не блокируют дальнейшую работу, но висят): регенерация `_BUILD/HOW-TO-START.docx` через pandoc + первый реальный push-based деплой на live-VPS (Phase 5 не обкатывалась).
3. **Точечные правки самого bootstrap'а** делаются как обычно: feature-ветка → squash PR → semver-тег `v3.0.x` / `v3.1` / и т.д.

## Session log

(новые записи добавляются сверху командой `/handoff`)

### Session 2026-04-29 — Phase 6 finalize + tag v3.0

**Done in this session:**
- Squash-merge PR [#12](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/12) (Phase 5 push-based deploy), тег `v3.0-deploy` поставлен и запушен.
- Phase 6 (8 атомарных коммитов в ветке `feat/v3.0-handoff-protocol`):
  - `feat(memory-template)` — реструктуризация `.claude/memory/project_state.md` под session-log формат + двойное назначение (bootstrap-refactor / site template).
  - `feat(commands)` — `.claude/commands/handoff.md`, `resume.md`, `catchup.md` (Claude Code Desktop сканирует папку автоматически).
  - `feat(stop-reminder)` — `.claude/hooks/stop-reminder.sh` + патч `session-start.sh` (запись sha в `/tmp/.claude-session-start-sha-$PPID`) + регистрация в `.claude/settings.json` под `Stop`. Sha-фильтр предотвращает спам напоминаний.
  - `docs(how-to-start)` — `_BUILD/HOW-TO-START.md` §§ 4–5 под `/handoff`+`/resume`, новые §§ 10–11 (миграция v2.x→v3 + обновление bootstrap'а), частые косяки.
  - `docs(claude-md-template)` — `_BUILD/claude-md-template.md` пересинхронизирован с `CLAUDE.md` (добавлена `## Automation rules`, версия комментария v3.0).
  - `docs(claude-md)` — секция `## Multi-Claude protocol` в `CLAUDE.md` и шаблоне.
  - `chore(final-check)` — `README.md` v2.3-dx → v3.0, `CLAUDE.md` BOOTSTRAP META обновлён, `docs/INDEX.md` automation-строка дополнена, в ТЗ-1 добавлен подраздел «Outstanding после v3.0».
  - `chore(memory)` — этот коммит (changelog v3.0 + project_state финал).

**Open at handoff:**
- Push ветки `feat/v3.0-handoff-protocol`, создать PR, squash-merge в main, тег `v3.0`. Это закроет Phase 6 на origin.
- (post-v3.0 outstanding) Регенерация `_BUILD/HOW-TO-START.docx` через pandoc.
- (post-v3.0 outstanding) Первый реальный push-based деплой на live-VPS.

**Uncommitted changes:** нет

**Resume hint:** Bootstrap v3.0 released. В bootstrap'е больше нет активных фаз. Следующая работа — в папках конкретных старых сайтов, через ТЗ-2 (`_BUILD/v3/02-migrate-existing-project.md`).

---

## Completed phases history

Подробности каждой фазы — `_BUILD/changelog.md`.

- **2026-04-29** — Фаза 6 (Multi-Claude handoff протокол + slash-команды + stop-reminder hook + HOW-TO-START финиш + claude-md-template sync) — done, тег `v3.0`. Ветка `feat/v3.0-handoff-protocol`, 8 атомарных коммитов.
- **2026-04-28** — Фаза 5 (push-based deploy + standalone + раздельные SSH-ключи) — done, тег `v3.0-deploy`. PR [#12](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/12), 9 атомарных коммитов. C-level backlog Фазы 1 (Caddy в `specs/01b` + `specs/14-migrate`, nginx-секции в `docs/performance.md` + `specs/11-performance.md`) закрыт здесь же. ⚠️ Реальный push-based деплой на live-VPS ещё не обкатан — фаза покрыта письменной верификацией и rollback-планом, первый реальный run будет happen-after-merge.
- **2026-04-28** — Фаза 4 (Next.js 16 паттерны: Server Actions, `use cache`, опциональный PPR, OKLCH в Tailwind v4) — done, тег `v3.0-next16`. PR [#11](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/11), 5 атомарных коммитов.
- **2026-04-28** — Фаза 3 (Cloudflare Turnstile в формах + Content Collections для MDX) — done, тег `v2.4`. PR [#10](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/10), 3 атомарных коммита.
- **2026-04-28** — Фаза 2 (Biome заменил ESLint+Prettier, pnpm заменил npm, mise заменил nvm, schema-dts для типобезопасных JSON-LD) — done, тег `v2.3-dx`. PR [#9](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/9), 8 атомарных коммитов.
- **2026-04-28** — Фаза 1 (Caddy вместо nginx+certbot, авто-HTTPS из коробки, multi-site через `Caddyfile.d/`) — done, тег `v2.3-caddy`. PR [#8](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/8), 11 атомарных коммитов.
- **2026-04-28** — Фаза 0 (P0 hotfix bundle, 12 точечных правок без архитектурных изменений) — done, тег `v2.2.2`. PR [#6](https://github.com/tem11134v2-cmd/web-dev-bootstrap/pull/6), 12 атомарных коммитов.
