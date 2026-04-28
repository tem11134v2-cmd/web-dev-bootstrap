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

- 2026-04-28 — **Фаза 1 (Caddy) — done**, тег `v2.3-caddy`. PR в ветке `feat/v2.3-caddy`. 11 атомарных коммитов: bootstrap-vps.sh (apt-репо Caddy + `CADDY_ADMIN_EMAIL`), server-manual-setup, server-add-site (Caddy-шаблон с reverse_proxy + encode + cache headers), server-multisite (Caddyfile.d), deploy.md, troubleshooting.md (Caddy startup + SSL разделы), specs/12-handoff (Caddy в runbook), changelog, project_state, severity-A (stack-строки CLAUDE.md / claude-md-template / references.md), severity-B (README, docs/INDEX, scripts/README, domain-connect, seo, specs/02/08, optional/opt-i18n + opt-migrate). C-level отложено: `specs/01b` (генератор шаблона), `specs/14-migrate` (runbook), `docs/performance.md` + `specs/11-performance.md` (nginx-секции).
- 2026-04-28 — **Фаза 0 (P0 hotfixes) — done**, тег `v2.2.2`. PR #6 (squash `660a108`). 12 атомарных коммитов: compress-images, localhost:4000, версии, migration-map, схемы A/B, ConsultationDialog spec, /privacy в footer, hooks.json→settings.json, scripts/README дополнен, Zod→Valibot убран, IDEAS.md убран, changelog v2.2.2.

## C-level backlog после Фазы 1 (Caddy)

Накопленные структурные правки, не вошедшие в `v2.3-caddy` потому что каждая — отдельный кусок работы. Делать в одну из следующих фаз или отдельным P1-bundle'ом:

1. **`specs/01b-server-handoff.md`** — спека генерирует `deploy/nginx.conf.example`. Под Caddy переписать на `deploy/{site}.caddy.example` с шаблоном из `docs/server-add-site.md`. Меняется и acceptance criteria, и код-генератор внутри спеки.
2. **`specs/14-migrate.md`** — миграционный runbook (M1–M4): несколько `certbot --nginx -d`, `nginx -t`, `rm /etc/nginx/sites-enabled/{site}`. Под Caddy упрощается (SSL автоматический, конфиг — один файл в Caddyfile.d/), но runbook нужно перепроверить пошагово.
3. **`docs/performance.md` § 7–8** + **`specs/11-performance.md` § 9** — секции «Серверная оптимизация (nginx)» / «Nginx-уровень» с gzip_static, brotli, Cache-Control. Caddy делает это через `encode gzip zstd` + `header @static Cache-Control` (уже в шаблоне). Секции нужно либо сократить до «как проверить, что Caddy всё это уже делает», либо переписать под Caddy-флаги. Уместнее в Фазе 4 (Next.js 16 паттерны) — там уже идёт перформанс-ревизия.

## Что делать в новой сессии (Фаза 2)

1. `pwd` — если в worktree, проверить sync с `origin/main` (`git fetch && git status`).
2. Если ветка автогенерёная (`claude/<имя>`) — `git branch -m feat/v2.3-dx-biome-pnpm-mise`.
3. `git tag pre-phase-2` — точка отката.
4. Прочитать раздел «Фаза 2» из `_BUILD/v3/01-bootstrap-refactor.md` (≈ строки 352–510) и KB-файлы оттуда (`docs/stack.md`, `specs/01a-local-setup.md`, `specs/02-project-init.md`, `_BUILD/HOW-TO-START.md` § 0.4, `.claude/hooks/format.sh`, `CLAUDE.md` § Commands).
5. Показать план фазы — ждать подтверждения.

## Блокеры

— нет
