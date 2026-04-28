# Spec 02: Инициализация проекта Next.js

## KB files to read first

- docs/stack.md
- docs/architecture.md
- docs/spec.md (название проекта, домен)
- `.claude/memory/references.md`, `.claude/memory/decisions.md`

## Goal

Создать Next.js-проект со всей структурой папок, установленными зависимостями и базовой конфигурацией. На выходе — `pnpm dev` показывает пустую страницу без ошибок, готовая база для дизайн-системы.

## Tasks

1. Создать Next.js проект (флаг `--no-eslint` — линтер ставим отдельно, через Biome, см. шаг 5):
   ```bash
   npx create-next-app@latest [project-name] --typescript --tailwind --app --turbopack --no-eslint
   cd [project-name]
   ```
2. Инициализировать shadcn/ui:
   ```bash
   npx shadcn@latest init
   ```
   Выбрать: New York style, base color = neutral, CSS variables = yes
3. Установить базовые shadcn/ui компоненты:
   ```bash
   npx shadcn@latest add button card accordion dialog input select tabs badge separator sheet form label textarea radio-group sonner
   ```
4. Установить дополнительные пакеты:
   ```bash
   pnpm add react-hook-form @hookform/resolvers zod @marsidev/react-turnstile sharp lucide-react clsx tailwind-merge class-variance-authority tw-animate-css
   ```
   `@marsidev/react-turnstile` — клиент Cloudflare Turnstile (антиспам форм, см. `docs/forms-and-crm.md` § «Антиспам»). Подключение в формы и серверная verify — спека 09. MDX-стек (`content-collections` + плагины) ставится отдельно в `specs/07-blog-optional.md` — он опциональный, только если в `docs/pages.md` запланирован блог.
5. Установить и инициализировать Biome (заменяет ESLint+Prettier) + типы Schema.org:
   ```bash
   pnpm add -D --save-exact @biomejs/biome
   pnpm add -D schema-dts
   pnpm exec biome init
   ```
   Скопировать содержимое `biome.json.example` из bootstrap-репо в `biome.json` проекта (или адаптировать сгенерированный). Ключевые настройки: `linter.recommended + a11y.recommended`, `formatter.lineWidth: 100`, `quoteStyle: single`, `semicolons: asNeeded`, `useSortedClasses` для Tailwind. После — прогнать `pnpm exec biome check --write` один раз, чтобы привести create-next-app файлы к формату.

   `schema-dts` даёт типы для JSON-LD (`WithContext<Service>`, `WithContext<BreadcrumbList>` и т.д.) — используются в `lib/schema.ts` начиная со спеки 05. Без них опечатка в `@type` ловится только Yandex Validator-ом на проде.
6. Настроить `next.config.ts` (без standalone — см. `docs/stack.md`):
   ```typescript
   const nextConfig = {
     compress: false, // сжатие делает Caddy (encode gzip zstd в шаблоне server-add-site)
     images: {
       formats: ['image/avif', 'image/webp'],
       deviceSizes: [640, 750, 828, 1080, 1200, 1920],
       minimumCacheTTL: 60 * 60 * 24 * 365,
     },
     reactStrictMode: true,
     experimental: {
       ppr: 'incremental', // Partial Prerendering — опт-ин per-route через `export const experimental_ppr = true`
     },
   }
   ```
   `experimental.ppr: 'incremental'` оставляет дефолтный SSG для всех роутов и активирует PPR только там, где явно прописано `experimental_ppr = true` в page.tsx. Подробнее когда применять — `docs/architecture.md` § «Partial Prerendering». Если PPR в проекте не пригодится — флаг можно убрать без последствий.
7. Настроить `package.json` scripts (dev на Mac и prod на VPS используют один порт 3000; на VPS фактический порт передаётся через переменную `PORT` при `pm2 start`):
   ```json
   "scripts": {
     "dev": "next dev -p 3000 --turbopack",
     "build": "next build",
     "start": "next start -p 3000",
     "lint": "biome check",
     "format": "biome check --write",
     "typecheck": "tsc --noEmit"
   }
   ```
   `lint` и `format` идут через Biome (он же сортирует Tailwind-классы — `prettier-plugin-tailwindcss` ставить не надо). `typecheck` отделён от `lint`, потому что Biome не делает проверку типов — её делает `tsc`.
8. Создать структуру папок (если каких-то нет):
   ```
   app/                  # уже создано create-next-app
   components/ui/        # уже создано shadcn/ui init
   components/layout/    # создать
   components/sections/  # создать
   components/forms/     # создать
   content/services/     # создать (для MDX)
   content/blog/         # создать (если планируется блог)
   lib/                  # уже создано (utils.ts), добавить consultation-context.tsx
   public/images/        # создать
   public/fonts/         # создать (если шрифты локально)
   public/og/            # создать (для OG-картинок)
   data/                 # создать (для leads.json fallback)
   ```
9. Создать `.gitignore` с обязательными исключениями: `.env*`, `data/leads.json`, `node_modules`, `.next`, `*.log`
10. Создать пустой `app/layout.tsx` с базовым HTML-каркасом (lang="ru", placeholder Header/Footer, ConsultationDialogProvider — будет добавлен в спеке 04)
11. Создать пустую `app/page.tsx` (просто `<main>Hello</main>` — наполнение в спеке 04)
12. Скопировать `CLAUDE.md` из bootstrap в корень проекта, заполнить секцию `Project: [name]`
13. Первый коммит: `chore: initial Next.js setup`
14. Проверка: `pnpm dev` — открыть localhost:3000 — пустая страница без ошибок в консоли

## Boundaries

- **Always:** использовать точные версии из docs/stack.md, не «latest» наугад
- **Ask first:** перед добавлением любой зависимости, не указанной в docs/stack.md
- **Never:** удалять `pnpm-lock.yaml`, добавлять Radix напрямую (только через shadcn base-ui), править файлы внутри `.next/`

## Done when

- `pnpm dev` запускает сервер на порту 3000 без ошибок
- Все папки структуры созданы
- shadcn/ui компоненты установлены, Tailwind работает (проверка: `<Button>` рендерится со стилями)
- `next.config.ts` содержит настройку изображений и `compress: false`
- `biome.json` существует в корне; `pnpm lint` и `pnpm format` отрабатывают без падений; в `package.json` нет ESLint/Prettier-зависимостей
- `CLAUDE.md` в корне проекта, секция `Project:` заполнена
- Первый коммит создан

## Memory updates

- `pointers.md` — пути к ключевым папкам (components/sections/, lib/, content/)
- `project_state.md` — done, следующая `03-design-system`
