# Spec 20: Server/Client Components Refactor

> ⚠️ **Pre-v3 пример.** Стек устарел (npm + nginx + pull-based deploy). Используй ТОЛЬКО как референс **формата** спеки (декомпозиция, описание critical complexity, баланс «требования / задачи / критерии») — не копируй команды и пути. Канонический стек v3.0+ — pnpm, Caddy, push-based deploy, Server Actions.

## KB files to read first
- docs/architecture.md (Server/Client разделение)
- docs/performance.md (§ 13.4 «Вирусный client» антипаттерн)
- components/service-page/ServicePageTemplate.tsx

## Goal
Convert all service pages from "use client" to server components. Only interactive parts (forms, buttons with handlers, consultation dialog) stay client-side. This gives: server-rendered HTML, metadata directly in page.tsx, less JS shipped to browser, better Lighthouse and SEO.

## Background
Currently all 15 service pages are "use client". This means:
- All content renders on the client (bigger JS bundle, slower LCP)
- Cannot export metadata from page.tsx (workaround: layout.tsx files created in spec session 1)
- No benefit of Next.js server components

After this refactor:
- page.tsx is server component with metadata export → remove layout.tsx workarounds
- ServicePageTemplate split into server (content) and client (forms/interactivity) parts
- Dramatic reduction in client-side JS

## Critical complexity

Some ServicePageData fields contain JSX with client hooks. For example `descriptionContent` is a `ReactNode` that may include `<Link>`, icons, and potentially interactive elements. Approach:
- Static JSX (Link, icons, divs) works fine in server components
- If any field uses hooks (useState, useConsultationDialog) — that specific field's content must be wrapped in a client component

Read ALL page.tsx files before starting to identify which pages have interactive JSX in data fields.

## Requirements

### 1. Split ServicePageTemplate
Current: `components/service-page/ServicePageTemplate.tsx` — one big "use client" component (445 lines).

Split into:
- `components/service-page/ServicePageTemplate.tsx` — **server component** (no "use client"), renders all static sections (hero, description, who, criteria, steps, timeline, advantages, comparison, urgency, guarantees)
- `components/service-page/ServicePageForms.tsx` — **client component** ("use client"), contains: mid-CTA form, final CTA form, consultation button handlers, any useState/toast logic
- `components/service-page/HeroWithCTA.tsx` — **client component** if hero has interactive CTA buttons that use useConsultationDialog

### 2. Convert each service page
For each of the 13 pages using ServicePageTemplate:
- Remove "use client" from page.tsx
- Move metadata from layout.tsx INTO page.tsx as `export const metadata`
- Delete the layout.tsx file (no longer needed)
- Keep data object (ServicePageData) in page.tsx — it's just static data
- Import icons from lucide-react (works in server components)
- **IMPORTANT:** if page's data contains JSX that uses hooks — extract that JSX into a client component

Pages: eb3, o1, eb5, e2, eb1, eb2-niw, grazhdanstvo, dvoinoe-grazhdanstvo, biznes, biznes-viza, otkaz-v-vize, grin-karta, l1

### 3. Handle viza-talantov
Custom page (not using ServicePageTemplate). Same approach:
- Extract interactive parts into client components
- Keep page.tsx as server component with metadata
- Delete layout.tsx

Note: eb1a directory does NOT exist — skip it.

### 4. Handle otzyvy page
Check if it needs "use client". If review display is static, convert to server component.

## Tasks
1. Read ServicePageTemplate.tsx fully, identify all client-only code (useState, event handlers, toast)
2. Create ServicePageForms.tsx with extracted client code
3. Refactor ServicePageTemplate.tsx to server component, importing ServicePageForms
4. Convert one page as proof of concept (eb3) — verify build + verify page works
5. Convert remaining 12 ServicePageTemplate pages
6. Convert viza-talantov (custom page)
7. Convert otzyvy page (if applicable)
8. Move metadata from layout.tsx to page.tsx for all converted pages
9. Delete all service page layout.tsx files
10. Final build + verify all pages render correctly

## Boundaries
- **Always:** commit after each sub-task (each page conversion)
- **Ask first:** if a page has unusual interactive elements not covered by ServicePageForms
- **Never:** change page content/text, change URLs, modify root layout.tsx

## Testing forms (specific steps)
1. Open any service page on localhost
2. Click "Бесплатная консультация" in hero — ConsultationDialog should open
3. Fill form, submit — should show success toast
4. Scroll to mid-CTA form — fill and submit — should work
5. Scroll to final CTA form — fill and submit — should work
6. Check browser console — no errors

## Before starting
- Commit current state: `git tag pre-spec-20`
- Verify: `npm run build` passes before any changes

## Deploy after completion
```
npm run build && git push origin dev
# On server:
cd /var/www/migrator && git pull && npm run build && pm2 restart migrator
# Verify: https://migrator.timur-seo.ru/eb3/ renders correctly
```

## Done when
- All service pages are server components (no "use client" in page.tsx)
- Metadata exported directly from page.tsx
- All layout.tsx in service page folders deleted
- npm run build passes
- All pages render identically to before (visual check on localhost)
- No console errors
- All 3 form types work (consultation dialog, mid-CTA, final CTA)
