---
name: project_state
description: Активная фаза bootstrap-refactor (v3.0) и история фаз
type: project
---

# Активное состояние проекта

> Этот файл — для самого `web-dev-bootstrap` (мы в канонической папке шаблона).
> Когда шаблон клонируется в реальный сайт, файл перезаписывается под формат «спеки 00–13».

## Текущая фаза bootstrap-refactor (v3.0)

- **Активная:** Фаза 1 — Caddy вместо nginx+certbot
- **ТЗ:** `_BUILD/v3/01-bootstrap-refactor.md`
- **Feature-ветка следующей сессии:** `feat/v2.3-caddy`
- **Целевой тег после фазы:** `v2.3-caddy`

## История фаз

- 2026-04-28 — **Фаза 0 (P0 hotfixes) — done**, тег `v2.2.2`. PR #6 (squash `660a108`). 12 атомарных коммитов: compress-images, localhost:4000, версии, migration-map, схемы A/B, ConsultationDialog spec, /privacy в footer, hooks.json→settings.json, scripts/README дополнен, Zod→Valibot убран, IDEAS.md убран, changelog v2.2.2.

## Что делать в новой сессии (Фаза 1)

1. `pwd` — если в worktree, проверить sync с `origin/main` (`git fetch && git status`).
2. Если ветка автогенерёная (`claude/<имя>`) — `git branch -m feat/v2.3-caddy`.
3. `git tag pre-phase-1` — точка отката.
4. Прочитать раздел «Фаза 1» из `_BUILD/v3/01-bootstrap-refactor.md` (≈ строки 235–349) и KB-файлы оттуда (`scripts/bootstrap-vps.sh`, `docs/server-manual-setup.md`, `docs/server-add-site.md`, `docs/server-multisite.md`, `docs/deploy.md`, `docs/troubleshooting.md`).
5. Показать план фазы — ждать подтверждения.

## Блокеры

— нет
