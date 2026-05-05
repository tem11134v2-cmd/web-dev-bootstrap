<!--
============================================================
BOOTSTRAP META — автозагружается Claude Code при открытии папки.

Если ты читаешь это и значение `# Project:` ниже равно **[Name]**
(то есть плейсхолдер не заменён) — ты в **канонической папке
`web-dev-bootstrap`**, цель которой быть шаблоном, а не сайтом.

В этом режиме:
1. Читай `README.md` и `_BUILD/changelog.md` (история версий v2.0 →
   v3.0), чтобы понимать, что уже сделано.
2. `git log --oneline -10` и посмотри текущую ветку/теги.
3. Спроси пользователя: «Что улучшаем в шаблоне?»
4. Работа: ветка `feature/{тема}`, commit, push, PR в `main`. После
   merge — новый semver-тег (v3.0.1, v3.1, v4.0 и т.д.), запись в
   `_BUILD/changelog.md` (сверху, самая свежая версия).
5. **НЕ запускай спеки `specs/00-13`** — они для сайтов, которые
   раскатываются из этого шаблона, не для него самого. Шаблон
   редактируется напрямую.

Если `# Project:` ниже заполнено реальным именем сайта (`timur-seo`,
`migrator` и т.п.) — ты в обычном проекте, игнорируй эту META-шапку
и работай по spec flow как обычно.
============================================================
-->

# Project: [Name]

[One sentence: what this project is, who it's for, what's the main goal]

## Stack

Next.js 16 (App Router, Turbopack) + Tailwind v4 + shadcn/ui (base-ui) + TypeScript
Tooling: Biome (lint+format), pnpm (через corepack/mise), schema-dts для JSON-LD типов
Forms: React Hook Form + Zod → Server Action `submitLead` → multi-sink (Google Sheets / Telegram / CRM) через `Promise.allSettled`, с JSON-fallback если все упали
Content: MDX (no database)
Dev: локально на Mac, `pnpm dev` на `localhost:3000`
Deploy: git push → GitHub Actions → PM2 + Caddy (встроенный ACME) на VPS (см. docs/deploy.md)

## Rules

- IMPORTANT: Always use plan mode (Shift+Tab×2) before coding
- Read relevant `docs/` files listed in spec's "KB files to read first" — never load all docs
- Read `.claude/memory/INDEX.md` at session start, then load only relevant memory files
- Work on `dev` branch, merge to `main` only via PR (`main` is protected)
- Never push to `main` directly. SSH to the VPS is allowed for setup/maintenance (see docs/server-*.md) — use the developer's key at `~/.ssh/id_ed25519`; run batched idempotent scripts, not ad-hoc interactive edits
- Commit after each completed sub-task with English messages
- Max 150 lines per component — split if longer
- ONLY use shadcn/ui components — never invent custom UI
- Tailwind only — no custom CSS, no CSS modules, no styled-components
- Mobile-first responsive design
- Server Components by default; `"use client"` only for state/effects/handlers

## Automation rules (hooks + scripts)

- **Session start:** `git fetch origin`, check if branch is behind upstream, offer `git pull`. After pull — re-read `.claude/memory/INDEX.md`. Hook `.claude/hooks/session-start.sh` does this automatically at the start of every session.
- **Before any `git push` / `gh repo` / `gh pr` command:** verify `gh auth status` active account matches the repo owner from `git remote get-url origin`. On mismatch: `gh auth switch -h github.com -u <owner>`. Hook `.claude/hooks/before-push.sh` blocks Claude-side pushes on mismatch (exit 2). Caveat: catches only Claude-side commands, not terminal pushes.
- **Secrets:** `.env*` (except `.env.example`) — never commit. Production secrets live in GitHub Environment `production` (single multiline secret `PROD_ENV_FILE` = full `.env.production`); the deploy workflow writes them into `releases/<sha>/.env` on every push. Update via `gh secret set --env production PROD_ENV_FILE < ~/projects/{site}/.env.production`. Fallback when Actions are down: `scripts/sync-env.sh` patches `current/.env` directly.
- **Rollback prod:** `scripts/rollback.sh` — atomic switch of `~/prod/{site}/current` symlink back to the previous release in `releases/<previous-sha>/` + `pm2 reload`. Milliseconds, no rebuild. Then on Mac: `git revert <bad-commit> && git push origin main` — Actions builds and rsyncs a fresh release. For merge commits use `git revert -m 1 <hash>`.

## Multi-Claude protocol

Одна Claude-сессия = одна задача (одна спека). Параллельные сессии на **ОДНУ папку проекта** запрещены — они не видят друг друга и поломают `.claude/memory/project_state.md`. Последовательные — норма:

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
docs/forms-and-crm.md      — form handling, CRM integration, consultation dialog
docs/deploy.md             — Mac → GitHub → VPS, branches, Actions, daily cycle, rollback
docs/seo.md                — meta, Schema.org, redirects, Yandex specifics
docs/performance.md        — Core Web Vitals, methodology (LCP breakdown), budget
docs/conversion-patterns.md — CTA placement, social proof, lead magnets, quiz
docs/legal-templates.md    — RU 152-ФЗ: cookie banner, PDn consent, privacy/terms

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

Task specs in `specs/` folder. Execute one per session.
- `specs/INDEX.md` — sequence (00 → 01a → 01b → 02 … → 13), dependency graph
- `_BUILD/HOW-TO-START.md` §0-§3 — ритуал разработчика до запуска Claude (установка Mac, создание репо, первое сообщение)
- `specs/optional/` — quiz, ecommerce, i18n, migrate-from-existing
- `specs/templates/spec-template.md` and `page-spec-template.md` — copy when starting new specs
- `specs/examples/` — mature spec examples from a real project (reference, not tasks)

## Commands

```
pnpm dev         — dev server (port 3000, локально на Mac)
pnpm build       — production build (собирается на GitHub-runner, rsync-ится на VPS как standalone-артефакт)
pnpm start       — prod server (порт передаётся через PORT=... при pm2 start)
pnpm lint        — Biome linter (заменил ESLint)
pnpm format      — Biome formatter (write changes)
pnpm typecheck   — tsc --noEmit
```

## Testing

After each change: check on localhost, no console errors, responsive on 375/768/1280px.
Before merging to `main`: `pnpm build` must succeed locally, Lighthouse mobile + desktop ≥ 90.
