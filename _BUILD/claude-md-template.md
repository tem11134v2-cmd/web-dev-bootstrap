<!--
CLAUDE.md template — скопируй как `CLAUDE.md` в корень нового проекта.
Замени все [плейсхолдеры] в квадратных скобках на значения проекта.
Секции «Stack», «Commands», «Testing» подстрой под реальный стек, если он отличается от дефолта (Next.js + Tailwind + shadcn).
После заполнения удали этот верхний HTML-комментарий.

Если сайт создан через `gh repo create --template` — корневой CLAUDE.md уже
приехал с репо, этот файл не нужен. Процедура тогда короче: в корневом
CLAUDE.md заполни `# Project:` реальным именем сайта и удали META-комментарий
из шапки (он для bootstrap-режима, сайту не нужен).
-->

# Project: [Name]

[One sentence: what this project is, who it's for, what's the main goal]

<!-- Пример: «migrator.me — посадочная сеть юридической фирмы по иммиграции в США, цель — собирать лиды на консультацию и вести их через квиз-калькулятор в воронку CRM.» -->

## Stack

<!-- Дефолт v4.0. Замени если другой стек. -->

Next.js 16 (App Router, Turbopack) + Tailwind v4 + shadcn/ui (base-ui) + TypeScript
Tooling: Biome (lint+format), pnpm (через corepack/mise), schema-dts для JSON-LD типов
Forms: React Hook Form + Zod → Server Action `submitLead` → multi-sink (Email / Google Sheets / Telegram / CRM) через `Promise.allSettled`, с JSONL-fallback если все упали; дефолт — «почта сегодня, остальное когда попросят»
Content: MDX (no database)
Dev: локально на Mac, `pnpm dev` на `localhost:3000`
Deploy: git push → GitHub Actions → PM2 + Caddy (встроенный ACME) на VPS (см. docs/deploy.md)

## Rules

- IMPORTANT: Always use plan mode (Shift+Tab×2) before coding
- Read relevant `docs/` files listed in spec's "KB files to read first" — never load all docs
- Read `.claude/memory/INDEX.md` at session start, then load only relevant memory files
- Work on `dev` branch, merge to `main` only via PR (`main` is protected). Never push to `main` directly
- После `gh pr merge` локальный `main` устарел — обновляйся только ребейзом на `origin/main` (`git fetch origin && git rebase origin/main`)
- Commit after each completed sub-task with English messages
- Max 150 lines per component — split if longer
- Примитивы (кнопки, инпуты, диалоги, табы, аккордеоны, карусель) — только shadcn/ui; секции — собственные композиции из них
- Tailwind only — no custom CSS, no CSS modules, no styled-components
- Mobile-first responsive design
- Server Components by default; `"use client"` only for state/effects/handlers

> **SSH-политика.** Claude ходит на VPS по SSH ключом разработчика (`~/.ssh/id_ed25519`) для: разовой настройки сервера (`docs/server-manual-setup.md`), подключения сайта (`docs/server-add-site.md`), проверок деплоя (read-only: `pm2 status`, `ls releases/`, `curl -I`), спек 11 и 14 — **предупредив пользователя, что именно собирается сделать**. Изменения на сервере — только батчированными идемпотентными скриптами, не интерактивными правками. Секреты GitHub ставит через `gh secret set`. Человеку остаётся только то, что требует чужих GUI: DNS у регистратора, оплата VPS, верификации аккаунтов, выдача ключей/паролей.

## Automation rules (hooks + scripts)

- **Хуки** (`.claude/hooks/`, детали и отключение — `docs/automation.md`): `session-start.sh` — git fetch, отставание ветки, uncommitted, gh-аккаунт; `guard-rm.sh` — блок деструктивных команд (Bash и PowerShell); `before-push.sh` — блок push при gh-аккаунт ≠ владелец origin + гейт `pnpm typecheck && pnpm lint` перед `git push` (обход осознанно: `SKIP_PUSH_GATE=1`); `format.sh` — biome на изменённых файлах; `subagent-stop.sh` — SubagentStop-гейт typecheck+lint после каждого субагента (обход `SKIP_SUBAGENT_GATE=1`); `stop-reminder.sh` — напоминание `/handoff`. Хуки ловят только команды Claude, не терминал.
- **Требования обвязки:** jq обязателен (guard-хуки без него fail-closed — блокируют всё); состояние хуков — в `.claude/state/` (gitignored), не в `/tmp`. Smoke-тест: `bash .claude/hooks/test-hooks.sh`.
- **Secrets:** `.env*` (except `.env.example`) — never commit. Production secrets live in GitHub Environment `production` (single multiline secret `PROD_ENV_FILE` = full `.env.production`); the deploy workflow writes them into `releases/<sha>/.env` on every push. Update via `gh secret set --env production PROD_ENV_FILE < ~/projects/{site}/.env.production`. Fallback when Actions are down: `scripts/sync-env.sh` patches `current/.env` directly.
- **Rollback prod:** `scripts/rollback.sh` — atomic switch of `~/prod/{site}/current` symlink back to the previous release in `releases/<previous-sha>/` + `pm2 delete` + `PORT=... HOSTNAME=127.0.0.1 pm2 start`. Seconds, no rebuild. Then on Mac: `git revert <bad-commit> && git push origin main` — Actions builds and ships a fresh release (tar.gz по scp). For merge commits use `git revert -m 1 <hash>`.

## Multi-Claude protocol

Одна **интерактивная** Claude-сессия = одна задача (одна спека). Параллельные интерактивные сессии на **ОДНУ папку проекта** по-прежнему запрещены — они не видят друг друга и поломают `.claude/memory/project_state.md`. **Оркестраторный режим с субагентами — штатный**: для крупных пластов (сайт целиком, rollout, recreate) оркестратор раздаёт брифы субагентам и один пишет память (субагентам она read-only). Вход — `/orchestrate`, правила — `docs/orchestration.md`. Последовательные сессии — норма:

- **Закончил работу / уходишь надолго:** `/handoff` — Claude обновит `.claude/memory/project_state.md` (Session log + Active phase + Next steps), спросит про uncommitted-изменения.
- **Начал новую сессию:** `/resume` — Claude прочитает память, сверится с git-состоянием, кратко резюмирует где остановились и подождёт ОК на работу.
- **Сломалось / Claude залип:** `/clear` → `/resume`. Если расходится `project_state.md` и git-state — поправь руками, потом `/resume`.

Stop-хук `.claude/hooks/stop-reminder.sh` подсказывает про `/handoff` если в текущей сессии были коммиты — мягкое напоминание, не блок.

Параллельно работать на **разные** папки проектов — ОК (один Claude-чат на одну папку).

## Memory triggers (when to update .claude/memory/)

- **After spec complete** → update `project_state.md` (mark done, set next spec)
- **Client gives feedback / correction** → save to `feedback.md` with **Why:** + **How to apply:**
- **Non-obvious decision made** → save to `decisions.md` with **Why:** + alternative considered
- **Incident / fix** → save to `lessons.md` (symptom → cause → fix → prevention)
- **External service integrated** (CRM, analytics, etc.) → save IDs/URLs to `references.md` (NEVER secrets)
- **New reusable component/pattern created** → add to `pointers.md`
- **Понял, что нужно что-то от заказчика** (доступ, материал, подтверждение) → сразу строка в `CLIENT-TODO.md` (формат — `specs/templates/client-todo-template.md`)
- **After /clear** → first action: read `.claude/memory/INDEX.md`

## KB pointers (read on demand, do NOT inline)

Always start by checking `docs/INDEX.md` to pick the right files for the current task.

```
docs/INDEX.md              — table: which file → when to read (start here)
docs/workflow.md           — dev cycle, context management, anti-patterns
docs/stack.md              — tech stack details, init commands
docs/architecture.md       — folder structure, App Router, Server/Client split
docs/design-system.md      — colors, typography, spacing, animation rules
docs/content-layout.md     — 44 section types and their structure
docs/design-motion.md      — паттерны подачи секций, анти-монотонность, бюджет анимаций (спеки 03/04 и любые правки дизайна)
docs/forms-and-crm.md      — form handling (ядро): архитектура multi-sink, Server Action, fallback
docs/forms-sink-recipes.md — полные листинги sink-каналов + подготовка каналов; читать при подключении конкретного канала
docs/deploy.md             — Mac → GitHub → VPS, branches, Actions, daily cycle, rollback
docs/seo.md                — meta, Schema.org, redirects, Yandex specifics
docs/performance.md        — Core Web Vitals, methodology (LCP breakdown), budget
docs/conversion-patterns.md — CTA placement, social proof, lead magnets, quiz
docs/legal-templates.md    — RU 152-ФЗ: cookie banner, PDn consent, privacy/consent pages
docs/orchestration.md      — оркестраторный режим: роли, волны, брифы, гейты; читать перед /orchestrate
docs/automation.md         — хуки, slash-команды, sync-env/rollback; читать когда хук блокирует/пишет непонятное
docs/troubleshooting.md    — частые косяки; когда что-то сломалось — сначала сюда
docs/ai-assets.md          — конвейер AI-изображений (стиль-блок, промпты); при генерации картинок для сайта

# Серверные чек-листы (Claude исполняет через SSH):
docs/server-manual-setup.md — разовая настройка свежего VPS (scripts/bootstrap-vps.sh)
docs/server-add-site.md     — подключение сайта на готовый VPS
docs/server-multisite.md    — как уживаются несколько сайтов
docs/domain-connect.md      — A-записи, Cloudflare, dig-проверка
```

## Project-specific (filled per site, source for content)

```
docs/spec.md          — business goals, target audience, services, brand colors
docs/content.md       — page texts (from client or migration)
docs/pages.md         — sitemap as markdown table, navigation, redirects
docs/integrations.md  — CRM, analytics, domain, external services
```

## Specs

Task specs in `specs/` folder. Execute one per session (или волной через `/orchestrate` — см. `docs/orchestration.md`).
- `specs/INDEX.md` — sequence (00 → 01a → 01b → 02 … → 14), dependency graph
- `_BUILD/HOW-TO-START.md` §0-§3 — ритуал разработчика до запуска Claude (установка Mac, создание репо, первое сообщение)
- `specs/optional/` — quiz, ecommerce, i18n, migrate-from-existing, visual-recreate, design-first входы (макет / референсы)
- `specs/templates/` — spec-template, page-spec-template, client-todo-template — copy when starting new specs
- `specs/examples/` — mature spec examples from a real project (reference, not tasks)

## Commands

<!-- Порт dev по умолчанию 3000. На VPS prod-порт берётся из реестра ~/ports.md. -->

```
pnpm dev         — dev server (port 3000, локально на Mac)
pnpm build       — production build (собирается на GitHub-runner, уезжает на VPS tar.gz-ом (scp) как standalone-артефакт)
pnpm start       — prod server (порт передаётся через PORT=... при pm2 start)
pnpm lint        — Biome linter (заменил ESLint)
pnpm format      — Biome formatter (write changes)
pnpm typecheck   — tsc --noEmit
```

## Testing

After each change: проверяй сам встроенным браузером (`mcp__Claude_Browser__*`) — resize-матрица 375/768/1280 + `read_console_messages {onlyErrors: true}` (ноль ошибок). Ручной скриншот человеком — fallback.
Before merging to `main`: `pnpm build` must succeed locally, Lighthouse mobile + desktop ≥ 90.
