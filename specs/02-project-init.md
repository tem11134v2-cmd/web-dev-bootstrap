# Spec 02: Инициализация проекта Next.js

## KB files to read first

- docs/stack.md
- docs/architecture.md
- docs/spec.md (название проекта, домен)
- `.claude/memory/references.md`, `.claude/memory/decisions.md`

## Goal

Создать Next.js-проект со всей структурой папок, установленными зависимостями и базовой конфигурацией. На выходе — `npm run dev` показывает пустую страницу без ошибок, готовая база для дизайн-системы.

## Tasks

1. Создать Next.js проект:
   ```bash
   npx create-next-app@latest [project-name] --typescript --tailwind --app --turbopack
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
   npm install react-hook-form @hookform/resolvers zod next-mdx-remote gray-matter sharp lucide-react clsx tailwind-merge class-variance-authority tw-animate-css
   ```
5. Настроить standalone output в `next.config.ts`:
   ```typescript
   const nextConfig = {
     output: 'standalone',
     compress: false, // сжатие на nginx
     images: {
       formats: ['image/avif', 'image/webp'],
       deviceSizes: [640, 750, 828, 1080, 1200, 1920],
       minimumCacheTTL: 60 * 60 * 24 * 365,
     },
     reactStrictMode: true,
   }
   ```
6. Настроить порты в `package.json` (по схеме из references.md):
   ```json
   "scripts": {
     "dev": "next dev -p 4000 --turbopack",
     "build": "next build",
     "start": "next start -p 3000",
     "lint": "next lint"
   }
   ```
7. Создать структуру папок (если каких-то нет):
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
8. Создать `.gitignore` с обязательными исключениями: `.env*`, `data/leads.json`, `node_modules`, `.next`, `*.log`
9. Создать пустой `app/layout.tsx` с базовым HTML-каркасом (lang="ru", placeholder Header/Footer, ConsultationDialogProvider — будет добавлен в спеке 09)
10. Создать пустую `app/page.tsx` (просто `<main>Hello</main>` — наполнение в спеке 04)
11. Скопировать `CLAUDE.md` из bootstrap в корень проекта, заполнить секцию `Project: [name]`
12. Первый коммит: `chore: initial Next.js setup`
13. Проверка: `npm run dev` — открыть localhost:4000 — пустая страница без ошибок в консоли

## Boundaries

- **Always:** использовать точные версии из docs/stack.md, не «latest» наугад
- **Ask first:** перед добавлением любой зависимости, не указанной в docs/stack.md
- **Never:** удалять `package-lock.json`, добавлять Radix напрямую (только через shadcn base-ui), править файлы внутри `.next/`

## Done when

- `npm run dev` запускает сервер на порту 4000 без ошибок
- Все папки структуры созданы
- shadcn/ui компоненты установлены, Tailwind работает (проверка: `<Button>` рендерится со стилями)
- `next.config.ts` содержит standalone output и оптимизацию изображений
- `CLAUDE.md` в корне проекта, секция `Project:` заполнена
- Первый коммит создан

## Memory updates

- `pointers.md` — пути к ключевым папкам (components/sections/, lib/, content/)
- `project_state.md` — done, следующая `03-design-system`
