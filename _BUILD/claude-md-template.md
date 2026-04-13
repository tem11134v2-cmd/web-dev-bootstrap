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

<!-- Дефолт v2.0. Замени если другой стек. -->

Next.js 16 (App Router, Turbopack, standalone) + Tailwind v4 + shadcn/ui (base-ui) + TypeScript
Forms: React Hook Form + Zod → /api/lead → CRM (with `data/leads.json` fallback)
Content: MDX (no database)
Deploy: PM2 + Nginx + Let's Encrypt on VPS — see docs/deploy.md (schemes A/B)

## Rules

- IMPORTANT: Always use plan mode (Shift+Tab×2) before coding
- Read relevant `docs/` files listed in spec's "KB files to read first" — never load all docs
- Read `.claude/memory/INDEX.md` at session start, then load only relevant memory files
- Work in `dev` branch (scheme B) or directly on main (scheme A) — see references.md
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
docs/deploy.md             — two deploy schemes (A/B), daily work, rollback
docs/deploy-server-setup.md — VPS bootstrap, nginx, SSL, GitHub Actions, Cloudflare
docs/seo.md                — meta, Schema.org, redirects, Yandex specifics
docs/performance.md        — Core Web Vitals, methodology (LCP breakdown), budget
docs/conversion-patterns.md — CTA placement, social proof, lead magnets, quiz
docs/legal-templates.md    — RU 152-ФЗ: cookie banner, PDn consent, privacy/terms
```

## Project-specific (filled per site, source for content)

```
docs/spec.md          — business goals, target audience, services, brand colors
docs/content.md       — page texts (from client or migration)
docs/pages.md         — sitemap as markdown table, navigation, redirects
docs/integrations.md  — CRM, analytics, domain, external services
```

## Specs

Task specs in `specs/` folder, numbered 00→13. Execute one per session.
- `specs/INDEX.md` — sequence, dependency graph, when to use optional specs
- `specs/optional/` — quiz, ecommerce, i18n, migrate-from-existing
- `specs/templates/spec-template.md` and `page-spec-template.md` — copy when starting new specs
- `specs/examples/` — mature spec examples (reference, not tasks)

## Commands

<!-- Порты подставь свои (dev/prod). Компрессию изображений убери если не нужна. -->

```
npm run dev      — dev server (port [DEV_PORT, e.g. 4000])
npm run build    — production build (standalone)
npm run start    — prod server (port [PROD_PORT, e.g. 3000])
npm run lint     — linting
npm run compress — sharp image optimization
```

## Testing

After each change: check on localhost, no console errors, responsive on 375/768/1280px.
Before deploy: `npm run build` must succeed, Lighthouse mobile + desktop ≥ 90.
