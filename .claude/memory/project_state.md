---
name: project_state
description: Активная фаза bootstrap-refactor (v3.0) и история фаз
type: project
---

# Активное состояние проекта

> Этот файл — для самого `web-dev-bootstrap` (мы в канонической папке шаблона).
> Когда шаблон клонируется в реальный сайт, файл перезаписывается под формат «спеки 00–13».

## Текущая фаза bootstrap-refactor (v3.0)

- **Активная:** Фаза 2 — DX win: Biome, pnpm, mise, schema-dts
- **ТЗ:** `_BUILD/v3/01-bootstrap-refactor.md` (раздел «Фаза 2», ≈ строки 352–510)
- **Feature-ветка следующей сессии:** `feat/v2.3-dx-biome-pnpm-mise`
- **Целевой тег после фазы:** `v2.3-dx`

## История фаз

- 2026-04-28 — **Фаза 1 (Caddy) — done**, тег `v2.3-caddy`. PR в ветке `feat/v2.3-caddy`. 7 атомарных коммитов: bootstrap-vps.sh (apt-репо Caddy + email-параметр), server-manual-setup, server-add-site (Caddy-шаблон с reverse_proxy + encode + cache headers), server-multisite (Caddyfile.d), deploy.md, troubleshooting.md (Caddy startup + SSL разделы), specs/12-handoff (Caddy в runbook), changelog v2.3-caddy. Out-of-scope ~15 файлов (CLAUDE.md stack-строка, README, performance/seo/domain-connect, specs/01b/02/08/11/14, claude-md-template, references.md) — вынесено в P1-bundle следующих фаз.
- 2026-04-28 — **Фаза 0 (P0 hotfixes) — done**, тег `v2.2.2`. PR #6 (squash `660a108`). 12 атомарных коммитов: compress-images, localhost:4000, версии, migration-map, схемы A/B, ConsultationDialog spec, /privacy в footer, hooks.json→settings.json, scripts/README дополнен, Zod→Valibot убран, IDEAS.md убран, changelog v2.2.2.

## Что делать в новой сессии (Фаза 2)

1. `pwd` — если в worktree, проверить sync с `origin/main` (`git fetch && git status`).
2. Если ветка автогенерёная (`claude/<имя>`) — `git branch -m feat/v2.3-dx-biome-pnpm-mise`.
3. `git tag pre-phase-2` — точка отката.
4. Прочитать раздел «Фаза 2» из `_BUILD/v3/01-bootstrap-refactor.md` (≈ строки 352–510) и KB-файлы оттуда (`docs/stack.md`, `specs/01a-local-setup.md`, `specs/02-project-init.md`, `_BUILD/HOW-TO-START.md` § 0.4, `.claude/hooks/format.sh`, `CLAUDE.md` § Commands).
5. Показать план фазы — ждать подтверждения.

## Блокеры

— нет
