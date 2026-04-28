---
name: project_state
description: Активная фаза bootstrap-refactor (v3.0) и история фаз
type: project
---

# Активное состояние проекта

> Этот файл — для самого `web-dev-bootstrap` (мы в канонической папке шаблона).
> Когда шаблон клонируется в реальный сайт, файл перезаписывается под формат «спеки 00–13».

## Текущая фаза bootstrap-refactor (v3.0)

- **Активная:** Фаза 5 — Push-based deploy + standalone + раздельные ключи (build на GitHub runner → rsync артефакта → атомарный switch симлинком)
- **ТЗ:** `_BUILD/v3/01-bootstrap-refactor.md` (раздел «Фаза 5», начиная со строки ~784)
- **Feature-ветка следующей сессии:** `feat/v3.0-push-deploy`
- **Целевой тег после фазы:** `v3.0-deploy`
- **Сложность:** **высокая** — самая рискованная фаза, без обкатки на тестовом VPS. Sub-phases 5.1–5.8 каждая отдельным коммитом, см. ТЗ.

## История фаз

- 2026-04-28 — **Фаза 4 (Next.js 16 паттерны) — done**, тег `v3.0-next16`. PR в ветке `feat/v3.0-next16-patterns`. 5 атомарных коммитов: feat(server-actions) — миграция лид-форм с `app/api/lead/route.ts` на Server Action `app/actions/submit-lead.ts` (`useActionState` + `<form action={formAction}>`, типизированный `LeadState`, прогрессивное улучшение, CSRF из коробки; полностью переписан `docs/forms-and-crm.md` и `specs/09`, обновлены `CLAUDE.md` / `claude-md-template.md` / `docs/architecture.md` / `docs/INDEX.md` / `specs/INDEX.md` / `specs/12-handoff.md` / `specs/optional/opt-quiz.md` / `.claude/memory/pointers.md`); `useOptimistic` как опциональный паттерн добавлен попутно в `docs/forms-and-crm.md` с явной заметкой что для лид-формы не нужен (fallback в JSON и так делает её всегда успешной). feat(use-cache) — раздел про директиву `use cache` в `docs/performance.md` § 7 с явными критериями где НЕ применять (per-request state, cookies/headers/searchParams) и упоминаниями в `specs/05` (для тяжёлых server-компонентов) + `specs/07` (callout, что поверх Content Collections обычно избыточно). feat(ppr) — Partial Prerendering как опциональный паттерн в `docs/architecture.md` (только для лендингов с гибридным static+dynamic), `experimental.ppr: 'incremental'` в шаблоне `next.config.ts` в `specs/02` (opt-in per-route через `experimental_ppr = true`). feat(oklch) — OKLCH как дефолтное цветовое пространство для палитр Tailwind v4 в `docs/design-system.md` (4 причины: предсказуемое осветление, плавные градиенты, перцептивно ровный hover, P3-гаммы) + перепись шагов 1–3 в `specs/03` (HEX в комментариях для сверки с брифом, токены через `@theme` в `globals.css` без `tailwind.config.ts`). chore(memory) — changelog v3.0-next16 + этот файл. Сам bootstrap ничего не билдит — изменения проявятся в новых проектах из шаблона.
- 2026-04-28 — **Фаза 3 (Turnstile + Content Collections) — done**, тег `v2.4`. PR в ветке `feat/v2.4-turnstile-content-collections`. 3 атомарных коммита: feat(turnstile) — Cloudflare Turnstile в формах (`@marsidev/react-turnstile` клиент + verify ДО CRM в /api/lead, новый раздел в docs/forms-and-crm.md, отдельная секция «1. Cloudflare Turnstile» в specs/09 и Turnstile-edge-кейсы в тестировании, добавлен в init-команду stack.md и spec/02), feat(content-collections) — полный rewrite specs/07 под Content Collections (Zod-схема в content-collections.ts, withContentCollections(nextConfig), типизированный allPosts, <MDXContent /> для рендера; обновлены docs/architecture.md и docs/stack.md, в pointers.md новый раздел «Контент»; CC ставится опционально только в spec/07, из дефолтного init убран вместе со старыми next-mdx-remote+gray-matter), chore(memory) — changelog v2.4 + project_state. Сам bootstrap ничего не билдит — изменения проявятся в новых проектах из шаблона.
- 2026-04-28 — **Фаза 2 (DX win) — done**, тег `v2.3-dx`. PR в ветке `feat/v2.3-dx-biome-pnpm-mise`. 8 атомарных коммитов: feat(biome) — Biome заменил ESLint+Prettier (один бинарник, useSortedClasses для Tailwind, biome.json.example в корне, format.sh hook), chore(pnpm) ×2 — sweep по specs/ и docs/scripts/CLAUDE.md (npm install → pnpm add, npm ci → pnpm install --frozen-lockfile, npm run X → pnpm X), feat(pnpm) — corepack на VPS (bootstrap-vps.sh) и на Mac (HOW-TO-START § 0.4), feat(mise) — `.tool-versions` вместо `.nvmrc`, mise activate в zshrc, feat(schema-dts) — типобезопасные WithContext<T> в lib/schema.ts (specs/05 + 08), chore(severity) — Stack/Commands/Версия в CLAUDE.md, claude-md-template, README (поднял до v2.3-dx, Phase 1 не делала). Сам bootstrap ничего не билдит — изменения проявятся в новых проектах из шаблона.
- 2026-04-28 — **Фаза 1 (Caddy) — done**, тег `v2.3-caddy`. PR в ветке `feat/v2.3-caddy`. 11 атомарных коммитов: bootstrap-vps.sh (apt-репо Caddy + `CADDY_ADMIN_EMAIL`), server-manual-setup, server-add-site (Caddy-шаблон с reverse_proxy + encode + cache headers), server-multisite (Caddyfile.d), deploy.md, troubleshooting.md (Caddy startup + SSL разделы), specs/12-handoff (Caddy в runbook), changelog, project_state, severity-A (stack-строки CLAUDE.md / claude-md-template / references.md), severity-B (README, docs/INDEX, scripts/README, domain-connect, seo, specs/02/08, optional/opt-i18n + opt-migrate). C-level отложено: `specs/01b` (генератор шаблона), `specs/14-migrate` (runbook), `docs/performance.md` + `specs/11-performance.md` (nginx-секции).
- 2026-04-28 — **Фаза 0 (P0 hotfixes) — done**, тег `v2.2.2`. PR #6 (squash `660a108`). 12 атомарных коммитов: compress-images, localhost:4000, версии, migration-map, схемы A/B, ConsultationDialog spec, /privacy в footer, hooks.json→settings.json, scripts/README дополнен, Zod→Valibot убран, IDEAS.md убран, changelog v2.2.2.

## C-level backlog после Фаз 1–2

Накопленные структурные правки, не вошедшие в `v2.3-caddy` и `v2.3-dx` потому что каждая — отдельный кусок работы. Делать в одну из следующих фаз или отдельным P1-bundle'ом:

1. **`specs/01b-server-handoff.md`** — спека генерирует `deploy/nginx.conf.example`. Под Caddy переписать на `deploy/{site}.caddy.example` с шаблоном из `docs/server-add-site.md`. Меняется и acceptance criteria, и код-генератор внутри спеки. **Будет затронуто в Фазе 5** (sub-phase 5.7) — там как раз переписывается `01b-server-handoff.md` под push-deploy, можно одновременно перевести на Caddy.
2. **`specs/14-migrate.md`** — миграционный runbook (M1–M4): несколько `certbot --nginx -d`, `nginx -t`, `rm /etc/nginx/sites-enabled/{site}`. Под Caddy упрощается (SSL автоматический, конфиг — один файл в Caddyfile.d/), но runbook нужно перепроверить пошагово. **Будет затронуто в Фазе 5** (sub-phase 5.7) — там и до Caddy, и до push-deploy за один проход.
3. **`docs/performance.md` § 7–8** + **`specs/11-performance.md` § 9** — секции «Серверная оптимизация (nginx)» / «Nginx-уровень» с gzip_static, brotli, Cache-Control. Caddy делает это через `encode gzip zstd` + `header @static Cache-Control` (уже в шаблоне). Секции нужно либо сократить до «как проверить, что Caddy всё это уже делает», либо переписать под Caddy-флаги. **Не вошло в Фазу 4** (scope ограничен Next 16 паттернами). Уместно в Фазе 5 как 5.8 (`docs/troubleshooting.md` всё равно правится) или отдельным P1-bundle'ом.

## Что делать в новой сессии (Фаза 5)

1. `pwd` — если в worktree, проверить sync с `origin/main` (`git fetch && git status`).
2. Если ветка автогенерёная (`claude/<имя>`) — `git branch -m feat/v3.0-push-deploy`.
3. `git tag pre-phase-5` — точка отката.
4. Прочитать раздел «Фаза 5» из `_BUILD/v3/01-bootstrap-refactor.md` (начиная со строки ~784) и KB-файлы оттуда (`docs/deploy.md`, `scripts/bootstrap-vps.sh`, `scripts/rollback.sh`, `scripts/sync-env.sh`, `specs/01b-server-handoff.md`, `specs/12-handoff.md`, `specs/14-migrate.md`, `docs/automation.md`, внешние https://nextjs.org/docs/app/getting-started/deploying и https://nextjs.org/docs/messages/install-sharp).
5. **Sub-phases 5.1–5.8 — каждая отдельным коммитом**, не сливать в один. Это самая рискованная фаза (push-deploy без обкатки на тестовом VPS), пользователь готов править ошибки на лету.
6. Показать план фазы и подтверждение каждой sub-phase — ждать ОК.

**Контекст для Фазы 5:**

- **Что меняется в архитектуре деплоя:** pull-based (Actions → SSH → git pull → `pnpm install` + `pnpm build` на VPS → `pm2 restart`) → push-based (build на GitHub runner → rsync артефакта `releases/<sha>/` на VPS → атомарный switch симлинка `current/` → `pm2 reload`). Преимущества: VPS больше не нужен Node toolchain (только runtime `node` + `pm2`), git с VPS можно убрать, ключи раздельные (приватный только в GitHub Secrets).
- **`output: 'standalone'`** возвращается в `next.config.ts` (раньше было убрано в v2.0 как лишнее при pull-based + `next start`). Под push-based deploy standalone-сборка нужна, чтобы rsync был компактным (`.next/standalone/` + `.next/static/` + `public/` — без `node_modules` целиком).
- **Раздельные SSH-ключи:** до сих пор был один `deploy_key` для git fetch + Actions SSH. Теперь Actions использует свой ключ (приватный в GitHub Secrets, публичный в `authorized_keys` на VPS), git с VPS можно убрать совсем (push-based не требует git pull на VPS).
- **`.env` через GitHub Environment Secrets** вместо `scripts/sync-env.sh` (`sync-env.sh` оставить как fallback инструмент или удалить — обсуждается в sub-phase 5.6).
- **C-level backlog** (Caddy в `specs/01b` и `specs/14-migrate`) удобно закрыть в sub-phase 5.7 — там и так переписываются эти спеки под push-deploy.
- **Возможно расширение scope:** `docs/performance.md` § 7–8 + `specs/11-performance.md` § 9 (nginx-секции → Caddy) — в sub-phase 5.8, либо отдельным P1-bundle'ом если Фаза 5 уже разрослась.

## Блокеры

— нет
