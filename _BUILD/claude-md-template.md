<!--
CLAUDE.md template — скопируй как `CLAUDE.md` в корень нового проекта.
Замени все [плейсхолдеры] в квадратных скобках на значения проекта.
Секции «Stack», «Commands», «Testing» подстрой под реальный стек, если он отличается от дефолта (Next.js + Tailwind + shadcn).
После заполнения удали этот верхний HTML-комментарий.
-->

# Project: [Name]

[One sentence: what this project is, who it's for, what's the main goal]

<!-- Пример: «migrator.me — посадочная сеть юридической фирмы по иммиграции в США, цель — собирать лиды на консультацию и вести их через квиз-калькулятор в воронку CRM.» -->

## Stack

<!-- Дефолт v2.1. Замени если другой стек. -->

Next.js 16 (App Router, Turbopack) + Tailwind v4 + shadcn/ui (base-ui) + TypeScript
Forms: React Hook Form + Zod → /api/lead → CRM (with `data/leads.json` fallback)
Content: MDX (no database)
Dev: локально на Mac, `npm run dev` на `localhost:3000`
Deploy: git push → GitHub Actions → PM2 + Nginx + Let's Encrypt на VPS (см. docs/deploy.md)

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
- `specs/INDEX.md` — sequence (00.5 → 00 → 01a → 01b → 02 … → 13), dependency graph
- `specs/00.5-new-project-init.md` — ритуал разработчика (делается до Claude)
- `specs/optional/` — quiz, ecommerce, i18n, migrate-from-existing
- `specs/templates/spec-template.md` and `page-spec-template.md` — copy when starting new specs
- `specs/examples/` — mature spec examples (reference, not tasks)

## Commands

<!-- Порт dev по умолчанию 3000. На VPS prod-порт берётся из реестра ~/ports.md. -->

```
npm run dev      — dev server (port 3000, локально на Mac)
npm run build    — production build (собирается на VPS после git pull)
npm run start    — prod server (порт передаётся через PORT=... при pm2 start)
npm run lint     — linting
```

## Testing

After each change: check on localhost, no console errors, responsive on 375/768/1280px.
Before merging to `main`: `npm run build` must succeed locally, Lighthouse mobile + desktop ≥ 90.
